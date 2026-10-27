import Foundation

/// Finds the calendar claims in an answer and checks each against the Gregorian calendar: weekdays of
/// dates, dates a number of days, weeks, months or business days from another, spans between dates,
/// the nth weekday of a month, leap years, month lengths, and dates that do not exist.
public struct CalendarChecker: Sendable {
    public let business: BusinessCalendar
    /// The time zone `now` is read in: "today" is the date there.
    public let timeZone: TimeZone

    public init(business: BusinessCalendar = .standard, timeZone: TimeZone = .current) {
        self.business = business
        self.timeZone = timeZone
    }

    /// - Parameters:
    ///   - answer: the text to check.
    ///   - question: the message the answer replies to. It lets "What day was July 4, 1976?" answered
    ///     "A Sunday." be checked, and gives a year to dates the answer leaves without one.
    ///   - now: when the answer was given. "Today", "next Friday" and "in 90 days" need it; without it
    ///     they are left unresolved, and dates with no year are not given the current one.
    ///   - contextYear: a year from earlier in the conversation, used before the current year.
    public func check(
        answer: String, question: String? = nil, now: Date? = nil, contextYear: Int? = nil
    ) -> CalendarReport {
        let today = now.map { CivilDate($0, in: timeZone) }
        let read = claims(answer: answer, question: question, today: today, contextYear: contextYear, shift: 0)
        let evaluator = CalendarEvaluator(business: business, today: today)
        var shifted: [Int: [CalendarClaim]] = [:]
        var checks = impossibleDates(in: read.answer)
        for (index, claim) in read.claims.enumerated() {
            var check = evaluator.check(claim)
            if check.status == .contradicted, claim.guessedYear, let today {
                for shift in [1, -1] {
                    let other = shifted[shift] ?? claims(
                        answer: answer, question: question, today: today, contextYear: contextYear, shift: shift
                    ).claims
                    shifted[shift] = other
                    if other.count == read.claims.count, evaluator.check(other[index]).status == .verified {
                        check = CalendarCheck(
                            claim: claim, status: .conventionDependent, statement: check.statement, truth: check.truth,
                            reason: "true for \(today.year + shift); "
                                + "the year was not stated and \(today.year) was assumed"
                        )
                        break
                    }
                }
            }
            checks.append(check)
        }
        return CalendarReport(
            checks: checks,
            today: today,
            questionYears: read.question?.statedYears ?? [],
            answerYears: read.answer.statedYears
        )
    }

    /// The claims in an answer, and the readings they came from.
    struct Read {
        let claims: [CalendarClaim]
        let answer: TextReading
        let question: TextReading?
    }

    func claims(answer: String, question: String?, today: CivilDate?, contextYear: Int?, shift: Int) -> Read {
        let todayYear = today.map { $0.year + shift }
        let questionReading = question.map {
            PieceReader(context: YearContext(contextYear: contextYear, todayYear: todayYear)).read($0)
        }
        let answerContext = YearContext(
            contextYear: questionReading?.statedYears.last ?? contextYear, todayYear: todayYear
        )
        let answerReading = PieceReader(context: answerContext).read(answer)
        var claims = ClaimReader().claims(in: answerReading)
        let reader = QuestionReader()
        if let questionReading, let operation = reader.operation(in: questionReading),
           !claims.contains(where: { $0.expression.kind == operation.expression.kind }),
           let (value, quote) = reader.bind(operation, answer: answerReading) {
            claims.append(CalendarClaim(
                expression: operation.expression, asserted: value, negated: false,
                quote: quote, origin: .question, guessedYear: operation.guessedYear
            ))
        }
        return Read(claims: claims, answer: answerReading, question: questionReading)
    }

    /// Every date in the answer that cannot exist, once each.
    func impossibleDates(in reading: TextReading) -> [CalendarCheck] {
        var seen: Set<String> = []
        return reading.pieces.compactMap { piece in
            guard case .date(let mention) = piece, mention.isImpossible,
                  seen.insert(mention.description).inserted else { return nil }
            return CalendarCheck(
                claim: nil, status: .impossibleDate, statement: mention.description, truth: Describe.impossible(mention)
            )
        }
    }
}
