# Pure projection of the zfs x linux compatibility matrix from a given nixpkgs:
# one row per (kernel, zfs) pair whose zfs kernel module is NOT broken, with the
# version of each attached. No policy here (no floor, no "newest") -- that lives
# in bin/bump-kernel. `meta.broken` on linuxKernel.packages.<K>.<zfs> is
# nixpkgs' own kernel/zfs support assertion.
#
#   import ./zfs-kernel-matrix.nix { inherit pkgs; }
#   => [ { kernel = { attr = "linux_6_18"; version = "6.18.38"; lts = true; };
#          zfs    = { attr = "zfs_2_4";   version = "2.4.3"; }; } ... ]
# `lts` is nixpkgs' kernel.isLTS (long-term-support series); the policy of
# preferring it lives in bin/bump-kernel, not here.
#
# Exposed as `flake.lib.zfsKernelMatrix`. Test directly (or via the flake, using
# `(builtins.getFlake (toString ./.)).lib.zfsKernelMatrix`):
#   nix eval --impure --json --expr 'import ./lib/zfs-kernel-matrix.nix {
#     pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
#   }'
{ pkgs }:
let
  inherit (pkgs) lib;
  kp = pkgs.linuxKernel.packages;

  # Stable numbered series only (excludes zfs_unstable).
  zfsAttrs = lib.filter (n: builtins.match "zfs_[0-9]+_[0-9]+" n != null)
    (builtins.attrNames pkgs);
  kernelAttrs = lib.filter (n: builtins.match "linux_[0-9]+_[0-9]+" n != null)
    (builtins.attrNames kp);

  # Rows for one kernel attr: one per zfs whose module builds against it. The
  # whole thing is tryEval-guarded so a kernel attr that fails to eval (removed /
  # EOL upstream) contributes nothing rather than aborting the projection.
  rowsFor = kn:
    let
      r = builtins.tryEval (
        let
          kernelVersion = kp.${kn}.kernel.version;
          kernelLTS = kp.${kn}.kernel.isLTS or false;
        in lib.concatMap
          (z:
            let ok = builtins.tryEval (
              (kp.${kn} ? ${z}) && (kp.${kn}.${z}.meta.broken or true) == false);
            in lib.optional (ok.success && ok.value) {
              kernel = { attr = kn; version = kernelVersion; lts = kernelLTS; };
              zfs = { attr = z; version = pkgs.${z}.version; };
            })
          zfsAttrs);
    in if r.success then r.value else [ ];
in
lib.concatMap rowsFor kernelAttrs
