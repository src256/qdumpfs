#!/bin/sh

curdir=$(dirname $0)
bundle exec ruby $curdir/exe/qdumpfs --command=list /Volumes/EXT/

