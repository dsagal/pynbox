#!/bin/bash

# The version should include the underlying software version, plus a suffix for build differences.
VERSION=3.6.0a
DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

echo "Building $PACKAGE"
bin/webports -v -V -t glibc build "$PACKAGE"

extract libxml2_2.9.4
extract libxslt_1.1.29
extract zlib_1.2.8

echo "Preparing files to package"
DEST_SITE_PACKAGES=$ROOT/python/lib/python2.7/site-packages
mkdir -p $DEST_SITE_PACKAGES

copy_dir  --exclude '*.pyc' \
          $NACL_SITE_PACKAGES/lxml                        $DEST_SITE_PACKAGES/
copy_file $NACL_SITE_PACKAGES/lxml-3.6.0-py2.7.egg-info   $DEST_SITE_PACKAGES/

strip_binaries_and_libs root/
create_archive root/
