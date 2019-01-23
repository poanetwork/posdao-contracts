#!/usr/bin/env bash

rm -rf flat/*
ROOT=contracts/
ABSTRACTS=abstracts/
ABSTRACTS_FULL="$ROOT""$ABSTRACTS"
STORAGE=eternal-storage/
STORAGE_FULL="$ROOT""$STORAGE"
FLAT=flat/

iterate_sources() {
	for FILE in "$1"*.sol; do
	    [ -f "$FILE" ] || break
	    echo $FILE
	    ./node_modules/.bin/poa-solidity-flattener $FILE $2
	done
}

iterate_sources $ROOT $FLAT

mkdir -p $FLAT$ABSTRACTS;
iterate_sources $ABSTRACTS_FULL $FLAT$ABSTRACTS

mkdir -p $FLAT$STORAGE;
iterate_sources $STORAGE_FULL $FLAT$STORAGE
