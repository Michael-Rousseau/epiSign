//
//  EpiSignTests.swift
//  EpiSignTests
//
//  Created by Michael ROUSSEAU on 21/04/2026.
//

import Testing
import Foundation
import SwiftData
import CryptoKit
@testable import EpiSign

// MARK: - Helpers

@MainActor
private func makeContainer() throws -> ModelContainer {
    let schema = Schema([Course.self, Signature.self, DeviceInfo.self, LocalSignatureDraft.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute
    ))!
}

// MARK: - Slot

@Suite("Slot")
struct SlotTests {

    @Test func rawValues() {
        #expect(Slot.morning.rawValue == "morning")
        #expect(Slot.afternoon.rawValue == "afternoon")
    }

    @Test func allCasesCount() {
        #expect(Slot.allCases.count == 2)
        #expect(Slot.allCases.contains(.morning))
        #expect(Slot.allCases.contains(.afternoon))
    }

    @Test func codableRoundTrip() throws {
        for slot in Slot.allCases {
            let data = try JSONEncoder().encode(slot)
            let decoded = try JSONDecoder().decode(Slot.self, from: data)
            #expect(decoded == slot)
        }
    }

    @Test func decodesFromRawString() throws {
        let data = Data("\"morning\"".utf8)
        let slot = try JSONDecoder().decode(Slot.self, from: data)
        #expect(slot == .morning)
    }
}

// MARK: - Course (computed properties)

@Suite("Course — computed properties")
struct CourseModelTests {

    private func makeCourse(
        title: String = "iOS Dev",
        slot: Slot = .morning,
        startsAt: Date,
        endsAt: Date,
        date: Date? = nil
    ) -> Course {
        Course(
            title: title,
            teacherName: "M. Dupont",
            room: "SM Apple",
            date: date ?? startsAt,
            slot: slot,
            startsAt: startsAt,
            endsAt: endsAt
        )
    }

    // MARK: isCurrent

    @Test func isCurrentWhenNowBetweenStartAndEnd() {
        let now = Date()
        let course = makeCourse(
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600)
        )
        #expect(course.isCurrent == true)
    }

    @Test func isNotCurrentWhenBeforeStart() {
        let now = Date()
        let course = makeCourse(
            startsAt: now.addingTimeInterval(3600),
            endsAt: now.addingTimeInterval(7200)
        )
        #expect(course.isCurrent == false)
    }

    @Test func isNotCurrentWhenAfterEnd() {
        let now = Date()
        let course = makeCourse(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600)
        )
        #expect(course.isCurrent == false)
    }

    @Test func isCurrentAtExactStartBoundary() {
        let now = Date()
        let course = makeCourse(
            startsAt: now.addingTimeInterval(-0.001),
            endsAt: now.addingTimeInterval(3600)
        )
        #expect(course.isCurrent == true)
    }

    // MARK: isSigned (without SwiftData context)

    @Test func isSignedFalseWhenNoSignatures() {
        let now = Date()
        let course = makeCourse(startsAt: now, endsAt: now)
        #expect(course.isSigned == false)
    }

    // MARK: formattedDate

    @Test func formattedDateMidMay() {
        let date = makeDate(year: 2026, month: 5, day: 13)
        let course = makeCourse(startsAt: date, endsAt: date, date: date)
        #expect(course.formattedDate == "13/05/2026")
    }

    @Test func formattedDateFirstOfJanuary() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        let course = makeCourse(startsAt: date, endsAt: date, date: date)
        #expect(course.formattedDate == "01/01/2026")
    }

    @Test func formattedDateLastOfDecember() {
        let date = makeDate(year: 2025, month: 12, day: 31)
        let course = makeCourse(startsAt: date, endsAt: date, date: date)
        #expect(course.formattedDate == "31/12/2025")
    }

    // MARK: formattedTime

    @Test func formattedTimeMorning() {
        let start = makeDate(year: 2026, month: 5, day: 13, hour: 9)
        let end   = makeDate(year: 2026, month: 5, day: 13, hour: 13)
        let course = makeCourse(startsAt: start, endsAt: end)
        #expect(course.formattedTime == "9h - 13h")
    }

    @Test func formattedTimeAfternoon() {
        let start = makeDate(year: 2026, month: 5, day: 13, hour: 14)
        let end   = makeDate(year: 2026, month: 5, day: 13, hour: 18)
        let course = makeCourse(startsAt: start, endsAt: end)
        #expect(course.formattedTime == "14h - 18h")
    }

    // MARK: formattedTimeArrow

    @Test func formattedTimeArrowMorning() {
        let start = makeDate(year: 2026, month: 5, day: 13, hour: 9)
        let end   = makeDate(year: 2026, month: 5, day: 13, hour: 13)
        let course = makeCourse(startsAt: start, endsAt: end)
        #expect(course.formattedTimeArrow == "09:00 \u{2192} 13:00")
    }

    @Test func formattedTimeArrowAfternoon() {
        let start = makeDate(year: 2026, month: 5, day: 13, hour: 14)
        let end   = makeDate(year: 2026, month: 5, day: 13, hour: 18)
        let course = makeCourse(startsAt: start, endsAt: end)
        #expect(course.formattedTimeArrow == "14:00 \u{2192} 18:00")
    }

    // MARK: id

    @Test func idIsUniqueByDefault() {
        let now = Date()
        let c1 = makeCourse(startsAt: now, endsAt: now)
        let c2 = makeCourse(startsAt: now, endsAt: now)
        #expect(c1.id != c2.id)
    }

    @Test func customIdIsPreserved() {
        let fixedId = UUID()
        let now = Date()
        let course = Course(
            id: fixedId,
            title: "Test",
            teacherName: "Prof",
            room: "A1",
            date: now,
            slot: .morning,
            startsAt: now,
            endsAt: now
        )
        #expect(course.id == fixedId)
    }
}

// MARK: - Course + Signature (SwiftData in-memory)

@Suite("Course — signatures relationship")
@MainActor
struct CourseSignatureTests {

    @Test func isSignedTrueAfterInsert() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()

        let course = Course(
            title: "iOS Dev",
            teacherName: "Prof",
            room: "SM Apple",
            date: now,
            slot: .morning,
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600)
        )
        context.insert(course)

        let sig = Signature(course: course, slot: .morning)
        context.insert(sig)
        try context.save()

        #expect(course.isSigned == true)
        #expect(course.signatures.count == 1)
    }

    @Test func multipleSignaturesTracked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()

        let course = Course(
            title: "Swift Avancé",
            teacherName: "Prof",
            room: "SM Apple",
            date: now,
            slot: .morning,
            startsAt: now,
            endsAt: now.addingTimeInterval(7200)
        )
        context.insert(course)
        context.insert(Signature(course: course, slot: .morning))
        context.insert(Signature(course: course, slot: .afternoon))
        try context.save()

        #expect(course.signatures.count == 2)
        #expect(course.isSigned == true)
    }

    @Test func cascadeDeleteRemovesSignatures() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()

        let course = Course(
            title: "Test",
            teacherName: "Prof",
            room: "R1",
            date: now,
            slot: .morning,
            startsAt: now,
            endsAt: now.addingTimeInterval(3600)
        )
        context.insert(course)
        context.insert(Signature(course: course, slot: .morning))
        try context.save()

        context.delete(course)
        try context.save()

        let sigs = try context.fetch(FetchDescriptor<Signature>())
        #expect(sigs.isEmpty)
    }
}

// MARK: - Signature

@Suite("Signature")
struct SignatureModelTests {

    @Test func defaultValues() {
        let before = Date()
        let sig = Signature(slot: .morning)
        let after = Date()

        #expect(sig.slot == .morning)
        #expect(sig.isSynced == false)
        #expect(sig.signatureImageData == nil)
        #expect(sig.course == nil)
        #expect(sig.timestamp >= before)
        #expect(sig.timestamp <= after)
    }

    @Test func customValues() {
        let fixedId   = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47])

        let sig = Signature(
            id: fixedId,
            slot: .afternoon,
            timestamp: fixedDate,
            signatureImageData: pngHeader,
            isSynced: true
        )

        #expect(sig.id == fixedId)
        #expect(sig.slot == .afternoon)
        #expect(sig.timestamp == fixedDate)
        #expect(sig.signatureImageData == pngHeader)
        #expect(sig.isSynced == true)
    }

    @Test func uniqueIdsGenerated() {
        let s1 = Signature(slot: .morning)
        let s2 = Signature(slot: .morning)
        #expect(s1.id != s2.id)
    }

    @Test func afternoonSlotPreserved() {
        let sig = Signature(slot: .afternoon)
        #expect(sig.slot == .afternoon)
    }
}

// MARK: - DeviceInfo

@Suite("DeviceInfo")
struct DeviceInfoModelTests {

    @Test func initialization() {
        let info = DeviceInfo(deviceId: "device-123", userId: "user-456")
        #expect(info.deviceId == "device-123")
        #expect(info.userId == "user-456")
    }

    @Test func uniqueIdsGenerated() {
        let d1 = DeviceInfo(deviceId: "x", userId: "y")
        let d2 = DeviceInfo(deviceId: "x", userId: "y")
        #expect(d1.id != d2.id)
    }

    @Test func customIdPreserved() {
        let fixedId = UUID()
        let info = DeviceInfo(id: fixedId, deviceId: "abc", userId: "def")
        #expect(info.id == fixedId)
    }
}

// MARK: - LocalSignatureDraft

@Suite("LocalSignatureDraft")
struct LocalSignatureDraftModelTests {

    @Test func fullInitialization() {
        let courseId  = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let expiresAt = createdAt.addingTimeInterval(300)
        let imgData   = Data([1, 2, 3])

        let draft = LocalSignatureDraft(
            courseId: courseId,
            slot: .morning,
            totp: "123456",
            deviceId: "dev-001",
            signatureImageData: imgData,
            createdAt: createdAt,
            expiresAt: expiresAt
        )

        #expect(draft.courseId == courseId)
        #expect(draft.slot == .morning)
        #expect(draft.totp == "123456")
        #expect(draft.deviceId == "dev-001")
        #expect(draft.signatureImageData == imgData)
        #expect(draft.createdAt == createdAt)
        #expect(draft.expiresAt == expiresAt)
    }

    @Test func isExpiredWhenPastExpiresAt() {
        let pastExpiry = Date(timeIntervalSinceNow: -600)
        let draft = LocalSignatureDraft(
            courseId: nil,
            slot: .afternoon,
            totp: "000000",
            deviceId: "dev",
            signatureImageData: nil,
            createdAt: pastExpiry.addingTimeInterval(-300),
            expiresAt: pastExpiry
        )
        #expect(draft.expiresAt < Date())
    }

    @Test func isNotExpiredWhenFuture() {
        let future = Date(timeIntervalSinceNow: 300)
        let draft = LocalSignatureDraft(
            courseId: nil,
            slot: .morning,
            totp: "111111",
            deviceId: "dev",
            signatureImageData: nil,
            expiresAt: future
        )
        #expect(draft.expiresAt > Date())
    }

    @Test func nilCourseIdAllowed() {
        let draft = LocalSignatureDraft(
            courseId: nil,
            slot: .morning,
            totp: "999999",
            deviceId: "dev",
            signatureImageData: nil,
            expiresAt: Date()
        )
        #expect(draft.courseId == nil)
    }

    @Test func nilSignatureDataAllowed() {
        let draft = LocalSignatureDraft(
            courseId: UUID(),
            slot: .afternoon,
            totp: "424242",
            deviceId: "dev",
            signatureImageData: nil,
            expiresAt: Date()
        )
        #expect(draft.signatureImageData == nil)
    }
}

// MARK: - RemoteCourse JSON Decoding

@Suite("RemoteCourse — JSON decoding")
struct RemoteCourseDecodingTests {

    private func decode(_ json: String) throws -> RemoteCourse {
        try JSONDecoder().decode(RemoteCourse.self, from: Data(json.utf8))
    }

    @Test func fullPayloadWithTeacher() throws {
        let json = """
        {
            "id": "aaaaaaaa-0000-0000-0000-000000000001",
            "title": "iOS Development",
            "date": "2026-05-13",
            "slot": "morning",
            "room": "SM Apple",
            "teacher_id": "bbbbbbbb-0000-0000-0000-000000000001",
            "starts_at": "2026-05-13T09:00:00Z",
            "ends_at":   "2026-05-13T13:00:00Z",
            "teachers": { "name": "M. Fournier" }
        }
        """
        let course = try decode(json)
        #expect(course.id == "aaaaaaaa-0000-0000-0000-000000000001")
        #expect(course.title == "iOS Development")
        #expect(course.slot == "morning")
        #expect(course.room == "SM Apple")
        #expect(course.teachers?.name == "M. Fournier")
    }

    @Test func payloadWithNullTeacher() throws {
        let json = """
        {
            "id": "aaaaaaaa-0000-0000-0000-000000000002",
            "title": "Swift Avancé",
            "date": "2026-05-14",
            "slot": "afternoon",
            "room": "Lab 2",
            "teacher_id": "bbbbbbbb-0000-0000-0000-000000000002",
            "starts_at": "2026-05-14T14:00:00Z",
            "ends_at":   "2026-05-14T18:00:00Z",
            "teachers": null
        }
        """
        let course = try decode(json)
        #expect(course.teachers == nil)
        #expect(course.slot == "afternoon")
    }

    @Test func morningAndAfternoonSlotsPreserved() throws {
        for slotStr in ["morning", "afternoon"] {
            let json = """
            {
                "id": "aaaaaaaa-0000-0000-0000-000000000003",
                "title": "T",
                "date": "2026-05-13",
                "slot": "\(slotStr)",
                "room": "R",
                "teacher_id": "t",
                "starts_at": "2026-05-13T09:00:00Z",
                "ends_at":   "2026-05-13T13:00:00Z",
                "teachers": null
            }
            """
            let course = try decode(json)
            #expect(course.slot == slotStr)
        }
    }
}

// MARK: - RemoteSignature JSON Decoding

@Suite("RemoteSignature — JSON decoding")
struct RemoteSignatureDecodingTests {

    @Test func fullPayload() throws {
        let json = """
        {
            "id": "cccccccc-0000-0000-0000-000000000001",
            "student_id": "dddddddd-0000-0000-0000-000000000001",
            "course_id":  "aaaaaaaa-0000-0000-0000-000000000001",
            "slot": "morning",
            "timestamp": "2026-05-13T09:15:00Z",
            "image_path": "signatures/file.png"
        }
        """
        let sig = try JSONDecoder().decode(RemoteSignature.self, from: Data(json.utf8))
        #expect(sig.id == "cccccccc-0000-0000-0000-000000000001")
        #expect(sig.slot == "morning")
        #expect(sig.image_path == "signatures/file.png")
    }

    @Test func nullImagePath() throws {
        let json = """
        {
            "id": "cccccccc-0000-0000-0000-000000000002",
            "student_id": "s",
            "course_id":  "c",
            "slot": "afternoon",
            "timestamp": "2026-05-13T14:00:00Z",
            "image_path": null
        }
        """
        let sig = try JSONDecoder().decode(RemoteSignature.self, from: Data(json.utf8))
        #expect(sig.image_path == nil)
    }
}

// MARK: - SignResponse JSON Decoding

@Suite("SignResponse — JSON decoding")
struct SignResponseDecodingTests {

    @Test func successResponse() throws {
        let json = #"{ "ok": true, "signature_id": "sig-123", "error": null }"#
        let resp = try JSONDecoder().decode(SignResponse.self, from: Data(json.utf8))
        #expect(resp.ok == true)
        #expect(resp.signature_id == "sig-123")
        #expect(resp.error == nil)
    }

    @Test func errorResponse() throws {
        let json = #"{ "ok": false, "signature_id": null, "error": "TOTP invalid" }"#
        let resp = try JSONDecoder().decode(SignResponse.self, from: Data(json.utf8))
        #expect(resp.ok == false)
        #expect(resp.signature_id == nil)
        #expect(resp.error == "TOTP invalid")
    }

    @Test func okFalseWithNoSignatureId() throws {
        let json = #"{ "ok": false, "signature_id": null, "error": "already signed" }"#
        let resp = try JSONDecoder().decode(SignResponse.self, from: Data(json.utf8))
        #expect(resp.ok == false)
        #expect(resp.signature_id == nil)
    }
}

// MARK: - StudentRecord JSON Encoding

@Suite("StudentRecord — JSON encoding")
struct StudentRecordEncodingTests {

    @Test func encodesAllFields() throws {
        let record = StudentRecord(
            id: "user-001",
            email: "alice@example.com",
            name: "alice",
            device_id: "device-abc"
        )
        let data = try JSONEncoder().encode(record)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(dict?["id"] == "user-001")
        #expect(dict?["email"] == "alice@example.com")
        #expect(dict?["name"] == "alice")
        #expect(dict?["device_id"] == "device-abc")
    }

    @Test func emailDerivedName() throws {
        let email = "bob.martin@epitech.eu"
        let name = email.components(separatedBy: "@").first ?? ""
        let record = StudentRecord(id: "u", email: email, name: name, device_id: "d")
        #expect(record.name == "bob.martin")
    }
}

// MARK: - SHA256 (matches SigningService hash logic)

@Suite("SHA256 — SigningService hashing")
struct SHA256Tests {

    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    @Test func knownHash() {
        // echo -n "hello" | sha256sum
        #expect(sha256Hex(Data("hello".utf8))
            == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test func emptyDataHash() {
        // sha256("") is well-known
        #expect(sha256Hex(Data())
            == "e3b0c44298fc1c149afbf4c8996fb924" +
               "27ae41e4649b934ca495991b7852b855")
    }

    @Test func hashLengthIs64Chars() {
        #expect(sha256Hex(Data("EpiSign".utf8)).count == 64)
    }

    @Test func differentDataProducesDifferentHash() {
        #expect(sha256Hex(Data("abc".utf8)) != sha256Hex(Data("def".utf8)))
    }

    @Test func deterministicForSameInput() {
        let data = Data("test".utf8)
        #expect(sha256Hex(data) == sha256Hex(data))
    }

    @Test func hexOutputIsLowercase() {
        let hex = sha256Hex(Data("EpiSign".utf8))
        #expect(hex == hex.lowercased())
    }
}

// MARK: - TOTP Validation (mirrors AudioManager logic)

@Suite("TOTP Validation — AudioManager")
struct TOTPValidationTests {

    private func isValidTOTP(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 6 && trimmed.allSatisfy { $0.isASCII && $0.isNumber }
    }

    @Test func validSixDigitCodes() {
        #expect(isValidTOTP("123456") == true)
        #expect(isValidTOTP("000000") == true)
        #expect(isValidTOTP("999999") == true)
    }

    @Test func trimmingWhitespace() {
        #expect(isValidTOTP("  123456  ") == true)
        #expect(isValidTOTP("\n123456\n") == true)
        #expect(isValidTOTP("\t654321\t") == true)
    }

    @Test func tooShortRejected() {
        #expect(isValidTOTP("12345")  == false)
        #expect(isValidTOTP("")       == false)
        #expect(isValidTOTP("1")      == false)
    }

    @Test func tooLongRejected() {
        #expect(isValidTOTP("1234567") == false)
        #expect(isValidTOTP("12345678") == false)
    }

    @Test func nonNumericRejected() {
        #expect(isValidTOTP("12345a") == false)
        #expect(isValidTOTP("ABCDEF") == false)
        #expect(isValidTOTP("12 456") == false)
        #expect(isValidTOTP("12.456") == false)
    }

    @Test func leadingZerosAllowed() {
        #expect(isValidTOTP("001234") == true)
        #expect(isValidTOTP("000001") == true)
    }
}
