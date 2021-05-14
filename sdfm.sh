#!/bin/bash

# SDFM - Super DotFile Manager.
# Copyright (C) 2021  Tom Simonart

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>

# Written by Tom Simonart (https://github.com/tomsimonart)

HOME_DIR="$HOME"
if [[ -z $SDFM_STORAGE ]]; then  # Use global variable if declared.
    STORAGE_DIR="$HOME/.dotfiles"
else
    STORAGE_DIR="$SDFM_STORAGE"
fi
STORAGE="$STORAGE_DIR/files"

# Create the storage directory if it doesn't exist already
mkdir -p "$STORAGE_DIR"

echo2() {
    # Echo to stderr
    echo "$@" >&2
}

usage() {
    # Print the command usage
    echo2 "$0 [-h] | [-r] [MODE [PATH...]]"
}

help_()
{
    # Display the help menu
    usage
    echo2 "Track dotfiles in a storage location."
    echo2 "Flags:"
    echo2 "  -h                     Display this help menu."
    echo2 "  -r                     Enable recursion."
    echo2 "  -i                     Print storage informations."
    echo2 "  -V                     Show version information."
    echo2 ""
    echo2 "Modes:"
    echo2 "  add PATH [PATH...]     Add dotfile(s) to the storage (track)."
    echo2 "  rm PATH [PATH...]      Remove dotfile(s) from the storage (untrack)."
    echo2 "  install [PATH...]      Install dotfile(s) from the storage to the home"
    echo2 "                         directory, existing files will be backed up."
    echo2 "  diff PATH [PATH...]    Display the diff between files."
    echo2 "  status [PATH...]       Display the tracking status of the dotfiles."
    echo2 "  list                   List stored dotfiles."
    echo2 "  shell                  Open a shell in the storage."
    echo2 ""
    echo2 "Paths supplied to the add, rm and diff modes must the be in the home directory."
    echo2 "Paths supplied to the install and status modes must be relative to the storage"
    echo2 "directory. If PATH is a directory sdfm will recurse over it only if the '-r'"
    echo2 "flag is supplied."
    echo2 "The storage location can be changed by setting '\$SDMF_STORAGE'."
}

color_out() {
    # Output to fileno and if fileno is from terminal enable colors
    local fileno=$1
    shift
    local color=$1
    shift
    if [[ -t $fileno ]]; then
        # Colorized output
        echo -e "\x1b[1;${color}m$*\x1b[0m" >&"${fileno}"
    else
        # Normal output
        echo "$@" >&2
    fi
}

error() {
    color_out 2 31 "$*"
}

warn() {
    color_out 2 33 "$*"
}

success() {
    color_out 1 32 "$*"
}

info() {
    color_out 1 34 "$*"
}

add_flag=0
rm_flag=0
install_flag=0
status_flag=0
recursion_flag=0

while getopts ":hriV" opt; do
    case $opt in
        "h")
            help_
            exit 0
            ;;
        "r")
            recursion_flag=1
            ;;
        "i")
            echo "Storage path:         $STORAGE_DIR"
            echo "Storage files path:   $STORAGE"
            echo "Home directory:       $HOME_DIR"
            exit 0
            ;;
        "V")
            echo "SDFM 1.0.0"
            echo "Copyrighe (C) 2021  Tom Simonart"
            echo "This program comes with ABSOLUTELY NO WARRANTY."
            echo "This is free software, and you are welcome to"
            echo "redistribute it under certain conditions."
            echo ""
            echo "Written by Tom Simonart (github.com/tomsimonart)"
            exit 0
            ;;
        "?")
            error "Unknown option $1"
            ;;
    esac
    shift
done

# Parse arguments
if [[ $# -ge 1 ]]; then
    case $1 in
        "add")
            command="add"
            add_flag=1
            ;;
        "rm" | "remove")
            command="rm_"
            rm_flag=1
            ;;
        "install")
            command="install"
            install_flag=1
            ;;
        "status")
            command="status"
            status_flag=1
            ;;
        "diff")
            command="diff_"
            diff_flag=1
            ;;
        "list" | "ls")
            find "$STORAGE" -type f -exec ls -Ahi {} \;
            exit 0
            ;;
        "shell")
            info "Opening shell in storage directory."
            warn "Enter 'exit' to quit."
            pushd "$STORAGE_DIR" || exit 1
            /bin/bash
            popd || exit 1
            exit 0
            ;;
    esac
    shift
    files=()  # Use an array to allow paths with spaces and globbing.
    while [[ $# -gt 0 ]]; do
        files+=("$1")
        shift
    done
fi


get_absolute() {
    # Change any path to an absolute path

    if [[ $1 == /* ]]; then
        echo "$1"
    else
        realpath "$HOME_DIR/$1"
    fi
}

get_path() {
    # Get the path relative to home or exit
    # This function guarantees that it won't return a path
    # outside of the home directory

    local search_dir
    if [[ $# -eq 2 ]]; then
        search_dir="$2"
    else
        search_dir="$HOME_DIR"
    fi

    local path
    path=$(realpath --relative-base "$search_dir" "$1")
    if [[ "$path" == /* ]]; then
        return 1
    else
        echo "$path"
        return 0
    fi
}

add() {
    # Add a dotfile to the storage
    mkdir -p "$STORAGE"
    # Check if the dotfile is a normal file
    if [[ -f "$1" ]]; then
        local path
        if path=$(get_path "$1"); then
            success "Adding: $path"
            # Create missing dirs in the storage
            mkdir -p "$STORAGE/$(dirname "$path")"
            # Add files in the storage
            ln -f "$HOME_DIR/$path" "$STORAGE/$path"
        else
            warn "Skipping: path is not in home directory: $1"
        fi
    else
        error "'$1': not a normal file or file does not exist."
    fi
}

rm_() {
    # Remove a dotfile from the storage
    local path
    path=$(get_path "$1")
    if [[ -f "$STORAGE/$path" ]]; then
        success "Removing: $path"
        # The --preserve-root option is unecessary
        # but at the same time it's good practice
        rm --preserve-root "$STORAGE/$path"
    else
        warn "Skipping: path not in home directory: $1"
    fi
}

clean_storage() {
    # Remove all empty directories from the storage
    find "$STORAGE" -mindepth 1 -type d -empty -delete
}

install() {
    # Install dotfiles (and create backups for files that already exist)
    install_() {
        local path
        path=$(get_path "$1" "$STORAGE")
        if [[ -f "$STORAGE/$path" ]]; then
            success "Installing: $path"
            mkdir -p "$HOME_DIR/$(dirname "$path")"
            ln --backup=numbered "$STORAGE/$path" "$HOME_DIR/$path"
        else
            warn "Skipping: path not in storage: $1"
        fi
    }
    if [[ $# -eq 0 ]]; then
        # Install all dotfiles
        while IFS= read -d '' -r file; do
            install_ "$file"
        done < <(find "$STORAGE" -mindepth 1 -type f -print0)
    else
        # Install single dotfile
        install_ "$1"
    fi
}

status() {
    # Print the status of dotfiles
    status_() {
        local path
        path=$(get_path "$1" "$STORAGE")
        # Item is installed and synced
        if ! [[ -f "$HOME_DIR/$path" ]]; then
            # Dotfile is missing in home directory (not installed)
            echo -e "[\x1b[1;31mMISS\x1b[0m]  $path"
        elif [[ "$STORAGE/$path" -ef "$HOME_DIR/$path" ]]; then
            # Dotfile is install (same inode)
            echo -e "[\x1b[1;32mSYNC\x1b[0m]  $path"
        else
            # Dotfile is not installed but present in home directory
            echo -e "[\x1b[1;33mDIFF\x1b[0m]  $path"
        fi
    }

    if [[ $# -eq 0 ]]; then
        # Status of all dotfiles
        while IFS= read -d '' -r file; do
            status_ "$file"
        done < <(find "$STORAGE" -mindepth 1 -type f -print0)
    else
        # Status of a single dotfile
        status_ "$1"
    fi
}

diff_() {
    local path
    path=$(get_path "$1")
    if [[ -t 1 ]]; then
        color=always
    else
        color=never
    fi
    diff --color="$color" -u "$STORAGE/$path" "$HOME_DIR/$path"
}

main() {
    run_command_ignore_backups() {
        # Run a command with a file as argument but skip backup files
        local command="$1"
        local target="$2"
        # Ignore backup files
        if ! [[ "$target" =~ .+\.~[0-9]+~$ ]]; then
            $command "$target"
        fi
    }

    if [[ $(( add_flag | rm_flag | install_flag | status_flag | diff_flag )) -ge 1 ]]; then
        if [[ ${#files[@]} -eq 0 ]]; then
            if [[ $(( install_flag | status_flag )) -ge 1 ]]; then
                # No path argument(s) required for these commands
                $command
            else
                error "The selected mode requires arguments."
                help_
                exit 1
            fi
        else
            # Files or directories in command arguments
            for target in "${files[@]}"; do
                if [[ -d "$target" ]]; then
                    if [[ $recursion_flag -ne 1 ]]; then
                        error "Cannot process directory without '-r'."
                        exit 1
                    fi
                    # If target is a directory loop into it
                    while IFS= read -d '' -r file; do
                        run_command_ignore_backups "$command" "$file"
                    done < <(find "$target" -mindepth 1 -type f -print0)
                else
                    # Otherwise run the command with the file as argument
                    run_command_ignore_backups "$command" "$target"
                fi
            done
        fi
    else
        error "No mode supplied"
        usage
        exit 1
    fi

    clean_storage
}

main
exit $?
