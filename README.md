# Video Conversion Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)
![FFmpeg](https://img.shields.io/badge/requires-FFmpeg-orange.svg)

High-quality video encoding with [FFmpeg](https://ffmpeg.org/) and x264/x265 codecs.

## Features

- **Interactive codec selection** - Choose between H.264 (x264) and H.265 (x265)
- **Flexible audio handling** - Copy original codecs (DTS, TrueHD) or re-encode (AC3, AAC, MP3)
- **Advanced video filters** - Auto-crop, deinterlacing, HDR→SDR conversion, resizing
- **Quality control** - CRF-based encoding or target bitrate
- **Subtitle support** - Copy subtitle tracks with automatic detection
- **Preview mode** - Test settings with 60-second samples
- **System optimization** - Thread control and CPU priority management

## Requirements

- **FFmpeg** with libx264 support
- **x265** encoder (for HEVC encoding)
- **Bash** shell

## Installation

### Download the script:
```bash
curl -L -O https://github.com/jbdemonte/ffmpeg-video-converter/raw/main/video-convert.sh
chmod +x video-convert.sh
```

### Install dependencies:

#### macOS (Homebrew)
```bash
brew install ffmpeg x265
```

#### Ubuntu/Debian
```bash
sudo apt install ffmpeg x265
```

#### Check installation
```bash
./video-convert.sh --version
```

#### **Optional: Add to PATH for global access**

##### Option 1: Copy to /usr/local/bin (requires sudo)
```bash
sudo cp video-convert.sh /usr/local/bin/
video-convert.sh --version  # Now available globally
```

##### Option 2: Add to your personal bin directory
```bash
mkdir -p ~/bin
cp video-convert.sh ~/bin/
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc for zsh
source ~/.bashrc  # Reload shell configuration
```

##### Option 3: Create symlink in PATH
```bash
sudo ln -s /path/to/video-convert.sh /usr/local/bin/video-convert
```

##### Verify global installation
```bash
which video-convert.sh
```

## Basic Usage

```bash
# Interactive mode (recommended for beginners)
video-convert.sh --input movie.mkv --output movie_x265.mkv

# Quick conversion with defaults
video-convert.sh -i input.mkv -o output.mkv --overwrite

# Preview mode for testing settings
video-convert.sh -i input.mkv -o test.mkv --preview

# If not added to PATH, use relative path
./video-convert.sh --input movie.mkv --output movie_x265.mkv
```

## Command Line Options

### Required Options
- `--input, -i` - Path to input video file
- `--output, -o` - Path to output video file

### Video Quality
- `--quality` - Quality preset: `ultra(16)`, `high(18)`, `medium(22)`, `low(28)`
- `--crf` - Manual CRF value (overrides quality presets)
- `--target-bitrate` - Target video bitrate instead of CRF (e.g., `5M`, `2500k`)
- `--speed` - Encoder preset: `slow`, `medium`, `fast`, etc.

### Audio Options
- `--keep-original-audio` - Copy all audio tracks without re-encoding
- `--audio-channels` - Force audio channels (`1`=mono, `2`=stereo, `6`=5.1)
- `--audio-bitrate` - Audio bitrate for re-encoding (default: `384k`)
- `--audio-samplerate` - Audio sample rate (e.g., `48000`, `44100`)
- `--audio-delay` - Fix audio sync in milliseconds (`150`=delay, `-200`=advance)
- `--normalize-loudness` - Normalize audio to -14 LUFS

### Video Filters
- `--crop` - Auto-detect and remove black bars
- `--deinterlace` - Apply deinterlacing filter
- `--resize` - Resize video (e.g., `1920x1080`, `1280x720`)
- `--hdr-to-sdr` - Convert HDR to SDR with tone mapping
- `--colorspace` - Force colorspace: `bt709` (HD) or `bt2020` (4K/HDR)

### Subtitle Options
- `--no-subtitles` - Exclude all subtitle tracks
- `--no-chapters` - Exclude chapter markers

### System Options
- `--threads` - Number of encoding threads (default: auto)
- `--priority` - CPU priority: `normal` or `low`
- `--max-size` - Maximum output file size (e.g., `2GB`, `500MB`)

### Utility Options
- `--preview` - Encode only first 60 seconds for testing
- `--overwrite` - Overwrite output file without asking
- `--dry-run` - Show FFmpeg command without executing
- `--version` - Show version and dependency information
- `--help, -h` - Show help message

## Usage Examples

### High-Quality Archival
```bash
# Keep original audio quality (DTS, TrueHD)
video-convert.sh -i bluray.mkv -o archive.mkv \
  --quality ultra --keep-original-audio
```

### Space-Efficient Conversion
```bash
# Re-encode audio to AC3 for smaller file size
video-convert.sh -i input.mkv -o output.mkv \
  --quality medium --max-size 2GB
```

### HDR Content Processing
```bash
# Convert HDR to SDR with automatic cropping
video-convert.sh -i hdr_movie.mkv -o sdr_movie.mkv \
  --hdr-to-sdr --crop --colorspace bt709
```

### Batch Processing Preparation
```bash
# Test settings with preview mode
video-convert.sh -i sample.mkv -o test.mkv \
  --preview --quality high --dry-run
```

### System-Friendly Encoding
```bash
# Low priority background encoding
video-convert.sh -i large_file.mkv -o output.mkv \
  --priority low --threads 6
```

## Interactive Workflow

The script provides an interactive interface for selecting:

1. **Video codec** - H.264 or H.265
2. **Audio tracks** - View available tracks with language/codec info
3. **Audio encoding** - Copy original or re-encode to AC3/AAC/MP3
4. **Subtitle tracks** - Select which subtitles to include

Example session:
```
🎞️ Encoder: available video codecs = h264 (libx264), h265 (libx265)
👉 Video codec [h265]: 

🎧 Available audio tracks:
  [1] lang: FRE - title: VFQ - 6 ch - codec: eac3
  [2] lang: FRE - title: VFF - 8 ch - codec: dts
  [3] lang: ENG - title: ENG - 8 ch - codec: truehd
👉 Enter audio track indexes to keep (e.g., 1 2): 2,3

🎵 Audio encoding options:
  copy  - Keep original codec (DTS, TrueHD, etc.) - Best quality
  ac3   - Dolby Digital - Universal compatibility
  aac   - Advanced Audio Codec - Modern, efficient
  mp3   - MPEG Audio Layer 3 - Compact
👉 Audio codec [copy]: 
```

## Audio Codec Recommendations

### For High-End Audio Systems
- **copy** - Preserves original quality (DTS, TrueHD, DTS-HD)
- Best for home theater setups with capable AV receivers

### For Universal Compatibility
- **ac3** - Dolby Digital, works on all devices
- Good compromise between quality and compatibility

### For Modern Devices/Streaming
- **aac** - Advanced Audio Codec, efficient compression
- Preferred for mobile devices and streaming platforms

### For Maximum Compression
- **mp3** - Smallest file sizes
- Use only when storage is extremely limited

## Performance Tips

### Encoding Speed
- Use `--speed fast` for quicker encoding (larger files)
- Use `--speed slow` for better compression (smaller files)
- Adjust `--threads` based on your CPU cores

### Quality vs File Size
- **CRF 16-18** - Visually lossless quality
- **CRF 20-22** - High quality, good for archival
- **CRF 24-26** - Good quality for streaming
- **CRF 28+** - Lower quality, very small files

### System Resources
- Use `--priority low` for background encoding
- Limit threads with `--threads` to keep system responsive
- Use `--preview` to test settings before long encodes

## Troubleshooting

### Common Issues

**"Could not find codec parameters" warnings**
- These are normal for complex Blu-ray files
- The script uses optimized analysis parameters to minimize them

**Audio sync problems**
- Use `--audio-delay` to fix sync issues
- Test with `--preview` mode first

**Large file sizes**
- Increase CRF value for smaller files
- Consider re-encoding audio instead of copying
- Use `--max-size` to enforce size limits

### Dependency Issues

Check dependencies:
```bash
video-convert.sh --version
# Or if not in PATH:
./video-convert.sh --version
```

Install missing components:
```bash
# macOS
brew install ffmpeg x265

# Linux
sudo apt install ffmpeg x265
```

## Technical Details

### FFmpeg Configuration
- **Analysis Duration**: 100MB (vs 5MB default) for complex codecs
- **Probe Size**: 100MB buffer for large file metadata
- **Pixel Format**: yuv420p10le for x265 (10-bit encoding)

### Supported Input Formats
- Matroska (MKV)
- MP4
- AVI
- MOV
- Any format supported by FFmpeg

### Output Format
- Matroska (MKV) container
- Preserves metadata, chapters, and multiple streams

## License

This script is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues and enhancement requests!
