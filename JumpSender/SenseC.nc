/*
 * Author: Yingda
 * Create time: 2015/12/14 20:27
 */

#include "Timer.h"
#include "Sense.h"

#define SAMPLING_FREQUENCY 100
#define NODE_ZERO 633
#define NODE_ONE 622
#define NODE_TWO 589

module SenseC {
  uses {
  	interface SplitControl as Control;
  	interface AMSend;
  	interface Packet;
  	interface AMPacket;
    interface Boot;
    interface Leds;
    interface Timer<TMilli> as Timer;
    interface Read<uint16_t> as Read1;
    interface Read<uint16_t> as Read2;
    interface Read<uint16_t> as Read3;

    interface Receive;
  }
}
implementation {

	message_t packet;
	sense_msg_t* recv_pkt;

	bool locked = FALSE;
	bool busy = FALSE;

	uint16_t cur_temp = 0;
	uint16_t cur_humid = 0;
	uint16_t cur_light = 0;
	
	uint16_t counter = 0;
	uint16_t version = 0, interval = 100;
  
  event void Boot.booted() {
  	call Control.start();
  }

  task void sendData() {
		if (!busy) {
			sense_msg_t* this_pkt = (sense_msg_t*)(call Packet.getPayload(&packet, NULL));
			this_pkt->nodeID = 1;
			this_pkt->temp = cur_temp;
			this_pkt->humid = cur_humid;
			this_pkt->light = cur_light;
			this_pkt->seq = ++counter;
			this_pkt->time = call Timer.getNow();
			this_pkt->token = 0xa849b25c;
			this_pkt->version = version;
			this_pkt->interval = interval;
			if(call AMSend.send(NODE_ZERO, &packet, sizeof(sense_msg_t)) == SUCCESS) {
				busy = TRUE;
				call Leds.led0Toggle();
			}
		} else {
			post sendData();		
		}
  }

  event void Timer.fired() {
    call Read1.read();
    call Read2.read();
    call Read3.read();
    post sendData();
  }

  event void Read1.readDone(error_t result, uint16_t data) {
  	if (result == SUCCESS) {
			cur_temp = data;
  	} else {
  	}
  }

  event void Read2.readDone(error_t result, uint16_t data) {
		if (result == SUCCESS) {
			cur_humid = data;
  	} else {
  	}
  }

  event void Read3.readDone(error_t result, uint16_t data) {
  	if (result == SUCCESS) {
			cur_light = data;
  	} else {
  	}
  }

  event void Control.startDone(error_t err) {
		if (err == SUCCESS) {
			call Timer.startPeriodic(interval);
		} else {
			call Control.start();
		}
  }

  event void Control.stopDone(error_t err) {}

	event void AMSend.sendDone(message_t* msg, error_t error) {
		//if(&packet == msg) {
			busy = FALSE;
		//}
	}

	task void sendJumpData() {
		if (!busy) {
			sense_msg_t* this_pkt = (sense_msg_t*)call Packet.getPayload(&packet, sizeof(sense_msg_t));
			this_pkt->nodeID = 2;
			this_pkt->temp = recv_pkt->temp;
			this_pkt->humid = recv_pkt->humid;
			this_pkt->light = recv_pkt->light;
			this_pkt->seq = recv_pkt->seq;
			this_pkt->time = recv_pkt->time;
			this_pkt->token = recv_pkt->token;
			this_pkt->version = recv_pkt->version;
			this_pkt->interval = recv_pkt->interval;

			/*if (this_pkt->interval != 0x64) {
				call Control.stop();
				call Leds.led1Toggle();
			}*/
			
			if(call AMSend.send(NODE_ZERO, &packet, sizeof(sense_msg_t)) == SUCCESS) {
				busy = TRUE;
				call Leds.led2Toggle();
			}
		} else {
			post sendJumpData();
		}
	}

	task void changeFreq() {
		if (busy) {
			call Timer.stop();
			call Timer.startPeriodic(interval);
		} else {
			post changeFreq();
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		if(len == sizeof(sense_msg_t)) {
			sense_msg_t* tmp_pkt = (sense_msg_t*)payload;
			if (tmp_pkt->token != 0xa849b25c) {
				return msg;
			} else if (call AMPacket.source(msg) == NODE_TWO && call AMPacket.destination(msg) == NODE_ONE && tmp_pkt->nodeID == -1) {
				recv_pkt = (sense_msg_t*)payload;
				post sendJumpData();
			} else if(tmp_pkt->nodeID == 3) {
				recv_pkt = (sense_msg_t*)payload;
				version = recv_pkt->version;
				interval = recv_pkt->interval;
				post changeFreq();
			}
		}
		return msg;
	}
}

