#!/bin/bash

#
# NOTE: this code uses `yq` utility for YAML file processing. The easiest way to get it:
#  $ wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/bin/yq
#


function fatal() {
    echo "FATAL: $1" 1>&2
    exit 1
}

function mangle_binary_conf_name() {
    local binconf="$1"
    echo "$binconf" | sed 's/[-.]/_/g'
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

isuint() { case $1 in ''|*[!0-9]*) return 1;;esac;}

function detect_optlist() {
  local optlist="$1"
  is_uint "$nn" || is_uint "$nt" && optlist=""
  echo "$optlist"
}

function get_hash_of_optlist() {
  local optlist="$1"
  echo $optlist | od -An -t u1 | awk '{for(i=1;i<=NF;i++) hash=(hash*$i+$i/10)%10000} END {printf "X%04X\n", hash}'
  local opt=""
  for opt in $(echo "$optlist" | tr ':' ' '); do
    case "$opt" in
    nnodes=*) nn=$(echo $opt | cut -d= -f2); break;;
    esac
  done
}

function get_hash_for_nn_np_nt() {
  local optnp=${np:=}; [ -z "$optnp" ] || optnp="-$optnp"
  local optnt=${nt:=}; [ -z "$optnt" ] || optnt="-$optnt"
  echo "$nn$optnp$optnt"
}

#--- YAML general subroutines ------------------------------------------------

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

#--- Cycle ------------------------------------------------------------------------

function submit() {
  local nn="$1"
  local np="$2"
  local nt="$3"
  local optlist="$4"
  local binconf="$5"
  local args=""
  local opts=""
  local binstr=$(mangle_binary_name "$binconf")
  [ -v "run_script_$binstr" ] && eval source \${run_script_$binstr}
  [ -v "run_script" ] && source ${run_script}

  local out=$(mktemp -p. .psubout-XXXXXXXXXX)
  [ -z "$np" ] || optnp="-p$np"
  [ -z "$nt" ] || optnt="-t$nt"
  [ -z "$optlist" ] && optnn="-n$nn"
  [ -z "$optlist" ] || optlist="-l$optlist" 
  [ -z "$opts" ] || optopts="-o $opts" 
  psubmit.sh $optnn $optnt $optlist $optopts -a "$args" -u "$binconf" >& $out
  cat $out | grep 'Job ID ' | awk '{print $3}'
}

function cycle() {
  local body_take="$1"
  local body_bin="$2"
  local body_nn="$3"
  local before="$4"
  local after="$5"
  [ -z "$before" ] || eval "$before"
  for nn_np_nt in $NNS; do
    local nn=$(echo $nn_np_nt | cut -d: -f1)	 
    local np=$(echo $nn_np_nt | cut -d: -s -f2)	 
    local nt=$(echo $nn_np_nt | cut -d: -s -f3)
    local nnhash=""
    [ "$np" == "*" ] && np=""	 
    [ "$nt" == "*" ] && nt=""	 
    local optlist=$(detect_optlist "$nn_np_nt") 
    [ -z "$optlist" ] || nnhash=$(get_hash_of_optlist "$optlist")
    [ -z "$optlist" ] && nnhash=$(get_hash_for_nn_np_nt)
    for binconf in $ALLBINS; do
      for take in $TAKES; do
        dir=scaling_${binconf}_${WORKLOAD_NAME}_NN${nnhash}_take$take
        [ -z "$body_take" ] || eval $body_take
      done
      [ -z "$body_bin" ] || eval $body_bin
    done
    [ -z "$body_nn" ] || eval $body_nn
  done
  [ -z "$after" ] || eval "$after"
}

#--- Scalability testing: parse YAML config ----------------------------------------------------

ALLBINS=""
NNS=""
TAKES=""
METRICS_PATTERN=""
NMETRICS=""
RUN_UNDER_PROFILER=FALSE
ASYNC_PSUBMIT=FALSE
OMIT_DOWNLOADS=FALSE


function check_yaml_parser_available() {
    which yq >& /dev/null || fatal "the utility yq must be available"
    echo -ne "---\naaa: [ bbb,ccc ]\n..." | yq e "." 2>/dev/null | grep -q "bbb, ccc" || fatal "yq utility is disfunctional. Wrong version?"
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
    yaml_get_if_exists "$yaml" ".target_directory" TARGET_DIRECTORY
    [ -z "$TARGET_DIRECTORY" ] && fatal "target_directory is a required field."
    yaml_get_if_exists "$yaml" ".workload_name" WORKLOAD_NAME
    [ -z "$WORKLOAD_NAME" ] && fatal "workload_name is a required field."
    yaml_entry_exists "$yaml" ".binary_confs" || fatal "binary_confs list must present in the yaml config."
    [ $(yaml_array_length "$yaml" ".binary_confs") == 0 ] && fatal "binary_confs list must present in the yaml config."
    for binconf in $(yaml_array "$yaml" ".binary_confs"); do
        [ -z "$ALLBINS" ] || ALLBINS="$ALLBINS $binconf"
        [ -z "$ALLBINS" ] && ALLBINS="$binconf"
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
        for binconf in $(yaml_keys "$yaml" ".per-binary-conf"); do
            if yaml_entry_exists "$yaml" ".per-binary-conf.[\"$binconf\"].build"; then 
                local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
                local binstr=$(mangle_binary_conf_name $binconf)
                eval build_script_$binstr=$script_file_name
                yaml_get "$yaml" ".per-binary-conf.[\"$binconf\"].build" > $script_file_name
            fi
            if yaml_entry_exists "$yaml" ".per-binary-conf.[\"$binconf\"].run"; then
                local script_file_name=$PWD/$(mktemp .scal.script.XXXXXXXX)
                local binstr=$(mangle_binary_conf_name $binconf)
                eval run_script_$binstr=$script_file_name
                yaml_get "$yaml" ".per-binary-conf.[\"$binconf\"].run" > $script_file_name
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

#--- Scalability testing -------------------------------------------------------------------------

function report-extract() {
  if [ $(nfiles_by_mask "$dir/result.*.yaml") == 1 ]; then
    local nfields=$NMETRICS
    table=table.$binconf.$take
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
  if [ $(nfiles_by_mask "table.$binconf.*") != 0 ]; then
    paste table.$binconf.* | awk '{sum=0;min=9999999;max=0;n=0;for (i=1;i<=NF;i++) {if (i%2==0) {sum+=$i; if($i!=0) n++; min=(min>$i?$i:min); max=(max<$i?$i:max);}} if (min==0||n<=2) print $1 " " max; else print $1 " " (sum-min-max)/(n-2)}' > table.$binconf.avg
  else 
    echo "WARNING: no data for binary conf: $binconf"
  fi
}

function report-print() {
  local header="nn=$nn";
  if [ "$nn" != "$nnhash" ]; then 
    [ -z "$optlist" ] && header="$header $nn_np_nt"; 
    [ -z "$optlist" ] || header="$header $optlist"; 
  fi
  if [ $(nfiles_by_mask "table.*.avg") != 0 ]; then
    local list=$(echo table.*.avg | sed 's/table\.//g;s/\.avg//g')
    { echo "$header:" $list; echo "---"; paste table.*.avg; echo "---"; } >> ../scaling_report.txt
    rm table.*.*
  else
    echo "WARNING: no data for $header"
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

function download() {
  for binconf in $ALLBINS; do
    local binstr=$(mangle_binary_conf_name "$binconf")
    [ -v "build_script_$binstr" ] && eval source \${build_script_$binstr}
    [ -v "build_script" ] && source ${build_script}
    echo "-- Download for $binconf:"
    [ -e overrides.yaml ] && cat overrides.yaml
    echo "--"
    echo -n > download_${binconf}.log
    ./dnb.sh :du &>> download.log || fatal "$binconf: failed on download stage."
    echo "--"
  done
}

function build() {
  set -ue
  for binconf in $ALLBINS; do
    local binstr=$(mangle_binary_conf_name "$binconf")
    [ -v "build_script_$binstr" ] && eval source \${build_script_$binstr}
    [ -v "build_script" ] && source ${build_script}

    echo "-- Building $binconf:"
    [ -e overrides.yaml ] && cat overrides.yaml
    echo "--"
    echo -n > build_${binconf}.log
    export DNB_SANDBOX_SUBDIR=${binconf}
    ./dnb.sh &>> build_${binconf}.log || fatal "$binconf: failed on build stage."
    du -sh $TARGET_DIRECTORY/$binconf
    echo "--"
  done
}

function execute() {
  [ -e "$binconf" ] || fatal "executable not found: $binconf."
  dir=scaling_${binconf}_${WORKLOAD_NAME}_NN${nnhash}_take$take
  [ -e "$dir" ] && rm -rf "$dir"
  local ntstr=${nt:=}; [ -z "$ntstr" ] || ntstr=" nt=$ntstr"
  local npstr=${np:=}; [ -z "$npstr" ] || npstr=" np=$npstr"
  [ -z "$optlist" ] && echo "submit: nn=${nn}${npstr}${ntstr} binconf=\"$binconf\""
  [ -z "$optlist" ] || echo "submit: optlist=$optlist binconf=\"$binconf\""
  if is_set_to_true ASYNC_PSUBMIT; then
    { local id=$(submit "$nn" "$np" "$nt" "$optlist" "$binconf"); [ -z "$id" ] || mv results.$id $dir; } &
  else
    local id=$(submit "$nn" "$np" "$nt" "$optlist" "$binconf"); [ -z "$id" ] || mv results.$id $dir;
  fi
}

function go-to-target-dir() {
    [ -d "$TARGET_DIRECTORY" ] || fatal "no directory: $TARGET_DIRECTORY -- was the build stage complete?"
    cd $TARGET_DIRECTORY
    return 0
}

#--- Scalability testing: entry point --------------------------------------------

[ -f "dnb.sh" -a -f "dnb.yaml" ] || fatal "must be run from build system root directory." 
[ -e "scalability_table.yaml" ] || fatal "config file scalability_table.yaml is required."
[ -z "$1" ] && fatal "single argument is required: download|build|execute|report"
chack_yaml_parser_available
parse_yaml_config "scalability_table.yaml"
case $1 in
  download) download;;
  build)    build;;
  execute)  cycle "execute" "" "" "go-to-target-dir"
            wait
            ;;
  report)   echo -n > scaling_report.txt   
            cycle "report-extract" "report-average" "report-print" \
                  "go-to-target-dir" "cd .. && report-postproc";
            ;;
  *)        fatal "Unknown mode: choose one of: download, build, execute, report.";;
esac

