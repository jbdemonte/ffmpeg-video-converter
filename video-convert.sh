#!/bin/bash
set -e

# Video conversion script with FFmpeg
# High-quality encoding with x264/x265 and advanced options
# Version 1.0

VERSION="1.0"
#
# FFmpeg Analysis Configuration:
# - ANALYZEDURATION: Controls how much data FFmpeg reads to detect codecs
#   100M = ~several minutes of video data (vs default 5M = ~5 seconds)
#   Needed for complex codecs like TrueHD, DTS-HD that have delayed headers
#
# - PROBESIZE: Buffer size for analyzing file structure
#   100M buffer (vs default 5M) handles complex Blu-ray metadata
#   Reduces "Could not find codec parameters" warnings for audio tracks

# Initialize all option variables with defaults
quality=""
crf=""
preset="slow"
input=""
output=""
dryrun=false
keep_audio=false
no_subtitles=false
normalize_audio=false
max_size=""
target_bitrate=""
deinterlace=false
crop=false
audio_channels=""
audio_bitrate="384k"
audio_samplerate=""
resize=""
hdr_to_sdr=false
preview=false
colorspace=""
audio_delay=""
no_chapters=false
threads=""
priority="normal"
overwrite=false

# FFmpeg analysis parameters for complex files (Blu-ray remux)
# These values help FFmpeg properly detect codec parameters in large/complex files
ANALYZEDURATION="100M"  # How much data to analyze (default: 5M)
PROBESIZE="100M"        # Buffer size for analysis (default: 5M)

show_help() {
  echo ""
  echo "Usage: $0 --input input.mkv --output output.mkv [options]"
  echo ""
  echo "Options:"
  echo "  --audio-bitrate           Audio bitrate (default: 384k)"
  echo "  --audio-channels          Force audio channels (1=mono, 2=stereo, 6=5.1)"
  echo "  --audio-delay             Fix audio sync in ms (e.g. 150=delay, -200=advance)"
  echo "  --audio-samplerate        Audio sample rate (e.g. 48000, 44100)"
  echo "  --colorspace              Force colorspace: bt709 (HD standard), bt2020 (4K/HDR)"
  echo "  --crf                     Manual CRF value (overrides quality)"
  echo "  --crop                    Auto-detect and crop black bars"
  echo "  --deinterlace             Apply deinterlacing filter"
  echo "  --dry-run                 Show the ffmpeg command without executing"
  echo "  --hdr-to-sdr              Convert HDR to SDR with tonemapping"
  echo "  --help, -h                Show this help message"
  echo "  --input, -i               Path to input file"
  echo "  --keep-original-audio     Do not re-encode audio (copy)"
  echo "  --max-size                Maximum output file size (e.g. 2GB, 500MB)"
  echo "  --no-chapters             Do not include chapter markers"
  echo "  --no-subtitles            Do not include any subtitle tracks"
  echo "  --normalize-loudness      Normalize audio loudness to -14 LUFS"
  echo "  --output, -o              Path to output file"
  echo "  --overwrite               Overwrite output file without asking"
  echo "  --preview                 Encode only first 60 seconds for testing"
  echo "  --priority                CPU priority: normal, low (default: normal)"
  echo "  --quality                 Quality level: ultra(16), high(18), medium(22), low(28)"
  echo "  --resize                  Resize video (e.g. 1920x1080, 1280x720)"
  echo "  --speed                   Set encoder preset (e.g. slow, medium, fast...)"
  echo "  --target-bitrate          Target video bitrate instead of CRF (e.g. 5M, 2500k)"
  echo "  --threads                 Number of encoding threads (default: auto)"
  echo "  --version                 Show version information"
  echo ""
  exit 0
}

show_version() {
  echo "Video conversion script v$VERSION"
  echo "High-quality encoding with FFmpeg and x264/x265"
  echo ""
  echo "Dependencies:"
  ffmpeg -version 2>/dev/null | head -1 || echo "  ffmpeg: Not found"

  # Check x264 support in FFmpeg
  if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "libx264"; then
    echo "  libx264: Available"
  else
    echo "  libx264: Not found"
  fi

  # Check x265 as separate tool (x265 outputs to stderr, not stdout)
  if x265 --version >/dev/null 2>&1; then
    echo "  $(x265 --version 2>&1 | head -1)"
  else
    echo "  x265: Not found"
  fi

  exit 0
}

# Show help if no arguments provided
if [[ $# -eq 0 ]]; then
  show_help
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input|-i) input="$2"; shift 2 ;;
    --output|-o) output="$2"; shift 2 ;;
    --quality) quality="$2"; shift 2 ;;
    --crf) crf="$2"; shift 2 ;;
    --speed) preset="$2"; shift 2 ;;
    --keep-original-audio) keep_audio=true; shift ;;
    --no-subtitles) no_subtitles=true; shift ;;
    --normalize-loudness) normalize_audio=true; shift ;;
    --max-size) max_size="$2"; shift 2 ;;
    --target-bitrate) target_bitrate="$2"; shift 2 ;;
    --deinterlace) deinterlace=true; shift ;;
    --crop) crop=true; shift ;;
    --audio-channels) audio_channels="$2"; shift 2 ;;
    --audio-bitrate) audio_bitrate="$2"; shift 2 ;;
    --audio-samplerate) audio_samplerate="$2"; shift 2 ;;
    --resize) resize="$2"; shift 2 ;;
    --hdr-to-sdr) hdr_to_sdr=true; shift ;;
    --preview) preview=true; shift ;;
    --colorspace) colorspace="$2"; shift 2 ;;
    --audio-delay) audio_delay="$2"; shift 2 ;;
    --no-chapters) no_chapters=true; shift ;;
    --threads) threads="$2"; shift 2 ;;
    --priority) priority="$2"; shift 2 ;;
    --overwrite) overwrite=true; shift ;;
    --dry-run) dryrun=true; shift ;;
    --version) show_version ;;
    --help|-h) show_help ;;
    *) echo "Unknown option: $1"; show_help ;;
  esac
done

# Validate required arguments
if [[ -z "$input" || -z "$output" ]]; then
  echo "❌ Error: --input and --output are required"
  exit 1
fi

if [[ ! -f "$input" ]]; then
  echo "❌ Error: Input file not found: $input"
  exit 1
fi

# Check if output file exists and handle overwrite
if [[ -f "$output" && $overwrite == false ]]; then
  echo "❌ Error: Output file already exists: $output"
  echo "   Use --overwrite to replace it, or choose a different output file"
  exit 1
fi

# Set default CRF value based on quality level
if [[ -z "$crf" ]]; then
  case "$quality" in
    ultra) crf=16 ;;
    high|"") crf=18 ;;
    medium) crf=22 ;;
    low) crf=28 ;;
    *) echo "❌ Unknown quality level: $quality"; exit 1 ;;
  esac
fi

# Check for conflicting options and validate parameters
if [[ -n "$target_bitrate" && -n "$crf" && -n "$quality" ]]; then
  echo "⚠️  Warning: --target-bitrate overrides CRF/quality settings"
fi

# Validate priority option
if [[ "$priority" != "normal" && "$priority" != "low" ]]; then
  echo "❌ Error: --priority must be 'normal' or 'low'"
  exit 1
fi

# Convert max_size to bytes if specified
size_opts=""
if [[ -n "$max_size" ]]; then
  # Convert human-readable size to bytes
  case "${max_size^^}" in
    *GB) size_bytes=$(echo "${max_size%??}" | awk '{print $1 * 1024 * 1024 * 1024}') ;;
    *MB) size_bytes=$(echo "${max_size%??}" | awk '{print $1 * 1024 * 1024}') ;;
    *KB) size_bytes=$(echo "${max_size%??}" | awk '{print $1 * 1024}') ;;
    *B)  size_bytes=$(echo "${max_size%?}") ;;
    *)   size_bytes="$max_size" ;;  # Assume bytes if no unit
  esac
  size_opts="-fs $size_bytes"
  echo "⚠️  Warning: File size limit set to $max_size ($size_bytes bytes)"
  echo "   This may result in incomplete encoding if the limit is reached."
fi

# Interactive codec selection
# Ask user for preferred video codec
echo -e "\n🎞️ Encoder: available video codecs = h264 (libx264), h265 (libx265)"
echo
read -p "👉 Video codec [h265]: " video_codec
video_codec=${video_codec:-h265}
[[ "$video_codec" == "h265" ]] && video_encoder="libx265"
[[ "$video_codec" == "h264" ]] && video_encoder="libx264"

# Set default preset based on codec choice
if [[ -z "$preset" ]]; then
  [[ "$video_codec" == "h265" ]] && preset="slow"
  [[ "$video_codec" == "h264" ]] && preset="medium"
fi

# Initialize stream mapping with first video stream
# Map the first video stream from the first input (i.e. stream #0:0)
# This is the most common case: one video stream per input file
map_opts="-map 0:v:0"

echo "🔍 Scanning input file..."

# Audio track selection
echo
echo "🎧 Available audio tracks:"
ffprobe -v error -select_streams a \
  -show_entries stream=index,codec_name,channels:stream_tags=language,title \
  -of default=noprint_wrappers=1 "$input" | awk '
  BEGIN { count = 0 }
  /^index=/ { gsub("index=", ""); idx=$0; indexes[count++] = idx; lang[idx]=""; title[idx]=""; ch[idx]=""; codec[idx]="" }
  /^codec_name=/ { gsub("codec_name=", ""); codec[idx]=$0 }
  /^channels=/ { gsub("channels=", ""); ch[idx]=$0 }
  /^TAG:language=/ { gsub("TAG:language=", ""); lang[idx]=toupper($0) }
  /^TAG:title=/ { gsub("TAG:title=", ""); title[idx]=$0 }
  END {
    for (i=0; i<count; i++) for (j=i+1; j<count; j++) if (indexes[i] > indexes[j]) { tmp=indexes[i]; indexes[i]=indexes[j]; indexes[j]=tmp }
    for (i=0; i<count; i++) {
      id = indexes[i]
      printf "  [%s] lang: %s - title: %s - %s ch - codec: %s\n", id, lang[id], title[id], ch[id], codec[id]
    }
  }
'
echo
read -p "👉 Enter audio track indexes to keep (e.g., 1 2): " audio_indexes

# Convert comma-separated input to space-separated for processing
audio_indexes=$(echo "$audio_indexes" | tr ',' ' ')

# Show selected audio tracks and ask for encoding choice
if [[ -n "$audio_indexes" ]]; then
  # Ask for encoding choice only if not using --keep-original-audio
  if ! $keep_audio; then
    echo
    echo "🎵 Audio encoding options:"
    echo "  copy  - Keep original codec (DTS, TrueHD, etc.) - Best quality"
    echo "  ac3   - Dolby Digital - Universal compatibility"
    echo "  aac   - Advanced Audio Codec - Modern, efficient"
    echo "  mp3   - MPEG Audio Layer 3 - Compact"
    echo
    read -p "👉 Audio codec [copy]: " audio_codec
    audio_codec=${audio_codec:-copy}
  fi
fi

# Process selected audio tracks and build encoding options
if [[ -n "$audio_indexes" ]]; then
  audio_opts=""
  aid=0  # Audio stream counter
  for i in $audio_indexes; do
    map_opts+=" -map 0:$i"
    if $keep_audio || [[ "$audio_codec" == "copy" ]]; then
      # Copy audio without re-encoding
      audio_opts+=" -c:a:$aid copy"
    else
      # Configure audio encoding based on selected codec
      if [[ "$audio_codec" == "mp3" ]]; then
        audio_opts+=" -c:a:$aid libmp3lame -b:a:$aid $audio_bitrate"
      elif [[ "$audio_codec" == "aac" ]]; then
        audio_opts+=" -c:a:$aid aac -b:a:$aid $audio_bitrate"
      else
        # ac3 or other codec
        audio_opts+=" -c:a:$aid $audio_codec -b:a:$aid $audio_bitrate"
      fi

      # Apply audio channel configuration if specified
      if [[ -n "$audio_channels" ]]; then
        audio_opts+=" -ac:a:$aid $audio_channels"
      fi

      # Apply audio sample rate if specified
      if [[ -n "$audio_samplerate" ]]; then
        audio_opts+=" -ar:a:$aid $audio_samplerate"
      fi

      # Apply audio delay for sync correction if specified
      if [[ -n "$audio_delay" ]]; then
        audio_opts+=" -itsoffset ${audio_delay}ms"
      fi

      # Apply audio normalization if requested
      if [[ $normalize_audio == true ]]; then
        audio_opts+=" -af:a:$aid loudnorm=I=-14:TP=-1.5:LRA=11"
      fi
    fi
    aid=$((aid + 1))
  done
fi

# Subtitle track selection and processing
if [[ "$no_subtitles" == true ]]; then
  subtitle_opts=" -sn"  # Disable all subtitle streams
else
  echo
  echo "💬 Available subtitle tracks:"
  ffprobe -v error -select_streams s \
    -show_entries stream=index,codec_name,disposition:stream_tags=language,title,NUMBER_OF_BYTES \
    -of default=noprint_wrappers=1 "$input" | awk '
    BEGIN { count = 0 }
    /^index=/ {
      gsub("index=", "")
      idx = $0
      indexes[count++] = idx
      lang[idx]=""; title[idx]=""; size[idx]=""; codec[idx]=""; flags[idx]=""
    }
    /^codec_name=/ {
      gsub("codec_name=", "")
      c=$0
      kind = (c ~ /subrip|ssa|ass|text/) ? " (text)" : " (bitmap)"
      codec[idx] = c kind
    }
    /^disposition=/ {
      if ($0 ~ /forced=1/) flags[idx] = flags[idx]" (forced)"
      if ($0 ~ /default=1/) flags[idx] = flags[idx]" (default)"
      if ($0 ~ /hearing_impaired=1/) flags[idx] = flags[idx]" (hearing_impaired)"
    }
    /^TAG:language=/ { gsub("TAG:language=", ""); lang[idx]=toupper($0) }
    /^TAG:title=/    { gsub("TAG:title=", ""); title[idx]=$0 }
    /^TAG:NUMBER_OF_BYTES=/ {
      gsub("TAG:NUMBER_OF_BYTES=", "")
      size[idx] = sprintf("%.2f", $0 / 1048576)
    }
    END {
      for (i=0; i<count; i++) for (j=i+1; j<count; j++) if (indexes[i] > indexes[j]) { tmp=indexes[i]; indexes[i]=indexes[j]; indexes[j]=tmp }
      for (i=0; i<count; i++) {
        id = indexes[i]
        printf "  [%s] lang: %s - title: %s - size: %s MB - codec: %s%s\n", id, lang[id], title[id], size[id], codec[id], flags[id]
      }
    }
  '

  # User input for subtitle selection
  echo
  read -p "👉 Enter subtitle track indexes to keep (optional): " subtitle_indexes

  if [[ -z "$subtitle_indexes" ]]; then
    subtitle_opts=" -sn"  # No subtitles if none selected
  else
    subtitle_indexes=$(echo "$subtitle_indexes" | tr ',' ' ')  # Convert comma-separated to space-separated
    subtitle_opts=" -c:s copy"  # Copy subtitle streams without re-encoding
    for i in $subtitle_indexes; do
      map_opts+=" -map 0:$i"
    done
  fi
fi

# Build video filter chain
# Video filters are applied in the order they are added to the chain
video_filters=""

# Apply deinterlacing filter if requested (yadif = Yet Another Deinterlacing Filter)
if [[ $deinterlace == true ]]; then
  video_filters="yadif"
fi

# Apply automatic crop detection and cropping to remove black bars
if [[ $crop == true ]]; then
  if [[ -n "$video_filters" ]]; then
    video_filters+=",cropdetect,crop"
  else
    video_filters="cropdetect,crop"
  fi
fi

# Apply video resizing/scaling if specified
if [[ -n "$resize" ]]; then
  if [[ -n "$video_filters" ]]; then
    video_filters+=",scale=$resize"
  else
    video_filters="scale=$resize"
  fi
fi

# Apply HDR to SDR conversion with tone mapping
if [[ $hdr_to_sdr == true ]]; then
  # HDR to SDR conversion with tonemapping using Hable algorithm
  hdr_filter="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
  if [[ -n "$video_filters" ]]; then
    video_filters+=",${hdr_filter}"
  else
    video_filters="$hdr_filter"
  fi
fi

# Apply colorspace conversion if specified
if [[ -n "$colorspace" ]]; then
  case "$colorspace" in
    bt709)
      # Standard HD colorspace (Rec.709)
      colorspace_filter="colorspace=bt709:bt709:bt709"
      ;;
    bt2020)
      # Wide color gamut for 4K/HDR (Rec.2020)
      colorspace_filter="colorspace=bt2020nc:bt2020:smpte2084"
      ;;
    *)
      echo "❌ Unknown colorspace: $colorspace (use bt709 or bt2020)"
      exit 1
      ;;
  esac

  if [[ -n "$video_filters" ]]; then
    video_filters+=",${colorspace_filter}"
  else
    video_filters="$colorspace_filter"
  fi
fi

# Prepare filter options for FFmpeg command
filter_opts=""
if [[ -n "$video_filters" ]]; then
  filter_opts="-vf $video_filters"
fi

# Configure preview mode - encode only first 60 seconds for testing
preview_opts=""
if [[ $preview == true ]]; then
  preview_opts="-t 60"
  echo "🎬 Preview mode: encoding first 60 seconds only"
fi

# Display conversion summary before starting
echo
echo "🚀 Starting conversion:"
echo "  Input     : $input"
echo "  Output    : $output"
if [[ -n "$target_bitrate" ]]; then
  echo "  Bitrate   : $target_bitrate (target)"
else
  echo "  CRF       : $crf"
fi
echo "  Preset    : $preset"
echo "  Audio     : $audio_indexes ($([[ $keep_audio == true ]] && echo "copy" || echo "$audio_codec")$(if [[ "$audio_codec" != "copy" && $keep_audio == false ]]; then echo " @ $audio_bitrate"; fi))"
echo "  Subtitles : $subtitle_indexes"
[[ -n "$max_size" ]] && echo "  Max size  : $max_size"
[[ -n "$resize" ]] && echo "  Resize    : $resize"
[[ -n "$audio_channels" ]] && echo "  Audio ch  : $audio_channels"
[[ -n "$audio_samplerate" ]] && echo "  Audio rate: $audio_samplerate"
[[ $deinterlace == true ]] && echo "  Filters   : deinterlace"
[[ $crop == true ]] && echo "  Filters   : auto-crop"
[[ $hdr_to_sdr == true ]] && echo "  Filters   : HDR→SDR tonemapping"
[[ -n "$colorspace" ]] && echo "  Colorspace: $colorspace"
[[ -n "$audio_delay" ]] && echo "  Audio sync: ${audio_delay}ms delay"
[[ $no_chapters == true ]] && echo "  Chapters  : disabled"
[[ -n "$threads" ]] && echo "  Threads   : $threads"
[[ "$priority" == "low" ]] && echo "  Priority  : low CPU"
[[ $overwrite == true ]] && echo "  Overwrite : enabled"
[[ $preview == true ]] && echo "  Mode      : Preview (60s)"
echo

# Build video encoding options based on rate control method
if [[ -n "$target_bitrate" ]]; then
  # Use target bitrate (constant bitrate mode)
  video_opts="-c:v $video_encoder -preset \"$preset\" -b:v \"$target_bitrate\" -pix_fmt yuv420p10le"
else
  # Use CRF (constant rate factor for consistent quality)
  video_opts="-c:v $video_encoder -preset \"$preset\" -crf \"$crf\" -pix_fmt yuv420p10le"
fi

# Add thread control if specified
if [[ -n "$threads" ]]; then
  video_opts+=" -threads $threads"
fi

# Configure overwrite behavior
overwrite_opts=""
if [[ $overwrite == true ]]; then
  overwrite_opts="-y"  # Overwrite output files without asking
fi

# Configure chapter handling
chapter_opts=""
if [[ $no_chapters == false ]]; then
  chapter_opts="-map_chapters 0"  # Copy chapters from input
fi

# Build final FFmpeg command with proper option ordering
ffmpeg_cmd="ffmpeg $overwrite_opts -analyzeduration $ANALYZEDURATION -probesize $PROBESIZE -i \"$input\" \
  $preview_opts \
  $video_opts \
  $filter_opts \
  $audio_opts \
  $subtitle_opts \
  $map_opts \
  $chapter_opts \
  $size_opts \
  \"$output\""

# Apply CPU priority if set to low (uses 'nice' command)
if [[ "$priority" == "low" ]]; then
  cmd="nice -n 10 $ffmpeg_cmd"
else
  cmd="$ffmpeg_cmd"
fi

# Execute or display the command based on dry-run mode
if $dryrun; then
  echo "🧪 Dry-run mode enabled. The following command would be executed:"
  echo
  echo "$cmd"
else
  eval $cmd
fi
