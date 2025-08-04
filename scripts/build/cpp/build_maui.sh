#!/bin/bash
#This script will only build C++ stuff.
#Operating systems supported:
# * All
set -e
build_type=Debug
resolve_missing_externals=0
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
repo_root=$(realpath $script_dir/../../..)
cmake_builder_dir=$repo_root/scripts/build/cpp
src_dir=$repo_root/
dst_dir=$repo_root/build/sw/cmake/

# Flags interperation
cmake_flags="
"
while getopts b:mh flag
do
    case "${flag}" in
        b) build_type=${OPTARG};;
        m) resolve_missing_externals=1;;
        h) echo "Usage: ${0##*/} [-b Build configuration] [-m]" && exit;;
    esac
done

# Resolve missing externals.
if [ $resolve_missing_externals == 1 ]; then
    $repo_root/scripts/build/ext/resolve_all.sh -m
fi

# Build maui.
$cmake_builder_dir/cmake_builder.sh -b$build_type -s$src_dir -d$dst_dir -f"$cmake_flags"

# Create a soft link to compile_commands.json directly under the build directory as required by the clangd language server (https://clangd.llvm.org/installation#project-setup)
if [ ! -f "$repo_root/build/compile_commands.json" ]; then
    ln -s $dst_dir/compile_commands.json $repo_root/build/
fi
