#!/usr/bin/env bash
set -eu
cp -R "$(dirname "$0")/files/." .
# Pronto reads the Base commit from git, so each run starts from one clean commit.
git init -q
git add -A
git -c user.email=eval@example.com -c user.name=eval commit -q -m "start"
