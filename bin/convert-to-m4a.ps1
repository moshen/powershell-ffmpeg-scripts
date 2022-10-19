# This script was created to convert mainly from wav to aac/m4a, but can be used
# for any audio or video filetype to convert to aac/m4a

param ($filename, $bitrate = 192)

if ([string]::IsNullOrEmpty($filename)) {
    Write-Output "No filename argument provided"
    exit
}

if (-Not (Test-Path -Path "$filename")) {
    Write-Output "filename '$filename' does not exist"
    exit
}

if (-Not ($bitrate -match "^[0-9]+$")) {
    Write-Output "bitrate $bitrate is not a number"
    exit
}

$new_filename = [System.IO.Path]::GetFileNameWithoutExtension("$filename")

ffmpeg -i "$filename" `
    "-vn" `
    "-c:a" aac "-b:a" "${bitrate}k" `
    "${new_filename}.m4a"
