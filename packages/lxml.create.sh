#!/bin/bash

DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

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
