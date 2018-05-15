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
    __virtualenv=$(dirname $__python)/virtualenv
    debug $__virtualenv -v -p $__python .venv$1
    if [ "$?" != "0" ] ; then
      __virtualenv=$(which virtualenv)
      debug $__virtualenv -v -p $__python .venv$1
      if [ "$?" != "0" ] ; then
        info echo "    virtualenv executable not found for $__python!"
        exit 1
      fi
    fi
    info echo "    python$1 ($__python) -> .venv$1"
  fi
}


# Run PyLint
__do_pylint() {
  LOG_DIR=.
  PYLINT_LOG=$LOG_DIR/pylint-report
  PYLINT_BADGE=$LOG_DIR/pylint.svg
  # Detect the test package
  debug echo "Detecting packages..."
  __packages="$(python -c 'import setuptools; print(" ".join(setuptools.find_packages()))')"
  debug echo $__packages
  # Append '/*' to each package name to hand off to pylint
  __pylint_directories=${__packages/ //* }/*
  __pylint_cmd="pylint $__pylint_directories test/*"
  debug echo "PyLint Command: '$__pylint_cmd'"
  debug echo
  info echo "PyLint: start ($PYLINT_LOG)"
  echo "Python $1" > $PYLINT_LOG
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
  anybadge -l pylint -v $__rating -f $PYLINT_BADGE 2=red 4=orange 8=yellow 10=green
}


# Run unit tests
__do_tests() {
  info echo "--Running Python$1 Tests--"
  # This is always printed... otherwise what is the point?
  coverage run $__branch -m unittest discover -s test/
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
  -c --recreate-venvs      Force creation of Python Virtual Environments.
  -C --no-recreate-venvs   Do not recreate Python Virtual Environments.
  -l --pylint              Run PyLint static analysis.
  -L --no-pylint           No not run PyLint static analysis.
     --htmlcov [dir]       Generate an HTML coverage report into 'dir' (default=htmlcov/)."

# Initialize variables
__recreate_venvs=0
__pylint=1
__log_level=3
__branch=""
__html_cov=0
__html_cov_dir=""

# Handle .testrc and arguments
if [ -e ".testrc" ] ; then
  __parse_rc ".testrc"
fi

# Add command line args after the rc args
args+=("$@")


while [ "${args[0]}" != "" ] ; do
  if [ "${args[0]}" = "-v" ] || [ "${args[0]}" = "--verbose" ] ; then
    __log_level=4
  elif [ "${args[0]}" = "-q" ] || [ "${args[0]}" = "--quiet" ] ; then
    __log_level=3
  elif [ "${args[0]}" = "-s" ] || [ "${args[0]}" = "--silent" ] ; then
    __log_level=1
  elif [ "${args[0]}" = "-c" ] || [ "${args[0]}" = "--recreate-venvs" ] ; then
    __recreate_venvs=1
  elif [ "${args[0]}" = "-C" ] || [ "${args[0]}" = "--no-recreate-venvs" ] ; then
    __recreate_venvs=0
  elif [ "${args[0]}" = "-l" ] || [ "${args[0]}" = "--pylint" ] ; then
    __pylint=1
  elif [ "${args[0]}" = "-L" ] || [ "${args[0]}" = "--no-pylint" ] ; then
    __pylint=0
  elif [ "${args[0]}" = "--log" ] ; then
    args=(${args[@]:1})
    __log_level=${args[0]}
  elif [ "${args[0]}" = "--branch" ] ; then
    __branch="--branch"
  elif [ "${args[0]}" = "--no-branch" ] ; then
    __branch=""
  elif [ "${args[0]}" = "--htmlcov" ] ; then
    __html_cov=1
    if [ "${args[1]}" = "" ] || [ "${args[1]:0:1}" = "-" ] ; then
      __html_cov_dir="htmlcov/"
    else
      __html_cov_dir="${args[1]}"
      args=(${args[@]:1})
    fi
  elif [ "${args[0]}" = "-h" ] || [ "${args[0]}" = "--help" ] ; then
    echo "$__help"
    exit 0
  else
    echo "Unrecognized option '${args[0]}'"
    echo "$__help"
    exit 1
  fi
  args=(${args[@]:1})
done


debug echo "__recreate_venvs  $__recreate_venvs"
debug echo "__pylint          $__pylint"
debug echo "__log_level       $__log_level"
debug echo "__html_cov        $__html_cov"
debug echo "__html_cov_dir    '$__html_cov_dir'"

# Enable dot glob so we will see any "hidden" yml files
shopt -s dotglob
debug echo "__parse_yml *.yml"
__versions=()
__parse_yaml *.yml
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

for __i in "${!__rcs[@]}" ; do
  if [ "${__rcs[$__i]}" = "0" ] ; then
    __version="${__versions[$__i]}"
    . .venv$__version/bin/activate
    # Install the test package
    debug pip install -r test_requirements.txt
    if [ "$__pylint" = "1" ] ; then
      __do_pylint $__version
    fi
    __do_tests $__version
  fi
done
