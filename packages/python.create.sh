#!/bin/bash

# The version should include the underlying software version, plus a suffix for build differences.
VERSION=2.7.11b
DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

echo "Building $PACKAGE.$VERSION"
bin/webports -v -V -t glibc build "$PACKAGE"

extract corelibs_0.2
extract gtest_1.7.0+
extract ncurses_5.9
extract readline_6.3
extract zlib_1.2.8
extract libtar_1.2.11
extract nacl-spawn_0.1
extract openssl_1.0.2e
extract bzip2_1.0.6
extract python_2.7.11

echo "Preparing files to package"

# We install everything python-related under root/python, because python.nexe is built with
# prefix=exec_prefix="/python". (Though I wasn't able to find how this is set.)
PYROOT=$ROOT/python
mkdir -p $ROOT/slib $PYROOT/{bin,lib/python2.7}

# Copy the python binary.
copy_file $PAYLOAD/bin/python2.7.nexe          $PYROOT/bin/

# Include all the top-level python modules.
copy_file $PAYLOAD/lib/python2.7/*.py          $PYROOT/lib/python2.7/

# Include all the native modules that python needs.
copy_dir  $PAYLOAD/lib/python2.7/lib-dynload   $PYROOT/lib/python2.7/

# To reduce the size of the sanboxed code, we skip a bunch of bigger python libraries that we
# don't expect to work in the sandbox, as well as tests and some other unneeded files.
copy_dir  $PAYLOAD/lib/python2.7/sqlite3       $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/logging       $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/encodings     $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/plat-nacl     $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/importlib     $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/xml           $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/curses        $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/site-packages $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/wsgiref       $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/unittest      $PYROOT/lib/python2.7/
copy_dir  --exclude 'test/' \
          $PAYLOAD/lib/python2.7/bsddb         $PYROOT/lib/python2.7/
copy_dir  --exclude 'test/' \
          $PAYLOAD/lib/python2.7/email         $PYROOT/lib/python2.7/
copy_dir  --exclude 'test/' \
          $PAYLOAD/lib/python2.7/ctypes        $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/hotshot       $PYROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/compiler      $PYROOT/lib/python2.7/
copy_dir  --exclude 'tests/' \
          $PAYLOAD/lib/python2.7/json          $PYROOT/lib/python2.7/
copy_dir  --exclude 'tests/' --exclude '*.exe' \
          $PAYLOAD/lib/python2.7/distutils     $PYROOT/lib/python2.7/

# Include the necessary shared libraries.
#   This command shows the shared libraries that a binary or library requires:
#   $NACL_TOOLCHAIN_DIR/bin/objdump -p bin/python2.7.nexe | grep NEEDED
#   $NACL_TOOLCHAIN_DIR/bin/objdump -p lib/python2.7/lib-dynload/_ssl.so | grep NEEDED
copy_file $PAYLOAD/lib/libc.so.11835d88        $ROOT/slib/
copy_file $PAYLOAD/lib/libcrypt.so.11835d88    $ROOT/slib/
copy_file $PAYLOAD/lib/libdl.so.11835d88       $ROOT/slib/
copy_file $PAYLOAD/lib/libm.so.11835d88        $ROOT/slib/
copy_file $PAYLOAD/lib/libpthread.so.11835d88  $ROOT/slib/
copy_file $PAYLOAD/lib/libutil.so.11835d88     $ROOT/slib/

copy_file $PAYLOAD/lib/libbz2.so.1.0           $ROOT/slib/
copy_file $PAYLOAD/lib/libcrypto.so.1.0.0      $ROOT/slib/
copy_file $PAYLOAD/lib/libncurses.so.5         $ROOT/slib/
copy_file $PAYLOAD/lib/libpanel.so.5           $ROOT/slib/
copy_file $PAYLOAD/lib/libreadline.so          $ROOT/slib/
copy_file $PAYLOAD/lib/libssl.so.1.0.0         $ROOT/slib/
copy_file $PAYLOAD/lib/libz.so.1               $ROOT/slib/

strip_binaries_and_libs root/
create_archive root/
