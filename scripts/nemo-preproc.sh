#!/bin/bash

[ -z "$PSUBMIT_ARGS" ] || BINARY="$PSUBMIT_ARGS"

export RUNNER_SCRIPT_DEFAULT_BINARY="./nemo"
export RUNNER_SCRIPT_DEFAULT_ARGS=""

default_workload_name=ORCA2-generic
[ -d "$default_workload_name" ] || default_workload_name="eORCA1-debug"
[ -z "$NEMO_WORKLOAD_NAME" ] && NEMO_WORKLOAD_NAME="$default_workload_name"

NEMO_TESTBED_DIR=nemo_testbed_${PSUBMIT_JOBID}
[ -d "$NEMO_TESTBED_DIR" ] && rm -rf "$NEMO_TESTBED_DIR"
mkdir -p $NEMO_TESTBED_DIR
binary=${BINARY:=$RUNNER_SCRIPT_DEFAULT_BINARY}
NEMO_EXE_FILES=$(ls -1d *.sh $binary lib gdb.cmd hostfile.${PSUBMIT_JOBID} 2>/dev/null)
for i in ${NEMO_EXE_FILES}; do 
    [ -e $i ] && ln -sf ../$i ${NEMO_TESTBED_DIR}
done
NEMO_INPUT_FILES=$(ls -1d $NEMO_WORKLOAD_NAME/data/*.dat $NEMO_WORKLOAD_NAME/data/*.nc $NEMO_WORKLOAD_NAME/data/*.xml $NEMO_WORKLOAD_NAME/data/*_cfg $NEMO_WORKLOAD_NAME/data/*_ref $NEMO_WORKLOAD_NAME/data/*.in $NEMO_WORKLOAD_NAME/data/namelistfc* $NEMO_WORKLOAD_NAME/data/forcings 2>/dev/null)
for i in ${NEMO_INPUT_FILES}; do 
    [ -e $i ] && ln -sf ../$i ${NEMO_TESTBED_DIR}
done

cd ${NEMO_TESTBED_DIR}
[ -z "$NSTEPS" ] && NSTEPS=8
[ -z "$MASSIVE_TESTS_TESTITEM_WPRT_PARAM" ] || NSTEPS=$MASSIVE_TESTS_TESTITEM_WPRT_PARAM
if [ -e "namelist_cfg" ]; then
    new_namelist=namelist_cfg.${PSUBMIT_JOBID}
    cat namelist_cfg > $new_namelist
    sed -i "s/nn_itend[ \t]*=.*/nn_itend=$NSTEPS/" $new_namelist
    rm namelist_cfg && cp $new_namelist namelist_cfg
fi

export OMP_NUM_THREADS=$PSUBMIT_NTH

if [ ! -z "$MASSIVE_TESTS_TESTITEM_WLD" ]; then
    echo ">> OMP_NUM_THREADS = " $OMP_NUM_THREADS
    echo ">> NSTEPS = " $NSTEPS
    echo ">> NNODES = " $(expr $PSUBMIT_NP / $PSUBMIT_PPN)
    echo ">> PPN = " $PSUBMIT_PPN
    echo ">> WLD = " $MASSIVE_TESTS_TESTITEM_WLD
    echo ">> WPRT = " $MASSIVE_TESTS_TESTITEM_WPRT
fi

