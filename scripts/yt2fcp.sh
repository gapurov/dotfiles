#!/usr/bin/env zsh
# yt2fcp — Download highest-res YouTube video and produce an FCP-friendly file fast.
# Shows progress for both yt-dlp (download) and ffmpeg (encode).
#
# Usage:
#   yt2fcp <url> [--bitrate 16M] [--codec auto|h264|hevc|prores] [--outdir DIR] [--no-aria] [--no-hw]
# Examples:
#   yt2fcp "https://youtu.be/example"                           # auto bitrate by resolution, auto codec
#   yt2fcp "https://youtu.be/example" --bitrate 20M             # custom target bitrate
#   yt2fcp "https://youtu.be/example" --codec hevc              # force HEVC output (good for HDR/10-bit)
#   yt2fcp "https://youtu.be/example" --codec prores            # ProRes 422 (bigger, edits like butter)

set -euo pipefail

# ============ CONFIGURATION CONSTANTS ============

# Resolution-based bitrate mapping
declare -A BITRATE_BY_RES=(
    [4320]="60M"  # 8K
    [2160]="40M"  # 4K
    [1440]="20M"  # 1440p
    [1080]="14M"  # 1080p
    [720]="8M"    # 720p and below
)

# Codec configurations
declare -A CODEC_CONFIGS=(
    ["h264"]="h264.mp4"
    ["hevc"]="hevc.mp4"
    ["prores"]="prores.mov"
)

# Encoder settings
readonly PRORES_PROFILE=3
readonly AUDIO_BITRATE="192k"
readonly FILENAME_TRIM_LENGTH=180

# FFmpeg settings
readonly FFMPEG_COMMON_ARGS=(-hide_banner -stats -y -nostdin -err_detect ignore_err)
readonly MOVFLAGS=(-movflags +faststart -shortest)

# yt-dlp settings
readonly ARIA2_ARGS=(-x16 -s16 -k1M -j16 --summary-interval=1)
readonly YTDLP_COMMON_ARGS=(--no-playlist --restrict-filenames --trim-filenames "$FILENAME_TRIM_LENGTH" --retries 10 --fragment-retries 10 --concurrent-fragments 10 --progress --newline)

# ============ UTILITY FUNCTIONS ============

have() { command -v "$1" >/dev/null 2>&1; }

log_info() { echo "ℹ $*" >&2; }
log_error() { echo "❌ yt2fcp: $*" >&2; }
log_success() { echo "✅ $*" >&2; }
log_progress() { echo "▶ $*" >&2; }

die() {
    log_error "$*"
    exit 1
}

warn() {
    log_info "Warning: $*"
}

# Validate required dependencies
check_dependencies() {
    local deps=("yt-dlp" "ffmpeg" "ffprobe" "jq")
    for dep in "${deps[@]}"; do
        have "$dep" || die "missing required dependency: $dep"
    done
}

# Validate and normalize bitrate input
validate_bitrate() {
    local bitrate="$1"
    [[ "$bitrate" =~ ^[0-9]+[kKmMgG]$ ]] || die "invalid bitrate format: $bitrate (expected format: 16M, 500k, etc.)"
    echo "$bitrate"
}

# Validate codec selection
validate_codec() {
    local codec="$1"
    [[ "$codec" =~ ^(auto|h264|hevc|prores)$ ]] || die "invalid codec: $codec (must be: auto, h264, hevc, or prores)"
    echo "$codec"
}

# Validate output directory
validate_outdir() {
    local outdir="$1"
    [[ -d "$outdir" ]] || mkdir -p "$outdir" 2>/dev/null || die "cannot create output directory: $outdir"
    [[ -w "$outdir" ]] || die "output directory not writable: $outdir"
    echo "$outdir"
}

usage() {
  # Extract usage information from the script header
  local script_path="$0"

  # Handle both absolute and relative paths
  if [[ "$script_path" != /* ]]; then
    script_path="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd)/$(basename "$script_path")"
  fi

  # Fallback if path resolution fails
  if [[ ! -f "$script_path" ]]; then
    cat << 'EOF'
yt2fcp — Download highest-res YouTube video and produce an FCP-friendly file fast.
Shows progress for both yt-dlp (download) and ffmpeg (encode).

Usage:
  yt2fcp <url> [--bitrate 16M] [--codec auto|h264|hevc|prores] [--outdir DIR] [--no-aria] [--no-hw]
Examples:
  yt2fcp "https://youtu.be/example"                           # auto bitrate by resolution, auto codec
  yt2fcp "https://youtu.be/example" --bitrate 20M             # custom target bitrate
  yt2fcp "https://youtu.be/example" --codec hevc              # force HEVC output (good for HDR/10-bit)
  yt2fcp "https://youtu.be/example" --codec prores            # ProRes 422 (bigger, edits like butter)
EOF
    exit 2
  fi

  sed -n '1,40p' "$script_path" | sed 's/^# \{0,1\}//'
  exit 2
}

# ============ ARGUMENT PARSING ============

parse_args() {
    [[ $# -lt 1 ]] && usage

    URL=""
    VBITRATE_IN="auto"
    CODEC="auto"
    OUTDIR="${YTDLP_OUTDIR:-$HOME/Downloads}"
    USE_ARIA="yes"
    USE_HW="yes"

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            -h|--help) usage;;
            --bitrate)
                VBITRATE_IN="$(validate_bitrate "${2:-}")"
                shift 2
                ;;
            --codec)
                CODEC="$(validate_codec "${2:-}")"
                shift 2
                ;;
            --outdir)
                OUTDIR="$(validate_outdir "${2:-}")"
                shift 2
                ;;
            --no-aria)
                USE_ARIA="no"
                shift
                ;;
            --no-hw)
                USE_HW="no"
                shift
                ;;
            http*://*|www.youtube.com/*|youtu.be/*)
                [[ -n "$URL" ]] && die "multiple URLs provided"
                URL="$1"
                shift
                ;;
            *)
                die "unknown argument: $1"
                ;;
        esac
    done

    [[ -n "$URL" ]] || die "no URL provided"
}

# ============ OPTIMIZED PROBE FUNCTION ============

# Single ffprobe call to get all needed metadata (performance optimization)
probe_video_metadata() {
    local input_file="$1"

    # Use ffprobe to get all metadata in one call
    local probe_output
    probe_output=$(ffprobe -v error \
        -select_streams v:0 -show_entries stream=codec_name,pix_fmt,height,color_transfer \
        -select_streams a:0 -show_entries stream=codec_name \
        -of json "$input_file" 2>/dev/null) || die "failed to probe video file"

    # Parse JSON and extract values
    VCODEC=$(echo "$probe_output" | jq -r '.streams[0].codec_name // empty' 2>/dev/null || echo "")
    PIXFMT=$(echo "$probe_output" | jq -r '.streams[0].pix_fmt // empty' 2>/dev/null || echo "")
    HEIGHT=$(echo "$probe_output" | jq -r '.streams[0].height // empty' 2>/dev/null || echo "1080")
    XFER=$(echo "$probe_output" | jq -r '.streams[0].color_transfer // empty' 2>/dev/null || echo "")
    ACODEC=$(echo "$probe_output" | jq -r '.streams[1].codec_name // empty' 2>/dev/null || echo "")

    # Set defaults if empty
    [[ -z "$HEIGHT" ]] && HEIGHT=1080
}

# ============ DOWNLOAD FUNCTIONS ============

setup_download_acceleration() {
    DL_ARGS=()
    if [[ "$USE_ARIA" == "yes" ]] && have aria2c; then
        DL_ARGS+=(--downloader aria2c --downloader-args "aria2c:${ARIA2_ARGS[*]}")
    fi
}

get_download_format() {
    # Prefer M4A/AAC to avoid Opus issues
    echo "bestvideo[height>=4320]+ba[ext=m4a]/bestvideo[height>=2160]+ba[ext=m4a]/bestvideo[height>=1440]+ba[ext=m4a]/bestvideo[height>=1080]+ba[ext=m4a]/bestvideo+bestaudio/best"
}

download_video() {
    local url="$1"
    local output_dir="$2"

    log_progress "Downloading video (yt-dlp) →"

    local fmt
    fmt="$(get_download_format)"
    local safe_tmpl="$output_dir/%(title).${FILENAME_TRIM_LENGTH}B [%(id)s].%(ext)s"

    # Get filename before download to avoid stdout capture
    BASENAME="$(yt-dlp --restrict-filenames --get-filename -o "%(title).${FILENAME_TRIM_LENGTH}B [%(id)s]" "$url" | tail -n 1)"
    [[ -n "$BASENAME" ]] || die "failed to resolve output name"

    OUTFILE="$output_dir/$BASENAME.mp4"

    yt-dlp "$url" \
        -o "$safe_tmpl" \
        "${YTDLP_COMMON_ARGS[@]}" \
        -f "$fmt" --merge-output-format mp4 \
        "${DL_ARGS[@]}"

    [[ -f "$OUTFILE" ]] || die "download/merge failed; not found: $OUTFILE"
}

# ============ CODEC SELECTION AND ENCODER FUNCTIONS ============

detect_hdr_content() {
    local pixfmt="$1"
    local xfer="$2"

    # Convert to lowercase for comparison
    local pixl="${pixfmt:l}"
    local xferl="${xfer:l}"

    # Check for HDR indicators
    if [[ "$pixl" == *"10le"* || "$pixl" == "p010le" || "$pixl" == "yuv420p10le" || "$pixl" == "yuv422p10le" ||
          "$xferl" == "smpte2084" || "$xferl" == "arib-std-b67" ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

select_video_encoder() {
    local codec="$1"
    local use_hw="$2"
    local is_hdr="$3"

    # Use global variables to return multiple values
    SELECTED_OUTEXT=""
    SELECTED_VENC_ARGS=()

    case "$codec" in
        "prores")
            SELECTED_OUTEXT="${CODEC_CONFIGS[prores]}"
            if [[ "$use_hw" == "yes" ]] && has_hw_encoder "prores_videotoolbox"; then
                SELECTED_VENC_ARGS=(-c:v prores_videotoolbox -profile:v "$PRORES_PROFILE" -pix_fmt yuv422p10le)
            else
                SELECTED_VENC_ARGS=(-c:v prores_ks -profile:v "$PRORES_PROFILE" -pix_fmt yuv422p10le)
            fi
            ;;
        "hevc"|auto)
            if [[ "$codec" == "auto" && "$is_hdr" == "yes" ]] || [[ "$codec" == "hevc" ]]; then
                SELECTED_OUTEXT="${CODEC_CONFIGS[hevc]}"
                if [[ "$use_hw" == "yes" ]] && has_hw_encoder "hevc_videotoolbox"; then
                    SELECTED_VENC_ARGS=(-c:v hevc_videotoolbox -profile:v main10 -pix_fmt p010le -tag:v hvc1)
                else
                    SELECTED_VENC_ARGS=(-c:v libx265 -pix_fmt yuv420p10le -tag:v hvc1 -preset medium)
                fi
            else
                # Fall back to H.264 for non-HDR content
                SELECTED_OUTEXT="${CODEC_CONFIGS[h264]}"
                if [[ "$use_hw" == "yes" ]] && has_hw_encoder "h264_videotoolbox"; then
                    SELECTED_VENC_ARGS=(-c:v h264_videotoolbox -pix_fmt yuv420p)
                else
                    SELECTED_VENC_ARGS=(-c:v libx264 -pix_fmt yuv420p -preset veryfast)
                fi
            fi
            ;;
        "h264")
            SELECTED_OUTEXT="${CODEC_CONFIGS[h264]}"
            if [[ "$use_hw" == "yes" ]] && has_hw_encoder "h264_videotoolbox"; then
                SELECTED_VENC_ARGS=(-c:v h264_videotoolbox -pix_fmt yuv420p)
            else
                SELECTED_VENC_ARGS=(-c:v libx264 -pix_fmt yuv420p -preset veryfast)
            fi
            ;;
        *)
            die "unsupported codec: $codec"
            ;;
    esac
}

has_hw_encoder() {
    local encoder="$1"
    ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "$encoder"
}

select_audio_encoder() {
    local acodec="$1"

    # Use global variables to return multiple values
    SELECTED_AENC_ARGS=()

    if [[ "$acodec" == "aac" || "$acodec" == "mp4a" ]]; then
        SELECTED_AENC_ARGS=(-c:a copy)
    else
        SELECTED_AENC_ARGS=(-c:a aac -b:a "$AUDIO_BITRATE")
    fi
}

get_auto_bitrate() {
    local height="$1"

    # Find the appropriate bitrate based on resolution
    # Sort resolutions in descending order for proper comparison
    local resolutions=("4320" "2160" "1440" "1080" "720")
    for res in "${resolutions[@]}"; do
        if (( height >= res )); then
            echo "${BITRATE_BY_RES[$res]}"
            return
        fi
    done

    # Default to 720p bitrate if height is less than all thresholds
    echo "${BITRATE_BY_RES[720]}"
}

# ============ FAST PATH OPTIMIZATION ============

try_fast_path() {
    local codec="$1"
    local vcodec="$2"
    local acodec="$3"
    local basename="$4"
    local outfile="$5"
    local outdir="$6"

    # Fast path: already H.264 + AAC MP4 → just faststart remux
    if [[ "$codec" == "auto" && "$vcodec" == "h264" && ( "$acodec" == "aac" || "$acodec" == "mp4a" ) ]]; then
        local out="${outdir}/${basename}.faststart.mp4"
        log_progress "Fast path: file already H.264+AAC. Optimizing container (ffmpeg)…"

        ffmpeg "${FFMPEG_COMMON_ARGS[@]}" -i "$outfile" \
            -map 0:v:0 -map 0:a:0 -c copy "${MOVFLAGS[@]}" "$out"

        log_success "Done → $out"
        exit 0
    fi
}

# ============ ENCODING FUNCTION ============

encode_video() {
    local outfile="$1"
    local basename="$2"
    local outdir="$3"
    local codec="$4"
    local vbitrate_in="$5"
    local use_hw="$6"

    # Detect HDR content
    local is_hdr
    is_hdr="$(detect_hdr_content "$PIXFMT" "$XFER")"

    # Select encoders (sets global variables)
    select_video_encoder "$codec" "$use_hw" "$is_hdr"
    select_audio_encoder "$ACODEC"

    # Determine bitrate
    local vbitrate
    if [[ "$vbitrate_in" == "auto" ]]; then
        vbitrate="$(get_auto_bitrate "$HEIGHT")"
    else
        vbitrate="$vbitrate_in"
    fi

    # Set output filename
    local out="${outdir}/${basename}.${SELECTED_OUTEXT}"

    log_progress "Encoding to ${SELECTED_OUTEXT%%.*} (ffmpeg)…"

    # Perform encoding
    ffmpeg "${FFMPEG_COMMON_ARGS[@]}" -i "$outfile" \
        -map 0:v:0 -map 0:a:0 \
        "${SELECTED_VENC_ARGS[@]}" -b:v "$vbitrate" -maxrate "$vbitrate" -bufsize "$vbitrate" \
        "${SELECTED_AENC_ARGS[@]}" "${MOVFLAGS[@]}" \
        "$out"

    log_success "Done → $out"
}

# ============ MAIN EXECUTION ============

main() {
    # Parse command line arguments
    parse_args "$@"

    # Validate environment
    check_dependencies

    # Setup download acceleration
    setup_download_acceleration

    # Download video
    download_video "$URL" "$OUTDIR"

    # Probe video metadata (single optimized call)
    probe_video_metadata "$OUTFILE"

    # Try fast path optimization
    try_fast_path "$CODEC" "$VCODEC" "$ACODEC" "$BASENAME" "$OUTFILE" "$OUTDIR"

    # Encode video
    encode_video "$OUTFILE" "$BASENAME" "$OUTDIR" "$CODEC" "$VBITRATE_IN" "$USE_HW"
}

# Run main function
main "$@"
