#!/bin/sh
# Downloads and installs zyguard (zyguard, zyguard-tui, zyguard-server) on
# Linux from the MakPr016/zyguard-releases GitHub releases. The Linux
# counterpart of install.ps1, published at the root of the same repo:
#
#   curl -fsSL https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.sh | sh
#
# Every release so far is a pre-release, which GitHub's releases/latest link
# skips, so the newest release is looked up through the API. The tarball is
# checked against the SHA-256 digest GitHub records for the asset before
# anything is unpacked. Installs to ~/.local/bin; running it again upgrades
# in place.
#
# Optional environment variables:
#   ZYGUARD_VERSION       a release to install instead of the newest (0.1.0-beta.2.8)
#   ZYGUARD_INSTALL_DIR   where to install instead of ~/.local/bin
#   GITHUB_TOKEN          used for the API lookup if set (avoids the 60/hour anonymous limit)
#
# Everything is inside main(), called on the last line, so a download cut off
# halfway through `curl | sh` runs nothing.

set -eu

main() {
    repo="MakPr016/zyguard-releases"
    bins="zyguard zyguard-tui zyguard-server"
    dir="${ZYGUARD_INSTALL_DIR:-$HOME/.local/bin}"

    say() { printf '%s\n' "$*"; }
    die() { printf 'zyguard install: %s\n' "$*" >&2; exit 1; }
    need() { command -v "$1" >/dev/null 2>&1 || die "needs '$1' on PATH"; }

    [ "$(uname -s)" = "Linux" ] || die "this script is for Linux; on Windows use install.ps1"
    case "$(uname -m)" in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        *) die "no prebuilt binary for $(uname -m); build from source with cargo" ;;
    esac
    asset="zyguard-linux-$arch.tar.gz"

    need curl
    need tar
    if command -v sha256sum >/dev/null 2>&1; then
        sha256() { sha256sum "$1" | cut -d' ' -f1; }
    elif command -v shasum >/dev/null 2>&1; then
        sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
    else
        die "needs sha256sum or shasum to verify the download"
    fi

    api="https://api.github.com/repos/$repo/releases"
    if [ -n "${ZYGUARD_VERSION:-}" ]; then
        url="$api/tags/v${ZYGUARD_VERSION#v}"
    else
        url="$api?per_page=1" # newest first, pre-releases included
    fi
    set -- -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: zyguard-install"
    [ -n "${GITHUB_TOKEN:-}" ] && set -- "$@" -H "Authorization: Bearer $GITHUB_TOKEN"
    json=$(curl "$@" "$url") || die "couldn't query $url"

    # No jq dependency: split the JSON so each field sits on its own line, then
    # take the first tag_name and the digest/download URL of the asset whose
    # name matches. GitHub lists an asset's "digest" before its
    # "browser_download_url", both after its "name".
    fields=$(printf '%s' "$json" | tr ',{}' '\n\n\n')
    tag=$(printf '%s\n' "$fields" | sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
    [ -n "$tag" ] || die "no releases found on github.com/$repo"
    block=$(printf '%s\n' "$fields" | sed -n "/\"name\": *\"$asset\"/,/\"browser_download_url\"/p")
    [ -n "$block" ] || die "release $tag has no $asset"
    expected=$(printf '%s\n' "$block" | sed -n 's/^ *"digest": *"sha256:\([0-9a-f]\{64\}\)".*/\1/p' | head -n 1)
    download=$(printf '%s\n' "$block" | sed -n 's/^ *"browser_download_url": *"\([^"]*\)".*/\1/p' | head -n 1)
    [ -n "$expected" ] || die "GitHub lists no SHA-256 digest for $asset in $tag; not installing an unverified download"
    [ -n "$download" ] || die "release $tag has no download URL for $asset"

    say "Installing zyguard $tag ($arch) to $dir"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM
    curl -fsSL -H "User-Agent: zyguard-install" -o "$tmp/$asset" "$download" || die "download failed: $download"
    actual=$(sha256 "$tmp/$asset")
    [ "$actual" = "$expected" ] || die "SHA-256 mismatch for $asset (expected $expected, got $actual); nothing was installed"

    mkdir -p "$tmp/unpacked"
    tar -xzf "$tmp/$asset" -C "$tmp/unpacked"
    for b in $bins; do
        [ -f "$tmp/unpacked/$b" ] || die "$asset is missing $b; nothing was installed"
    done
    mkdir -p "$dir"
    # Install via a temp name + rename so a running copy keeps its old inode
    # instead of failing with "text file busy".
    for b in $bins; do
        cp "$tmp/unpacked/$b" "$dir/.$b.new"
        chmod 755 "$dir/.$b.new"
        mv -f "$dir/.$b.new" "$dir/$b"
    done

    case ":$PATH:" in
        *":$dir:"*) ;;
        *) say "" && say "$dir is not on your PATH. Add it with:" && say "  echo 'export PATH=\"$dir:\$PATH\"' >> ~/.bashrc && . ~/.bashrc" ;;
    esac

    # wgpu loads the Vulkan loader at runtime; without it nothing can run.
    if ! { ldconfig -p 2>/dev/null | grep -q 'libvulkan\.so\.1'; } \
        && ! ls /usr/lib*/libvulkan.so.1 /usr/lib/*-linux-gnu/libvulkan.so.1 >/dev/null 2>&1; then
        say ""
        say "warning: libvulkan.so.1 (the Vulkan loader) was not found. zyguard needs it plus a GPU driver:"
        say "  Debian/Ubuntu:       sudo apt install libvulkan1 mesa-vulkan-drivers"
        say "  Amazon Linux/Fedora: sudo dnf install vulkan-loader mesa-vulkan-drivers"
        say "  NVIDIA (e.g. AWS g4dn/g5/g6): the NVIDIA driver package ships the Vulkan driver"
    fi

    say ""
    say "Installed zyguard $tag. Start the chat UI with:  zyguard-tui"
    say "Or the HTTP API with:                        zyguard-server   (ZYGUARD_HOST / ZYGUARD_PORT, default 0.0.0.0:8080)"
}

main "$@"
