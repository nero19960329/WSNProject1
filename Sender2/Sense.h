/*
 * Author: Wang Zhao
 * Create time: 2015/12/14 17:53
 */

#ifndef SENSE_H
#define SENSE_H

enum {
    AM_MSG = 6,
    TIMER_PERIOD_MILLI = 250
};

typedef nx_struct sense_msg_t {
  nx_uint16_t version; /* Version of the interval. */
  nx_uint16_t interval; /* Samping period. */
	nx_uint16_t nodeID;
	nx_uint16_t temp;
	nx_uint16_t humid;
	nx_uint16_t light;
	nx_uint16_t seq;
	nx_uint32_t time;
	nx_uint32_t token;
}sense_msg_t;

#endif
