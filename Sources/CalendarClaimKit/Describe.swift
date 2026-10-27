/// Sentences for checks: what a claim says, in the same words for every claim of a kind.
enum Describe {
    static func ordinal(_ ordinal: Int) -> String {
        ordinal == -1 ? "last" : ["first", "second", "third", "fourth", "fifth"][ordinal - 1]
    }

    /// "90 days after March 3, 2026", "3 days before today (October 27, 2026)".
    static func offset(_ amount: Int, _ unit: CalendarUnit, _ base: DateBase, _ start: CivilDate) -> String {
        let phrase = "\(unit.phrase(abs(amount))) \(amount < 0 ? "before" : "after")"
        switch base {
        case .anchor(let anchor): return "\(phrase) \(anchor.rawValue) (\(start))"
        case .date: return "\(phrase) \(start)"
        }
    }

    static func statement(_ claim: CalendarClaim) -> String {
        let not = claim.negated ? "not " : ""
        let value = claim.asserted.description
        switch claim.expression {
        case .weekdayOf(let mention):
            return "\(mention) is \(not)\(value)"
        case .offset(let base, let amount, let unit):
            return "\(unit.phrase(abs(amount))) \(amount < 0 ? "before" : "after") \(base) is \(not)\(value)"
        case .span(let from, let to, let unit, let inclusive):
            return "\(from) to \(to) is \(count(claim.asserted, unit))" + (inclusive ? ", counting both ends" : "")
        case .nthWeekday(let ordinal, let weekday, let month):
            return "the \(self.ordinal(ordinal)) \(weekday.name) of \(month) is \(not)\(value)"
        case .leapYear(let year):
            return "\(year) is \(claim.asserted == .truth(true) ? "" : "not ")a leap year"
        case .yearLength(let year):
            return "\(year) has \(count(claim.asserted, .day))"
        case .monthLength(let month):
            let known = month.yearSource == .stated || month.yearSource == .text
            return "\(known ? month.description : CivilDate.monthName(month.month)) has \(count(claim.asserted, .day))"
        case .anchor(let anchor):
            return "\(anchor.rawValue) is \(not)\(value)"
        case .relative(let kind, let weekday):
            return "\(kind.rawValue) \(weekday.name) is \(not)\(value)"
        }
    }

    /// The value a claim gave, in a few words ("June 2, 2026", "a Thursday", "14 business days"), or
    /// nil when only the whole statement makes sense ("is not a Monday", "is a leap year").
    static func assertedValue(_ claim: CalendarClaim) -> String? {
        if claim.negated { return nil }
        switch (claim.expression, claim.asserted) {
        case (_, .truth): return nil
        case (.span(_, _, let unit, _), _): return count(claim.asserted, unit)
        case (.yearLength, _), (.monthLength, _): return count(claim.asserted, .day)
        default: return claim.asserted.description
        }
    }

    /// "about 13 weeks", "90 days".
    static func count(_ value: CalendarValue, _ unit: CalendarUnit) -> String {
        guard case .count(let amount, let qualifier) = value else { return value.description }
        return (qualifier == .exact ? "" : "\(qualifier.rawValue) ") + unit.phrase(amount)
    }

    /// "April 2025 has 30 days", "February has at most 29 days".
    static func impossible(_ mention: DateMention) -> String {
        let name = CivilDate.monthName(mention.month)
        guard let year = mention.year, mention.yearSource == .stated || mention.yearSource == .text else {
            return "\(name) has at most \(CivilDate.daysIn(month: mention.month, year: 2000)) days"
        }
        return "\(name) \(year) has \(CivilDate.daysIn(month: mention.month, year: year)) days"
    }
}
