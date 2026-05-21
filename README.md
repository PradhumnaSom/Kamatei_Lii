# Kamatei Lii

A real-world app designed for a Christian community from Manipur, Kamatei Lii is built to preserve language, worship songs, and shared faith in a form that is easy to carry and use every day.

At its heart, this app is not just a song finder. It reflects community memory: songs learned in fellowship, voices raised together in prayer, and the cultural identity carried through lyrics across generations. The goal is simple and meaningful: make these songs accessible offline, searchable in seconds, and readable for everyone.

This project started from a practical need: make it easy to find and read songs quickly during fellowship, without depending on internet. It now includes two books in one app:

- `Kamatei Lii` (main book, song numbers shown as `KL`)
- `Tam Kamatoi Lii` (song numbers shown as `TL`)

Everything runs locally on device, including search.
        [Soon Publishing on Playstore & App Store]
## What the app does

- Search songs by number, title, or lyrics
- Global search across both books
- Full-text search in SQLite for fast results
- Bookmark songs
- Browse songs by topical index
- Adjust font size while reading
- Swipe left/right to move to next/previous song
- Open songs completely offline

## Tech stack

- Flutter (Dart)
- Riverpod for state management
- SQLite (`sqflite`) for local storage
- Local JSON assets as source data
- Python PDF extractor (`tools/extract_kkl_pdf.py`)

## Data flow (PDF -> App)

1. Lyrics are extracted from PDF into JSON.
2. JSON files are bundled in `assets/data`.
3. On app startup, JSON is imported to local SQLite.
4. Search, bookmarks, and topic browsing read from local DB/assets.

Main data files:

- `assets/data/songs.json`
- `assets/data/tam_kamatoi_lii.json`
- `assets/data/topic_index.json`

## Run locally

```bash
cd "/Users/pradhumna/Documents/New project/kamatei_lii"
flutter pub get
flutter run
```

## Update lyrics from PDF

Use the extractor script when source PDFs are updated:

```bash
python3 tools/extract_kkl_pdf.py \
  --pdf "/absolute/path/New.pdf" \
  --out assets/data/songs.json

python3 tools/extract_kkl_pdf.py \
  --pdf "/absolute/path/TAM KAMATOI LII.pdf" \
  --out assets/data/tam_kamatoi_lii.json
```

Then restart the app so updated data is imported.

## Android release (Play Store)

1. Create signing config file:
```bash
cp android/key.properties.example android/key.properties
```

2. Fill `android/key.properties` with real values.
3. Build release AAB:
```bash
flutter build appbundle --release
```

4. Upload:
`build/app/outputs/bundle/release/app-release.aab`

## Project layout

- `lib/core` -> database, providers, models
- `lib/features` -> home, songs, tam kamatoi, bookmarks, topics
- `tools` -> PDF extraction scripts
- `assets/data` -> bundled lyric datasets and topic index

## A practical note

PDF formatting is not always consistent, so extraction uses heuristics. If a song looks wrong, update parser rules in `tools/extract_kkl_pdf.py`, regenerate JSON, and recheck in app.
