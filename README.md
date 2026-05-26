# Little Sorter

A calm, ad-free drag-and-sort game for toddlers (ages 2–5). Drag each thing to where it belongs — a cow to the barn, a duck to the pond, a boat onto the water — rewarded with soft chimes, gentle animations, and friendly encouragement. Never a buzzer or a harsh "wrong." Built for Apple's Kids Category.

<p align="center">
  <img src="screenshots/main_menu_frame.png" width="240" />
  <img src="screenshots/farm_level_frame.png" width="240" />
  <img src="screenshots/ocean_level_frame.png" width="240" />
</p>
<p align="center">
  <img src="screenshots/star_level_frame.png" width="240" />
  <img src="screenshots/parent_settings_frame.png" width="240" />
  <img src="screenshots/parent_gate_frame.png" width="240" />
</p>

## Features

- **Six playful worlds** — Farm, Ocean, Town, Jungle, Vehicles, and Garden. Farm and Ocean are free; the other four unlock with a single one-time purchase (no subscriptions).
- **Forgiving, mistake-proof play** — a wrong drop just floats back with a soft nudge; nothing punishes a small child.
- **Spoken item names** for pre-readers, fully on-device.
- **Themed celebrations** — a particle burst tuned per zone (splash, feathers, leaves, petals, and more) plus per-world music.
- **Optional Challenge Mode** — a gentle 30-second timer with 1–3 star rewards. Off by default, and only reachable by a grown-up behind a parental gate.
- **Privacy-first** — no ads, no tracking, no accounts, no analytics, no networking. Collects zero data.

## Built with

- SwiftUI (iOS 17.6+), portrait, iPhone
- StoreKit 2 for the one-time non-consumable unlock
- AVFoundation — runtime-synthesized tones, on-device speech, and looping background music
- Persistence via `@AppStorage` (UserDefaults)
- No third-party dependencies

## Project structure

- `LittleSorterApp.swift` — app entry + the menu/gameplay state machine
- `Models.swift` — the six worlds, zones, items, and content validation
- `GameView.swift` — drag-and-sort gameplay, timer, celebration
- `LevelPickerView.swift` — the world picker
- `GrownUpsView.swift` / `ParentalGate.swift` / `PaywallView.swift` — the adult-only area
- `Store.swift` — StoreKit 2 wrapper
- `DropEffectView.swift` / `ConfettiView.swift` — asset-free particle effects
- `ToneManager.swift` / `SpeechManager.swift` / `MusicManager.swift` — audio

## Running it

1. Open `LittleSorter.xcodeproj` in Xcode 26+.
2. Select the `LittleSorter` scheme and an iPhone simulator or device.
3. Build & run (`⌘R`). The bundled `Products.storekit` config lets you test the purchase and restore flows locally without App Store Connect.

## Privacy

Little Sorter collects no data, contains no advertising, makes no network requests, and never asks a child to make a purchase. All progress is stored only on the device.

---

© 2026 Ethan Irimiciuc. All rights reserved.
