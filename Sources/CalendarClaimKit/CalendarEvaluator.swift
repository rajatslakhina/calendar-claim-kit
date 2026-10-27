/// Works out what the calendar says for one expression and compares it with what the claim says.
struct CalendarEvaluator: Sendable {
    let business: BusinessCalendar
    let today: CivilDate?

    /// What an expression comes to.
    enum Outcome: Sendable, Hashable {
        /// A day, with another day that a second reading of the words would give, and that reading.
        case day(CivilDate, truth: String, alternate: CivilDate? = nil, why: String? = nil)
        case count(exact: Double, whole: Int, truth: String, alternate: Int? = nil, why: String? = nil)
        case truth(Bool, truth: String)
        /// The expression names something that does not exist: "the fifth Monday of March 2026".
        case nothing(String)
        case unresolved(String)
    }

    func check(_ claim: CalendarClaim) -> CalendarCheck {
        let statement = Describe.statement(claim)
        switch outcome(claim.expression) {
        case .day(let date, let truth, let alternate, let why):
            if Self.matches(claim.asserted, date) != claim.negated {
                return CalendarCheck(claim: claim, status: .verified, statement: statement, truth: truth)
            }
            if let alternate, Self.matches(claim.asserted, alternate) != claim.negated {
                return CalendarCheck(
                    claim: claim, status: .conventionDependent, statement: statement, truth: truth, reason: why
                )
            }
            return CalendarCheck(claim: claim, status: .contradicted, statement: statement, truth: truth)
        case .count(let exact, let whole, let truth, let alternate, let why):
            let (status, reason) = Self.judge(
                claim.asserted, exact: exact, whole: whole, alternate: alternate, why: why
            )
            return CalendarCheck(claim: claim, status: status, statement: statement, truth: truth, reason: reason)
        case .truth(let value, let truth):
            let holds = (claim.asserted == .truth(value)) != claim.negated
            let status: CheckStatus = holds ? .verified : .contradicted
            return CalendarCheck(claim: claim, status: status, statement: statement, truth: truth)
        case .nothing(let truth):
            return CalendarCheck(claim: claim, status: .contradicted, statement: statement, truth: truth)
        case .unresolved(let reason):
            return CalendarCheck(
                claim: claim, status: .unresolved, statement: statement, truth: "not checked", reason: reason
            )
        }
    }

    // MARK: - Comparing

    static func matches(_ value: CalendarValue, _ date: CivilDate) -> Bool {
        switch value {
        case .date(let mention):
            mention.month == date.month && mention.day == date.day
                && (mention.yearSource != .stated || mention.year == date.year)
        case .dayOfMonth(let day): day == date.day
        case .weekday(let weekday): weekday == date.weekday
        default: false
        }
    }

    /// A count is exact when the span is a whole number of units. Otherwise the whole units it contains
    /// ("6 weeks" for 44 days) depend on convention. "About" allows less than one unit either way;
    /// "over" and "under" need the right side.
    static func judge(
        _ value: CalendarValue, exact: Double, whole: Int, alternate: Int?, why: String?
    ) -> (CheckStatus, String?) {
        guard case .count(let claimed, let qualifier) = value else { return (.contradicted, nil) }
        let stated = Double(claimed)
        switch qualifier {
        case .approximately:
            return (abs(stated - exact) < 1 ? .verified : .contradicted, nil)
        case .over:
            return (stated < exact ? .verified : .contradicted, nil)
        case .under:
            return (stated > exact ? .verified : .contradicted, nil)
        case .exact:
            if stated == exact { return (.verified, nil) }
            if let alternate, claimed == alternate { return (.conventionDependent, why) }
            if exact != exact.rounded(.down), claimed == whole {
                return (.conventionDependent, "true only counting whole units")
            }
            return (.contradicted, nil)
        }
    }

    // MARK: - Working out

    func outcome(_ expression: CalendarExpression) -> Outcome {
        switch expression {
        case .weekdayOf(let mention):
            return resolve(.date(mention)).map { .day($0, truth: "\($0) is a \($0.weekday.name)") }
        case .offset(let base, let amount, let unit):
            return resolve(base).map { start in
                let end = add(amount, unit, to: start)
                return .day(end, truth: "\(Describe.offset(amount, unit, base, start)) is \(end.weekday.name), \(end)")
            }
        case .span(let from, let to, let unit, let inclusive):
            return resolve(from).map { start in
                resolve(to).map { end in span(start, end, unit: unit, inclusive: inclusive) }
            }
        case .nthWeekday(let ordinal, let weekday, let month):
            return nthWeekday(ordinal, weekday, month)
        case .leapYear(let year):
            let leap = CivilDate.isLeap(year)
            return .truth(leap, truth: "\(year) is \(leap ? "" : "not ")a leap year")
        case .yearLength(let year):
            let days = CivilDate.isLeap(year) ? 366 : 365
            return .count(exact: Double(days), whole: days, truth: "\(year) has \(days) days")
        case .monthLength(let month):
            return monthLength(month)
        case .anchor(let anchor):
            return resolve(.anchor(anchor)).map { .day($0, truth: "\(anchor.rawValue) is \($0.weekday.name), \($0)") }
        case .relative(let kind, let weekday):
            return relative(kind, weekday)
        }
    }

    func resolve(_ base: DateBase) -> Resolved {
        switch base {
        case .anchor(let anchor):
            guard let today else { return .failed(.unresolved("needs today's date")) }
            return .date(today.adding(days: anchor.offset))
        case .date(let mention):
            guard let year = mention.year else { return .failed(.unresolved("the year of \(mention) is not known")) }
            guard let date = mention.civil else {
                return .failed(.nothing("\(mention) does not exist: \(CivilDate.monthName(mention.month)) \(year) has "
                    + "\(CivilDate.daysIn(month: mention.month, year: year)) days"))
            }
            return .date(date)
        }
    }

    func add(_ amount: Int, _ unit: CalendarUnit, to date: CivilDate) -> CivilDate {
        switch unit {
        case .day: date.adding(days: amount)
        case .week: date.adding(days: 7 * amount)
        case .month: date.adding(months: amount)
        case .year: date.adding(months: 12 * amount)
        case .businessDay: business.adding(businessDays: amount, to: date)
        }
    }
}

/// A resolved date, or the outcome that stops the check.
enum Resolved {
    case date(CivilDate)
    case failed(CalendarEvaluator.Outcome)

    func map(_ transform: (CivilDate) -> CalendarEvaluator.Outcome) -> CalendarEvaluator.Outcome {
        switch self {
        case .date(let date): transform(date)
        case .failed(let outcome): outcome
        }
    }
}
