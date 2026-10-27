@testable import CalendarClaimKit
import XCTest

final class CheckerTests: XCTestCase {
    func testVerdicts() {
        XCTAssertEqual(check("Nothing about dates.").verdict, .noClaims)
        XCTAssertEqual(check("March 17, 2026 is a Tuesday.").verdict, .verified)
        XCTAssertEqual(check("From March 3 to June 1, 2026 is 91 days.").verdict, .conventionDependent)
        XCTAssertEqual(check("March 17, 2026 is a Monday.").verdict, .contradicted)
        XCTAssertEqual(check("Meet on February 30.").verdict, .contradicted)
        XCTAssertEqual(check("Next Friday is October 30.", now: nil).verdict, .unverifiable)
    }

    func testImpossibleDatesOnceEach() {
        let report = check("April 31, 2025 or April 31, 2025, and February 30.", now: nil)
        XCTAssertEqual(report.checks.map(\.truth), ["April 2025 has 30 days", "February 2025 has 28 days"])
        XCTAssertEqual(check("Meet on February 30.", now: nil).checks.map(\.truth), ["February has at most 29 days"])
        XCTAssertEqual(report.corrections.first, "April 31, 2025 does not exist: April 2025 has 30 days.")
    }

    func testGuessedYears() {
        let next = check("March 17 is a Wednesday.")
        XCTAssertEqual(next.checks.first?.status, .conventionDependent)
        XCTAssertEqual(next.checks.first?.reason, "true for 2027; the year was not stated and 2026 was assumed")
        let previous = check("March 17 is a Monday.")
        XCTAssertEqual(previous.checks.first?.reason, "true for 2025; the year was not stated and 2026 was assumed")
        XCTAssertEqual(check("March 17 is a Friday.").checks.first?.status, .contradicted)
        XCTAssertEqual(check("March 17 is a Wednesday.", contextYear: 2026).checks.first?.status, .contradicted)
    }

    func testQuestionsAndDeduplication() {
        let bound = check("A Sunday.", question: "What day of the week was July 4, 1976?")
        XCTAssertEqual(bound.checks.map(\.claim?.origin), [.question])
        let explicit = check("July 4, 1976 was a Sunday.", question: "What day of the week was July 4, 1976?")
        XCTAssertEqual(explicit.checks.map(\.claim?.origin), [.answer])
        let fromQuestionYear = check("March 17 is a Tuesday.", question: "In 2026, what day is March 17?", now: nil)
        XCTAssertEqual(statuses(fromQuestionYear), [.verified])
        XCTAssertEqual(check("Nothing.", question: "Is 2100 a leap year?").checks, [])
        XCTAssertEqual(check("Sunny.", question: "Will it rain?").checks, [])
    }

    func testNoteAndFeedback() {
        let report = check("March 17, 2026 is a Monday. July 4, 1976 was not a Sunday. From March 3 to June 1, 2026 is 91 days.")
        XCTAssertEqual(report.corrections, [
            "March 17, 2026 is a Tuesday (the answer said a Monday).",
            "July 4, 1976 is a Sunday (the answer said \"July 4, 1976 is not a Sunday\")."
        ])
        XCTAssertEqual(report.caveats, ["March 3, 2026 to June 1, 2026 is 91 days: true only counting both ends."])
        XCTAssertEqual(report.note, "Calendar check: " + (report.corrections + report.caveats).joined(separator: " "))
        XCTAssertEqual(report.feedback, """
        Some calendar facts in your answer are wrong. These values were computed on the Gregorian calendar:
        - March 17, 2026 is a Tuesday
        - July 4, 1976 is a Sunday
        Correct the answer with these values and keep everything else.
        """)
        let clean = check("March 17, 2026 is a Tuesday.")
        XCTAssertNil(clean.note)
        XCTAssertNil(clean.feedback)
        XCTAssertEqual(check("2100 is a leap year.").corrections, ["2100 is not a leap year (the answer said \"2100 is a leap year\")."])
        XCTAssertEqual(check("2027 has 366 days; April has 31 days.").corrections, [
            "2027 has 365 days (the answer said 366 days).", "April 2027 has 30 days (the answer said 31 days)."
        ])
        XCTAssertEqual(check("There are 14 business days between March 2 and March 16, 2026.").corrections.first,
                       "March 2, 2026 to March 16, 2026 is 10 business days (11 counting both ends) (the answer said 14 business days).")
        XCTAssertEqual(check("This is not 2027").caveats, [])
    }

    func testDescribeStatements() {
        XCTAssertEqual(check("2100 is not a leap year.").checks.first?.statement, "2100 is not a leap year")
        XCTAssertEqual(check("February 2028 has 29 days.").checks.first?.statement, "February 2028 has 29 days")
        XCTAssertEqual(check("Today is October 27, 2026.").checks.first?.truth, "today is Tuesday, October 27, 2026")
        XCTAssertEqual(check("3 days ago was Saturday.").checks.first?.truth,
                       "3 days before today (October 27, 2026) is Saturday, October 24, 2026")
        XCTAssertEqual(CalendarChecker().timeZone, .current)
    }

    func testSessionCarriesTheYear() async {
        let session = CalendarSession(checker: utcChecker)
        await session.review(answer: "Sure.", question: "Plan the 2027 offsite.", now: october27)
        let report = await session.review(answer: "March 17 is a Wednesday.", question: "Is March 17 free?", now: october27)
        XCTAssertEqual(statuses(report), [.verified])
        await session.review(answer: "June 1, 2030 is a Saturday, and February 30 too.")
        await session.review(answer: "Next Friday is October 30.")
        await session.review(answer: "From March 3 to June 1, 2026 is 91 days.")
        let year = await session.contextYear
        XCTAssertEqual(year, 2026)
        let totals = await session.totals
        XCTAssertEqual(totals.turns, 5)
        XCTAssertEqual(totals.checks, 5)
        XCTAssertEqual(totals.verified, 2)
        XCTAssertEqual(totals.impossibleDates, 1)
        XCTAssertEqual(totals.unresolved, 1)
        XCTAssertEqual(totals.conventionDependent, 1)
        XCTAssertEqual(totals.contradicted, 0)
        let last = await session.lastReport
        XCTAssertEqual(last?.verdict, .conventionDependent)
        XCTAssertEqual(session.checker.timeZone, .gmt)
    }
}
