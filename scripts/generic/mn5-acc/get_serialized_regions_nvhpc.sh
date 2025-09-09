#!/bin/bash

set -eu

LOG=compiler.log
SRC_PATH=nemo.src/cfgs/ORCA2/BLD/ppsrc/nemo

get_all_diagnostic_lines=$(cat << 'EOF'
/^[^ ]*:$/ { subroutine = $1; gsub(/:/, "", subroutine); line = 0; } 
/^ [ ]*[0-9]*,/ { 
  line = $1; gsub(/,/, "", line); 
}
/prevents/ { 
  if (line == prev + 1 || line == prev) { prev = line; next; }
  print subroutine "  " line; 
  prev = line;
}
EOF
)

get_diagnostic_block=$(cat << 'EOF'
BEGIN { ON=0 } 
/^[^ ][^ ]/ { if (ON) print "```"; ON=0; } 
$0 ~ "^ [ ]*"LINE"," {
  if (match($0, /[Ll]oop/) && !match($0, /!\$acc/) && !match($0, /!\$omp/)) {
    ON=1; 
    print "```"; 
    print; 
    next;
  }
} 
ON==1 && /^ [ ]*[0-9]*,/ {
  if (match($0, /prevents/) == 0) {
    ON=0; 
    print "```";
  }
} 
ON==1 {print}
END {if (ON==1) print "```";}
EOF
)

get_source_code_block=$(cat << 'EOF'
NR>=LINE-3 { 
  if (match($0,/acc end/)) { 
    if (start && NR>=LINE) { print; print "```"; exit; } 
    next; 
  } 
  if (match($0,/acc/)) { 
    if (!start) print "```"; 
    start=1; 
  } 
  if (!start && NR>=LINE) { print "```"; print "   ..."; start=1; }
} 
start==1 {print}
EOF
)

get_num_of_extra_spaces=$(cat << 'EOF'
BEGIN { min_spaces=9999; } 
/ [0-9]+/ {
    gsub(/^[ \t]+/, "", $0)
    spaces = index($0, $2) - length($1);
    if (spaces >= 0 && spaces < min_spaces) { min_spaces = spaces }
}
END { print min_spaces == 9999 ? 0 : (min_spaces > 3 ? min_spaces - 3 : 0); }
EOF
)

make_subroutine_listing() {
  local subroutine=$1	
  local lines=$2
  local src=$3
  echo
  echo "### Subroutine $subroutine"
  for line in $(cat $lines); do
    echo "- Line $(basename $src):$line ($src):"
    awk -vLINE=$line "$get_diagnostic_block" < $LOG
    echo
    cat -n $src | awk -vLINE=$line "$get_source_code_block" > .${subroutine}__src.txt  
    local nextra=$(awk "$get_num_of_extra_spaces" < .${subroutine}__src.txt)
    sed -i "s/\( [0-9]*\)\s\{${nextra}\}/\1/" .${subroutine}__src.txt
    cat .${subroutine}__src.txt
  done
}

[ -e "$LOG" ] || { echo "FATAL: The file $LOG is used to get the compiler output."; exit 1; }
[ -d "$SRC_PATH" ] || { echo "FATAL: We expect directory: $SRC_PATH to contain the preprocesses source code."; exit 1; }
awk "$get_all_diagnostic_lines" < $LOG | sort | uniq > .lines.txt
cat .lines.txt | awk '{print $1}' | uniq | while read subroutine; do 
  src_file=$(grep -iIrl "^[ ]*SUBROUTINE.*$subroutine" $SRC_PATH/*) 
  grep "$subroutine" .lines.txt | awk '{print $2}' > ".${subroutine}__lines.txt"
  make_subroutine_listing "$subroutine" ".${subroutine}__lines.txt" "$src_file" 
done

rm -f .lines.txt
rm -f .*__lines.txt
rm -f .*__src.txt

