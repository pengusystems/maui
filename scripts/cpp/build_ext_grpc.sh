#!/bin/bash
#This script will build the C++ external grpc.
#Operating systems supported:
# * Ubuntu/Debian/Mint
# * See comment about Windows below.
# The default build type is not Debug, otherwise the library is huge.
set -e
build_type=MinSizeRel
repo_root=$(dirname $(realpath $0))/../..
cmake_builder_dir=$repo_root/scripts/cpp/
while getopts b:h flag 
do
    case "${flag}" in
        b) build_type=${OPTARG};;
        h) echo "Usage: ${0##*/} [-b Build configuration]" && exit;;
    esac
done

# Install deps
# Get the system name.
uname_out="$(uname -s)"
case "${uname_out}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Windows;;
    MINGW*)     machine=Windows;;
    *)          machine="UNKNOWN:${uname_out}"
esac

# For now, only linux is supported.
# On Windows extra stuff is required (https://github.com/grpc/grpc/blob/master/BUILDING.md)
if [ $machine != "Linux" ]; then
    echo OS not supported.
    exit 1
else
    sudo apt install -y build-essential autoconf libtool pkg-config
fi

# Clone the repo and update the submodules.
dst_dir=$repo_root/build/ext/grpc
if [ -d "$dst_dir" ]; then
    rm -rf $dst_dir
fi
mkdir -p $dst_dir
cd $dst_dir
git clone --recurse-submodules -b v1.60.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc .

# Build grpc.
src_dir=$dst_dir
dst_dir=$repo_root/build/ext/grpc/build
cmake_flags="
    -DgRPC_INSTALL=ON
    -DCMAKE_INSTALL_PREFIX=$dst_dir/install
"
$cmake_builder_dir/cmake_builder.sh -b$build_type -s$src_dir -d$dst_dir -f"$cmake_flags" -i
