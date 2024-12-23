#!/bin/bash

#
# NOTE: this code uses `yq` utility for YAML file processing. The easiest way to get it:
#  $ wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/bin/yq
#

BASE_BINARY_NAME=""
ALLBINS=""
NNS=""
TAKES=""
METRICS_PATTERN=""
NMETRICS=""
RUN_UNDER_PROFILER=FALSE
ASYNC_PSUBMIT=FALSE
OMIT_DOWNLOADS=FALSE

function fatal() {
    echo "FATAL: $1" 1>&2
    exit 1
}

function mangle_binary_name() {
    local bin="$1"
    echo "$bin" | sed 's/[-.]/_/g'
    return 0
}

function is_set_to_true() {
    local varname=$1
    set +u
    [ -z "${!varname}" -o "${!varname}" == 0 -o "${!varname}" == false -o "${!varname}" == FALSE ] && return 1
    set -u
    return 0
}

function nfiles_by_mask() {
    local mask="$1"
    ls -1 $mask 2>/dev/null | wc -l
    return 0
}

function yaml_check_correctness() {
    local yaml="$1"
    yq e "." "$yaml" >& /dev/null || fatal "can't parse the file $yaml"
    return 0
}

function yaml_entry_exists() {
    local yaml="$1"
    local expr="$2"
    [ "$(yq e "$expr" "$yaml")" != "null" ]
}

function yaml_get() {
    local yaml="$1"
    local expr="$2" 
    yq e "$expr" "$yaml" || fatal "error evaluating expr: \"$expr\" in file: $yaml."
    return 0
}

function yaml_get_if_exists() {
    local yaml="$1"
    local expr="$2" 
    local var="$3"
    local value=$(yq e "$expr" "$yaml")
    [ $value == "null" ] || eval $var=$value
    return 0
}

function yaml_array_length() {
    local yaml="$1"
    local expr="$2" 
    yq e "$expr | length" "$yaml" || fatal "error evaluating expr: \"$expr | length\" in file: $yaml."
    return 0
}

function yaml_keys() {
    local yaml="$1"
    local expr="$2" 
    yq e "$expr | keys | join(\" \")" "$yaml" || fatal "error evaluating expr: \"$expr | keys in file: $yaml."
    return 0
}

function yaml_array() {
    local yaml="$1"
    local expr="$2" 
    yq e "$expr | join(\" \")" "$yaml" || fatal "error evaluating expr: \"$expr | join(\" \")\" in file: $yaml."
    return 0
}

root_directory=""
function remove_scal_scripts() {
    [ -z "$root_directory" ] || cd $root_directory
    rm -f .scal.script.*
}

function parse_yaml_config() {
    local yaml="$1"
    yaml_check_correctness "$yaml"
    root_directory=$pwd
    trap remove_scal_scripts EXIT
    yaml_get_if_exists "$yaml" ".base_binary_name" BASE_BINARY_NAME
    yaml_get_if_exists "$yaml" ".target_directory" TARGET_DIRECTORY
    [ -z "$BASE_BINARY_NAME" ] && fatal "base_binary_name is a required field."
    [ -z "$TARGET_DIRECTORY" ] && fatal "target_directory is a required field."
    yaml_get_if_exists "$yaml" ".workload_name" WORKLOAD_NAME
    [ -z "$WORKLOAD_NAME" ] && fatal "workload_name is a required field."
    yaml_entry_exists "$yaml" ".binaries" || fatal "binaries list must present in the yaml config."
    [ $(yaml_array_length "$yaml" ".binaries") == 0 ] && fatal "binaries list must present in the yaml config."
    for bin in $(yaml_array "$yaml" ".binaries"); do
        [ -z "$ALLBINS" ] || ALLBINS="$ALLBINS $bin"
        [ -z "$ALLBINS" ] && ALLBINS="$bin"
    done
    if yaml_entry_exists "$yaml" ".environment"; then        
        local nlines=$(yaml_array_length "$yaml" ".environment")
        if [ "$nlines" != 0 ]; then
            for i in $(seq 0 1 $(expr $nlines - 1)); do
                local line=$(yaml_get "$yaml" ".environment[$i]")
                [ "$line" == "null" ] && continue
                echo $line
                eval $line
            done    
        fi
    fi
    
    yaml_entry_exists "$yaml" ".scope" || fatal "scope definition must present in the yaml config."
    yaml_entry_exists "$yaml" ".scope.nnodes" || fatal "scope/nnodes definition must present in the yaml config."
    yaml_entry_exists "$yaml" ".scope.ntakes" || fatal "scope/ntakes definition must present in the yaml config."
    
    for nn in $(yaml_array "$yaml" ".scope.nnodes"); do 
        [ -z "$NNS" ] || NNS="$NNS $nn"
        [ -z "$NNS" ] && NNS="$nn"
    done
    
    TAKES=$(seq 1 1 $(yaml_get "$yaml" ".scope.ntakes"))
    
    yaml_entry_exists "$yaml" ".metrics" || fatal "metrics definition must present in the yaml config."    
    yaml_entry_exists "$yaml" ".metrics.pattern" || fatal "metrics/pattern definition must present in the yaml config."    
    
    METRICS_PATTERN=$(yaml_get "$yaml" ".metrics.pattern")
    yaml_get_if_exists "$yaml" ".metrics.quantity" NMETRICS
    NMETRICS=${NMETRICS:=0}

    if yaml_entry_exists "$yaml" ".settings"; then
        yaml_get_if_exists "$yaml" ".settings.run_under_profiler" RUN_UNDER_PROFILER
	    yaml_get_if_exists $yaml ".settings.async_psubmit" ASYNC_PSUBMIT
        yaml_get_if_exists $yaml ".settings.omit_downloads" OMIT_DOWNLOADS
    fi
    if yaml_entry_exists "$yaml" ".per-binary"; then
        for bin in $(yaml_keys "$yaml" ".per-binary"); do
            if yaml_entry_exists "$yaml" ".per-binary.[\"$bin\"].build"; then 
                local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
                local binstr=$(mangle_binary_name $bin)
                eval build_script_$binstr=$script_file_name
                yaml_get "$yaml" ".per-binary.[\"$bin\"].build" > $script_file_name
            fi
            if yaml_entry_exists "$yaml" ".per-binary.[\"$bin\"].run"; then
                local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
                local binstr=$(mangle_binary_name $bin)
                eval run_script_$binstr=$script_file_name
                yaml_get "$yaml" ".per-binary.[\"$bin\"].run" > $script_file_name
            fi
        done 
    fi
    if yaml_entry_exists "$yaml" ".general"; then
        if yaml_entry_exists "$yaml" ".general.build"; then  
            local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
            build_script=$script_file_name
            yaml_get "$yaml" ".general.build" > $script_file_name
        fi
        if yaml_entry_exists "$yaml" ".general.run"; then
            local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
            run_script=$script_file_name
            yaml_get "$yaml" ".general.run" > $script_file_name
        fi
    fi
}

function submit() {
  local nn="$1"
  local nt="$2"
  local optlist="$3"
  local bin="$4"
  local args=""
  local opts="./psubmit.opt"
  local binstr=$(mangle_binary_name "$bin")
  [ -v "run_script_$binstr" ] && eval source \${run_script_$binstr}
  [ -v "run_script" ] && source ${run_script}

  local out=$(mktemp -p. .psubout-XXXXXXXXXX)
  [ -z "$nt" ] || optnt="-t$nt"
  [ -z "$optlist" ] || optnn="-n$nn"
  [ -z "$optlist" ] || optlist="-l$optlist" 
  psubmit.sh $optnn $optnt $optlist -a "$args" -o "$opts" >& $out
  cat $out | grep 'Job ID ' | awk '{print $3}'
}

function execute() {
  [ -e "$bin" ] || fatal "executable not found: $bin."
  dir=scaling_${bin}_${WORKLOAD_NAME}_NN${nn}_take$take
  [ -e "$dir" ] && rm -rf "$dir"
  local ntstr=${nt:=}
  [ -z "$ntstr" ] || ntstr="nt=$ntstr"
  [ -z "$optlist" ] && echo "submit: nn=$nn $ntstr bin=\"$bin\""
  [ -z "$optlist" ] || echo "submit: optlist=$optlist bin=\"$bin\""
  if is_set_to_true ASYNC_PSUBMIT; then
    { local id=$(submit "$nn" "$nt" "$optlist" "$bin"); [ -z "$id" ] || mv results.$id $dir; } &
  else
    local id=$(submit "$nn" "$nt" "$optlist" "$bin"); [ -z "$id" ] || mv results.$id $dir;
  fi
}

function report-extract() {
  if [ $(nfiles_by_mask "$dir/result.*.yaml") == 1 ]; then
    local nfields=$NMETRICS
    table=table.$bin.$take
    cat $dir/result.*.yaml | egrep "$METRICS_PATTERN" > $table
    local nrecords="$(cat $table | wc -l)"
    [ "$nrecords" == 0 ] && { rm $table; echo "WARNING: no result records in $dir (pattern: \"$METRICS_PATTERN\")"; }
    [ "$nfields" == 0 ] && continue
    if [ $nrecords != $nfields ]; then
      rm $table
      echo "WARNING: fields quantity mismatch in results: $dir (pattern: \"$METRICS_PATTERN\"), results table removed"
    fi
  fi
}

function report-average() {
  if [ $(nfiles_by_mask "table.$bin.*") != 0 ]; then
    paste table.$bin.* | awk '{sum=0;min=9999999;max=0;n=0;for (i=1;i<=NF;i++) {if (i%2==0) {sum+=$i; if($i!=0) n++; min=(min>$i?$i:min); max=(max<$i?$i:max);}} if (min==0||n<=2) print $1 " " max; else print $1 " " (sum-min-max)/(n-2)}' > table.$bin.avg
  else 
    echo "WARNING: no data for binary: $bin"
  fi
}

function report-print() {
  if [ $(nfiles_by_mask "table.*.avg") != 0 ]; then
    { echo "nn=$nn:" table.*.avg; echo "---"; paste table.*.avg; echo "---"; } >> ../scaling_report.txt
    rm table.*.*
  else
    echo "WARNING: no data for nn: $nn"
  fi
}

function report-postproc() {
   # Postprocess the report to a markdown table if possible:
   if [ "$(cat scaling_report.txt | wc -l)" != 0 ]; then
     FLDS=$(echo $ALLBINS | tr ' ' ',')
     BASELINE=$(echo $ALLBINS | awk '{print $1}')
     if [ "$(echo $ALLBINS | awk '{print NF}')" -gt 1 ]; then
       cat scaling_report.txt | awk -vFLDS=$FLDS -vBASELINE=$BASELINE -f ./scalability_table_to_markdown.awk > scaling_report.md
     fi
   fi
}

isuint() { case $1 in ''|*[!0-9]*) return 1;;esac;}

function detect_optlist() {
  local optlist="$1"
  is_uint "$nn" || is_uint "$nt" && optlist=""
  echo "$optlist"
}

function get_hash_of_optlist() {
  local optlist="$1"
  echo $optlist | | od -An -t u1 | awk '{for(i=1;i<=NF;i++) hash=(hash*$i+$i/10)%10000} END {printf "X%04X\n", hash}'
#  local nnodes=""
#  for opt in $(echo "$optlist" | tr ':' ' '); do
#    case $opt in
#    nnodes=*) nnodes=$(echo $opt | cut -d= -f2 -s)
#    esac
#  done
#  echo $nnodes
}


function cycle() {
  local body_take="$1"
  local body_bin="$2"
  local body_nn="$3"
  for nn_and_nt in $NNS; do
    local nn=$(echo $nn_and_nt | cut -d: -f1)	 
    local nt=$(echo $nn_and_nt | cut -d: -s -f2)	 
    local optlist=$(detect_optlist "$nn_and_nt") 
    [ -z "$optlist" ] || nn=$(get_hash_of_optlist "$optlist")
    for bin in $ALLBINS; do
      for take in $TAKES; do
        dir=scaling_${bin}_${WORKLOAD_NAME}_NN${nn}_take$take
        [ -z "$body_take" ] || eval $body_take
      done
      [ -z "$body_bin" ] || eval $body_bin
    done
    [ -z "$body_nn" ] || eval $body_nn
  done
}

function download() {
  for bin in $ALLBINS; do
    local binstr=$(mangle_binary_name "$bin")
    [ -v "build_script_$binstr" ] && eval source \${build_script_$binstr}
    [ -v "build_script" ] && source ${build_script}
    echo "-- Download for $bin:"
    [ -e overrides.yaml ] && cat overrides.yaml
    echo "--"
    echo -n > download_${bin}.log
    ./dnb.sh :du &>> download.log || fatal "$bin: failed on download stage."
    echo "--"
  done
}

function build() {
  set -ue
  rm -rf $TARGET_DIRECTORY/$BASE_BINARY_NAME
  for bin in $ALLBINS; do
    local binstr=$(mangle_binary_name "$bin")
    [ -v "build_script_$binstr" ] && eval source \${build_script_$binstr}
    [ -v "build_script" ] && source ${build_script}

    echo "-- Building $bin:"
    [ -e overrides.yaml ] && cat overrides.yaml
    echo "--"
    echo -n > build_${bin}.log
    ./dnb.sh &>> build_${bin}.log || fatal "$bin: failed on build stage."
    cd $TARGET_DIRECTORY; rm -rf $bin; mv $BASE_BINARY_NAME $bin; cd - >& /dev/null
    ls -ld $TARGET_DIRECTORY/$bin
    du -sh $TARGET_DIRECTORY/$bin
    echo "--"
  done
}

[ -f "dnb.sh" -a -f "dnb.yaml" ] || fatal "must be run from build system root directory." 
[ -e "scalability_table.yaml" ] || fatal "config file scalability_table.yaml is required."
[ -z "$1" ] && fatal "single argument is required: download|build|execute|report"
which yq >& /dev/null || fatal "the utility yq must be available"
parse_yaml_config "scalability_table.yaml"
case $1 in
  download) download;;
  build)   build;;
  execute) [ -d "$TARGET_DIRECTORY" ] || fatal "no directory: $TARGET_DIRECTORY -- was the build stage complete?"
           cd $TARGET_DIRECTORY  
	   cycle "execute" 
           wait
           ;;
  report)  [ -d "$TARGET_DIRECTORY" ] || fatal "no directory $TARGET_DIRECTORY -- was the build stage complete?"
           cd $TARGET_DIRECTORY
           echo -n > ../scaling_report.txt   
           cycle "report-extract" "report-average" "report-print";
           cd ..
           report-postproc
           ;;
  *) fatal "Unknown mode: choose one of: build, execute, report.";;
esac

