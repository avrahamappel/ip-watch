#!/usr/bin/env bash

nix flake update

cargo update

nix build --no-link
