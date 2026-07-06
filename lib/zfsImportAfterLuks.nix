# Factory: order each ZFS boot pool's import after the LUKS devices backing it
# are decrypted -- a dependency the NixOS zfs module doesn't wire itself.
# Returns a `boot.initrd.systemd.services` fragment; call it from hardware.nix,
# next to where the disks are declared:
#
#   systemd.services = flake.lib.zfsImportAfterLuks {
#     luksDevices = [ "<uuid>" ... ];   # LUKS partition UUIDs backing the pools
#     zfsPools = [ "root-pool" ];
#   };
{ lib, escapeSystemdPath }:
{
  luksDevices,
  zfsPools,
}:
let
  unit = uuid: "systemd-cryptsetup@${escapeSystemdPath uuid}.service";
  units = map unit luksDevices;
in
  # zfs-import-<pool>.service is NixOS-defined, so this plain definition merges
  # its after/requires into the existing unit.
  lib.genAttrs (map (pool: "zfs-import-${pool}") zfsPools) (_: {
    after = units;
    requires = units;
  })
