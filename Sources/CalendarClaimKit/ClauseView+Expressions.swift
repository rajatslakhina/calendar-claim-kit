/// An expression found in a clause, with the pieces it covers.
struct Located: Sendable, Hashable {
    let expression: CalendarExpression
    let start: Int
    let end: Int

    static func offset(_ base: DateBase, _ amount: Int, _ unit: CalendarUnit, from start: Int, to end: Int) -> Located {
        Located(expression: .offset(base: base, amount: amount, unit: unit), start: start, end: end)
    }
}

/// The two ends of a span and whether the words count both of them.
struct SpanEnds: Sendable, Hashable {
    let from: DateBase
    let to: DateBase
    let inclusive: Bool
}

/// "the third Tuesday of March 2026"; `month` is nil for "of the month".
struct NthMatch: Sendable, Hashable {
    let ordinal: Int
    let weekday: Weekday
    let month: MonthMention?
    let end: Int
}

extension ClauseView {
    /// "90 days after March 3", "3 weeks from today", "5 business days before June 1", "3 days ago",
    /// "in 10 days", "March 3 + 90 days", "the day after Monday, July 27", and "90 days later" counted
    /// from the last date before it.
    func offset(at index: Int) -> Located? {
        if word(index) == "the", self[index + 1] == .unit(.day), let (sign, afterDirection) = direction(at: index + 2),
           let (base, afterBase) = base(at: afterDirection) {
            return .offset(base, sign, .day, from: index, to: afterBase)
        }
        guard let found = amount(at: index) else { return nil }
        let (amount, unit, afterUnit) = (found.amount, found.unit, found.next)
        if word(afterUnit) == "ago" { return .offset(.anchor(.today), -amount, unit, from: index, to: afterUnit + 1) }
        if let (sign, afterDirection) = direction(at: afterUnit), let (base, afterBase) = base(at: afterDirection) {
            return .offset(base, sign * amount, unit, from: index, to: afterBase)
        }
        if ["later", "earlier"].contains(word(afterUnit)), let base = lastDate(before: index) {
            let sign = word(afterUnit) == "later" ? 1 : -1
            return .offset(.date(base), sign * amount, unit, from: index, to: afterUnit + 1)
        }
        if word(index - 1) == "in" { return .offset(.anchor(.today), amount, unit, from: index - 1, to: afterUnit) }
        let sign = arithmeticSign(before: index)
        guard sign != 0, let (base, _) = base(at: index - 2) else { return nil }
        return .offset(base, sign * amount, unit, from: index - 2, to: afterUnit)
    }

    /// The last date before `index` in this sentence, else the last date of the sentences before it.
    func lastDate(before index: Int) -> DateMention? {
        for piece in pieces[..<index].reversed() {
            if case .date(let mention) = piece { return mention }
        }
        return priorDate
    }

    /// 1 for "+" or "plus" before `index`, -1 for "-" or "minus", 0 otherwise.
    func arithmeticSign(before index: Int) -> Int {
        if isMark(index - 1, "+") || word(index - 1) == "plus" { return 1 }
        return isMark(index - 1, "-") || word(index - 1) == "minus" ? -1 : 0
    }

    /// "between A and B", "from A to B" ("through" counts both ends), "since A", "until B".
    func spanEnds() -> SpanEnds? {
        for index in pieces.indices {
            if let ends = spanEnds(at: index) { return ends }
        }
        return nil
    }

    func spanEnds(at index: Int) -> SpanEnds? {
        switch word(index) {
        case "between":
            guard let (first, afterFirst) = base(at: index + 1), word(afterFirst) == "and",
                  let (second, _) = base(at: afterFirst + 1) else { return nil }
            return SpanEnds(from: first, to: second, inclusive: false)
        case "from":
            guard let (first, afterFirst) = base(at: index + 1), let connector = word(afterFirst),
                  ["to", "until", "till", "through", "thru"].contains(connector),
                  let (second, _) = base(at: afterFirst + 1) else { return nil }
            return SpanEnds(from: first, to: second, inclusive: ["through", "thru"].contains(connector))
        case "since":
            return base(at: index + 1).map { SpanEnds(from: $0.0, to: .anchor(.today), inclusive: false) }
        case "until", "till":
            return base(at: index + 1).map { SpanEnds(from: .anchor(.today), to: $0.0, inclusive: false) }
        default:
            return nil
        }
    }

    /// "inclusive", "counting both", "including both".
    var saysInclusive: Bool {
        pieces.indices.contains { index in
            ["inclusive", "inclusively"].contains(word(index))
                || (word(index) == "both" && ["counting", "including", "include"].contains(word(index - 1)))
        }
    }

    /// "the third Tuesday of March 2026", "the last Friday in October", "the second Monday of the month"
    /// (the month then comes from the date the sentence names).
    func nthWeekday(at index: Int) -> NthMatch? {
        guard case .ordinal(let ordinal) = self[index], case .weekday(let weekday) = self[index + 1] else { return nil }
        if case .month(let month) = self[index + 3] {
            return NthMatch(ordinal: ordinal, weekday: weekday, month: month, end: index + 4)
        }
        guard word(index + 3) == "the", self[index + 4] == .unit(.month) else { return nil }
        return NthMatch(ordinal: ordinal, weekday: weekday, month: nil, end: index + 5)
    }
}
