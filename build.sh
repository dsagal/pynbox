#!/bin/bash

# Change to the directory of this script, and get the absolute path to it.
cd `dirname "$0"`
mkdir -p software/ build/
source scripts/util.sh

ROOT=`pwd`
NACL_SDK_PEPPER_VERSION=50
WEBPORTS_PEPPER_VERSION=49
NACL_SRC_BRANCH=readonly_mount
ARCHD=x86-64
NACL_ARCH=x86_64
TOOLCHAIN_ARCH=x86
if [ `uname -s` = "Darwin" ]; then
  OS_TYPE=mac
elif [ `uname -s` = 'Linux' ]; then
  OS_TYPE=linux
else
  OS_TYPE=unknown
fi

DEPOT_TOOLS_PATH=$ROOT/software/depot_tools
NACL_SDK_ROOT=$ROOT/software/nacl_sdk/pepper_$NACL_SDK_PEPPER_VERSION
WEBPORTS_DIR=$ROOT/software/webports/src

SANDBOX_DEST_ROOT=$ROOT/build/root

NACL_TOOLCHAIN_DIR=$NACL_SDK_ROOT/toolchain/${OS_TYPE}_${TOOLCHAIN_ARCH}_glibc/${NACL_ARCH}-nacl

if [ -n "$INSTALL_PYTHON_MODULE" ]; then
  pushdir "$WEBPORTS_DIR"
    # NACL_BARE=1 is a variable added by our own patch, to omit certain
    # Chrome-specific libraries from the Python build.
    run_oneline make NACL_SDK_ROOT="$NACL_SDK_ROOT" V=2 "F=$BUILD_PYTHON_FORCE" \
      NACL_BARE=1 NACL_ARCH=$NACL_ARCH FROM_SOURCE=1 TOOLCHAIN=glibc "python_modules/$INSTALL_PYTHON_MODULE"

    SUBDIR="lib/python2.7/site-packages/$INSTALL_PYTHON_MODULE"
    SANDBOX_DEST_DIR="$SANDBOX_DEST_ROOT/python/$SUBDIR"
    EXPECTED_DIR="${NACL_TOOLCHAIN_DIR}/usr/${SUBDIR}"
    if [ ! -e "${EXPECTED_DIR}" ]; then
      echo "Installed package not found in $EXPECTED_DIR"
      exit 1
    fi
    echo "Package installed to $EXPECTED_DIR"
    run_oneline copy_dir "$EXPECTED_DIR"/ "$SANDBOX_DEST_DIR"
  popdir
  exit 0
fi

#----------------------------------------------------------------------
# Fetch Google's depot_tools, used to check out webports and native_client from source.
# See http://dev.chromium.org/developers/how-tos/depottools
#----------------------------------------------------------------------
header "--- fetch depot_tools"
if [ ! -d "$DEPOT_TOOLS_PATH" ]; then
  run git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_PATH"
elif [ "$BUILD_SYNC" = "yes" ]; then
  run git -C "$DEPOT_TOOLS_PATH" pull
fi

# All we need to do to use them is make them accessible in PATH.
export PATH=$DEPOT_TOOLS_PATH:$PATH


#----------------------------------------------------------------------
# Fetch Chrome's NaCl SDK. It's big, but needed to build webports (NaCl tools built
# from sources above aren't enough).
# See https://developer.chrome.com/native-client/sdk/download.
#----------------------------------------------------------------------
header "--- fetch NaCl SDK"
NACL_SDK_BASE_DIR=`dirname "$NACL_SDK_ROOT"`
NACL_SDK_SYNC=$BUILD_SYNC
if [ ! -d "$NACL_SDK_BASE_DIR" ]; then
  run curl -O -L https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip
  run unzip -d nacl_tmp nacl_sdk.zip
  run mv nacl_tmp/nacl_sdk "$NACL_SDK_BASE_DIR"
  run rmdir nacl_tmp
  run rm nacl_sdk.zip
  NACL_SDK_SYNC=yes
fi
if [ "$NACL_SDK_SYNC" = "yes" ]; then
  pushdir "$NACL_SDK_BASE_DIR"
    run_oneline ./naclsdk update ${VERBOSE:+-v} pepper_$NACL_SDK_PEPPER_VERSION
  popdir
fi


#----------------------------------------------------------------------
# Maybe fetch Native Client source code (disabled by default because not currently needed).
# See https://www.chromium.org/nativeclient/how-tos/how-to-use-git-svn-with-native-client
#----------------------------------------------------------------------
if [ "$BUILD_NACL_SRC" = "yes" ]; then
  header "--- fetch native_client source code"
  NACL_DIR="$ROOT"/software/nacl/native_client
  NACL_SRC_SYNC=$BUILD_SYNC
  if [ ! -d "$NACL_DIR" ]; then
    mkdir -p software/nacl
    pushdir software/nacl
      # This line would fetch the official nacl. We do a little hacking to
      # fetch from our own repository copy that has additional changes.
      #run $DEPOT_TOOLS_PATH/fetch.py --no-history nacl
      cat >> .gclient <<EOF
solutions = [
{
  "managed": False,
  "name": "native_client",
  "url": "https://github.com/dsagal/native_client.git",
  "custom_deps": {},
  "deps_file": "DEPS",
  "safesync_url": "",
},
]
EOF
      run_oneline gclient sync
    popdir
    NACL_SRC_SYNC=yes
  fi
  pushdir "$NACL_DIR"
    run git checkout "$NACL_SRC_BRANCH"
    run git pull
    if [ "$NACL_SRC_SYNC" = "yes" ]; then
      run_oneline gclient sync
    fi
  popdir
fi


#----------------------------------------------------------------------
# Build from source Native Client's sel_ldr, the stand-alone "Secure ELF Loader"
#----------------------------------------------------------------------
if [ "$BUILD_NACL_SRC" = "yes" ]; then
  header "--- build native_client's sel_ldr"
  pushdir "$NACL_DIR"
    if [ "$BUILD_NACL_TESTS" = "yes" ]; then
      NACL_SRC_TESTS="run_limited_file_access_test run_limited_file_access_ro_test"
      NACL_SRC_MODE=""
    else
      NACL_SRC_TESTS=""
      NACL_SRC_MODE="opt-$OS_TYPE"
    fi
    run_oneline ./scons ${VERBOSE:+--verbose} platform=$ARCHD MODE=$NACL_SRC_MODE sel_ldr $NACL_SRC_TESTS

    BUILT_SEL_LDR_BINARY=`pwd`/scons-out/opt-$OS_TYPE-$ARCHD/staging/sel_ldr
    echo "Build result should be here: $BUILT_SEL_LDR_BINARY"
  popdir
fi


#----------------------------------------------------------------------
# Fetch webports.
# See instructions here: https://chromium.googlesource.com/webports/
#----------------------------------------------------------------------
header "--- fetch webports"
WEBPORTS_SYNC=$BUILD_SYNC
if [ ! -d "$WEBPORTS_DIR" ]; then
  WEBPORTS_BASE_DIR=`dirname "$WEBPORTS_DIR"`
  mkdir -p "$WEBPORTS_BASE_DIR"
  pushdir "$WEBPORTS_BASE_DIR"
    # Use a clone of webports that includes changes we need. The clone is of https://chromium.googlesource.com/webports/.
    run gclient config --unmanaged --name=src https://github.com/dsagal/webports.git
    run gclient sync --with_branch_heads
    #run git -C src checkout -b pepper_$WEBPORTS_PEPPER_VERSION origin/pepper_$WEBPORTS_PEPPER_VERSION
  popdir
  WEBPORTS_SYNC=yes
fi
if [ "$WEBPORTS_SYNC" = "yes" ]; then
  pushdir "$WEBPORTS_DIR"
    run_oneline gclient sync
  popdir
fi


#----------------------------------------------------------------------
# Build python webport
#----------------------------------------------------------------------
header "--- build python webport"
pushdir "$WEBPORTS_DIR"

  # NACL_BARE=1 is a variable added to our webports clone, to omit certain
  # Chrome-specific libraries from the Python build.
  run_oneline make NACL_SDK_ROOT="$NACL_SDK_ROOT" V=2 "F=$BUILD_PYTHON_FORCE" \
    NACL_BARE=1 NACL_ARCH=$NACL_ARCH FROM_SOURCE=1 TOOLCHAIN=glibc python

popdir


#----------------------------------------------------------------------
# Collect files for sandbox
#----------------------------------------------------------------------
header "--- collect files for sandbox"

SANDBOX_DEST_LIBDIR=$SANDBOX_DEST_ROOT/slib/
mkdir -p "$SANDBOX_DEST_ROOT" "$SANDBOX_DEST_LIBDIR"

# Copy the outer binaries and libraries needed to run python in the sandbox.
copy_file $ROOT/scripts/run                             build/run
copy_file $NACL_SDK_ROOT/tools/irt_core_$NACL_ARCH.nexe build/irt_core.nexe
copy_file $NACL_TOOLCHAIN_DIR/lib/runnable-ld.so        build/runnable-ld.so

# Copy the sel_ldr binary, from source if we built it, otherwise from the SDK.
if [ -n "$BUILT_SEL_LDR_BINARY" ]; then
  copy_file $BUILT_SEL_LDR_BINARY                       build/sel_ldr
else
  copy_file $NACL_SDK_ROOT/tools/sel_ldr_$NACL_ARCH     build/sel_ldr
fi

# Copy all of python installation into the sandbox.
run_oneline copy_dir "$WEBPORTS_DIR"/out/build/python/install_${ARCHD}_glibc/payload/ "$SANDBOX_DEST_ROOT/python"

# This command shows most of the shared libraries the python binary needs.
# echo "$NACL_TOOLCHAIN_DIR/bin/objdump -p $SANDBOX_DEST_ROOT/python/bin/python2.7.nexe | grep NEEDED"
copy_file $NACL_TOOLCHAIN_DIR/lib/libdl.so.11835d88         "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libpthread.so.11835d88    "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libstdc++.so.6            "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libutil.so.11835d88       "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libm.so.11835d88          "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libc.so.11835d88          "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/librt.so.11835d88         "$SANDBOX_DEST_LIBDIR"

# Additional libraries required generally or for some python modules.
copy_file $NACL_TOOLCHAIN_DIR/lib/libgcc_s.so.1             "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/lib/libcrypt.so.11835d88      "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libz.so.1             "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libncurses.so.5       "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libpanel.so.5         "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libssl.so.1.0.0       "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libbz2.so.1.0         "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libreadline.so        "$SANDBOX_DEST_LIBDIR"
copy_file $NACL_TOOLCHAIN_DIR/usr/lib/libcrypto.so.1.0.0    "$SANDBOX_DEST_LIBDIR"

#----------------------------------------------------------------------
# Demonstrate and test the building of C++ code for the sandbox.
#----------------------------------------------------------------------
# Build a sample C++ program, which tests a few things about the sandbox.
mkdir -p "$SANDBOX_DEST_ROOT/test"
echo "Here is how you can build C++ code for use in the sandbox"
NACL_LIBDIR=$NACL_SDK_ROOT/lib/glibc_${NACL_ARCH}/Release
run_oneline $NACL_TOOLCHAIN_DIR/bin/g++ -I$NACL_SDK_ROOT/include -L$NACL_LIBDIR -o "$SANDBOX_DEST_ROOT"/test/test_hello.nexe test/test_hello.cc -ldl
run build/run -R -L test/test_hello.nexe

#----------------------------------------------------------------------
# Run a bunch of python tests under the sandbox.
#----------------------------------------------------------------------
# Copy to the sandbox and run a Python test script which tests various things about the sandbox.
run cp test/test_nacl.py "$SANDBOX_DEST_ROOT"/test/test_nacl.py
run build/run python test/test_nacl.py

#----------------------------------------------------------------------
# Prepare a package of everything needed to run sandboxed python (all in build directory).
#----------------------------------------------------------------------
if [ "$RELEASE" = "yes" ]; then
  # Record version information into a file in the build.
  BUILD_INFO="$ROOT/build/buildinfo.txt"
  function get_git_info() {
    echo $1 `git -C $2 remote -v | awk '/fetch/{print $2}'` `git -C $2 rev-parse HEAD`
  }
  ( echo NACL_SDK_PEPPER_VERSION $NACL_SDK_PEPPER_VERSION;
    echo WEBPORTS_PEPPER_VERSION $WEBPORTS_PEPPER_VERSION;
    get_git_info nacl_src $NACL_DIR;
    get_git_info webports $WEBPORTS_DIR
  ) > "$BUILD_INFO"

  VERSION_ID_TMP=`date +%Y-%m-%d ; shasum -a 256 "$BUILD_INFO"`
  VERSION_ID=`echo $VERSION_ID_TMP | awk '{print $1 "." substr($2,1,6)}'`
  OUTPUT_BUNDLE=pynbox-${OS_TYPE}-${TOOLCHAIN_ARCH}.${VERSION_ID}.tgz
  echo "Creating output bundle $ColorBlue$OUTPUT_BUNDLE$ColorReset"
  if [ $OS_TYPE = 'mac' ]; then
    TAR_TRANSFORM_FLAG="-s /build/nacl/"
  elif [ $OS_TYPE = 'linux' ]; then
    TAR_TRANSFORM_FLAG="--transform s/build/nacl/"
  fi
  run_oneline tar $TAR_TRANSFORM_FLAG --exclude="*.pyc" -zcvf $OUTPUT_BUNDLE build/
  run aws --profile pynbox s3 cp "$OUTPUT_BUNDLE" s3://grist-pynbox/ ||
    (echo "${ColorBlue}To upload to S3, you must have 'aws' client installed, and ";
    echo "suitable credential configured for profile 'pynbox'${ColorReset}";
    exit 1)
fi
