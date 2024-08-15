# vi: syntax=sh

set +u
[ -z "$NEMO_CODEBASE" ] && NEMO_CODEBASE="COMMUNITY_4.0"
set -u

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
    true;
    # Settings for github version of NEMO (5.0 versions)
    # TBD
fi


