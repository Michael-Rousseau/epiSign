import SwiftUI
import SwiftData

struct SigningView: View {
    let course: Course
    @Environment(\.modelContext) private var modelContext
    @State private var audioManager = AudioManager()
    @State private var showSignatureSheet = false
    @State private var totpCode: String = ""
    @State private var signingError: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 0) {
            // Course info header
            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("\(course.teacherName) \u{00B7} \(course.room)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(course.formattedTimeArrow)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            // Spectrum visualizer
            SpectrumVisualizerView(
                spectrumData: audioManager.spectrumData,
                isActive: audioManager.isListening && !course.isSigned
            )

            Spacer()

            // Status
            VStack(spacing: 6) {
                if course.isSigned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .padding(.bottom, 4)
                    Text("Signé")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Signature enregistrée")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                } else if let totp = audioManager.detectedTOTP {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .padding(.bottom, 4)
                    Text("Code détecté : \(totp)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Vous pouvez signer")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                } else if audioManager.isListening {
                    Text("Ready to sign")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(audioManager.devMode ? "Listening 1-4 kHz (dev)" : "Approach your instructor")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    if !audioManager.debugStatus.isEmpty {
                        Text(audioManager.debugStatus)
                            .font(.caption2)
                            .foregroundStyle(.yellow.opacity(0.7))
                            .padding(.top, 4)
                    }
                } else {
                    Text("Microphone requis")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Autorisez l'accès au micro")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            if !course.isSigned {
                // Manual TOTP entry (fallback)
                HStack(spacing: 12) {
                    TextField("Code TOTP", text: $totpCode)
                        .keyboardType(.numberPad)
                        .font(.title3.monospaced())
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)
                        .frame(maxWidth: 180)
                        .onChange(of: audioManager.detectedTOTP ?? "") { _, newValue in
                            if !newValue.isEmpty {
                                totpCode = newValue
                            }
                        }
                }
                .padding(.bottom, 12)

                if let error = signingError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }

                // Sign button
                Button {
                    showSignatureSheet = true
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.white.opacity(0.5)))
                    } else {
                        Text("Sign")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(canSign ? Color.white : Color.white.opacity(0.3)))
                            .foregroundStyle(canSign ? .black : .white.opacity(0.5))
                    }
                }
                .disabled(!canSign || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            await audioManager.requestPermission()
            if audioManager.permissionGranted {
                audioManager.start()
            }
        }
        .onDisappear {
            audioManager.stop()
        }
        .sheet(isPresented: $showSignatureSheet) {
            SignatureSheetView(
                course: course,
                totpCode: totpCode,
                onSigned: { error in
                    signingError = error
                }
            )
        }
    }

    private var canSign: Bool {
        totpCode.count == 6 && totpCode.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
