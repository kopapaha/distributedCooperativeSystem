#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
typedef nx_struct BlinkToRadioMsg{
  nx_uint16_t id;
  //nx_uint16_t data;
  nx_uint16_t nodeSnd;
  nx_uint16_t group;
}BTR_msg;


enum { IDBUF_SIZE=100, SEND_PERIOD=30000, AM_BLINKTORADIO = 6};
#endif