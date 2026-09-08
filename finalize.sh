#!/usr/bin/env bash
# Finalize current flexipatch tree into output directory, then make that tree
# working copy of finalizer branch without checking out branch files over it.
set -euo pipefail

FINALIZER_BRANCH=${FINALIZER_BRANCH:-finalized}

usage() {
    printf 'Usage: %s [OUTPUT_DIRECTORY]\n' "${0##*/}"
    printf 'Run from repository root. Default output directory is temporary.\n'
    printf 'Supplied OUTPUT_DIRECTORY must not exist and must be outside repository.\n'
}

if (($# > 1)); then
    usage >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel) || {
    printf 'Not inside Git repository.\n' >&2
    exit 1
}
repo=$(realpath "$repo")
if [[ $(realpath .) != "$repo" ]]; then
    printf 'Run this script from repository root: %s\n' "$repo" >&2
    exit 1
fi

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    printf 'Refusing: repository has uncommitted changes.\n' >&2
    exit 1
fi

if ! git show-ref --verify --quiet "refs/heads/$FINALIZER_BRANCH"; then
    printf 'Finalizer branch does not exist: %s\n' "$FINALIZER_BRANCH" >&2
    exit 1
fi

if (($# == 0)); then
    output=$(mktemp -d "${TMPDIR:-/tmp}/flexipatch-finalized.XXXXXX")
    output_was_created=1
else
    output=$(realpath -m "$1")
    output_was_created=0
fi
if (( ! output_was_created )) && [[ -e $output ]]; then
    printf 'Output directory already exists: %s\n' "$output" >&2
    exit 1
fi
if [[ $output == "$repo" || $output == "$repo"/* ]]; then
    printf 'Output directory must be outside repository: %s\n' "$output" >&2
    exit 1
fi

cleanup_output=1
cleanup() {
    if ((cleanup_output)); then
        rm -rf -- "$output"
    fi
}
trap cleanup EXIT

"$repo/flexipatch-finalizer.sh" --run --directory "$repo" --output "$output"

# Keep Git metadata; deleting it would make branch switch impossible.
find "$repo" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +
shopt -s dotglob nullglob
mv -- "$output"/* "$repo"/
shopt -u dotglob nullglob
rmdir -- "$output"
cleanup_output=0

# Move HEAD only; checking out branch files would overwrite finalized output.
git symbolic-ref HEAD "refs/heads/$FINALIZER_BRANCH"
printf 'Finalized tree installed. Switched HEAD to %s.\n' "$FINALIZER_BRANCH"
