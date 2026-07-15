# scan <output.pdf> -- scan on `print` and stream the PDF back to this machine.
# The scanner is USB-attached to `print`, so scanimage + img2pdf run there; we
# ask for the PDF on stdout (`scan -`) and redirect it into a local file. Nothing
# is left on print. Override the target with SCAN_HOST (e.g. an ssh alias) if
# print.lan isn't it.

log() { printf 'scan: %s\n' "$*" >&2; }

if [[ $# -ne 1 || $1 == -h || $1 == --help ]]; then
  echo "usage: scan <output.pdf>" >&2
  exit 2
fi

out=$1
[[ $out == *.pdf ]] || out=$out.pdf

host=${SCAN_HOST:-print.lan}

# Stream into a sibling .part and commit with an atomic rename, so a failed or
# empty scan never truncates/clobbers an existing PDF or leaves a 0-byte file.
tmp=$out.part
trap 'rm -f "$tmp"' EXIT
ssh "$host" scan - >"$tmp"
mv "$tmp" "$out"
log "wrote $out (scanned on $host)"
