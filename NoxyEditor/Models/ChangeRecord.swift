import Foundation

struct ChangeRecord: Identifiable, Codable {
    let id: UUID
    let componentPath: String
    let propertyName: String
    let oldValue: String
    let newValue: String
    let timestamp: Date

    init(componentPath: String, propertyName: String, oldValue: String, newValue: String) {
        self.id = UUID()
        self.componentPath = componentPath
        self.propertyName = propertyName
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}
