// Placeholder file — replace with real ggwave sources:
//   cp /tmp/ggwave/src/ggwave.cpp Packages/GGWave/Sources/CGGWave/
//   cp /tmp/ggwave/src/ggwave-common.cpp Packages/GGWave/Sources/CGGWave/
// Then delete this file.

#include "include/ggwave.h"

// Stub implementations so the package compiles before real sources are added
ggwave_Parameters ggwave_getDefaultParameters(void) {
    ggwave_Parameters p = {0};
    p.sampleRateInp = 48000;
    p.sampleRateOut = 48000;
    p.samplesPerFrame = 1024;
    return p;
}

ggwave_Instance ggwave_init(ggwave_Parameters params) {
    (void)params;
    return 1;
}

void ggwave_free(ggwave_Instance instance) {
    (void)instance;
}

int ggwave_encode(ggwave_Instance instance, const char *data, int dataSize, int txProtocolId, int volume, char *output, int playbackId) {
    (void)instance; (void)data; (void)dataSize; (void)txProtocolId; (void)volume; (void)output; (void)playbackId;
    return 0;
}

int ggwave_decode(ggwave_Instance instance, const char *data, int dataSize, char *output) {
    (void)instance; (void)data; (void)dataSize; (void)output;
    return 0;
}

int ggwave_ndecode(ggwave_Instance instance, const char *data, int dataSize, char *output, int outputSize) {
    (void)instance; (void)data; (void)dataSize; (void)output; (void)outputSize;
    return 0;
}
