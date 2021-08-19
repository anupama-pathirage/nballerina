#!/bin/bash
# This expects to be run on Linux
# Argument is a executable file
# stdin is expected output of running the file

if test ! -f "$1"; then
    echo usage: $0 prog expect >&2
    exit 1
fi
b=`basename "$1"` 
kind=`echo "$b" | head -c 1`
out="out/actual/$b.txt"
mkdir -p out/actual

BAL_FILE=$(echo "$1" | sed -e s/"out\/result"/"..\/compiler\/testSuite"/ -e s/exe/bal/)
HEAP_SIZE=$(sed -ne 's;^.*// *@small_heap  *;;p' "$BAL_FILE")

if [ ! -z "$HEAP_SIZE" ]
then
    export SMALL_HEAP=$HEAP_SIZE
fi
export LD_LIBRARY_PATH=../runtime/gc-roots/third-party-lib/libbacktrace/.libs

if test $kind == P; then
    $("./$1" >/dev/null 2>"$out")
else
    "./$1" >"$out"
fi

diff -u "$2" "$out"
