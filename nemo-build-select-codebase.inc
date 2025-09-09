# vi: syntax=sh

NEMO_CODEBASE=${NEMO_CODEBASE:-"COMMUNITY_4.0"}

if [ "$NEMO_CODEBASE" == "COMMUNITY_4.0" ]; then
    # Settings for SVN (community) version of NEMO (4.0 versions)
    export NEMO_CFG="ORCA2"
    export NEMO_SUBCOMPONENTS="OCE"
    export NEMO_KEYS_TO_DELETE="key_top key_si3 key_iomput"
    export NEMO_KEYS_TO_ADD="key_netcdf4"
    export NEMO_WORKLOAD_ARCHIVE="ORCA2_ICE_v4.0.tar"
    export NEMO_WORKLOAD_MD5="fe6c0c2ae1d4fb42b30578646536615f"
elif [ "$NEMO_CODEBASE" == "COMMUNITY_4.2" ]; then
    true;
    # Settings for github version of NEMO (4.2 versions)
    # TBD
elif [ "$NEMO_CODEBASE" == "COMMUNITY_5.0" ]; then
    export NEMO_SRC_URL="forge.nemo-ocean.eu/nemo"  #"https://forge.nemo-ocean.eu/nemo/nemo.git"
    export NEMO_WORKLOAD_URL="https://gws-access.jasmin.ac.uk/public/nemo/sette_inputs/r5.0.0"
    export NEMO_CFG="ORCA2"
    export NEMO_SUBCOMPONENTS="OCE ICE"
    export NEMO_KEYS_TO_DELETE="key_top key_xios"
    export NEMO_KEYS_TO_ADD="bld::tool::fppkeys key_si3 key_qco key_vco_1d3d key_nosignedzero"
    is_set_to_true NEMO_WITH_RK3 && NEMO_KEYS_TO_ADD="$NEMO_KEYS_TO_ADD key_RK3"
    is_set_to_true NEMO_WITH_RK3 || NEMO_KEYS_TO_DELETE="$NEMO_KEYS_TO_DELETE key_RK3"
    export NEMO_WORKLOAD_ARCHIVE="ORCA2_ICE_v5.0.0.tar.gz"
    export NEMO_WORKLOAD_MD5="872eea51f22c5dabaffd268c0220eba6"
    export PSYCLONE__FILES_TO_SKIP="icblbc.f90,ice.f90,ice1d.f90,icealb.f90,icecor.f90,icectl.f90,icedia.f90,icedyn.f90,icedyn_adv.f90,icedyn_adv_pra.f90,icedyn_adv_umx.f90,icedyn_rdgrft.f90,icedyn_rhg.f90,icedyn_rhg_eap.f90,icedyn_rhg_evp.f90,icedyn_rhg_vp.f90,icefrm.f90,iceistate.f90,iceitd.f90,icerst.f90,icesbc.f90,icestp.f90,icetab.f90,icethd.f90,icethd_da.f90,icethd_dh.f90,icethd_do.f90,icethd_pnd.f90,icethd_sal.f90,icethd_zdf.f90,icethd_zdf_bl99.f90,iceupdate.f90,icevar.f90,icewri.f90,lbclnk.f90,lbcnfd.f90,lib_mpp.f90,mppini.f90,halo_mng.f90,par_ice.f90,par_icedyn.f90,sbc_ice.f90,sbcblk.f90,nvtx.f90,roctx.f90,hipinit.f90,ranges.f90"
else
    echo "Unknown value for NEMO_CODEBASE"
    exit 1
fi


