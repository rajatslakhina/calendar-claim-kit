extension CalendarEvaluator {
    /// Days are counted exclusively ("March 3 to June 1 is 90 days"); counting both ends gives the
    /// alternate. Weeks, months and years count whole units and report what is left over.
    func span(_ first: CivilDate, _ second: CivilDate, unit: CalendarUnit, inclusive: Bool) -> Outcome {
        let (start, end) = first <= second ? (first, second) : (second, first)
        let days = start.days(until: end)
        let both = "counting both ends"
        switch unit {
        case .day:
            let exact = inclusive ? days + 1 : days
            let truth = "\(start) to \(end) is \(CalendarUnit.day.phrase(exact))"
                + (inclusive ? ", \(both)" : " (\(days + 1) \(both))")
            return .count(
                exact: Double(exact), whole: exact, truth: truth,
                alternate: inclusive ? nil : days + 1, why: "true only \(both)"
            )
        case .businessDay:
            let after = business.businessDays(from: start, to: end)
            let withStart = after + (business.isBusinessDay(start) ? 1 : 0)
            let exact = inclusive ? withStart : after
            let truth = "\(start) to \(end) is \(CalendarUnit.businessDay.phrase(exact))"
                + (inclusive || withStart == after ? "" : " (\(withStart) \(both))")
            let alternate = inclusive || withStart == after ? nil : withStart
            return .count(
                exact: Double(exact), whole: exact, truth: truth, alternate: alternate, why: "true only \(both)"
            )
        case .week:
            let truth = "\(start) to \(end) is \(CalendarUnit.week.phrase(days / 7))"
                + (days % 7 == 0 ? "" : " and \(CalendarUnit.day.phrase(days % 7))")
            return .count(exact: Double(days) / 7, whole: days / 7, truth: truth)
        case .month, .year:
            var months = (end.year - start.year) * 12 + end.month - start.month
            if start.adding(months: months) > end { months -= 1 }
            let rest = start.adding(months: months).days(until: end)
            let monthPart = CalendarUnit.month.phrase(unit == .year ? months % 12 : months)
            let truth = "\(start) to \(end) is "
                + (unit == .year ? "\(CalendarUnit.year.phrase(months / 12)), " : "")
                + "\(monthPart) and \(CalendarUnit.day.phrase(rest))"
            let exactMonths = Double(months) + Double(rest) / 30.436_875
            return unit == .month
                ? .count(exact: exactMonths, whole: months, truth: truth)
                : .count(exact: exactMonths / 12, whole: months / 12, truth: truth)
        }
    }

    func nthWeekday(_ ordinal: Int, _ weekday: Weekday, _ month: MonthMention) -> Outcome {
        let name = "the \(Describe.ordinal(ordinal)) \(weekday.name) of \(month)"
        guard let year = month.year else { return .unresolved("the year of \(month) is not known") }
        let length = CivilDate.daysIn(month: month.month, year: year)
        let day: Int
        if ordinal > 0 {
            let first = CivilDate(valid: year, month.month, 1)
            day = 1 + (weekday.rawValue - first.weekday.rawValue + 7) % 7 + 7 * (ordinal - 1)
        } else {
            let last = CivilDate(valid: year, month.month, length)
            day = length - (last.weekday.rawValue - weekday.rawValue + 7) % 7
        }
        guard day <= length else { return .nothing("\(month) has no \(Describe.ordinal(ordinal)) \(weekday.name)") }
        let date = CivilDate(valid: year, month.month, day)
        return .day(date, truth: "\(name) is \(date)")
    }

    /// February with no stated year has 28 days, or 29 in a leap year; both are accepted that way.
    func monthLength(_ month: MonthMention) -> Outcome {
        let name = CivilDate.monthName(month.month)
        let knownYear = month.yearSource == .stated || month.yearSource == .text ? month.year : nil
        if month.month == 2, knownYear == nil {
            return .count(
                exact: 28, whole: 28, truth: "February has 28 days, 29 in a leap year",
                alternate: 29, why: "true only in a leap year"
            )
        }
        let days = CivilDate.daysIn(month: month.month, year: knownYear ?? 2001)
        let label = knownYear.map { "\(name) \($0)" } ?? name
        return .count(exact: Double(days), whole: days, truth: "\(label) has \(days) days")
    }

    /// "next Friday" is the first Friday after today; the one a week later is the other reading.
    /// "this Friday" may be today. "last Friday" is the most recent one before today.
    func relative(_ kind: RelativeWeek, _ weekday: Weekday) -> Outcome {
        guard let today else { return .unresolved("needs today's date") }
        let ahead = (weekday.rawValue - today.weekday.rawValue + 7) % 7
        let behind = (today.weekday.rawValue - weekday.rawValue + 7) % 7
        let offset: Int
        switch kind {
        case .next: offset = ahead == 0 ? 7 : ahead
        case .this: offset = ahead
        case .last: offset = -(behind == 0 ? 7 : behind)
        }
        let date = today.adding(days: offset)
        let step = kind == .last ? -7 : 7
        return .day(
            date,
            truth: "\(kind.rawValue) \(weekday.name) is \(date)",
            alternate: date.adding(days: step),
            why: "true only if \"\(kind.rawValue) \(weekday.name)\" means \(date.adding(days: step))"
        )
    }
}
