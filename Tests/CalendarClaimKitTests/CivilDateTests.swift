@testable import CalendarClaimKit
import XCTest

final class CivilDateTests: XCTestCase {
    func testValidityAndDayNumbers() {
        XCTAssertNil(CivilDate(year: 2025, month: 4, day: 31))
        XCTAssertNil(CivilDate(year: 2027, month: 2, day: 29))
        XCTAssertNil(CivilDate(year: 2026, month: 13, day: 1))
        XCTAssertNil(CivilDate(year: 2026, month: 1, day: 0))
        XCTAssertNil(CivilDate(year: 0, month: 1, day: 1))
        XCTAssertNil(CivilDate(year: 10_000, month: 1, day: 1))
        XCTAssertEqual(CivilDate(year: 2024, month: 2, day: 29)?.dayNumber, 19_782)
        let known: [(CivilDate, Int)] = [
            (date(1970, 1, 1), 0), (date(2000, 3, 1), 11_017), (date(9999, 12, 31), 2_932_896),
            (date(1, 1, 1), -719_162), (date(1600, 2, 29), -135_081)
        ]
        for (day, number) in known {
            XCTAssertEqual(day.dayNumber, number, "\(day)")
            XCTAssertEqual(CivilDate(dayNumber: number), day)
        }
    }

    func testWeekdaysAndArithmetic() {
        XCTAssertEqual(date(1970, 1, 1).weekday, .thursday)
        XCTAssertEqual(date(2026, 3, 17).weekday, .tuesday)
        XCTAssertEqual(date(1976, 7, 4).weekday, .sunday)
        XCTAssertEqual(date(2026, 3, 3).adding(days: 90), date(2026, 6, 1))
        XCTAssertEqual(date(2026, 1, 31).adding(months: 1), date(2026, 2, 28))
        XCTAssertEqual(date(2024, 1, 31).adding(months: 1), date(2024, 2, 29))
        XCTAssertEqual(date(2026, 12, 15).adding(months: 1), date(2027, 1, 15))
        XCTAssertEqual(date(2026, 3, 31).adding(months: -1), date(2026, 2, 28))
        XCTAssertEqual(date(2026, 1, 1).days(until: date(2026, 2, 14)), 44)
        XCTAssertTrue(date(2026, 1, 1) < date(2026, 1, 2))
        XCTAssertEqual(date(2026, 3, 17).description, "March 17, 2026")
    }

    func testLeapYearsAndMonthLengths() {
        XCTAssertTrue(CivilDate.isLeap(2000))
        XCTAssertTrue(CivilDate.isLeap(2024))
        XCTAssertFalse(CivilDate.isLeap(1900))
        XCTAssertFalse(CivilDate.isLeap(2100))
        XCTAssertFalse(CivilDate.isLeap(2026))
        XCTAssertEqual((1...12).map { CivilDate.daysIn(month: $0, year: 2026) }, [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
        XCTAssertEqual(CivilDate.daysIn(month: 2, year: 2028), 29)
    }

    func testDateInTimeZone() {
        XCTAssertEqual(CivilDate(october27, in: .gmt), date(2026, 10, 27))
        let tokyo = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        XCTAssertEqual(CivilDate(Date(timeIntervalSince1970: 1_793_140_200), in: .gmt), date(2026, 10, 27))
        XCTAssertEqual(CivilDate(Date(timeIntervalSince1970: 1_793_140_200), in: tokyo), date(2026, 10, 28))
    }

    func testWeekdayNamesAndOrder() {
        XCTAssertEqual(Weekday.allCases.map(\.name), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        XCTAssertTrue(Weekday.monday < .sunday)
    }

    func testBusinessCalendar() {
        let standard = BusinessCalendar.standard
        XCTAssertFalse(standard.isBusinessDay(date(2026, 10, 31)))
        XCTAssertEqual(standard.adding(businessDays: 1, to: date(2026, 10, 30)), date(2026, 11, 2))
        XCTAssertEqual(standard.adding(businessDays: -1, to: date(2026, 11, 2)), date(2026, 10, 30))
        XCTAssertEqual(standard.adding(businessDays: 0, to: date(2026, 10, 31)), date(2026, 10, 31))
        XCTAssertEqual(standard.businessDays(from: date(2026, 3, 2), to: date(2026, 3, 16)), 10)
        XCTAssertEqual(standard.businessDays(from: date(2026, 3, 16), to: date(2026, 3, 2)), 10)
        let christmas = BusinessCalendar(holidays: [date(2026, 12, 25)])
        XCTAssertEqual(christmas.adding(businessDays: 1, to: date(2026, 12, 24)), date(2026, 12, 28))
        XCTAssertFalse(christmas.isBusinessDay(date(2026, 12, 25)))
        let never = BusinessCalendar(weekend: Set(Weekday.allCases))
        XCTAssertEqual(never.adding(businessDays: 3, to: date(2026, 1, 1)), date(2026, 1, 1))
    }
}
