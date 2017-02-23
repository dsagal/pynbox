#!/bin/bash

if [[ "$OS" == "Windows_NT" ]]; then
  OS_TYPE=win
elif [[ `uname -s` = "Darwin" ]]; then
  OS_TYPE=mac
elif [[ `uname -s` = 'Linux' ]]; then
  OS_TYPE=linux
else
  OS_TYPE=host
fi

# The version should include the underlying software version, plus a suffix for build differences.
VERSION="2017-02-10a.${OS_TYPE}"
DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh


# Change to the directory of this script, and get the absolute path to it.
CHECKOUT_DIR="$(dirname "$DIR")"
BUILD_DIR="$CHECKOUT_DIR/build"

NACL_SRC_BRANCH=windows_mount
ARCHD=x86-64


if [[ "$OS_TYPE" == "win" ]] ; then
  #----------------------------------------------------------------------
  # Building on windows requires some preliminary setup, which isn't automated here.
  # Try to detect it and print what to do.
  #----------------------------------------------------------------------
  WINDOWS_NEEDS_SETUP=0
  if ! which gclient >/dev/null 2>&1 ; then
    WINDOWS_NEEDS_SETUP=1
  else
    DEPOT_TOOLS_PATH="$(dirname "$(which gclient)")"
    if [[ ! -e "$DEPOT_TOOLS_PATH/python.bat" ]]; then
      WINDOWS_NEEDS_SETUP=1
    fi
  fi
  if [[ "$WINDOWS_NEEDS_SETUP" == 1 ]]; then
    echo "    ********************"
    echo "    Windows environment does not seem correctly set up."
    echo "    Follow full directions in goo.gl/3jemcG"
    echo "    for 'Visual Studio' and 'Install depot_tools'"
    echo "    ********************"
    exit 1
  fi

else
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
  export PATH=`pwd`/$DEPOT_TOOLS_PATH:$PATH

fi


#----------------------------------------------------------------------
# Fetch Native Client source code from our own repo (we have changes to support read-only mounts).
# See https://www.chromium.org/nativeclient/how-tos/how-to-use-git-svn-with-native-client
#----------------------------------------------------------------------
echo "*** Fetching native_client source code"
NACL_DIR="$BUILD_DIR/nacl/native_client"
NACL_ROOT="$(dirname $NACL_DIR)"
if [[ ! -d "$NACL_DIR" ]]; then
  mkdir -p "$NACL_ROOT"
  # This line would fetch the official nacl. We do a little hacking to
  # fetch from our own repository copy that has additional changes.
  #run $DEPOT_TOOLS_PATH/fetch.py --no-history nacl
  cat >> "$NACL_ROOT/.gclient" <<EOF
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
fi

sysrun() {
  if [[ "$OS_TYPE" == "win" ]] ; then
    local args=("$@")
    # Replace slashes with backslashes.
    args=("${args[@]//\//\\}")

    # See http://stackoverflow.com/a/15335686 for this way to set Visual Studio
    # environment before running the command.
    cmd //C call "$VS120COMNTOOLS/../../VC/vcvarsall.bat" "amd64" "&&" "${args[@]}"
  else
    "$@"
  fi
}

# While developing, you can set GCLIENT_SYNC=no to skip this slow step.
if [[ "${GCLIENT_SYNC:-yes}" != "no" ]]; then
  pushd "$NACL_ROOT"
    echo "*** Running gclient sync"
    sysrun gclient sync
  popd
fi

echo "*** Checking out branch '$NACL_SRC_BRANCH'"
git -C $NACL_DIR fetch
git -C $NACL_DIR checkout "$NACL_SRC_BRANCH"
git -C $NACL_DIR merge --ff-only "origin/$NACL_SRC_BRANCH"


#----------------------------------------------------------------------
# Build from source Native Client's sel_ldr, the stand-alone "Secure ELF Loader"
#----------------------------------------------------------------------
echo "*** Building native_client's sel_ldr"

sysrun python $NACL_DIR/scons.py -C "$NACL_DIR" platform=$ARCHD --mode="opt-$OS_TYPE" sel_ldr
NACL_BUILD_RESULTS=$NACL_DIR/scons-out/opt-$OS_TYPE-$ARCHD/staging

# Also build and run tests. This is just to check that the native_client repository has the
# feature we want (limited file access), but isn't part of packaging, so disabled here.
if [[ 1 -eq 0 ]]; then
  echo "*** Building and running some native_client tests"
  NACL_SRC_TESTS="run_limited_file_access_test run_limited_file_access_ro_test"
  sysrun python $NACL_DIR/scons.py -C "$NACL_DIR" platform=$ARCHD $NACL_SRC_TESTS
fi

#----------------------------------------------------------------------
# Prepare the 'sandbox_outer' package with sel_ldr and convenience scripts.
#----------------------------------------------------------------------

echo "*** Preparing files to package"
mkdir -p $STAGE_DIR/bin

# rsync might not be present on Windows, so copy files without using copy_file function.
cp -f $NACL_BUILD_RESULTS/sel_ldr         $STAGE_DIR/bin/
cp -f $CHECKOUT_DIR/scripts/run           $STAGE_DIR/bin/

create_archive bin/
