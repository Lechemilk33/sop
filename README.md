# My Story

A simple, private iPhone app for someone with early-stage Alzheimer's. He records his life stories in his own voice, keeps them by the chapters of his life, and sees the important people in his life. The family sets it up and keeps a copy of everything, forever.

- Why it looks and works the way it does, with the research behind every rule: [PLAN.md](PLAN.md)
- Clickable mockup of every screen: https://claude.ai/artifact/GC9B2p2PyC9YXgTfrBk7VT (private until shared)

## Try it in the simulator (no Apple account needed)

1. Open `MyStory.xcodeproj` in Xcode 26 or later.
2. Pick an iPhone simulator (iOS 26 or later) next to the Run button.
3. Press Run (⌘R).

The first launch shows the family setup: his name, a family code, the microphone, and the on-device language file for writing stories down.

## Put it on his iPhone

The app has to stay installed for years, so this needs the Apple Developer Program ($99 a year). With a free account, apps stop opening after 7 days.

1. Join the Apple Developer Program, then add the account in Xcode → Settings → Accounts.
2. In Xcode, select the **MyStory** target → **Signing & Capabilities**:
   - Team: your team.
   - Bundle Identifier: change `com.mystory.app` to something unique, like `com.yourname.mystory`.
3. Connect his iPhone with a cable. On the iPhone, turn on Settings → Privacy & Security → Developer Mode (it restarts).
4. Choose his iPhone next to the Run button and press Run.

For updates without a cable, use TestFlight: Product → Archive → Distribute App → TestFlight (Internal testing needs no review, and each build lasts 90 days). Add him as a user on your App Store Connect team to install it.

## Turn on iCloud backup

Until this is on, stories live only on his iPhone (and in any copies made with **Save a copy of everything**).

1. Target → **Signing & Capabilities** → **+ Capability** → **iCloud**. Tick **CloudKit** and add a container named `iCloud.<your bundle identifier>`.
2. Target → **Build Settings**, search for `MYSTORY_ICLOUD_SYNC`, and set it to `YES`.
3. Before the first TestFlight build, open the CloudKit Console and deploy the schema to production.
4. On his iPhone, make sure he's signed in to iCloud. Recordings count against his iCloud storage (about 10 MB per 20 minutes), so iCloud+ 50 GB is a good idea.

## If the family code is forgotten

There's no Face ID fallback on purpose: it's his phone, so his face or passcode would open the family area.

1. Open the iPhone's **Settings** app → **Apps** → **My Story**, and turn on **Reset family code**.
2. Open My Story → **For family**. It asks you to choose a new code (type it twice).

The switch turns itself off again, and no stories, people or photos are touched.

## How the code is organised

```
MyStory/
  App/            Entry point, services, root view
  Navigation/     Router: a simple stack of screens, no gestures
  DesignSystem/   Palette, type, sizes, BigButton, TopBar, ScreenScaffold, rows
  Features/
    Home/         Greeting and the three big choices
    TellAStory/   Question → listening → saved
    MyLife/       Chapters and a chapter's stories
    Player/       Hearing a story
    MyPeople/     People and a person's page
    FamilyGate/   The family code screen
    Setup/        First-run family setup
    Family/       The family area (standard iPhone forms and lists)
  Models/         SwiftData models (iCloud-ready)
  Persistence/    Store, built-in chapters and questions, seeding
  Services/       Recording, playback, read-aloud, writing stories down,
                  question choice, photos, the saved copy, family code, settings
  Resources/      Icon, colors, Atkinson Hyperlegible Next fonts (SIL OFL)
MyStoryTests/     Unit tests (Swift Testing)
Config/Info.plist
```

## Tests

In Xcode: Product → Test (⌘U).

## What happens to a story

1. He taps **Start talking**. Audio is recorded uncompressed to a crash-safe file.
2. He taps **I'm finished**. The file becomes a compact `.m4a` and is stored with the story.
3. The words are written down on the iPhone (Apple's SpeechAnalyzer). Nothing is sent anywhere.
4. If the app closes mid-story, the recording is rescued as a new story next time it opens.
5. **Save a copy of everything** makes a folder with every original recording, the words in text files, the photos, the questions the family recorded, `stories.json`, and `Open me.html`, which plays everything in any web browser. Only the newest copy is kept on the iPhone, so move it somewhere safe (a Mac, a USB drive, iCloud Drive) each time.
6. Nothing he taps deletes anything. Stories are only removed by the family, from the family area, after a confirmation.
