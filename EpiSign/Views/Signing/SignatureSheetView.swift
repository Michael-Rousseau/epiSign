import SwiftUI
import SwiftData
import PencilKit
import Functions

struct SignatureSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let course: Course
    let totpCode: String
    var onSigned: ((String?) -> Void)?

    @State private var canvasView = PKCanvasView()
    @State private var hasDrawn = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Signez ci-dessous")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                SignatureCanvas(canvasView: $canvasView, hasDrawn: $hasDrawn)
                    .frame(height: 250)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                if let error = errorMessage {
                    Text(friendlyError(error))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        canvasView.drawing = PKDrawing()
                        hasDrawn = false
                    } label: {
                        Text("Effacer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                    }

                    Button {
                        Task { await confirmSignature() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.white.opacity(0.3)))
                        } else {
                            Text("Confirmer")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(hasDrawn ? Color.white : Color.white.opacity(0.3)))
                                .foregroundStyle(hasDrawn ? .black : .white.opacity(0.5))
                        }
                    }
                    .disabled(!hasDrawn || isSubmitting)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func confirmSignature() async {
        let drawing = canvasView.drawing
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return }

        let image = drawing.image(from: bounds, scale: 2.0)
        guard let pngData = image.pngData() else { return }

        isSubmitting = true
        errorMessage = nil

        // Get device ID
        let descriptor = FetchDescriptor<DeviceInfo>()
        let deviceId = (try? modelContext.fetch(descriptor))?.first?.deviceId ?? UUID().uuidString

        // Try to submit to Supabase
        let signingService = SigningService()
        do {
            let response = try await signingService.submitSignature(
                courseId: course.id,
                totp: totpCode,
                signaturePNG: pngData,
                slot: course.slot,
                deviceId: deviceId
            )

            if response.ok {
                // Save local signature record
                let signature = Signature(
                    course: course,
                    slot: course.slot,
                    signatureImageData: pngData,
                    isSynced: true
                )
                modelContext.insert(signature)
                try? modelContext.save()
                onSigned?(nil)
                dismiss()
            } else {
                errorMessage = response.error ?? "Erreur inconnue"
                onSigned?(errorMessage)
            }
        } catch let error as URLError {
            // Network error: save as draft for offline retry
            let draft = LocalSignatureDraft(
                courseId: course.id,
                slot: course.slot,
                totp: totpCode,
                deviceId: deviceId,
                signatureImageData: pngData,
                expiresAt: course.endsAt
            )
            modelContext.insert(draft)

            let signature = Signature(
                course: course,
                slot: course.slot,
                signatureImageData: pngData,
                isSynced: false
            )
            modelContext.insert(signature)
            try? modelContext.save()
            onSigned?(nil)
            dismiss()
        } catch let error as FunctionsError {
            if case .httpError(_, let data) = error,
               let response = try? JSONDecoder().decode(SignResponse.self, from: data) {
                errorMessage = friendlyError(response.error ?? "Erreur inconnue")
            } else {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
            onSigned?(errorMessage)
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            onSigned?(errorMessage)
        }

        isSubmitting = false
    }

    private func friendlyError(_ code: String) -> String {
        switch code {
        case "invalid_totp": return "Code invalide, veuillez réessayer"
        case "out_of_window": return "Le cours n'est pas en cours"
        case "already_signed": return "Vous avez déjà signé"
        case "device_mismatch": return "Appareil non reconnu"
        case "no_totp_secret": return "Configuration du cours incomplète"
        default: return code
        }
    }
}

struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var hasDrawn: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(hasDrawn: $hasDrawn)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasDrawn: Bool

        init(hasDrawn: Binding<Bool>) {
            _hasDrawn = hasDrawn
        }

        nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            Task { @MainActor in
                hasDrawn = !canvasView.drawing.strokes.isEmpty
            }
        }
    }
}
