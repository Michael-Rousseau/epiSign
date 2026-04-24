import Foundation
import SwiftData

@Model
final class LocalSignatureDraft {
    @Attribute(.unique) var id: UUID
    var courseId: UUID?
    var slot: Slot
    var totp: String
    var deviceId: String
    @Attribute(.externalStorage) var signatureImageData: Data?
    var createdAt: Date
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        courseId: UUID?,
        slot: Slot,
        totp: String,
        deviceId: String,
        signatureImageData: Data?,
        createdAt: Date = .now,
        expiresAt: Date
    ) {
        self.id = id
        self.courseId = courseId
        self.slot = slot
        self.totp = totp
        self.deviceId = deviceId
        self.signatureImageData = signatureImageData
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
