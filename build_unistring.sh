# uncomment to see the comands echoed in the output
# set -ex

# configure settings
BASEPATH="${PWD}/unistring"
CURRENTPATH="/tmp/unistring"

DEVELOPER_DIR="$(xcode-select -p)"
VERSION_MIN="9.0"

# create temp dir
mkdir -p "${CURRENTPATH}"
cd "${CURRENTPATH}"

# clone the source
git clone --depth 1 --shallow-submodules https://github.com/gnosis/libunistring.git
cd libunistring

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
    export PATH="/usr/local/opt/texinfo/bin:$PATH"
    export PATH="/usr/local/opt/m4/bin:$PATH"
    # To generate the 'configure' script:
    git pull && ./gitsub.sh pull
    ./autogen.sh

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

        echo "Building unistring for ${ARCH}"
        echo "This will take time..."

        DEVROOT="${DEVELOPER_DIR}/Platforms/${SDK}.platform/Developer"
        SDKROOT="${DEVROOT}/SDKs/${SDK}.sdk"

        export PATH="${DEVROOT}/usr/bin:${DEVROOT}/usr/sbin:${PATH}"

        export PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
        mkdir -p ${PREFIX}

        COMMON_FLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mios-version-min=${VERSION_MIN} -fembed-bitcode"

        export CPPFLAGS="-I${PREFIX}/include ${COMMON_FLAGS} -I${SDKROOT}/usr/include -O2 -g -Wno-error=tautological-compare"
        export LDFLAGS="-L$(pwd)/lib ${COMMON_FLAGS} -L${SDKROOT}/usr/lib -Wno-error=unused-command-line-argument"

        # build
        ./configure \
            --prefix="${PREFIX}" \
            --host=${HOST} \
            --disable-shared
        make -j 10
        make install
        make clean
        make distclean
    done <arch_lookup_table.txt
    
# create fat library archive

echo "Create fat archive..."
rm -rf "${BASEPATH}/lib/"
mkdir -p "${BASEPATH}/lib/"

while read ARCH SDK HOST; do
    PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
    LIPO_UNISTRING="${LIPO_UNISTRING} ${PREFIX}/lib/libunistring.a"
done <arch_lookup_table.txt

lipo -create ${LIPO_UNISTRING} -output "${BASEPATH}/lib/libunistring.a"

# copy headers

echo "Copying headers..."

rm -rf "${BASEPATH}/include/"
mkdir -p "${BASEPATH}/include/"

while read ARCH SDK HOST; do
    PREFIX="$(pwd)/.build/${SDK}-${ARCH}"
    UNISTRING_INCLUDE_DIR="${PREFIX}/include"
    break
done <arch_lookup_table.txt

cp -RL "${UNISTRING_INCLUDE_DIR}" "${BASEPATH}/include/"

# clean up

cd "${BASEPATH}"
echo "Building done."

echo "Cleaning up..."
rm -rf "${CURRENTPATH}"
echo "Done."