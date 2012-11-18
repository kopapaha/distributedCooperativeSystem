#include "TestSerial.h"
#include "BlinkToRadio.h"

configuration BlinkToRadioAppC
{
}
implementation
{
  components MainC, LedsC, BlinkToRadioC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new AMSenderC(AM_BLINKTORADIO);
  components new AMReceiverC(AM_BLINKTORADIO);
  components ActiveMessageC;
  components new DemoSensorC() as lightSensor;
  components SerialActiveMessageC as AM;

  BlinkToRadioC -> MainC.Boot;

  BlinkToRadioC.Timer0 -> Timer0;
  BlinkToRadioC.Timer1 -> Timer1;
  BlinkToRadioC.Leds -> LedsC;

  BlinkToRadioC.Packet -> AMSenderC;
  BlinkToRadioC.AMPacket -> AMSenderC;
  BlinkToRadioC.AMSend -> AMSenderC;
  BlinkToRadioC.AMControl -> ActiveMessageC;
  BlinkToRadioC.Receive -> AMReceiverC;
  BlinkToRadioC.light-> lightSensor;

  //Serial
  BlinkToRadioC.serialControl -> AM;
  BlinkToRadioC.serialAMSend -> AM.AMSend[AM_TEST_SERIAL_MSG];
  BlinkToRadioC.serialPacket -> AM;
  BlinkToRadioC.serialReceive -> AM.Receive[AM_TEST_SERIAL_MSG];
}