#!/bin/bash
set -e
build_type=Debug
install=0
cmake_flags=""
while getopts b:s:d:f:ih flag 
do
    case "${flag}" in
        b) build_type=${OPTARG};;
        s) src_dir=${OPTARG};;
        d) dst_dir=${OPTARG};;
        f) cmake_flags=${OPTARG};;
        i) install=1;;
        h) echo "Usage: ${0##*/} <-s Source dir> <-d Dest dir> [-f CMAKE flags] [-b Build configuration]" && exit;;
    esac
done

# Generate the build directory.
echo Building $src_dir with configuration $build_type
mkdir -p $dst_dir
cd $dst_dir

# Get the system name.
uname_out="$(uname -s)"
case "${uname_out}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Windows;;
    MINGW*)     machine=Windows;;
    *)          machine="UNKNOWN:${uname_out}"
esac

# Build based on the machine type.
time_start=`date +%s`
if [ $machine = "Mac" ]; then
    echo OS not supported.
    exit 1
fi
if [ $machine = "Windows" ]; then
    cmake $cmake_flags $src_dir
    cmake --build ./ --config $build_type
fi
if [ $machine = "Linux" ]; then
    cmake -DCMAKE_BUILD_TYPE=$build_type $cmake_flags $src_dir
    hw_threads_available=$(nproc --all)
    make --jobs=${hw_threads_available}
    if [ $install = 1 ]; then
        make install --jobs=${hw_threads_available}
    fi
fi
time_end=`date +%s`
runtime=$((time_end-time_start))
echo "Completed building $src_dir in ${runtime}[s]"!
