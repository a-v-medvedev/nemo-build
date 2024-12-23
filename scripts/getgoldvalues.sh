#!/bin/bash

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

function get_nth_array_element() {
    local n="$1"
    local array="$2"
    echo "$array" | awk -v "N=$n" -F '[\\[\\], ]+' '{ N+=2; if (N<=NF) print $N }'
}

function print_general() {
    echo "        execution/success: true"
    echo "        execution/error_in_ocean_output: false"
    echo "        execution/ocean_output_per_rank_exists: false"
    echo "        model/last_step: " $NSTEPS
}

function print_norms() {
    variable_name="$1"
    for i in $(seq 0 1 $(expr "$NSTEPS" - 1)); do 
#        echo ">>>>> model__${variable_name} --- $(eval echo \$model__${variable_name})"
        echo "        model/${variable_name}[$i]: " $(get_nth_array_element $i "$(eval echo \$model__${variable_name})")
    done
}

function check_sanity() {
    [ "$execution__success" == "true" ] || return 1
    [ "$execution__error_in_ocean_output" == "false" ] || return 1
    [ "$execution__ocean_output_per_rank_exists" == "false" ] || return 1
    [ "$model__last_step" == "$NSTEPS" ] || return 1
    return 0
}

#echo ">> OMP_NUM_THREADS = " $OMP_NUM_THREADS
#echo ">> NSTEPS = " $NSTEPS
#echo ">> NNODES = " $(expr $PSUBMIT_NP / $PSUBMIT_PPN)
#echo ">> PPN = " $PSUBMIT_PPN


function get_key_from_psubmit_output() {
    local psubmit_out_file="$1"
    local key="$2"
	cat "$psubmit_out_file" | grep ">> $key = " | awk '{print $4}'
}

function get_wld_conf_from_psubmit_output() {
    local psubmit_out_file="$1"
	local optim=false
	local repro=false
	cat "$psubmit_out_file" | grep runner-script.sh | grep -q optim && optim=true
	cat "$psubmit_out_file" | grep runner-script.sh | grep -q repro && repro=true
	[ "$optim" == "true" ] && { echo OPTIM; return 0; }
	[ "$repro" == "true" ] && { echo REPRO; return 0; }
	return 1;
}


#function get_exec_arg() {
#    local psubmit_out_file="$1"
#    local key="$2"
#    cat "$psubmit_out_file" | grep mpirun | awk -v "KEY=$key" '{ for (i=1;i<NF;i++) { if ($i==KEY) {++i; print $i; } } }'
#}

function check_if_already_printed() {
    local value="$1"
    value_as_string=$(echo $value | sed 's/\./_/g;s/\+/_/g;s/-/_/g')
    was_already_printed=$(eval echo \${printed_${value_as_string}})
    [ -z "$was_already_printed" ] || return 0
    eval printed_${value_as_string}=1
 	return 1
}

N=$(ls -1 results.*/result*.yaml 2>/dev/null | wc -l)
[ "$N" == "0" ] && exit 0
for i in results.*/result*.yaml; do
    ps=$(echo $i | sed 's!/result.!/psubmit_wrapper_output.!;s/\.yaml$//')
	NNODES=$(get_key_from_psubmit_output "$ps" "NNODES")
	PPN=$(get_key_from_psubmit_output "$ps" "PPN")
	NTH=$(get_key_from_psubmit_output "$ps" "OMP_NUM_THREADS")
	[ "$NNODES" == 1 ] || continue
	[ "$PPN" == 8 ] || continue
	[ "$NTH" == 1 ] || continue
	WLD=$(get_key_from_psubmit_output "$ps" "WLD")
	WLD_CONF=$(get_wld_conf_from_psubmit_output "$ps")
	WPRT=$(get_key_from_psubmit_output "$ps" "WPRT")
	NSTEPS=$(get_key_from_psubmit_output "$ps" "NSTEPS")
    [ ! -z "$1" -a "$WLD" != "$1" ] && continue
	[ -z "$WLD_CONF" ] && { echo "WARNING: neither OPTIM or REPRO configuration ($i)."; continue; }
    VALS=$(parse_yaml "$i")
    eval $VALS

    check_sanity || continue
    ctrl_value=$(get_nth_array_element 7 "$(eval echo \$model__${model__ssh_norm_max})")
    check_if_already_printed ${ctrl_value} && continue
    
    echo "# from: " $i
    echo "${WLD}/${WLD_CONF}/${WPRT}:"
    echo "    values:"
    print_general
    print_norms ssh_norm_max
    print_norms U_norm_max
    print_norms S_min
    print_norms S_max
    echo
done
