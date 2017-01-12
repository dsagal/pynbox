#!/bin/bash

DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

# Change to the directory of this script, and get the absolute path to it.
CHECKOUT_DIR="$(pwd)"
BUILD_DIR="$CHECKOUT_DIR/build"

NACL_SRC_BRANCH=readonly_mount
ARCHD=x86-64
if [ `uname -s` = "Darwin" ]; then
  OS_TYPE=mac
elif [ `uname -s` = 'Linux' ]; then
  OS_TYPE=linux
else
  OS_TYPE=unknown
fi


#----------------------------------------------------------------------
# Fetch Google's depot_tools, used to check out native_client from source.
# See http://dev.chromium.org/developers/how-tos/depottools
#----------------------------------------------------------------------
echo "*** Fetching depot_tools"

DEPOT_TOOLS_PATH=$BUILD_DIR/depot_tools
if [[ ! -d "$DEPOT_TOOLS_PATH" ]]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_PATH"
fi

# All we need to do to use them is make them accessible in PATH.
export PATH=$DEPOT_TOOLS_PATH:$PATH


#----------------------------------------------------------------------
# Fetch Native Client source code from our own repo (we have changes to support read-only mounts).
# See https://www.chromium.org/nativeclient/how-tos/how-to-use-git-svn-with-native-client
#----------------------------------------------------------------------
echo "*** Fetching native_client source code"
NACL_DIR="$BUILD_DIR/nacl/native_client"
if [[ ! -d "$NACL_DIR" ]]; then
  mkdir -p `dirname $NACL_DIR`
  pushd `dirname $NACL_DIR`
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
    echo "*** Running gclient sync"
    gclient sync
  popd
fi

echo "*** Checking out branch '$NACL_SRC_BRANCH'"
git -C $NACL_DIR checkout "$NACL_SRC_BRANCH"
git -C $NACL_DIR pull


#----------------------------------------------------------------------
# Build from source Native Client's sel_ldr, the stand-alone "Secure ELF Loader"
#----------------------------------------------------------------------
echo "*** Building native_client's sel_ldr"
NACL_SRC_TESTS="run_limited_file_access_test run_limited_file_access_ro_test"
NACL_BUILD_RESULTS=$NACL_DIR/scons-out/opt-$OS_TYPE-$ARCHD/staging
$NACL_DIR/scons -C "$NACL_DIR" platform=$ARCHD --mode="opt-$OS_TYPE" sel_ldr

# Also build and run tests.
echo "*** Building and running some native_client tests"
$NACL_DIR/scons -C "$NACL_DIR" platform=$ARCHD $NACL_SRC_TESTS

#----------------------------------------------------------------------
# Prepare the 'sandbox_outer' package with sel_ldr and convenience scripts.
#----------------------------------------------------------------------

copy_file $NACL_BUILD_RESULTS/sel_ldr   $STAGE_DIR/bin/
copy_file $CHECKOUT_DIR/scripts/run     $STAGE_DIR/bin/
#copy_file $DIR/scripts/nacl_python2     $STAGE_DIR/bin/
#copy_file $DIR/scripts/nacl_python3     $STAGE_DIR/bin/

create_archive bin/


# # Copy the outer binaries and libraries needed to run python in the sandbox.
# copy_file $NACL_BUILD_RESULTS/sel_ldr           build/runner/sel_ldr
# copy_file $DIR/scripts/run                              build/runner/run
# 
# build/nacl//native_client/toolchain/mac_x86/nacl_x86_glibc/x86_64-nacl/lib/runnable-ld.so
# 
# # THESE SHOULD COME FROM DOCKER -- do not seem platform-specific 
# NACL_BUILD_RESULTS_UNTRUSTED=$NACL_DIR/scons-out/nacl_irt-$ARCHD/staging
# copy_file $NACL_BUILD_RESULTS_UNTRUSTED/irt_core.nexe   build/runner/irt_core.nexe
# NACL_TOOLCHAIN_ARCH=x86
# NACL_ARCH=x86_64
# NACL_TOOLCHAIN_DIR=$NACL_DIR/toolchain/
# NACL_TOOLCHAIN_DIR=$NACL_DIR/toolchain/${OS_TYPE}_${NACL_TOOLCHAIN_ARCH}_glibc/${NACL_ARCH}-nacl
# copy_file $NACL_TOOLCHAIN_DIR/lib/runnable-ld.so        build/runner/runnable-ld.so
# 
