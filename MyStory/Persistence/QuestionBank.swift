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

    static let questions: [QuestionSeed] = makeQuestions()

    private static func makeQuestions() -> [QuestionSeed] {
        let groups: [(String, [String])] = [
            ("parent", [
                "What were your kids like when they were little?",
                "Tell me about the day your first child was born.",
                "What's a trip with the kids you'll never forget?",
                "What games did you play with your kids?",
                "What made you proud as a dad?",
                "What did you hope your kids would learn from you?",
                "Tell me about a time your kids made you laugh.",
                "What was a normal weekend like when the kids were young?",
                "What's something your kids taught you?",
                "Tell me about teaching one of your kids something new.",
                "What was the hardest part of being a dad?",
                "What traditions did your family have?",
                "Tell me about a birthday that was special.",
                "What do you want your kids to know about you?",
                "What's a funny thing one of your kids said?",
                "What were the holidays like at your house?",
            ]),
            ("work", [
                "Tell me about a job you were proud of.",
                "What was your very first job?",
                "Who was the best boss you ever had?",
                "What did a normal workday look like for you?",
                "What were you really good at in your work?",
                "Tell me about someone you worked with who became a friend.",
                "What was the hardest problem you solved at work?",
                "What would you tell someone starting out in your line of work?",
                "What's a funny thing that happened at work?",
                "How did you end up doing the work you did?",
                "What did you like most about your work?",
                "Tell me about a big day at work that stays with you.",
                "What changed the most in your work over the years?",
                "What skill are you proudest of learning for work?",
            ]),
            (familyKey, [
                "Tell me about someone you fell in love with.",
                "What was your first date like?",
                "Tell me about your mom.",
                "Tell me about your dad.",
                "Tell me about your brothers and sisters.",
                "Who in your family are you most like?",
                "What's a family story that gets told again and again?",
                "Tell me about a family get-together you loved.",
                "What did your grandparents teach you?",
                "Who could always make you laugh?",
                "What's the best gift you ever gave someone?",
                "What does family mean to you?",
                "Tell me about the first home you made your own.",
                "Who have you always been able to count on?",
            ]),
            ("places", [
                "What's the most beautiful place you've ever been?",
                "Tell me about a road trip you took.",
                "Where did you love to go on vacation?",
                "Tell me about a house you lived in.",
                "What was your neighborhood like?",
                "Where would you go back to if you could?",
                "Tell me about a place that feels like home.",
                "Tell me about a restaurant or diner you loved.",
                "Tell me about an adventure you had somewhere new.",
                "What's the farthest you ever traveled?",
                "Tell me about your favorite spot outdoors.",
                "What town or city do you feel most connected to?",
            ]),
            ("proud", [
                "What's something you're proud of?",
                "Tell me about a time you helped someone.",
                "What's the best thing you ever built or made?",
                "Tell me about a time you were brave.",
                "Tell me about a goal you worked hard for.",
                "Tell me about a time someone's thanks meant a lot to you.",
                "What's a skill you're proud to have?",
                "Tell me about a team you were part of.",
                "What's a decision you're glad you made?",
                "Tell me about a day you'll always treasure.",
            ]),
            ("lessons", [
                "What's the best advice anyone ever gave you?",
                "What would you tell your younger self?",
                "What matters most in life?",
                "What have you learned about being a good friend?",
                "What makes for a happy life?",
                "What do you hope people will say about you?",
                "What are you grateful for?",
                "What have you learned about love?",
                "What would you like your grandchildren to know?",
                "What's a mistake that taught you something?",
                "What makes a good day for you?",
                "What do you believe in?",
            ]),
            (thoughtsKey, [
                "What made you smile this week?",
                "What are you looking forward to?",
                "What would you like to tell your family today?",
                "What song has been on your mind lately?",
                "Who have you been thinking about lately?",
                "What are you thankful for today?",
            ]),
            ("school", [
                "What was school like for you?",
                "Tell me about your favorite teacher.",
                "Who were your best friends in school?",
                "What did you do after school?",
                "Tell me about a sport or club you were part of.",
                "What was your very first car?",
                "Tell me about a school dance or a big event.",
                "What were you like as a teenager?",
                "What music did you love when you were young?",
                "What did you want to be when you grew up?",
                "Tell me about your graduation day.",
            ]),
            ("growing-up", [
                "Tell me about the house you grew up in.",
                "What games did you play as a kid?",
                "What was your neighborhood like when you were young?",
                "Who were your friends when you were a kid?",
                "What was dinner like at your house growing up?",
                "Tell me about a pet you had.",
                "What did you do in the summers?",
                "Tell me about something you loved doing as a little kid.",
                "What did your parents do for work?",
                "What were the holidays like when you were a kid?",
                "Tell me about a time you got into a little trouble.",
                "What did you love to eat as a kid?",
                "What was your town like back then?",
            ]),
        ]

        var seeds: [QuestionSeed] = [
            QuestionSeed(key: freeTalkKey, chapterKey: thoughtsKey, text: "What's on your mind today?", isFreeTalk: true),
        ]
        for (chapterKey, texts) in groups {
            for (index, text) in texts.enumerated() {
                seeds.append(QuestionSeed(key: "\(chapterKey).\(index + 1)", chapterKey: chapterKey, text: text))
            }
        }
        return seeds
    }

    static func chapterSeed(forKey key: String) -> ChapterSeed? {
        chapters.first { $0.key == key }
    }
}

/// Invitations to tell a story about one person.
enum PersonPrompts {
    static func texts(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = trimmed.isEmpty ? "them" : trimmed
        return [
            "Tell me about \(who).",
            "What's a favorite memory with \(who)?",
            "What do you love about \(who)?",
            "What have you and \(who) done together that you'll never forget?",
            "What would you like \(who) to know?",
        ]
    }
}
