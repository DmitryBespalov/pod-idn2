set -ex

# common build variables
DEVELOPER_DIR="$(xcode-select -p)"
VERSION_MIN="9.0"

clean_all() {
    rm -rf .build
}

# main function
build_xcframework() {
    build_idn2 iPhoneSimulator i386 i686-apple-darwin
    build_idn2 iPhoneSimulator x86_64 x86_64-apple-darwin
    build_idn2 iPhoneOS armv7 arm-apple-darwin
    build_idn2 iPhoneOS armv7s arm-apple-darwin
    build_idn2 iPhoneOS arm64 arm-apple-darwin

    create_xcframework unistring
    create_xcframework idn2
}

# Creates xcframework from libraries for different iOS platforms
#
# requires: 
#   - library and header files exist for 5 different platforms
# 
# arguments:
#   - name: the first argument is the name of the library
create_xcframework() {
    NAME=$1
    LIBNAME=lib${NAME}.a

    # all iPhoneOS architectures must be bundled in one universal file
    # for xcframework to work
    rm -rf .build/iPhoneOS/${NAME}/lib
    mkdir -p .build/iPhoneOS/${NAME}/lib
    lipo -create \
        .build/iPhoneOS/armv7/arm-apple-darwin/${NAME}/lib/${LIBNAME} \
        .build/iPhoneOS/armv7s/arm-apple-darwin/${NAME}/lib/${LIBNAME} \
        .build/iPhoneOS/arm64/arm-apple-darwin/${NAME}/lib/${LIBNAME} \
        -output \
        .build/iPhoneOS/${NAME}/lib/${LIBNAME}

    # all iPhoneSimulator architectures must be in one universal file
    # for xcframework to work
    rm -rf .build/iPhoneSimulator/${NAME}/lib
    mkdir -p .build/iPhoneSimulator/${NAME}/lib
    lipo -create \
        .build/iPhoneSimulator/i386/i686-apple-darwin/${NAME}/lib/${LIBNAME} \
        .build/iPhoneSimulator/x86_64/x86_64-apple-darwin/${NAME}/lib/${LIBNAME} \
        -output \
        .build/iPhoneSimulator/${NAME}/lib/${LIBNAME}

    # create a xcframework for one library. Multiple libraries in the same
    # framework are not supported.
    xcodebuild -create-xcframework \
        -library .build/iPhoneOS/${NAME}/lib/${LIBNAME} \
        -headers .build/iPhoneOS/armv7s/arm-apple-darwin/${NAME}/include \
        \
        -library .build/iPhoneSimulator/${NAME}/lib/${LIBNAME} \
        -headers .build/iPhoneSimulator/i386/i686-apple-darwin/${NAME}/include \
        \
        -output ${NAME}.xcframework
}

# Builds idn2 library for a given combination of SDK, ARCH, and HOST arguments.
# Also builds unistring with the same combination.
build_idn2() {
    ### parse arguments
    SDK=$1
    ARCH=$2
    HOST=$3

    build_unistring "${SDK}" "${ARCH}" "${HOST}"

    ### make build dir
    BUILD_DIR="$(pwd)/.build/${SDK}/${ARCH}/${HOST}"
    mkdir -p "${BUILD_DIR}"

    ### clone the source
    git clone --depth 1 --shallow-submodules https://github.com/gnosis/libidn2.git "${BUILD_DIR}/libidn2"
    
    ### enter the repo directory
    pushd "${BUILD_DIR}/libidn2"

    ### bootstrap 
    # To use updated version of the texinfo and m4 by brew and not by macOS
    export PATH="/usr/local/opt/gettext/bin:$PATH"
    export PATH="/usr/local/opt/texinfo/bin:$PATH"
    export PATH="/usr/local/opt/m4/bin:$PATH"

    ./bootstrap

    ### set env vars
    DEVROOT="${DEVELOPER_DIR}/Platforms/${SDK}.platform/Developer"
    SDKROOT="${DEVROOT}/SDKs/${SDK}.sdk"

    export PATH="${DEVROOT}/usr/bin:${DEVROOT}/usr/sbin:${PATH}"

    # the location of the resulting /lib and /include directionries
    export PREFIX="${BUILD_DIR}/idn2"
    mkdir -p "${PREFIX}"

    COMMON_FLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mios-version-min=${VERSION_MIN} -fembed-bitcode"

    export CPPFLAGS="-I${PREFIX}/include ${COMMON_FLAGS} -I${SDKROOT}/usr/include -O2 -g -Wno-error=tautological-compare -I${BUILD_DIR}/unistring/include"

    export LDFLAGS="-L$(pwd)/lib ${COMMON_FLAGS} -L${SDKROOT}/usr/lib -Wno-error=unused-command-line-argument -L${BUILD_DIR}/unistring/lib -lunistring"

    ### run configure
    ./configure \
        --prefix="${PREFIX}" \
        --host=${HOST} \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-doc \
        --with-libunistring-prefix="${BUILD_DIR}/unistring"
    
    ### compile
    make -j 10
    
    ### install to the PREFIX dir
    make install

    ### Create modulemap file
    INCLUDE_DIR="${PREFIX}/include"
    INCLUDED_FILES=$(find "${INCLUDE_DIR}" -name "*.h" | sed "s|^${INCLUDE_DIR}/\(.*\)|header \"\1\"|")

cat <<EOF >"${INCLUDE_DIR}/module.modulemap"
module idn2 {
    $INCLUDED_FILES

    export *
    link "iconv"
    link "unistring"
}

EOF

    popd
}

# Builds a unistring library for a combination of SDK, ARCH and HOST
build_unistring() {
    ### parse arguments
    SDK=$1
    ARCH=$2
    HOST=$3

    ### make build dir
    BUILD_DIR="$(pwd)/.build/${SDK}/${ARCH}/${HOST}"
    mkdir -p "${BUILD_DIR}"

    ### clone the source
    git clone --depth 1 --shallow-submodules https://github.com/gnosis/libunistring.git "${BUILD_DIR}/libunistring"
    
    ### enter the repo directory
    pushd "${BUILD_DIR}/libunistring"

    ### bootstrap 
    # To use updated version of the texinfo and m4 by brew and not by macOS
    export PATH="/usr/local/opt/texinfo/bin:$PATH"
    export PATH="/usr/local/opt/m4/bin:$PATH"

    # To generate the 'configure' script:
    git pull && ./gitsub.sh pull
    ./autogen.sh

    ### set env vars
    DEVROOT="${DEVELOPER_DIR}/Platforms/${SDK}.platform/Developer"
    SDKROOT="${DEVROOT}/SDKs/${SDK}.sdk"
    
    export PATH="${DEVROOT}/usr/bin:${DEVROOT}/usr/sbin:${PATH}"

    # the location of the resulting /lib and /include directionries
    export PREFIX="${BUILD_DIR}/unistring"
    
    mkdir -p "${PREFIX}"
    
    COMMON_FLAGS="-arch ${ARCH} -isysroot ${SDKROOT} -mios-version-min=${VERSION_MIN} -fembed-bitcode"

    export CPPFLAGS="-I${PREFIX}/include ${COMMON_FLAGS} -I${SDKROOT}/usr/include -O2 -g -Wno-error=tautological-compare"

    export LDFLAGS="-L$(pwd)/lib ${COMMON_FLAGS} -L${SDKROOT}/usr/lib -Wno-error=unused-command-line-argument"

    ### run configure
    ./configure \
            --prefix="${PREFIX}" \
            --host=${HOST} \
            --disable-shared
    ### make
    make -j 10
    ### make install
    make install

    ### pop to previously located directory
    popd
}


# build all
build_xcframework
