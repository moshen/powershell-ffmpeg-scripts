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
# Dot-source this file from another script to expose the Get-VideoEncoder
# function:
#
#     . "$PSScriptRoot\get-video-encoder.ps1"
#     $enc = Get-VideoEncoder -Codec "h264"

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

function Get-VideoEncoder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("h264", "hevc", "av1")]
        [string]$Codec
    )

    $software = switch ($Codec) {
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

    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        Write-Warning "ffmpeg was not found in PATH"
        return $software
    }

    # QSV/AMF preset names are quality-vs-speed tradeoffs, not resolution or
    # bitrate settings, so codecs can pick their own defaults. AV1 favors
    # quality since it's used less for real-time/latency-sensitive work.
    $qsvPreset = switch ($Codec) { "av1" { "slow" } Default { "fast" } }
    $amfPreset = switch ($Codec) { "av1" { "high_quality" } Default { "speed" } }

    $candidates = @(
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

    $encoders = ffmpeg -hide_banner -encoders 2>&1 | Out-String

    foreach ($candidate in $candidates) {
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
