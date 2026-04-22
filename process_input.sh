#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INPUT_DIR="$SCRIPT_DIR/input"
OUTPUT_DIR="$SCRIPT_DIR/output"
FORCE=0

usage() {
  cat <<'EOF'
Usage: ./process_input.sh [--force] [--input DIR] [--output DIR]

Processes every PDF under input/ and writes Markdown to output/, preserving
the input folder structure. Existing Markdown files are skipped unless --force
is provided.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --input)
      INPUT_DIR="${2:?Missing value for --input}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:?Missing value for --output}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$SCRIPT_DIR/.venv/bin/activate" ]]; then
  echo "Virtual environment not found at $SCRIPT_DIR/.venv" >&2
  echo "Create it first with: python3 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt" >&2
  exit 1
fi

source "$SCRIPT_DIR/.venv/bin/activate"

python - "$INPUT_DIR" "$OUTPUT_DIR" "$FORCE" <<'PY'
from pathlib import Path
import sys

input_dir = Path(sys.argv[1]).expanduser().resolve()
output_dir = Path(sys.argv[2]).expanduser().resolve()
force = sys.argv[3] == "1"

if not input_dir.is_dir():
    raise SystemExit(f"Input directory does not exist: {input_dir}")

pdf_paths = sorted(
    path
    for path in input_dir.rglob("*")
    if path.is_file() and path.suffix.lower() == ".pdf"
)

if not pdf_paths:
    print(f"No PDF files found under {input_dir}")
    raise SystemExit(0)

output_dir.mkdir(parents=True, exist_ok=True)

from extract import MarkdownPDFExtractor, config

processed = 0
skipped = 0
failed = 0

for pdf_path in pdf_paths:
    relative_path = pdf_path.relative_to(input_dir)
    markdown_path = output_dir / relative_path.with_suffix(".md")

    if markdown_path.exists() and not force:
        skipped += 1
        print(f"SKIP  {relative_path}", flush=True)
        continue

    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    config["OUTPUT_DIR"] = str(markdown_path.parent)

    print(f"RUN   {relative_path}", flush=True)
    extractor = MarkdownPDFExtractor(str(pdf_path))
    extractor.extract()

    produced_path = markdown_path.parent / f"{pdf_path.stem}.md"
    if produced_path != markdown_path and produced_path.exists():
        produced_path.replace(markdown_path)

    if markdown_path.exists():
        processed += 1
        print(
            f"DONE  {relative_path} -> {markdown_path.relative_to(output_dir)}",
            flush=True,
        )
    else:
        failed += 1
        print(f"FAIL  {relative_path}", file=sys.stderr, flush=True)

print()
print(f"Processed: {processed}")
print(f"Skipped:   {skipped}")
print(f"Failed:    {failed}")

if failed:
    raise SystemExit(1)
PY
