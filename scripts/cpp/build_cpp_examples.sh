#!/bin/bash
#This script will only build C++ based examples.
#Operating systems supported:
# * All
set -e
build_type=Debug
repo_root=$(dirname $(realpath $0))/../..
cmake_builder_dir=$repo_root/scripts/cpp/
src_dir=$repo_root/
dst_dir=$repo_root/build/sw/cmake/

while getopts b:h flag
do
    case "${flag}" in
        b) build_type=${OPTARG};;
        h) echo "Usage: ${0##*/} [-b Build configuration]" && exit;;
    esac
done
$cmake_builder_dir/cmake_builder.sh -b$build_type -s$src_dir -d$dst_dir