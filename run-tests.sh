#!/usr/bin/env bash
# run-tests.sh
#
# Sets up and runs unittests in each python environment it detects in the build files.


# Print if log level is CRITICAL
critical() {
  log 0 "(C): " "$@"
}

# Print if log level is ERROR
error() {
  log 1 "(E): " "$@"
}

# Print if log level is WARN
warn() {
  log 2 "(W): " "$@"
}

# Print if log level is INFO
info() {
  log 3 "(I): " "$@"
}

# Print if log level is DEBUG
debug() {
  log 4 "(D): " "$@"
}

# Print if log level is >= $1
log() {
  __this_level=$1
  shift 1
  __prefix="$1"
  shift 1
  if [ $__log_level -ge $__this_level ] ; then
    echo -n "$__prefix"
    "$@"
  else
    (2>&1 >/dev/null "$@")
  fi
}


# Figure out the full interpreter path for a python version
__get_python_interpreter_path() {
  __python=python$1
  (> /dev/null which $__python 2>&1)
  if [ "$?" != "0" ] ; then
    if [ "$1" = "2" ] ; then
      __python=python
    fi
  fi
  (> /dev/null which $__python 2>&1)
  if [ "$?" = "0" ] ; then
    which $__python 
  else
    echo "NONE"
  fi
}


# Create a new virtual environment for a particular python version
__create_venv() {
  local __python
  __python=$(__get_python_interpreter_path $1)
  if [ "$__python" = "NONE" ] ; then
    info echo "    python$1 not found!"
    exit 1
  else
    __virtualenv=$(which virtualenv)
    __virtualenv_by_version=$(dirname $__python)/virtualenv
    if [ -e $__virtualenv_by_version ] ; then
      debug $__virtualenv_by_version -v -p $__python .venv$1
      rc=$?
    elif [  -e $__virtualenv ] ; then
      debug $__virtualenv -v -p $__python .venv$1
      rc=$?
    else
      info echo "    virtualenv executable not found for $__python!"
      exit 1
    fi
    info echo "    python$1 ($__python) -> .venv$1"
  fi
}


# Run PyLint
__do_pylint() {
  # Detect the test package
  debug echo "Detecting packages..."
  __packages="$(python -c 'import setuptools; print(" ".join(setuptools.find_packages()))')"
  debug echo $__packages
  # Append '/*' to each package name to hand off to pylint
  __pylint_directories=${__packages/ //* }/*
  __pylint_files="$(find . -name '*.py' ! -path '*.venv*' -printf '%p ')"
  debug echo "__pylint_files: $__pylint_files"
  __pylint_cmd="pylint $__pylint_files"
  debug echo "PyLint Command: '$__pylint_cmd'"
  debug echo
  info echo "PyLint: start ($PYLINT_LOG)"
  echo "Python $1" >> $PYLINT_LOG
  echo "" >> $PYLINT_LOG
  __pylint_out=$(2>&1 $__pylint_cmd)
  __pylint_E=$(echo "$__pylint_out" | grep -c "E:")
  __pylint_W=$(echo "$__pylint_out" | grep -c "W:")
  __pylint_C=$(echo "$__pylint_out" | grep -c "C:")
  __pylint_R=$(echo "$__pylint_out" | grep -c "R:")
  __pylint_F=$(echo "$__pylint_out" | grep -c "F:")
  echo "$__pylint_out" >> $PYLINT_LOG
  __summary="PyLint: done  ($__pylint_E errors, $__pylint_W warnings, $__pylint_C conventions, $__pylint_R refactors, $__pylint_F fatals)"
  echo "$__summary" >> $PYLINT_LOG
  echo "" >> $PYLINT_LOG
  echo "" >> $PYLINT_LOG
  __rating_line=$(echo "$__pylint_out" | grep "Your code has been rated at ")
  __rating=$(echo "$__rating_line" | cut -d ' ' -f7 | cut -d '/' -f1)
  info echo "  $__rating_line"
  info echo "$__summary"
  info echo
  rm -f $PYLINT_BADGE
  if [ $(2>/dev/null which anybadge) ] ; then
    anybadge -l pylint -v $__rating -f $PYLINT_BADGE 2=red 4=orange 8=yellow 10=green
  else
    warn echo "anybdage not found, PyLint badge not created."
  fi
}


# Run unit tests
__do_tests() {
  info echo "--Running Python$1 Tests--"
  # This is always printed... otherwise what is the point?
  coverage run $__branch -m unittest discover -s $__test_dir
  log 2 "" coverage report
  rm -f coverage.svg
  coverage-badge -o coverage.svg
  if [ "$__html_cov" = "1" ] ; then
    info echo "Generating html coverage into '$__html_cov_dir'"
    coverage html -d $__html_cov_dir
  fi
  info echo
  info echo "---------Complete---------"
  info echo
  info echo
}


# Go through a simple yaml file and grab all python versions from it
__parse_yaml() {
  # For Windows compatibility, replace any CRLF with LF
  local yaml=($(cat $1 | tr '\r\n' '\n'))
  debug echo "Parsing '$1'"
  local token
  local capturing=0
  local capture_next=0
  __versions=()
  for token in "${yaml[@]}" ; do
    debug echo "Token: '$token'"
    if [ "$token" = "python:" ] ; then
      capturing=1
    elif [ $capturing -eq 1 ] ; then
      if [ $capture_next -eq 1 ] ; then
        __versions+=($(echo "$token" | cut -c 2- | rev | cut -c 2- | rev))
        capture_next=0
      elif [ "$token" = "-" ] ; then
        capture_next=1
      else
        capturing=0
      fi
    fi
  done
}


__parse_rc() {
  # For Windows compatibility, replace any CRLF with LF
  local rc_file=($(cat $1 | tr '\r\n' '\n'))
  local token
  for token in "${rc_file[@]}" ; do
    args+=("$token")
  done
}


#
# Main body
#

__help="\
usage: run-tests.sh [options]
  -h --help                Display this help message.
  -v --verbose             Print everything!  Equivalent to --log 4
  -q --quiet               Produce only some output.  Equivalent to --log 3
  -s --silent              Only report errors.  Equivalent to --log 1
     --log <level>         Set logging level.
                             0 = CRITICAL
                             1 = ERROR
                             2 = WARNING
                             3 = INFO
                             4 = DEBUG
     --recreate-venvs      Force creation of Python Virtual Environments.
     --no-recreate-venvs   Do not force recreation of Python Virtual Environments.
     --pylint              Run PyLint static analysis.
     --no-pylint           Do not run PyLint static analysis.
     --branch              Measure branch coverage in addition to statement coverage.
     --no-branch           Do not measure branch coverage in addition to statement coverage.
     --htmlcov [dir]       Generate an HTML coverage report into 'dir' (default=htmlcov/).
     --test-dir <dir>      Do test discovery from <dir> (default=test/).
     --skip-tests          Skip unit testing, venv creation and PyLint will still run normally.
     --no-skip-tests       Do not skip unit testing."

# Initialize variables
__log_level=3
__recreate_venvs=0
__pylint=1
__branch=""
__html_cov=0
__html_cov_dir=""
__test_dir="test"
__skip_tests=0

# Handle .testrc and arguments
if [ -e ".testrc" ] ; then
  __parse_rc ".testrc"
fi

# Add command line args after the rc args
args+=("$@")


while [ "${args[0]}" != "" ] ; do
  #
  # Help
  #
  if [ "${args[0]}" = "-h" ] || [ "${args[0]}" = "--help" ] ; then
    echo "$__help"
    exit 0
  #
  # Logging
  #
  elif   [ "${args[0]}" = "-v" ] || [ "${args[0]}" = "--verbose" ] ; then
    __log_level=4
  elif [ "${args[0]}" = "-q" ] || [ "${args[0]}" = "--quiet" ] ; then
    __log_level=3
  elif [ "${args[0]}" = "-s" ] || [ "${args[0]}" = "--silent" ] ; then
    __log_level=1
  elif [ "${args[0]}" = "--log" ] ; then
    # Consume the arg following '--log'
    __log_level="${args[1]}"
    # Advance args
    args=(${args[@]:1})
  #
  # Virtual Environment Control
  #
  elif [ "${args[0]}" = "--recreate-venvs" ] ; then
    __recreate_venvs=1
  elif [ "${args[0]}" = "--no-recreate-venvs" ] ; then
    __recreate_venvs=0
  #
  # PyLint Controls
  #
  elif [ "${args[0]}" = "--pylint" ] ; then
    __pylint=1
  elif [ "${args[0]}" = "--no-pylint" ] ; then
    __pylint=0
  #
  # Coverage Controls
  #
  #   Measure branch coverage in addition to statement coverage.
  elif [ "${args[0]}" = "--branch" ] ; then
    __branch="--branch"
  #   Do not measure branch coverage in addition to statement coverage.
  elif [ "${args[0]}" = "--no-branch" ] ; then
    __branch=""
  #   Produce an HTML coverage report.
  elif [ "${args[0]}" = "--htmlcov" ] ; then
    __html_cov=1
    if [ "${args[1]}" = "" ] || [ "${args[1]:0:1}" = "-" ] ; then
      __html_cov_dir="htmlcov/"
    else
      # Consume the arg following '--htmlcov'
      __html_cov_dir="${args[1]}"
      # Advance args
      args=(${args[@]:1})
    fi
  #
  # Test Discovery Control
  #
  #   Test Discovery Start Directory
  elif [ "${args[0]}" = "--test-dir" ] ; then
    # Consume the arg following '--test-dir'
    __test_dir="${args[1]}"
    # Advance args
    args=(${args[@]:1})
  #
  # Skip Tests
  #
  elif [ "${args[0]}" = "--skip-tests" ] ; then
    __skip_tests=1
  elif [ "${args[0]}" = "--no-skip-tests" ] ; then
    __skip_tests=0
  #
  # Unrecognized Option/Argument
  #
  else
    echo "Unrecognized option '${args[0]}'"
    echo "$__help"
    exit 1
  fi
  # Advance args
  args=(${args[@]:1})
done


debug echo "Session Variables:"
debug echo "    __recreate_venvs  '$__recreate_venvs'"
debug echo "    __pylint          '$__pylint'"
debug echo "    __log_level       '$__log_level'"
debug echo "    __html_cov        '$__html_cov'"
debug echo "    __html_cov_dir    '$__html_cov_dir'"
debug echo "    __test_dir        '$__test_dir'"
debug echo "    __skip_tests      '$__skip_tests'"


# PyLint Variables
LOG_DIR=.
PYLINT_LOG=$LOG_DIR/pylint-report
PYLINT_BADGE=$LOG_DIR/pylint.svg


# Enable dot glob so we will see any "hidden" yml files
shopt -s dotglob
__versions=()
# Capture all the yml files in here
__yml_files=($(ls *.yml))
debug echo "__parse_yml $__yml_files"
# Parse each of them
for __file in "${__yml_files[@]}" ; do
  __parse_yaml $__file
done
# Disable dot glob
shopt -u dotglob
# Get the array of version numbers
# Print the versions, replace ' ' with '\n', sort the lines, 
__versions=($(echo "${__versions[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | uniq))
debug echo "Versions: '$__versions'"

info echo "Setting up Python virtual environments"

declare -a __pids
declare -a __rcs
for __i in "${!__versions[@]}" ; do
  __version=${__versions[$__i]}
  debug echo "Setting up for Python$__version"
  if [ "$__recreate_venvs" = "1" ] || [ ! -e .venv$__version ] ; then
    __create_venv $__version &
    __pids[$__i]=$!
  else
    info echo "    python$__version (existing virtualenv) -> .venv$__version" &
    __pids[$__i]=$!
  fi
done

for __i in "${!__pids[@]}" ; do
  wait ${__pids[$__i]}
  __rcs[$__i]=$?
done

info echo "done."
info echo

# If we're going to run PyLint, reset the log file
if [ "$__pylint" = "1" ] ; then
  echo "" > $PYLINT_LOG
fi

for __i in "${!__rcs[@]}" ; do
  if [ "${__rcs[$__i]}" = "0" ] ; then
    __version="${__versions[$__i]}"
    . .venv$__version/bin/activate
    if [ "$__pylint" = "1" ] ; then
      __do_pylint $__version
    fi
    if [ "$__skip_tests" = "1" ] ; then
      warn echo "Python$__version Unit Testing Skipped (--skip-tests flag set)"
    else
      # Install the test package, if we're doing the unit tests.
      debug pip install -r test_requirements.txt
      __do_tests $__version
    fi
  fi
done
