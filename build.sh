#!/bin/sh
#bundle config build.libv8 --with-system-v8
#bundle config build.therubyracer --with-v8-dir
set -x
#export NOKOGIRI_USE_SYSTEM_LIBRARIES=1

bundle_dir=./vendor/bundle
bundle config --local path $bundle_dir

if [ "$1" = "clean" ]; then
    echo "rm -rf $bundle_dir"
    /bin/rm -rf "$bundle_dir"
    /bin/rm Gemfile.lock    
    exit 0
fi

if [ -d "$bundle_dir" ] ; then
    echo "bunlde update"
    bundle update
    bundle clean
else
    echo "bundle install"
    /bin/rm -rf "$bundle_dir"
    bundle install
fi
