# Detects which hardware accelerated video encoder ffmpeg supports, then returns
# a hashtable with the encoder name, preset, optional hwaccel flags, and the
# matching scale filter for the requested codec.
#
# Detection order is NVIDIA (NVENC), Intel (QSV), AMD (AMF), then a software
# fallback (libx264 / libx265 / libsvtav1).
#
# `ffmpeg -encoders` lists every encoder compiled into the build, not the ones
# this machine can actually use (the common Windows builds include NVENC, QSV
# and AMF all at once). So each hardware encoder found in that list is also
# test-encoded on a few generated frames, and only used if that succeeds.
#
# Saving defaults
# ---------------
# Detection runs a few short test encodes. To skip it on every run, detect once
# and save the result:
#
#     get-video-encoder.ps1 -SaveDefaults
#
# This writes the chosen encoder for each codec to
# %LOCALAPPDATA%\powershell-ffmpeg-scripts\video-encoders.json, which
# Get-VideoEncoder then reads instead of detecting. Run it again after changing
# GPU, drivers or ffmpeg build, or delete the file to go back to detecting on
# every run.
#
# Using from another script
# -------------------------
# Dot-source this file to expose the Get-VideoEncoder function:
#
#     . "$PSScriptRoot\get-video-encoder.ps1"
#     $enc = Get-VideoEncoder -Codec "h264"
#
# Pass -Detect to ignore any saved default and detect again.

param(
    # Detect the best encoder for every codec and save it as the default.
    [switch]$SaveDefaults
)

function Get-SoftwareVideoEncoder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Codec
    )

    switch ($Codec) {
        "h264" {
            @{
                Encoder              = "libx264"
                Preset               = "medium"
                HwAccel              = $null
                HwAccelOutputFormat  = $null
                ScaleFilter          = "scale"
            }
        }
        "hevc" {
            @{
                Encoder              = "libx265"
                Preset               = "medium"
                HwAccel              = $null
                HwAccelOutputFormat  = $null
                ScaleFilter          = "scale"
            }
        }
        "av1" {
            @{
                Encoder              = "libsvtav1"
                Preset               = "4"
                HwAccel              = $null
                HwAccelOutputFormat  = $null
                ScaleFilter          = "scale"
            }
        }
    }
}

# Hardware encoders for a codec, in the order they should be tried.
function Get-HardwareVideoEncoders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Codec
    )

    # QSV/AMF preset names are quality-vs-speed tradeoffs, not resolution or
    # bitrate settings, so codecs can pick their own defaults. AV1 favors
    # quality since it's used less for real-time/latency-sensitive work.
    $qsvPreset = switch ($Codec) { "av1" { "slow" } Default { "fast" } }
    $amfPreset = switch ($Codec) { "av1" { "high_quality" } Default { "speed" } }

    @(
        @{
            Encoder              = "${Codec}_nvenc"
            Preset               = "p7"
            HwAccel              = "cuda"
            HwAccelOutputFormat  = "cuda"
            ScaleFilter          = "scale_cuda"
        }
        @{
            Encoder              = "${Codec}_qsv"
            Preset               = $qsvPreset
            HwAccel              = "qsv"
            HwAccelOutputFormat  = "qsv"
            # scale_qsv takes width:height positionally. vpp_qsv does not: its
            # first two positional options are deinterlace and denoise, so
            # "vpp_qsv=-1:1080" fails.
            ScaleFilter          = "scale_qsv"
        }
        @{
            Encoder              = "${Codec}_amf"
            Preset               = $amfPreset
            HwAccel              = $null
            HwAccelOutputFormat  = $null
            ScaleFilter          = "scale"
        }
    )
}

# Settings for a specific encoder name, or $null if it isn't one we know.
function Get-VideoEncoderSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Codec,
        [Parameter(Mandatory = $true)]
        [string]$Encoder
    )

    $all = @(Get-HardwareVideoEncoders -Codec $Codec) + @(Get-SoftwareVideoEncoder -Codec $Codec)
    foreach ($settings in $all) {
        if ($settings.Encoder -eq $Encoder) {
            return $settings
        }
    }

    return $null
}

function Test-VideoEncoder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Encoder
    )

    # Encode a handful of frames from a generated test pattern into the null
    # muxer. This fails quickly when the GPU, driver or runtime the encoder
    # needs is missing (e.g. "Cannot load nvcuda.dll", or av1_nvenc on a
    # pre-RTX 40 card).
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $null = ffmpeg -hide_banner -nostdin -loglevel error `
            -f lavfi -i "color=c=black:s=640x360:r=30" `
            -frames:v 5 -c:v $Encoder -f null - 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

# Probe the hardware encoders and return the first that works, or the
# software encoder if none do.
function Find-VideoEncoder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Codec
    )

    $software = Get-SoftwareVideoEncoder -Codec $Codec

    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        Write-Warning "ffmpeg was not found in PATH"
        return $software
    }

    $encoders = ffmpeg -hide_banner -encoders 2>&1 | Out-String

    foreach ($candidate in (Get-HardwareVideoEncoders -Codec $Codec)) {
        $name = $candidate.Encoder

        if ($encoders -notmatch "\b$([regex]::Escape($name))\b") {
            continue
        }

        if (Test-VideoEncoder -Encoder $name) {
            return $candidate
        }

        Write-Verbose "$name is in this ffmpeg build but not usable on this machine, skipping"
    }

    return $software
}

function Get-VideoEncoderDefaultsPath {
    $base = [Environment]::GetFolderPath("LocalApplicationData")
    return Join-Path (Join-Path $base "powershell-ffmpeg-scripts") "video-encoders.json"
}

function Read-VideoEncoderDefaults {
    $path = Get-VideoEncoderDefaultsPath

    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        Write-Warning "Ignoring unreadable encoder defaults in ${path}: $_"
        return $null
    }
}

function Save-VideoEncoderDefaults {
    $defaults = [ordered]@{}
    foreach ($codec in @("h264", "hevc", "av1")) {
        $defaults[$codec] = (Find-VideoEncoder -Codec $codec).Encoder
    }

    $path = Get-VideoEncoderDefaultsPath
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path)
    $defaults | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8

    return @{
        Path     = $path
        Defaults = $defaults
    }
}

function Get-VideoEncoder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("h264", "hevc", "av1")]
        [string]$Codec,

        # Ignore any saved default and detect again.
        [switch]$Detect
    )

    if (-not $Detect) {
        $defaults = Read-VideoEncoderDefaults
        if ($defaults -and $defaults.$Codec) {
            $saved = $defaults.$Codec
            $settings = Get-VideoEncoderSettings -Codec $Codec -Encoder $saved
            if ($settings) {
                return $settings
            }

            Write-Warning "Saved default encoder '$saved' for $Codec is not recognized, detecting instead"
        }
    }

    return Find-VideoEncoder -Codec $Codec
}

if ($SaveDefaults) {
    $result = Save-VideoEncoderDefaults
    foreach ($codec in $result.Defaults.Keys) {
        Write-Output ("{0,-5} -> {1}" -f $codec, $result.Defaults[$codec])
    }
    Write-Output "Saved to $($result.Path)"
}
