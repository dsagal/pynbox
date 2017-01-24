#!/bin/bash

# The version should include the underlying software version, plus a suffix for build differences.
VERSION="2017-01-24a"
DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

echo "Building $PACKAGE"

# The test_pynbox_native test serves two purposes:
# (1) to verify that we can run native code and that its environment is restricted.
# (2) to be a simpler example than webports of how to build native code for the sandbox.

# We need to build and use C++ runtime libraries from corelibs.
bin/webports -v -V -t glibc build corelibs
extract corelibs_0.2

SRC_DIR=/host/packages/tests
NACL_LIBDIR=$NACL_SDK_ROOT/lib/glibc_${NACL_ARCH}/Release
$NACL_TOOLCHAIN_DIR/bin/g++ -I$NACL_SDK_ROOT/include -L$NACL_LIBDIR -o test_pynbox_native.nexe $SRC_DIR/test_pynbox_native.cc -ldl


echo "Preparing files to package"
mkdir -p $ROOT/test $STAGE_DIR/bin

copy_file $PAYLOAD/lib/libgcc_s.so.1        $ROOT/slib/
copy_file $PAYLOAD/lib/libstdc++.so.6       $ROOT/slib/
copy_file test_pynbox_native.nexe           $ROOT/test/
copy_file $SRC_DIR/test_pynbox_native.cc    $ROOT/test/
copy_file $SRC_DIR/test_pynbox_python.py    $ROOT/test/
copy_file $SRC_DIR/test_pynbox              $STAGE_DIR/bin/

strip_binaries_and_libs root/
create_archive root/ bin/
