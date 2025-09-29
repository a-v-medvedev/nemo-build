#!/bin/bash

[ -v OMPI_COMM_WORLD_LOCAL_RANK ] || { echo "AFFINITY: OMPI_COMM_WORLD_LOCAL_RANK is not defined, are we running under HPCX MPI?"; exit 1; }
[ -v OMPI_COMM_WORLD_RANK ] || { echo "AFFINITY: OMPI_COMM_WORLD_RANK is not defined, are we running under HPCX MPI?"; exit 1; }
[ -v OMPI_COMM_WORLD_LOCAL_SIZE ] || { echo "AFFINITY: OMPI_COMM_WORLD_LOCAL_SIZE is not defined, are we running under HPCX MPI?"; exit 1; }


#-- Definition of BINARY and ARGS variables
if [ -v BINARY ]; then
    [ ! -z "$BINARY" -a ! -z "$1" -a "$BINARY" != "$1" ] && { echo "FATAL: runner-script.sh: can't handle different binary names from different sources: BINARY env. and an argument."; exit 1; }
    [ -z "$BINARY" ] && BINARY="$RUNNER_SCRIPT_DEFAULT_BINARY"
else
    BINARY="$RUNNER_SCRIPT_DEFAULT_BINARY"
fi
[ -z "$1" ] || { BINARY="$1"; shift; }

# uncomment for verbose debugging
#printenv >& PRINTENV.$(basename $BINARY).$SLURM_JOBID.$OMPI_COMM_WORLD_RANK
#exec 1>AFFINITY.$(basename $BINARY).$SLURM_JOBID.$OMPI_COMM_WORLD_RANK
#exec 2>&1
#set -x

ARGS="$*"
[ -z "$ARGS" ] && ARGS="$RUNNER_SCRIPT_DEFAULT_ARGS"
##-- End of definition of BINARY and ARGS variables


omit_numactl=0
omit_nvidia_mps=1

export local_rank=$OMPI_COMM_WORLD_LOCAL_RANK
export global_rank=$OMPI_COMM_WORLD_RANK
export local_ppn=$OMPI_COMM_WORLD_LOCAL_SIZE
export local_ngpus=$SLURM_GPUS_ON_NODE

[ "$local_ngpus" == "0" ] &&  { echo "AFFINITY: local_ngpus=0: the SLURM_GPUS_ON_NODE=$SLURM_GPUS_ON_NODE -- no gpus in the SLURM allocation?"; exit 1; }

# Fill in the "threads for rank" array
threads=()
ncrs=20
nsckts=4
case "$local_ppn" in
1|2|4)   for _ in $(seq "$local_ppn"); do 
             threads+=($ncrs); 
         done
         ;;
8|16|20|32|40|80) thrds=$(($ncrs * $nsckts / "$local_ppn")); 
         for _ in $(seq "$local_ppn"); do 
             threads+=($thrds); 
         done; 
         omit_nvidia_mps=0   # NOTE: we switch on MPS usage here
         ;;
0)       echo -ne "AFFINITY: ppn=0 detected: SLURM_NPROCS=$SLURM_NPROCS, "
         echo -ne "SLURM_JOB_NUM_NODES=$SLURM_JOB_NUM_NODES, "
         echo -ne "OMPI_COMM_WORLD_LOCAL_SIZE=$OMPI_COMM_WORLD_LOCAL_SIZE"
         echo -ne "\n"
         printenv | grep SLURM_
         exit 1
         ;;
*)       [ "$local_ppn" -gt "$local_ngpus" ] && omit_nvidia_mps=0 # NOTE: we switch on MPS usage here
         omit_numactl=1
         ;;
esac

# Fill in the "physical cores per rank" array based on threads() array
physcores=()
sum=0
for i in "${threads[@]}"; do
    j=$(echo "${sum}-$(($sum + $i - 1))")
    physcores+=($j)
    sum=$(($sum + $i))
done

# Fill in the NICs array
nics=(mlx5_0:1 mlx5_1:1 mlx5_4:1 mlx5_5:1)

# Which GPU device is local to us?
divider=$(expr "$local_ppn" / "$local_ngpus")
[ "$divider" == "0" ] && divider=1
export local_device_id=$(($local_rank / $divider))

export OMP_PROC_BIND=close
export OMP_PLACES=cores
nthr=1
[ -v threads ] && nthr=${threads[$local_rank]}
[ -z "$OMP_NUM_THREADS" -a "$omit_numactl" == 0 ] && export OMP_NUM_THREADS=$nthr
[ ! -z "$OMP_NUM_THREADS" -a "$OMP_NUM_THREADS" -gt "$nthr" ] && echo "AFFINITY: WARNING: OMP_NUM_THREADS>$nthr with ppn=$local_ppn may lead to oversubscription"

export CUDA_VISIBLE_DEVICES="$local_device_id"
export UCX_NET_DEVICES="${nics[$local_device_id]}"
export NVCOMPILER_ACC_DEFER_UPLOADS=1
export OMPI_MCA_coll_ucc_enable=0
export OMPI_MCA_hcoll_ucc_enable=0
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl="^vader,tcp,openib,smcuda"

function stop-nvidia-mps() {
  [ "$local_rank" == 0 -a "$omit_nvidia_mps" == 0 ] && sleep 5 && echo quit | nvidia-cuda-mps-control || true
}

function kill-nvidia-mps() {
    if pgrep nvidia-cuda-mps >& /dev/null; then
        [ "$local_rank" == 0 ] && echo quit | nvidia-cuda-mps-control || true
        sleep 5
        [ "$local_rank" == 0 ] && killall nvidia-cuda-mps 2>/dev/null || true
        timeout 10 bash -c 'while pgrep nvidia-cuda-mps >/dev/null; do sleep 0.5; done' || true
    fi
}

function start-nvidia-mps() {
    [ "$local_rank" == 0 -a "$omit_nvidia_mps" == 0 ] && env -u CUDA_VISIBLE_DEVICES nvidia-cuda-mps-control -d || true
    [ "$local_rank" != 0 -a "$omit_nvidia_mps" == 0 ] && timeout 20 bash -c 'until pgrep nvidia-cuda-mps >/dev/null; do sleep 0.5; done'
}

export CUDA_MPS_LOG_DIRECTORY=$PWD
kill-nvidia-mps
trap stop-nvidia-mps EXIT
start-nvidia-mps

numactlline=""
[ "$omit_numactl" == 0 ] && numactlline="numactl -l --all --physcpubind=${physcores[$local_rank]} --"

if [ -v PROFILE ]; then
    export PROFILE
    [ "$global_rank" == 0 ] && echo ">> runner-script.sh: executing: $numactlline ./profiling-wrapper.sh $BINARY $ARGS"
    $numactlline ./profiling-wrapper.sh $BINARY $ARGS
else
    [ "$global_rank" == 0 ] && echo ">> runner-script.sh: executing: $numactlline $BINARY $ARGS"
    $numactlline $BINARY $ARGS
fi

