#!/usr/bin/awk -f
BEGIN {
  #FS="[ :]";
  nodes = 99;
  nofMsgs = 12;
  for(i=0;i<=nodes;i++)
     duplicates[nodes] = 0;
}
{
  duplicates[$5]++;
}
END {
  for(i=0;i<=nodes;i++){ 
    #print "msgID:",i " coverage:",count[i];
    print i, duplicates[i]/nofMsgs;
  }
}