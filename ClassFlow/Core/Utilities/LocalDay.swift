import Foundation

public enum DomainError: Error, Equatable {
    case invalidDate, invalidTimeZone, invalidWeeks, invalidSemester
    case invalidTimeSlot, invalidSchedule, invalidOverride, invalidCourse
    case invalidWeek, invalidLayout
}

/// A civil date, independent of the device's time zone. Persist `key`, not midnight UTC.
public struct LocalDay: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public var key: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static let schoolTimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .gmt

    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.locale = Locale(identifier: "en_US_POSIX")
        result.timeZone = timeZone
        result.firstWeekday = 2
        result.minimumDaysInFirstWeek = 4
        return result
    }

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            throw DomainError.invalidDate
        }
        let calendar = Self.calendar(in: .gmt)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { throw DomainError.invalidDate }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(key: String) throws {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            throw DomainError.invalidDate
        }
        try self.init(year: y, month: m, day: d)
        guard self.key == key else { throw DomainError.invalidDate }
    }

    public init(date: Date, timeZone: TimeZone) {
        let calendar = Self.calendar(in: timeZone)
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
    }

    public func start(in timeZone: TimeZone) throws -> Date {
        let calendar = Self.calendar(in: timeZone)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              LocalDay(date: date, timeZone: timeZone) == self else { throw DomainError.invalidDate }
        return calendar.startOfDay(for: date)
    }

    /// Civil arithmetic in UTC avoids 23/25-hour days and skipped midnights.
    public func adding(days: Int) throws -> LocalDay {
        let calendar = Self.calendar(in: .gmt)
        guard let date = calendar.date(byAdding: .day, value: days, to: try start(in: .gmt)) else {
            throw DomainError.invalidDate
        }
        let result = LocalDay(date: date, timeZone: .gmt)
        guard (1...9999).contains(result.year) else { throw DomainError.invalidDate }
        return result
    }

    public func distance(to other: LocalDay) throws -> Int {
        let value = Self.calendar(in: .gmt).dateComponents(
            [.day], from: try start(in: .gmt), to: try other.start(in: .gmt)).day
        guard let value else { throw DomainError.invalidDate }
        return value
    }

    public var weekday: Weekday {
        // Gregorian date is validated at construction; no locale-dependent weekday numbering escapes here.
        let calendar = Self.calendar(in: .gmt)
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        return date.map { Weekday(calendarWeekday: calendar.component(.weekday, from: $0)) } ?? .monday
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.key < rhs.key }
}

public enum Weekday: Int, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    init(calendarWeekday: Int) { self = Self(rawValue: (calendarWeekday + 5) % 7 + 1) ?? .monday }
}
