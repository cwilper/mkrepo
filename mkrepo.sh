#!/bin/bash

## # mkrepo
##
## Makes a tagged git repository out of a series of input directories
## representing significant states of a source tree.
##
## For a script that does the opposite, see
## [unmkrepo](https://github.com/cwilper/mkrepo/blob/master/README-unmkrepo.md).
##
## **Usage:**
##
##     mkrepo.sh input-dir output-dir [include-dir]
##
## **Where:**
##
## * ```input-dir``` is the directory containing the input directories.
## * ```output-dir``` is the directory where the repository should be created.
##   It must not yet exist.
## * ```include-dir``` is an optional directory containing a set of files to
##   be included in each commit.
##
## ## Basic Operation
##
## When you run this script, the directories within ```input-dir``` will be
## visited, and a new commit will be created for each. Each commit will be
## tagged using the directory name. The order of processing is alphanumerical
## by default, but may be customized.
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
## If you want directories to be processed in non-alphanumerical order,
## you may create a file in the input directory called ```mkrepo.order```
## containing a list of the directories/tags, one per line, in the order you
## want them processed.

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
    echo "mkrepo v1.1.0 from https://github.com/cwilper/mkrepo"
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

cd $input_dir
if [[ -f "mkrepo.order" ]]; then
    tags=($(cat mkrepo.order))
else
    tags=($(ls|grep -v \.txt$|grep -v \.branch$|grep -v ^mkrepo.order$|sort))
fi
cd ..

echo "Creating repository at $output_dir"

numtags=${#tags[@]}

tagnum=0
for tagname in "${tags[@]}"; do
    let "tagnum++"

    # skip files; we only want dirs
    if [[ -f "$input_dir/$tagname" ]]; then
        continue
    fi

    # if output-dir exists, move the repo aside and nuke the dir first
    if [[ -d $output_dir ]]; then
        cd "$output_dir"

        # create a temporary branch if needed
        branch_file="../$input_dir/$tagname.branch"
        if [[ -f $branch_file ]]; then
            parent_branch=$(cat $branch_file)
            echo "Adding $tagname [$tagnum/$numtags] as branched child of $parent_branch"
            git checkout -b tmp $parent_branch > /dev/null 2>&1 || die "Unable to create tmp branch from $parent_branch"
        else
            echo "Adding $tagname [$tagnum/$numtags] as latest child of master"
        fi

        cd ..

        mv "$output_dir/.git" /tmp/mkrepo.tmp
        rm -rf "$output_dir"
    else
        echo "Adding $tagname [$tagnum/$numtags] as root commit on master"
    fi

    # copy everything in $input_dir/$tagname into output-dir
    cp -r "$input_dir/$tagname" "$output_dir" || die "Unable to copy $input_dir/$tagname to $output_dir from $(pwd)"

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

    commit_args=(commit)

    if [[ -f "../$input_dir/$tagname.author" ]]; then
        author_file="../$input_dir/$tagname.author"
    else
        author_file="../$input_dir/author"
    fi
    if [[ -f $author_file ]]; then
        commit_args+=(--author="$(cat $author_file)")
    fi

    unset GIT_COMMITTER_EMAIL
    unset GIT_COMMITTER_NAME
    if [[ -f "../$input_dir/$tagname.committer" ]]; then
        committer_file="../$input_dir/$tagname.committer"
    else
        committer_file="../$input_dir/committer"
    fi
    if [[ -f $committer_file ]]; then
        export GIT_COMMITTER_EMAIL=$(sed 's/.*<\(.*\)>$/\1/' $committer_file)
        export GIT_COMMITTER_NAME=$(sed 's/\(.*\) <.*/\1/' $committer_file)
    fi

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE
    date_file="../$input_dir/$tagname.date"
    if [[ -f $date_file ]]; then
        date_value=$(cat $date_file)
        export GIT_AUTHOR_DATE="$date_value"
        export GIT_COMMITTER_DATE="$date_value"
    else
        if [[ -f "../$input_dir/$tagname.author-date" ]]; then
            export GIT_AUTHOR_DATE=$(cat "../$input_dir/$tagname.author-date")
        fi
        if [[ -f "../$input_dir/$tagname.committer-date" ]]; then
            export GIT_COMMITTER_DATE=$(cat "../$input_dir/$tagname.committer-date")
        fi
    fi

    message_file="../$input_dir/$tagname.txt"
    if [[ -f $message_file ]]; then
        commit_args+=(-F $message_file)
    else
        commit_args+=(-m $tagname)
    fi

    git "${commit_args[@]}" > /dev/null 2>&1 || die "Error committing"

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
