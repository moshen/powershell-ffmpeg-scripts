[CmdletBinding()]
param (
    [Parameter(ValueFromRemainingArguments=$true)]
    $Path
)

$scriptRoot = $PSScriptRoot

foreach ($aPath in $Path) {
    $dirName = [System.IO.Path]::GetDirectoryName($aPath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($aPath)
    $fileNameWext = [System.IO.Path]::GetFileName($aPath)
    Push-Location -LiteralPath "$dirName"
    & "$scriptRoot\convert-for-discord.ps1" -input_file "$fileNameWext" -output_file "${fileName}-for-discord"
    Pop-Location
}

Write-Host -NoNewLine 'Press any key to close...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')