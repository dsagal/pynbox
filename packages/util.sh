#!/bin/bash

# This is intended to be sourced and used from "<module>.create.sh" scripts.
# See python.create.sh for an example.

set -e -u

DEST_DIR=$1
SCRIPT_NAME="$(basename $0)"
PACKAGE=${SCRIPT_NAME%%.*}
DEST_ARCHIVE=$DEST_DIR/${PACKAGE}.tbz2

# Create a temporary staging directory, and remove it when this script exits.
WORK_DIR=`pwd`
STAGE_DIR=`mktemp -d "$WORK_DIR/tmp.${PACKAGE}.XXXXXX"`
trap "rm -rf $STAGE_DIR" EXIT
echo "Using staging directory $STAGE_DIR"

PAYLOAD=$STAGE_DIR/payload
ROOT=$STAGE_DIR/root

# The way to check if a variable is defined: http://stackoverflow.com/a/13864829/328565
if [[ -n "${NACL_SDK_ROOT+x}" ]]; then
  NACL_TOOLCHAIN_DIR=$NACL_SDK_ROOT/toolchain/linux_x86_glibc/x86_64-nacl
  NACL_SITE_PACKAGES=$NACL_TOOLCHAIN_DIR/usr/lib/python2.7/site-packages
  STRIP=$NACL_TOOLCHAIN_DIR/bin/strip
fi

BUILT_PACKAGE_DIR=`pwd`/out/packages
BUILT_PACKAGE_SUFFIX="_x86-64_glibc.tar.bz2"

# Extract the payload/ subdirectory of a .tar.bz2 archive.
extract() {
  module=$1
  echo "Extracting $BUILT_PACKAGE_DIR/${module}$BUILT_PACKAGE_SUFFIX to $STAGE_DIR/"
  mkdir -p $STAGE_DIR/payload
  tar -C $STAGE_DIR/ -jxf "$BUILT_PACKAGE_DIR/${module}$BUILT_PACKAGE_SUFFIX" payload/
}

copy_file() { rsync -Lt --chmod=a-w "$@" ; }
copy_dir()  { rsync -rlt --safe-links --chmod=Fa-w "$@" ; }

# Reduce size by stripping all NaCl binaries and shared libraries under the given directory,
# relative to $STAGE_DIR.
# Usage: strip_binaries_and_libs <DIR_RELATIVE_TO_STAGE_DIR> (normally root/)
strip_binaries_and_libs() {
  echo "Stripping binaries and shared libraries"
  find $STAGE_DIR/$1 -name '*.nexe' -o -name '*.so' -o -name '*.so.*' | xargs $STRIP
}

# Once all files are ready, create an archive of passed-in directories under $STAGE_DIR.
# Usage: create_archive <DIR_RELATIVE_TO_STAGE_DIR> (normally root/)
create_archive() {
  echo "Creating archive $DEST_ARCHIVE"
  mkdir -p $DEST_DIR
  tar -jcf $DEST_ARCHIVE -C $STAGE_DIR "$@"
}

