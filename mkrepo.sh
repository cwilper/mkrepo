#!/bin/bash

## # mkrepo
##
## Makes a tagged git repository out of a series of input directories
## representing significant states of a source tree.
##
## **Usage:**
##
##     mkrepo.sh input-dir output-dir [include-dir]
##
## **Where:**
##
## * ```input-dir``` is the directory containing the input directories.
## * ``output-dir`` is the directory where the repository should be created.
##   It must not yet exist.
## * ```include-dir``` is an optional directory containing a set of files to
##   be included in each commit.
##
## ## Basic Operation
##
## When you run this script, all directories within ```input-dir``` will be
## traversed in alphanumeric order, and a new commit will be created for each.
## Each commit will be tagged using the directory name.
##
## Prior to each commit, a scan will be performed for empty directories.
## For each found, an empty ```.gitignore``` file will be placed within,
## ensuring that the directory's existence will be recorded in git.
##
## ## Advanced Use
##
## ### Custom Commit Messages
##
## By default, the commit message for each directory will be identical to
## the directory/tag name. But if a file exists in ```input-dir``` with a
## ```.txt``` extension and the same base name of the directory, the
## content of that file will be used as the commit message instead.
##
## ### Non-Linear History 
##
## By default, each commit will be created as a child of the previous commit
## on the ```master``` branch. But if a file exists in ```input-dir``` with a 
## ```.branch``` extension and the same base name of the directory, a new
## branch will be created instead, and the commit will be created and tagged
## on it, after which the new branch ref will be deleted. The parent of this
## commit will be the ref whose name is found in the ```.branch``` file.
##
## This functionality is useful, for example, when a bugfix release is made
## for an older version of the software which has already been used as the
## baseline for a newer version. See the demo for an example.
##
## ### Non-Alphanumeric Ordering
##
## If you want tag names that occur in non-alphanumeric order, you may
## prepend your directory names with a number to ensure correct processing
## order, e.g.:
##
##     input-dir/01-very-first
##     input-dir/02-second
##
## Then rename the tags after the repository is created, e.g:
##
##     mkrepo.sh input-dir output-dir
##     cd output-dir
##     git tag very-first 01-very-first
##     git tag -d 01-very-first
##     git tag second 02-second
##     git tag -d second

temp_path=/tmp/mkrepo.tmp

die() {
    echo "Error: $1"
    exit 1
}

die_with_usage() {
    echo "Error: $1"
    echo "Usage: mkrepo.sh input-dir output-dir [include-dir]"
    echo "       mkrepo.sh --help"
    exit 1
}

if [ "$1" = "--help" ]; then
    grep "^##" $0 | sed 's/^## \{0,1\}//'
    exit 0
fi

if [ "$1" = "--version" ]; then
    echo "mkrepo unreleased from https://github.com/cwilper/mkrepo"
    exit 0
fi

if [[ ($# -ne 2 && $# -ne 3) ]]; then
    die_with_usage "Wrong number of arguments"
fi

input_dir="$1"
output_dir="$2"
include_dir="$3"

if [[ ! -d $input_dir ]]; then
    die_with_usage "input-dir must be a directory"
fi

if [[ -d $output_dir ]]; then
    die_with_usage "output-dir must not exist yet"
fi

if [[ ( -n $include_dir && ! -d $include_dir) ]]; then
    die_with_usage "if specified, include-dir must be a directory"
fi

# remove any previously-existing temp file from a previous run
if [[ -f "$temp_path/config" ]]; then
    rm -rf "$temp_path" || die "Unable to delete $temp_path"
fi

echo "Creating repository at $output_dir"

for input_path in "$input_dir"/*; do

    # skip files; we only want dirs
    if [[ -f "$input_path" ]]; then
        continue
    fi

    tagname="$(basename $input_path)"

    # if output-dir exists, move the repo aside and nuke the dir first
    if [[ -d $output_dir ]]; then
        cd $output_dir

        # create a temporary branch if needed
        branch_file="../$input_path.branch"
        if [[ -f $branch_file ]]; then
            parent_branch=$(cat $branch_file)
            echo "Adding $tagname as branched child of $parent_branch"
            git checkout -b tmp $parent_branch > /dev/null 2>&1 || die "Unable to create tmp branch from $parent_branch"
        else
            echo "Adding $tagname as latest child of master"
        fi

        cd ..

        mv "$output_dir/.git" /tmp/mkrepo.tmp
        rm -rf "$output_dir"
    else
        echo "Adding $tagname as root commit on master"
    fi

    # copy everything in input_path into output-dir
    cp -r "$input_path" "$output_dir"

    # add includes if needed
    if [[ -n $include_dir ]]; then
        # /. ensures all files in $include_dir (even dotfiles) are copied
        cp -r "$include_dir/." "$output_dir"
    fi

    cd "$output_dir"

    # create empty .gitignore files for empty dirs
    find . -type d -empty -exec touch {}/.gitignore \;

    # move repo back, or create it if needed
    if [[ -d "$temp_path" ]]; then
        mv "$temp_path" "../$output_dir/.git"
    else
        git init > /dev/null 2>&1
    fi

    # add changes to index
    git add -A . > /dev/null 2>&1 || die "Error adding changes to index"

    # commit changes with appropriate message
    message_file="../$input_path.txt"
    if [[ -f $message_file ]]; then
        git commit -F "$message_file" > /dev/null 2>&1 || die "Error committing"
    else
        git commit -m "$tagname"  > /dev/null 2>&1 || die "Error committing"
    fi

    # tag the commit
    git tag "$tagname" > /dev/null 2>&1 || die "Error tagging $tagname"

    # return to master
    git checkout master > /dev/null 2>&1 || die "Error checking out master"

    # drop the temporary branch if need
    if [[ -f $branch_file ]]; then
        git branch -D tmp > /dev/null 2>&1 || die "Unable to delete temporary branch"
    fi

    cd ..
done

echo "Done"
