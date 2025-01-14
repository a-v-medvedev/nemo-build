# vi: syntax=sh

[ -v NEMO_CODEBASE ] || export NEMO_CODEBASE="COMMUNITY_4.0"

if [ "$NEMO_CODEBASE" == "COMMUNITY_4.0" ]; then
    # Settings for SVN version of NEMO (4.0 versions)
    export NEMO_CFG="ORCA2"
    export NEMO_SUBCOMPONENTS="OCE ICE"
    export NEMO_KEYS_TO_DELETE="key_top"
    export NEMO_KEYS_TO_ADD="key_netcdf4 key_mpp_mpi key_iomput"
    export NEMO_WORKLOAD_ARCHIVE="ORCA2_ICE_v4.0.tar"
    export NEMO_WORKLOAD_MD5="fe6c0c2ae1d4fb42b30578646536615f"
elif [ "$NEMO_CODEBASE" == "COMMUNITY_4.2" ]; then
    true;
    # Settings for github version of NEMO (4.2 versions)
    # TBD
elif [ "$NEMO_CODEBASE" == "COMMUNITY_5.0" ]; then
    # Settings for github version of NEMO (5.0 versions)
    export NEMO_SRC_URL="https://forge.nemo-ocean.eu/nemo/nemo.git"
    export NEMO_WORKLOAD_URL="https://gws-access.jasmin.ac.uk/public/nemo/sette_inputs/r5.0.0"
    export NEMO_CFG="ORCA2"
    export NEMO_SUBCOMPONENTS="OCE ICE"
    export NEMO_KEYS_TO_DELETE="key_top"
    export NEMO_KEYS_TO_ADD="bld::tool::fppkeys key_si3 key_xios key_qco key_vco_1d3d"
    is_set_to_true NEMO_WITH_RK3 && NEMO_KEYS_TO_ADD="$NEMO_KEYS_TO_ADD key_RK3"
    is_set_to_true NEMO_WITH_RK3 || NEMO_KEYS_TO_DEL="$NEMO_KEYS_TO_DEL key_RK3"
    export NEMO_WORKLOAD_ARCHIVE="ORCA2_ICE_v5.0.0.tar.gz"
    export NEMO_WORKLOAD_MD5="872eea51f22c5dabaffd268c0220eba6"
else
    echo "Unknown value for NEMO_CODEBASE"
    exit 1
fi


