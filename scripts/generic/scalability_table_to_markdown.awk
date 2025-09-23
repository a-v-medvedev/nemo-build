#!/bin/awk

#cat orca1_cce.txt | awk -vFLDS=CPU,GPU-ACC,GPU-OMP -vBASELINE=CPU

BEGIN { 
  if (FLDS=="") exit 1; 
  split(FLDS,FIELDS,/,/); 
  if (SPD=="") SPD="min"; 
  for (i in FIELDS) {
    if (FIELDS[i]==SPD) SPD=i
    if (FIELDS[i]!=BASELINE) V[i]=0
    else baselineidx=i
  } 
  THR_ZERO=2
  THR_EQ=20
  DIVIDER=1000
} 
  

/^---/ {next} 

/nn=[0-9]+.*: / { 
  print "\n## " $0 
  printf "\n| Region | " BASELINE " |" 
  for (i in V) printf " " FIELDS[i] " |"; 
  printf " SPEEDUP |\n" 
  print "|------------|---|---|---|--|"
  next 
} 

/: [0-9]/ {
  region=$1
  #print ">> ", region, " baselineidx: ", baselineidx 
  nf=2
  max=0; min=9999999999; nominmax=0;
  for (i in FIELDS) {
    value=$nf
    region_nf=$(nf-1)
    if (region_nf != region) exit 1;
    #print ">> ", region, " nf: ", $nf, " >> "
    nf+=2
    if (i==baselineidx) {
      baseline=value
      if (SPD=="min") continue;
    }
    if (value < THR_ZERO) {
      nominmax=1
    } else {
      if (min>value) {
        min=value
        minidx=i
        #print ">> ", region, " updated min: ", min, ",", minidx 
      }
      if (max<value) {
        max=value
        maxidx=i
        #print ">> ", region, " updated max: ", max, ",", maxidx 
      }
    }
    if (FIELDS[i]!=BASELINE) V[i]=value
  }
  #print ">> ", region, " speedup: ", baseline/min 
  if (!nominmax && max-min<THR_EQ) nominmax=1
  value=baseline
  if (value<THR_ZERO) value="--"
  else value=int(value/DIVIDER)
  if ((nominmax || minidx==baselineidx) && value!="--") bold="**"; else bold="" 
  printf "| `" region "` | " bold value bold " | "
  for (i in V) {
    if ((nominmax || minidx==i) && value!="--") bold="**"; else bold=""
    value=V[i]
    if (value<THR_ZERO) value="--"
    else value=int(value/DIVIDER)
    printf " " bold value bold " |"
  }
  if (baseline!=0) {
    if (SPD=="min") value=min
    else value=V[SPD]
    if (value>THR_ZERO) {
      speedup=baseline/value
      printf " %4.1f |", speedup    
    } else {
      printf "  --   |"
    }
  }
  printf "\n"
  next
}
