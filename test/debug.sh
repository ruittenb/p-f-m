#!/usr/bin/env sh

GITROOT=$(git rev-parse --show-toplevel)

PFMDEBUG=1 perl -d -I$GITROOT/lib $GITROOT/pfm "$@"
