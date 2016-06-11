#!/bin/bash

# This file contains the utilities and settings used by build.sh. These are
# separated out so that build.sh itself contains just the essential steps, and
# is easier to read and adjust.

# Settings for script robustness.
set -o pipefail  # trace ERR through pipes
set -o nounset   # same as set -u : treat unset variables as an error
set -o errtrace  # same as set -E: inherit ERR trap in functions
trap 'echo Error in line "${BASH_SOURCE}":"${LINENO}"; exit 1' ERR
trap 'echo "${ColorReset}Exiting on interrupt"; exit 1' INT

# Destination for a copy of all stdout and stderr.
LOG=`pwd`/build.log
ONELINE=`pwd`/scripts/oneline

# Variables controlled by command-line options.
BUILD_SYNC=no
BUILD_NACL_SRC=yes
BUILD_NACL_TESTS=yes
BUILD_PYTHON_FORCE=0
INSTALL_PYTHON_MODULE=
RELEASE=no
VERBOSE=

process_options() {
  while [[ $# > 0 ]]; do
    case "$1" in
      --sync) BUILD_SYNC=yes
        ;;
      --no_nacl_src) BUILD_NACL_SRC=no
        ;;
      --no_nacl_tests) BUILD_NACL_TESTS=no
        ;;
      --rebuild_python) BUILD_PYTHON_FORCE=1
        ;;
      -v) VERBOSE=yes
        ;;
      --release) RELEASE=yes
        ;;
      install) INSTALL_PYTHON_MODULE="$2"; shift
        ;;
      -h|*) cat <<EOF
Usage: $0 [options]
Build everything needed to run Python within NativeClient (NaCl) sandbox.

  -h          Display this help and exit
  -v          Verbose mode
  --sync      Run "gclient sync" steps
  --no_nacl_src  Skip the building of NaCl tools from sources, and use the
              pre-built ones from the SDK.
  --no_nacl_tests Skip building sel_ldr-related tests in NaCl sources.
  --rebuild_python
              Force-rebuild python webport (useful if you changed its code,
              since the build does not pick up changes automatically).
  --release   Package the build results into a release, and publish to S3.
  install <module>
              Build and install a python module for which there is a webport.
EOF
        exit 2;
        ;;
    esac
    shift
  done
}

# Change to a directory and back, silently.
pushdir() { pushd "$@" > /dev/null; }
popdir() { popd > /dev/null; }

# Variables for changing text color.
ColorGrey=`tput setaf 7`
ColorBlue=`tput setaf 4`
ColorReset=`tput sgr0`

# Print a header, in blue color, useful for separating build stages.
header() { echo "$ColorBlue$@$ColorReset"; }

# Run the command (starting at the second argument) only if the first argument is "yes".
maybe_run() {
  dorun=$1
  shift
  if [ "$1" = "yes" ]; then
    echo "RUNNING[`pwd`]: $@"
    "$@"
  else
    echo "SKIPPING[`pwd`]: $@"
  fi
}

# Run the command given as arguments, after first printing it.
run() { echo "RUNNING[`pwd`]: $@"; "$@"; }

# Same, but print the output on a single line, to avoid filling the screen.
run_oneline() {
  echo "RUNNING[`pwd`]: $@$ColorGrey"
  if [ "$VERBOSE" = "yes" ]; then
    "$@"
  else
    "$@" 2>&1 | tee -i -a $LOG | $ONELINE >&3
  fi
  result=$?
  echo -n "$ColorReset"
  return $result
}

# Apply a patch only if it hasn't yet been applied. The first argument is the
# patch file, the rest are options to the patch command (e.g. -p1).
apply_patch() {
  patch=$1
  shift
  if patch --dry-run -R "$@" < $patch >/dev/null; then
    echo "Skipping previously applied patch: $patch"
  else
    run patch -N "$@" < $patch
  fi
}

# Copy file or directory only if the source is newer than the target.
copy_file() { rsync -Ltv --chmod=a-w "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }
copy_dir()  { rsync -rltv --safe-links --chmod=Fa-w "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }

#----------------------------------------------------------------------
# Copy full stdout and stderr to a log file.
echo "Writing full log to $ColorBlue`pwd`/$LOG$ColorReset"
>$LOG
exec 3>&1     # FD 3 goes to stdout only
exec >  >(tee -i -a $LOG)
exec 2> >(tee -i -a $LOG >&2)
process_options "$@"
