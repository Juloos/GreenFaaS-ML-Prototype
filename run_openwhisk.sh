#!/bin/sh

cd "$(dirname "$0")"

git submodule update --init --recursive

cd openwhisk
cat core/standalone/src/main/resources/standalone.conf | \
    sed "s/limits-actions-sequence-maxLength = 50/limits-actions-sequence-maxLength = 999999/ ;
         s/limits-triggers-fires-perMinute = 60/limits-triggers-fires-perMinute = 999999/ ;
         s/limits-actions-invokes-perMinute = 60/limits-actions-invokes-perMinute = 999999/ ;
         s/limits-actions-invokes-concurrent = 30/limits-actions-invokes-concurrent = 999999/" \
    >standalone.conf.modified
./gradlew core:standalone:bootRun --args='-c standalone.conf.modified'
