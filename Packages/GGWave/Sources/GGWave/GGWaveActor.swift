import Foundation
import CGGWave
import os

private let log = Logger(subsystem: "com.EpiSign", category: "GGWave")

/// Thread-unsafe ggwave wrapper. All methods must be called from a single serial queue.
public final class GGWaveDecoder: @unchecked Sendable {
    private var instance: ggwave_Instance = -1

    public init(sampleRate: Int = 48000, markerThreshold: Float = 3.0) {
        var params = ggwave_getDefaultParameters()
        params.sampleRateInp = Float(sampleRate)
        params.sampleRateOut = Float(sampleRate)
        params.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_F32
        params.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_F32
        params.operatingMode = Int32(GGWAVE_OPERATING_MODE_RX_AND_TX)
        params.soundMarkerThreshold = markerThreshold
        instance = ggwave_init(params)
        log.info("init instance=\(self.instance) sr=\(sampleRate) threshold=\(markerThreshold)")
    }

    deinit {
        if instance >= 0 {
            ggwave_free(instance)
        }
    }

    public func decode(samples: UnsafeBufferPointer<Float>) -> String? {
        guard instance >= 0, samples.count > 0 else { return nil }

        var output = [UInt8](repeating: 0, count: 256)
        let waveformSize = Int32(samples.count * MemoryLayout<Float>.size)

        let result: Int32 = output.withUnsafeMutableBufferPointer { outBuf in
            ggwave_ndecode(
                instance,
                samples.baseAddress!,
                waveformSize,
                outBuf.baseAddress!,
                256
            )
        }

        if result > 0 {
            let data = Data(output.prefix(Int(result)))
            let text = String(data: data, encoding: .utf8)
            log.info("DECODED \(result) bytes: '\(text ?? "<nil>")'")
            return text
        } else if result < 0 {
            log.error("decode error: \(result)")
        }
        return nil
    }

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
        log.info("encoded '\(payload)' → \(floatCount) samples")
        return output.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: Float.self, capacity: floatCount) { ptr in
                Array(UnsafeBufferPointer(start: ptr, count: floatCount))
            }
        }
    }
}
