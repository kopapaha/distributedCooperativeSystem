#!/usr/bin/awk -f
BEGIN {
  #154 msgs
  tmp=0;
  count[12]=0;
  i=0;
  g=1;
}
{
  #101 msgID start
  if (g==1){
    tmp=$7;
    g++;
  }
  if($7!=tmp){i++; tmp=$7;}
  count[i]++;
}
END {
  for(i=0;i<12;i++) 
    #print "msgID:",i " coverage:",count[i];
    print i, count[i];
}