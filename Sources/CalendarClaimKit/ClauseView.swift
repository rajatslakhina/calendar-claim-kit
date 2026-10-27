/// A number and the calendar unit after it, and the index after both.
struct Amount: Sendable, Hashable {
    let amount: Int
    let unit: CalendarUnit
    let next: Int
}

/// Small matchers over one clause's pieces, shared by the answer and question readers.
struct ClauseView {
    let pieces: [Piece]
    /// The last date of the sentences before this one: what "90 days later" counts from when this
    /// sentence names no date before it.
    var priorDate: DateMention?

    static let subjects: Set = ["it", "that", "which", "this"]
    static let copulas: Set = [
        "is", "was", "are", "were", "it's", "that's", "has", "had", "gives", "becomes",
        "falls", "fell", "lands", "landed"
    ]
    static let negatedCopulas: Set = ["isn't", "wasn't", "hasn't"]
    static let fillers: Set = ["on", "a", "an", "the", "exactly", "also"]
    /// Words that make the date after them an input ("after March 3"), not the subject of a sentence.
    static let inputMarkers: Set = [
        "after", "from", "before", "past", "following", "since", "until", "till", "than", "to",
        "plus", "minus", "between", "and", "in", "through", "thru"
    ]

    subscript(index: Int) -> Piece? {
        pieces.indices.contains(index) ? pieces[index] : nil
    }

    func word(_ index: Int) -> String? { self[index]?.word }

    func isMark(_ index: Int, _ text: String) -> Bool { self[index] == .mark(text) }

    /// "is", "was", "will be", "falls on", "=", "isn't", "it's", with "not", "on", "a", "the" after them.
    /// Returns the index after the copula and whether it was negated.
    func copula(at start: Int) -> (next: Int, negated: Bool)? {
        var index = start
        if let subject = word(index), Self.subjects.contains(subject) { index += 1 }
        var negated = false
        switch self[index] {
        case .mark("="):
            index += 1
        case .word(let verb) where Self.copulas.contains(verb):
            index += 1
        case .word(let verb) where Self.negatedCopulas.contains(verb):
            index += 1
            negated = true
        case .word(let verb) where ["will", "would", "won't"].contains(verb) && word(index + 1) == "be":
            index += 2
            negated = verb == "won't"
        default:
            return nil
        }
        if word(index) == "not" {
            negated = true
            index += 1
        }
        while let filler = word(index), Self.fillers.contains(filler) { index += 1 }
        return (index, negated)
    }

    /// "90 days", "a month", "5 business days", "90-day".
    func amount(at index: Int) -> Amount? {
        guard case .number(let amount) = self[index] else { return nil }
        let unitIndex = isMark(index + 1, "-") ? index + 2 : index + 1
        guard case .unit(let unit) = self[unitIndex] else { return nil }
        return Amount(amount: amount, unit: unit, next: unitIndex + 1)
    }

    /// "after", "from", "past", "following", "later than" count forwards; "before", "prior to",
    /// "earlier than" count backwards.
    func direction(at index: Int) -> (sign: Int, next: Int)? {
        switch word(index) {
        case "after", "from", "past", "following": (1, index + 1)
        case "before": (-1, index + 1)
        case "later" where word(index + 1) == "than": (1, index + 2)
        case "earlier" where word(index + 1) == "than": (-1, index + 2)
        case "prior" where word(index + 1) == "to": (-1, index + 2)
        default: nil
        }
    }

    /// A date, "today", "tomorrow", "yesterday" or "now".
    func base(at index: Int) -> (DateBase, Int)? {
        switch self[index] {
        case .date(let mention): (.date(mention), index + 1)
        case .anchor(let anchor): (.anchor(anchor), index + 1)
        case .word("now"): (.anchor(.today), index + 1)
        default: nil
        }
    }

    /// A date, a weekday or "the 17th": what a calendar expression comes to.
    func dayValue(at index: Int) -> CalendarValue? {
        switch self[index] {
        case .date(let mention): .date(mention)
        case .weekday(let weekday): .weekday(weekday)
        case .dayOfMonth(let day): .dayOfMonth(day)
        default: nil
        }
    }

    /// "about", "roughly", "nearly", "over", "under", "more than", "less than", "fewer than",
    /// "just over", "just under" before the number at `index`.
    func qualifier(before index: Int) -> Qualifier {
        let previous = word(index - 1)
        if previous == "than" {
            return word(index - 2) == "more" ? .over : (["less", "fewer"].contains(word(index - 2)) ? .under : .exact)
        }
        return previous.flatMap { Lexicon.qualifiers[$0] } ?? .exact
    }

    /// The value on the far side of a copula after `end` ("... is June 1", "... later on June 1"), or
    /// the value whose copula ends exactly at `start` ("June 1 is ..."), with the negation either way.
    func dayValue(around start: Int, end: Int) -> (CalendarValue, Bool)? {
        let after = isMark(end, ",") ? end + 1 : end
        if let (next, negated) = copula(at: after), let value = dayValue(at: next) { return (value, negated) }
        if word(after) == "on", let value = dayValue(at: after + 1) { return (value, false) }
        for subject in stride(from: start - 1, through: max(0, start - 3), by: -1) {
            if let value = dayValue(at: subject), let (next, negated) = copula(at: subject + 1), next == start {
                return (value, negated)
            }
        }
        return nil
    }

    /// True when the date at `index` is an input to something else ("after March 3").
    /// True when a copula ends exactly at `index`: "it's June 1", "lands on June 1".
    func followsCopula(_ index: Int) -> Bool {
        (max(0, index - 4)..<index).contains { copula(at: $0)?.next == index }
    }

    func isInput(_ index: Int) -> Bool {
        if let previous = word(index - 1), Self.inputMarkers.contains(previous) { return true }
        return isMark(index - 1, "+") || isMark(index - 1, "-")
    }
}
