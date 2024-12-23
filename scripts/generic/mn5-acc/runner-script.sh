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

export local_rank=$OMPI_COMM_WORLD_LOCAL_RANK
export global_rank=$OMPI_COMM_WORLD_RANK

nonumactl=0
nomps=1

[ -z "$PSUBMIT_PPN" ] && PSUBMIT_PPN=8
[ -z "$PSUBMIT_NGPUS" ] && PSUBMIT_NGPUS=4
# P=10; C=8; for i in $(seq 1 1 $P); do a=$(expr '(' $i '-' 1 ')' '*' $C); b=$(expr '(' $i '-' 1 ')' '*' $C '+' $C - 1); echo "$a-$b"; done | tr '\n' ' '
if [ "$PSUBMIT_PPN" == 1 ]; then
  threads=(20)
  physcores=(0-19)
elif [ "$PSUBMIT_PPN" == 2 ]; then
  threads=(20 20)
  physcores=(0-19 20-39)
elif [ "$PSUBMIT_PPN" == 4 ]; then
  threads=(20 20 20 20)     
  physcores=(0-19 20-39 40-59 60-79)
elif [ "$PSUBMIT_PPN" == 8 ]; then
  threads=(10 10 10 10 10 10 10 10)
  physcores=(0-9 10-19 20-29 30-39 40-49 50-59 60-69 70-79)
  nomps=0
#elif [ "$PSUBMIT_PPN" == 10 ]; then
#  threads=(8 8 8 8 8 8 8 8 8 8)
#  physcores=(0-7 8-15 16-23 24-31 32-39 40-47 48-55 56-63 64-71 72-79)
#  nomps=0
elif [ "$PSUBMIT_PPN" == 16 ]; then
  threads=(5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5)
  physcores=(0-4 5-9 10-14 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 65-69 70-74 75-79)
  nomps=0
else
  [ "$PSUBMIT_PPN" -gt "$PSUBMIT_NGPUS" ] && nomps=0
  nonumactl=1
fi

nics=(mlx5_0:1 mlx5_1:1 mlx5_4:1 mlx5_5:1)

#  NIC0: mlx5_0
#  NIC1: mlx5_1
#  NIC4: mlx5_4
#  NIC5: mlx5_5


divider=$(expr "$PSUBMIT_PPN" / "$PSUBMIT_NGPUS")
[ "$divider" == "0" ] && divider=1
export local_device_id=$(echo | awk -v X=$local_rank -v D=$divider "{print int(X/D)}")

export OMP_PROC_BIND=close
export OMP_PLACES=cores
[ -z "$OMP_NUM_THREADS" -a "$nonumactl" == 0 ] && export OMP_NUM_THREADS=${threads[$local_rank]}
[ ! -z "$OMP_NUM_THREADS" -a "$OMP_NUM_THREADS" -gt "${threads[$local_rank]}" ] && echo "runnetr-script.sh: WARNING: OMP_NUM_THREADS>${threads[$local_rank]} with ppn=$PSUBMIT_PPN may lead to oversubscription"

export CUDA_VISIBLE_DEVICES="$local_device_id"
export UCX_NET_DEVICES="${nics[$local_device_id]}"
#export UCX_CUDA_COPY_DMABUF=no
export NVCOMPILER_ACC_DEFER_UPLOADS=1
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl="^vader,tcp,openib,smcuda"
#export OMPI_MCA_coll_ucc_enable=0

function stop-mps() {
  [ "$local_rank" == 0 -a "$nomps" == 0 ] && sleep 5 && echo quit | nvidia-cuda-mps-control || true
}

function kill-mps() {
    if pgrep nvidia-cuda-mps >& /dev/null; then
        [ "$local_rank" == 0 ] && echo quit | nvidia-cuda-mps-control || true
        sleep 5
        [ "$local_rank" == 0 ] && killall nvidia-cuda-mps 2>/dev/null || true
        timeout 10 bash -c 'while pgrep nvidia-cuda-mps >/dev/null; do sleep 0.5; done' || true
    fi
}

function start-mps() {
    [ "$local_rank" == 0 -a "$nomps" == 0 ] && env -u CUDA_VISIBLE_DEVICES nvidia-cuda-mps-control -d || true
    [ "$local_rank" != 0 -a "$nomps" == 0 ] && timeout 20 bash -c 'until pgrep nvidia-cuda-mps >/dev/null; do sleep 0.5; done'
}


export CUDA_MPS_LOG_DIRECTORY=$PWD
kill-mps
trap stop-mps EXIT
start-mps

numactlline=""
[ "$nonumactl" == 0 ] && numactlline="numactl -l --all --physcpubind=${physcores[$local_rank]} --"

if is_set_to_true PROFILE; then
    export PROFILE
    $numactlline ./profiling-wrapper.sh $BINARY $ARGS
else
    $numactlline $BINARY $ARGS
fi

