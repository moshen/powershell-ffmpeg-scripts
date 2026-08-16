# Detects which hardware accelerated video encoder ffmpeg supports, then returns
# a hashtable with the encoder name, preset, optional hwaccel flags, and the
# matching scale filter for the requested codec.
#
# Detection order is NVIDIA (NVENC), Intel (QSV), AMD (AMF), then a software
# fallback (libx264 / libx265 / libsvtav1).
#
# Dot-source this file from another script to expose the Get-VideoEncoder
# function:
#
#     . "$PSScriptRoot\get-video-encoder.ps1"
#     $enc = Get-VideoEncoder -Codec "h264"

function Get-VideoEncoder {
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

    # QSV/AMF preset names are quality-vs-speed tradeoffs, not resolution or
    # bitrate settings, so codecs can pick their own defaults. AV1 favors
    # quality since it's used less for real-time/latency-sensitive work.
    $qsvPreset = switch ($Codec) { "av1" { "slow" } Default { "fast" } }
    $amfPreset = switch ($Codec) { "av1" { "high_quality" } Default { "speed" } }

    $encoders = ffmpeg -hide_banner -encoders 2>&1 | Out-String

    if ($encoders -match "${Codec}_nvenc") {
        return @{
            Encoder              = "${Codec}_nvenc"
            Preset               = "p7"
            HwAccel              = "cuda"
            HwAccelOutputFormat  = "cuda"
            ScaleFilter          = "scale_cuda"
        }
    }

    if ($encoders -match "${Codec}_qsv") {
        return @{
            Encoder              = "${Codec}_qsv"
            Preset               = $qsvPreset
            HwAccel              = "qsv"
            HwAccelOutputFormat  = "qsv"
            ScaleFilter          = "vpp_qsv"
        }
    }

    if ($encoders -match "${Codec}_amf") {
        return @{
            Encoder              = "${Codec}_amf"
            Preset               = $amfPreset
            HwAccel              = $null
            HwAccelOutputFormat  = $null
            ScaleFilter          = "scale"
        }
    }

    return $software
}