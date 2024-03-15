#!/bin/bash

function env_init_global {
    echo "=== Specific Environment settings for 'mn4' host ==="
    script=$(mktemp .XXXXXX.sh)
cat > $script << 'EOM'

module load gcc/7.2.0 intel/2021.4 impi/2018.3 mkl/2021.4 netcdf/4.4.1.1 hdf5/1.8.19 perl/5.26

export FC=ifort

export MAKE_PARALLEL_LEVEL=48

export PSUBMIT_OPTS_NNODES=1
export PSUBMIT_OPTS_PPN=6
export PSUBMIT_OPTS_NTH=8
export PSUBMIT_OPTS_NGPUS=0
export PSUBMIT_OPTS_QUEUE_NAME=
export PSUBMIT_OPTS_TIME_LIMIT=10
export PSUBMIT_OPTS_NODETYPE=debug
export PSUBMIT_OPTS_RESOURCE_HANDLING=qos
export PSUBMIT_OPTS_INIT_COMMANDS='"module load gcc/7.2.0 intel/2021.4 impi/2018.3 mkl/2021.4 netcdf/4.4.1.1 hdf5/1.8.19"'
export PSUBMIT_OPTS_INJOB_INIT_COMMANDS='"export LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH"'
export PSUBMIT_OPTS_MPI_SCRIPT=impi
export PSUBMIT_OPTS_BATCH_SCRIPT=slurm

# We normally don't download source code -- do download phase separately as: "./dnb.sh :d"
# This is because MN4 nodes have no internet access
export DEFAULT_BUILD_MODE=":ubi"

[ -e "nemo-build.inc" ] || { echo "FATAL: nemo-build.inc symlink is required"; exit 1; } 
source nemo-build.inc

# NOTE: if the probuilt flag is set to FALSE, the project will be downloaded and built
export NEMO_USE_PREBUILT_HDF5=TRUE
export NEMO_USE_PREBUILT_NETCDF_C=TRUE
export NEMO_USE_PREBUILT_NETCDF_FORTRAN=TRUE
export NEMO_USE_PREBUILT_XIOS=FALSE
export NEMO_HDF5_PATH="/apps/HDF5/1.8.19/INTEL/IMPI"
export NEMO_NETCDF_C_PATH="/apps/NETCDF/4.4.1.1/INTEL/IMPI"
export NEMO_NETCDF_FORTRAN_PATH="/apps/NETCDF/4.4.1.1/INTEL/IMPI"

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
        # put here any specific env. setting before netcdf-c build
    ;;
    netcdf-fortran)
        # put here any specific env. setting before netcdf-fortran build
    ;;
    xios)
        module unload gcc/7.2.0
        module load intel/2021.4
        export XIOS_MAKE_PARALLEL_LEVEL="$MAKE_PARALLEL_LEVEL"
        export XIOS_CCOMPILER="mpicc"
        export XIOS_FCOMPILER="mpif90"
        export XIOS_LINKER="mpif90 -nofor-main"
        export XIOS_CFLAGS="-std=c++03 -O3 -D BOOST_DISABLE_ASSERTS"
        export XIOS_CPP="mpicc -EP"
        export XIOS_FPP="cpp -P"
    ;;
    nemo)
        export NEMO_CPP="cpp"
        export NEMO_CC="icc"
        export NEMO_FC="mpiifort"
        export NEMO_FCFLAGS="-r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays -fopenmp"
        export NEMO_LDFLAGS="-lstdc++ -fopenmp"
        # Note: to get the MPI includes path, run mpicc -showme
        export NEMO_FPPFLAGS="-P -traditional -I/apps/INTEL/2018.3.051/impi/2018.3.222/intel64/include"
    ;;
    esac
    return 0
}

