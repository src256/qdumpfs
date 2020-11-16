#!/bin/sh

curdir=$(dirname $0)
bundle exec ruby $curdir/exe/qdumpfs $* ~/_qdumpfs/src ~/_qdumpfs/dst


