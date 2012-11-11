

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

  BlinkToRadioC -> MainC.Boot;

  BlinkToRadioC.Timer0 -> Timer0;
  BlinkToRadioC.Timer1 -> Timer1;
  BlinkToRadioC.Leds -> LedsC;

  BlinkToRadioC.Packet -> AMSenderC;
  BlinkToRadioC.AMPacket -> AMSenderC;
  BlinkToRadioC.AMSend -> AMSenderC;

  BlinkToRadioC.AMControl -> ActiveMessageC;
  BlinkToRadioC.Receive -> AMReceiverC;

}

