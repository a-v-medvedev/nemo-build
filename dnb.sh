[ -f ./env.sh ] && source ./env.sh || echo "WARNING: no env.sh file found"

BSCRIPTSDIR=./dbscripts

source $BSCRIPTSDIR/base.inc
source $BSCRIPTSDIR/funcs.inc
source $BSCRIPTSDIR/compchk.inc
source $BSCRIPTSDIR/envchk.inc
source $BSCRIPTSDIR/db.inc
source $BSCRIPTSDIR/apps.inc

function mkdatalink() {
    local dir="$1"
    local file="$2"
    local oldpwd=$PWD
    cd "$dir"
    [ -L "$file" ] && rm -rf "$file"
    [ -e "$file" ] || ln -s "$HOME/data/$file" .
    cd "$oldpwd"
}

function dnb_netcdf-fortran() {
    local pkg="netcdf-fortran"
    environment_check_specific "$pkg" || fatal "${pkg}: environment check failed"
    local m=$(get_field "$1" 2 "=")
    local V=$(get_field "$2" 2 "=")
    du_github "Unidata" "netcdf-fortran" "v" "$V" "$m"
    local OPTS=""
    OPTS="$OPTS CPPFLAGS=-I$INSTALL_DIR/netcdf-c.bin/include"
#    OPTS="$OPTS FCFLAGS=-fallow-argument-mismatch""
    local CMDS="export LDFLAGS=\"-L$INSTALL_DIR/netcdf-c.bin/lib -Wl,-rpath,$INSTALL_DIR/netcdf-c.bin/lib\""
    bi_autoconf_make "$pkg" "$V" "$CMDS" "$OPTS" "$m"
    i_make_binary_symlink "$pkg" "${V}" "$m"
}

function dnb_netcdf-c() {
    local pkg="netcdf-c"
    environment_check_specific "$pkg" || fatal "${pkg}: environment check failed"
    local m=$(get_field "$1" 2 "=")
    local V=$(get_field "$2" 2 "=")
    du_github "Unidata" "netcdf-c" "v" "$V" "$m"
    local OPTS=""
    OPTS="$OPTS CPPFLAGS=-I$INSTALL_DIR/hdf5.bin/include"
    OPTS="$OPTS LDFLAGS=-L$INSTALL_DIR/hdf5.bin/lib"
    bi_autoconf_make "$pkg" "$V" "" "$OPTS" "$m"
    i_make_binary_symlink "$pkg" "${V}" "$m"

}

function dnb_nemo() {
    local pkg="nemo"
    environment_check_specific "$pkg" || fatal "${pkg}: environment check failed"
    local m=$(get_field "$1" 2 "=")
    local V=$(get_field "$2" 2 "=")
    local WORKLOAD_ARCHIVE="ORCA2_ICE_v4.0.tar"
    local WORKLOAD_MD5="fe6c0c2ae1d4fb42b30578646536615f"

    mkdatalink "$INSTALL_DIR" "$WORKLOAD_ARCHIVE"
    mkdatalink "$INSTALL_DIR" "nemo_de340.tgz"

    if this_mode_is_set 'd' "$m"; then
        mkdir -p "${pkg}.dwn"
        if [ "$V" == "DE340" ]; then
	        rm -f "${pkg}.dwn"/"${pkg}-${V}.tar.gz"
            ln -s "../nemo_de340.tgz" "${pkg}.dwn"/"${pkg}-${V}.tar.gz"
        #elif [ "$V" ~ 4.2 ]; then
            # go with github
        else
        	cd "${pkg}.dwn"
            svn export https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/r4.0/r$V $pkg
    	    cd $pkg
            tar czf "../${pkg}-${V}.tar.gz" $pkg
    	    cd $INSTALL_DIR
        fi
    	# download from https://zenodo.org/record/2640723#.ZGOnotJByV4
	    cd "${pkg}.dwn"
    	if [ -f "$WORKLOAD_ARCHIVE" ]; then
	        echo "$WORKLOAD_MD5 $WORKLOAD_ARCHIVE" | md5sum -c --status || rm -f "$WORKLOAD_ARCHIVE"
    	fi
	    if [ ! -f "$WORKLOAD_ARCHIVE" ]; then
            if [ -f "../$WORKLOAD_ARCHIVE" ]; then  
		        rm -f "$WORKLOAD_ARCHIVE"
                ln -s "../$WORKLOAD_ARCHIVE" .
            else
                wget -nv -O "$WORKLOAD_ARCHIVE" "https://zenodo.org/record/2640723/files/$WORKLOAD_ARCHIVE?download=1"
            fi
    	fi
	    cd $INSTALL_DIR
    fi
    if this_mode_is_set 'u' "$m"; then
        local archive="${pkg}.dwn/${pkg}-${V}.tar.gz"
        [ -e "$archive" ] || fatal "${pkg}: no downloaded archive file: $archive"
        local DIR=$(tar tzf "$archive" | head -n1 | sed s!/!!)
        [ -e "$DIR"} ] && rm -rf "$DIR"
        tar zxf "$archive"
        [ -d "$DIR" ] || fatal "${pkg}: error handling directory name in downloaded archive"
        [ -e ${pkg}-${V}.src ] && rm -rf ${pkg}-${V}.src
        mv ${DIR} ${pkg}-${V}.src
    fi
	if this_mode_is_set 'b' "$m"; then
		set +u
        [ -z "$NEMO_CFG" ] && NEMO_CFG="ORCA2"
        [ -z "$NEMO_SUBCOMPONENTS" ] && NEMO_SUBCOMPONENTS="OCE ICE"
        [ -z "$NEMO_KEYS_TO_DELELE" ] && NEMO_KEYS_TO_DELETE="key_top"
        [ -z "$NEMO_KEYS_TO_ADD" ] && NEMO_KEYS_TO_DELETE="key_asminc key_netcdf4 key_sms"
        if [ ! -z "$NEMO_USE_PREBUILD_PREREQS" ]; then
            [ -z "$NEMO_NETCDF_C_PATH" ] && fatal "direct path to necdf_c library is required"
            [ -z "$NEMO_NETCDF_FORTRAN_PATH" ] && fatal "direct path to necdf_fortran library is required"
        fi
        [ -z "$NEMO_NETCDF_C_PATH" ] && NEMO_NETCDF_C_PATH="$INSTALL_DIR/netcdf-c.bin"
        [ -z "$NEMO_NETCDF_FORTRAN_PATH" ] && NEMO_NETCDF_FORTRAN_PATH="$INSTALL_DIR/netcdf-fortran.bin"
		[ -z "$NEMO_CPP" ] && NEMO_CPP="cpp"
		[ -z "$NEMO_CC" ] && NEMO_CC="cc"
		[ -z "$NEMO_FC" ] && NEMO_FC="mpif90"
		[ -z "$NEMO_FCFLAGS" ] && NEMO_FCFLAGS="-fdefault-real-8 -O3 -funroll-all-loops -fcray-pointer -ffree-line-length-none"
		[ -z "$NEMO_LDFLAGS" ] && NEMO_LDFLAGS=""
		[ -z "$NEMO_FPPFLAGS" ] && NEMO_FPPFLAGS="-P -C -traditional"
		set -u
		cd ${pkg}-${V}.src
		cat > arch/arch-dnb.fcm <<EOF
%NCDF_INC            -I$NEMO_NETCDF_FORTRAN_PATH/include
%NCDF_LIB            -L$NEMO_NETCDF_FORTRAN_PATH/lib -L$NEMO_NETCDF_C_PATH/lib -lnetcdf -lnetcdff
%CPP                 $NEMO_CPP
%CC                  $NEMO_CC
%FC                  $NEMO_FC
%FCFLAGS             $NEMO_FCFLAGS
%FFLAGS              %FCFLAGS
%LD                  %FC
%LDFLAGS	     $NEMO_LDFLAGS
%FPPFLAGS            $NEMO_FPPFLAGS
%AR                  ar
%ARFLAGS             rs
%MK                  gmake
%USER_INC            %NCDF_INC
%USER_LIB            %NCDF_LIB
EOF
		echo y | ./makenemo -n "$NEMO_CFG" clean_config || true
		./makenemo -r ORCA2_ICE_PISCES -n "$NEMO_CFG" -d "$NEMO_SUBCOMPONENTS" -m dnb add_key "$NEMO_KEYS_TO_ADD" del_key "$NEMO_KEYS_TO_DELETE" -j $MAKE_PARALLEL_LEVEL
		cd $INSTALL_DIR
	fi
	if this_mode_is_set 'i' "$m"; then
		[ -d "$pkg-$V" ] && rm -rf "$pkg-$V"
		[ -e "$pkg-$V" ] && rm -f "$pkg-$V"
		mkdir -p "$pkg-$V"
		cp -v $pkg-$V.src/cfgs/$NEMO_CFG/EXP00/* "$pkg-$V"
		cd "$pkg-$V"
		tar --skip-old-files -xvf "../${pkg}.dwn/$WORKLOAD_ARCHIVE"
		cd $INSTALL_DIR
        echo;
	fi
	i_make_binary_symlink "$pkg" "${V}" "$m"
}

function dnb_sandbox() {
    mkdir -p sandbox
    cd sandbox
    cp ../nemo.bin/* .
    for i in *.gz; do gunzip -f $i; done
    mkdir -p lib
    [ -e "../netcdf-c.bin/lib" ] && cp -a ../netcdf-c.bin/lib/* lib
    [ -e "../netcdf-fortran.bin/lib" ] && cp -a ../netcdf-fortran.bin/lib/* lib
    cat > psubmit.opt.TEMPLATE <<EOF
QUEUE=__QUEUE__
NODETYPE=__NODETYPE__
RESOURCE_HANDLING=__RESOURCE_HANDLING__
TIME_LIMIT=__TIME_LIMIT__         
TARGET_BIN="./nemo"
JOB_NAME="NEMO_test_job"    
INIT_COMMANDS=__INIT_COMMANDS__
INJOB_INIT_COMMANDS=__INJOB_INIT_COMMANDS__
MPIEXEC=__MPI_SCRIPT__
BATCH=__BATCH_SCRIPT__  
EOF
    template_to_psubmitopts "." ""
    cd $INSTALL_DIR
}

####


started=$(date "+%s")
echo "Download and build started at timestamp: $started."
#env_init_is_declared=0
#set_variable_if_not_defined INSTALL_DIR $PWD
environment_check_main || fatal "Environment is not supported, exiting"

if [ -z "$NEMO_USE_PREBUILD_PREREQS" ]; then
    PACKAGES="nemo hdf5 netcdf-c netcdf-fortran"
    #PACKAGE_DEPS="nemo:netcdf-fortran netcdf-fortran:netcdf-c,hdf5 netcdf-c:hdf5"
    VERSIONS="nemo:4.0.7 hdf5:1.10.7 netcdf-fortran:4.4.3 netcdf-c:4.4.0"
    TARGET_DIRS="nemo.bin hdf5.bin netcdf-fortran.bin netcdf-c.bin"
else
    PACKAGES="nemo"
    VERSIONS="nemo:4.0.7"
    TARGET_DIRS="nemo.bin"
fi

dubi_main "$*"
finished=$(date "+%s")
echo "----------"
echo "Full operation time: $(expr $finished - $started) seconds."

