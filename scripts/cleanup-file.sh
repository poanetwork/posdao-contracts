#!/bin/sh --
set -eu
unset dir || :
printf %s\\n "$0"
case $0 in
   (/*) dir=${0%/*}/;;
   (*/*) dir=./${0%/*};;
   (*)  dir=.;;
esac
printf %s\\n "$dir"
cd -L "$dir/.." && {
   git ls-files -z |
   xargs -0 vim -T dumb -N -u NONE -n -es -S scripts/script.vim --
}
