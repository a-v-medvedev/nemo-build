#!/bin/bash

function env_init_global {
    echo "=== Specific Environment settings for 'mn4' host ==="
    script=$(mktemp .XXXXXX.sh)
cat > $script << 'EOM'

module load gcc/7.2.0 intel/2021.4 impi/2018.3 mkl/2021.4 netcdf/4.4.1.1 hdf5/1.8.19 perl/5.26

export FC=ifort

export MAKE_PARALLEL_LEVEL=4

export PSUBMIT_OPTS_NNODES=1
export PSUBMIT_OPTS_PPN=48
export PSUBMIT_OPTS_NGPUS=0
export PSUBMIT_OPTS_QUEUE_NAME=
export PSUBMIT_OPTS_TIME_LIMIT=10
export PSUBMIT_OPTS_NODETYPE=debug
export PSUBMIT_OPTS_RESOURCE_HANDLING=qos
export PSUBMIT_OPTS_INIT_COMMANDS='"module load gcc/7.2.0 intel/2021.4 impi/2018.3 mkl/2021.4"'
export PSUBMIT_OPTS_INJOB_INIT_COMMANDS='"export LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH"'
export PSUBMIT_OPTS_MPI_SCRIPT=impi
export PSUBMIT_OPTS_BATCH_SCRIPT=slurm

export PSUBMIT_OPTS_DIRECT_OVERSUBSCRIBE_LEVEL=4

export DNB_NOCUDA=1
export DNB_NOCMAKE=1
export DNB_NOCCOMP=1
export DNB_NOCXXCOMP=1

export NEMO_USE_PREBUILD_PREREQS=TRUE
export DEFAULT_BUILD_MODE=":ubi"

export PACKAGE_VERSIONS="nemo:DE340"
export NEMO_CFG="ORCE2"
export NEMO_SUBCOMPONENTS="OCE ICE"
export NEMO_KEYS_TO_DELETE="key_top"
export NEMO_KEYS_TO_ADD="key_asminc key_netcdf4 key_sms"

#export PACKAGE_VERSIONS="nemo:4.0.7"
#export NEMO_CFG="ORCE2"
#export NEMO_SUBCOMPONENTS="OCE"
#export NEMO_KEYS_TO_DELETE="key_top key_si3 key_iomput"
#export NEMO_KEYS_TO_ADD="key_netcdf4"

EOM
    . $script
    cat $script
    rm $script
    echo "============================================================"
}


function env_init {
    local name="$1"
    case "$name" in
    netcdf-c)
        # put here any specific env. setting before scotch build
    ;;
    netcdf-fortran)
        # put here any specific env. setting before yaml-cpp build
    ;;
    XIOS)
        # put here any specific env. setting before silo build
    ;;
    nemo)
        export NEMO_NETCDF_C_PATH="/apps/NETCDF/4.4.1.1/INTEL/IMPI"
        export NEMO_NETCDF_FORTRAN_PATH="/apps/NETCDF/4.4.1.1/INTEL/IMPI"
        export NEMO_CPP="cpp"
        export NEMO_CC="icc"
        export NEMO_FC="mpiifort"
        export NEMO_FCFLAGS="-r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays"
        export NEMO_LDFLAGS="-lstdc++"
        export NEMO_FPPFLAGS="-P -traditional -I/apps/INTEL/2018.3.051/impi/2018.3.222/intel64/include -I/apps/INTEL/2018.3.051/impi/2018.3.222/intel64/include"
    ;;
    esac
    return 0
}

