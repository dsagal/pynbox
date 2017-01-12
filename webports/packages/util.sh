#!/bin/bash

# This is intended to be sourced and used from "<module>.create.sh" scripts.
# See python.create.sh for an example.

set -e -u

DEST_DIR=$1
SCRIPT_NAME="$(basename $0)"
PACKAGE=${SCRIPT_NAME%%.*}
DEST_ARCHIVE=$DEST_DIR/${PACKAGE}.tbz2
PACKAGE_DIR=`pwd`/packages/$PACKAGE
PAYLOAD=$PACKAGE_DIR/payload
ROOT=$PACKAGE_DIR/root

NACL_TOOLCHAIN_DIR=$NACL_SDK_ROOT/toolchain/linux_x86_glibc/x86_64-nacl
NACL_SITE_PACKAGES=$NACL_TOOLCHAIN_DIR/usr/lib/python2.7/site-packages
STRIP=$NACL_TOOLCHAIN_DIR/bin/strip

BUILT_PACKAGE_DIR=`pwd`/out/packages
BUILT_PACKAGE_SUFFIX="_x86-64_glibc.tar.bz2"

# It might be better to use a temp dir for PACKAGE_DIR, and to clean it up on exit.
rm -Rf $PACKAGE_DIR/
mkdir -p $PACKAGE_DIR/payload $PACKAGE_DIR/root/{bin,slib,lib/python2.7/site-packages}

# Extract the payload/ subdirectory of a .tar.bz2 archive.
extract() {
  module=$1
  echo "Extracting $BUILT_PACKAGE_DIR/${module}$BUILT_PACKAGE_SUFFIX to $PACKAGE_DIR/"
  tar -C $PACKAGE_DIR/ -jxf "$BUILT_PACKAGE_DIR/${module}$BUILT_PACKAGE_SUFFIX" payload/
}

copy_file() { rsync -Lt --chmod=a-w "$@" ; }
copy_dir()  { rsync -rlt --safe-links --chmod=Fa-w "$@" ; }

# Once all files have been prepared in $ROOT, create an archive of them.
create_archive() {
  # We can reduce sizes substantially by stripping binaries and shared libraries.
  echo "Stripping binaries and shared libraries"
  find $ROOT -name '*.nexe' -o -name '*.so' -o -name '*.so.*' | xargs $STRIP

  echo "Creating archive $DEST_ARCHIVE"
  tar -jcf $DEST_ARCHIVE -C $PACKAGE_DIR root/
}

