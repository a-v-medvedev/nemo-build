#!/bin/bash

DNB_DBSCRIPTSDIR=./dbscripts
DNB_YAML_CONFIG="dnb.yaml"

source $DNB_DBSCRIPTSDIR/includes.inc
source $DNB_DBSCRIPTSDIR/apps-nemo.inc

function dnb_sandbox() {
    mkdir -p sandbox
    cd sandbox
    cp -r ../nemo.bin/* .

    mkdir -p lib
    [ -e "../hdf5.bin/lib" ] && cp -a ../hdf5.bin/lib/* lib
    [ -e "../netcdf-c.bin/lib" ] && cp -a ../netcdf-c.bin/lib/* lib
    [ -e "../netcdf-fortran.bin/lib" ] && cp -a ../netcdf-fortran.bin/lib/* lib
    for i in ../scripts/*.sh; do
        rm -f $(basename $i)
        ln -s $i .
    done
    [ -z "$NEMO_SCRIPTS_FOLDER" ] && fatal "NEMO_SCRIPTS_FOLDER is not set"
    for i in ../scripts/generic/$NEMO_SCRIPTS_FOLDER/*.sh; do
        rm -f $(basename $i)
        ln -s $i .
    done
    generate_psubmit_opt "."
    cd $DNB_INSTALL_DIR
}

source "$DNB_DBSCRIPTSDIR/yaml-config.inc"
