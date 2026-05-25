#!/usr/bin/env python3
"""
Extract KKL songs from a PDF into JSON for Flutter asset import.

Usage:
  python tools/extract_kkl_pdf.py \
    --pdf "/absolute/path/KAMTE LII FULL FILE (14-11-2019).pdf" \
    --out assets/data/songs.json

Notes:
- Requires `pypdf` in a virtualenv.
- This parser uses heuristics. Review generated JSON before shipping.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from pypdf import PdfReader


def normalize_space(text: str) -> str:
  return re.sub(r"[ \t]+", " ", text).strip()


def clean_title(raw_title: str) -> str:
  title = normalize_space(raw_title)
  if "." in title:
    title = title.split(".", 1)[0]
  if "(" in title:
    title = title.split("(", 1)[0]
  return normalize_space(title).strip(' "\'')


def format_lyrics(lines: list[str]) -> str:
  # Preserve the PDF's lyric line layout. Titles/details are parsed separately,
  # so this only affects the visible lyric body.
  formatted_lines: list[str] = []
  previous_blank = False
  for raw_line in lines:
    line = raw_line.rstrip()
    if not line:
      if formatted_lines and not previous_blank:
        formatted_lines.append("")
      previous_blank = True
      continue

    normalized_line = normalize_space(line)
    if formatted_lines and not previous_blank:
      if is_verse_line(normalized_line) or _starts_unnumbered_section(
        normalized_line,
        formatted_lines,
      ):
        formatted_lines.append("")

    formatted_lines.append(line)
    previous_blank = False

  return "\n".join(formatted_lines).strip()


def _starts_unnumbered_section(line: str, formatted_lines: list[str]) -> bool:
  if is_verse_line(line):
    return False

  previous_line = next((l.strip() for l in reversed(formatted_lines) if l.strip()), "")
  if not previous_line:
    return False

  # Refrains/choruses in the PDF often begin as an unnumbered line after a
  # complete sentence, while wrapped lyric lines usually follow commas.
  if not re.search(r"[.!?]\s*(?:[\"')\]]+)?$", previous_line):
    return False

  if re.match(r"^(S\.?P\.?|Alto:|Ten,|Tenor:|Bass:|Chorus:?|Refrain:?)\b", line, re.IGNORECASE):
    return True

  return bool(re.match(r"^[“\"'()]?[A-Z]", line))


def _split_inline_verses(text: str) -> list[str]:
  matches = list(re.finditer(r"(?<!\d)(\d{1,3}[.)]\s+)", text))
  if len(matches) < 2:
    return [text]

  starts = [m.start() for m in matches]
  segments: list[str] = []
  for i, start in enumerate(starts):
    end = starts[i + 1] if i + 1 < len(starts) else len(text)
    segment = text[start:end].strip()
    if segment:
      segments.append(segment)
  return segments or [text]


def format_special_song_lyrics(lines: list[str]) -> str:
  return format_lyrics(lines)


def format_details(lines: list[str]) -> str:
  cleaned = [normalize_space(line) for line in lines if normalize_space(line)]
  return "\n".join(cleaned).strip()


def _alpha_ratio(text: str) -> tuple[int, int]:
  letters = [c for c in text if c.isalpha()]
  if not letters:
    return (0, 0)
  lower = sum(1 for c in letters if c.islower())
  return (lower, len(letters))

def _upper_ratio(text: str) -> tuple[int, int]:
  letters = [c for c in text if c.isalpha()]
  if not letters:
    return (0, 0)
  upper = sum(1 for c in letters if c.isupper())
  return (upper, len(letters))

def is_song_header(line: str) -> bool:
  match = re.match(r"^(\d{1,4})[.)]?\s*(.+)$", line)
  if not match:
    return False
  number = int(match.group(1))
  if number <= 0 or number > 999:
    return False
  rest = match.group(2)
  if rest.lstrip().startswith(":"):
    return False
  if is_verse_line(line):
    return False

  # Skip year/author lines like "1913. WILLIAM ..."
  if number >= 1000:
    if re.search(r"\b(17|18|19|20)\d{2}\b", rest):
      return False
    if re.search(r"\b(REV|PS|KEY|S\.?\s?S|C\.?\s?W|TUNE|HYMN|SONG)\b", rest) is None:
      return False

  lower, total = _alpha_ratio(rest)
  upper, _ = _upper_ratio(rest)
  if total == 0:
    return False
  # Strong signal: mostly uppercase or known header tokens.
  if (upper / total) >= 0.6:
    return True
  if re.search(r"\b(REV|PS|KEY|S\.?\s?S|C\.?\s?W|TUNE|HYMN|SONG)\b", rest, re.IGNORECASE):
    return True
  if re.search(r"\b[A-Za-z]{1,4}\.?\s*\d{1,3}\s*:\s*\d{1,3}\b", rest):
    return True
  if re.search(r"\([A-Za-z. ]{1,8}\s*\d{1,4}\)", rest):
    return True
  # Allow some lowercase in titles; verses are filtered above.
  return (lower / total) <= 0.25


def is_verse_line(line: str) -> bool:
  match = re.match(r"^\d{1,3}[.)]\s+(.+)$", line)
  if not match:
    return False
  rest = match.group(1)
  lower, total = _alpha_ratio(rest)
  upper, _ = _upper_ratio(rest)
  if total == 0:
    return False
  return (lower / total) > 0.3 and (upper / total) < 0.6


def split_song_blocks(full_text: str) -> list[str]:
  # Typical headings: "101 TITLE" or "101. TITLE". Keep original line breaks in blocks.
  raw_lines = full_text.splitlines()
  starts: list[int] = []
  for i, raw_line in enumerate(raw_lines):
    line = raw_line.strip()
    if line and is_song_header(line):
      starts.append(i)

  if not starts:
    return [full_text.strip()]

  blocks: list[str] = []
  for idx, start in enumerate(starts):
    end = starts[idx + 1] if idx + 1 < len(starts) else len(raw_lines)
    blocks.append("\n".join(raw_lines[start:end]).strip())
  return blocks


def parse_song_block(
  block: str,
  topic_map: dict[str, str],
) -> dict[str, str] | None:
  raw_rows = block.splitlines()
  header_index = next((i for i, row in enumerate(raw_rows) if row.strip()), None)
  if header_index is None:
    return None

  header = normalize_space(raw_rows[header_index])
  match = re.match(r"^(\d{1,4})[.)]?\s*(.*)$", header)
  if not match:
    return None

  number = match.group(1)
  header_text = normalize_space(match.group(2))
  title = clean_title(header_text)
  inline_details = header_text[len(title):].strip() if title and header_text.startswith(title) else ''

  body_rows = raw_rows[header_index + 1 :]

  verse_start = None
  for idx, line in enumerate(body_rows):
    if is_verse_line(normalize_space(line)):
      verse_start = idx
      break

  details_lines: list[str] = []
  if inline_details:
    details_lines.append(inline_details)
  if verse_start is not None:
    details_lines.extend(body_rows[:verse_start])

  if verse_start is None:
    lyrics_lines = body_rows
  else:
    lyrics_lines = body_rows[verse_start:]

  details = format_details(details_lines)
  lyrics = (
    format_special_song_lyrics(lyrics_lines)
    if 497 <= int(number) <= 507
    else format_lyrics(lyrics_lines)
  )

  # Topic heuristic: use topical index mapping, then bracketed marker, then keywords.
  topic = topic_map.get(number)
  if not topic:
    topic_match = re.search(r"\[(.*?)\]", block)
    topic = normalize_space(topic_match.group(1)) if topic_match else None
  if not topic:
    topic = infer_topic(title, lyrics)

  return {
    "kkl_number": number,
    "title": title or f"Song {number}",
    "details": details,
    "lyrics": lyrics,
    "topic": topic or "General",
  }


def infer_topic(title: str, lyrics: str) -> str:
  text = f"{title} {lyrics}".lower()
  if any(k in text for k in ("cross", "calvary", "blood", "crucified", "redeemer")):
    return "Salvation"
  if any(k in text for k in ("prayer", "pray", "kneel", "supplication")):
    return "Prayer"
  if any(k in text for k in ("holy spirit", "spirit", "anoint", "comforter")):
    return "Holy Spirit"
  if any(k in text for k in ("mission", "send", "harvest", "evangel", "nations")):
    return "Mission"
  if any(k in text for k in ("grace", "faith", "trust", "believe")):
    return "Faith"
  if any(k in text for k in ("christmas", "bethlehem", "manger", "born")):
    return "Christmas"
  if any(k in text for k in ("resurrection", "risen", "easter")):
    return "Resurrection"
  if any(k in text for k in ("heaven", "home", "glory", "eternal")):
    return "Heaven"
  if any(k in text for k in ("thank", "praise", "worship", "hallelujah")):
    return "Praise"
  return "General"


def extract(pdf_path: Path) -> list[dict[str, str]]:
  reader = PdfReader(str(pdf_path))
  text_parts: list[str] = []

  for page in reader.pages:
    text = page.extract_text() or ""
    if text.strip():
      text_parts.append(text)

  full_text = "\n".join(text_parts)
  topic_map = parse_topical_index(full_text)
  blocks = split_song_blocks(full_text)

  songs: list[dict[str, str]] = []
  seen_numbers: set[str] = set()

  for block in blocks:
    song = parse_song_block(block, topic_map)
    if not song:
      continue
    if song["kkl_number"] in seen_numbers:
      continue
    seen_numbers.add(song["kkl_number"])
    songs.append(song)

  songs.sort(key=lambda s: int(s["kkl_number"]))
  return songs


def parse_topical_index(full_text: str) -> dict[str, str]:
  lines = [normalize_space(l) for l in full_text.splitlines()]
  start_idx = None
  for i, line in enumerate(lines):
    if re.search(r"(topical|topic).{0,12}index", line, re.IGNORECASE):
      start_idx = i + 1
      break

  if start_idx is None:
    return {}

  topic_map: dict[str, str] = {}
  current_topic: str | None = None
  for line in lines[start_idx:]:
    if not line:
      continue

    # Stop if another major index starts.
    if re.search(r"(index of|tunes|authors)", line, re.IGNORECASE):
      break

    cleaned = re.sub(r"[.•]+", " ", line).strip()
    numbers = re.findall(r"\d{1,4}", cleaned)
    letters_only = re.sub(r"[^A-Za-z &/-]", "", cleaned).strip()

    if numbers and letters_only:
      current_topic = letters_only
      for num in numbers:
        topic_map[num] = current_topic
      continue

    if numbers and current_topic:
      for num in numbers:
        topic_map[num] = current_topic
      continue

    if letters_only and not numbers:
      current_topic = letters_only

  return topic_map


def main() -> None:
  parser = argparse.ArgumentParser()
  parser.add_argument("--pdf", required=True, type=Path)
  parser.add_argument("--out", required=True, type=Path)
  args = parser.parse_args()

  if not args.pdf.exists():
    raise SystemExit(f"PDF not found: {args.pdf}")

  songs = extract(args.pdf)
  if not songs:
    raise SystemExit("No songs detected. Adjust parser heuristics.")

  args.out.parent.mkdir(parents=True, exist_ok=True)
  args.out.write_text(json.dumps(songs, ensure_ascii=False, indent=2), encoding="utf-8")
  print(f"Wrote {len(songs)} songs to {args.out}")


if __name__ == "__main__":
  main()
