!/bin/bash

[ -z "$PSUBMIT_ARGS" ] || BINARY="$PSUBMIT_ARGS"

export RUNNER_SCRIPT_DEFAULT_BINARY="./nemo"
export RUNNER_SCRIPT_DEFAULT_ARGS=""

subdir=${PSUBMIT_SUBDIR:-"."}

binary=${BINARY:=$RUNNER_SCRIPT_DEFAULT_BINARY}
export NEMO_IS_NEMO5=FALSE
binary_for_nm="$subdir/$binary"
if [ ! -e "$binary_for_nm" ] ; then
    binary_for_nm=$(basename "$binary_for_nm")
    [ -e "$binary_for_nm" ] || echo "WARNING: can't find a binary: $binary_for_nm"
fi
nm "$binary_for_nm" | grep -q lbc_lnk_neicoll && export NEMO_IS_NEMO5=TRUE

default_workload_name=eORCA1-debug
[ "$NEMO_IS_NEMO5" == TRUE ] && default_workload_name=ORCA2-generic
[ -v NEMO_DEFAULT_WORKLOAD ] && default_workload_name=$NEMO_DEFAULT_WORKLOAD
[ -d "$default_workload_name" ] || default_workload_name="eORCA1-spinup"
[ -z "$NEMO_WORKLOAD_NAME" ] && NEMO_WORKLOAD_NAME="$default_workload_name"
[ -d "$NEMO_WORKLOAD_NAME" ] || { echo "FATAL: workload directory \"$NEMO_WORKLOAD_NAME\" does not exist"; exit 1; }

NEMO_TESTBED_DIR=nemo_testbed_${PSUBMIT_JOBID}
[ -d "$NEMO_TESTBED_DIR" ] && rm -rf "$NEMO_TESTBED_DIR"
mkdir -p $NEMO_TESTBED_DIR
NEMO_EXE_FILES=$(ls -1d $subdir/*.sh $subdir/$binary lib gdb.cmd hostfile.${PSUBMIT_JOBID} 2>/dev/null)
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
    sed -i 's/nn_stock[ \t]*=.*/nn_stock = -1/' $new_namelist
    sed -i 's/nn_stocklist[ \t]*=.*/nn_stocklist = -9999/' $new_namelist
    sed -i 's/ln_timing[ \t]*=.*$/ln_timing = .true./' $new_namelist
    sed -i '/ln_timing_detail[ \t]*=.*$/d' $new_namelist
    sed -i '/sn_cfctl%l_runstat[ \t]*=.*$/d' $new_namelist
    # NOTE: timing_detail is for NEMO4 only
    if [ "$NEMO_IS_NEMO5" == "TRUE" ]; then
        sed -i 's/ln_timing[ \t]*=.*$/&\nsn_cfctl%l_runstat = .true./' $new_namelist
    else
        sed -i 's/ln_timing[ \t]*=.*$/&\nln_timing_detail = .true.\nsn_cfctl%l_runstat = .true./' $new_namelist
    fi
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


