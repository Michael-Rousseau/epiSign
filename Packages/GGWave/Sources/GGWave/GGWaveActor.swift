import Foundation
import CGGWave

public actor GGWaveActor {
    private var instance: ggwave_Instance = 0
    private let sampleRate: Int

    public init(sampleRate: Int = 48000) {
        self.sampleRate = sampleRate
        var params = ggwave_getDefaultParameters()
        params.sampleRateInp = Int32(sampleRate)
        params.sampleRateOut = Int32(sampleRate)
        instance = ggwave_init(params)
    }

    deinit {
        if instance != 0 {
            ggwave_free(instance)
        }
    }

    /// Decode audio samples. Returns the detected payload string, or nil.
    public func decode(samples: [Float]) -> String? {
        guard instance != 0, !samples.isEmpty else { return nil }

        var output = [CChar](repeating: 0, count: 256)
        let result: Int32 = samples.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count * MemoryLayout<Float>.size) { ptr in
                ggwave_ndecode(instance, ptr, Int32(buf.count * MemoryLayout<Float>.size), &output, 256)
            }
        }

        if result > 0 {
            return String(cString: output)
        }
        return nil
    }

    /// Encode a string payload into audio samples for transmission.
    public func encode(payload: String, protocolId: Int32 = 5, volume: Int32 = 10) -> [Float]? {
        guard instance != 0 else { return nil }

        // First call to get size
        let size = ggwave_encode(instance, payload, Int32(payload.utf8.count), protocolId, volume, nil, 0)
        guard size > 0 else { return nil }

        var output = [CChar](repeating: 0, count: Int(size))
        let written = ggwave_encode(instance, payload, Int32(payload.utf8.count), protocolId, volume, &output, 0)
        guard written > 0 else { return nil }

        // Convert bytes to Float samples
        let floatCount = Int(written) / MemoryLayout<Float>.size
        return output.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: Float.self, capacity: floatCount) { ptr in
                Array(UnsafeBufferPointer(start: ptr, count: floatCount))
            }
        }
    }
}
