# Detects which hardware accelerated video encoder ffmpeg supports, then returns
# a hashtable with the encoder name, preset, optional hwaccel flags, and the
# matching scale filter for the requested codec.
#
# Detection order is NVIDIA (NVENC), Intel (QSV), AMD (AMF), then a software
# fallback (libx264 / libx265).
#
# Dot-source this file from another script to expose the Get-VideoEncoder
# function:
#
#     . "$PSScriptRoot\get-video-encoder.ps1"
#     $enc = Get-VideoEncoder -Codec "h264"

function Get-VideoEncoder {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("h264", "hevc")]
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
    }

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
            Preset               = "fast"
            HwAccel              = "qsv"
            HwAccelOutputFormat  = "qsv"
            ScaleFilter          = "vpp_qsv"
        }
    }

    if ($encoders -match "${Codec}_amf") {
        return @{
            Encoder              = "${Codec}_amf"
            Preset               = "speed"
            HwAccel              = $null
            HwAccelOutputFormat  = $null
            ScaleFilter          = "scale"
        }
    }

    return $software
}