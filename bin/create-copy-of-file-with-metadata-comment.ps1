# This script was created to include large comments from as text file within
# media file metadata. Mainly because programs like mp3tag do not properly
# store the newlines in the comment.
#
# This is specifically useful for including tracklists

param ($music_file, $comment_text_file)

if ([string]::IsNullOrEmpty($music_file)) {
    Write-Output "No filename argument provided for the music"
    exit
}

if ([string]::IsNullOrEmpty($comment_text_file)) {
    Write-Output "No filename argument provided for the image"
    exit
}

if (-Not (Test-Path -Path "$music_file")) {
    Write-Output "$music_file does not exist"
    exit
}

if (-Not (Test-Path -Path "$comment_text_file")) {
    Write-Output "$comment_text_file does not exist"
    exit
}

$comment = [IO.File]::ReadAllText("$(Resolve-Path "$comment_text_file")")
$new_filename = [System.IO.Path]::GetFileNameWithoutExtension("$music_file")
$extension = [System.IO.Path]::GetExtension("$music_file")

ffmpeg -i "$music_file" `
    -c copy `
    -metadata comment="$comment" `
    "${new_filename}-new-metadata${extension}"
