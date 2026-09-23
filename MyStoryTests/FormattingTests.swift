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
