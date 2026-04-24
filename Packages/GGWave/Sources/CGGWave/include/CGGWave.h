// CGGWave.h — C-only public header for Swift interop
// Exposes the ggwave C API without the C++ class.

#ifndef CGGWAVE_H
#define CGGWAVE_H

#ifdef __cplusplus
extern "C" {
#endif

// Sample formats
typedef enum {
    GGWAVE_SAMPLE_FORMAT_UNDEFINED,
    GGWAVE_SAMPLE_FORMAT_U8,
    GGWAVE_SAMPLE_FORMAT_I8,
    GGWAVE_SAMPLE_FORMAT_U16,
    GGWAVE_SAMPLE_FORMAT_I16,
    GGWAVE_SAMPLE_FORMAT_F32,
} ggwave_SampleFormat;

// Protocol ids
typedef enum {
    GGWAVE_PROTOCOL_AUDIBLE_NORMAL,
    GGWAVE_PROTOCOL_AUDIBLE_FAST,
    GGWAVE_PROTOCOL_AUDIBLE_FASTEST,
    GGWAVE_PROTOCOL_ULTRASOUND_NORMAL,
    GGWAVE_PROTOCOL_ULTRASOUND_FAST,
    GGWAVE_PROTOCOL_ULTRASOUND_FASTEST,
    GGWAVE_PROTOCOL_DT_NORMAL,
    GGWAVE_PROTOCOL_DT_FAST,
    GGWAVE_PROTOCOL_DT_FASTEST,
    GGWAVE_PROTOCOL_MT_NORMAL,
    GGWAVE_PROTOCOL_MT_FAST,
    GGWAVE_PROTOCOL_MT_FASTEST,
    GGWAVE_PROTOCOL_CUSTOM_0,
    GGWAVE_PROTOCOL_CUSTOM_1,
    GGWAVE_PROTOCOL_CUSTOM_2,
    GGWAVE_PROTOCOL_CUSTOM_3,
    GGWAVE_PROTOCOL_CUSTOM_4,
    GGWAVE_PROTOCOL_CUSTOM_5,
    GGWAVE_PROTOCOL_CUSTOM_6,
    GGWAVE_PROTOCOL_CUSTOM_7,
    GGWAVE_PROTOCOL_CUSTOM_8,
    GGWAVE_PROTOCOL_CUSTOM_9,
    GGWAVE_PROTOCOL_COUNT,
} ggwave_ProtocolId;

// Operating modes
enum {
    GGWAVE_OPERATING_MODE_RX        = 1 << 1,
    GGWAVE_OPERATING_MODE_TX        = 1 << 2,
    GGWAVE_OPERATING_MODE_RX_AND_TX = (1 << 1) | (1 << 2),
};

// Instance parameters
typedef struct {
    int                 payloadLength;
    float               sampleRateInp;
    float               sampleRateOut;
    float               sampleRate;
    int                 samplesPerFrame;
    float               soundMarkerThreshold;
    ggwave_SampleFormat sampleFormatInp;
    ggwave_SampleFormat sampleFormatOut;
    int                 operatingMode;
} ggwave_Parameters;

typedef int ggwave_Instance;

ggwave_Parameters ggwave_getDefaultParameters(void);
ggwave_Instance   ggwave_init(ggwave_Parameters parameters);
void              ggwave_free(ggwave_Instance instance);

int ggwave_encode(
    ggwave_Instance instance,
    const void * payloadBuffer,
    int payloadSize,
    ggwave_ProtocolId protocolId,
    int volume,
    void * waveformBuffer,
    int query);

int ggwave_decode(
    ggwave_Instance instance,
    const void * waveformBuffer,
    int waveformSize,
    void * payloadBuffer);

int ggwave_ndecode(
    ggwave_Instance instance,
    const void * waveformBuffer,
    int waveformSize,
    void * payloadBuffer,
    int payloadSize);

void ggwave_rxToggleProtocol(ggwave_ProtocolId protocolId, int state);
void ggwave_txToggleProtocol(ggwave_ProtocolId protocolId, int state);

#ifdef __cplusplus
}
#endif

#endif // CGGWAVE_H
