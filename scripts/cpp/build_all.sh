#!/bin/bash
#This script will build all C/C++ (external & local) based libraries and applications.
#Operating systems supported are based on the other build scripts called from here.
set -e
build_type=Debug
repo_root=$(dirname $(realpath $0))/../..
while getopts b:h flag 
do
    case "${flag}" in
        b) build_type=${OPTARG};;
        h) echo "Usage: ${0##*/} [-b Build configuration]" && exit;;
    esac
done

cd $repo_root/scripts/cpp/
echo Build C/C++ All
echo
echo
./build_ext_grpc.sh -b $build_type
echo
echo
./build_maui.sh -b $build_type
echo Completed C/C++ All build 
