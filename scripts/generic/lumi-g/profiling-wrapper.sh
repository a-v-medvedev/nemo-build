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
    echo "$str$delim" | cut -d$delim -f$n
}

is_set PROFILE || { echo "FATAL: PROFILE environment variable must be set"; exit 1; }

outdir="profiling.${SLURM_JOBID}"
name="report"

export MPI_RANK=${SLURM_PROCID}
global_rank=$MPI_RANK
rocprof="${ROCM_PATH}/bin/rocprof"
traceopts="--hsa-trace --hip-trace --roctx-trace"

counters1="GPUBusy Wavefronts SALUInsts VALUInsts SFetchInsts VFetchInsts VWriteInsts VALUUtilization"
counters2="SALUBusy VALUBusy WriteSize MemUnitBusy MemUnitStalled WriteUnitStalled LDSBankConflict"
counters3="L2CacheHit"

option=$(get_field "$PROFILE" 1)
parameter=$(get_field "$PROFILE" 2)
parameter2=$(get_field "$PROFILE" 3)

case "$option" in
    gdb)    outdir="${outdir}/rank_${global_rank}"
            outfile="${name}_${global_rank}.gdb"
            mkdir -p $outdir
            [ "$global_rank" == 0 -a ! -f ../gdb.cmd ] && { echo "FATAL: no gdb.cmd"; exit 1; }
            while [ ! -f gdb.cmd ]; do sleep 0.1; done
            cat gdb.cmd > ${outdir}/${outfile}
            [ "$global_rank" == 0 ] && echo "=== gdb.cmd: ===" && cat gdb.cmd && echo "======" && set -x
            exec gdb -batch -x gdb.cmd --args $* 2>&1 >> ${outdir}/${outfile}
            ;;
    counters)  pid="$$"
               outdir="${outdir}/rank_${pid}_${MPI_RANK}" # Output directory per rank
               outfile="${name}_counters_${pid}_${MPI_RANK}.csv"   # Filenames annotated with rank as well

               # NOTE: for kernel names: "$ nm ./nemo | grep '_\$ck_'"
               if [ "$MPI_RANK" == 0 ]; then
                   [ -z "$parameter" ] && { echo "FATAL: PROFILE variable: kernel name as a parameter is required"; exit 1; }
                   kernels=$(nm "$1" | grep '_\$ck_' | grep $parameter)
                   n=$(echo $kernels | wc -l)
                   [ "$n" == 0 ] && { echo "FATAL: can't find the kernel: $kernel_name in the binary $1"; exit 1; }
                   [ "$n" != 1 ] && { echo "FATAL: ambigous kernel name: $kernel_name in the binary $1"; exit 1; }
                   kernel_name=$(echo $kernels | awk '{print $3}')
                   [ -z "$parameter2" ] && parameter2=1
                   counters_varname=counters$parameter2
                   echo -ne "pmc : ${counters1}\npmc : ${counters2}\npmc : ${counters3}\nrange: 0:1\ngpu: 0\nkernel: $kernel_name\n" > rocprof_counters.${SLURM_JOBID}.txt
                   touch .rocprof_counters.${SLURM_JOBID}.txt.done
               else
                   while [ ! -e .rocprof_counters.${SLURM_JOBID}.txt.done ]; do sleep 1; done 
               fi
               ${rocprof} -i rocprof_counters.${SLURM_JOBID}.txt -d ${outdir} -o ${outdir}/${outfile} $*
               [ "$MPI_RANK" == 0 ] && rm .rocprof_counters.${SLURM_JOBID}.txt.done
               ;;
    each-rank) pid="$$"
               outdir="${outdir}/rank_${pid}_${MPI_RANK}" # Output directory per rank
               outfile="${name}_${pid}_${MPI_RANK}.csv"   # Filenames annotated with rank as well
               exec ${rocprof} -d ${outdir} $traceopts -o ${outdir}/${outfile} $*
               ;;
    only-selected-one) outfile=${name}.csv
                       selected="$parameter"
                       [ -z "$selected" ] && selected=0
                       if [ "$MPI_RANK" == "$selected" ]; then 
                           exec ${rocprof} -d ${outdir} $traceopts -o ${outdir}/${outfile} $*
                       else
                           exec $*  
                       fi 
                       ;;
    *) echo "FATAL: PROFILE variable: unknown option"
esac
