import Foundation

/// A day of the week, numbered as ISO 8601 does: Monday is 1, Sunday is 7.
public enum Weekday: Int, Sendable, Hashable, CaseIterable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A day on the Gregorian calendar with no time of day and no time zone: what "March 17, 2026" means
/// in a sentence. Arithmetic is done on a day count, so it does not depend on `Calendar`, a locale or
/// daylight saving.
///
/// Years run from 1 to 9999. The reader only reads four-digit years, and the amounts it reads are small
/// enough that adding them to such a year stays in range.
public struct CivilDate: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Returns nil for a day that does not exist: April 31, February 29 in 2027, month 13, day 0.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month),
              day >= 1, day <= CivilDate.daysIn(month: month, year: year) else { return nil }
        self.init(valid: year, month, day)
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.init(
            valid: calendar.component(.year, from: date),
            calendar.component(.month, from: date),
            calendar.component(.day, from: date)
        )
    }

    init(valid year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01 (H. Hinnant's `days_from_civil`, for years ≥ 1).
    public var dayNumber: Int {
        let shifted = month <= 2 ? year - 1 : year
        let era = shifted / 400
        let yearOfEra = shifted - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The inverse of `dayNumber` (`civil_from_days`).
    init(dayNumber: Int) {
        let shifted = dayNumber + 719_468
        let era = shifted / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        self.init(
            valid: yearOfEra + era * 400 + (month <= 2 ? 1 : 0),
            month,
            dayOfYear - (153 * monthIndex + 2) / 5 + 1
        )
    }

    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        Weekday.allCases[(dayNumber % 7 + 7 + 3) % 7]
    }

    public func adding(days: Int) -> CivilDate { CivilDate(dayNumber: dayNumber + days) }

    /// Adds calendar months and clamps to the end of a shorter month: one month after March 31 is
    /// April 30, the rule `Calendar`, `java.time` and Python's `dateutil` all follow.
    public func adding(months: Int) -> CivilDate {
        let total = year * 12 + (month - 1) + months
        let newYear = total / 12
        let newMonth = total % 12 + 1
        return CivilDate(valid: newYear, newMonth, min(day, CivilDate.daysIn(month: newMonth, year: newYear)))
    }

    public func days(until other: CivilDate) -> Int { other.dayNumber - dayNumber }

    public static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    public static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    public static func monthName(_ month: Int) -> String { monthNames[month - 1] }

    static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    /// "March 17, 2026".
    public var description: String { "\(CivilDate.monthName(month)) \(day), \(year)" }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool { lhs.dayNumber < rhs.dayNumber }
}
