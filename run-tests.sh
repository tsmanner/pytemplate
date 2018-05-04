# run-tests.sh
#
# Sets up 


# Wrapper function that squashes stdout
__quiet() {
  "$@" > /dev/null
}


# Wrapper function that squashes both stdout and stderr
__silence() {
  (2>&1 > /dev/null "$@")
}


# Wrpper function that routes stdout to stderr
__stderr() {
  "$@" >&2
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
__setup_venv() {
  local __python
  rm -rf venv$1
  __python=$(__get_python_interpreter_path $1)
  if [ "$__python" = "NONE" ] ; then
    __stderr echo "    python$1 not found!"
    exit 1
  else
    __silence $(dirname $__python)/virtualenv -v -p $__python venv$1
    if [ "$?" = "0" ] ; then
      __stderr echo "    python$1 ($__python) -> venv$1"
      . venv$1/bin/activate
      pip install .
    else
      __stderr echo "    virtualenv executable not found for $__python!"
      exit 1
    fi
  fi
  exit 0
}


# Run the unit tests
__do_tests() {
  echo "--Running Python$1 Tests--"
  . venv$1/bin/activate
  __python=python$1
  if [ "$1" = "2" ] ; then
    __python=python
  fi
  which $__python
  nose2 -s test/
  echo "---------Complete---------"
  echo
}


# Go through a simple yaml file and grab all python versions from it
__parse_yaml() {
  local yaml=($(cat $1))
  local token
  local capturing=0
  local capture_next=0
  declare -a versions
  for token in "${yaml[@]}" ; do
    if [ "$token" = "python:" ] ; then
      capturing=1
    elif [ $capturing -eq 1 ] ; then
      if [ $capture_next -eq 1 ] ; then
        echo "$token" | cut -c 2- | rev | cut -c 2- | rev
        capture_next=0
      elif [ "$token" = "-" ] ; then
        capture_next=1
      else
        capturing=0
      fi
    fi
  done
}


export PYTHONDONTWRITEBYTECODE=1

__prefix="__quiet"
if [ "$1" = "-v" ] ; then
  __prefix=""
elif [ "$1" = "-s" ] ; then
  __prefix="__silence"
fi

__versions=($(__parse_yaml *.yml))
__versions=($(echo "${__versions[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo "Creating Python virtual environments"

declare -A __pids
declare -A __rcs
for __version in "${__versions[@]}" ; do
  $__prefix __setup_venv $__version &
  __pids[$__version]=$!
done

for __version in "${!__pids[@]}" ; do
  wait ${__pids[$__version]}
  __rcs["$__version"]=$?
done

echo "done."
echo

for __version in "${!__rcs[@]}" ; do
  if [ "${__rcs[$__version]}" = "0" ] ; then
    __do_tests $__version
  fi
done
