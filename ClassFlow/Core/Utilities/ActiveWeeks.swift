import Foundation

/// Persist sorted integers via SwiftData; display strings are never the source of truth.
public struct ActiveWeeks: Equatable, Sendable {
    public let values: Set<Int>
    public var sorted: [Int] { values.sorted() }

    public init(_ values: [Int]) throws {
        guard !values.isEmpty, values.allSatisfy({ (1...104).contains($0) }) else {
            throw DomainError.invalidWeeks
        }
        self.values = Set(values)
    }

    public static func every(_ range: ClosedRange<Int>) throws -> Self { try Self(Array(range)) }
    public static func odd(_ range: ClosedRange<Int>) throws -> Self {
        try Self(range.filter { $0 % 2 == 1 })
    }
    public static func even(_ range: ClosedRange<Int>) throws -> Self {
        try Self(range.filter { $0 % 2 == 0 })
    }
    public func contains(_ week: Int) -> Bool { values.contains(week) }

    /// Accepts `1-8,10-16` / `1,2,5` and Chinese comma; rejects partial or reversed input.
    public static func parse(_ text: String) throws -> Self {
        let normalized = text.replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "周", with: "")
            .replacingOccurrences(of: " ", with: "")
        var result = [Int]()
        for token in normalized.split(separator: ",", omittingEmptySubsequences: false) {
            let bounds = token.split(separator: "-", omittingEmptySubsequences: false)
            if bounds.count == 1, let value = Int(bounds[0]) { result.append(value) }
            else if bounds.count == 2, let a = Int(bounds[0]), let b = Int(bounds[1]),
                    a >= 1, b <= 104, a <= b { result.append(contentsOf: a...b) }
            else { throw DomainError.invalidWeeks }
        }
        return try Self(result)
    }
}
