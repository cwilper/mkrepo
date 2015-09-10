# mkrepo

Makes a tagged git repository out of a series of input directories
representing significant states of a source tree.

**Usage:**

    mkrepo.sh input-dir output-dir [include-dir]

**Where:**

* ```input-dir``` is the directory containing the input directories.
* ``output-dir`` is the directory where the repository should be created.
  It must not yet exist.
* ```include-dir``` is an optional directory containing a set of files to
  be included in each commit.

## Basic Operation

When you run this script, all directories within ```input-dir``` will be
traversed in alphanumeric order, and a new commit will be created for each.
Each commit will be tagged using the directory name.

Prior to each commit, a scan will be performed for empty directories.
For each found, an empty ```.gitignore``` file will be placed within,
ensuring that the directory's existence will be recorded in git.

## Advanced Use

### Custom Commit Messages

By default, the commit message for each directory will be identical to
the directory/tag name. But if a file exists in ```input-dir``` with a
```.txt``` extension and the same base name of the directory, the
content of that file will be used as the commit message instead.

### Non-Linear History 

By default, each commit will be created as a child of the previous commit
on the ```master``` branch. But if a file exists in ```input-dir``` with a 
```.branch``` extension and the same base name of the directory, a new
branch will be created instead, and the commit will be created and tagged
on it, after which the new branch ref will be deleted. The parent of this
commit will be the ref whose name is found in the ```.branch``` file.

This functionality is useful, for example, when a bugfix release is made
for an older version of the software which has already been used as the
baseline for a newer version. See the demo for an example.

### Non-Alphanumeric Ordering

If you want tag names that occur in non-alphanumeric order, you may
prepend your directory names with a number to ensure correct processing
order, e.g.:

    input-dir/01-very-first
    input-dir/02-second

Then rename the tags after the repository is created, e.g:

    mkrepo.sh input-dir output-dir
    cd output-dir
    git tag very-first 01-very-first
    git tag -d 01-very-first
    git tag second 02-second
    git tag -d second
