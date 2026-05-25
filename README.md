# Kamatei Lii

A real-world app designed for a Christian community from Manipur, Kamatei Lii is built to preserve language, worship songs, and shared faith in a form that is easy to carry and use every day.

The goal is simple and meaningful: make these songs accessible offline, searchable in seconds, and readable for everyone.

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

## App architecture

Kamatei Lii follows a simple feature-first Flutter structure. The app is intentionally offline-first: the PDF is not parsed on the phone. Instead, the lyrics are prepared ahead of time, bundled as JSON, and then loaded locally by the app.

At a high level:

```text
PDF source files
      |
      v
Python extractor
      |
      v
Bundled JSON assets
      |
      v
Flutter app
      |
      v
Local SQLite / in-memory JSON / SharedPreferences
```

The main book, `Kamatei Lii`, is imported from `assets/data/songs.json` into SQLite during app startup. A SHA-256 hash is stored in the local database, so when the bundled JSON changes in a new app version, the app can automatically re-import the updated lyrics without asking the user to press a manual refresh button.

Search is handled through the repository layer. Song number and title matching are ranked first, while lyrics search uses SQLite FTS when the device supports it. If FTS is unavailable on a device, the app falls back to normal SQLite `LIKE` search so the app still works offline.

`Tam Kamatoi Lii` is smaller, so it is loaded directly from `assets/data/tam_kamatoi_lii.json`. Its bookmarks are stored separately in `SharedPreferences`, while the main book bookmarks are stored in SQLite.

State is managed with Riverpod:

- providers expose database, repository, search, topic, bookmark, and font-size state
- search providers use `autoDispose` where useful so old search queries do not stay cached forever
- UI pages stay mostly focused on rendering and navigation

The UI is split by feature:

- `home` handles global search across both books
- `songs` handles song lists and the main lyrics reader
- `tam_kamatoi` handles the separate Tam Kamatoi lyrics section
- `bookmarks` combines saved songs from both books
- `topics` shows the topical index and topic-based song lists

This keeps the app easy to maintain: PDF parsing stays in `tools`, data lives in `assets`, persistence stays in `lib/core`, and screens live under `lib/features`.

## Code architecture

The codebase is kept small and direct. The main idea is to separate app setup, shared logic, persistence, and UI features so each part has one clear job.

```text
kamatei_lii/
|
|-- lib/
|   |-- main.dart                  # App entry point
|   |-- app.dart                   # Material app, theme, navigation shell
|   |
|   |-- core/
|   |   |-- database/
|   |   |   |-- database_helper.dart   # SQLite setup, import, search, bookmarks
|   |   |   `-- song_repository.dart   # Clean API over database queries
|   |   |
|   |   |-- models/
|   |   |   |-- song.dart              # Main Kamatei Lii song model
|   |   |   `-- topic_group.dart       # Topical index model
|   |   |
|   |   `-- providers.dart             # Riverpod providers and shared app state
|   |
|   `-- features/
|       |-- home/
|       |   `-- home_page.dart         # Global search across KL and TL
|       |
|       |-- songs/
|       |   |-- song_list_page.dart    # Main song list/search results
|       |   `-- song_detail_page.dart  # Lyrics reader, bookmark, font size, swipe
|       |
|       |-- tam_kamatoi/
|       |   |-- tam_kamatoi_page.dart  # Tam Kamatoi Lii list and reader
|       |   `-- tam_song.dart          # Tam Kamatoi data model
|       |
|       |-- bookmarks/
|       |   `-- bookmarks_page.dart    # Saved KL and TL songs
|       |
|       `-- topics/
|           |-- topics_page.dart       # Topical index categories
|           `-- topic_songs_page.dart  # Songs inside a selected topic
|
|-- assets/
|   |-- data/
|   |   |-- songs.json                # Main Kamatei Lii lyrics
|   |   |-- tam_kamatoi_lii.json      # Tam Kamatoi Lii lyrics
|   |   `-- topic_index.json          # Topical index data
|   |
|   `-- images/
|       `-- logo.jpg                  # App logo
|
`-- tools/
    `-- extract_kkl_pdf.py            # PDF-to-JSON extraction script
```

### Entry point and app shell

- `lib/main.dart` starts Flutter and attaches Riverpod.
- `lib/app.dart` defines the Material app, theme, and bottom navigation.

### Core layer

- `database_helper.dart` owns SQLite setup, table creation, bundled JSON import, dataset hash checking, bookmarks, and search queries.
- `song_repository.dart` provides a cleaner API over the database so UI code does not talk to SQL directly.
- `song.dart` and `topic_group.dart` describe the main app data models.
- `providers.dart` wires the app together with Riverpod providers for database access, search results, bookmarks, topics, font size, and Tam Kamatoi data.

### Feature layer

- `home_page.dart` handles global search across both books.
- `song_list_page.dart` shows Kamatei Lii song results and lists.
- `song_detail_page.dart` renders lyrics, metadata, font-size controls, bookmarking, and next/previous swipe navigation.
- `tam_kamatoi_page.dart` handles the separate Tam Kamatoi Lii reader, including TL numbering, bookmarks, font size, and swipe navigation.
- `bookmarks_page.dart` combines saved songs from both books in one place.
- `topics_page.dart` and `topic_songs_page.dart` handle the topical index flow.

### Data and tooling

- `assets/data/songs.json` is the main Kamatei Lii dataset.
- `assets/data/tam_kamatoi_lii.json` is the Tam Kamatoi Lii dataset.
- `assets/data/topic_index.json` stores the topical index.
- `tools/extract_kkl_pdf.py` converts edited PDF files into app-ready JSON while preserving lyric formatting as closely as possible.

This structure keeps the mobile app lightweight: the heavy PDF cleanup work happens before release, while the installed app only reads local JSON and SQLite data.

## Run locally

```bash
cd "/kamatei_lii"
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

## Project layout

- `lib/core` -> database, providers, models
- `lib/features` -> home, songs, tam kamatoi, bookmarks, topics
- `tools` -> PDF extraction scripts
- `assets/data` -> bundled lyric datasets and topic index

## A practical note

PDF formatting is not always consistent, so extraction uses heuristics. If a song looks wrong, update parser rules in `tools/extract_kkl_pdf.py`, regenerate JSON, and recheck in app.
