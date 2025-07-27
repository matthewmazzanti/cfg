{ ... }: {
  fileSystems = {
    "/var/lib/samba" = {
      device = "root-pool/state/services/samba";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
    "/srv/files" = {
      device = "data-pool/share/files";
      fsType = "zfs";
      options = [ "noatime" "nodiratime" ];
    };
  };

  systemd.services.samba = {
    after = [ "var-lib-samba.mount" "srv-files.mount" ];
    requires = [ "var-lib-samba.mount" "srv-files.mount" ];
  };

  services.samba = {
    enable = true;
    openFirewall = false;
    nmbd.enable = false;
    winbindd.enable = false;

    settings = {
      global = {
        "interfaces" = "lo enp7s0";
        "bind interfaces only" = "yes";

        # Protocol and Transport Hardening
        "server min protocol"  = "SMB3_11";
        "client min protocol"  = "SMB3_11";
        "client signing"       = "mandatory";
        "server signing"       = "mandatory";
        "smb encrypt"          = "required";

        # Disable Legacy Protocols
        "disable netbios" = "yes";
        "smb ports"       = "445";
        "ntlm auth"       = "no";

        # Fully Disable Guest / Anonymous Access
        "map to guest"     = "never";
        "guest account"    = "nobody";
        "restrict anonymous" = "2";

        # Disable Browsing and Printer Exposure
        "disable spoolss" = "yes";
        "load printers"   = "no";
        "printing"        = "bsd";
        "printcap name"   = "/dev/null";

        # ACLs and permissions
        "valid users"          = "mmazzanti";
        "force group"          = "samba";
        "force user"           = "samba";
        "force create mode"    = "0660";
        "create mask"          = "0660";
        "force directory mode" = "0770";
        "directory mask"       = "0770";
        "inherit permissions"  = "yes";
        "inherit acls"         = "yes";
        "vfs objects"          = "acl_xattr";
        "unix extensions"      = "yes";
        "map acl inherit"      = "yes";

        # Fix samba setting +x for files
        "ea support"           = "yes";
        "nt acl support"        = "no";  # No Windows-style ACLs
        "dos filemode"          = "no";  # Prevent clients from chmod'ing via SMB
        "store dos attributes"  = "no";  # Don't store DOS metadata in xattrs
        "map archive"           = "no";  # Prevent `+x` reuse for archive bit
        "map hidden"            = "no";
        "map system"            = "no";

        # Performance?
        "write cache size" = "16777216";  # 1 MB
        "strict sync" = "no";
        "sync always" = "no";

        # Misc security defaults, override in shares
        "writeable"  = "no";
        "browseable" = "no";
      };

      files = {
        path = "/srv/files";
        writable  = "yes";
        browseable = "yes";
      };

      /*
      timemachine = {
        path = "/srv/timemachine";
        writable  = "yes";
        browseable = "no";

        # Time Machine–specific settings
        "unix extensions" = "no";
        "nt acl support" = "yes";
        "store dos attributes" = "yes";
        "ea support" = "yes";
        "fruit:aapl" = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "1099511627776";  # 1TiB
        "vfs objects" = "catia fruit streams_xattr";
      };
      */
    };
  };

  networking.firewall.allowedTCPPorts = [ 445 ];

  users.users = {
    samba = {
      isSystemUser = true;
      group = "samba";
      description = "Samba file share owner";
    };
    mmazzanti.extraGroups = [ "samba" ];
  };
  users.groups.samba = {};
}
