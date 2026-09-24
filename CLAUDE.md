# My Story: notes for contributors

A SwiftUI + SwiftData iPhone app (iOS 26+) for a man with early-stage Alzheimer's to record his life stories. PLAN.md explains every design decision and the research behind it. Read it before changing anything he sees.

## Rules for his screens (non-negotiable)

These come from dementia research; don't trade them away for convenience.

- At most three or four main choices per screen; one main thing to do.
- Every tappable thing uses `BigButton`, `PlaceTile`, `NavPill`, `TappableRow`, `PersonCard` or the small choice tiles built the same way, all of which go through `TapGuard` (ignores double taps, gives a haptic). Main buttons are 88–136 pt tall; nothing is under 64 pt. People shown on a story (`PersonBadge`) and medallions are not tappable.
- Taps only. No swipe, long-press, double-tap, drag or pinch gestures, and no swipe-back navigation. Navigation is `Router` (push, pop, go home).
- Every screen uses `ScreenScaffold`: Home in the top-right corner, labeled back button, main actions pinned at the bottom (at accessibility text sizes they scroll with the content instead). Content fits on one screen without scrolling whenever it can. The recording screen deliberately has no Home button, and recording never stops on its own because of silence.
- A list row that opens a screen calls `router.remember(id)` first and carries `.id(id)`, so coming back shows the same place, not the top.
- Colors only from `Palette`/`Tone`. Dark text on a warm light background, light mode only. Text ≥ 7:1 contrast, tappable edges ≥ 3:1. The three places (brick = Tell, blue = People, marigold = Stories) differ in lightness. `RootView` sets `placeTone` from `Screen.place`, which tints the background glow.
- Liquid Glass only on controls (buttons, Home's tiles, the top bar, the code pad): colored glass always sits on the solid tone color (so white words keep 7:1), frosted glass always has a 2 pt edge, and glass is never `.interactive()` (it would bounce; pressing only darkens). Content (rows, cards, photos) is solid, not glass. Home's tiles also carry a solid stripe of the place's color, so the places differ in lightness at a glance.
- Every screen is one `ScrollView` that only scrolls when content doesn't fit. Don't swap between a plain and a scrolling copy with `ViewThatFits` on screens with a text field: the field would lose the keyboard.
- Text only through `.appFont(...)`. Nothing smaller than 20 pt on his side. Styles scale with Dynamic Type and the family's text size, and switch to Atkinson Hyperlegible with "Extra-clear letters".
- Every icon sits next to a word. People are shown with real photos framed around the face (`thumbnailData` is a face-framed square; `photoData` is the whole photo), their name and "My daughter"-style relationship. Other photos are shown whole with `WholePhoto`, never cropped.
- No timers, auto-advance, pop-ups, badges, streaks or scores. Nothing he taps can delete anything. He can name, sort and add people to stories and make chapters (Features/Organize); deleting lives only in the family area.
- A screen that goes back somewhere other than the previous screen says so with `ScreenScaffold(back: BackAction(...))`.
- Questions invite ("Tell me about…"), never quiz ("Do you remember…?", "What was the name…", "What's the very first…"), and never ask about the last few days, which fade first. `QuestionBankTests` enforces this for built-in questions and person prompts.
- The recording is the story. Transcripts are only for reading along; never generate, summarize or rewrite his words or photos.

## Data

- Models are CloudKit-safe: every property has a default, every relationship is optional, inverses are declared on one side only, no unique constraints. Keep it that way; iCloud sync is switched on with the `MYSTORY_ICLOUD_SYNC` build setting.
- Big blobs (audio, photos) use `@Attribute(.externalStorage)`.
- Chapters he or the family make have an empty `key`; built-in chapter and question keys in `QuestionBank` must never change once shipped. Each question's key is written out by hand, never worked out from its position, so questions can be reworded, added or reordered safely.
- When sync creates duplicates, `Seeder` keeps the copy with the smallest `uuid`, the same choice on every device. Every story always belongs to a chapter (loose ones go to More stories).
- Anything that holds a model across an `await` must look it up again afterwards, because the family may have deleted it in the meantime (see `TranscriptionService`). Lists that play or copy many records keep IDs, not models, and skip ones that are gone.
- Never delete a recording automatically unless it is certainly shorter than a second and a half. A recording that can't be stored is kept on disk and rescued later (`RecordingRecovery`). Each story recording has a `RecordingNote` beside it (same name, `.json`) with its name, question, chapter, photo and people; remove it together with the recording.
- The models in `MyStorySchemaV1` are the live classes. Before changing any model once he has data, freeze a copy of today's models as V1, make the change in a V2, and add a migration stage to `MyStoryMigrationPlan`.
- Family editors never delete a model that's still on screen: they set `deleteWhenGone`, dismiss, and delete in `.onDisappear`.

## Audio, background and the screen

- Keep the screen on only through `ScreenAwake` (recording, playing, saving a copy); never set `isIdleTimerDisabled` directly.
- Anything that must finish if the phone locks runs inside a `BackgroundActivity`, begun before the microphone or the sound stops. It ends itself when time runs out; cancel the work in `onExpire`.
- Players listen to `AudioSessionEvents`: a call pauses, losing headphones pauses and stays paused, and a media-services reset drops the player. Finished callbacks carry the player (or utterance) that finished, compared with `===`.
- Photos are decoded off the main thread through `ImageCache`; never decode in a view's `body`.

## Checking changes

- Xcode: ⌘B, then ⌘U.
- Without a Mac, the Foundation-only files (`Support/Formatting.swift`, `Services/Questions/QuestionPicker.swift`, `Persistence/QuestionBank.swift`, `Services/Export/FileNaming.swift`, `ArchiveManifest.swift`, `ArchiveHTML.swift`, `AudioFileType.swift`, `Services/Audio/RecordingNote.swift`, `ConversionCheck.swift`, `Services/Media/PortraitFraming.swift`, `DesignSystem/Symbols.swift`) and their tests build with a Linux Swift toolchain. Put them in a Swift package whose library target is named `MyStory`, then run `swift test`. `Services/Family/FamilyLock.swift` and its tests also run there if you add a small stand-in `CryptoKit` target that provides `SHA256.hash(data:)`. Every file should at least pass `swiftc -parse`.
