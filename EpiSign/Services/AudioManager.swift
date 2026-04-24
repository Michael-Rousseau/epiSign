import AVFoundation
import Accelerate
import SwiftUI
import GGWave
import os

private let log = Logger(subsystem: "com.EpiSign", category: "AudioManager")

@Observable
final class AudioManager {
    var spectrumData: [Float] = Array(repeating: 0, count: 64)
    var detectedTOTP: String?
    var isListening = false
    var permissionGranted = false
    var debugStatus: String = ""

    /// When true, listens for audible-range signals (~1-4 kHz) instead of ultrasound (17-21 kHz).
    /// Toggle this for local MacBook testing where speakers can't emit ultrasound.
    var devMode: Bool = false {
        didSet {
            if isListening {
                stop()
                start()
            }
        }
    }

    private var engine: AVAudioEngine?
    private let fftSize = 2048
    private var fftSetup: vDSP_DFT_Setup?

    // ggwave decoder actor — created on start() with the hardware sample rate
    private var ggwave: GGWaveActor?
    private var decodeCallCount = 0
    // Serial queue ensures audio samples are fed to ggwave in chronological order
    private let decodeQueue = DispatchQueue(label: "com.EpiSign.ggwave-decode")

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        log.info("init")
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
        log.info("permission: \(self.permissionGranted)")
    }

    func start() {
        guard permissionGranted, !isListening else {
            log.warning("start blocked — permission: \(self.permissionGranted), listening: \(self.isListening)")
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        engine = AVAudioEngine()
        guard let engine else { return }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        let sampleRate = hwFormat.sampleRate

        log.info("sampleRate: \(sampleRate), channels: \(hwFormat.channelCount), devMode: \(self.devMode)")

        // Create ggwave instance at the hardware sample rate
        ggwave = GGWaveActor(sampleRate: Int(sampleRate))
        decodeCallCount = 0
        log.info("ggwave actor created at \(Int(sampleRate)) Hz")

        // Acoustic self-test: encode with C library, play through speaker,
        // mic captures it, ggwave decodes. Tests the full acoustic path.
        let capturedSampleRate = sampleRate
        Task {
            guard let ggwave else { return }
            log.info("acoustic-test: encoding '999999' with AUDIBLE_NORMAL (proto 0)")
            if let samples = await ggwave.encode(payload: "999999", protocolId: 0, volume: 100) {
                log.info("acoustic-test: playing \(samples.count) samples through speaker...")

                // Play the encoded audio through the device speaker
                let audioFormat = AVAudioFormat(standardFormatWithSampleRate: capturedSampleRate, channels: 1)!
                let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples.count))!
                buffer.frameLength = AVAudioFrameCount(samples.count)
                let channelData = buffer.floatChannelData![0]
                for i in 0..<samples.count {
                    channelData[i] = samples[i]
                }

                let playerNode = AVAudioPlayerNode()
                let playerEngine = AVAudioEngine()
                playerEngine.attach(playerNode)
                playerEngine.connect(playerNode, to: playerEngine.mainMixerNode, format: audioFormat)
                try? playerEngine.start()
                await playerNode.scheduleBuffer(buffer, at: nil)
                playerNode.play()

                log.info("acoustic-test: audio playing — mic should pick it up and ggwave should decode")

                // Wait for playback to finish
                try? await Task.sleep(for: .seconds(3))
                playerNode.stop()
                playerEngine.stop()
                log.info("acoustic-test: playback done")
            } else {
                log.error("acoustic-test: encode returned nil")
            }
        }

        // Install a single tap — fan out to FFT visualizer and ggwave decoder
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: hwFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)

            // 1. FFT for spectrum visualization
            self.computeSpectrum(data: channelData, count: frameCount, sampleRate: Float(sampleRate))

            // 2. Feed samples to ggwave for decoding
            self.feedGGWave(data: channelData, count: frameCount)
        }

        do {
            try engine.start()
            isListening = true
            log.info("engine started OK")
            Task { @MainActor in
                self.debugStatus = "Listening (\(Int(sampleRate)) Hz)"
            }
        } catch {
            log.error("engine start FAILED: \(error)")
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isListening = false
        ggwave = nil
        log.info("stopped")
    }

    // MARK: - Spectrum frequency band based on mode

    var spectrumLowFreq: Float {
        devMode ? 1000.0 : 17000.0
    }

    var spectrumHighFreq: Float {
        devMode ? 6000.0 : 21000.0
    }

    // MARK: - FFT Spectrum

    private func computeSpectrum(data: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float) {
        guard let fftSetup, count >= fftSize else { return }

        var realInput = [Float](repeating: 0, count: fftSize)
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        for i in 0..<min(count, fftSize) {
            realInput[i] = data[i]
        }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftSize))

        vDSP_DFT_Execute(fftSetup, realInput, imagInput, &realOutput, &imagOutput)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOutput.withUnsafeMutableBufferPointer { realBuf in
            imagOutput.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        let binResolution = sampleRate / Float(fftSize)
        let lowBin = Int(spectrumLowFreq / binResolution)
        let highBin = min(Int(spectrumHighFreq / binResolution), fftSize / 2 - 1)
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
            bars[i] = max(0, min(1, (10 * log10(avg + 1e-10) + 60) / 60))
        }

        Task { @MainActor in
            self.spectrumData = bars
        }
    }

    // MARK: - ggwave Decode

    private func feedGGWave(data: UnsafeMutablePointer<Float>, count: Int) {
        guard let ggwave else {
            log.error("feedGGWave: no ggwave instance!")
            return
        }

        let samples = Array(UnsafeBufferPointer(start: data, count: count))
        decodeCallCount += 1

        let callNum = decodeCallCount
        let shouldLog = (callNum % 50 == 0)

        if shouldLog {
            let maxSample = samples.max() ?? 0
            log.info("decode call #\(callNum) | samples: \(count) | peak: \(maxSample)")
        }

        // Use serial queue to guarantee samples are fed in chronological order.
        // Creating separate Tasks per buffer causes out-of-order delivery to the actor.
        decodeQueue.async { [weak self] in
            guard let self else { return }
            let semaphore = DispatchSemaphore(value: 0)
            var payload: String? = nil
            Task {
                payload = await ggwave.decode(samples: samples)
                semaphore.signal()
            }
            semaphore.wait()

            if let payload {
                log.info("ggwave decoded payload: \(payload)")
                let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count == 6, trimmed.allSatisfy(\.isNumber) {
                    log.info("TOTP DETECTED: \(trimmed)")
                    DispatchQueue.main.async {
                        self.detectedTOTP = trimmed
                        self.debugStatus = "Decoded: \(trimmed)"
                    }
                } else {
                    log.warning("decoded but not 6-digit TOTP: \(trimmed)")
                }
            }
        }
    }
}
