/// SF Symbol names used in the app, in one place so every screen uses the same
/// icon for the same idea. Every icon is always shown next to a word.
enum Symbols {
    static let tell = "mic.fill"
    static let ownStory = "quote.bubble.fill"
    static let question = "questionmark.bubble.fill"
    static let people = "person.2.fill"
    static let stories = "book.fill"
    static let allStories = "list.bullet"
    static let home = "house.fill"
    static let back = "chevron.left"
    static let forward = "chevron.right"
    static let play = "play.fill"
    static let pause = "pause.fill"
    static let playAgain = "arrow.counterclockwise"
    static let stop = "stop.fill"
    static let read = "speaker.wave.2.fill"
    static let differentQuestion = "arrow.clockwise"
    static let shuffle = "shuffle"
    static let saved = "checkmark"
    static let selected = "checkmark.circle.fill"
    static let lock = "lock.fill"
    static let hello = "speaker.wave.2.fill"
    static let askedBy = "text.bubble.fill"
    static let photo = "photo.fill"
    static let addPhoto = "photo.badge.plus"
    static let noPhoto = "xmark.circle"
    static let person = "person.fill"
    static let organize = "square.and.pencil"
    static let rename = "pencil"
    static let chapter = "folder.fill"
    static let newChapter = "folder.badge.plus"
    static let done = "checkmark"
    static let deleteDigit = "delete.left.fill"
    static let microphoneOff = "mic.slash.fill"

    /// The few pictures he chooses from when he makes a chapter.
    static let simpleChapterChoices: [(symbol: String, name: String)] = [
        ("book.closed.fill", "Book"),
        ("figure.2.and.child.holdinghands", "Family"),
        ("briefcase.fill", "Work"),
        ("airplane", "Travel"),
        ("tree.fill", "Outdoors"),
        ("music.note", "Music"),
    ]

    /// Every picture a chapter can have; the family chooses from these.
    static let chapterChoices: [(symbol: String, name: String)] = simpleChapterChoices + [
        ("heart.fill", "Love"),
        ("hammer.fill", "Tools"),
        ("car.fill", "Cars"),
        ("sailboat.fill", "Boats"),
        ("leaf.fill", "Garden"),
        ("sportscourt.fill", "Sports"),
        ("fork.knife", "Food"),
        ("pawprint.fill", "Pets"),
        ("star.fill", "Star"),
    ]
}
