#!/bin/sh

if [ "$1" = "" ]; then
#  bundle exec rspec
  bundle exec rails test
else
  # 以下のように実行  
    # ./test.sh test/unit/checker_test.rb
    #bundle exec rake test TEST=test/models/entry_test.rb TESTOPTS="--name=test_sample_2"    
  bundle exec rake test "$1"       
fi




