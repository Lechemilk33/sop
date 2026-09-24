import Foundation

/// A built-in chapter of life.
struct ChapterSeed: Equatable {
    let key: String
    let name: String
    let symbolName: String
    /// Order in My life.
    let sortOrder: Int
    /// Lower is asked about sooner. Recent decades come first because with
    /// Alzheimer's they usually fade before childhood memories do.
    let askPriority: Int
}

/// Compares questions by their words, ignoring case, spacing and the kind
/// of apostrophe, so a question is recognized after small edits.
enum QuestionMatching {
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// A built-in question. Keys never change once shipped.
struct QuestionSeed: Equatable {
    let key: String
    let chapterKey: String
    let text: String
    var isFreeTalk: Bool = false
}

/// The chapters and questions the app starts with. Every question is an open
/// invitation ("Tell me about…"), never a memory test ("Do you remember…?",
/// "What year…?"). The family can hide any of them and add their own.
enum QuestionBank {
    static let moreStoriesKey = "more"
    static let thoughtsKey = "thoughts"
    static let familyKey = "family"
    static let freeTalkKey = "thoughts.free"

    static let chapters: [ChapterSeed] = [
        ChapterSeed(key: "growing-up", name: "Growing up", symbolName: "house.fill", sortOrder: 0, askPriority: 70),
        ChapterSeed(key: "school", name: "School days", symbolName: "graduationcap.fill", sortOrder: 1, askPriority: 60),
        ChapterSeed(key: familyKey, name: "Love and family", symbolName: "heart.fill", sortOrder: 2, askPriority: 20),
        ChapterSeed(key: "parent", name: "Being a dad", symbolName: "figure.and.child.holdinghands", sortOrder: 3, askPriority: 0),
        ChapterSeed(key: "work", name: "Work", symbolName: "briefcase.fill", sortOrder: 4, askPriority: 10),
        ChapterSeed(key: "places", name: "Places I've been", symbolName: "map.fill", sortOrder: 5, askPriority: 30),
        ChapterSeed(key: "proud", name: "Proud moments", symbolName: "star.fill", sortOrder: 6, askPriority: 35),
        ChapterSeed(key: "lessons", name: "Lessons and advice", symbolName: "lightbulb.fill", sortOrder: 7, askPriority: 40),
        ChapterSeed(key: thoughtsKey, name: "My thoughts", symbolName: "bubble.left.fill", sortOrder: 8, askPriority: 45),
        ChapterSeed(key: moreStoriesKey, name: "More stories", symbolName: "books.vertical.fill", sortOrder: 9, askPriority: 90),
    ]

    /// Every built-in question, with a key written out by hand. Keys never
    /// change once shipped, so questions can be reworded, added or reordered
    /// without mixing them up on an iPhone that already has them.
    static let questions: [QuestionSeed] = {
        var all = [
            QuestionSeed(key: freeTalkKey, chapterKey: thoughtsKey, text: "What's on your mind today?", isFreeTalk: true),
        ]
        all += seeds("parent", [
            ("little", "What were your kids like when they were little?"),
            ("becoming", "What was it like becoming a dad?"),
            ("born", "Tell me about the day one of your kids was born."),
            ("trip", "Tell me about a trip you took with the kids."),
            ("games", "What games did you play with your kids?"),
            ("proud", "What made you proud as a dad?"),
            ("hopes", "What did you hope your kids would learn from you?"),
            ("laugh", "Tell me about a time your kids made you laugh."),
            ("weekend", "What was a normal weekend like when the kids were young?"),
            ("bedtime", "What was bedtime like when the kids were small?"),
            ("taught-you", "What's something your kids taught you?"),
            ("teaching", "Tell me about teaching one of your kids something new."),
            ("hard", "What was hard about being a dad?"),
            ("traditions", "What traditions did your family have?"),
            ("birthday", "Tell me about a birthday that was special."),
            ("know", "What do you want your kids to know about you?"),
            ("funny", "Tell me about something funny one of your kids did."),
            ("holidays", "What were the holidays like at your house?"),
            ("songs", "What songs did you sing or play for your kids?"),
            ("now", "What do you love about who your kids are now?"),
        ])
        all += seeds("work", [
            ("proud-job", "Tell me about a job you were proud of."),
            ("young-job", "Tell me about a job you had when you were young."),
            ("how", "How did you end up doing the work you did?"),
            ("workday", "What did a normal workday look like for you?"),
            ("good-at", "What were you really good at in your work?"),
            ("boss", "Tell me about a boss you liked working for."),
            ("friend", "Tell me about someone you worked with who became a friend."),
            ("people", "What did you enjoy about the people you worked with?"),
            ("problem", "Tell me about a problem you solved at work."),
            ("tools", "Tell me about the tools of your trade."),
            ("trained", "Tell me about someone you taught or trained at work."),
            ("advice", "What would you tell someone starting out in your line of work?"),
            ("funny", "Tell me about a funny day at work."),
            ("liked", "What did you like most about your work?"),
            ("big-day", "Tell me about a big day at work that stays with you."),
            ("changed", "Tell me about how your work changed over the years."),
            ("skill", "Tell me about a skill you learned for work."),
            ("travel", "Tell me about a time work took you somewhere new."),
        ])
        all += seeds(familyKey, [
            ("fell-in-love", "Tell me about someone you fell in love with."),
            ("date", "Tell me about a favorite date night."),
            ("mom", "Tell me about your mom."),
            ("dad", "Tell me about your dad."),
            ("siblings", "Tell me about your brothers and sisters."),
            ("most-like", "Who in your family are you most like?"),
            ("family-story", "What's a family story that gets told again and again?"),
            ("get-together", "Tell me about a family get-together you loved."),
            ("grandparents", "What did your grandparents teach you?"),
            ("laugh", "Who could always make you laugh?"),
            ("gift", "Tell me about a gift you gave someone."),
            ("meaning", "What does family mean to you?"),
            ("home", "Tell me about a home you made your own."),
            ("count-on", "Who have you always been able to count on?"),
            ("wedding", "Tell me about a wedding that was special to you."),
            ("meal", "Tell me about a meal your family loved to share."),
            ("like-family", "Tell me about a friend who feels like family."),
        ])
        all += seeds("places", [
            ("beautiful", "Tell me about a beautiful place you've been."),
            ("road-trip", "Tell me about a road trip you took."),
            ("vacation", "Where did you love to go on vacation?"),
            ("house", "Tell me about a house you lived in."),
            ("neighborhood", "What was your neighborhood like?"),
            ("go-back", "Where would you go back to if you could?"),
            ("feels-home", "Tell me about a place that feels like home."),
            ("restaurant", "Tell me about a restaurant or diner you loved."),
            ("adventure", "Tell me about an adventure you had somewhere new."),
            ("view", "Tell me about a view you loved."),
            ("outdoors", "Tell me about your favorite spot outdoors."),
            ("water", "Tell me about a lake, river, or beach you loved."),
            ("town", "What town or city do you feel most connected to?"),
            ("hangout", "Where did you and your friends like to hang out?"),
            ("friends-trip", "Tell me about a trip you took with friends."),
            ("concert", "Tell me about a concert or a game you went to."),
        ])
        all += seeds("proud", [
            ("something", "What's something you're proud of?"),
            ("helped", "Tell me about a time you helped someone."),
            ("made", "Tell me about something you built or made."),
            ("brave", "Tell me about a time you were brave."),
            ("goal", "Tell me about a goal you worked hard for."),
            ("thanks", "Tell me about a time someone's thanks meant a lot to you."),
            ("skill", "What's a skill you're proud to have?"),
            ("team", "Tell me about a team you were part of."),
            ("decision", "What's a decision you're glad you made?"),
            ("treasure", "Tell me about a day you'll always treasure."),
            ("fixed", "Tell me about a time you fixed something."),
            ("stood-up", "Tell me about a time you stood up for someone."),
            ("their-day", "Tell me about a time you made someone's day."),
        ])
        all += seeds("lessons", [
            ("advice", "Tell me about some good advice someone gave you."),
            ("younger-self", "What would you tell your younger self?"),
            ("matters", "What matters most in life?"),
            ("good-friend", "What have you learned about being a good friend?"),
            ("happy-life", "What makes for a happy life?"),
            ("hope-say", "What do you hope people will say about you?"),
            ("grateful", "What are you grateful for?"),
            ("love", "What have you learned about love?"),
            ("grandchildren", "What would you like your grandchildren to know?"),
            ("mistake", "What's a mistake that taught you something?"),
            ("good-day", "What makes a good day for you?"),
            ("believe", "What do you believe in?"),
            ("hard-times", "What helped you get through hard times?"),
            ("kindness", "Tell me about a kindness someone showed you."),
            ("neighbor", "What makes someone a good neighbor?"),
        ])
        all += seeds(thoughtsKey, [
            ("smile", "What makes you smile?"),
            ("looking-forward", "What are you looking forward to?"),
            ("tell-family", "What would you like to tell your family today?"),
            ("song", "What song do you love to sing along to?"),
            ("time-with", "Who do you love spending time with?"),
            ("thankful", "What are you thankful for today?"),
            ("wish", "What do you wish for the people you love?"),
            ("simple-joy", "What's a simple thing that makes you happy?"),
            ("peace", "Where do you feel most at peace?"),
            ("free-time", "What do you love doing in your free time?"),
            ("root-for", "Tell me about a team you love to root for."),
            ("again", "What's something you'd love to do again?"),
        ])
        all += seeds("school", [
            ("like", "What was school like for you?"),
            ("teacher", "Tell me about a teacher you liked."),
            ("friend", "Tell me about a friend from your school days."),
            ("after-school", "What did you do after school?"),
            ("sport", "Tell me about a sport or club you were part of."),
            ("learning", "What did you love learning about?"),
            ("car", "Tell me about a car you loved."),
            ("dance", "Tell me about a school dance or a big event."),
            ("teenager", "What were you like as a teenager?"),
            ("weekends", "What did you and your friends do on weekends?"),
            ("music", "What music did you love when you were young?"),
            ("grow-up", "What did you want to be when you grew up?"),
            ("graduation", "Tell me about your graduation day."),
        ])
        all += seeds("growing-up", [
            ("house", "Tell me about the house you grew up in."),
            ("room", "What was your room like as a kid?"),
            ("games", "What games did you play as a kid?"),
            ("neighborhood", "What was your neighborhood like when you were young?"),
            ("friend", "Tell me about a friend you had as a kid."),
            ("dinner", "What was dinner like at your house growing up?"),
            ("sunday", "What was a Sunday like at your house growing up?"),
            ("pet", "Tell me about a pet you had."),
            ("summers", "What did you do in the summers?"),
            ("loved-doing", "Tell me about something you loved doing as a little kid."),
            ("toy", "Tell me about a toy you loved."),
            ("looked-up-to", "Tell me about a grown-up you looked up to as a kid."),
            ("holidays", "What were the holidays like when you were a kid?"),
            ("trouble", "Tell me about a time you got into a little trouble."),
            ("chores", "What chores did you have as a kid?"),
            ("food", "What did you love to eat as a kid?"),
            ("town", "What was your town like back then?"),
        ])
        return all
    }()

    /// Where each built-in question sits in the list above, for showing them
    /// to the family in the same order.
    static let position: [String: Int] = Dictionary(
        uniqueKeysWithValues: questions.enumerated().map { ($0.element.key, $0.offset) }
    )

    private static func seeds(_ chapterKey: String, _ items: [(key: String, text: String)]) -> [QuestionSeed] {
        items.map { QuestionSeed(key: "\(chapterKey).\($0.key)", chapterKey: chapterKey, text: $0.text) }
    }

    static func chapterSeed(forKey key: String) -> ChapterSeed? {
        chapters.first { $0.key == key }
    }
}

/// Invitations to tell a story about one person.
/// Invitations for a chapter he or the family made, which has no questions
/// of its own: questions from other chapters would be filed in the wrong
/// place, so it's asked about in its own words.
enum ChapterPrompts {
    static func texts(for chapterName: String) -> [String] {
        let name = chapterName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return ["Tell me a story."] }
        let quoted = "\u{201C}\(name)\u{201D}"
        return [
            "Tell me a story about \(quoted).",
            "What do you think of when you hear \(quoted)?",
            "Tell me more about \(quoted).",
        ]
    }
}

enum PersonPrompts {
    static func texts(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = trimmed.isEmpty ? "them" : trimmed
        return [
            "Tell me about \(who).",
            "What do you love about \(who)?",
            "Tell me about a good time with \(who).",
            "Tell me about something you and \(who) did together.",
            "What would you like \(who) to know?",
        ]
    }
}
