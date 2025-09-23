#!/bin/awk

BEGIN { 
  if (NNS=="") exit 1; 
  split(NNS,NUMBER_OF_NODES,/,/); 
  min_nn=999999; min_idx=0;
  for (i in NUMBER_OF_NODES) if (NUMBER_OF_NODES[i]<min_nn) { min_nn=NUMBER_OF_NODES[i]; min_idx=i; }
  for (i in NUMBER_OF_NODES) COEF[i]=NUMBER_OF_NODES[i]/min_nn;  
  for (i in NUMBER_OF_NODES) SORTED_NN[i]=NUMBER_OF_NODES[i]
  asort(SORTED_NN)
  THR_ZERO=3
  DIVIDER=1000
} 
  

/^---/ {next} 

/^fld=.*: / { 
  print "\n## " $0 
  printf "\n| Region | " 
  for (x in SORTED_NN) { nn=SORTED_NN[x]; printf " nn=" nn " |"; }
  printf "\n"
  printf "|------------|"
  for (i in NUMBER_OF_NODES) printf "---|"
  printf "\n"
  next 
} 

/: [0-9]/ {
  region=$1
  nf=2
  max=0; min=9999999999; nominmax=0;
  
  for (i in NUMBER_OF_NODES) {
    value=$nf
    region_nf=$(nf-1)
    if (region_nf != region) exit 1;
    nf+=2
    eff=-1
    V[i]=0
    if (value > THR_ZERO) V[i]=value;
    if (i==min_idx) baseline=value
  }

  printf "| `" region "` | " 
  for (i in V) I[NUMBER_OF_NODES[i]]=i
  for (x in SORTED_NN) {
    nn=SORTED_NN[x]
    i=I[nn]
    if (V[i] == 0 || baseline == 0) {
      printf " -- |"
    } else {
      eff=100.0*(2.0-(COEF[i]*V[i]/baseline))
      printf " " int(V[i]/DIVIDER) " (" int(eff) "%)" " |"
    }
  }
  printf "\n"
  next
}
