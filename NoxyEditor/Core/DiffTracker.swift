import Foundation

@Observable
final class DiffTracker {
    static let shared = DiffTracker()

    private var snapshots: [String: String] = [:]

    private init() {}

    func captureSnapshot(key: String, value: String) {
        snapshots[key] = value
    }

    func detectChange(key: String, currentValue: String) -> ChangeRecord? {
        guard let oldValue = snapshots[key], oldValue != currentValue else { return nil }
        return ChangeRecord(
            componentPath: key.components(separatedBy: "/").dropLast().joined(separator: "/"),
            propertyName: key.components(separatedBy: "/").last ?? key,
            oldValue: oldValue,
            newValue: currentValue
        )
    }

    func reset() {
        snapshots = [:]
    }
}
