#!/usr/bin/env sh

PFMDEBUG=1 perl -d -I../lib ../pfm "$@"
