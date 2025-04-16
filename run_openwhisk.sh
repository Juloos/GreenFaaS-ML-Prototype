#!/bin/sh

cd "$(dirname "$0")"

git submodule update --init --recursive

cd openwhisk
./gradlew core:standalone:bootRun
