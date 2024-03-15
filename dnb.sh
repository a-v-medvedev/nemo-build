#!/bin/bash

BSCRIPTSDIR=./dbscripts

which module >& /dev/null || [ `type -t module`"" == 'function' ] || source $BSCRIPTSDIR/module.inc
[ -f ./env.sh ] && source ./env.sh || { echo "FATAL: no env.sh file found"; exit 1; }

source $BSCRIPTSDIR/base.inc
source $BSCRIPTSDIR/funcs.inc
source $BSCRIPTSDIR/compchk.inc
source $BSCRIPTSDIR/envchk.inc
source $BSCRIPTSDIR/db.inc
source $BSCRIPTSDIR/apps.inc
source $BSCRIPTSDIR/apps-nemo.inc

function dnb_sandbox() {
    mkdir -p sandbox
    cd sandbox
    cp -r ../nemo.bin/* .
    for i in *.gz; do gunzip -f $i; done
    mkdir -p lib
    [ -e "../netcdf-c.bin/lib" ] && cp -a ../netcdf-c.bin/lib/* lib
    [ -e "../netcdf-fortran.bin/lib" ] && cp -a ../netcdf-fortran.bin/lib/* lib
    cat > psubmit.opt.TEMPLATE <<EOF
QUEUE=__QUEUE__
NODETYPE=__NODETYPE__
RESOURCE_HANDLING=__RESOURCE_HANDLING__
ACCOUNT=__ACCOUNT__
PPN=__PPN__
NTH=__NTH__
TIME_LIMIT=__TIME_LIMIT__         
TARGET_BIN="./nemo"
JOB_NAME="NEMO_test_job"    
INIT_COMMANDS=__INIT_COMMANDS__
INJOB_INIT_COMMANDS=__INJOB_INIT_COMMANDS__
MPIEXEC=__MPI_SCRIPT__
BATCH=__BATCH_SCRIPT__  
EOF
    template_to_psubmitopts "." ""
    cd $INSTALL_DIR
}

####

# Avoid versions checks to make things faster
export DNB_NOCUDA=1
export DNB_NOCMAKE=1
export DNB_NOCCOMP=1
export DNB_NOCXXCOMP=1

started=$(date "+%s")
echo "Download and build started at timestamp: $started."
environment_check_main || fatal "Environment is not supported, exiting"

set +u
PACKAGES=nemo
is_set_to_true NEMO_USE_PREBUILT_XIOS || PACKAGES="xios $PACKAGES"
is_set_to_true NEMO_USE_PREBUILT_NETCDF_FORTRAN || PACKAGES="netcdf-fortran $PACKAGES"
is_set_to_true NEMO_USE_PREBUILT_NETCDF_C || PACKAGES="netcdf-c $PACKAGES"
is_set_to_true NEMO_USE_PREBUILT_HDF5 || PACKAGES="hdf5 $PACKAGES"

VERSIONS="nemo:4.0.7 hdf5:1.10.7 netcdf-fortran:4.4.3 netcdf-c:4.4.0 xios:2.5"
TARGET_DIRS="nemo.bin hdf5.bin netcdf-fortran.bin netcdf-c.bin xios.bin"

echo ">> Package list: $PACKAGES"

set -u

dubi_main "$*"
finished=$(date "+%s")
echo "----------"
echo "Full operation time: $(expr $finished - $started) seconds."

