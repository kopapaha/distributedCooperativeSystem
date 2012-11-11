#include <stdlib.h>
#include "Timer.h"
#include "BlinkToRadio.h"


module BlinkToRadioC @safe()
{
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  uses interface Leds;
  uses interface Boot;
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
}

implementation
{
	uint16_t ctr=0;
	bool busy=0, firstSend = 0, sendOK = 0;
	message_t p;
	uint16_t nxtBufPos = 0; //idx to next available store idBuf position
	uint16_t idBuf[IDBUF_SIZE]; 


  void sendMSG( BTR_msg *m ) {

	  if (!busy){
		  if (firstSend){
			  m->id = TOS_NODE_ID*100 + ctr%100;
		  	  if (nxtBufPos == IDBUF_SIZE)
			     nxtBufPos=0;
		  	  idBuf[nxtBufPos++] = m->id;
			  ctr++;
			  firstSend = 0;
			  dbg("latency", "msg_snd from= %d msgId= %d @ %s\n", TOS_NODE_ID, m->id, sim_time_string());
		  }
		  m->nodeSnd = TOS_NODE_ID;
		  m->group=1;

		  sendOK=1; //send when Timer1.fired
		  dbg("cost", "msg_snd from= %d msgId= %d @ %s\n", m->nodeSnd, m->id, sim_time_string());
	  }
  }

  event void Boot.booted()
  {
	  dbg("DBG", "AMControlStart @ %s.\n", sim_time_string());
	  call AMControl.start();
  }

  void init() {
	  int i;
	  for(i=0; i<IDBUF_SIZE; i++)
		  idBuf[i]=10000; //max for 100 nodes 9999
  }

  event void AMControl.startDone(error_t err) {
	  int r;
	  srandom (TOS_NODE_ID);
	  if (err == SUCCESS){
		  init();
		  r = (int)rand()%200;
		  dbg("DBG", "rand %d.\n", r);
		  call Timer1.startPeriodic( r+200);
		  call Timer0.startPeriodic( SEND_PERIOD );
	  }
	  else {
		  call AMControl.start();
	  }
  }

  event void Timer0.fired()
  {
	  BTR_msg *m;
	  uint32_t t; //max time 4.294967296e9
	  t = call Timer0.getNow();
	  dbg("DBG", "timer0Fired\n");
	  dbg("DBG", "t= %d d= %d\n",t, t/SEND_PERIOD);
	  m = (BTR_msg *) call Packet.getPayload(&p, sizeof(BTR_msg));
	  
	  if(((t/SEND_PERIOD-1)*11)%100 == TOS_NODE_ID){
		  firstSend = 1;
		  sendMSG(m);
	  }
  }
  
  event void Timer1.fired()
  {
	  BTR_msg *m;
	  if (sendOK){
		  if (call AMSend.send(AM_BROADCAST_ADDR, &p, sizeof(BTR_msg)) == SUCCESS){
			  m = (BTR_msg *) call Packet.getPayload(&p, sizeof(BTR_msg));
			  dbg("DBG", "MSG send... msgId=%d group=%d @ %s.\n", m->id, m->group, sim_time_string());
			  
			  busy=1;
		  }
		  sendOK=0;
	  }
  }

  event void AMControl.stopDone(error_t err) {}

  event void AMSend.sendDone(message_t *msg, error_t err) {
	  if (msg == &p) {
		  busy = 0;
	  }
  }

  event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len)
  {
	int i;
	BTR_msg *payl;
	BTR_msg *m;

	if (len == sizeof(BTR_msg)){
		payl = (BTR_msg *)payload;
		dbg("duplicates", "msg_rcv Iam= %d msgId= %d @ %s\n", TOS_NODE_ID, payl->id, sim_time_string());
		if (payl->group!=1)
			return msg;
		for (i=0; i < IDBUF_SIZE; i++) {
			if (idBuf[i] == payl->id)
				return msg;
		}
		if (nxtBufPos == IDBUF_SIZE)
			nxtBufPos=0;
		idBuf[nxtBufPos++] = payl->id;

		m = call Packet.getPayload(&p, sizeof(BTR_msg));//(BTR_msg *)payload;
		m->id = payl->id;
		m->group = payl->group;
		m->nodeSnd = payl->nodeSnd;

		dbg("coverage", "msg_rcv from= %d msgId= %d @ %s\n", m->nodeSnd, m->id, sim_time_string());
		dbg("latency", "msg_rcv from= %d msgId= %d @ %s\n", m->nodeSnd, m->id, sim_time_string());
		sendMSG(m);
	}
	return msg;
  }
  
}

