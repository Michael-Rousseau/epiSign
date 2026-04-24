import Foundation
import CryptoKit
import SwiftData
import Supabase
import Functions

struct SignResponse: Decodable {
    let ok: Bool
    let signature_id: String?
    let error: String?
}

actor SigningService {
    func submitSignature(
        courseId: UUID,
        totp: String,
        signaturePNG: Data,
        slot: Slot,
        deviceId: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> SignResponse {
        let base64 = signaturePNG.base64EncodedString()
        let hash = SHA256.hash(data: signaturePNG)
        let sha256 = hash.compactMap { String(format: "%02x", $0) }.joined()
        let timestamp = ISO8601DateFormatter().string(from: .now)

        var body: [String: String] = [
            "session_id": courseId.uuidString,
            "totp": totp,
            "signature_png_base64": base64,
            "slot": slot.rawValue,
            "device_id": deviceId,
            "timestamp": timestamp,
            "sha256": sha256
        ]

        if let lat = latitude { body["latitude"] = String(lat) }
        if let lon = longitude { body["longitude"] = String(lon) }

        let response: SignResponse = try await supabase.functions
            .invoke("sign", options: .init(body: body))

        return response
    }

    func submitOfflineDraft(draft: LocalSignatureDraft, context: ModelContext) async throws {
        guard let courseId = draft.courseId,
              let signatureData = draft.signatureImageData else { return }

        let response = try await submitSignature(
            courseId: courseId,
            totp: draft.totp,
            signaturePNG: signatureData,
            slot: draft.slot,
            deviceId: draft.deviceId
        )

        if response.ok {
            context.delete(draft)
            try context.save()
        }
    }
}
