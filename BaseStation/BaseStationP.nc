// $Id: BaseStationP.nc,v 1.10 2008/06/23 20:25:14 regehr Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * Revision:	$Id: BaseStationP.nc,v 1.10 2008/06/23 20:25:14 regehr Exp $
 */
  
/* 
 * BaseStationP bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the TOSBase, and messages moving from radio to
 * serial will be filtered by that same group id.
 */

#include "AM.h"
#include "Serial.h"
#include "Msg.h"

module BaseStationP @safe() {
  uses {
    interface Boot;
	
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;
	
    interface AMSend as RadioAMSend;
    interface Receive as RadioReceive;
	interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;
	
	interface AMSend as SerialAMSend;
    interface Receive as SerialReceive;
	interface Packet as SerialPacket;
    interface AMPacket as SerialAMPacket;

    interface Leds;
  }
}

implementation
{
  enum {
    RADIO_QUEUE_LEN = 12,
	SERIAL_QUEUE_LEN = 12,
  };

  message_t  * ONE_NOK serialQueue[SERIAL_QUEUE_LEN];
  uint8_t    serialIn, serialOut;
  bool       serialBusy, serialFull;

  message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
  uint8_t    radioIn, radioOut;
  bool       radioBusy, radioFull;

  task void serialSendTask();
  task void radioSendTask();

  message_t* forwardSampleMsg(message_t* msg, void* payload, uint8_t len);
  message_t* forwardControlMsg(message_t* msg, void* payload, uint8_t len);

  void dropBlink() {
    call Leds.led2Toggle();
  }

  void failBlink() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    serialIn = serialOut = 0;
    serialBusy = FALSE;
    serialFull = TRUE;

    radioIn = radioOut = 0;
    radioBusy = FALSE;
    radioFull = TRUE;
	
    call RadioControl.start();
    call SerialControl.start();
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      radioFull = FALSE;
    }
	else {
	  call RadioControl.start();
	}
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      serialFull = FALSE;
    }
	else {
	  call SerialControl.start();
	}
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  event message_t *RadioReceive.receive(message_t *msg,
						    void *payload,
						    uint8_t len) {
    if (len == sizeof(SampleMsg)) {
       return forwardSampleMsg(msg, payload, len);
    }
    return msg;
  }

  event message_t *SerialReceive.receive(message_t *msg,
						    void *payload,
						    uint8_t len) {
    if (len == sizeof(ControlMsg)) {
       return forwardControlMsg(msg, payload, len);
    }
    return msg;
  }
  
  task void serialSendTask() {
	am_addr_t source;
    message_t* msg;
	
    atomic
      if (serialIn == serialOut && !serialFull) {
	  serialBusy = FALSE;
	  return;
	}
	
	msg = serialQueue[serialOut];
	source = call RadioAMPacket.source(msg);
	call SerialPacket.clear(msg);
    call SerialAMPacket.setSource(msg, source);

    if (call SerialAMSend.send(AM_BROADCAST_ADDR, serialQueue[serialOut], sizeof(SampleMsg)) == SUCCESS) {
      call Leds.led0Toggle();
	} 
    else {
	  failBlink();
	  post serialSendTask();
    }
  }
  
  task void radioSendTask() {
	am_addr_t source;
    message_t* msg;
	
    atomic
      if (radioIn == radioOut && !radioFull) {
	  radioBusy = FALSE;
	  return;
	}

	msg = radioQueue[radioOut];
	source = call SerialAMPacket.source(msg);
	call RadioPacket.clear(msg);
    call RadioAMPacket.setSource(msg, source);
	
    if (call RadioAMSend.send(AM_BROADCAST_ADDR, radioQueue[radioOut], sizeof(SampleMsg)) == SUCCESS) {
      call Leds.led0Toggle();
	} 
    else {
	  failBlink();
	  post radioSendTask();
    }
  }
  
  message_t* forwardSampleMsg(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;
	
    atomic {
      if (!serialFull)
	{
	  ret = serialQueue[serialIn];
	  serialQueue[serialIn] = msg;

	  serialIn = (serialIn + 1) % SERIAL_QUEUE_LEN;
	
	  if (serialIn == serialOut)
	    serialFull = TRUE;

	  if (!serialBusy)
	    {
	      post serialSendTask();
	      serialBusy = TRUE;
	    }
	}
      else
	dropBlink();
    }
    
    return ret;
  }
  
  message_t* forwardControlMsg(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;

    atomic {
      if (!radioFull)
	{
	  ret = radioQueue[radioIn];
	  radioQueue[radioIn] = msg;

	  radioIn = (radioIn + 1) % RADIO_QUEUE_LEN;
	
	  if (radioIn == radioOut)
	    radioFull = TRUE;

	  if (!radioBusy)
	    {
	      post radioSendTask();
	      radioBusy = TRUE;
	    }
	}
      else
	dropBlink();
    }
    
    return ret;
  }

  event void SerialAMSend.sendDone(message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == serialQueue[serialOut])
	  {
	    if (++serialOut >= SERIAL_QUEUE_LEN)
	      serialOut = 0;
	    if (serialFull)
	      serialFull = FALSE;
	  }
    post serialSendTask();
  }

  event void RadioAMSend.sendDone(message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == radioQueue[radioOut])
	  {
	    if (++radioOut >= RADIO_QUEUE_LEN)
	      radioOut = 0;
	    if (radioFull)
	      radioFull = FALSE;
	  }
    
    post radioSendTask();
  }
}  
