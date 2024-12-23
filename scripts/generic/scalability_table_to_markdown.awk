#!/bin/awk

#cat orca1_cce.txt | awk -vFLDS=CPU,GPU-ACC,GPU-OMP -vBASELINE=CPU

BEGIN { if (FLDS=="") exit 1; split(FLDS,FIELDS,/,/); } 

/^---/ {next} 

/np=[0-9]+: / { 
  print "\n## " $0 
  printf "\n| Region |" 
  for (i in FIELDS) printf " " FIELDS[i] " |"; 
  printf " SPEEDUP |\n" 
  print "|------------|---|---|---|--|" 
  next 
} 

/: [0-9]/ {
  region=$1
  baseline=$2
  nf=4
  max=0; min=9999999; nominmax=0;
  for (i in FIELDS) {
    if (FIELDS[i] == BASELINE) continue
    V[i]=$nf
    nf+=2
    if (V[i] == 0) {
      nominmax=1
    } else {
      if (min>V[i]) {
        min=V[i]
        minidx=i
      }
      if (max<V[i]) {
        max=V[i]
        maxidx=i
      }
    }
  }
  if (!nominmax && max-min<20) nominmax=1
  printf "| `" region "` | " int(baseline) " | "
  for (i in V) {
    printf " "
    if (nominmax || minidx==i) printf "**"
    printf int(V[i])
    if (nominmax || minidx==i) printf "**"
    printf " |"
  }
  if (baseline!=0 && min!=0) {
    speedup=baseline/min
    printf " %4.1f |", speedup    
  } else {
    printf "  --   |"
  }
  printf "\n"
  next
}
