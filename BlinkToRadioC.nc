#include <stdlib.h>
#include "Timer.h"
#include "BlinkToRadio.h"
#include "TestSerial.h"


module BlinkToRadioC @safe()
{
	uses interface Timer<TMilli> as Timer0;
	uses interface Timer<TMilli> as Timer1;
	uses interface Timer<TMilli> as testTimer;
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

	struct queryBuffer qBuf[MAX_QUERIES];
	
	uint8_t ctrId = 0, randTime;
	uint16_t sender = 0;
	
	bool sendQ = 0, busy = 0;


	event void Boot.booted() {
		call AMControl.start();
		call serialControl.start();
	}

	void init() {
		uint8_t i, j;
		
		for(i=0; i<MAX_QUERIES; i++) {
			qBuf[i].q_id = 10000; //max for 100 nodes 9999
			qBuf[i].lifetimeCtr = 0;
			qBuf[i].readCtr = -1;
			qBuf[i].sendR = 0;
			qBuf[i].aggrCtr = 0;
			qBuf[i].waitingTime = 0;
		}
		
		//Initialize data
		for(i=0; i<MAX_QUERIES; i++)
			for(j=0; j<HISTSIZE; j++)
				qBuf[i].data[j] = 0;
	}

	
	event void AMControl.startDone(error_t err) {
		
		srand (TOS_NODE_ID);
		if (err == SUCCESS){
			init();
			randTime = (uint8_t)rand()%80;
			randTime += 50;
			dbg("DBG", "randtime = %d.\n", randTime);
			call Timer0.startPeriodic(randTime);//Used to forward queries
			
			call Timer1.startPeriodic(BASIC_TIMER);
			
			call testTimer.startPeriodic(1000);
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
	

	event void testTimer.fired() {
		
		int i;
		query_msg *m;
		
#ifndef SERIAL			
			if(TOS_NODE_ID == sender%99 && (TOS_NODE_ID == 0 || TOS_NODE_ID == 1)) {
				m = (query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
				m->id =TOS_NODE_ID*IDBUF_SIZE + ctrId%IDBUF_SIZE;
				m->group = 1;
				m->from = TOS_NODE_ID;
				m->period = 3000 + TOS_NODE_ID*1000;
				m->lifetime = 12000;
				m->hops = 0;
				
				for(i=0; i<MAX_QUERIES && qBuf[i].lifetimeCtr != 0; i++);
				
				
				qBuf[i].q_id = m->id;
				qBuf[i].from = 999;
				qBuf[i].readCtr = m->period / BASIC_TIMER;
				qBuf[i].period = m->period;
				qBuf[i].hoplevel = 0;
		
				if(!busy) {
					
					call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg));
				}
				
				dbg("DBG", "new query created. i= %d id: %d readCtr=%d @ %s\n", i, qBuf[i].q_id, qBuf[i].readCtr, sim_time_string());

				//Calculate waitingTime
				qBuf[i].waitingTime = (MAX_HOPS - 0)*(100+100);

				//Start measurement period
				qBuf[i].lifetimeCtr = (uint16_t)( m->lifetime / BASIC_TIMER);
				
				ctrId++;
				call testTimer.stop();
			}
			sender++;
#endif
	}

	//Measurement's period
	event void Timer1.fired() {
		
		uint8_t i;
		bool flag = 0;
		
		//dbg("DBG", "BASIC_TIMER fired. @ %s\n", sim_time_string());
		
		for(i=0; i<MAX_QUERIES && qBuf[i].readCtr != -1; i++) {
			qBuf[i].readCtr--;
			if( qBuf[i].lifetimeCtr > 0 ) {
				qBuf[i].lifetimeCtr--;
				if(qBuf[i].readCtr == 0)
					flag = 1;
			}
		}
		
		if(flag)
			call light.read();
	}



	//Forward query to next nodes && Return aggregated packet
	event void Timer0.fired() {
		
		test_serial_msg_t* s;
		uint8_t i,j;
		result_msg *r;
		
		//dbg("DBG", "Timer0 fired. @ %s\n", sim_time_string());
		
		if ( !busy && sendQ ) {
			if (call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg)) == SUCCESS)
				busy=1;
		} else {
			
			for(j=0; j<MAX_QUERIES;j++) {
				
				if ((qBuf[j].aggrCtr > (qBuf[j].waitingTime / randTime)) && qBuf[j].sendR && !busy) {
			
					//Blue led toggles when a new aggregated message is sent
					call Leds.led2Toggle();
			
					if(qBuf[j].from == 999) {
				
						//for(i=0; i<HISTSIZE; i++)
							//dataBuf[i] = 0;
						dbg("DBG", "Source received result for query: %d! Value: %d %d %d @ %s\n",j, qBuf[j].data[0], qBuf[j].data[1], qBuf[j].data[2], sim_time_string());
#ifdef SERIAL
						s = (test_serial_msg_t*)call Packet.getPayload(&serialp, sizeof(test_serial_msg_t));

						s->data[0] = qBuf[j].data[0];
						s->data[1] = qBuf[j].data[1];
						s->data[2] = qBuf[j].data[2];
						
						call serialAMSend.send(AM_BROADCAST_ADDR, &serialp, sizeof(test_serial_msg_t));
#endif
						for(i=1; i<HISTSIZE; i++)	//Reset buffer after send to serial
							qBuf[j].data[i] = 0;
				
						qBuf[j].sendR = 0;
						return;
					}
			
					r = (result_msg *) call Packet.getPayload(&r_pkt, sizeof(result_msg));
					
					r->id = qBuf[j].q_id;
					r->group = 1;
					r->data[0] = qBuf[j].data[0];
					r->data[1] = qBuf[j].data[1];
					r->data[2] = qBuf[j].data[2];
					r->to = qBuf[j].from;
					
					
					call AMSend.send(AM_BROADCAST_ADDR, &r_pkt, sizeof(result_msg));
					
					dbg("DBG", "Aggregated packet send. Query: %d Value: %d %d %d  @ %s\n",j, qBuf[j].data[0], qBuf[j].data[1], qBuf[j].data[2], sim_time_string());
					
					for(i=1; i<HISTSIZE; i++)	//Reset buffer after send to serial
							qBuf[j].data[i] = 0;
					
					busy = 1;
					qBuf[j].sendR = 0;
					
					return;
					
				}
				
				qBuf[j].aggrCtr++;
			}
		}
	}
	
	

	event void AMSend.sendDone(message_t *msg, error_t err) {
		if (msg == &q_pkt)
			sendQ = 0;
		//dbg("DBG", "send done @ %s\n", sim_time_string());

		busy = 0;
	}
	
	
	//Get value from light sensor and forward result immediately
	event void light.readDone(error_t result, uint16_t data) {
		
		uint8_t i;
		dbg("DBG", "Read value: %d  @ %s\n", data, sim_time_string());
		if (result == SUCCESS) {
			
			for(i=0; i<MAX_QUERIES; i++) {
				
				if(qBuf[i].readCtr == 0) {
					if(data<35)
						qBuf[i].data[0]++;
					else if(data>=35 && data<=70)
						qBuf[i].data[1]++;
					else
						qBuf[i].data[2]++;

					qBuf[i].readCtr = qBuf[i].period / BASIC_TIMER;
					qBuf[i].sendR = 1;
					qBuf[i].aggrCtr = 0;		//Reset vounter for waiting time, molis diavasei ti diki tou timi.

				}
			}
		}
	}


	
	
	event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len)
	{
		uint8_t i,j;
		query_msg *payl_q, *m;
		result_msg *payl_r;
	

		//Check message type (query or response)
		if (len == sizeof(query_msg)){
			
			payl_q = (query_msg *)payload;
			if (payl_q->group!=1)
				return msg;
			for (i=0; i < MAX_QUERIES; i++) {
				if (qBuf[i].q_id == payl_q->id)
					return msg;
			}
			
					
			for(i=0; i<MAX_QUERIES && qBuf[i].lifetimeCtr != 0; i++);
			//dbg("DBG", "Receive done id=%d @ %s\n", i,sim_time_string());
			qBuf[i].q_id = payl_q->id;
			qBuf[i].from = payl_q->from;
			qBuf[i].readCtr = payl_q->period / BASIC_TIMER;
			qBuf[i].period = payl_q->period;
			qBuf[i].hoplevel = ++payl_q->hops;
			qBuf[i].readCtr = payl_q->period / BASIC_TIMER;
			
			//Calculate waiting timer
			qBuf[i].waitingTime = (MAX_HOPS - 0)*(100+100);
			
			//Start measurement period
			qBuf[i].lifetimeCtr = (uint16_t)( payl_q->lifetime / BASIC_TIMER);
			
			dbg("DBG", "new query from %d at level %d with readctr: %d lifetcounter: %d @ %s \n", payl_q->from, qBuf[i].hoplevel, qBuf[i].readCtr, qBuf[i].lifetimeCtr,  sim_time_string());

			
			//Prepare query message forward
			m = (query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
			m->id = payl_q->id;
			m->group = payl_q->group;
			m->from = (nx_uint16_t)TOS_NODE_ID;
			m->period = payl_q->period;
			m->lifetime = payl_q->lifetime;
			m->hops = qBuf[i].hoplevel;
			
			//Red led toggles when a new query arrives
			call Leds.led0Toggle();
			
			sendQ = 1;
			
		}
		else if( len == sizeof(result_msg)) {
			
			payl_r = (result_msg *)payload;
			
			if(payl_r->group!=1)
				return msg;
			if(payl_r->to != TOS_NODE_ID)
				return msg;

			//Green led toggles when a new result message arrives
			//call Leds.led1Toggle();
			
			dbg("DBG", "Received result. Value: %d %d %d  @ %s\n", payl_r->data[0], payl_r->data[1], payl_r->data[2], sim_time_string());
			
			//Prosoxi an den yparxei to id mesa
			for(i=0; i<MAX_QUERIES && qBuf[i].q_id != payl_r->id; i++);
			
			if(qBuf[i].q_id != payl_r->id)		//Mono an exei ftasei sto telos kai den yparxei to id sth mnhmh
				return msg;
			
			for(j=0; j< HISTSIZE; j++)
				qBuf[i].data[j] += payl_r->data[j];

			qBuf[i].sendR = 1;
		}
	return msg;
	}


	event message_t *serialReceive.receive(message_t *msg, void *payload, uint8_t len)
	{
		test_serial_msg_t *payl;
		query_msg *m;
		uint8_t i;
		
		if (len == sizeof(test_serial_msg_t)){

			payl = (test_serial_msg_t *)payload;

			m =(query_msg *) call Packet.getPayload(&q_pkt, sizeof(query_msg));
			m->id = TOS_NODE_ID*IDBUF_SIZE + ctrId%IDBUF_SIZE;
			m->group = 1;
			m->from = (nx_uint16_t)TOS_NODE_ID;
			m->period = payl->period;
			m->lifetime = payl->lifetime;
			m->hops = 0;

			ctrId++;
			
			for(i=0; i<MAX_QUERIES && qBuf[i].lifetimeCtr != 0; i++);

			//multiple queries POSITION!!!
			qBuf[i].q_id = m->id;
			qBuf[i].from = 999;		//I am the source node
			qBuf[i].readCtr = m->period / BASIC_TIMER;
			qBuf[i].period = m->period;
			qBuf[i].hoplevel = 0;
			qBuf[i].readCtr = m->period / BASIC_TIMER;
						
			//Start measurement period
			qBuf[i].lifetimeCtr = (uint16_t)( m->lifetime / BASIC_TIMER);

			
			//Calculate waiting timer
			qBuf[i].waitingTime = (MAX_HOPS - 0)*(100+100);
			
			//Red led toggles when a new query arrives
			call Leds.led0Toggle();
			
			if(!busy) {
				call AMSend.send(AM_BROADCAST_ADDR, &q_pkt, sizeof(query_msg));
			}
			dbg("DBG", "This message will never appear\n");



		}
		return msg;
	}



}
			//Reset vounter for waiting time, molis diavasei ti diki tou timi.