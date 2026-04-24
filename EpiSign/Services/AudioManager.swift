import AVFoundation
import Accelerate
import SwiftUI

@Observable
final class AudioManager {
    var spectrumData: [Float] = Array(repeating: 0, count: 64)
    var detectedTOTP: String?
    var isListening = false
    var permissionGranted = false

    private var engine: AVAudioEngine?
    private let fftSize = 2048
    private var fftSetup: vDSP_DFT_Setup?

    // ggwave instance (nil until package is linked)
    private var ggwaveInstance: OpaquePointer?

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    func requestPermission() async {
        if #available(iOS 17, *) {
            permissionGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            permissionGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    func start() {
        guard permissionGranted, !isListening else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        engine = AVAudioEngine()
        guard let engine else { return }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        let sampleRate = hwFormat.sampleRate

        // Install a single tap — fan out to FFT visualizer and ggwave decoder
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: hwFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)

            // 1. FFT for spectrum visualization (17-21 kHz band)
            self.computeSpectrum(data: channelData, count: frameCount, sampleRate: Float(sampleRate))

            // 2. ggwave decode (will be wired when package is available)
            self.decodeGGWave(data: channelData, count: frameCount)
        }

        do {
            try engine.start()
            isListening = true
        } catch {
            print("AudioManager: engine start failed: \(error)")
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isListening = false
    }

    // MARK: - FFT Spectrum (17-21 kHz band)

    private func computeSpectrum(data: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float) {
        guard let fftSetup, count >= fftSize else { return }

        var realInput = [Float](repeating: 0, count: fftSize)
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Copy samples into real part
        for i in 0..<min(count, fftSize) {
            realInput[i] = data[i]
        }

        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftSize))

        // Perform DFT
        vDSP_DFT_Execute(fftSetup, realInput, imagInput, &realOutput, &imagOutput)

        // Compute magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuf in
            imagOutput.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Extract 17-21 kHz band (64 bars)
        let binResolution = sampleRate / Float(fftSize)
        let lowBin = Int(17000.0 / binResolution)
        let highBin = min(Int(21000.0 / binResolution), fftSize / 2 - 1)
        let bandWidth = highBin - lowBin
        let barsCount = 64

        var bars = [Float](repeating: 0, count: barsCount)
        let binsPerBar = max(1, bandWidth / barsCount)

        for i in 0..<barsCount {
            let startBin = lowBin + i * binsPerBar
            let endBin = min(startBin + binsPerBar, fftSize / 2)
            guard startBin < endBin else { continue }

            var sum: Float = 0
            for b in startBin..<endBin {
                sum += magnitudes[b]
            }
            let avg = sum / Float(endBin - startBin)
            // Convert to dB scale, normalize
            bars[i] = max(0, min(1, (10 * log10(avg + 1e-10) + 60) / 60))
        }

        Task { @MainActor in
            self.spectrumData = bars
        }
    }

    // MARK: - ggwave Decode

    private func decodeGGWave(data: UnsafeMutablePointer<Float>, count: Int) {
        // TODO: Wire to ggwave C library when package is linked
        // The integration point:
        //   1. Feed audio samples to ggwave_decode()
        //   2. If a payload is detected, parse the 6-digit TOTP
        //   3. Publish to detectedTOTP
        //
        // Example (once CGGWave is available):
        //   let result = ggwave_decode(instance, data, Int32(count), &output)
        //   if result > 0 {
        //       let totp = String(cString: output)
        //       if totp.range(of: "^\\d{6}$", options: .regularExpression) != nil {
        //           Task { @MainActor in self.detectedTOTP = totp }
        //       }
        //   }
    }
}
