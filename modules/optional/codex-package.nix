{ pkgs }:

let
  rev = "93a9ed0a866099a230ed5146a5bb7d16fd5c9b14";
  unstable = import (builtins.fetchTarball {
    name = rev;
    url = "https://codeload.github.com/NixOS/nixpkgs/tar.gz/${rev}";
    sha256 = "1x2cili34ky3fcj7b0z7ivmr7mkv0szr8kfqkcwrhlfnbg4y147h";
  }) {
    localSystem.system = pkgs.stdenv.buildPlatform.system;
    crossSystem = if pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform then null else {
      inherit (pkgs.stdenv.hostPlatform) config;
    };
    config = { };
    overlays = [ ];
  };
in
unstable.codex
