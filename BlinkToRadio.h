#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
//#define SERIAL
#define HISTSIZE 3
#define MAX_HOPS 11
#define MAX_QUERIES 5

#define TEST_TIMER

#ifdef SERIAL
#define MAXDELAY 150
#else
#define MAXDELAY 800
#endif

//delay 800: max time: 2*800*MAX_HOPS = 17.600 ms
#define PERIOD_SIM 20000
#define LIFETIME_SIM 60000

#define TEST_TIMER_PERIOD_SIM 70000


typedef nx_struct queryMessage{
  nx_uint16_t group;
  nx_uint16_t id;
  nx_uint16_t from;
  nx_uint16_t period;
  nx_uint32_t lifetime;
  nx_uint8_t hops;
}query_msg;

typedef nx_struct resultMessage{
  nx_uint16_t id;
  nx_uint16_t group;
  nx_uint16_t data[HISTSIZE];
  nx_uint16_t to;
}result_msg;

struct queryBuffer {
	uint16_t q_id;
	uint16_t from;
	uint32_t lifetimeCtr;
	int16_t readCtr;		//max period = 32000
	uint16_t waitingTime;
	uint16_t period;
	uint16_t data[HISTSIZE];
	uint8_t hoplevel;
	uint16_t aggrCtr;
	bool sendR;
};

enum { IDBUF_SIZE=10, BASIC_TIMER=1000, AM_BLINKTORADIO = 6};
#endif