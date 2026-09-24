import Foundation
import Testing
@testable import MyStory

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}

private func date(_ hour: Int, _ minute: Int = 0, day: Int = 23, month: Int = 9, year: Int = 2026) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite("Greeting")
struct GreetingTests {
    @Test(arguments: [
        (6, "Good morning, Dave"),
        (11, "Good morning, Dave"),
        (12, "Good afternoon, Dave"),
        (16, "Good afternoon, Dave"),
        (17, "Good evening, Dave"),
        (21, "Good evening, Dave"),
        (23, "Hello, Dave"),
        (3, "Hello, Dave"),
    ])
    func timeOfDay(hour: Int, expected: String) {
        #expect(Greeting.text(for: date(hour), name: "Dave", calendar: utcCalendar) == expected)
    }

    @Test func withoutName() {
        #expect(Greeting.text(for: date(9), name: "  ", calendar: utcCalendar) == "Good morning")
    }
}

@Suite("Durations and counts")
struct DurationTests {
    @Test func clock() {
        #expect(DurationText.clock(0) == "0:00")
        #expect(DurationText.clock(7.9) == "0:07")
        #expect(DurationText.clock(245) == "4:05")
        #expect(DurationText.clock(3723) == "1:02:03")
        #expect(DurationText.clock(.nan) == "0:00")
    }

    @Test func spoken() {
        #expect(DurationText.spoken(30) == "Under a minute")
        #expect(DurationText.spoken(60) == "1 min")
        #expect(DurationText.spoken(245) == "4 min")
        #expect(DurationText.spoken(3600) == "1 hr")
        #expect(DurationText.spoken(3900) == "1 hr 5 min")
    }

    @Test func storyCounts() {
        #expect(StoryCountText.text(0) == "No stories yet")
        #expect(StoryCountText.text(1) == "1 story")
        #expect(StoryCountText.text(14) == "14 stories")
    }

    @Test func toldDates() {
        let now = date(15)
        #expect(DayText.toldShort(date(9), now: now, calendar: utcCalendar) == "Told today")
        #expect(DayText.toldShort(date(9, day: 22), now: now, calendar: utcCalendar) == "Told yesterday")
        #expect(DayText.toldByYou(date(9, day: 12), now: now, calendar: utcCalendar) == "Told by you on September 12")
    }

    @Test func isoDay() {
        #expect(DayText.isoDay(date(9, day: 5), timeZone: TimeZone(identifier: "UTC")!) == "2026-09-05")
    }
}

@Suite("Story names")
struct StoryTitlesTests {
    @Test func tidiesWhatHeTyped() {
        #expect(StoryTitles.cleaned("  The   summer\nat the lake  ") == "The summer at the lake")
        #expect(StoryTitles.cleaned("\n \t ") == "")
    }

    @Test func keepsNamesToALength() {
        let long = String(repeating: "word ", count: 60)
        #expect(StoryTitles.cleaned(long).count == StoryTitles.maximumLength)
    }

    @Test func namesUntitledStoriesByTheDay() {
        let name = StoryTitles.untitled(on: date(10), locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!)
        #expect(name == "My story from Wednesday, September 23")
    }
}

@Suite("Years the family types")
struct StoryYearsTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000) // 2026
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func acceptsRealYears() {
        #expect(StoryYears.parse("1975", now: now, calendar: calendar) == 1975)
        #expect(StoryYears.parse(" 1900 ", now: now, calendar: calendar) == 1900)
        #expect(StoryYears.parse("2026", now: now, calendar: calendar) == 2026)
    }

    @Test func refusesAnythingElse() {
        #expect(StoryYears.parse("", now: now, calendar: calendar) == nil)
        #expect(StoryYears.parse("75", now: now, calendar: calendar) == nil)
        #expect(StoryYears.parse("1899", now: now, calendar: calendar) == nil)
        #expect(StoryYears.parse("2027", now: now, calendar: calendar) == nil)
        #expect(StoryYears.parse("19x5", now: now, calendar: calendar) == nil)
        #expect(StoryYears.parse("\u{0661}\u{0669}\u{0667}\u{0665}", now: now, calendar: calendar) == nil)
    }
}

@Suite("Lists of names")
struct ListTextTests {
    @Test func joinsTheWayPeopleSayIt() {
        #expect(ListText.joined([]) == "")
        #expect(ListText.joined(["Emily"]) == "Emily")
        #expect(ListText.joined(["Emily", "Jake"]) == "Emily and Jake")
        #expect(ListText.joined(["Emily", "Jake", "Sam"]) == "Emily, Jake and Sam")
    }
}

@Suite("Chapter pictures")
struct ChapterPictureTests {
    @Test func eachPictureIsDifferentAndNamed() {
        let symbols = Symbols.chapterChoices.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
        #expect(Symbols.chapterChoices.allSatisfy { !$0.name.isEmpty })
    }
}
