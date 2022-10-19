# This script was created in order to convert files into a format that's usable
# by Davinci Resolve. For some reason, Resolve does not import h264 encoded
# video properly, making it impossible to work with certain source material
# without first converting it.
#
# This script also forces the file into 1080p format for editing

param ($filename, $fps = 30)

if ([string]::IsNullOrEmpty($filename)) {
    Write-Output "No filename argument provided"
    exit
}

if (-Not (Test-Path -Path $filename)) {
    Write-Output "$filename does not exist"
    exit
}

if (-Not ($fps -match "^[0-9]+$")) {
    Write-Output "fps $fps is not a number"
    exit
}

$new_filename = [System.IO.Path]::GetFileNameWithoutExtension("$filename")

ffmpeg -i "$filename" `
    "-c:v" dnxhd `
    -vf "scale=(iw*sar)*min(1920/(iw*sar)\,1080/ih):ih*min(1920/(iw*sar)\,1080/ih), pad=1920:1080:(1920-iw*min(1920/iw\,1080/ih))/2:(1080-ih*min(1920/iw\,1080/ih))/2, fps=${fps},format=yuv422p" `
    "-b:v" 175M `
    "-c:a" pcm_s16le `
    "${new_filename}.mov"
