#!/usr/bin/awk -f
BEGIN {

  FS="[ :]";
  timeSend[12];
  timeRcv[12];
  i=-1;
}
{
#print $4;
if ($4=="msg_snd")
{
  i++;
  timeSend[i]=$12+$11*60+$10*3600;
}
else
{
  timeRcv[i]=$12+$11*60+$10*3600;
}
}
END {
  for(i=0;i<12;i++){ 
    #print "msgID:",i " coverage:",count[i];
    print i, timeRcv[i]-timeSend[i];
  }
}