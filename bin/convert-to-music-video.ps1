# This script was created to create music videos to upload to youtube but can
# be adapted to create videos for other social media platforms

param ($image_file, $music_file, $dimensions="1920:1080")

if ([string]::IsNullOrEmpty($image_file)) {
    Write-Output "No filename argument provided for the image"
    exit
}

if ([string]::IsNullOrEmpty($music_file)) {
    Write-Output "No filename argument provided for the music"
    exit
}

if ([string]::IsNullOrEmpty($dimensions) -or -not $dimensions -match '^-?[0-9]+:-?[0-9]+$') {
    Write-Output "${dimensions} are invalid dimensions"
    exit
}

if (-Not (Test-Path -Path "$image_file")) {
    Write-Output "$image_file does not exist"
    exit
}

if (-Not (Test-Path -Path "$music_file")) {
    Write-Output "$music_file does not exist"
    exit
}

$new_filename = [System.IO.Path]::GetFileNameWithoutExtension("$music_file")

ffmpeg -loop 1 -i "$image_file" `
    -i "$music_file" `
    -shortest `
    -acodec copy `
    "-c:v" libx264 -tune stillimage `
    -vf "scale=${dimensions}:force_original_aspect_ratio=decrease,pad=${dimensions}:-1:-1:color=black" `
    "${new_filename}.mp4"
