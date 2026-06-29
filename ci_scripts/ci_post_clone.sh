#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud runs this automatically right after cloning the repository.
#
# Pre-approve the Swift Package build-tool plugin so the headless build doesn't
# fail with "Plugin OpenAPIGenerator must be enabled before it can be used".
# A headless CI build has no interactive "trust" prompt, so this is the only
# way to let swift-openapi-generator's plugin run.
#
# Scope & safety:
#   - This only writes a default inside Xcode Cloud's ephemeral, throwaway build
#     VM. It does NOT touch your local machine.
#   - Safety comes from the committed Package.resolved pinning exact dependency
#     versions, so the plugin that runs is the vetted version we expect.
#   - We deliberately do NOT skip macro validation — this project uses no macros.
#
# Note: the key is misspelled ("Validatation") on purpose — that is the actual
# key Apple ships, so the correctly-spelled version does NOT work.

set -e

defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

echo "Pre-approved Swift Package build-tool plugin fingerprint validation."
