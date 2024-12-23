#!/bin/bash

set -euo pipefail

function is_set() {
    local varname=$1
    set +u
    [ -z "${!varname}" -o "${!varname}" == 0 -o "${!varname}" == false -o "${!varname}" == FALSE ] && return 1
    set -u
    return 0
}

function get_field() {
    local str="$1"
    local n="$2"
    set +u
    local delim="$3"
    set -u
    [ -z "$delim" ] && delim=":"
    echo "$str$delim" | cut -d$delim -f$n -s
}

is_set PROFILE || { echo "FATAL: PROFILE environment variable must be set"; exit 1; }

# NOTE: this is OpenMPI-specific, change this for MPICH-based MPIs
local_rank=$OMPI_COMM_WORLD_LOCAL_RANK
global_rank=$OMPI_COMM_WORLD_RANK

outdir="profiling.${PSUBMIT_JOBID}"
name="report"
# nsys profile -t cuda,nvtx,mpi -s none -f true -o out-$grank.nsys-rep $@
profiler="nsys profile"
limited_scope="--capture-range=cudaProfilerApi --capture-range-end=stop"
traceopts="--trace cuda,nvtx,mpi -s none -f true" 

option=$(get_field "$PROFILE" 1)
parameter=$(get_field "$PROFILE" 2)
parameter2=$(get_field "$PROFILE" 3)

case "$option" in
    gdb) outdir="${outdir}/rank_${global_rank}"
         outfile="${name}_${global_rank}.gdb"
  	     mkdir -p $outdir
   	     [ "$global_rank" == 0 -a ! -f ../gdb.cmd ] && { echo "FATAL: no gdb.cmd"; exit 1; }
	     while [ ! -f gdb.cmd ]; do sleep 0.1; done
	     cat gdb.cmd > ${outdir}/${outfile}
	     [ "$global_rank" == 0 ] && echo "=== gdb.cmd: ===" && cat gdb.cmd && echo "======" && set -x
	     exec gdb -batch -x gdb.cmd --args $* 2>&1 >> ${outdir}/${outfile} 
	     ;;
    counters)  echo "FATAL: counters option is not supported."
               exit 1 
               ;;
    each-rank) outdir="${outdir}/rank_${global_rank}"
               outfile="${name}_${global_rank}.nsys"
               mkdir -p $outdir 
               exec ${profiler} ${traceopts} -o ${outdir}/${outfile} $*
               ;;
    only-selected-one) outfile=${name}.nsys
                       selected="$parameter"
                       [ -z "$selected" ] && selected=0
                       if [ "$global_rank" == "$selected" ]; then
                           mkdir -p $outdir 
                           exec ${profiler} ${traceopts} -o ${outdir}/${outfile} $*
                       else
                           exec $* 
                       fi
                       ;;
esac


#nsys nvprof --print-gpu-trace -f -o nvprof.${PSUBMIT_JOBID} $BINARY $*
###ncu -f -o report.${PSUBMIT_JOBID} --target-processes all $BINARY $*

