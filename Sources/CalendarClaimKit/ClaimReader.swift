/// Reads the calendar statements an answer makes in full: "March 17, 2026 is a Monday", "90 days after
/// March 3 is June 1", "there are 45 days between January 1 and February 14", "2100 is a leap year".
struct ClaimReader: Sendable {
    struct Found {
        let expression: CalendarExpression
        let value: CalendarValue
        let negated: Bool

        init(_ expression: CalendarExpression, _ value: CalendarValue, _ negated: Bool) {
            self.expression = expression
            self.value = value
            self.negated = negated
        }
    }

    /// - Parameter priorDate: the last date named before this text (in the question it answers), which
    ///   "90 days later" in the text's first sentence counts from when that sentence names none.
    func claims(in reading: TextReading, priorDate initial: DateMention? = nil) -> [CalendarClaim] {
        var claims: [CalendarClaim] = []
        var priorDate = initial
        for clause in reading.clauses {
            for claim in self.claims(in: clause, priorDate: priorDate) where !claims.contains(claim) {
                claims.append(claim)
            }
            priorDate = ClauseView(pieces: clause.pieces).lastDate(before: clause.pieces.count) ?? priorDate
        }
        return claims
    }

    func claims(in clause: Clause, priorDate: DateMention? = nil) -> [CalendarClaim] {
        let view = ClauseView(pieces: clause.pieces, priorDate: priorDate)
        var found: [Found] = []
        var usedAmounts: Set<Int> = []
        for index in clause.pieces.indices {
            if let located = view.offset(at: index) {
                usedAmounts.insert(index)
                if let (value, negated) = view.dayValue(around: located.start, end: located.end) {
                    found.append(Found(located.expression, value, negated))
                }
            }
            found += weekdayClaims(view, at: index)
            found += nthClaims(view, at: index)
            found += yearClaims(view, at: index)
            found += relativeClaims(view, at: index)
        }
        found += spanClaims(view, skipping: usedAmounts)
        return found.map {
            CalendarClaim(
                expression: $0.expression, asserted: $0.value, negated: $0.negated,
                quote: clause.quote, origin: .answer, guessedYear: clause.guessedYear
            )
        }
    }

    /// "Tuesday, March 17, 2026", "March 17, 2026 is a Monday", "March 17, 2026 (Tuesday)",
    /// "June 2, 2026, a Tuesday", "March 17, 2026, which is not a Monday".
    func weekdayClaims(_ view: ClauseView, at index: Int) -> [Found] {
        guard case .date(let mention) = view[index], !mention.isImpossible else { return [] }
        var found: [Found] = []
        if let stated = mention.statedWeekday { found.append(Found(.weekdayOf(mention), .weekday(stated), false)) }
        guard !view.isInput(index) else { return found }
        var next = view.isMark(index + 1, ",") || view.isMark(index + 1, "(") ? index + 2 : index + 1
        if next > index + 1, ["a", "an"].contains(view.word(next)) { next += 1 }
        if case .weekday(let weekday) = view[next] {
            found.append(Found(.weekdayOf(mention), .weekday(weekday), false))
        } else if let (after, negated) = view.copula(at: next), case .weekday(let weekday) = view[after] {
            found.append(Found(.weekdayOf(mention), .weekday(weekday), negated))
        }
        return found
    }

    /// "the third Tuesday of March 2026 is March 17", "March 17 is the third Tuesday of the month".
    func nthClaims(_ view: ClauseView, at index: Int) -> [Found] {
        guard let match = view.nthWeekday(at: index),
              let (value, negated) = view.dayValue(around: index, end: match.end) else { return [] }
        var month = match.month
        if month == nil, case .date(let mention) = value { month = MonthMention(of: mention) }
        guard let month else { return [] }
        return [Found(.nthWeekday(ordinal: match.ordinal, weekday: match.weekday, month: month), value, negated)]
    }

    /// "2100 is not a leap year", "2027 has 365 days", "February 2028 has 29 days", "April has 30 days".
    func yearClaims(_ view: ClauseView, at index: Int) -> [Found] {
        switch view[index] {
        case .year(let year):
            guard let (after, negated) = view.copula(at: index + 1) else { return [] }
            if view.word(after) == "leap", view[after + 1] == .unit(.year) {
                return [Found(.leapYear(year), .truth(!negated), false)]
            }
            guard let found = view.amount(at: after), found.unit == .day else { return [] }
            return [Found(.yearLength(year), .count(found.amount, .exact), negated)]
        case .month(let month):
            guard let (after, negated) = view.copula(at: index + 1),
                  let found = view.amount(at: after), found.unit == .day else { return [] }
            return [Found(.monthLength(month), .count(found.amount, .exact), negated)]
        default:
            return []
        }
    }

    /// "today is Tuesday, October 27", "tomorrow is the 28th", "next Friday is October 30".
    func relativeClaims(_ view: ClauseView, at index: Int) -> [Found] {
        switch view[index] {
        case .anchor(let anchor) where !view.isInput(index):
            let next = view.word(index + 1) == "date" ? index + 2 : index + 1
            if let (after, negated) = view.copula(at: next), let value = view.dayValue(at: after) {
                return [Found(.anchor(anchor), value, negated)]
            }
            guard view.isMark(next, ","), case .date(let mention) = view[next + 1] else { return [] }
            return [Found(.anchor(anchor), .date(mention), false)]
        case .word(let word):
            guard let kind = RelativeWeek(rawValue: word), case .weekday(let weekday) = view[index + 1],
                  let (after, negated) = view.copula(at: index + 2),
                  let value = view.dayValue(at: after) else { return [] }
            return [Found(.relative(kind, weekday), value, negated)]
        default:
            return []
        }
    }

    /// Every count in a clause that names a span: "there are 90 days, about 13 weeks, between March 3
    /// and June 1".
    func spanClaims(_ view: ClauseView, skipping used: Set<Int>) -> [Found] {
        guard let ends = view.spanEnds() else { return [] }
        let inclusive = ends.inclusive || view.saysInclusive
        return view.pieces.indices.compactMap { index in
            guard !used.contains(index), let found = view.amount(at: index) else { return nil }
            return Found(
                .span(from: ends.from, to: ends.to, unit: found.unit, inclusive: inclusive),
                .count(found.amount, view.qualifier(before: index)),
                false
            )
        }
    }
}

extension MonthMention {
    init(of date: DateMention) {
        self.init(month: date.month, year: date.year)
        yearSource = date.yearSource
    }
}
