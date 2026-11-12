import Foundation

enum WeekPlanOps {

    static func stamp(for date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (parts.yearForWeekOfYear ?? 0) * 100 + (parts.weekOfYear ?? 0)
    }

    /// 跨周时把这一周收进上周。第一次见到周戳时只记下当前周，不制造一份假的上周。
    static func roll(
        days: [PlannedDay],
        lastWeek: [PlannedDay],
        stamp: Int,
        now: Date,
        calendar: Calendar
    ) -> (days: [PlannedDay], lastWeek: [PlannedDay], stamp: Int) {
        let next = Self.stamp(for: now, calendar: calendar)
        guard next != stamp else { return (days, lastWeek, stamp) }
        let archived = stamp == 0 ? lastWeek : days
        return (days, archived, next)
    }

    static func reorder(_ days: [PlannedDay], from offsets: IndexSet, to destination: Int) -> [PlannedDay] {
        var ordered = days.sorted { $0.weekday < $1.weekday }
        let moving = offsets.sorted().compactMap { index in
            ordered.indices.contains(index) ? ordered[index] : nil
        }
        for index in offsets.sorted(by: >) where ordered.indices.contains(index) {
            ordered.remove(at: index)
        }
        let shift = offsets.filter { $0 < destination }.count
        let insertAt = min(max(0, destination - shift), ordered.count)
        ordered.insert(contentsOf: moving, at: insertAt)
        for index in ordered.indices {
            ordered[index].weekday = index + 1
        }
        return ordered
    }

    static func cleared(_ days: [PlannedDay]) -> [PlannedDay] {
        days.map { day in
            var copy = day
            copy.title = "恢复"
            copy.focus = nil
            copy.exercises = []
            copy.rest = true
            return copy
        }
    }

    static func copied(from lastWeek: [PlannedDay]) -> [PlannedDay]? {
        let ordered = lastWeek.sorted { $0.weekday < $1.weekday }
        guard !ordered.isEmpty else { return nil }
        return ordered.enumerated().map { index, day in
            var copy = day
            copy.weekday = index + 1
            return copy
        }
    }
}
