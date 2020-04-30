# uncomment to see the comands echoed in the output
# set -ex

# Build the dependency - unistring.
./build_unistring.sh

# configure settings
BASEPATH="${PWD}"
CURRENTPATH="/tmp/idn2"

DEVELOPER_DIR="$(xcode-select -p)"
VERSION_MIN="9.0"

UNISTRING_DIR="${BASEPATH}/unistring"
OTHER_CPP_FLAGS="-I${UNISTRING_DIR}/include"
OTHER_LD_FLAGS="-L${UNISTRING_DIR}/lib -lunistring"

# create temp dir
mkdir -p "${CURRENTPATH}"
cd "${CURRENTPATH}"

# clone the source
git clone --depth 1 --shallow-submodules https://github.com/gnosis/libidn2.git
cd libidn2

# build library

    # check prerequisites

        # brew install automake autoconf m4 gperf sed perl wget texinfo
    for cmd in automake autoconf m4 gperf sed perl wget texindex; do 
        if ! [ -x "$(command -v $cmd)" ]; then
            echo >&2 "$cmd is required but it is not installed."
            echo >&2 "To install all prerequisites, you can use Homebrew"
            echo >&2 "    brew install automake autoconf m4 gperf sed perl wget texinfo"
            echo >&2 "Aborting."
            exit 1
        fi
    done
    echo "Build dependencies found."
    

    # generate configure script
    echo "Creating configure script..."
    # To use updated version of the texinfo and m4 by brew and not by macOS
    export PATH="/usr/local/opt/gettext/bin:$PATH"
    export PATH="/usr/local/opt/texinfo/bin:$PATH"
    export PATH="/usr/local/opt/m4/bin:$PATH"

    ./bootstrap

    # for each architecture
    
    cat <<EOF > arch_lookup_table.txt
i386    iPhoneSimulator i686-apple-darwin
x86_64  iPhoneSimulator x86_64-apple-darwin
armv7   iPhoneOS        arm-apple-darwin
armv7s  iPhoneOS        arm-apple-darwin
arm64   iPhoneOS        arm-apple-darwin
EOF
    # read the parameters from the lookup table above
    while read ARCH SDK HOST; do

        # configure build parameters

        echo "Building idn2 for ${ARCH}"
        echo "This will take time..."

        DEVROOT="${DEVELOPER_DIR}/Platforms/${SDK}.platform/Developer"
        SDKROOT="${DEVROOT}/SDKs/${SDK}.sdk"

        export PATH="${DEVROOT}/usr/bin:${DEVROOT}/usr/sbin:${PATH}"

        export PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
        mkdir -p ${PREFIX}

        COMMON_FLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mios-version-min=${VERSION_MIN} -fembed-bitcode"

        export CPPFLAGS="-I${PREFIX}/include ${COMMON_FLAGS} -I${SDKROOT}/usr/include -O2 -g -Wno-error=tautological-compare ${OTHER_CPP_FLAGS}"
        export LDFLAGS="-L$(pwd)/lib ${COMMON_FLAGS} -L${SDKROOT}/usr/lib -Wno-error=unused-command-line-argument ${OTHER_LD_FLAGS}"

        # build
        ./configure \
            --prefix="${PREFIX}" \
            --host=${HOST} \
            --disable-shared \
            --disable-dependency-tracking \
            --disable-doc \
            --with-libunistring-prefix="${UNISTRING_DIR}"
        make -j 10
        make install
        make clean
    done <arch_lookup_table.txt
    
# create fat library archive

OUTPATH="${BASEPATH}/idn2"

echo "Create fat archive..."
LIBDIR="${OUTPATH}/lib"

rm -rf "${LIBDIR}"
mkdir -p "${LIBDIR}"

while read ARCH SDK HOST; do
    PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
    LIPO_IDN2="${LIPO_IDN2} ${PREFIX}/lib/libidn2.a"
done <arch_lookup_table.txt

lipo -create ${LIPO_IDN2} -output "${LIBDIR}/libidn2.a"

# copy headers

echo "Copying headers..."
INCLUDE_DIR="${OUTPATH}/include"

rm -rf "${INCLUDE_DIR}"
mkdir -p "${INCLUDE_DIR}"

while read ARCH SDK HOST; do
    PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
    IDN2_INCLUDE_DIR="${PREFIX}/include"
    break
done <arch_lookup_table.txt

cp -RL "${IDN2_INCLUDE_DIR}" "${INCLUDE_DIR}/../"

# create modulemap file
INCLUDED_FILES=$(find "${INCLUDE_DIR}" -name "*.h" | sed "s|^${INCLUDE_DIR}/\(.*\)|header \"\1\"|")

cat <<EOF >"${INCLUDE_DIR}/module.modulemap"
module idn2 {
    $INCLUDED_FILES

    export *
    link "iconv"
    link "unistring"
}

EOF

# clean up

cd "${BASEPATH}"
echo "Building done."

echo "Cleaning up..."
rm -rf "${CURRENTPATH}"
echo "Done."