#!/bin/bash

## # unmkrepo
##
## Makes a series of directories out of a git repository, one for each tag.
##
## This has the opposite effect of
## [mkrepo](https://github.com/cwilper/mkrepo/blob/master/README.md).
##
## **Usage:**
##
##     unmkrepo.sh input-dir output-dir [tag1 [tag2 [etc..]]]
##
## **Where:**
##
## * ```input-dir``` is the directory containing the repository.
## * ```output-dir``` is the directory where the directories should be created.
## * ```tags``` are the set of tags to copy. If unspecified, all tags will
##   be copied.
##
## ## Basic Operation
##
## When you run this script, all tags (or the specified subset) from the
## repository in ```input-dir``` will be checked out, and the state of the
## source tree for each will be copied into a subdirectory of ```output-dir```.
##
## If the commit message for any of the tagged commits consists of anything
## other than the tag name itself, a ```.txt``` file will be written alongside
## the subdirectory, with the same base name.

temp_path=/tmp/unmkrepo.tmp

die() {
    echo "Error: $1"
    exit 1
}

die_with_usage() {
    echo "Error: $1"
    echo "Usage: unmkrepo.sh input-dir output-dir [tag1 [tag2 [etc..]]]"
    echo "       unmkrepo.sh --help"
    exit 1
}

restore_dotgit() {
    popd > /dev/null 2>&1
    if [[ -d $temp_path ]]; then
        mv $temp_path $input_dir
    fi
}

if [ "$1" = "--help" ]; then
    grep "^##" $0 | sed 's/^## \{0,1\}//'
    exit 0
fi

if [ "$1" = "--version" ]; then
    echo "unmkrepo v1.1.0 from https://github.com/cwilper/mkrepo"
    exit 0
fi

if [[ ($# -lt 2) ]]; then
    die_with_usage "Wrong number of arguments"
fi

input_dir="$1"
output_dir="$2"
shift
shift
# hold on to these if specified at command line
tags=($*)

if [[ ! -d "$input_dir/.git" ]]; then
    die_with_usage "input-dir must be a directory containing a git repository"
fi

# remove any previously-existing temp file from a previous run
if [[ -f "$temp_path/config" ]]; then
    rm -rf "$temp_path" || die "Unable to delete $temp_path"
fi

cd $input_dir

# ensure we've got no changes to commit before starting
git status|grep "nothing to commit" > /dev/null 2>&1 || die "Uncommitted changes detected in $input_dir"

# remember current branch so we can switch back when done
orig_branch=$(git rev-parse --abbrev-ref HEAD)

echo "Creating directory $output_dir"

if [[ ! -d "../$output_dir" ]]; then
    mkdir ../$output_dir || die "Unable to create directory"
fi

# make sure the .git dir is restored on exit
pushd . > /dev/null 2>&1
trap restore_dotgit EXIT

# no tags at command line, so use all tags
if [[ -z $tags ]]; then
    tags=($(git tag -l))
fi

numtags=${#tags[@]}

tagnum=0
for tagname in "${tags[@]}"; do
    let "tagnum++"

    echo "Copying source tree for tag $tagname [$tagnum/$numtags]"

    git checkout $tagname > /dev/null 2>&1 || die "Unable to check out tag $tagname"

    mv .git $temp_path
    cp -r . ../$output_dir/$tagname > /dev/null 2>&1 || die "Unable to copy source tree"
    mv $temp_path .git

    # save the commit message as a .txt file, keeping it if it's not the same as the tag
    git log --format=%B -n 1 HEAD | sed '$ d' > ../$output_dir/$tagname.txt
    msg=$(cat ../$output_dir/$tagname.txt)
    if [ "$msg" = "$tagname" ]; then
        rm ../$output_dir/$tagname.txt
    fi
done

git checkout $orig_branch > /dev/null 2>&1 || die "Unable to check out $orig_branch"

cd ..

echo "Done"
