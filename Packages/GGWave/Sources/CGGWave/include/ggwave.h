// Placeholder — replace with the real ggwave.h from:
//   git clone https://github.com/ggerganov/ggwave /tmp/ggwave
//   cp /tmp/ggwave/include/ggwave/ggwave.h Packages/GGWave/Sources/CGGWave/include/
//   cp /tmp/ggwave/src/ggwave.cpp Packages/GGWave/Sources/CGGWave/
//   cp /tmp/ggwave/src/ggwave-common.cpp Packages/GGWave/Sources/CGGWave/

#ifndef GGWAVE_H
#define GGWAVE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef int ggwave_Instance;

typedef struct {
    int sampleRateInp;
    int sampleRateOut;
    int samplesPerFrame;
    int sampleFormatInp;
    int sampleFormatOut;
    int operatingMode;
} ggwave_Parameters;

ggwave_Parameters ggwave_getDefaultParameters(void);
ggwave_Instance ggwave_init(ggwave_Parameters params);
void ggwave_free(ggwave_Instance instance);
int ggwave_encode(ggwave_Instance instance, const char *data, int dataSize, int txProtocolId, int volume, char *output, int playbackId);
int ggwave_decode(ggwave_Instance instance, const char *data, int dataSize, char *output);
int ggwave_ndecode(ggwave_Instance instance, const char *data, int dataSize, char *output, int outputSize);

#ifdef __cplusplus
}
#endif

#endif // GGWAVE_H
