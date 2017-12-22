/*
 * Copyright (c) 2006, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Revision -------------------------------------------------------------
 * $Revision: 1.4 $
 * $Date: 2006/12/12 18:22:49 $
 * @author: Jan Hauer
 * ========================================================================
 */

/**
 *
 * Sensing demo application. See README.txt file in this directory for usage
 * instructions and have a look at tinyos-2.x/doc/html/tutorial/lesson5.html
 * for a general tutorial on sensing in TinyOS.
 *
 * @author Jan Hauer
 */

#include "Timer.h"
#include "printf.h"
#include "SensirionSht11.h"
#include "../BaseStation/Msg.h"

module SensorC
{
  uses {
    interface Boot;
    interface Leds;
    interface Timer<TMilli>;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface SplitControl as RadioControl;
    interface Read<uint16_t> as TemperatureRead;
    interface Read<uint16_t> as HumidityRead;
    interface Read<uint16_t> as LightRead;
    interface Receive as SampleMsgReceiver;
    interface Receive as CommandMsgReceiver;
  }
}
implementation
{
  enum {
    MSG_QUEUE_LEN = 12
  };

  SampleMsg cur_message;
  message_t msgQueue[MSG_QUEUE_LEN];

  uint8_t num_information = 0; // once reached 3, packet ready
  uint8_t cur_Version = 0;
  uint32_t queueHead = 0;
  uint32_t queueTail = 0;
  uint16_t cur_frequency = DEFAULT_INTERVAL;
  bool Busy = FALSE;

  void SendMsg(SampleMsg* msg);
  void Init();
  void checkPacket();

/*------------------init part-----------------------*/
  void Init() {
    cur_message.nodeId = TOS_NODE_ID;
    cur_message.time = 0;
  }

  void checkPacket() {
    if (num_information >= 3) {
      SendMsg(&cur_message);
      num_information = 0;
    }
  }

  event void Boot.booted() {
    Init();
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if(err == SUCCESS) {
      call Timer.startPeriodic(cur_frequency);
    }
    else {
      call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {

  }

/*------------------send part-----------------------*/
  event void Timer.fired()
  {
    call TemperatureRead.read();
    call HumidityRead.read();
    call LightRead.read();
  }

  event void TemperatureRead.readDone(error_t result, uint16_t data)
  {
    if (result == SUCCESS) {
  	  uint16_t temperature = (uint16_t)((data * 0.01 - 40.1) - 32) / 1.8;
      cur_message.temperature = temperature;
      num_information = num_information + 1;
      checkPacket();
  	  printf("Temperature: %d\n", temperature);
    }
	else {
      printf("Get temperature failed\n");
      call TemperatureRead.read();
    }
  }

  event void HumidityRead.readDone(error_t result, uint16_t data)
  {
    if (result == SUCCESS) {
  	  uint16_t humidity = (uint16_t)(-4 + 0.0405 * data + (-2.8 * 0.00001) * (data * data));
      cur_message.humidity = humidity;
      num_information = num_information + 1;
      checkPacket();
      printf("Humidity: %d\n", humidity);
    }
	else {
      printf("Get humidity failed\n");
      call HumidityRead.read();
    }
  }

  event void LightRead.readDone(error_t result, uint16_t data)
  {
    if(result == SUCCESS) {
      uint16_t light = 0.625 * 10 * data * 1.5 / 4.096;
      cur_message.light = light;
      num_information = num_information + 1;
      checkPacket();
	    printf("Light: %d\n", light);
    }
	else {
      printf("Get light failed\n");
      call LightRead.read();
    }
  }

/*------------------send part-----------------------*/
  task void SendTask() {
    message_t* packet = msgQueue + queueTail % MSG_QUEUE_LEN;

    if (call AMSend.send(AM_BROADCAST_ADDR, packet, sizeof(SampleMsg)) == SUCCESS) {
      Busy = TRUE;    // update busy state
    } else {
      queueHead = (queueHead + 1) % MSG_QUEUE_LEN;
      if (queueHead < queueTail) {
        post SendTask();
      }
    }
  }

  void SendMsg(SampleMsg* msg) {
    message_t* packet;
    void* payload;

    /*queue full*/
    if (queueHead + MSG_QUEUE_LEN <= queueTail) {
      return;
    }

    packet = msgQueue + queueTail % MSG_QUEUE_LEN;
    payload = call AMSend.getPayload(packet, sizeof(SampleMsg));

    memcpy(payload, msg, sizeof(SampleMsg));

    if (queueHead == queueTail) {
      post SendTask();
    }

    queueTail = (queueTail + 1) % MSG_QUEUE_LEN;
  }

  event void AMSend.sendDone(message_t* msg, error_t srr) {
    Busy = FALSE;
    queueHead = (queueHead + 1) % MSG_QUEUE_LEN;

    if (queueHead > queueTail) {
      post SendTask();
    }
  }

/*------------------receive part-----------------------*/
  event message_t* CommandMsgReceiver.receive(message_t* msg, void* payload, uint8_t len) {
    if( len == sizeof(CommandMsg)) {
      CommandMsg* cur_commandMsg = (CommandMsg*)payload;
      if(cur_commandMsg->version > cur_Version) {
        cur_Version = cur_commandMsg->version;
        cur_frequency = cur_commandMsg->frequency;
        call Timer.stop();
        call Timer.startPeriodic(cur_frequency);
      }
    }
    return msg;
  }

  event message_t* SampleMsgReceiver.receive(message_t* msg, void* payload, uint8_t len) {
    if(len == sizeof(SampleMsg)) {
      SampleMsg* cur_sampleMsg = (SampleMsg*)payload;
      if(cur_sampleMsg->nodeId == SENSOR_ID) {
        SendMsg(cur_sampleMsg);
      }
    }
    return msg;
  }

}
