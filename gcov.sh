#!/usr/bin/env bash

gcovNix=$(nix-build --no-out-link -A gcovBuild)
lcov=$(nix-build '<nixpkgs>' --no-out-link -A lcov)

export PATH=$(nix-build '<nixpkgs>' --no-out-link -A gcc-unwrapped)/bin:$PATH

source common.sh

if [ "$#" -gt 0 ]; then
    if [ -d "$1" ]; then
        inputs=$(echo "$1"/*)
    else
        inputs="$@"
    fi
else
    inputs=$(echo inputs/corpus/*)
fi

rm -rf gcov-prefix htmlcov
mkdir -p gcov-prefix
export GCOV_PREFIX=$(readlink -f gcov-prefix)

for f in $inputs; do
    $gcovNix/bin/nix-instantiate $fuzzArgs $f
done

(
    cd $GCOV_PREFIX
    storepath=$(echo nix/store/*)
    for d in $(find /$storepath -type d); do
        d=$(echo "$d" | sed -e 's|^/||')
        mkdir -p $d
    done

    for srcfile in $(find /$storepath -name '*.c' -o -name '*.cc' -o -name '*.hh' -o -name '*.h' -o -name '*.gcno'); do
        srcfile=$(echo "$srcfile" | sed -e 's|^/||')
        cp /$srcfile $srcfile
    done

    $lcov/bin/lcov -d . -c -o coverage.info
    $lcov/bin/genhtml coverage.info -o ../htmlcov --ignore-errors source
)

