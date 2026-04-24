import Foundation
import SwiftData

@Model
final class Signature {
    @Attribute(.unique) var id: UUID
    var course: Course?
    var slot: Slot
    var timestamp: Date
    @Attribute(.externalStorage) var signatureImageData: Data?
    var isSynced: Bool

    init(id: UUID = UUID(), course: Course? = nil, slot: Slot, timestamp: Date = .now, signatureImageData: Data? = nil, isSynced: Bool = false) {
        self.id = id
        self.course = course
        self.slot = slot
        self.timestamp = timestamp
        self.signatureImageData = signatureImageData
        self.isSynced = isSynced
    }
}
