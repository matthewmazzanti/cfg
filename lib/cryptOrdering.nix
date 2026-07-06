# Factory: wire a host's LUKS unlock into the initrd boot ordering. Returns a
# `boot.initrd.systemd.services` fragment -- call it from hardware.nix, where
# the disks are declared, so the linkage reads locally:
#
#   systemd.services = flake.lib.cryptOrdering {
#     luksDevices = [ "<uuid>" ... ];   # LUKS partition UUIDs
#     zfsPools = [ "root-pool" ];        # boot pools to gate; omit on non-ZFS
#   };
#
#   - each device's unlock waits for systemd-vconsole-setup, so the virtual
#     console is fully set up before the passphrase prompt renders and the
#     prompt isn't garbled by the console reflowing mid-text (having the keymap,
#     e.g. CapsLock->Escape, active is a bonus). Covers the interactive prompt
#     and the keyfile console fallback.
#   - each ZFS boot pool's import waits for every unlock
{ lib, escapeSystemdPath }:
{
  luksDevices,
  zfsPools ? [ ],
}:
let
  unit = uuid: "systemd-cryptsetup@${escapeSystemdPath uuid}.service";
  units = map unit luksDevices;
in
  # The cryptsetup units are generated at runtime from /etc/crypttab, so order
  # them via a drop-in rather than a full unit definition.
  lib.genAttrs units (_: {
    overrideStrategy = "asDropin";
    after = [ "systemd-vconsole-setup.service" ];
    wants = [ "systemd-vconsole-setup.service" ];
  })
  # zfs-import-<pool>.service is NixOS-defined, so this plain definition merges
  # its after/requires into the existing unit (empty set when no pools given).
  // lib.genAttrs (map (pool: "zfs-import-${pool}") zfsPools) (_: {
    after = units;
    requires = units;
  })
