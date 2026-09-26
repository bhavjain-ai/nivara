#!/bin/sh

# Xcode Cloud custom build script — runs automatically right after Xcode
# Cloud clones the repo, before it tries to resolve/build anything.
#
# This repo deliberately doesn't commit NivaraPatient.xcodeproj (see
# ios/NivaraPatient/README.md — hand-maintained Xcode project files are
# brittle and easy to corrupt); it's generated from project.yml via
# XcodeGen instead. That's fine for local development (README documents
# running `xcodegen generate` by hand), but Xcode Cloud clones straight
# from git with no local generation step, so without this script it fails
# immediately with "Project NivaraPatient.xcodeproj does not exist".
#
# Xcode Cloud's macOS build images come with Homebrew preinstalled, so no
# extra environment setup is needed beyond this.

set -e

echo "Installing XcodeGen…"
brew install xcodegen

echo "Generating NivaraPatient.xcodeproj…"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios/NivaraPatient"
xcodegen generate

echo "Done."
