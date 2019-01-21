#!/bin/sh --
set -eu
unset dir || :
case $0 in
   (/*) dir=${0%/*}/;;
   (*/) dir=./${0%/*};;
   (*)  dir=.;;
esac
cd "$dir" && {
   git ls-files -z |
   grep -z '\.sol$' |
   xargs -0 vim -T dumb -N -u NONE -n -es -S script.vim --
}
