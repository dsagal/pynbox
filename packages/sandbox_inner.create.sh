#!/bin/bash

DIR="$(dirname $BASH_SOURCE[0])"
source $DIR/util.sh

echo "Preparing files to package"
mkdir -p $STAGE_DIR/lib

copy_file $NACL_TOOLCHAIN_DIR/lib/runnable-ld.so            $STAGE_DIR/lib/
copy_file $NACL_SDK_ROOT/tools/irt_core_${NACL_ARCH}.nexe   $STAGE_DIR/lib/irt_core.nexe
chmod 555 $STAGE_DIR/lib/irt_core.nexe

strip_binaries_and_libs lib/
create_archive lib/
