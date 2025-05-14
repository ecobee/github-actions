#!/bin/sh

# This script is simply a wrapper to a executable hard-committed on the GIT
# repo.
# The binary was built from repo [github.com/bazelbuild/buildtools.git] using
# the "main" branch (commit d9ed52af26ee7e03973f776739d46fd79742dc36). The
# bianry is statically linked (compiled in Go) and should run on most X86-64
# Linux platforms. (Maybe later, we could add other architectures if needed?)

# Run Buildifier in fix mode and print their names to standard error
script_path=$(dirname "$(realpath "$0")")
${script_path}/buildifier.x86-64.elf -v $@
