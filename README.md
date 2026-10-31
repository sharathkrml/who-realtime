# Who Realtime

A macOS app that listens to a meeting on your Mac and turns it into a speaker-attributed transcript — **entirely on device**. While it records, you watch the transcript stream in; every couple of minutes the speakers get named (Speaker 1, Speaker 2…). When you stop, a timestamped Markdown doc lands in `~/Documents/Meetings`, with the WAV recording next to it and editable speaker names.

One library (`Sources/WhoRealtime`), two flavors of the app:

- **Desktop** — `Who Realtime.app`: a regular Dock app. Record in the main pane, and every meeting already in `~/Documents/Meetings` is listed in the sidebar — click one to read it, copy the Markdown, or send it (and its recording) to the Trash. ⌘R toggles listening from anywhere.
- **Menu bar** — `Who Realtime Menu Bar.app`, popover in the waveform menu bar item (no Dock icon). The icon flips to a record circle while a session is active.

Both share one model cache (`~/Library/Application Support/WhoRealtime/Models`), so the models download once per Mac.

## The models

Both run offline on the Neural Engine via [desert-ant-core](https://github.com/Desert-Ant-Labs/desert-ant-core):

- [**Voz**](https://desertant.com/models/voz/) — speech recognition with word timestamps. Streams text live with its built-in `LiveTranscriber`.
- [**Who**](https://desertant.com/models/who/) — speaker labeling. Re-diaryzes the growing recording every 2 minutes (and once fully at the end), then words are matched to the best-overlapping speaker turn.

One-time download of both models (~550 MB from Hugging Face) happens on first launch; after that everything is offline.

## Modes

- **On this Mac** — taps the chosen meeting app's audio (Zoom / Meet / Teams / browser, via a Core Audio process tap) **and** your microphone, mixed onto one timeline. Your own voice is in the doc too. The first tap triggers a system consent prompt; mic access gets the standard mic permission.
- **In a room** — records with the Mac's microphone only. Put the Mac at the table.

## Build & run

```sh
swift build            # or: scripts/make-app.sh
scripts/make-app.sh    # two app bundles: build/"WhoRealtime.app" + build/"Who Realtime Menu Bar.app"
open build/WhoRealtime.app
```

The desktop app opens as a normal window with the meeting list in the sidebar; the menu bar app lives behind the waveform icon → Listen. Recordings and docs go to `~/Documents/Meetings`. Speech recognition covers the model's 25 languages (English among them); tests: `swift test`.

## Layout

```
Sources/WhoTapCore      ObjC shim: CATapDescription process-tap creation
Sources/WhoRealtime     shared library: capture, attribution, doc, views
Sources/WhoRealtime/Views  SwiftUI surfaces: design tokens (glass on macOS 26), flow, transcript with live level meters, chimes/haptics
Sources/WhoMenuBar      menu bar entry point (MenuBarExtra)
Sources/WhoWindowed     desktop entry point: sidebar of past meetings + the record flow
Tests/                  attribution + doc + level-meter tests
scripts/make-icon.swift draws build/WhoRealtime.icns (no asset catalog)
```
