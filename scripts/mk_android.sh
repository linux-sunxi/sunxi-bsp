#!/bin/sh

die() {
	echo "$*" >&2
	exit 1
}

[ -s "./chosen_board.mk" ] || die "please run ./configure first."

set -e

. ./chosen_board.mk

# Board-independent configuration variables
REPO_TOOL_URL="https://dl-ssl.google.com/dl/googlesource/git-repo/repo"
REPO_MANIFEST="git://github.com/CyanogenMod/android.git"
REPO_LOCAL_MANIFEST="http://turl.linux-sunxi.org/local_manifest_jb.xml"
REPO_BRANCH="jellybean"

ANDROID_REPO_DIR="$PWD/android"
PATH="$ANDROID_REPO_DIR:$PATH"

# Do we need to create the repo dir?
if [ ! -d "$ANDROID_REPO_DIR" ]; then
    mkdir "$ANDROID_REPO_DIR"
fi

# Do we have the repo tool installed already?
if [ ! -x "$ANDROID_REPO_DIR/repo" ]; then
    wget "$REPO_TOOL_URL" -O "$ANDROID_REPO_DIR/repo" || die "error downloading repo tool"
    chmod +x "$ANDROID_REPO_DIR/repo"
fi

cd "$ANDROID_REPO_DIR"

# Update/download repo
repo init -u "$REPO_MANIFEST" -b "$REPO_BRANCH" || die "error initializing repo"
wget "$REPO_LOCAL_MANIFEST" -O "$ANDROID_REPO_DIR/.repo/local_manifest.xml" || die "error downloading local manifest"
repo sync || die "error syncing repo"

# And keep repo tool up to date
cp "$ANDROID_REPO_DIR/.repo/repo/repo" "$ANDROID_REPO_DIR/.repo/repo/repo"

# If we weren't invoked as "make android update" we should build the system
if [ ! "$1" = "update" ]; then
    . build/envsetup.sh
    brunch "$BOARD"
fi
