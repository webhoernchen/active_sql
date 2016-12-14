#!/bin/bash

set -e

source "$HOME/.rvm/scripts/rvm"

local_folder=$(pwd)
RESULT=0

for test_app in $(ls test_apps | grep -v 2_3)
do
  if [[ $RESULT == 0 ]]
  then
    echo $test_app
    cd $local_folder/test_apps/$test_app
    RUBY_VERSION=$(cat RUBY_VERSION)
    rvm use $RUBY_VERSION || rvm install $RUBY_VERSION --disable-binary && rvm use $RUBY_VERSION
    gem install bundler
    bundle --version | awk '{print $3}' > BUNDLER_VERSION
    export BUNDLE_GEMFILE="$local_folder/test_apps/$test_app/Gemfile"
    bundle install
    bundle exec rake db:create:all
    bundle exec rake db:migrate
    bundle exec rake 
    RESULT=$(($RESULT + $?))
  fi
done

if [ $RESULT == 0 ]
then
  exit 0
else
  exit 1
fi
