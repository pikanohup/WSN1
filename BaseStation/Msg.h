#ifndef MSG_H
#define MSG_H

enum {
    DEFAULT_INTERVAL = 100,
	AM_SAMPLE_MSG = 0x93,
    AM_COMMAND_MSG = 0x94,
    BASE_STATION_ID = 1,
    BRIDGE_SENSOR_ID = 2,
    SENSOR_ID = 3
};

typedef nx_struct SampleMsg {
    nx_uint8_t nodeId;
	nx_uint16_t frequency;
    nx_uint16_t version;
    nx_uint16_t time;
    nx_uint16_t temperature;
    nx_uint16_t humidity;
    nx_uint16_t light;
} SampleMsg;

typedef nx_struct CommandMsg {
    nx_uint8_t rootId;
    nx_uint16_t frequency;
    nx_uint16_t version;
} CommandMsg;

#endif
