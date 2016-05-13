#!/bin/bash

# This file contains the utilities and settings used by build.sh. These are
# separated out so that build.sh itself contains just the essential steps, and
# is easier to read and adjust.

# Settings for script robustness.
set -o pipefail  # trace ERR through pipes
set -o nounset   # same as set -u : treat unset variables as an error
trap 'echo Error in line "${BASH_SOURCE}":"${LINENO}"; exit 1' ERR
trap 'echo "${ColorReset}Exiting on interrupt"; exit 1' INT

# Destination for a copy of all stdout and stderr.
LOG=`pwd`/build/build.log
ONELINE=`pwd`/scripts/oneline

# Variables controlled by command-line options.
BUILD_SYNC=yes
BUILD_NACL_SRC=no
BUILD_PYTHON_FORCE=no
VERBOSE=

process_options() {
  while [[ $# > 0 ]]; do
    case "$1" in
      --nosync) BUILD_SYNC=no
        ;;
      --nacl_src) BUILD_NACL_SRC=yes
        ;;
      --rebuild_python) BUILD_PYTHON_FORCE=yes
        ;;
      -v) VERBOSE=yes
        ;;
      -h|*) cat <<EOF
Usage: $0 [options]
Build everything needed to run Python within NativeClient (NaCl) sandbox.

  -h          Display this help and exit
  -v          Verbose mode
  --nosync    Skip "gclient sync" steps
  --nacl_src  Don't skip the building of NaCl tools from sources (they are not
              needed unless you need to work on the NaCl tools themselves).
  --rebuild_python
              Force-rebuild python webport (useful if you changed its code,
              since the build does not pick up changes automatically).
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

# Copy file or directory only if the source is newer than the target.
copy_file() { rsync -Lv --chmod=a-w --update "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }
copy_dir()  { rsync -rlv --safe-links --chmod=a-w --update "$@" | ( grep -Ev '^(sent |total size |$)' || true ); }

#----------------------------------------------------------------------
# Copy full stdout and stderr to a log file.
echo "Writing full log to $ColorBlue`pwd`/$LOG$ColorReset"
>$LOG
exec 3>&1     # FD 3 goes to stdout only
exec >  >(tee -i -a $LOG)
exec 2> >(tee -i -a $LOG >&2)
process_options "$@"
