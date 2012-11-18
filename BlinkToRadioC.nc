#include <stdlib.h>
#include "Timer.h"
#include "BlinkToRadio.h"
#include "TestSerial.h"


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
  
  uses interface Read<uint16_t> as light;

  uses interface SplitControl as serialControl;
  uses interface Packet as serialPacket;
  uses interface AMSend as serialAMSend;
  uses interface Receive as serialReceive;
}




implementation {

	message_t q_pkt;
	message_t r_pkt;
	message_t serialp;

	uint16_t qBuf[2][IDBUF_SIZE];
	uint8_t nxtBufPos = 0, ctrId = 0;
	uint16_t lifetimeCtr = 0;
	
	bool sendQ = 0, busy = 0, sendR = 0;


	event void Boot.booted() {
		call AMControl.start();
		call serialControl.start();
	}

	void init() {
		int i;
		for(i=0; i<IDBUF_SIZE; i++)
			qBuf[0][i] = 10000; //max for 100 nodes 9999
	}

	
	event void AMControl.startDone(error_t err) {
		int r;
		query_msg *m;
		srand (TOS_NODE_ID);
		if (err == SUCCESS){
			init();
			r = (int)rand()%200;
			call Timer0.startPeriodic( r+200);		//Used to forward queries
			
#ifndef SERIAL			
			if(TOS_NODE_ID == 0) {
				m = (query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
				m->id = 1;
				m->group = 1;
				m->from = 0;
				m->period = 1000;
				m->lifetime = 4000;
				
				qBuf[0][0] = 1;
				qBuf[1][0] = 999;
				if(!busy) {
					call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg));
				}
				dbg("DBG", "First query created.\n");
			}
#endif
		}
		else {
			call AMControl.start();
		}
	}
	
	
	event void serialControl.startDone(error_t err) {

		if (err == SUCCESS){}
		else 
			call serialControl.start();
	}
	
	event void serialControl.stopDone(error_t err) {}
	
	event void serialAMSend.sendDone(message_t *msg, error_t err) {}

	event void AMControl.stopDone(error_t err) {}
	
	//Measurement's period
	event void Timer1.fired() {
	
		if(lifetimeCtr > 0) {
			call light.read();
			lifetimeCtr--;
		}
	}


	//Forward query to next nodes
	event void Timer0.fired() {
		
		if ( !busy && sendQ ) {
			if (call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg)) == SUCCESS)
				busy=1;
		} else if ( !busy && sendR ) {
			dbg("DBG", "fwd result msg\n");
			if (call AMSend.send(AM_BROADCAST_ADDR, &r_pkt, sizeof(result_msg)) == SUCCESS)
				busy=1;
		}
	}
	
	

	event void AMSend.sendDone(message_t *msg, error_t err) {
		if (msg == &q_pkt)
			sendQ = 0;
		else if (msg == &r_pkt) 
			sendR = 0;
		//Else, an den isxyei na anapsoume to fws
		busy = 0;
	}
	
	
	//Get value from light sensor and forward result immediately
	event void light.readDone(error_t result, uint16_t data) {
		
		result_msg *payl_r;

		dbg("DBG", "Read value: %d  @ %s\n", data, sim_time_string());

		
		if (result == SUCCESS) {
			
			payl_r = (result_msg *) call Packet.getPayload(&r_pkt, sizeof(result_msg));
			payl_r->group = 1;
			payl_r->id = qBuf[0][0];
			payl_r->data = data;
			payl_r->to = qBuf[1][0];
			
			if(qBuf[1][0] == 999) {
				
				dbg("DBG", "Source to serial\n");
				return;
			}
			
			if(!busy) {
				dbg("DBG", "fwd my result.\n");
				call AMSend.send(AM_BROADCAST_ADDR, &r_pkt, sizeof(result_msg));
				busy = 1;
			}
		}
	}


	
	
	event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len)
	{
		int i;
		query_msg *payl_q, *m;
		result_msg *payl_r, *r;
		test_serial_msg_t* s;
	
		//Check message type (query or response)
		if (len == sizeof(query_msg)){
			
			payl_q = (query_msg *)payload;
			if (payl_q->group!=1)
				return msg;
			for (i=0; i < IDBUF_SIZE; i++) {
				if (qBuf[0][i] == payl_q->id)
					return msg;
			}
			if (nxtBufPos == IDBUF_SIZE)
				nxtBufPos=0;
			qBuf[0][nxtBufPos] = payl_q->id;
			qBuf[1][nxtBufPos] = payl_q->from;
			nxtBufPos++;

			//Start measurement period
			lifetimeCtr = (uint16_t)( payl_q->lifetime / payl_q->period);
			dbg("DBG", "new query received with counter: %d @ %s \n", lifetimeCtr,  sim_time_string());
			call Timer1.startPeriodic(payl_q->period);
			
			//Prepare query message forward
			m = (query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
			m->id = payl_q->id;
			m->group = payl_q->group;
			m->from = (nx_uint16_t)TOS_NODE_ID;
			m->period = payl_q->period;
			m->lifetime = payl_q->lifetime;
			
			sendQ = 1;
			
		}
		else if( len == sizeof(result_msg)) {
			
			payl_r = (result_msg *)payload;
			
			if(payl_r->group!=1)
				return msg;
			if(payl_r->to != TOS_NODE_ID)
				return msg;
			if(qBuf[1][0] == 999) {
				
				dbg("DBG", "Source received result! - fwd to serial\n");
#ifdef SERIAL				
				s = (test_serial_msg_t*)call Packet.getPayload(&serialp, sizeof(test_serial_msg_t));

				//oikonomia energeias, symvash epistrofhs apotelesmatos sthn period
				s->period = payl_r->data;
				call serialAMSend.send(AM_BROADCAST_ADDR, &serialp, sizeof(test_serial_msg_t));
#endif
				return msg;
			}
			
			dbg("DBG", "Received result with value: %d   @ %s\n", payl_r->data, sim_time_string());
			r = (result_msg *) call Packet.getPayload(&r_pkt, sizeof(result_msg));
			
			r->group = payl_r->group;
			r->id = payl_r->id;
			r->data = payl_r->data;
			r->to = qBuf[1][0];
			
			sendR = 1;			
		}
	return msg;
	}


	event message_t *serialReceive.receive(message_t *msg, void *payload, uint8_t len)
	{
		test_serial_msg_t *payl;
		query_msg *m;
		
		if (len == sizeof(test_serial_msg_t)){

			payl = (test_serial_msg_t *)payload;

			m =(query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
			m->id = TOS_NODE_ID*10 + ctrId%10;
			m->group = 1;
			m->from = (nx_uint16_t)TOS_NODE_ID;
			m->period = payl->period;
			m->lifetime = payl->lifetime;
			ctrId++;
			
			//multiple queries POSITION!!!
			qBuf[0][0] = m->id;
			qBuf[1][0] = 999;
			
			if(!busy) {
				call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg));
			}
			dbg("DBG", "This message will never appear\n");

		}
		return msg;
	}


























}