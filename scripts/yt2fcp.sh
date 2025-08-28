#!/usr/bin/env zsh
# yt2fcp — Download highest-res YouTube video and produce an FCP-friendly file fast.
# Shows progress for both yt-dlp (download) and ffmpeg (encode).
#
# Usage:
#   yt2fcp <url> [--bitrate 16M] [--codec auto|h264|hevc|prores] [--outdir DIR] [--no-aria] [--no-hw]
# Examples:
#   yt2fcp "https://youtu.be/IdTMDpizis8"                       # auto bitrate by resolution, auto codec
#   yt2fcp "https://youtu.be/IdTMDpizis8" --bitrate 20M         # custom target bitrate
#   yt2fcp "https://youtu.be/IdTMDpizis8" --codec hevc          # force HEVC output (good for HDR/10-bit)
#   yt2fcp "https://youtu.be/IdTMDpizis8" --codec prores        # ProRes 422 (bigger, edits like butter)

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
die()  { echo "yt2fcp: $*" >&2; exit 1; }

usage() {
  sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# -------- Parse args --------
[[ $# -lt 1 ]] && usage

URL=""
VBITRATE_IN="auto"
CODEC="auto"      # auto | h264 | hevc | prores
OUTDIR="${YTDLP_OUTDIR:-$HOME/Downloads}"
USE_ARIA="yes"
USE_HW="yes"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage;;
    --bitrate) VBITRATE_IN="${2:-}"; shift 2;;
    --codec)   CODEC="${2:-}"; shift 2;;
    --outdir)  OUTDIR="${2:-}"; shift 2;;
    --no-aria) USE_ARIA="no"; shift;;
    --no-hw)   USE_HW="no"; shift;;
    http*://*|www.youtube.com/*|youtu.be/*) URL="$1"; shift;;
    *) die "unknown arg: $1";;
  esac
done

[[ -n "$URL" ]] || die "no URL provided"
have yt-dlp || die "missing yt-dlp"
have ffmpeg || die "missing ffmpeg"
have ffprobe || die "missing ffprobe"

mkdir -p "$OUTDIR"

# -------- Downloader accel (optional) --------
DL_ARGS=()
if [[ "$USE_ARIA" == "yes" ]] && have aria2c; then
  # aria2c prints its own live progress
  DL_ARGS+=(--downloader aria2c --downloader-args "aria2c:-x16 -s16 -k1M -j16 --summary-interval=1")
fi

# -------- Format selection (prefer M4A/AAC to avoid Opus issues) --------
FMT="bestvideo[height>=4320]+ba[ext=m4a]/\
bestvideo[height>=2160]+ba[ext=m4a]/\
bestvideo[height>=1440]+ba[ext=m4a]/\
bestvideo[height>=1080]+ba[ext=m4a]/\
bestvideo+bestaudio/best"

SAFE_TMPL="$OUTDIR/%(title).180B [%(id)s].%(ext)s"

# Compute the final merged filename *before* download so we don't have to capture stdout
BASENAME="$(yt-dlp --restrict-filenames --get-filename -o "%(title).180B [%(id)s]" "$URL" | tail -n 1)"
[[ -n "$BASENAME" ]] || die "failed to resolve output name"
OUTFILE="$OUTDIR/$BASENAME.mp4"

echo "▶ Downloading (yt-dlp) →"
yt-dlp "$URL" \
  -o "$SAFE_TMPL" \
  --no-playlist --restrict-filenames --trim-filenames 180 \
  -f "$FMT" --merge-output-format mp4 \
  --retries 10 --fragment-retries 10 --concurrent-fragments 10 \
  --progress --newline \
  "${DL_ARGS[@]}"

[[ -f "$OUTFILE" ]] || die "download/merge failed; not found: $OUTFILE"

# -------- Probe streams --------
probe_field() { ffprobe -v error -select_streams "$1" -show_entries "$2" -of default=nw=1:nk=1 "$OUTFILE" 2>/dev/null || true; }

VCODEC="$(probe_field v:0 stream=codec_name)"
ACODEC="$(probe_field a:0 stream=codec_name)"
PIXFMT="$(probe_field v:0 stream=pix_fmt)"
HEIGHT="$(probe_field v:0 stream=height)"
XFER="$(probe_field v:0 stream=color_transfer)"
[[ -z "$HEIGHT" ]] && HEIGHT=1080

# -------- Fast path: already H.264 + AAC MP4 → just faststart remux --------
if [[ "${CODEC}" == "auto" && "${VCODEC}" == "h264" && ( "${ACODEC}" == "aac" || "${ACODEC}" == "mp4a" ) ]]; then
  OUT="${OUTDIR}/${BASENAME}.faststart.mp4"
  echo "▶ Fast path: file already H.264+AAC. Optimizing container (ffmpeg)…"
  ffmpeg -hide_banner -stats -y -nostdin -i "$OUTFILE" \
    -map 0:v:0 -map 0:a:0 -c copy -movflags +faststart -shortest "$OUT"
  echo "✔ Done → $OUT"
  exit 0
fi

# -------- Choose output codec/encoder --------
lower() { print -r -- "${1:l}"; }
PIXL="$(lower "${PIXFMT:-}")"
XFERL="$(lower "${XFER:-}")"

IS_HDR="no"
if [[ "$PIXL" == *"10le"* || "$PIXL" == "p010le" || "$PIXL" == "yuv420p10le" || "$PIXL" == "yuv422p10le" || "$XFERL" == "smpte2084" || "$XFERL" == "arib-std-b67" ]]; then
  IS_HDR="yes"
fi

OUTEXT="h264.mp4"
VENC=()
if [[ "$CODEC" == "prores" ]]; then
  OUTEXT="prores.mov"
  if [[ "$USE_HW" == "yes" && "$(ffmpeg -hide_banner -encoders | grep -c prores_videotoolbox || true)" -gt 0 ]]; then
    VENC=( -c:v prores_videotoolbox -profile:v 3 -pix_fmt yuv422p10le )
  else
    VENC=( -c:v prores_ks -profile:v 3 -pix_fmt yuv422p10le )
  fi
elif [[ "$CODEC" == "hevc" || ( "$CODEC" == "auto" && "$IS_HDR" == "yes" ) ]]; then
  OUTEXT="hevc.mp4"
  if [[ "$USE_HW" == "yes" && "$(ffmpeg -hide_banner -encoders | grep -c hevc_videotoolbox || true)" -gt 0 ]]; then
    VENC=( -c:v hevc_videotoolbox -profile:v main10 -pix_fmt p010le -tag:v hvc1 )
  else
    VENC=( -c:v libx265 -pix_fmt yuv420p10le -tag:v hvc1 -preset medium )
  fi
else
  OUTEXT="h264.mp4"
  if [[ "$USE_HW" == "yes" && "$(ffmpeg -hide_banner -encoders | grep -c h264_videotoolbox || true)" -gt 0 ]]; then
    VENC=( -c:v h264_videotoolbox -pix_fmt yuv420p )
  else
    VENC=( -c:v libx264 -pix_fmt yuv420p -preset veryfast )
  fi
fi

# -------- Auto bitrate by resolution (VideoToolbox prefers target bitrate) --------
if [[ "$VBITRATE_IN" == "auto" ]]; then
  if   (( HEIGHT >= 4320 )); then VBITRATE="60M"
  elif (( HEIGHT >= 2160 )); then VBITRATE="40M"
  elif (( HEIGHT >= 1440 )); then VBITRATE="20M"
  elif (( HEIGHT >= 1080 )); then VBITRATE="14M"
  else                           VBITRATE="8M"
  fi
else
  VBITRATE="$VBITRATE_IN"
fi

# -------- Audio: copy AAC else transcode to AAC --------
AENC=()
if [[ "$ACODEC" == "aac" || "$ACODEC" == "mp4a" ]]; then
  AENC=( -c:a copy )
else
  AENC=( -c:a aac -b:a 192k )
fi

OUT="${OUTDIR}/${BASENAME}.${OUTEXT}"

echo "▶ Encoding to ${OUTEXT%%.*} (ffmpeg)…"
# -stats prints a live progress line; -err_detect ignore_err tolerates minor packet quirks.
ffmpeg -hide_banner -stats -y -nostdin -err_detect ignore_err -i "$OUTFILE" \
  -map 0:v:0 -map 0:a:0 \
  "${VENC[@]}" -b:v "$VBITRATE" -maxrate "$VBITRATE" -bufsize "$VBITRATE" \
  "${AENC[@]}" -movflags +faststart -shortest \
  "$OUT"

echo "✔ Done → $OUT"
