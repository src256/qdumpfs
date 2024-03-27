#!/bin/sh

curdir=$(dirname $0)
#bundle exec ruby $curdir/exe/qdumpfs $* ~/_qdumpfs/src ~/_qdumpfs/dst
bundle exec ruby $curdir/exe/qdumpfs $* --exclude="/Users/sora/Documents/Virtual Machines.localized"  /Users/sora /Volumes/qdumpfs/home
