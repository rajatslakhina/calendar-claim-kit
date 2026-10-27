/// Which days count as business days. The default is Monday to Friday with no holidays: the kit has no
/// holiday list, because which holidays apply depends on the country, the state and the employer.
public struct BusinessCalendar: Sendable, Hashable {
    public let weekend: Set<Weekday>
    public let holidays: Set<CivilDate>

    public init(weekend: Set<Weekday> = [.saturday, .sunday], holidays: Set<CivilDate> = []) {
        self.weekend = weekend
        self.holidays = holidays
    }

    public static let standard = BusinessCalendar()

    public func isBusinessDay(_ date: CivilDate) -> Bool {
        !weekend.contains(date.weekday) && !holidays.contains(date)
    }

    /// Steps one day at a time and counts only business days, so "5 business days after Friday" lands
    /// on the next Friday. A negative amount counts backwards.
    public func adding(businessDays amount: Int, to date: CivilDate) -> CivilDate {
        let step = amount < 0 ? -1 : 1
        var remaining = abs(amount)
        var current = date
        while remaining > 0 && weekend.count < 7 {
            current = current.adding(days: step)
            if isBusinessDay(current) { remaining -= 1 }
        }
        return current
    }

    /// Business days after `start` up to and including `end`: the count of working days a task that
    /// starts the morning after `start` needs to reach `end`. Order does not matter.
    public func businessDays(from start: CivilDate, to end: CivilDate) -> Int {
        let (low, high) = start <= end ? (start, end) : (end, start)
        var count = 0
        var current = low
        while current < high {
            current = current.adding(days: 1)
            if isBusinessDay(current) { count += 1 }
        }
        return count
    }
}
