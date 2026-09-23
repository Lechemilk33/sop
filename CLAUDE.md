# My Story: notes for contributors

A SwiftUI + SwiftData iPhone app (iOS 26+) for a man with early-stage Alzheimer's to record his life stories. PLAN.md explains every design decision and the research behind it. Read it before changing anything he sees.

## Rules for his screens (non-negotiable)

These come from dementia research; don't trade them away for convenience.

- At most three or four main choices per screen; one main thing to do.
- Every tappable thing uses `BigButton`, `NavPill`, `TappableRow` or `PersonChip`, all of which go through `TapGuard` (ignores double taps, gives a haptic). Main buttons are 88–136 pt tall; nothing is under 64 pt.
- Taps only. No swipe, long-press, double-tap, drag or pinch gestures, and no swipe-back navigation. Navigation is `Router` (push, pop, go home).
- Every screen uses `ScreenScaffold`: Home in the top-right corner, labeled back button, main actions pinned at the bottom. The recording screen deliberately has no Home button.
- Colors only from `Palette`/`Tone`. Dark text on cream, light mode only. Text ≥ 7:1 contrast, tappable outlines ≥ 3:1. The three places (brick = Tell, blue = People, marigold = Life) differ in lightness.
- Text only through `.appFont(...)`. Nothing smaller than 20 pt on his side. Styles scale with Dynamic Type and the family's text size.
- Every icon sits next to a word. People are shown with real photos, their name and "My daughter"-style relationship.
- No timers, auto-advance, pop-ups, badges, streaks or scores. Nothing he taps can delete anything; deleting and editing live in the family area.
- Questions invite ("Tell me about…"), never quiz ("Do you remember…?"). `QuestionBankTests.noQuestionQuizzes` enforces this.
- The recording is the story. Transcripts are only for reading along; never generate, summarize or rewrite his words or photos.

## Data

- Models are CloudKit-safe: every property has a default, every relationship is optional, inverses are declared on one side only, no unique constraints. Keep it that way; iCloud sync is switched on with the `MYSTORY_ICLOUD_SYNC` build setting.
- Big blobs (audio, photos) use `@Attribute(.externalStorage)`.
- Built-in chapter and question keys in `QuestionBank` must never change once shipped.

## Checking changes

- Xcode: ⌘B, then ⌘U.
- Without a Mac, the Foundation-only files (`Support/Formatting.swift`, `Services/Questions/QuestionPicker.swift`, `Persistence/QuestionBank.swift`, `Services/Export/FileNaming.swift`, `ArchiveManifest.swift`, `ArchiveHTML.swift`) and their tests build with a Linux Swift toolchain. Put them in a Swift package whose library target is named `MyStory`, then run `swift test`. Every file should at least pass `swiftc -parse`.
