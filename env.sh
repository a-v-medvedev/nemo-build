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
export PSUBMIT_OPTS_QUEUE_NAME=debug
export PSUBMIT_OPTS_INIT_COMMANDS='module load gcc/7.2.0 intel/2021.4 impi/2018.3 mkl/2021.4'
export PSUBMIT_OPTS_INJOB_INIT_COMMANDS='export LD_LIBRARY_PATH=lib:$LD_LIBRARY_PATH'
export PSUBMIT_OPTS_MPI_SCRIPT=impi
export PSUBMIT_OPTS_BATCH_SCRIPT=slurm

export PSUBMIT_OPTS_DIRECT_OVERSUBSCRIBE_LEVEL=4

export DNB_NOCUDA=1
export DNB_NOCMAKE=1
export DNB_NOCCOMP=1
export DNB_NOCXXCOMP=1
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
	export NEMO_CPP="cpp"
	export NEMO_CC="icc"
        export NEMO_FC="mpiifort"
        export NEMO_FCFLAGS="-r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays"
        export NEMO_LDFLAGS="-lstdc++"
        export NEMO_FPPFLAGS="-P -traditional"
#%CPP                 cpp
#%NCDF_INC            -I/apps/NETCDF/4.4.1.1/INTEL/IMPI/include
#%NCDF_LIB            -L/apps/NETCDF/4.4.1.1/INTEL/IMPI/lib -lnetcdf -lnetcdff

#%XIOS_DIR            /gpfs/scratch/bsc32/bsc32402/a4y2/precisionoptimizationworkflow4nemo/xios_sources/trunk
#%XIOS_INC            -I%XIOS_DIR/inc
#%XIOS_LIB            -L%XIOS_DIR/lib -lxios -lstdc++

#%FC                  mpiifort
#%CC                  icc
#%CFLAGS              -O3
#%FCFLAGS             -r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays
#%FFFLAGS             %FCFLAGS
#%LD                  mpiifort
#%FPPFLAGS            -P -traditional
#%LDFLAGS             -lstdc++
#%AR                  ar
#%ARFLAGS             -r
#%MK                  gmake
#%USER_INC            %NCDF_INC %XIOS_INC  %RPE_INC
#%USER_LIB            %NCDF_LIB %XIOS_LIB  %RPE_LIB
        # put here any specific env. setting before scotch build
    ;;
    esac
    return 0
}

