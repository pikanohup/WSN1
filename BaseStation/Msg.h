#ifndef MSG_H
#define MSG_H

enum {
    DEFAULT_INTERVAL = 100,
	AM_SAMPLE_MSG = 0x93,
    AM_CONTROL_MSG = 0x94,
    BASE_STATION_ID = 1,
    BRIDGE_SENSER_ID = 2,
    SENSER_ID = 3,
    SAMPLE_NUM = 3
};

typedef nx_struct SampleMsg {
	nx_uint16_t version;
    nx_uint16_t frequency;
    nx_uint8_t nodeId;
    nx_uint16_t time;
    nx_uint16_t temperature[SAMPLE_NUM];
    nx_uint16_t humidity[SAMPLE_NUM];
    nx_uint16_t light[SAMPLE_NUM];
} SampleMsg;

typedef nx_struct ControlMsg {
    nx_uint8_t rootId;
    nx_uint16_t confirmTime;
    nx_uint16_t samplingFrequency;
    nx_uint16_t frequencyVersion;
} ControlMsg;

#endif
