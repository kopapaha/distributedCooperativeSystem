#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
//#define SERIAL
typedef nx_struct queryMessage{
  nx_uint16_t group;
  nx_uint16_t id;
  nx_uint16_t from;
  nx_uint16_t period;
  nx_uint16_t lifetime;
}query_msg;

typedef nx_struct resultMessage{
  nx_uint16_t id;
  nx_uint16_t group;
  nx_uint16_t data;
  nx_uint16_t to;
}result_msg;

enum { IDBUF_SIZE=10, SEND_PERIOD=30000, AM_BLINKTORADIO = 6};
#endif