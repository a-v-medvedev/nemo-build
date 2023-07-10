[ -f ./env.sh ] && source ./env.sh || echo "WARNING: no env.sh file found"

BSCRIPTSDIR=./dbscripts

source $BSCRIPTSDIR/base.inc
source $BSCRIPTSDIR/funcs.inc
source $BSCRIPTSDIR/compchk.inc
source $BSCRIPTSDIR/envchk.inc
source $BSCRIPTSDIR/db.inc
source $BSCRIPTSDIR/apps.inc

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
    local WORKLOAD_ARCHIVE=ORCA2_ICE_v4.0.tar
    local WORKLOAD_MD5="fe6c0c2ae1d4fb42b30578646536615f"

    if this_mode_is_set 'd' "$m"; then
        mkdir -p "${pkg}.dwn"
	cd "${pkg}.dwn"
        svn export https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/r4.0/r$V $pkg
	cd $pkg
        tar czf "../${pkg}-${V}.tar.gz" $pkg
	cd $INSTALL_DIR
	# download from https://zenodo.org/record/2640723#.ZGOnotJByV4
	cd "${pkg}.dwn"
	if [ -f "$WORKLOAD_ARCHIVE" ]; then
	    echo "$WORKLOAD_MD5 $WORKLOAD_ARCHIVE" | md5sum -c --status || rm -f "$WORKLOAD_ARCHIVE"
	fi
	if [ ! -f "$WORKLOAD_ARCHIVE" ]; then
            wget -nv -O "$WORKLOAD_ARCHIVE" "https://zenodo.org/record/2640723/files/$WORKLOAD_ARCHIVE?download=1"
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
		[ -z "$NEMO_CPP" ] && NEMO_CPP="cpp"
		[ -z "$NEMO_CC" ] && NEMO_CC="cc"
		[ -z "$NEMO_FC" ] && NEMO_FC="mpif90"
		[ -z "$NEMO_FCFLAGS" ] && NEMO_FCFLAGS="-fdefault-real-8 -O3 -funroll-all-loops -fcray-pointer -ffree-line-length-none"
		[ -z "$NEMO_LDFLAGS" ] && NEMO_LDFLAGS=""
		[ -z "$NEMO_FPPFLAGS" ] && NEMO_FPPFLAGS="-P -C -traditional"
		set -u
		cd ${pkg}-${V}.src
		cat > arch/arch-dnb.fcm <<EOF
%NCDF_INC            -I$INSTALL_DIR/netcdf-fortran.bin/include
%NCDF_LIB            -L$INSTALL_DIR/netcdf-fortran.bin/lib -L$INSTALL_DIR/netcdf-c.bin/lib -lnetcdf -lnetcdff
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
		echo y | ./makenemo -n ORCA2 clean_config || true
		./makenemo -r ORCA2_ICE_PISCES -n ORCA2 -m dnb -d OCE del_key 'key_si3 key_top key_iomput' -j $MAKE_PARALLEL_LEVEL
		cd $INSTALL_DIR
	fi
	if this_mode_is_set 'i' "$m"; then
		[ -d "$pkg-$V" ] && rm -rf "$pkg-$V"
		[ -e "$pkg-$V" ] && rm -f "$pkg-$V"
		mkdir -p "$pkg-$V"
		# copy binary from $pkg-$V.src/cfgs/ORCA2/EXP00/* to $pkg-$V
		cp -v $pkg-$V.src/cfgs/ORCA2/EXP00/* "$pkg-$V"
		# unpack data tar archive
		cd "$pkg-$V"
		tar --skip-old-files -xvf "../${pkg}.dwn/$WORKLOAD_ARCHIVE"
		cd $INSTALL_DIR
        echo;
	fi
	i_make_binary_symlink "$pkg" "${V}" "$m"
}

####
export DNB_NOCUDA=1

PACKAGES="nemo"
#PACKAGE_DEPS=""
#PACKAGES="nemo hdf5 netcdf-c netcdf-fortran"
#PACKAGE_DEPS="nemo:netcdf-fortran netcdf-fortran:netcdf-c,hdf5 netcdf-c:hdf5"
VERSIONS="nemo:4.0.7 hdf5:1.10.7 netcdf-fortran:4.4.3 netcdf-c:4.4.0"
TARGET_DIRS="nemo.bin hdf5.bin netcdf-fortran.bin netcdf-c.bin"

started=$(date "+%s")
echo "Download and build started at timestamp: $started."
#env_init_is_declared=0
#set_variable_if_not_defined INSTALL_DIR $PWD
environment_check_main || fatal "Environment is not supported, exiting"
dubi_main "$*"
finished=$(date "+%s")
echo "----------"
echo "Full operation time: $(expr $finished - $started) seconds."

