/// A recognised unit of a sentence: a date, a weekday, a number with or without a calendar unit, or a
/// plain word. Claims are patterns over pieces, so "March 17, 2026" is one step, not four.
enum Piece: Sendable, Hashable {
    case date(DateMention)
    case month(MonthMention)
    case weekday(Weekday)
    case number(Int)
    /// "17th" not attached to a month.
    case dayOfMonth(Int)
    /// "third" or "last" in "the third Tuesday of March".
    case ordinal(Int)
    case unit(CalendarUnit)
    case year(Int)
    case anchor(Anchor)
    case word(String)
    case mark(String)
    case boundary

    var word: String? {
        if case .word(let word) = self { return word }
        return nil
    }

    /// The year this piece states outright, if any.
    var statedYear: Int? {
        switch self {
        case .date(let mention) where mention.yearSource == .stated: mention.year
        case .month(let mention) where mention.yearSource == .stated: mention.year
        case .year(let year): year
        default: nil
        }
    }
}

/// One sentence or line of a text, as pieces, with its original wording.
struct Clause: Sendable, Hashable {
    var pieces: [Piece]
    let quote: String
    var guessedYear = false
}

/// Years a reading falls back on when a date in the text has none.
struct YearContext: Sendable, Hashable {
    var contextYear: Int?
    var todayYear: Int?
}

struct TextReading: Sendable, Hashable {
    let clauses: [Clause]
    /// Every year the text states, in order.
    let statedYears: [Int]

    var pieces: [Piece] { clauses.flatMap(\.pieces) }

    /// The last date the text names.
    var lastDate: DateMention? {
        ClauseView(pieces: pieces).lastDate(before: pieces.count)
    }
}
