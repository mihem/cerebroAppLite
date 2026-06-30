#!/usr/bin/env bash
set -euo pipefail

reports_url="https://raw.githubusercontent.com/mihem/attic/main/reports/README.md"
cache_url="https://osmzhlab.uni-muenster.de:4949/r-packages"
cache_key="r-packages:Op7Q3XME8az4XNcP1clupGw4ZbuaguBw+sUziweqpTY="

latest_date="$({
  curl --fail --location --silent --show-error "$reports_url" |
    grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' |
    sort -u |
    tail -n 1
})"

if [[ -z "$latest_date" ]]; then
  echo "Could not determine latest osmzhlab cache date from $reports_url" >&2
  exit 1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "NIX_CONFIG<<EOF"
    printf 'extra-substituters = %s\n' "$cache_url"
    printf 'extra-trusted-public-keys = %s\n' "$cache_key"
    echo "EOF"
  } >> "$GITHUB_ENV"
else
  export NIX_CONFIG="extra-substituters = $cache_url
extra-trusted-public-keys = $cache_key"
fi

if [[ -f default.nix ]]; then
  perl -0pi -e "s#https://github.com/rstats-on-nix/nixpkgs/archive/[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz#https://github.com/rstats-on-nix/nixpkgs/archive/$latest_date.tar.gz#g" default.nix
fi

echo "Using osmzhlab Attic cache date: $latest_date"
