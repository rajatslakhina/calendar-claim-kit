/// What a question asks the calendar, and what kind of answer it expects.
struct QuestionOperation: Sendable, Hashable {
    enum Expectation: Sendable, Hashable {
        case date, weekday, dateOrWeekday, truth
        case count(CalendarUnit)
    }

    let expression: CalendarExpression
    let expects: Expectation
    /// Dates the question gives, so an answer that repeats them is not read as giving them as the result.
    let inputs: [DateMention]
    let guessedYear: Bool
}

/// Reads a question that asks for a calendar value, and binds the value the answer gives. "What day of
/// the week was July 4, 1976?" answered "It was a Sunday." is a claim that July 4, 1976 was a Sunday,
/// though the answer never repeats the date.
struct QuestionReader: Sendable {
    func operation(in reading: TextReading) -> QuestionOperation? {
        for clause in reading.clauses {
            if let operation = operation(in: clause) { return operation }
        }
        return nil
    }

    func operation(in clause: Clause) -> QuestionOperation? {
        let view = ClauseView(pieces: clause.pieces)
        let words = Set(clause.pieces.compactMap(\.word))
        let lower = clause.quote.lowercased()
        let dates = clause.pieces.compactMap { piece -> DateMention? in
            if case .date(let mention) = piece { return mention }
            return nil
        }
        func make(_ expression: CalendarExpression, _ expects: QuestionOperation.Expectation) -> QuestionOperation {
            QuestionOperation(expression: expression, expects: expects, inputs: dates, guessedYear: clause.guessedYear)
        }
        let asksWeekday = ["day of the week", "what weekday", "which weekday"].contains { lower.contains($0) }
        let asksDay = asksWeekday || lower.contains("what day") || lower.contains("which day")
        let dayExpectation: QuestionOperation.Expectation = asksWeekday
            ? .weekday : (lower.contains("what date") || lower.contains("which date") ? .date : .dateOrWeekday)
        if words.contains("leap"), let year = clause.pieces.lazy.compactMap(\.statedYear).first {
            return make(.leapYear(year), .truth)
        }
        for index in clause.pieces.indices {
            if let match = view.nthWeekday(at: index), let month = match.month {
                return make(.nthWeekday(ordinal: match.ordinal, weekday: match.weekday, month: month), .date)
            }
            if let located = view.offset(at: index) { return make(located.expression, dayExpectation) }
        }
        if lower.contains("how many") || lower.contains("how long") {
            return countOperation(view, make: make)
        }
        if asksDay, let date = dates.first { return make(.weekdayOf(date), .weekday) }
        let named = clause.pieces.lazy.compactMap(Self.anchor).first
        let anchor = named ?? (asksDay && words.contains("it") ? .today : nil)
        if let anchor, asksDay || lower.contains("date") { return make(.anchor(anchor), dayExpectation) }
        return nil
    }

    /// "How many days are there between A and B?", "How many weeks until June 1?", "How many days are
    /// in February 2028?", "How many days does 2027 have?".
    func countOperation(
        _ view: ClauseView,
        make: (CalendarExpression, QuestionOperation.Expectation) -> QuestionOperation
    ) -> QuestionOperation? {
        let unit = view.pieces.lazy.compactMap { piece -> CalendarUnit? in
            if case .unit(let unit) = piece { return unit }
            return nil
        }.first ?? .day
        if let ends = view.spanEnds() {
            let inclusive = ends.inclusive || view.saysInclusive
            return make(.span(from: ends.from, to: ends.to, unit: unit, inclusive: inclusive), .count(unit))
        }
        for piece in view.pieces {
            if case .month(let month) = piece { return make(.monthLength(month), .count(.day)) }
            if case .year(let year) = piece { return make(.yearLength(year), .count(.day)) }
        }
        return nil
    }

    static func anchor(_ piece: Piece) -> Anchor? {
        if case .anchor(let anchor) = piece { return anchor }
        return nil
    }

    // MARK: - Binding the answer

    /// The value the answer gives for `operation`. One value, however often repeated, is the answer.
    /// Otherwise the last value that follows "is", "it's", "lands on" or "=" is the result of a worked
    /// answer ("28 days in, it is March 31; at 90 it is June 1"). Failing that, a first sentence with
    /// exactly one value, followed by more sentences, is a direct answer. Anything else is too ambiguous
    /// to bind. Dates the question gave are never candidates, and a count prefers numbers with the
    /// asked unit.
    func bind(_ operation: QuestionOperation, answer: TextReading) -> (CalendarValue, String)? {
        if operation.expects == .truth { return truth(in: answer) }
        var candidates: [Candidate] = []
        for (clauseIndex, clause) in answer.clauses.enumerated() {
            let view = ClauseView(pieces: clause.pieces)
            for index in clause.pieces.indices {
                if let (value, unitMatch) = candidate(view, at: index, for: operation) {
                    candidates.append(Candidate(
                        value: value, clause: clauseIndex, quote: clause.quote,
                        unitMatch: unitMatch, afterCopula: view.followsCopula(index)
                    ))
                }
            }
        }
        if candidates.contains(where: \.unitMatch) { candidates.removeAll { !$0.unitMatch } }
        let chosen: Candidate?
        if Set(candidates.map(\.value)).count == 1 {
            chosen = candidates.first
        } else if let result = candidates.last(where: \.afterCopula) {
            chosen = result
        } else if answer.clauses.count > 1, candidates.filter({ $0.clause == 0 }).count == 1 {
            chosen = candidates.first
        } else {
            chosen = nil
        }
        return chosen.map { ($0.value, $0.quote) }
    }

    struct Candidate {
        let value: CalendarValue
        let clause: Int
        let quote: String
        let unitMatch: Bool
        let afterCopula: Bool
    }

    func candidate(_ view: ClauseView, at index: Int, for operation: QuestionOperation) -> (CalendarValue, Bool)? {
        switch (operation.expects, view[index]) {
        case (.date, .date(let mention)), (.dateOrWeekday, .date(let mention)):
            let repeated = operation.inputs.contains { $0.month == mention.month && $0.day == mention.day }
            return repeated ? nil : (.date(mention), false)
        case (.date, .dayOfMonth(let day)):
            return (.dayOfMonth(day), false)
        case (.weekday, .weekday(let weekday)), (.dateOrWeekday, .weekday(let weekday)):
            return (.weekday(weekday), false)
        case (.count(let unit), .number(let count)):
            if case .unit(let stated) = view[index + 1] {
                return stated == unit ? (.count(count, view.qualifier(before: index)), true) : nil
            }
            return (.count(count, view.qualifier(before: index)), false)
        default:
            return nil
        }
    }

    /// "Yes" or "No" as the answer's first word.
    func truth(in answer: TextReading) -> (CalendarValue, String)? {
        guard let clause = answer.clauses.first, let first = clause.pieces.first?.word,
              first == "yes" || first == "no" else { return nil }
        return (.truth(first == "yes"), clause.quote)
    }
}
