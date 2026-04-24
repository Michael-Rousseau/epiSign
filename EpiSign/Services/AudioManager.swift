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

    var devMode: Bool = false {
        didSet {
            if isListening {
                stop()
                start()
            }
        }
    }

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let fftSize = 2048
    private var fftSetup: vDSP_DFT_Setup?

    private let decodeQueue = DispatchQueue(label: "com.EpiSign.ggwave-decode")
    private var decoder: GGWaveDecoder?
    private var decodeCallCount = 0
    private let ggwaveSamplesPerFrame = 1024
    private var pendingSamples: [Float] = []  // accumulate until we have 1024

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

        log.info("start: sr=\(sampleRate) ch=\(hwFormat.channelCount) devMode=\(self.devMode)")

        decodeQueue.sync {
            decoder = GGWaveDecoder(sampleRate: Int(sampleRate))
        }
        decodeCallCount = 0

        let player = AVAudioPlayerNode()
        engine.attach(player)
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        playerNode = player

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: hwFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            self.computeSpectrum(data: channelData, count: frameCount, sampleRate: Float(sampleRate))
            self.feedGGWave(data: channelData, count: frameCount)
        }

        do {
            try engine.start()
            isListening = true
            log.info("engine started")
            Task { @MainActor in
                self.debugStatus = "Listening (\(Int(sampleRate)) Hz)"
            }
        } catch {
            log.error("engine failed: \(error)")
        }
    }

    func stop() {
        playerNode?.stop()
        playerNode = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isListening = false
        decodeQueue.sync {
            decoder = nil
            pendingSamples = []
        }
    }

    func playTOTP(_ code: String, protocolId: Int32 = 0, volume: Int32 = 100) {
        guard let engine, let playerNode else { return }

        decodeQueue.async { [weak self] in
            guard let self, let decoder = self.decoder else { return }
            guard let samples = decoder.encode(payload: code, protocolId: protocolId, volume: volume) else { return }

            let sampleRate = engine.inputNode.outputFormat(forBus: 0).sampleRate
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buffer.frameLength = AVAudioFrameCount(samples.count)
            let channelData = buffer.floatChannelData![0]
            for i in 0..<samples.count { channelData[i] = samples[i] }

            DispatchQueue.main.async {
                playerNode.scheduleBuffer(buffer, at: nil)
                playerNode.play()
            }
        }
    }

    // MARK: - Spectrum

    var spectrumLowFreq: Float { devMode ? 1000.0 : 17000.0 }
    var spectrumHighFreq: Float { devMode ? 6000.0 : 21000.0 }

    private func computeSpectrum(data: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float) {
        guard let fftSetup, count >= fftSize else { return }

        var realInput = [Float](repeating: 0, count: fftSize)
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        for i in 0..<min(count, fftSize) { realInput[i] = data[i] }

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
            for b in startBin..<endBin { sum += magnitudes[b] }
            let avg = sum / Float(endBin - startBin)
            bars[i] = max(0, min(1, (10 * log10(avg + 1e-10) + 60) / 60))
        }

        Task { @MainActor in self.spectrumData = bars }
    }

    // MARK: - ggwave Decode

    private func feedGGWave(data: UnsafeMutablePointer<Float>, count: Int) {
        let newSamples = Array(UnsafeBufferPointer(start: data, count: count))
        decodeCallCount += 1
        let n = decodeCallCount

        if n % 20 == 0 {
            let peak = newSamples.max() ?? 0
            log.info("mic #\(n) | \(count) samples | peak=\(peak)")
        }

        // ggwave needs exactly samplesPerFrame (1024) samples per decode call.
        // The audio tap delivers variable-size buffers (e.g. 4800), so we chunk them.
        decodeQueue.async { [weak self] in
            guard let self, let decoder = self.decoder else { return }

            self.pendingSamples.append(contentsOf: newSamples)

            while self.pendingSamples.count >= self.ggwaveSamplesPerFrame {
                let chunk = Array(self.pendingSamples.prefix(self.ggwaveSamplesPerFrame))
                self.pendingSamples.removeFirst(self.ggwaveSamplesPerFrame)

                let payload: String? = chunk.withUnsafeBufferPointer { buf in
                    decoder.decode(samples: buf)
                }

                if let payload {
                    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    log.info("TOTP received: '\(trimmed)'")
                    if trimmed.count == 6, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
                        DispatchQueue.main.async {
                            self.detectedTOTP = trimmed
                            self.debugStatus = "Decoded: \(trimmed)"
                        }
                    }
                }
            }
        }
    }
}
