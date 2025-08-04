#!/bin/bash
#Operating systems supported:
# * All
set -e

# Configuration flags.
local=0
while getopts lh flag
do
    case "${flag}" in
        l) local=1;;
        h) echo "Usage: ${0##*/} [-s]" && exit;;
    esac
done

echo Resolving concurrentqueue...
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
repo_root=$(realpath $script_dir/../../..)
dst_dir=$repo_root/build/ext/concurrentqueue

# Clone or use local copy.
if [ $local == 0 ]; then
    if [ -d "$dst_dir" ]; then
        rm -rf $dst_dir
    fi
    mkdir -p $dst_dir
    cd $dst_dir
    git clone --depth 1 --branch v1.0.4 https://github.com/pengusystems/concurrentqueue .
fi

# Nothing to build, used as header only.
echo Completed resolving concurrentqueue
