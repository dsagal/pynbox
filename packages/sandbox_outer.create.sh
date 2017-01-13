#!/bin/bash

# The version should include the underlying software version, plus a suffix for build differences.
VERSION="2017-01-13a"
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
$NACL_DIR/scons -C "$NACL_DIR" platform=$ARCHD --mode="opt-$OS_TYPE" sel_ldr
NACL_BUILD_RESULTS=$NACL_DIR/scons-out/opt-$OS_TYPE-$ARCHD/staging

# Also build and run tests. This is just to check that the native_client repository has the
# feature we want (limited file access), but isn't part of packaging, so disabled here.
if [[ 1 -eq 0 ]]; then
  echo "*** Building and running some native_client tests"
  NACL_SRC_TESTS="run_limited_file_access_test run_limited_file_access_ro_test"
  $NACL_DIR/scons -C "$NACL_DIR" platform=$ARCHD $NACL_SRC_TESTS
fi

#----------------------------------------------------------------------
# Prepare the 'sandbox_outer' package with sel_ldr and convenience scripts.
#----------------------------------------------------------------------

echo "*** Preparing files to package"
mkdir -p $STAGE_DIR/bin

copy_file $NACL_BUILD_RESULTS/sel_ldr         $STAGE_DIR/bin/
copy_file $CHECKOUT_DIR/scripts/run           $STAGE_DIR/bin/
copy_file $CHECKOUT_DIR/scripts/nacl_python2  $STAGE_DIR/bin/
#copy_file $CHECKOUT_DIR/scripts/nacl_python3  $STAGE_DIR/bin/

create_archive bin/
