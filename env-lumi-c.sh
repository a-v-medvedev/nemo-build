#!/bin/bash

function env_init_global {
    echo "=== Specific Environment settings for 'LUMI-C' host ==="
    script=$(mktemp .XXXXXX.sh)
cat > $script << 'EOM'

module load LUMI/23.03 partition/C PrgEnv-cray/8.3.3 craype-x86-milan cce/14.0.2 cray-fftw/3.3.10.1 cray-hdf5/1.12.1.5 cray-netcdf/4.8.1.5

export FC=ftn

export MAKE_PARALLEL_LEVEL=1

export PSUBMIT_OPTS_NNODES=1
export PSUBMIT_OPTS_PPN=64
export PSUBMIT_OPTS_NGPUS=8
export PSUBMIT_OPTS_QUEUE_NAME=small
export PSUBMIT_OPTS_TIME_LIMIT=10
export PSUBMIT_OPTS_ACCOUNT=project_465000454
export PSUBMIT_OPTS_INIT_COMMANDS='"module load PrgEnv-cray/8.3.3 craype-x86-milan cce/14.0.2 cray-fftw/3.3.10.1 cray-hdf5/1.12.1.5 cray-netcdf/4.8.1.5"'
export PSUBMIT_OPTS_INJOB_INIT_COMMANDS='"export LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH"'
export PSUBMIT_OPTS_MPI_SCRIPT=cmpi
export PSUBMIT_OPTS_BATCH_SCRIPT=slurm

export PSUBMIT_OPTS_DIRECT_OVERSUBSCRIBE_LEVEL=4

export DNB_NOCUDA=1
export DNB_NOCMAKE=1
export DNB_NOCCOMP=1
export DNB_NOCXXCOMP=1

export NEMO_USE_PREBUILD_PREREQS=TRUE
export DEFAULT_BUILD_MODE=":ubi"

export PACKAGE_VERSIONS="nemo:DE340"
export NEMO_CFG="ORCA2"
export NEMO_SUBCOMPONENTS="OCE ICE"
export NEMO_KEYS_TO_DELETE="key_top"
export NEMO_KEYS_TO_ADD="key_asminc key_netcdf4 key_sms key_xios2"

#export PACKAGE_VERSIONS="nemo:4.0.7"
#export NEMO_CFG="ORCA2"
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
    local necdf_path=""
    local hdf5_path=""
    if [ ! -z "$NEMO_USE_PREBUILD_PREREQS" ]; then
    	necdf_path="/opt/cray/pe/netcdf/4.8.1.5/crayclang/14.0"
    	hdf5_path="/opt/cray/pe/hdf5/1.12.1.5/crayclang/14.0"
    fi

    case "$name" in
    netcdf-c)
        # put here any specific env. setting before scotch build
    ;;
    netcdf-fortran)
        # put here any specific env. setting before yaml-cpp build
    ;;
    xios)
        export XIOS_HDF5_PATH="$hdf5_path"
        export XIOS_NETCDF_C_PATH="$necdf_path"
        export XIOS_NETCDF_FORTRAN_PATH="$necdf_path"
	export XIOS_MAKE_PARALLEL_LEVEL="1"
        export XIOS_CCOMPILER="mpicc"
        export XIOS_FCOMPILER="mpif90"
        export XIOS_LINKER="mpif90"
        export XIOS_CFLAGS="-std=c++03 -O3 -D BOOST_DISABLE_ASSERTS"
        export XIOS_CPP="mpicc -EP"
        export XIOS_FPP="cpp -P"
    ;;
    nemo)
        export NEMO_HDF5_PATH="$hdf5_path"
        export NEMO_NETCDF_C_PATH="$necdf_path"
        export NEMO_NETCDF_FORTRAN_PATH="$necdf_path"
        export NEMO_XIOS_PATH="$INSTALL_DIR/xios.bin"
        export NEMO_CPP="cpp"
        export NEMO_CC="gcc"
        export NEMO_FC="mpif90"
        export NEMO_FCFLAGS="-O3"
        export NEMO_LDFLAGS="-lstdc++"
        export NEMO_FPPFLAGS="-P -traditional -I/opt/cray/pe/mpich/8.1.23/ofi/cray/10.0/include"
    ;;
    esac
    return 0
}

