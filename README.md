# Powershell FFMPEG Scripts

Requires ffmpeg.exe (and ffprobe.exe) in your PATH.

## Installation

Download the script bundle from releases. Or...

### mise

These scripts are distributed as GitHub release archives, one per push to `main`.
Install the latest release with [mise](https://mise.jdx.dev) using the `github:`
backend:

```sh
mise use -g "github:moshen/powershell-ffmpeg-scripts"
```

This downloads the release archive, which contains a `bin/` directory, and adds
that directory to your PATH so the scripts are directly invokable, e.g.:

```sh
convert-to-mp3.ps1 some-file.wav
```

If your `mise.toml` pins a specific version, the equivalent config is:

```toml
[tools."github:moshen/powershell-ffmpeg-scripts"]
version = "latest"
asset_pattern = "powershell-ffmpeg-scripts-{{ version }}.zip"
bin_path = "bin"
```

Use `mise ls-remote github:moshen/powershell-ffmpeg-scripts` to see available
versions. A specific version can be installed with
`mise use -g "github:moshen/powershell-ffmpeg-scripts@<version>"`.

### Manual

Download the zip of master and copy the scripts from `bin/` into a folder in
your PATH.

## Scripts

- `convert-to-mp3.ps1` — convert audio/video to MP3
- `convert-to-m4a.ps1` — convert audio/video to AAC/M4A
- `convert-to-music-video.ps1` — combine an image and music into an MP4
- `convert-to-dnxhd.ps1` — convert to DNxHD (for DaVinci Resolve)
- `convert-to-two-pass-h264.ps1` — two-pass H.264 encode (auto-detects NVENC/QSV/AMF)
- `convert-to-two-pass-hevc.ps1` — two-pass HEVC encode (auto-detects NVENC/QSV/AMF)
- `convert-to-two-pass-av1.ps1` — two-pass AV1 encode (auto-detects NVENC/QSV/AMF)
- `convert-for-discord.ps1` — encode a clip to fit under Discord's size limit
- `drag-here-to-convert-for-discord.ps1` — drop files onto a shortcut to run `convert-for-discord.ps1`
- `create-copy-of-file-with-metadata-comment.ps1` — embed a text comment into media metadata
- `get-video-encoder.ps1` — picks the encoder the two-pass scripts use

### Saving the detected encoder

The two-pass scripts test which hardware encoder works each time
they run. To detect once and reuse the result, run:

```powershell
get-video-encoder.ps1 -SaveDefaults
```

This saves the choice for each codec to
`%LOCALAPPDATA%\powershell-ffmpeg-scripts\video-encoders.json`. Run it again
after changing your GPU, drivers or ffmpeg build, or delete that file to go
back to detecting on every run.