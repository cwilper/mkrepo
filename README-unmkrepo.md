# unmkrepo

Makes a series of directories out of a git repository, one for each tag.

This has the opposite effect of [mkrepo](README.md).

**Usage:**

    unmkrepo.sh input-dir output-dir [tag1 [tag2 [etc..]]]

**Where:**

* ```input-dir``` is the directory containing the repository.
* ```output-dir``` is the directory where the directories should be created.
* ```tags``` are the set of tags to copy. If unspecified, all tags will
  be copied.

## Basic Operation

When you run this script, all tags (or the specified subset) from the
repository in ```input-dir``` will be checked out, and the state of the
source tree for each will be copied in to a subdirectory of ```output-dir```.

If the commit message for any of the tagged commits consists of anything
other than the tag name itself, a ```.txt``` file will be written alongside
the subdirectory, with the same base name.
