#!/bin/bash

set -e -u

DEST_DIR=$1
DEST_ARCHIVE="$DEST_DIR/python.tbz2"
NACL_TOOLCHAIN_DIR=$NACL_SDK_ROOT/toolchain/linux_x86_glibc/x86_64-nacl
STRIP=$NACL_TOOLCHAIN_DIR/bin/strip

xcopy_file() { rsync -Ltv --chmod=a-w "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }
xcopy_dir()  { rsync -rltv --safe-links --chmod=Fa-w "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }

copy_file() { rsync -Lt --chmod=a-w "$@" ; }
copy_dir()  { rsync -rlt --safe-links --chmod=Fa-w "$@" ; }

SUFFIX="_x86-64_glibc.tar.bz2"
modules=(
    corelibs_0.2
    gtest_1.7.0+
    ncurses_5.9
    readline_6.3
    zlib_1.2.8
    libtar_1.2.11
    nacl-spawn_0.1
    openssl_1.0.2e
    bzip2_1.0.6
    python_2.7.11
)

rm -Rf packages/python/
mkdir -p packages/python/payload
for module in "${modules[@]}"; do
  echo "Extracting out/packages/${module}${SUFFIX} to packages/python/"
  tar -C packages/python/ -jxf "out/packages/${module}${SUFFIX}" payload/
done

cd packages/python
mkdir -p root root/bin root/slib root/lib/python2.7
echo "Preparing files to package"

# Copy the python binary.
copy_file payload/bin/python2.7.nexe          root/bin/

# Include all the top-level python modules.
copy_file payload/lib/python2.7/*.py          root/lib/python2.7/

# Include all the native modules that python needs.
copy_dir payload/lib/python2.7/lib-dynload    root/lib/python2.7/

# To reduce the size of the sanboxed code, we skip a bunch of bigger python libraries that we
# don't expect to work in the sandbox, as well as tests and some other unneeded files.
copy_dir payload/lib/python2.7/sqlite3        root/lib/python2.7/
copy_dir payload/lib/python2.7/logging        root/lib/python2.7/
copy_dir payload/lib/python2.7/encodings      root/lib/python2.7/
copy_dir payload/lib/python2.7/plat-nacl      root/lib/python2.7/
copy_dir payload/lib/python2.7/importlib      root/lib/python2.7/
copy_dir payload/lib/python2.7/xml            root/lib/python2.7/
copy_dir payload/lib/python2.7/curses         root/lib/python2.7/
copy_dir payload/lib/python2.7/site-packages  root/lib/python2.7/
copy_dir payload/lib/python2.7/wsgiref        root/lib/python2.7/
copy_dir payload/lib/python2.7/unittest       root/lib/python2.7/
copy_dir --exclude '/test/' \
         payload/lib/python2.7/email          root/lib/python2.7/
copy_dir --exclude '/test/' \
         payload/lib/python2.7/ctypes         root/lib/python2.7/
copy_dir payload/lib/python2.7/hotshot        root/lib/python2.7/
copy_dir payload/lib/python2.7/compiler       root/lib/python2.7/
copy_dir --exclude '/tests/' \
         payload/lib/python2.7/json           root/lib/python2.7/

# Include the necessary shared libraries.
#   This command shows the shared libraries that a binary or library requires:
#   $NACL_TOOLCHAIN_DIR/bin/objdump -p bin/python2.7.nexe | grep NEEDED
#   $NACL_TOOLCHAIN_DIR/bin/objdump -p lib/python2.7/lib-dynload/_ssl.so | grep NEEDED
copy_file payload/lib/libc.so.11835d88        root/slib/
copy_file payload/lib/libcrypt.so.11835d88    root/slib/
copy_file payload/lib/libdl.so.11835d88       root/slib/
copy_file payload/lib/libm.so.11835d88        root/slib/
copy_file payload/lib/libpthread.so.11835d88  root/slib/
copy_file payload/lib/libutil.so.11835d88     root/slib/

copy_file payload/lib/libbz2.so.1.0           root/slib/
copy_file payload/lib/libcrypto.so.1.0.0      root/slib/
copy_file payload/lib/libncurses.so.5         root/slib/
copy_file payload/lib/libpanel.so.5           root/slib/
copy_file payload/lib/libreadline.so          root/slib/
copy_file payload/lib/libssl.so.1.0.0         root/slib/
copy_file payload/lib/libz.so.1               root/slib/

# We can reduce sizes substantially by stripping binaries and shared libraries.
$STRIP root/bin/*.nexe
$STRIP root/slib/*.so*
$STRIP root/lib/python2.7/lib-dynload/*.so*

echo "Creating archive $DEST_ARCHIVE"
tar -jcf $DEST_ARCHIVE root/
