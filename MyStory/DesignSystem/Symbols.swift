/// SF Symbol names used in the app, in one place so every screen uses the same
/// icon for the same idea. Every icon is always shown next to a word.
enum Symbols {
    static let tell = "mic.fill"
    static let ownStory = "quote.bubble.fill"
    static let question = "questionmark.bubble.fill"
    static let people = "person.2.fill"
    static let stories = "books.vertical.fill"
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

    /// Pictures he or the family can give a chapter, each with a word.
    static let chapterChoices: [(symbol: String, name: String)] = [
        ("book.closed.fill", "Book"),
        ("heart.fill", "Love"),
        ("house.fill", "Home"),
        ("figure.2.and.child.holdinghands", "Family"),
        ("briefcase.fill", "Work"),
        ("hammer.fill", "Tools"),
        ("airplane", "Travel"),
        ("car.fill", "Cars"),
        ("sailboat.fill", "Boats"),
        ("tree.fill", "Outdoors"),
        ("leaf.fill", "Garden"),
        ("music.note", "Music"),
        ("sportscourt.fill", "Sports"),
        ("fork.knife", "Food"),
        ("pawprint.fill", "Pets"),
    ]
}
