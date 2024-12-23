#!/bin/bash

function array_to_yaml_array() {
    local array=($*)
    oldIFS=$IFS
    echo -n "[ "
    IFS=","; echo -n "${array[*]}" | sed 's/,/, /g;s/D/e/g';
    IFS=$oldIFS
    echo -n " ]"
}

function nfiles_by_mask() {
    local mask="$1"
    ls -1 $mask 2>/dev/null | wc -l
}

NEMO_TESTBED_DIR=nemo_testbed_${PSUBMIT_JOBID}

# FIXME in fact, we need an analysis of timeout and abnormal termination (signal?) cases
if [ -f "ocean.output" -a -f "run.stat" -a -f "time.step" ]; then
    success="true"
else
    success="false"
fi


ocean_output_per_rank_exists=false
[ $(nfiles_by_mask ocean.output_*) != "0" ] && ocean_output_per_rank_exists=true

laststep=0
if [ -f time.step ]; then
    nsteps=$(cat time.step | wc -l)
    if [ "$nsteps" -gt "0" ]; then
        laststep=$(tail -n1 time.step | sed 's/ //g')
    fi
fi

error_in_ocean_output="false"
if [ -f "ocean.output" ]; then
    grep -q 'E R R O R' ocean.output && error_in_ocean_output="true"
fi

ssh_norm_max=()
U_norm_max=()
S_min=()
S_max=()
if [ -f "run.stat" ]; then
    if [ "$laststep" != "0" ]; then
        for step in $(seq 1 1 "$laststep"); do
            # 5 7 9 11 -- ssh_norm_max U_norm_max S_min S_max
            value=$(cat run.stat | awk -vN=$step 'NR==N { if ($3==N) print $5 }')
            ssh_norm_max+=($value)
            value=$(cat run.stat | awk -vN=$step 'NR==N { if ($3==N) print $7 }')
            U_norm_max+=($value)
            value=$(cat run.stat | awk -vN=$step 'NR==N { if ($3==N) print $9 }')
            S_min+=($value)
            value=$(cat run.stat | awk -vN=$step 'NR==N { if ($3==N) print $11 }')
            S_max+=($value)
        done
    fi
fi

echo "---" > result.${PSUBMIT_JOBID}.yaml
echo "execution:" >> result.${PSUBMIT_JOBID}.yaml
echo "    success: $success" >> result.${PSUBMIT_JOBID}.yaml
echo "    error_in_ocean_output: $error_in_ocean_output" >> result.${PSUBMIT_JOBID}.yaml
echo "    ocean_output_per_rank_exists: $ocean_output_per_rank_exists" >> result.${PSUBMIT_JOBID}.yaml
echo "model:" >> result.${PSUBMIT_JOBID}.yaml
echo "    last_step: $laststep" >> result.${PSUBMIT_JOBID}.yaml
echo "    ssh_norm_max: $(array_to_yaml_array ${ssh_norm_max[@]})" >> result.${PSUBMIT_JOBID}.yaml
echo "    U_norm_max: $(array_to_yaml_array ${U_norm_max[@]})" >> result.${PSUBMIT_JOBID}.yaml
echo "    S_min: $(array_to_yaml_array ${S_min[@]})" >> result.${PSUBMIT_JOBID}.yaml
echo "    S_max: $(array_to_yaml_array ${S_max[@]})" >> result.${PSUBMIT_JOBID}.yaml

ice_dyn_adv_pra="ice_dyn_adv_pra ice_dyn_adv_pra_adv_x ice_dyn_adv_pra_adv_y ice_dyn_adv_pra_Hbig ice_dyn_adv_pra_icemax3D ice_dyn_adv_pra_icemax4D ice_var_zapneg ice_dyn_adv_pra_h2d ice_dyn_adv_pra_d2h ice_dyn_adv_pra_BLOCK_A ice_dyn_adv_pra_BLOCK_B ice_dyn_adv_pra_BLOCK_C ice_dyn_adv_pra_BLOCK_D ice_dyn_adv_pra_BLOCK_E ice_dyn_adv_pra_LBC_1 ice_dyn_adv_pra_LBC_2 ice_dyn_adv_pra_LBC_3 ice_dyn_adv_pra_LBC_4"

SUBROUTINES="sbc sbc_stokes icestp ice_dyn icedyn_rdgrft icedyn_adv icedyn_rhg ice_thd_main ice_thd_jllopp iceupdate_flx iceitd_rem icealb iceitd_reb ice_strengh icesbc ice_thd_do icethd icecor icewri iceupdate_tau dyn_ldf dyn_spg_ts dyn_zdf dia_wri tra_bbl tra_ldf_iso tra_zdf_imp dom_vvl_sf_swp"
# Averaged inclusive CPU time on all processors
echo "timing:" >> result.${PSUBMIT_JOBID}.yaml
echo "    elapsed_time:" >> result.${PSUBMIT_JOBID}.yaml
for sub in $SUBROUTINES; do
    if [ -e timing.output ]; then
        value=$(cat timing.output | awk -vSUB=$sub '/Averaged inclusive timing on all processors/ {start=1} /------------/{if (start) ++start; if (start == 3) start=0} start && $1==SUB {print int($2*1000000) }')
## Attempt of adaptation for NEMO 5:
##Timing : AVG values over all MPI processes:
        value=$(cat timing.output | awk -vSUB=$sub '/Timing : AVG values over all MPI processes:/ {start=1} /------------/{if (start) ++start; if (start == 4) start=0} start && $2==SUB {print int($3*1000000) }')
        [ -z "$value" ] && value=0
        echo "        ${sub}: $value" >> result.${PSUBMIT_JOBID}.yaml
    fi
done
echo "..." >> result.${PSUBMIT_JOBID}.yaml

# We don't submit the result.yaml if we understand that program didn't even run
# This will be shown as a NORES state as a test result
if [ -f "ocean.output" -o -f "run.stat" -o -f "time.step" ]; then
    mv result.${PSUBMIT_JOBID}.yaml ..
else
    rm result.${PSUBMIT_JOBID}.yaml
fi

FILES="layout.dat ocean.output output.namelist.dyn output.namelist.ice run.stat run.stat.nc time.step timing.output communication_report.txt"
for i in $FILES; do
    [ -e $i ] && mv -f $i ../${i}.${PSUBMIT_JOBID}
done
rm -f ocean.output_*
if [ "$(echo *${PSUBMIT_JOBID}*)" != "*${PSUBMIT_JOBID}*" ]; then
    for i in *${PSUBMIT_JOBID}*; do 
        [ -e ../$i ] || mv $i ..
    done
fi
cd ..
rm -rf ${NEMO_TESTBED_DIR}

pswrpout=psubmit_wrapper_output.${PSUBMIT_JOBID}
if [ -f $pswrpout ]; then
    if grep -q 'Caught signal' $pswrpout; then
        cat $pswrpout | awk '/==== backtrace \(/ && start == 1 { start=2; } /======/{print; start=0} /Caught signal/ {print ">> STATUS: CRASH"; print; start=1} start==2{print}' > stacktrace.${PSUBMIT_JOBID}
    fi
    if grep -q '>> STATUS: ASSERT' $pswrpout; then
        echo ">> STATUS: ASSERT" > stacktrace.${PSUBMIT_JOBID}
    fi
fi

