import Foundation

public struct ScheduleLayoutMetrics: Equatable, Sendable {
    public static let standard = ScheduleLayoutMetrics(uncheckedSectionHeight: 76, dayColumnWidth: 112,
        horizontalInset: 3, verticalInset: 3, laneSpacing: 2)

    public let sectionHeight: Double
    public let dayColumnWidth: Double
    public let horizontalInset: Double
    public let verticalInset: Double
    public let laneSpacing: Double

    private init(uncheckedSectionHeight sectionHeight: Double, dayColumnWidth: Double, horizontalInset: Double,
                 verticalInset: Double, laneSpacing: Double) {
        self.sectionHeight = sectionHeight
        self.dayColumnWidth = dayColumnWidth
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.laneSpacing = laneSpacing
    }

    public init(sectionHeight: Double = 76, dayColumnWidth: Double = 112,
                horizontalInset: Double = 3, verticalInset: Double = 3,
                laneSpacing: Double = 2) throws {
        guard sectionHeight >= 24, dayColumnWidth >= 56, horizontalInset >= 0,
              verticalInset >= 0, laneSpacing >= 0,
              horizontalInset * 2 < dayColumnWidth,
              verticalInset * 2 < sectionHeight else { throw DomainError.invalidLayout }
        self.init(uncheckedSectionHeight: sectionHeight, dayColumnWidth: dayColumnWidth,
            horizontalInset: horizontalInset, verticalInset: verticalInset, laneSpacing: laneSpacing)
    }
}

public struct CourseLayoutItem: Identifiable, Equatable, Sendable {
    public var id: String { occurrence.id }
    public let occurrence: CourseOccurrence
    public let dayColumnIndex: Int
    public let topOffset: Double
    public let height: Double
    public let leadingOffset: Double
    public let width: Double
    public let laneIndex: Int
    public let laneCount: Int

    public init(occurrence: CourseOccurrence, dayColumnIndex: Int, topOffset: Double,
                height: Double, leadingOffset: Double, width: Double,
                laneIndex: Int, laneCount: Int) {
        self.occurrence = occurrence
        self.dayColumnIndex = dayColumnIndex
        self.topOffset = topOffset
        self.height = height
        self.leadingOffset = leadingOffset
        self.width = width
        self.laneIndex = laneIndex
        self.laneCount = laneCount
    }
}

public struct CourseLayoutEngine: Sendable {
    public init() {}

    public func layout(days: [DayScheduleSnapshot], timeSlots: [TimeSlotDefinition],
                       metrics: ScheduleLayoutMetrics = .standard) throws -> [CourseLayoutItem] {
        try TimeSlotDefinition.validate(timeSlots)
        let sortedSlots = timeSlots.sorted { $0.sectionNumber < $1.sectionNumber }
        let slotIndices = Dictionary(uniqueKeysWithValues:
            sortedSlots.enumerated().map { ($0.element.sectionNumber, $0.offset) })
        var output = [CourseLayoutItem]()
        for (dayIndex, day) in days.enumerated() {
            let courses = day.courses.sorted {
                if $0.startSection != $1.startSection { return $0.startSection < $1.startSection }
                if $0.endSection != $1.endSection { return $0.endSection < $1.endSection }
                return $0.id < $1.id
            }
            for group in overlapGroups(courses) {
                let assignments = laneAssignments(group)
                let laneCount = max(1, (assignments.values.max() ?? 0) + 1)
                let available = metrics.dayColumnWidth - metrics.horizontalInset * 2
                    - metrics.laneSpacing * Double(laneCount - 1)
                let laneWidth = available / Double(laneCount)
                guard laneWidth > 0 else { throw DomainError.invalidLayout }
                for occurrence in group {
                    guard let startIndex = slotIndices[occurrence.startSection],
                          let endIndex = slotIndices[occurrence.endSection], startIndex <= endIndex else {
                        throw DomainError.invalidLayout
                    }
                    let lane = assignments[occurrence.id] ?? 0
                    output.append(CourseLayoutItem(occurrence: occurrence, dayColumnIndex: dayIndex,
                        topOffset: Double(startIndex) * metrics.sectionHeight + metrics.verticalInset,
                        height: Double(endIndex - startIndex + 1) * metrics.sectionHeight
                            - metrics.verticalInset * 2,
                        leadingOffset: metrics.horizontalInset
                            + Double(lane) * (laneWidth + metrics.laneSpacing),
                        width: laneWidth, laneIndex: lane, laneCount: laneCount))
                }
            }
        }
        return output.sorted {
            if $0.dayColumnIndex != $1.dayColumnIndex { return $0.dayColumnIndex < $1.dayColumnIndex }
            if $0.topOffset != $1.topOffset { return $0.topOffset < $1.topOffset }
            return $0.occurrence.id < $1.occurrence.id
        }
    }

    private func overlapGroups(_ courses: [CourseOccurrence]) -> [[CourseOccurrence]] {
        var groups = [[CourseOccurrence]]()
        var current = [CourseOccurrence]()
        var furthestEnd = Int.min
        for course in courses {
            if !current.isEmpty, course.startSection > furthestEnd {
                groups.append(current)
                current = []
                furthestEnd = Int.min
            }
            current.append(course)
            furthestEnd = max(furthestEnd, course.endSection)
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    private func laneAssignments(_ courses: [CourseOccurrence]) -> [String: Int] {
        var laneEnds = [Int]()
        var assignments = [String: Int]()
        for course in courses {
            if let lane = laneEnds.firstIndex(where: { $0 < course.startSection }) {
                laneEnds[lane] = course.endSection
                assignments[course.id] = lane
            } else {
                assignments[course.id] = laneEnds.count
                laneEnds.append(course.endSection)
            }
        }
        return assignments
    }
}

public struct CurrentTimeLayoutEngine: Sendable {
    public init() {}

    public func position(at date: Date, timeZone: TimeZone, timeSlots: [TimeSlotDefinition],
                         metrics: ScheduleLayoutMetrics = .standard) throws -> Double? {
        try TimeSlotDefinition.validate(timeSlots)
        let slots = timeSlots.sorted { $0.sectionNumber < $1.sectionNumber }
        guard let first = slots.first, let last = slots.last else { return nil }
        let calendar = LocalDay.calendar(in: timeZone)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        guard minute >= first.startMinute, minute <= last.endMinute else { return nil }
        for (index, slot) in slots.enumerated() {
            if minute <= slot.endMinute {
                if minute < slot.startMinute { return Double(index) * metrics.sectionHeight }
                let progress = Double(minute - slot.startMinute) / Double(slot.endMinute - slot.startMinute)
                return (Double(index) + progress) * metrics.sectionHeight
            }
        }
        return nil
    }
}
