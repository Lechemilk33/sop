# Life Story App: plan

A private iPhone app where Dave (a stand-in name) records his life stories in his own voice, keeps them organized by the chapters of his life and the people in it, and listens back whenever he likes. The family helps set it up and keeps a copy of everything, forever.

Clickable mockup of every screen: https://claude.ai/artifact/GC9B2p2PyC9YXgTfrBk7VT (private until shared from its Share menu).

Status: Phase 1 is built, and round 2 is done after the family's first try: a calmer, more grown-up look using Liquid Glass; his own stories with names he chooses, not only answers to questions; organizing stories by name, people, chapter and photo; and people's photos framed around their faces. The app lives in `MyStory/`, and the README explains how to run it and put it on his iPhone.

## Who it's for

- Dave, 55, recently diagnosed with early-onset Alzheimer's, early stage. Uses an iPhone.
- Sometimes he uses it alone, sometimes with a family member sitting beside him.
- The goal is for him to cherish his life now and for the family to keep his voice later. Day-to-day reminders (where did I park, who is this) are out of scope for now.

## Design rules and the research behind them

Most dementia-specific evidence comes from small or qualitative studies. Where a rule is our inference rather than a finding, it says so.

| Rule | Why |
| --- | --- |
| Three big choices on Home. One thing to do per screen. | People with dementia use touchscreens well when there are few steps and uncluttered, consistent screens (Joddrell & Astell 2016, review of 45 studies). A 2023 review of 40 studies gives the same "simplify, bigger, further apart" rules (Gomez-Hernandez et al., JMIR mHealth uHealth). |
| Main buttons 88–136 pt tall and full width. Other buttons at least 64 pt. At least 20 pt between main buttons. | Touch studies with older adults found targets of roughly 16.5–19 mm worked best (Jin, Plocher & Kiff 2007, via secondary sources). That is about 100–115 pt on an iPhone; Apple's 44 pt minimum is only about 7 mm. |
| Taps only: no swiping, holding, pinching or double-tapping. Ignore rapid repeat taps. | Gestures and double taps cause errors for older users (Caprani et al. 2012; Gomez-Hernandez et al. 2023). |
| Every button has an icon and a word. Real photos for people. | Icons without words failed in the touchscreen studies (Joddrell & Astell 2016). The Alzheimer's Society found real photographs work "much better" than cartoons. |
| Home is always in the same corner (top right). The way back is labeled with where it goes. | Finding things and getting lost in menus were top problems for people with dementia using phones (Dixon et al. 2022, ASSETS). |
| Dark text on warm cream. No dark mode. Text at least 7:1 contrast, outlines of tappable things at least 3:1. | Dark-on-light reads better at every age (Piepenbrock et al. 2013). Alzheimer's reduces contrast sensitivity (Cronin-Golomb et al. 1991). Contrast, not color, drove the famous red-plate result (Dunne et al. 2004). "White can be overwhelming," one participant told Dixon & Lazar (2020). |
| The three places (Tell, People, Stories) differ in lightness as well as color. | Color errors in Alzheimer's are mostly on the blue axis (Cronin-Golomb et al. 1991), so blue vs. green or blue vs. violet can't be the only cue. |
| Liquid Glass only for controls (buttons, Home's tiles, the top bar), over a calm background; solid white cards for content. Colored glass sits on solid color, and frosted glass always has a visible edge. | The family found the first look childish. Apple reserves Liquid Glass for the control layer, and translucency can cost contrast, so the contrast rules above still apply to every glass surface. iOS makes glass more opaque when Reduce Transparency is on. |
| Text never below 20 pt. Reading text 22 pt. Questions 30 pt. Grows with the iPhone's text size setting. Sentence case, bold for emphasis. | The Alzheimer's Society recommends 14 pt print minimum, which is larger at phone distance. The 2023 review cites at least 30 pt for critical text and 20 pt for secondary text on mobile. Reading ability can change through the day (Dixon & Lazar 2020), so Dynamic Type matters. |
| Recording: tap to start, tap to stop. It never stops by itself when he pauses. The question stays on screen while he talks. Everything saves as he talks. | People with dementia pause longer and more often, especially before names, and assistants that cut in early frustrate them (Addlesee & Eshghi 2024). |
| Touch only, no voice commands. | Speech recognition errors damaged trust; people chose touch 55,442 times against 853 successful voice uses (Stara et al. 2021). |
| Never make anything up. His words are transcribed, never rewritten. No AI voice, no AI-made or AI-edited images. AI may only suggest labels the family confirms. | Chatbots and AI-edited images raised false memories in healthy adults (Chan et al. 2024, preprint; Pataranutaporn et al., CHI 2025). He can't fact-check. |
| Questions are invitations, not quizzes: "Tell me about…", never "Do you remember…?" Skipping is always fine. | Dementia communication guidance from the Alzheimer's Society and the US National Institute on Aging: "Avoid trying to jog their memory." |
| No timers, pop-ups, streaks, badges or scores. | W3C cognitive accessibility guidance: limit interruptions, avoid timeouts. (No streaks/badges is our inference.) |
| Nothing he taps can delete a story. He can name his stories, choose who's in them, move them between chapters and make chapters; deleting only happens in the family area, behind a code. | People with dementia prefer preset easy modes to configuring things (Dixon et al. 2022), so nothing needs setting up, but choosing what his stories are called and where they go supports his sense of control (Suijkerbuijk et al. 2019). The family asked for it. A code, not a hidden gesture he could trigger by accident, guards deleting. |
| He can tell his own story, not only answer a question, and call it whatever he likes (or skip naming it). | Open invitations respect his choice of what matters; questions stay available as cues, because cued recall is easier than free recall. Naming is optional so it never blocks a story. |
| Keep the layout the same between updates. | Relearning after updates was a key problem (Dixon et al. 2022). |
| Build it with him. Show him each version in short sessions, with his own photos and stories. | People with dementia can shape content, design and the core idea, and co-design strengthens their sense of control (Suijkerbuijk et al. 2019). Early-onset Alzheimer's is more often atypical (for example, visual), so test with him rather than assume. |

Related evidence that shaped the product itself:

- Reviewing personal photos and recordings works. In small studies, people with Alzheimer's recalled events better after reviewing wearable-camera photos than after rereading a diary (Woodberry et al. 2015). An iPad reminiscence app co-created with people with dementia (InspireD, Laird et al. 2018) was followed by better relationship quality and well-being for the person with dementia.
- Using it together is a first-class mode. Touchscreen reminiscence made caregivers more equal conversation partners and was enjoyed by both (CIRCA, Astell et al. 2010).

## Look and feel

Calm, warm and grown-up, like a good photo album: warm neutrals, one deep color per place used for small accents, Liquid Glass on the things you tap.

| Token | Hex | Used for | Contrast |
| --- | --- | --- | --- |
| Paper → Paper deep | `#F5F1EB` → `#E8E1D7` | Background gradient, with a faint glow of the place's color | ink 15.4:1 / 13.4:1 |
| Card | `#FFFFFF` | Content cards and rows | |
| Ink | `#1C1A17` | Main text, "I'm finished" | |
| Soft ink | `#443E39` | Second line of text | 8.1:1 on paper deep, 7.2:1 on the glows |
| Edge | `#82786C` | Edge of anything tappable | 3.3:1 on paper deep, 4.3:1 on white |
| Hairline | `#DCD4C9` | Soft edge of things you can't tap | |
| Brick | `#9A331C` | Tell a story | white text 7.3:1 |
| Blue | `#1F3E6E` | My people | white text 10.6:1 |
| Marigold | `#E0A33A` | My stories, and anything you listen to | ink text 7.8:1 |
| Marigold rim | `#6E4B0E` | Edge of gold shapes, text on gold tints | 6.0:1 on paper deep |
| Green | `#265E36` | Saved, chosen | white text 7.7:1 |

- Type: the iPhone's own font (San Francisco), scaled with Dynamic Type via `UIFontMetrics` and the family's text size. The family can switch to Atkinson Hyperlegible Next ("Extra-clear letters"), made by the Braille Institute for readers with low vision.
- Glass: `glassEffect(.regular.interactive())` for quiet buttons and Home's tiles, tinted glass over solid color for main actions, 2 pt edges (3 pt with Increase Contrast).
- Icons: SF Symbols, always paired with a word, in colored medallions that never look tappable on their own.
- Always light mode (`.preferredColorScheme(.light)`). Honor Increase Contrast, Bold Text, Reduce Motion and Reduce Transparency.

## Screens

His side (see the mockup):

- **Home**: "Good morning, Dave" and the date. Three glass tiles: Tell a story, My people, My stories. A small "For family" button.
- **Tell a story**: two choices, "My own story" or "Answer a question". His own story can be given any name (typed, or said with the keyboard's microphone), or none. A question shows in big type with "Read it to me", "Start talking" and "A different question". Then the listening screen: the story's name or the question stays visible, a big "I'm finished" button, and no Home button, so a stray tap can't cut a story short. Then "Saved. “The summer at the lake” is in My stories, under More stories." with Listen to it, Name it and add people, and Tell another story.
- **About this story** (from Saved or while listening): its name, who's in it, its chapter and its photo, each a tap away from changing. He can make a new chapter with a name and a picture.
- **My people**: a grid of photos framed around each face, with names and "my daughter", "my brother". A person's page: a big framed photo, name, relationship, two or three facts, "Hear Emily" (a voice message she recorded), "Stories with Emily", and "Tell a story about Emily".
- **My stories**: "Play me a story" (one tap, no choices), All my stories, then the chapters, including ones he made. A chapter: "Play them all", its stories, and changing its name or picture. A story: the whole photo, big play/pause, who's in it, his words to read along, and About this story.

Family side, behind a 4-digit code:

- Add a person: photo (from Photos or the camera, framed around their face automatically, with Move and Zoom to adjust), name, relationship, a few facts, and a recorded hello. Tap the photo to change it later.
- Chapters: rename any chapter or change its picture; delete ones he or the family made (their stories move to More stories).
- Add a question: typed, or recorded in their own voice, tagged "Emily asked this one".
- Add photos, with who's in them and roughly when.
- Bring in old recordings (Voice Memos or files).
- Check new stories: fix the title, chapter, people, year or transcript.
- Tips for sitting with him (below).
- Save a copy of everything.
- Settings: his name, the family code, text size, extra-clear letters.

## Questions

- Chapters: Growing up, School days, Work, Love and family, Being a dad, Places I've been, Proud moments, Lessons and advice, My thoughts.
- Recent decades first. With Alzheimer's, recent decades usually fade before childhood, so his years raising kids and working come before his childhood.
- Every question is an open invitation: "What was Emily like when she was little?", "Tell me about a job you were proud of.", "What's the best advice anyone ever gave you?"
- "What's on your mind today?" rotates in for free talk. Those stories go to My thoughts.
- About 150 questions to start. The family can add more, optionally recorded in their own voice.

Tips card for whoever sits with him (in the family area):

- Let him lead. Follow up with "What happened next?", "Who was there?", "How did that feel?"
- Don't correct him or ask "Do you remember…?"
- If he loses the thread, repeat the question gently or pick another one.
- Stop while it's still fun. 15 to 30 minutes is plenty.

## How it's built

- **Platform**: native SwiftUI for iOS 26 and later. iOS 27 is current. Both run on iPhone 11 / SE (2nd gen) and newer.
- **Data**: SwiftData, synced to his private iCloud for backup (`ModelConfiguration(cloudKitDatabase: .private(...))`). CloudKit rules: no unique attributes, every relationship optional, defaults on everything.
- **Storage**: audio is about 10 MB per 20 minutes (AAC, mono, about 64 kbps) and counts against his iCloud storage. Plan on iCloud+ 50 GB.
- **Recording**: AVAudioRecorder to `.m4a`.
  - If a phone call interrupts, save what was recorded and continue into a new file.
  - Keep the screen awake while recording.
  - Enable the background audio mode so a screen lock doesn't cut him off.
  - Silence never stops it.
- **Transcription**: on the phone with Apple's SpeechAnalyzer/SpeechTranscriber (iOS 26+).
  - Needs a one-time language download.
  - Reportedly unavailable on iPhone 11 / SE (2nd gen); fall back to DictationTranscriber there.
  - Runs in the background after saving; the family can fix the text.
- **Suggestions (later, optional)**: Apple's on-device Foundation Models, on Apple Intelligence iPhones (15 Pro, 16 and later, Air).
  - Suggests a title, people and year for the family to confirm.
  - The context is about 4K tokens, so long transcripts get split first.
- **Read aloud**: AVSpeechSynthesizer, or the family member's recorded question.
- **Privacy**: no accounts, ads, analytics or third-party servers, and no third-party packages. Everything stays on his phone and his iCloud.
- **Save a copy**: one folder with human-readable names, so nothing depends on the app still existing years from now:
  - `2026-09-12 Her first bike ride.m4a`, a `.txt` transcript per story, and photos.
  - `data.json` with everything else.
  - `index.html`, which plays it all offline in any browser.
- **Accessibility**:
  - Dynamic Type including the accessibility sizes, VoiceOver labels, Reduce Motion, Increase Contrast.
  - Support Apple's Assistive Access (`UISupportsFullScreenInAssistiveAccess`), a simplified whole-phone mode the family can turn on later.

### Data model

- `Person`: name, relationship, photo, facts, hello recording, sort order.
- `Chapter`: name, icon, cover photo, sort order.
- `Question`: text, chapter, asked by (Person), recorded question audio, built-in or family-added, times shown.
- `Story`: title, audio file, duration, transcript and its status, recorded at, chapter, the question it answered, asked by, people in it, photos, year (optional), told with (Person).
- `Photo`: image, caption, year (optional), people, chapter.

## Getting it onto his iPhone

- Join the Apple Developer Program ($99 a year). With a free account, the app stops opening after 7 days and iCloud sync isn't available.
- Install with TestFlight or from Xcode with a cable:
  - TestFlight internal testing: no review, each build lasts 90 days, and his Apple ID is added as a user on your team.
- Deploy the CloudKit schema to production before the first TestFlight build.

## Build order

**Phase 0: now, no code**

- Show him the mockup on his phone. Watch where he hesitates and change it.
- Start recording stories now with Voice Memos. The app will import them.
- Gather photos of the important people. Agree on chapters. Brainstorm questions as a family.
- Join the Apple Developer Program. Find out which iPhone he has.

**Phase 1: the first version he uses**

- Home, Tell a story (question, listening, saved), My life, now My stories (play me a story, chapters, story player), My people (grid, person page).
- Family area: people, questions, photos, import, review, save a copy, code.
- On-device transcription, iCloud backup.

**Phase 2: family from their own phones**

- Family add questions, photos and their own stories about him from their phones. SwiftData can't share with other Apple IDs, so this needs Core Data + CloudKit sharing or a small server.
- Messages for later: recordings for a future day, kept sealed until then.
- Music in chapters. AI label suggestions. Finding "the story where…".

**Phase 3: as things change**

- A listen-only Home with one button: Play me a story.
- Larger default text. Assistive Access.
- A slideshow of his photos with his voice for an iPad or TV.

## Where to build it

This cloud session can write Swift but can't compile or run iOS apps. The smoothest path is Claude Code on the Mac, in this repo. It can build with Xcode, run the iPhone simulator, and fix its own compile errors.

## Open questions

1. Which iPhone does he have? This decides on-device transcription and AI suggestions.
2. What does he want it called, and what name should it greet him by?
3. Who looks after the family area, and what's the code?
4. Which people and chapters go in first?
5. Are there topics he wants kept private or handled gently? Ask him while he can say.
