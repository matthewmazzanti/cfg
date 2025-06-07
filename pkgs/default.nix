{ pkgs, vim-easyclip, ... }:
pkgs.callPackage ./nvim { vim-easyclip = vim-easyclip; }
