#!/bin/bash

DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

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

# Copy the python binary.
copy_file $PAYLOAD/bin/python2.7.nexe          $ROOT/bin/

# Include all the top-level python modules.
copy_file $PAYLOAD/lib/python2.7/*.py          $ROOT/lib/python2.7/

# Include all the native modules that python needs.
copy_dir  $PAYLOAD/lib/python2.7/lib-dynload   $ROOT/lib/python2.7/

# To reduce the size of the sanboxed code, we skip a bunch of bigger python libraries that we
# don't expect to work in the sandbox, as well as tests and some other unneeded files.
copy_dir  $PAYLOAD/lib/python2.7/sqlite3       $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/logging       $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/encodings     $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/plat-nacl     $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/importlib     $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/xml           $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/curses        $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/site-packages $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/wsgiref       $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/unittest      $ROOT/lib/python2.7/
copy_dir  --exclude 'test/' \
          $PAYLOAD/lib/python2.7/email         $ROOT/lib/python2.7/
copy_dir  --exclude 'test/' \
          $PAYLOAD/lib/python2.7/ctypes        $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/hotshot       $ROOT/lib/python2.7/
copy_dir  $PAYLOAD/lib/python2.7/compiler      $ROOT/lib/python2.7/
copy_dir  --exclude 'tests/' \
          $PAYLOAD/lib/python2.7/json          $ROOT/lib/python2.7/

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

create_archive
