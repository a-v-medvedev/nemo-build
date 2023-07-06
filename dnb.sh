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
    OPTS="$OPTS FCFLAGS=-fallow-argument-mismatch"
    OPTS="$OPTS LDFLAGS=-L$INSTALL_DIR/netcdf-c.bin/lib"
    bi_autoconf_make "$pkg" "$V" "cd src" "$OPTS" "$m"
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
    if this_mode_is_set 'd' "$m"; then
        svn export https://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/r4.0/r$V $pkg
        mkdir -p "${pkg}.dwn"
        tar czf "${pkg}.dwn/${pkg}-${V}.tar.gz" $pkg
        rm -rf $pkg
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
		[ -z "NEMO_CPP" ] && NEMO_CPP="cpp"
		[ -z "NEMO_CC" ] && NEMO_CC="cc"
		[ -z "NEMO_FC" ] && NEMO_FC="mpif90"
		[ -z "NEMO_FCFLAGS" ] && NEMO_FCFLAGS="-fdefault-real-8 -O3 -funroll-all-loops -fcray-pointer -ffree-line-length-none"
		[ -z "NEMO_LDFLAGS" ] && NEMO_LDFLAGS=""
		[ -z "NEMO_FPPFLAGS" ] && NEMO_FPPFLAGS="-P -C -traditional"
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
%LDFLAGS			 $NEMO_LDFLAGS
%FPPFLAGS            $NEMO_FPPFLAGS
%AR                  ar
%ARFLAGS             rs
%MK                  make
%USER_INC            %NCDF_INC
%USER_LIB            %NCDF_LIB
EOF
		./makenemo -v3 -r ORCA2_ICE_PISCES -n ORCA2 -m dnb -d OCE del_key 'key_si3 key_top key_iomput'
		cd $INSTALL_DIR
	fi
	if this_mode_is_set 'i' "$m"; then
		# download from https://zenodo.org/record/2640723#.ZGOnotJByV4 to $pkg-$V
		# copy binary from $pkg-$V.src/cfgs/ORCA2/EXP00/* to $pkg-$V
        echo;
	fi
	i_make_binary_symlink "$pkg" "${V}" "$m"
}

####
export DNB_NOCUDA=1

PACKAGES="nemo hdf5 netcdf-c netcdf-fortran"
#PACKAGE_DEPS="nemo netcdf-fortran:netcdf-c,hdf5 netcdf-c:hdf5"
VERSIONS="nemo:4.0.7 hdf5:1.10.7 netcdf-fortran:4.4.3 netcdf-c:4.4.0"
TARGET_DIRS="nemo.bin hdf5.bin netcdf-fortran.bin netcdf-c.bin"

started=$(date "+%s")
echo "Download and build started at timestamp: $started."
environment_check_main || fatal "Environment is not supported, exiting"
dubi_main "$*"
finished=$(date "+%s")
echo "----------"
echo "Full operation time: $(expr $finished - $started) seconds."

