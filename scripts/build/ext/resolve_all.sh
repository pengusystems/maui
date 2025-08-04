#!/bin/bash
#This script will resolve all the external dependencies.
#Operating systems supported are based on whatever is called from here.
set -e
echo Resolve All Externals
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
repo_root=$(realpath $script_dir/../../..)
resolve_missing_only=0
while getopts hm flag 
do
    case "${flag}" in
        h) echo "Usage: ${0##*/} [-m]" && exit;;
        m) resolve_missing_only=1;;
    esac
done

resolve_if_missing() {
    # Requires as input parameters:
    # 1 - External directory to search for the external
    # 2 - Git description to match the git version to
    # 3 - Resolve script to run if the external should be resolved
    local ext_dir="$1"
    local description_to_match="$2"
    local resolve_script="$3"
    local need_resolve=0
    if [ -d $ext_dir ]; then
        cd $ext_dir
        git fetch

        # Warn the user if an external repo is dirty.
        status_porcelain=$(git status --porcelain)
        if [[ (! -z $status_porcelain) && ($status_porcelain != "?? build/") && ($status_porcelain != "?? build_host/") && ($status_porcelain != *"M .gitmodules"*) ]]; then
            read -p "Warning - the git repository in $1 is dirty, rerun resolve? [y/n] " warn_response
            case $warn_response in [yY])
                :;;
                *) echo Exiting ; exit 1;;
            esac
            need_resolve=1
        fi

        # Warn the user if the branch is behind (this will trigger when the local copy is behind the reomte).
        if [[ ! -z $(git status | grep "branch is behind") ]]; then
            read -p "Warning - the git repository in $1 is behind origin, rerun resolve? [y/n] " warn_response
            case $warn_response in [yY])
                :;;
                *) echo Exiting ; exit 1;;
            esac
            need_resolve=1
        fi

        # Compare tags.
        description=$(git describe $(git rev-parse --short HEAD) --exact-match --all)
        if [[ $description != $description_to_match ]]; then
            read -p "Warning - the tag of the git repository in $1 ($description) is different than expected ($description_to_match), rerun resolve? [y/n] " warn_response
            case $warn_response in [yY])
                :;;
                *) echo Exiting ; exit 1;;
            esac
            need_resolve=1
        fi
    else
        need_resolve=1
    fi

    # Resolve if needed
    if [ $need_resolve == 1 ]; then
        eval "$resolve_script"
    else
        echo Skipping $ext_dir, $description matches
    fi
}

# Resolve missing only or all
if [ $resolve_missing_only == 1 ]; then
    resolve_if_missing "$repo_root/build/ext/asio" "tags/asio-1-34-2" "$repo_root/scripts/build/ext/resolve_asio.sh"
    resolve_if_missing "$repo_root/build/ext/concurrentqueue" "tags/v1.0.4" "$repo_root/scripts/build/ext/resolve_concurrentqueue.sh"
else
    echo "You are going to resolve all the externals, this will take a while"
    read -p "Continue? [y/n] " response
    case $response in [yY])
        :;;
        *) exit 1;;
    esac
    cd $repo_root/scripts/build/ext
    ./resolve_asio.sh
    ./resolve_concurrentqueue.sh
fi
echo Completed Resolving Externals
