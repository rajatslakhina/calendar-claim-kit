@testable import CalendarClaimKit
import XCTest

final class QuestionTests: XCTestCase {
    func operation(_ question: String) -> QuestionOperation? {
        QuestionReader().operation(in: read(question, today: 2026))
    }

    func bound(_ question: String, _ answer: String) -> CalendarValue? {
        guard let operation = operation(question) else { return nil }
        return QuestionReader().bind(operation, answer: read(answer, today: 2026))?.0
    }

    func testOperations() {
        XCTAssertEqual(operation("Is 2100 a leap year?")?.expression, .leapYear(2100))
        XCTAssertEqual(operation("When is the third Tuesday of March 2026?")?.expects, .date)
        XCTAssertNil(operation("When is the third Tuesday of the month?"))
        XCTAssertEqual(operation("What day of the week is 100 days from today?")?.expects, .weekday)
        XCTAssertEqual(operation("Which weekday is 3 days after March 3, 2026?")?.expects, .weekday)
        XCTAssertEqual(operation("What date is 90 days after March 3, 2026?")?.expects, .date)
        XCTAssertEqual(operation("Which date is 2 days ago?")?.expects, .date)
        XCTAssertEqual(operation("When is 90 days after March 3, 2026?")?.expects, .dateOrWeekday)
        XCTAssertEqual(operation("How many business days are there between March 2 and March 16, 2026?")?.expects, .count(.businessDay))
        XCTAssertEqual(operation("How long is it from March 3 through June 1, 2026?")?.expression,
                       .span(from: .date(withYear(3, 3)), to: .date(mention(6, 1, 2026)), unit: .day, inclusive: true))
        XCTAssertEqual(operation("How many days are in February 2028?")?.expression, .monthLength(MonthMention(month: 2, year: 2028)))
        XCTAssertEqual(operation("How many days does 2027 have?")?.expression, .yearLength(2027))
        XCTAssertNil(operation("How many apples?"))
        XCTAssertEqual(operation("What day of the week was July 4, 1976?")?.expression, .weekdayOf(mention(7, 4, 1976)))
        XCTAssertEqual(operation("Which day was July 4, 1976?")?.expects, .weekday)
        XCTAssertEqual(operation("What day is it?")?.expression, .anchor(.today))
        XCTAssertEqual(operation("What's tomorrow's date?")?.expression, .anchor(.tomorrow))
        XCTAssertNil(operation("Is it raining today?"))
        XCTAssertNil(operation("Is it raining?"))
        XCTAssertEqual(operation("Hello there. What day is it today?")?.expression, .anchor(.today))
    }

    func withYear(_ month: Int, _ day: Int) -> DateMention {
        var mention = mention(month, day, 2026)
        mention.yearSource = .text
        return mention
    }

    func testBinding() {
        XCTAssertEqual(bound("Is 2100 a leap year?", "No, it is not."), .truth(false))
        XCTAssertEqual(bound("Is 2100 a leap year?", "Yes."), .truth(true))
        XCTAssertNil(bound("Is 2100 a leap year?", "It is."))
        XCTAssertNil(bound("Is 2100 a leap year?", ""))
        XCTAssertNil(bound("Is 2100 a leap year?", ", yes"))
        XCTAssertEqual(bound("What day was July 4, 1976?", "It was a Sunday."), .weekday(.sunday))
        XCTAssertEqual(bound("When is the third Tuesday of March 2026?", "The 17th."), .dayOfMonth(17))
        XCTAssertEqual(bound("What date is 90 days after March 3, 2026?", "June 1, 2026. That is after June 15."), .date(mention(6, 1, 2026)))
        XCTAssertEqual(bound("What date is 90 days after March 3, 2026?", "From March 3, 2026 it lands on June 1, 2026."),
                       .date(mention(6, 1, 2026)))
        XCTAssertEqual(bound("What date is 90 days after March 3, 2026?", "28 days in, it is March 31; at 90 it is June 1, 2026."),
                       .date(mention(6, 1, 2026)))
        XCTAssertNil(bound("What date is 90 days after March 3, 2026?", "Maybe June 1, 2026 or June 2, 2026."))
        XCTAssertNil(bound("What date is 90 days after March 3, 2026?", "Not sure."))
        XCTAssertEqual(bound("How many days until June 1, 2026?", "About 13 weeks, or 90 days."), .count(90, .exact))
        XCTAssertEqual(bound("How many days until June 1, 2026?", "Roughly 90."), .count(90, .approximately))
        XCTAssertEqual(bound("How many weeks until June 1, 2026?", "90 days."), nil)
    }
}
