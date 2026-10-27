@testable import CalendarClaimKit
import XCTest

final class EvaluatorTests: XCTestCase {
    let evaluator = CalendarEvaluator(business: .standard, today: date(2026, 10, 27))
    let noClock = CalendarEvaluator(business: .standard, today: nil)

    func claim(_ expression: CalendarExpression, _ value: CalendarValue, negated: Bool = false) -> CalendarClaim {
        CalendarClaim(expression: expression, asserted: value, negated: negated, quote: "", origin: .answer, guessedYear: false)
    }

    func status(_ expression: CalendarExpression, _ value: CalendarValue, on evaluator: CalendarEvaluator? = nil) -> CheckStatus {
        (evaluator ?? self.evaluator).check(claim(expression, value)).status
    }

    func testSpansByUnit() {
        let march3 = DateBase.date(mention(3, 3, 2026))
        let june1 = DateBase.date(mention(6, 1, 2026))
        XCTAssertEqual(status(.span(from: june1, to: march3, unit: .day, inclusive: false), .count(90, .exact)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .day, inclusive: true), .count(91, .exact)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .day, inclusive: true), .count(90, .exact)), .contradicted)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(12, .exact)), .conventionDependent)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(13, .approximately)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(12, .over)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(13, .over)), .contradicted)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(13, .under)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(12, .under)), .contradicted)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .week, inclusive: false), .count(15, .approximately)), .contradicted)
        let week = DateBase.date(mention(3, 10, 2026))
        XCTAssertEqual(status(.span(from: march3, to: week, unit: .week, inclusive: false), .count(1, .exact)), .verified)
        XCTAssertEqual(status(.span(from: march3, to: june1, unit: .month, inclusive: false), .count(2, .exact)), .conventionDependent)
        XCTAssertEqual(status(.span(from: march3, to: .date(mention(5, 3, 2026)), unit: .month, inclusive: false), .count(2, .exact)), .verified)
        let early = DateBase.date(mention(3, 3, 2020))
        let outcome = evaluator.outcome(.span(from: early, to: june1, unit: .year, inclusive: false))
        guard case .count(_, let whole, let truth, _, _) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(whole, 6)
        XCTAssertEqual(truth, "March 3, 2020 to June 1, 2026 is 6 years, 2 months and 29 days")
        let monthOutcome = evaluator.outcome(.span(from: .date(mention(1, 31, 2026)), to: .date(mention(3, 1, 2026)), unit: .month, inclusive: false))
        guard case .count(_, let months, let monthTruth, _, _) = monthOutcome else { return XCTFail() }
        XCTAssertEqual(months, 1)
        XCTAssertEqual(monthTruth, "January 31, 2026 to March 1, 2026 is 1 month and 1 day")
    }

    func testBusinessSpans() {
        let monday = DateBase.date(mention(3, 2, 2026))
        let nextMonday = DateBase.date(mention(3, 16, 2026))
        XCTAssertEqual(status(.span(from: monday, to: nextMonday, unit: .businessDay, inclusive: false), .count(11, .exact)), .conventionDependent)
        XCTAssertEqual(status(.span(from: monday, to: nextMonday, unit: .businessDay, inclusive: true), .count(11, .exact)), .verified)
        let sunday = DateBase.date(mention(3, 1, 2026))
        let check = evaluator.check(claim(.span(from: sunday, to: nextMonday, unit: .businessDay, inclusive: false), .count(11, .exact)))
        XCTAssertEqual(check.status, .verified)
        XCTAssertEqual(check.truth, "March 1, 2026 to March 16, 2026 is 11 business days")
    }

    func testDayOutcomes() {
        XCTAssertEqual(status(.offset(base: .date(mention(10, 30, 2026)), amount: 1, unit: .businessDay), .weekday(.monday)), .verified)
        XCTAssertEqual(status(.offset(base: .date(mention(1, 1, 2026)), amount: 2, unit: .year), .date(mention(1, 1, 2028))), .verified)
        XCTAssertEqual(status(.offset(base: .anchor(.yesterday), amount: 1, unit: .week), .date(mention(11, 2, 2026))), .verified)
        XCTAssertEqual(status(.offset(base: .anchor(.today), amount: 1, unit: .day), .date(mention(10, 28, 2027))), .contradicted)
        XCTAssertEqual(status(.nthWeekday(ordinal: 5, weekday: .monday, month: MonthMention(month: 3, year: 2026)), .dayOfMonth(30)), .verified)
        XCTAssertEqual(status(.nthWeekday(ordinal: -1, weekday: .friday, month: MonthMention(month: 10, year: 2026)), .dayOfMonth(30)), .verified)
        let none = evaluator.check(claim(.nthWeekday(ordinal: 5, weekday: .sunday, month: MonthMention(month: 2, year: 2026)), .dayOfMonth(29)))
        XCTAssertEqual(none.status, .contradicted)
        XCTAssertEqual(none.truth, "February 2026 has no fifth Sunday")
        XCTAssertEqual(status(.nthWeekday(ordinal: 1, weekday: .monday, month: MonthMention(month: 3, year: nil)), .dayOfMonth(2)), .unresolved)
        XCTAssertEqual(status(.relative(.this, .tuesday), .date(mention(10, 27, 2026))), .verified)
        XCTAssertEqual(status(.relative(.next, .tuesday), .date(mention(11, 3, 2026))), .verified)
        XCTAssertEqual(status(.relative(.last, .tuesday), .date(mention(10, 20, 2026))), .verified)
        XCTAssertEqual(status(.relative(.last, .friday), .date(mention(10, 16, 2026))), .conventionDependent)
        XCTAssertEqual(status(.relative(.last, .friday), .date(mention(10, 9, 2026))), .contradicted)
        XCTAssertEqual(status(.relative(.next, .friday), .date(mention(10, 30, 2026)), on: noClock), .unresolved)
        XCTAssertEqual(status(.anchor(.today), .weekday(.tuesday), on: noClock), .unresolved)
        XCTAssertEqual(status(.weekdayOf(mention(3, 17, nil)), .weekday(.tuesday)), .unresolved)
        let missing = evaluator.check(claim(.weekdayOf(mention(4, 31, 2025)), .weekday(.thursday)))
        XCTAssertEqual(missing.truth, "April 31, 2025 does not exist: April 2025 has 30 days")
    }

    func testLengthsAndTruth() {
        XCTAssertEqual(status(.yearLength(2028), .count(366, .exact)), .verified)
        XCTAssertEqual(status(.monthLength(MonthMention(month: 2, year: nil)), .count(29, .exact)), .conventionDependent)
        XCTAssertEqual(status(.monthLength(MonthMention(month: 2, year: nil)), .count(28, .exact)), .verified)
        XCTAssertEqual(status(.monthLength(MonthMention(month: 4, year: nil)), .count(31, .exact)), .contradicted)
        XCTAssertEqual(status(.leapYear(2024), .truth(true)), .verified)
        XCTAssertEqual(evaluator.check(claim(.leapYear(2024), .truth(false), negated: true)).status, .verified)
    }

    func testValuesOfTheWrongKind() {
        XCTAssertFalse(CalendarEvaluator.matches(.count(3, .exact), date(2026, 1, 3)))
        XCTAssertEqual(CalendarEvaluator.judge(.weekday(.monday), exact: 3, whole: 3, alternate: nil, why: nil).0, .contradicted)
        XCTAssertEqual(Describe.count(.weekday(.monday), .day), "a Monday")
        XCTAssertEqual(Describe.ordinal(-1), "last")
    }
}
