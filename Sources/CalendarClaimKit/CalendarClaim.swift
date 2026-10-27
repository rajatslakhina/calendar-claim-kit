/// Where a year came from when the text did not attach one to the date.
public enum YearSource: String, Sendable, Hashable {
    case stated
    /// Another date or year in the same text: "between March 1 and April 1, 2026".
    case text = "from the text"
    /// An earlier turn of the conversation, or the question being answered.
    case context = "from the conversation"
    /// The current year, because nothing else gave one.
    case today = "from today's date"
    case missing
}

/// A date as a sentence wrote it. The day may not exist ("April 31, 2025"); the year may be missing.
public struct DateMention: Sendable, Hashable, CustomStringConvertible {
    public let month: Int
    public let day: Int
    public internal(set) var year: Int?
    public internal(set) var yearSource: YearSource
    /// "Tuesday" in "Tuesday, March 17, 2026".
    public let statedWeekday: Weekday?

    init(month: Int, day: Int, year: Int?, statedWeekday: Weekday? = nil) {
        self.month = month
        self.day = day
        self.year = year
        self.yearSource = year == nil ? .missing : .stated
        self.statedWeekday = statedWeekday
    }

    public var civil: CivilDate? { year.flatMap { CivilDate(year: $0, month: month, day: day) } }

    /// True for a day that cannot exist: in the year the text gave, or in any year when it gave none
    /// (February 29 exists in leap years, February 30 never does). A year guessed from the
    /// conversation or the clock is not enough to call February 29 impossible.
    public var isImpossible: Bool {
        if year != nil, yearSource == .stated || yearSource == .text { return civil == nil }
        return day > CivilDate.daysIn(month: month, year: 2000)
    }

    /// "March 17, 2026", or "March 17" when no year was given or guessed.
    public var description: String {
        let base = "\(CivilDate.monthName(month)) \(day)"
        return year.map { "\(base), \($0)" } ?? base
    }
}

/// A month as a sentence wrote it: "March 2026", or "March".
public struct MonthMention: Sendable, Hashable, CustomStringConvertible {
    public let month: Int
    public internal(set) var year: Int?
    public internal(set) var yearSource: YearSource

    init(month: Int, year: Int?) {
        self.month = month
        self.year = year
        self.yearSource = year == nil ? .missing : .stated
    }

    public var description: String {
        let name = CivilDate.monthName(month)
        return year.map { "\(name) \($0)" } ?? name
    }
}

public enum CalendarUnit: String, Sendable, Hashable, CaseIterable {
    case day, week, month, year
    case businessDay = "business day"

    /// "1 day", "90 days", "5 business days".
    public func phrase(_ amount: Int) -> String {
        "\(amount) \(rawValue)\(abs(amount) == 1 ? "" : "s")"
    }
}

public enum Anchor: String, Sendable, Hashable {
    case today, tomorrow, yesterday

    var offset: Int {
        switch self {
        case .today: 0
        case .tomorrow: 1
        case .yesterday: -1
        }
    }
}

/// "next Friday", "this Friday", "last Friday".
public enum RelativeWeek: String, Sendable, Hashable {
    case next, this, last
}

/// The start or end of a span, or the base of an offset.
public enum DateBase: Sendable, Hashable, CustomStringConvertible {
    case date(DateMention)
    case anchor(Anchor)

    public var description: String {
        switch self {
        case .date(let mention): mention.description
        case .anchor(let anchor): anchor.rawValue
        }
    }
}

/// Something the calendar can answer.
public enum CalendarExpression: Sendable, Hashable {
    case weekdayOf(DateMention)
    /// `amount` is signed: negative counts backwards ("3 days before", "3 days ago").
    case offset(base: DateBase, amount: Int, unit: CalendarUnit)
    case span(from: DateBase, to: DateBase, unit: CalendarUnit, inclusive: Bool)
    /// `ordinal` is 1...5, or -1 for "last".
    case nthWeekday(ordinal: Int, weekday: Weekday, month: MonthMention)
    case leapYear(Int)
    case yearLength(Int)
    case monthLength(MonthMention)
    case anchor(Anchor)
    case relative(RelativeWeek, Weekday)

    public var kind: Kind {
        switch self {
        case .weekdayOf: .weekdayOf
        case .offset: .offset
        case .span: .span
        case .nthWeekday: .nthWeekday
        case .leapYear: .leapYear
        case .yearLength, .monthLength: .length
        case .anchor, .relative: .relative
        }
    }

    public enum Kind: String, Sendable, Hashable {
        case weekdayOf, offset, span, nthWeekday, leapYear, length, relative
    }
}

/// "about", "over", "under", or nothing.
public enum Qualifier: String, Sendable, Hashable {
    case exact = ""
    case approximately = "about"
    case over
    case under
}

/// What the text says the expression comes to.
public enum CalendarValue: Sendable, Hashable, CustomStringConvertible {
    case date(DateMention)
    /// "the 17th"
    case dayOfMonth(Int)
    case weekday(Weekday)
    case count(Int, Qualifier)
    case truth(Bool)

    public var description: String {
        switch self {
        case .date(let mention): mention.description
        case .dayOfMonth(let day): "the \(day)\(CalendarValue.suffix(day))"
        case .weekday(let weekday): "a \(weekday.name)"
        case .count(let amount, let qualifier): qualifier == .exact ? "\(amount)" : "\(qualifier.rawValue) \(amount)"
        case .truth(let value): value ? "yes" : "no"
        }
    }

    static func suffix(_ day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}

/// One calendar statement found in a text: an expression and the value the text gives it.
public struct CalendarClaim: Sendable, Hashable {
    public enum Origin: String, Sendable, Hashable {
        /// The answer states both sides: "March 17, 2026 is a Monday".
        case answer
        /// The question asked for the value and the answer gave it: "What day is March 17, 2026?" /
        /// "A Monday."
        case question
    }

    public let expression: CalendarExpression
    public let asserted: CalendarValue
    public let negated: Bool
    /// The sentence the claim was read from, as written.
    public let quote: String
    public let origin: Origin
    /// True when a year in the claim's sentence came from today's date because nothing else gave one.
    public let guessedYear: Bool
}
