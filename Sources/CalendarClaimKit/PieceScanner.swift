/// Turns tokens into pieces. Dates are recognised first, so "March 17, 2026" and "Tue 17 Mar 2026"
/// become one piece each; "May" is a month only when capitalised.
struct PieceScanner {
    let tokens: [Token]

    static let fullMonthNames = Set(CivilDate.monthNames.map { $0.lowercased() })

    func piece(at index: Int) -> (Piece, Int) {
        let token = tokens[index]
        switch token.kind {
        case .boundary: return (.boundary, index + 1)
        case .mark: return (.mark(token.text), index + 1)
        case .iso: return (isoDate(token), index + 1)
        case .number, .word: return wordOrNumber(at: index)
        }
    }

    func isoDate(_ token: Token) -> Piece {
        let parts = token.text.split(separator: "-").compactMap { Int($0) }
        guard (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return .word(token.lower) }
        return .date(DateMention(month: parts[1], day: parts[2], year: parts[0]))
    }

    func wordOrNumber(at index: Int) -> (Piece, Int) {
        if let (mention, next) = date(at: index) { return (.date(mention), next) }
        let token = tokens[index]
        let lower = token.lower
        if let weekday = Lexicon.weekdays[lower], lower.count >= 6 { return (.weekday(weekday), index + 1) }
        if let ordinal = ordinalBeforeWeekday(at: index) { return (.ordinal(ordinal), index + 1) }
        if let number = numberPiece(at: index) { return (number, index + 1) }
        if let (unit, next) = unit(at: index) { return (.unit(unit), next) }
        if let value = Lexicon.numberWord(lower) { return (.number(value), index + 1) }
        if lower == "a" || lower == "an", unit(at: index + 1) != nil { return (.number(1), index + 1) }
        if let (month, next) = monthPiece(at: index) { return (.month(month), next) }
        if let anchor = Lexicon.anchors[lower] { return (.anchor(anchor), index + 1) }
        return (.word(lower), index + 1)
    }

    /// "17th" as a day of the month, "2026" as a year (unless a unit follows: "2000 days"), "90".
    func numberPiece(at index: Int) -> Piece? {
        let token = tokens[index]
        if let day = Lexicon.suffixedNumber(token.text), (1...31).contains(day) { return .dayOfMonth(day) }
        guard token.kind == .number, let value = Lexicon.plainNumber(token.text) else { return nil }
        if let year = Lexicon.year(token.text), unit(at: index + 1) == nil { return .year(year) }
        return .number(value)
    }

    // MARK: - Dates

    /// An optional weekday, then "March 17, 2026", "17 March 2026", "17th of March" or "Mar. 17".
    func date(at start: Int) -> (DateMention, Int)? {
        var index = start
        var weekday: Weekday?
        if let named = Lexicon.weekdays[tokens[index].lower] {
            weekday = named
            index += isMark(index + 1, ",") ? 2 : 1
        }
        guard let (found, next) = monthFirst(at: index) ?? dayFirst(at: index) else { return nil }
        return (DateMention(month: found.month, day: found.day, year: found.year, statedWeekday: weekday), next)
    }

    func monthFirst(at index: Int) -> (DateMention, Int)? {
        guard let (month, afterMonth) = month(at: index), let day = day(at: afterMonth) else { return nil }
        let (year, next) = trailingYear(after: afterMonth + 1)
        return (DateMention(month: month, day: day, year: year), next)
    }

    func dayFirst(at index: Int) -> (DateMention, Int)? {
        guard let day = day(at: index) else { return nil }
        let monthIndex = word(at: index + 1) == "of" ? index + 2 : index + 1
        guard let (month, afterMonth) = month(at: monthIndex) else { return nil }
        let (year, next) = trailingYear(after: afterMonth)
        return (DateMention(month: month, day: day, year: year), next)
    }

    /// A month name or abbreviation, and the index after it (and after an abbreviation's full stop).
    func month(at index: Int) -> (Int, Int)? {
        guard index < tokens.count, let month = Lexicon.months[tokens[index].lower],
              tokens[index].lower != "may" || tokens[index].text == "May" else { return nil }
        let abbreviated = !Self.fullMonthNames.contains(tokens[index].lower)
        let next = abbreviated && index + 1 < tokens.count && tokens[index + 1].text == "." ? index + 2 : index + 1
        return (month, next)
    }

    /// "March 2026" or a lone full month name: "the third Tuesday in March".
    func monthPiece(at index: Int) -> (MonthMention, Int)? {
        guard let (month, next) = month(at: index) else { return nil }
        if let year = year(at: next) { return (MonthMention(month: month, year: year), next + 1) }
        guard Self.fullMonthNames.contains(tokens[index].lower) else { return nil }
        return (MonthMention(month: month, year: nil), index + 1)
    }

    func day(at index: Int) -> Int? {
        guard index < tokens.count, tokens[index].kind == .number else { return nil }
        let text = tokens[index].text
        guard let day = Lexicon.suffixedNumber(text) ?? (text.count <= 2 ? Int(text) : nil),
              (1...31).contains(day) else { return nil }
        return day
    }

    func trailingYear(after index: Int) -> (Int?, Int) {
        if isMark(index, ","), let year = year(at: index + 1) { return (year, index + 2) }
        if let year = year(at: index) { return (year, index + 1) }
        return (nil, index)
    }

    func year(at index: Int) -> Int? {
        guard index < tokens.count, tokens[index].kind == .number else { return nil }
        return Lexicon.year(tokens[index].text)
    }

    // MARK: - Other pieces

    /// "third" or "3rd" before a weekday and then "of" or "in": "the third Tuesday of March".
    /// "last Friday" on its own is relative ("last Friday was the 23rd"), not an ordinal.
    func ordinalBeforeWeekday(at index: Int) -> Int? {
        let text = tokens[index].text
        let numbered = Lexicon.suffixedNumber(text).flatMap { $0 <= 5 ? $0 : nil }
        guard let ordinal = Lexicon.ordinals[text.lowercased()] ?? numbered,
              let next = word(at: index + 1), Lexicon.weekdays[next] != nil, next.count >= 6,
              ["of", "in"].contains(word(at: index + 2)) else { return nil }
        return ordinal
    }

    /// "days", "weeks", "business days", "working days", "weekdays".
    func unit(at index: Int) -> (CalendarUnit, Int)? {
        guard let lower = word(at: index) else { return nil }
        if lower == "business" || lower == "working", ["day", "days"].contains(word(at: index + 1)) {
            return (.businessDay, index + 2)
        }
        return Lexicon.units[lower].map { ($0, index + 1) }
    }

    func word(at index: Int) -> String? {
        index < tokens.count ? tokens[index].lower : nil
    }

    func isMark(_ index: Int, _ text: String) -> Bool {
        index < tokens.count && tokens[index].text == text
    }
}
