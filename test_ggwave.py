#!/usr/bin/env python3
"""
Test ggwave encode → speaker → mic → decode on the local machine.
Uses the same ggwave Python library (which wraps the same C code).

Usage:
  # Terminal 1: listen
  python3 test_ggwave.py listen

  # Terminal 2: emit
  python3 test_ggwave.py emit

  # Or self-test (digital loopback, no speaker/mic):
  python3 test_ggwave.py selftest
"""

import sys
import numpy as np
import sounddevice as sd
import ggwave

SAMPLE_RATE = 48000
PROTOCOL_ID = 0  # GGWAVE_PROTOCOL_AUDIBLE_NORMAL
VOLUME = 100


def selftest():
    """Digital loopback: encode → decode in memory. No speaker/mic."""
    print("[selftest] Encoding '123456' with protocol", PROTOCOL_ID)
    instance = ggwave.init()

    waveform = ggwave.encode("123456", protocolId=PROTOCOL_ID, volume=VOLUME, instance=instance)
    print(f"[selftest] Encoded {len(waveform)} bytes")

    result = ggwave.decode(instance, waveform)
    if result is not None:
        text = result.decode('utf-8') if isinstance(result, bytes) else result
        print(f"[selftest] DECODED: '{text}'")
    else:
        print("[selftest] decode returned None — trying chunk by chunk...")
        # Feed in chunks like the iOS app does
        chunk_size = 1024 * 4  # 1024 float32 samples = 4096 bytes
        for i in range(0, len(waveform), chunk_size):
            chunk = waveform[i:i+chunk_size]
            result = ggwave.decode(instance, chunk)
            if result is not None:
                text = result.decode('utf-8') if isinstance(result, bytes) else result
                print(f"[selftest] DECODED at offset {i}: '{text}'")
                break
        else:
            print("[selftest] FAILED — no decode after all chunks")

    ggwave.free(instance)


def emit():
    """Encode and play through speakers."""
    print(f"[emit] Encoding '123456' with protocol {PROTOCOL_ID}, volume {VOLUME}")
    instance = ggwave.init()
    waveform = ggwave.encode("123456", protocolId=PROTOCOL_ID, volume=VOLUME, instance=instance)
    ggwave.free(instance)

    # Convert bytes to float32 array
    samples = np.frombuffer(waveform, dtype=np.float32)
    duration = len(samples) / SAMPLE_RATE
    print(f"[emit] Playing {len(samples)} samples ({duration:.2f}s) at {SAMPLE_RATE} Hz")
    print("[emit] You should hear a chirp/buzz sound...")

    sd.play(samples, SAMPLE_RATE)
    sd.wait()
    print("[emit] Done. Run again to repeat, or use 'listen' in another terminal.")


def listen():
    """Capture mic audio and try to decode ggwave signals."""
    print(f"[listen] Listening on mic at {SAMPLE_RATE} Hz...")
    print("[listen] Run 'emit' in another terminal or play from the teacher web page.")
    print("[listen] Press Ctrl+C to stop.\n")

    instance = ggwave.init()
    chunk_samples = 1024
    chunk_bytes = chunk_samples * 4  # float32

    try:
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype='float32',
                            blocksize=chunk_samples) as stream:
            count = 0
            while True:
                data, overflowed = stream.read(chunk_samples)
                if overflowed:
                    print("[listen] WARNING: audio buffer overflowed")

                # Convert to bytes for ggwave
                audio_bytes = data.astype(np.float32).tobytes()
                result = ggwave.decode(instance, audio_bytes)

                count += 1
                if count % 100 == 0:
                    peak = np.max(np.abs(data))
                    print(f"[listen] chunk #{count} | peak: {peak:.4f}")

                if result is not None:
                    text = result.decode('utf-8') if isinstance(result, bytes) else result
                    print(f"\n*** DECODED: '{text}' ***\n")

    except KeyboardInterrupt:
        print("\n[listen] Stopped.")
    finally:
        ggwave.free(instance)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 test_ggwave.py [selftest|emit|listen]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "selftest":
        selftest()
    elif cmd == "emit":
        emit()
    elif cmd == "listen":
        listen()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
