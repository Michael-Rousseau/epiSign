import Foundation
import SwiftData

@Model
final class DeviceInfo {
    @Attribute(.unique) var id: UUID
    var deviceId: String
    var userId: String

    init(id: UUID = UUID(), deviceId: String, userId: String) {
        self.id = id
        self.deviceId = deviceId
        self.userId = userId
    }
}
