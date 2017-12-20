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
    interface Receive;
    interface SplitControl as RadioControl;
    interface Read<uint16_t> as TemperatureRead;
	  interface Read<uint16_t> as HumidityRead;
	  interface Read<uint16_t> as LightRead;
  }
}
implementation
{
  event void Boot.booted() {
    call Timer.startPeriodic(DEFAULT_INTERVAL);
  }

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
	  printf("Humidity: %d\n", humidity);
    }
	else {
      printf("Get humidity failed\n");
      call HumidityRead.read();
    }
  }

  event void LightRead.readDone(error_t result, uint16_t data)
  {
    if (result == SUCCESS) {
      uint16_t light = 0.625 * 10 * data * 1.5 / 4.096;
	  printf("Light: %d\n", light);
    }
	else {
      printf("Get light failed\n");
      call LightRead.read();
    }
  }
}
