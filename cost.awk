#!/usr/bin/awk -f
BEGIN {
  #FS="[ :]";
  nodes=99;
  for(i=0;i<=nodes;i++)
     cost[i]=0;
}
{
  cost[$5]++;
}
END {
  for(i=0;i<=nodes;i++){ 
    #print "msgID:",i " coverage:",count[i];
    print i, cost[i];
  }
}