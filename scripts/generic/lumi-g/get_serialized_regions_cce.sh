#!/bin/bash

set -u

LOG=compiler.log
##SRC_PATH=nemo.src/cfgs/ORCA2/BLD/ppsrc/nemo

get_diagnostic_block=$(cat << 'EOF'
BEGIN {print "```"}
match($0, "ACCEL " s) {if (start==0) start=1;}
start==1 && /Line = / {for (i=1;i<=NF;i++) if ($i=="Line" && $(i+2) >= ls && $(i+2) <= le) start=2;}
start==2 && match($0, "ACCEL " s) && /Line = / { for (i=1;i<=NF;i++) if ($i=="Line" && $(i+2) > le) {start=0;} }
match($0, "ACCEL ") && !match($0, "ACCEL " s) {if (start>0) start=0}
/A region starting at line/ && start {if ($6 == ls && $11 == le) start=2; else start=0;}
/was partitioned/ && start==2 {print; start=0;}
/^[ ]*[0-9]+\.  / {next}
start==2 {print}
END {print "```"}
EOF
)

get_source_code_block=$(cat << 'EOF'
BEGIN {print "```"}
NR>=ls-1 && NR<=le+1 {print} 
END {print "```"}
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
  cat $lines | while read ls le; do
    echo "- Line $(basename $src):$ls ($src):"
    awk -vls=$ls -vle=$le -vs=$subroutine "$get_diagnostic_block" < $LOG
    echo
    [ -f "$src" ] || xsrc=$(find nemo.src/ -name "$(basename $src)")
    [ -z "$xsrc" ] || src="$xsrc"
    cat -n "$src" | awk -vls=$ls -vle=$le "$get_source_code_block" > .${subroutine}__src.txt  
    local nextra=$(awk "$get_num_of_extra_spaces" < .${subroutine}__src.txt)
    sed -i "s/\( [0-9]*\)\s\{${nextra}\}/\1/" .${subroutine}__src.txt
    cat .${subroutine}__src.txt
  done
}

cat $LOG | grep -B1 'A region starting at line [0-9]* and ending at line [0-9]* was placed on the accelerator.' | awk '/ACCEL.*, File = / { s=$4; f=$7; sub(/\,/,"",s); sub(/\,/,"",f);} /A region starting/ && s!="" {print $6 " " $11 " " s " " f}' > .regions1.txt

cat $LOG | grep -B1 'A loop starting at line [0-9]* was placed on the accelerator.' | awk '/ACCEL.*, File = / { s=$4; f=$7; sub(/\,/,"",s); sub(/\,/,"",f);} /A loop starting/ && s!="" { loopline=$6; while ((getline ls le field3 field4 < ".regions1.txt") > 0) { if (ls<=loopline && le>=loopline) exit; } print loopline " " loopline " " s " " f}' > .regions2.txt

cat .regions1.txt .regions2.txt | sort > .regions.txt

grep 'was partitioned across the threadblocks and' $LOG | awk '{line=$6; $1=$2=$3=$4=$5=$6=$7=""; printf line " " $0 "\n" }' > .lines-good.txt
#???grep 'was partitioned across the [^t]' $LOG | awk '{line=$6; $1=$2=$3=$4=$5=$6=$7=""; printf line " " $0 "\n" }' > .lines-bad.txt

rm -f .lines.txt
cat .regions.txt | while read ls le s f; do
    d=$(cat .lines-good.txt | awk -vls=$ls -vle=$le 'ls<=$1 && le>=$1 {print $0}')
    [ -z "$d" ] && echo "$ls $le $s $f" >> .lines.txt
done

cat .lines.txt | awk '{print $3}' | uniq | while read subroutine; do 
  src_file=$(grep " $subroutine " .lines.txt | awk '{print $4}' | head -n1)
  grep " $subroutine " .lines.txt | awk '{print $1 " " $2}' > ".${subroutine}__lines.txt"
  make_subroutine_listing "$subroutine" ".${subroutine}__lines.txt" "nemo.src/$src_file" 
done

rm -f .lines.txt .regions.txt .regions?.txt .subroutines.txt .lines-good.txt .lines-bad.txt
rm -f .*__lines.txt
rm -f .*__src.txt
