# This script was written to ease converting game clips for Discord
#
# It does a two pass h264 encoding to attempt to maximize quality
# This script will also break when passed $start_time over 1 minute as it will
# attempt to determine the duration in seconds only

param(
    [System.IO.FileInfo]$input_file,
    [System.IO.FileInfo]$output_file,
    [float]$start_time = 0, # Start time in seconds (seek to)
    [float]$total_time = 0, # Total duration in seconds (snipping your clip)
    [string]$filters = "",
    [string]$resolution = "1080",
    [int]$audio_bitrate = 100,
    [float]$target_size = 20, # My math must be off because 20mb doesn't work sometimes
    [boolean]$full_size_copy = 0,
    [System.IO.DirectoryInfo]$full_size_path = '.\full\'
)

$max_size = $target_size; # In MB
$output_path = "${output_file}.mp4"

if (Test-Path -LiteralPath $output_path) {
    if ((Get-Item -LiteralPath $output_path).Length -eq 0) {
        # An empty file is left over from an ffmpeg run that failed
        Remove-Item -Force -LiteralPath $output_path
    } else {
        Write-Output "$output_path already exists, delete it to convert again"
        exit
    }
}

$params = @()

if ($start_time -gt 0) {
    $params = $params + @(
        "-ss"
        "$start_time"
    )
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
    '-c:v'
    'copy'
    '-c:a'
    'copy'
)

$full_output_file = [System.IO.Path]::Combine($full_size_path, [System.IO.Path]::GetFileName($output_file))
$input_file_ext = [System.IO.Path]::GetExtension($input_file)

if ($full_size_copy)
{
    ffmpeg.exe @params `
        "${full_output_file}.${input_file_ext}"
}

# Let's see if a full size copy is smaller than 10mb first
if (($input_file_ext -eq ".mp4") -and [string]::IsNullOrEmpty($filters))
{
    ffmpeg.exe @params `
        "$output_path"
}

while ($true) {
    if (Test-Path -LiteralPath $output_path) {
        $size = (Get-Item -LiteralPath $output_path).Length

        if (($size -gt 0) -and (($size / 1MB) -le $max_size)) {
            break
        }

        Remove-Item -Force -LiteralPath $output_path

        # Too big rather than empty, so aim a little lower next time
        if ($size -gt 0) {
            $target_size = $target_size - .5;
        }
    }

    & "$PSScriptRoot\convert-to-two-pass-h264.ps1" `
    -input_file "$input_file" `
    -output_file "$output_file" `
    -start_time "$start_time" `
    -total_time "$total_time" `
    -filters "$filters" `
    -resolution "$resolution" `
    -audio_bitrate "$audio_bitrate" `
    -target_size "$target_size"

    # A failed encode leaves no file (or an empty one). Stop rather than
    # retrying the same failing command forever.
    if ((-Not (Test-Path -LiteralPath $output_path)) -or ((Get-Item -LiteralPath $output_path).Length -eq 0)) {
        Remove-Item -Force -LiteralPath $output_path -ErrorAction SilentlyContinue
        Write-Error "Encoding failed, see the output above"
        exit 1
    }
}
