#!/bin/bash

[ -v RUNNER_SCRIPT_DEFAULT_BINARY ] || { echo "FATAL: runner-script.sh: RUNNER_SCRIPT_DEFAULT_BINARY must be set"; exit 1; }
[ -v RUNNER_SCRIPT_DEFAULT_ARGS ] || { echo "FATAL: runner-script.sh: RUNNER_SCRIPT_DEFAULT_ARGS must be set"; exit 1; }

function is_set_to_true() {
    local varname=$1
    set +u
    [ -z "${!varname}" -o "${!varname}" == 0 -o "${!varname}" == false -o "${!varname}" == FALSE ] && return 1
    set -u
    return 0
}

[ ! -z "$BINARY" -a ! -z "$1" -a "$BINARY" != "$1" ] && { echo "FATAL: runner-script.sh: can't handle different binary names from different sources: BINARY env. and an argument."; exit 1; }
[ -z "$BINARY" ] && BINARY="$RUNNER_SCRIPT_DEFAULT_BINARY"
[ -z "$1" ] || { BINARY="$1"; shift; }

ARGS="$*"
[ -z "$ARGS" ] && ARGS="$RUNNER_SCRIPT_DEFAULT_ARGS"

export local_rank=$SLURM_LOCALID
export global_rank=$SLURM_PROCID

if [ "$SLURM_NTASKS_PER_NODE" == 8 ]; then

    export ROCR_VISIBLE_DEVICES="$local_rank"
    export MPICH_GPU_SUPPORT_ENABLED=1

    physcores=(49-55 57-63 17-23 25-31 1-7 9-15 33-39 41-47)
    threads=(7 7 7 7 7 7 7 7)

    [ "$OMP_NUM_THREADS" != 1 ] && export OMP_NUM_THREADS=${threads[$local_rank]}
    export OMP_DISPLAY_AFFINITY=true
    export CRAY_OMP_CHECK_AFFINITY=TRUE
    export OMP_PROC_BIND=close
    export OMP_PLACES=cores

    export MPICH_OFI_NIC_POLICY=GPU
    export MPICH_OFI_NIC_VERBOSE=2

    if [ -v PROFILE ]; then
        export PROFILE
        [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: numactl -l --all --physcpubind=${physcores[$local_rank]} -- ./profiling-wrapper.sh $BINARY $ARGS"
        numactl -l --all --physcpubind=${physcores[$local_rank]} -- ./profiling-wrapper.sh $BINARY $*
    else
# NOTE: possible workaround for cce/16 and rocm/6 compatibility bug:
#        export LD_PRELOAD=/opt/cray/pe/gcc/12.2.0/snos/lib64/libstdc++.so.6
        [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: numactl -l --all --physcpubind=${physcores[$local_rank]} -- $BINARY $ARGS"
        numactl -l --all --physcpubind=${physcores[$local_rank]} -- $BINARY $*
    fi

else

    if [ -v PROFILE ]; then
        export PROFILE
        [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: ./profiling-wrapper.sh $BINARY $ARGS"
        ./profiling-wrapper.sh $BINARY $ARGS
    else
        [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: $BINARY $ARGS"
        $BINARY $ARGS
    fi
fi

