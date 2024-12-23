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
    for i in ../scripts/*.sh ../scripts/*.awk; do
        rm -f $(basename $i)
        ln -s $i .
    done
#    [ -e "../scripts/nemo-postproc.sh" ] && { rm -f nemo-postproc.sh; ln -s ../scripts/nemo-postproc.sh .; }
#    [ -e "../scripts/nemo-preproc.sh" ] && { rm -f nemo-preproc.sh; ln -s ../scripts/nemo-preproc.sh .; }
#    [ -e "../scripts/compare.sh" ] && cp -a ../scripts/compare.sh .
#    [ -e "../scripts/cmp.sh" ] && cp -a ../scripts/cmp.sh .
#    [ -e "../scripts/scalability_table.sh" ] && ln -sf ../scripts/scalability_table.sh .
#    [ -e "../scripts/scalability_table_to_markdown.awk" ] && ln -sf ../scripts/scalability_table_to_markdown.awk .
#    [ -e "../scripts/scalability_table.sh" ] && ln -sf scripts/scalability_table.sh ..
    [ -z "$NEMO_SCRIPTS_FOLDER" ] && fatal "NEMO_SCRIPTS_FOLDER is not set"
    for i in ../scripts/$NEMO_SCRIPTS_FOLDER/*.sh; do
        rm -f $(basename $i)
        ln -s $i .
    done

#    [ -e "../scripts/$NEMO_SCRIPTS_FOLDER/interactive-run.sh" ] && cp -a ../scripts/$NEMO_SCRIPTS_FOLDER/interactive-run.sh .
#    [ -e "../scripts/$NEMO_SCRIPTS_FOLDER/runner-script.sh" ] && cp -a ../scripts/$NEMO_SCRIPTS_FOLDER/nemo-runner.sh .
#    [ -e "../scripts/$NEMO_SCRIPTS_FOLDER/profiling-wrapper.sh" ] && cp -a ../scripts/$NEMO_SCRIPTS_FOLDER/profiling-wrapper.sh .
    generate_psubmit_opt "."
    #sed -i 's/nn_itend[ ]*=.*/nn_itend=32/' namelist_cfg
    cd $DNB_INSTALL_DIR
}

source "$DNB_DBSCRIPTSDIR/yaml-config.inc"
