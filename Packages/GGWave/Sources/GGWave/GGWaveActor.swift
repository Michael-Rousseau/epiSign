import Foundation
import CGGWave
import os

private let log = Logger(subsystem: "com.EpiSign", category: "GGWave")

public actor GGWaveActor {
    // -1 = not initialized; 0, 1, 2, ... = valid instance IDs
    private var instance: ggwave_Instance = -1
    private let sampleRate: Int
    private var decodeCount: Int = 0

    public init(sampleRate: Int = 48000) {
        self.sampleRate = sampleRate
        var params = ggwave_getDefaultParameters()
        params.sampleRateInp = Float(sampleRate)
        params.sampleRateOut = Float(sampleRate)
        params.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_F32
        params.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_F32
        params.operatingMode = Int32(GGWAVE_OPERATING_MODE_RX_AND_TX)
        instance = ggwave_init(params)
        log.info("init instance=\(self.instance) sampleRate=\(sampleRate)")
    }

    deinit {
        if instance >= 0 {
            ggwave_free(instance)
        }
    }

    /// Decode audio samples (Float32). Returns the detected payload string, or nil.
    public func decode(samples: [Float]) -> String? {
        guard instance >= 0, !samples.isEmpty else {
            if decodeCount == 0 {
                log.error("decode skipped — instance=\(self.instance)")
            }
            return nil
        }

        var output = [UInt8](repeating: 0, count: 256)
        let waveformSize = Int32(samples.count * MemoryLayout<Float>.size)

        let result: Int32 = samples.withUnsafeBufferPointer { buf in
            output.withUnsafeMutableBufferPointer { outBuf in
                ggwave_ndecode(
                    instance,
                    buf.baseAddress!,
                    waveformSize,
                    outBuf.baseAddress!,
                    256
                )
            }
        }

        decodeCount += 1

        // Log non-zero results always, periodic status every 100 calls
        if result != 0 {
            log.info("decode #\(self.decodeCount) returned \(result)")
        } else if decodeCount % 100 == 0 {
            log.info("decode #\(self.decodeCount) still listening (0)")
        }

        if result > 0 {
            let data = Data(output.prefix(Int(result)))
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Encode a string payload into audio samples for transmission.
    public func encode(payload: String, protocolId: Int32 = 3, volume: Int32 = 25) -> [Float]? {
        guard instance >= 0 else { return nil }

        let payloadBytes = Array(payload.utf8)

        let sizeBytes = payloadBytes.withUnsafeBufferPointer { buf in
            ggwave_encode(
                instance,
                buf.baseAddress!,
                Int32(buf.count),
                ggwave_ProtocolId(rawValue: UInt32(protocolId)),
                volume,
                nil,
                1
            )
        }
        guard sizeBytes > 0 else { return nil }

        var output = [UInt8](repeating: 0, count: Int(sizeBytes))
        let written = payloadBytes.withUnsafeBufferPointer { buf in
            output.withUnsafeMutableBufferPointer { outBuf in
                ggwave_encode(
                    instance,
                    buf.baseAddress!,
                    Int32(buf.count),
                    ggwave_ProtocolId(rawValue: UInt32(protocolId)),
                    volume,
                    outBuf.baseAddress!,
                    0
                )
            }
        }
        guard written > 0 else { return nil }

        let floatCount = Int(written) / MemoryLayout<Float>.size
        return output.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: Float.self, capacity: floatCount) { ptr in
                Array(UnsafeBufferPointer(start: ptr, count: floatCount))
            }
        }
    }
}
