# scan <output.pdf|-> -- batch-scan the loaded ADF stack into a single PDF.
# Runs on `print`, where the ScanSnap iX1300 lives. With `-` as the target the
# PDF is written to stdout (so a remote caller can stream it straight into a
# local file); otherwise to the named file (.pdf appended if missing). Duplex /
# colour / 300dpi by default; override with SCAN_SOURCE / SCAN_MODE /
# SCAN_RESOLUTION. All status goes to stderr so stdout carries only the PDF. PNG
# pages are lossless and the smallest thing scanimage writes directly; img2pdf
# embeds them without recompression.

log() { printf 'scan: %s\n' "$*" >&2; } # all status to stderr; stdout is the PDF

if [[ $# -ne 1 || $1 == -h || $1 == --help ]]; then
  echo "usage: scan <output.pdf|->" >&2
  exit 2
fi

out=$1
if [[ $out != - ]]; then
  [[ $out == *.pdf ]] || out=$out.pdf
fi

source=${SCAN_SOURCE:-ADF Duplex}
mode=${SCAN_MODE:-Color}
resolution=${SCAN_RESOLUTION:-300}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --batch pulls every sheet in the feeder, then ends with NO_DOCS (exit 7) once
# it empties -- that's the normal terminator, not a failure. So accept 0 and 7,
# and decide success by whether any pages actually landed.
rc=0
scanimage \
  --source "$source" \
  --mode "$mode" \
  --resolution "$resolution" \
  --format=png \
  --batch="$work/page-%04d.png" || rc=$?

if (( rc != 0 && rc != 7 )); then
  log "scanimage failed (exit $rc)"
  exit "$rc"
fi

shopt -s nullglob
pages=("$work"/page-*.png)
if (( ${#pages[@]} == 0 )); then
  log "no pages scanned -- is paper loaded in the feeder?"
  exit 1
fi

# img2pdf writes the PDF to stdout when --output is omitted.
if [[ $out == - ]]; then
  img2pdf "${pages[@]}"
  log "streamed ${#pages[@]} page(s)"
else
  img2pdf "${pages[@]}" --output "$out"
  log "wrote $out (${#pages[@]} page(s))"
fi
