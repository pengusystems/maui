#!/bin/bash
#This script will setup the environment for development.
#Use "source ./set_env_development.sh" to source.
#Include in ~/.bashrc for convenience.
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Environment variables.
repo_root=$(realpath  $script_dir/../..)
export MAUI_ROOT=$repo_root
export MAUI_SCRIPTS=$repo_root/scripts
export MAUI_BUILD=$repo_root/build
export MAUI_DBG_BUILD=$repo_root/build/sw/cmake/x64/Debug

# Custom commands.
alias mald="cd $MAUI_ROOT/build/sw/cmake/x64/Debug/"
alias c='clear'
alias klast='kill -9 %'
alias lhs='ls -l -h --sort=size'

pretty-print-csv() {
    # Requires .csv file.
    if [ -z $1 ]; then
        echo "Usage: pretty-print-csv [/path/to/csv]"
        return 1
    fi
    column -s, -t < $1 | less -#2 -N -S
}

pa() {
    # Finds and prints process id of the given process.
    # Requires process name.
    if [ -z $1 ]; then
        echo "Usage: pa [process name]"
        return 1
    fi
    ps aux | grep $1 | awk '$0 !~ /grep/ {print}'
}

memusage-follow() {
    # Follows process memory usage.
    # Requires pid.
    if [ -z $1 ]; then
        echo "Usage: memusage-follow [#pid]"
        return 1
    fi
    if ! kill -0 $1 2>/dev/null; then
        echo "Process $1 not found."
        return 1
    fi
    while kill -0 $1 2>/dev/null; do
        read RSS VSZ <<< $(ps -o rss,vsz --no-headers -p $1)
        RSS_MB=$(bc <<< "scale=2; $RSS/1024")
        VSZ_MB=$(bc <<< "scale=2; $VSZ/1024")
        echo "$(date '+%Y-%m-%d %H:%M:%S') | RSS: ${RSS_MB}[MB] | VSZ: ${VSZ_MB}[MB]"
        sleep 1
    done
}

update-tags-from-remote() {
    # Requires local copy and remote upstream url.
    if [ -z $1 ]; then
        echo "Usage: update-tags-from-remote [/path/to/repo] [https://url/remote/upstream]"
        return 1
    fi
    echo "Changing directory to $1"
    cd $1
    echo "Result of running git describe in $1 is $(git describe). Remote upstream given is $2"
    read -p "Continue? [y/n] " response
    case $response in [yY])
        :;;
        *) return;;
    esac
    git remote add upstream $2
    git fetch --tags upstream
    git push --tags
}

# Allow forward search (i-search)
stty -ixon

# Workaround to enable tab autocomplete with environment variables.
shopt -s direxpand

# Increase limit for core dumps (on ubuntu those will appear under /var/lib/apport/coredump/).
ulimit -c unlimited

# A new shell gets the history lines from all previous shells.
PROMPT_COMMAND='history -a'

# If there are multiple matches for completion, Tab should cycle through them and Shift-Tab should cycle backwards.
bind 'TAB:menu-complete'
bind '"\e[Z": menu-complete-backward'

# Display a list of the matching files.
bind "set show-all-if-ambiguous on"

# Perform partial (common) completion on the first Tab press, only start cycling full results on the second Tab press (from bash version 5).
bind "set menu-complete-display-prefix on"

# Cycle through history based on characters already typed on the line.
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

# Keep Ctrl-Left and Ctrl-Right working when the above are used.
bind '"\e[1;5C":forward-word'
bind '"\e[1;5D":backward-word'
