# This script encapsulates the two pass hevc / aac .mp4 encoding process with ffmpeg
#

param(
    [System.IO.FileInfo]$input_file,
    [System.IO.FileInfo]$output_file,
    [float]$start_time = 0, # Start time in seconds (seek ttar)
    [float]$total_time = 0, # Total duration in seconds (snipping your clip)
    [string]$filters = "",
    [string]$resolution = "1080",
    [int]$audio_bitrate = 128,
    [float]$target_size # float target size
)

. "$PSScriptRoot\get-video-encoder.ps1"

$errs = @()

if ([string]::IsNullOrEmpty($input_file)) {
    $errs += "No input_file argument provided"
}

if (-Not (Test-Path -Path $input_file)) {
    $errs += "input_file $input_file does not exist"
}

if ([string]::IsNullOrEmpty($output_file)) {
    $errs += "No output_file argument provided"
}

if (Test-Path -Path "${output_file}.mp4") {
    $errs += "output_file $output_file exists"
}

# Make sure filters ends in a comma
if (!([string]::IsNullOrEmpty($filters)) -and !($filters -match ",$")) {
    $filters = "${filters},"
}

switch ($resolution) {
    "720" { Break }
    "1080" { Break }
    Default {
        $errs += "resolution $resolution is not 720 or 1080"
    }
}

if ($errs.count -gt 0) {
    Write-Output @errs
    exit
}

$duration

if ($total_time -lt 1) {
    $duration = "$(ffprobe.exe -show_entries format=duration -of 'default=noprint_wrappers=1:nokey=1' "$input_file")"
    $duration = [float]$duration - [float]$start_time
} else {
    $duration = [int]$total_time
}

if ($audio_bitrate -lt 1) {
    $audio_bitrate = 128
}

$bitrate = 0
if ($target_size -gt 0) {
    # Got this number from: https://trac.ffmpeg.org/wiki/Encode/H.264#twopass
    # subtracting audio bitrate (default 128)
    $bitrate = [int]((($target_size * 8388.608) / $duration) - ($audio_bitrate))

    if ($bitrate -eq 0) {
        Write-Error "Bitrate still 0, something went wrong"
        exit
    }

    Write-Output "Targeting bitrate: $bitrate"
}

$encoder = Get-VideoEncoder -Codec "hevc"
Write-Output "Using encoder: $($encoder.Encoder) (preset $($encoder.Preset))"

# With hardware decoding, frames normally stay on the GPU so the GPU scale
# filter can use them directly. Custom filters like eq or crop only work on
# frames in system memory, so when any are given, let ffmpeg copy decoded
# frames back and scale in software. The hardware encoder is still used.
$hwAccelOutputFormat = $encoder.HwAccelOutputFormat
$scaleFilter = $encoder.ScaleFilter
if (-not [string]::IsNullOrEmpty($filters)) {
    $hwAccelOutputFormat = $null
    $scaleFilter = "scale"
}

$params = @()

if ($start_time -gt 0) {
    $params = $params + @(
        "-ss"
        "$start_time"
    )
}

if ($encoder.HwAccel) {
    $params += @(
        '-hwaccel'
        $encoder.HwAccel
    )

    if ($hwAccelOutputFormat) {
        $params += @(
            '-hwaccel_output_format'
            $hwAccelOutputFormat
        )
    }
}

$params += @(
    '-i'
    "$input_file"
)

if ($total_time -gt 0) {
    $params += @(
        "-t"
        "$total_time"
    )
}

$params += @(
    '-vf'
    "${filters}${scaleFilter}=-1:${resolution}"
    '-c:v'
    $encoder.Encoder
    '-preset'
    $encoder.Preset
)

if ($bitrate -gt 0) {
    $params += @(
        '-b:v'
        "${bitrate}k"
    )
}

$params += @(
    '-c:a'
    'aac'
    '-b:a'
    "${audio_bitrate}k"
)

ffmpeg.exe @params `
    -pass 1 `
    -fps_mode cfr `
    -f null NUL
ffmpeg.exe @params `
    -pass 2 `
    "${output_file}.mp4"