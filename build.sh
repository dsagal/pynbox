#!/bin/bash

# Change to the directory of this script, and get the absolute path to it.
cd `dirname "$0"`
ROOT=`pwd`

mkdir -p software/ build/

source scripts/util.sh


NACL_SDK_PEPPER_VERSION=50
WEBPORTS_PEPPER_VERSION=49
PLAT=x86
ARCHD=x86-64
ARCHU=`echo $ARCHD | tr - _`    # Same as ARCHD, replacing "-" with "_"

#----------------------------------------------------------------------
# Fetch Google's depot_tools, used to check out webports and native_client from source.
# See http://dev.chromium.org/developers/how-tos/depottools
#----------------------------------------------------------------------
header "--- fetch depot_tools"
if [ ! -d software/depot_tools ]; then
  run git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git software/depot_tools
else
  run git -C software/depot_tools pull
fi

# All we need to do to use them is make them accessible in PATH.
DEPOT_TOOLS_PATH=$ROOT/software/depot_tools
export PATH=$DEPOT_TOOLS_PATH:$PATH


#----------------------------------------------------------------------
# Fetch Chrome's NaCl SDK. It's big, but needed to build webports (NaCl tools built
# from sources above aren't enough).
# See https://developer.chrome.com/native-client/sdk/download.
#----------------------------------------------------------------------
header "--- fetch NaCl SDK"
NACL_SDK_ROOT=$ROOT/software/nacl_sdk/pepper_$NACL_SDK_PEPPER_VERSION
if [ ! -d software/nacl_sdk ]; then
  run curl -O -L https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip
  run unzip -d software/ nacl_sdk.zip
  run rm nacl_sdk.zip
fi
pushdir software/nacl_sdk
  run_oneline ./naclsdk update ${VERBOSE:+-v} pepper_$NACL_SDK_PEPPER_VERSION
popdir


#----------------------------------------------------------------------
# Maybe fetch Native Client source code (disabled by default because not currently needed).
# See https://www.chromium.org/nativeclient/how-tos/how-to-use-git-svn-with-native-client
#----------------------------------------------------------------------
if [ "$BUILD_NACL_SRC" = "yes" ]; then
  header "--- fetch native_client source code"
  NACL_DIR=$ROOT/software/nacl/native_client
  if [ ! -d "$NACL_DIR" ]; then
    mkdir -p software/nacl
    pushdir software/nacl
      run python -u $DEPOT_TOOLS_PATH/fetch.py --no-history nacl
    popdir
  fi
  pushdir "$NACL_DIR"
    run git checkout master
    run git pull
    if [ "$BUILD_SYNC" = "yes" ]; then
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

    # Workaround for only having XCode command-line tools without full SDK (which is fine)
    if patch -N --dry-run --quiet < $ROOT/patches/SConstruct.patch >/dev/null; then
      run patch -N < $ROOT/patches/SConstruct.patch
    fi

    run_oneline ./scons ${VERBOSE:+--verbose} platform=$ARCHD sel_ldr

    BUILT_SEL_LDR_BINARY=`pwd`/scons-out/opt-mac-$ARCHD/staging/sel_ldr
    echo "Build result should be here: $BUILT_SEL_LDR_BINARY"
  popdir
fi


#----------------------------------------------------------------------
# Fetch webports.
# See instructions here: https://chromium.googlesource.com/webports/
#----------------------------------------------------------------------
header "--- fetch webports"
WEBPORTS_DIR=$ROOT/software/webports/src
if [ ! -d "$WEBPORTS_DIR" ]; then
  mkdir software/webports
  pushdir software/webports
    run gclient config --unmanaged --name=src https://chromium.googlesource.com/webports.git
    run gclient sync --with_branch_heads
    run git -C src checkout -b pepper_$WEBPORTS_PEPPER_VERSION origin/pepper_$WEBPORTS_PEPPER_VERSION
  popdir
fi
pushdir "$WEBPORTS_DIR"
  if [ "$BUILD_SYNC" = "yes" ]; then
    run_oneline gclient sync
  fi
popdir


#----------------------------------------------------------------------
# Build python webport
#----------------------------------------------------------------------
header "--- build python webport"
pushdir "$WEBPORTS_DIR"

  # Apply out patch to the Python webport. (This includes patching the webport's
  # own patch file, which makes for a hard-to-read diff of a diff. Sorry.)
  if ! patch --dry-run -p1 -R < $ROOT/patches/webports.patch >/dev/null; then
    run patch -p1 -N < $ROOT/patches/webports.patch
  fi

  [ "$BUILD_PYTHON_FORCE" = "yes" ] && FORCE="1" || FORCE="0"
  # NACL_BARE=1 is a variable added by our own patch, to omit certain
  # Chrome-specific libraries from the Python build.
  run_oneline make NACL_SDK_ROOT="$NACL_SDK_ROOT" V=2 F=$FORCE \
    NACL_BARE=1 NACL_ARCH=$ARCHU FROM_SOURCE=1 TOOLCHAIN=glibc python

popdir


#----------------------------------------------------------------------
# Collect files for sandbox
#----------------------------------------------------------------------
header "--- collect files for sandbox"

mkdir -p build/sandbox_root build/sandbox_root/lib

NACL_TOOLCHAIN=$NACL_SDK_ROOT/toolchain/mac_${PLAT}_glibc/${ARCHU}-nacl
NACL_LIBDIR=$NACL_SDK_ROOT/lib/glibc_${ARCHU}/Release

# Copy the outer binaries and libraries needed to run python in the sandbox.
copy_file $NACL_SDK_ROOT/tools/sel_ldr_$ARCHU       build/sel_ldr
copy_file $NACL_SDK_ROOT/tools/irt_core_$ARCHU.nexe build/irt_core.nexe
copy_file $NACL_TOOLCHAIN/lib/runnable-ld.so        build/runnable-ld.so

# Copy all of python installation into the sandbox.
run_oneline copy_dir "$WEBPORTS_DIR"/out/build/python/install_${ARCHD}_glibc/payload/ build/sandbox_root/python

# This command shows most of the shared libraries the python binary needs.
# echo "$NACL_SDK_ROOT/toolchain/mac_${PLAT}_glibc/bin/${ARCHU}-nacl-objdump -p build/sandbox_root/python/bin/python2.7.nexe | grep NEEDED"
copy_file $NACL_TOOLCHAIN/lib/libdl.so.11835d88         build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libpthread.so.11835d88    build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libstdc++.so.6            build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libutil.so.11835d88       build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libm.so.11835d88          build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libc.so.11835d88          build/sandbox_root/lib/

# Additional libraries required generally or for some python modules.
copy_file $NACL_TOOLCHAIN/lib/libgcc_s.so.1             build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/lib/libcrypt.so.11835d88      build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libz.so.1             build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libncurses.so.5       build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libpanel.so.5         build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libssl.so.1.0.0       build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libbz2.so.1.0         build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libreadline.so        build/sandbox_root/lib/
copy_file $NACL_TOOLCHAIN/usr/lib/libcrypto.so.1.0.0    build/sandbox_root/lib/

#----------------------------------------------------------------------
# Demonstrate and test the building of C++ code for the sandbox.
#----------------------------------------------------------------------
# Build a sample C++ program, which tests a few things about the sandbox.
mkdir -p build/sandbox_root/test
echo "Here is how you can build C++ code for use in the sandbox"
run_oneline $NACL_TOOLCHAIN/bin/g++ -I$NACL_SDK_ROOT/include -L$NACL_LIBDIR -o build/sandbox_root/test/test_hello.nexe test/test_hello.cc -ldl
run ./sandbox_run test/test_hello.nexe

#----------------------------------------------------------------------
# Run a bunch of python tests under the sandbox.
#----------------------------------------------------------------------
# Copy to the sandbox and run a Python test script which tests various things about the sandbox.
run cp test/test_nacl.py build/sandbox_root/test/test_nacl.py
run ./pynbox test/test_nacl.py
