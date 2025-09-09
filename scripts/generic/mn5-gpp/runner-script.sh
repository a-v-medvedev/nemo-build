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

[ ! -z "$BINARY" -a ! -z "$1" -a "$BINARY" != "$1" ] && { echo "FATAL: can't handle different binary names from different sources: BINARY env. and an argument."; exit 1; }
[ -z "$BINARY" ] && BINARY="$RUNNER_SCRIPT_DEFAULT_BINARY"
[ -z "$1" ] || { BINARY="$1"; shift; }

ARGS="$*"
[ -z "$ARGS" ] && ARGS="$RUNNER_SCRIPT_DEFAULT_ARGS"

export local_rank=$PMI_RANK

#[ "$OMP_NUM_THREADS" != 1 ] && export OMP_NUM_THREADS=${threads[$local_rank]}
export OMP_PROC_BIND=close
export OMP_PLACES=cores

mpiexec=$(basename $MPIEXEC | awk -F'[-.]' '$1=="mpiexec" {print $2}')
if [ "$mpiexec" == "impi" ]; then
    [ -v I_MPI_PIN ] || export I_MPI_PIN=1
    [ -v I_MPI_PIN_DOMAIN ] || export I_MPI_PIN_DOMAIN=core
fi

if [ -v PROFILE ]; then
    export PROFILE
    [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: ./profiling-wrapper.sh $BINARY $ARGS"
    ./profiling-wrapper.sh $BINARY $ARGS
else
    [ "$local_rank" == 0 ] && echo ">> runner-script.sh: executing: $BINARY $ARGS"
    $BINARY $ARGS
fi


