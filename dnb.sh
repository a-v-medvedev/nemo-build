#!/bin/bash

source dbscripts/includes.inc
source dbscripts/apps-nemo.inc

function dnb_sandbox() {
    i_mksandbox
    cd sandbox

    for wld in $NEMO_AVAILABLE_WORKLOADS; do
        case "$wld" in
        ORCA2-generic)
            [ -e "$wld/scripts" -a -e "$wld/data" ] && continue
            [ -e "$HOME/data/$wld" ] || fatal "workload $wld is selected, but there is no directory $HOME/data/$wld"
            ln -s $HOME/data/$wld $wld
            ;;
        *) fatal "Unknown workload name in NEMO_AVAILABLE_WORKLOADS" 
            ;;
            esac
    done
 
    cd $DNB_SANDBOX
    cp -r $DNB_INSTALL_DIR/nemo.bin/[^_]* .
    mkdir -p lib
    [ -e "$DNB_INSTALL_DIR/hdf5.bin/lib" ] && cp -a $DNB_INSTALL_DIR/hdf5.bin/lib/* lib
    [ -e "$DNB_INSTALL_DIR/netcdf-c.bin/lib" ] && cp -a $DNB_INSTALL_DIR/netcdf-c.bin/lib/* lib
    [ -e "$DNB_INSTALL_DIR//netcdf-fortran.bin/lib" ] && cp -a $DNB_INSTALL_DIR/netcdf-fortran.bin/lib/* lib

    [ -z "$NEMO_SCRIPTS_FOLDER" ] && fatal "NEMO_SCRIPTS_FOLDER is not set"
    DNB_MACHINE_SCRIPTS_FOLDER="$NEMO_SCRIPTS_FOLDER"
    i_copy_scripts
    generate_psubmit_opt
    cd $DNB_INSTALL_DIR
    i_copy_scal_scripts
}

source dbscripts/yaml-config.inc
