{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/usb-Samsung_Flash_Drive_0358123090004561-0:0";
    content = {
      type = "gpt";
      partitions = {
        ESPLIVE = {
          size = "1G";
          type = "EF00";
          uuid = "8f3f3389-df5a-4742-99b7-fc1052768cb3";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-i" "53776b66" ];
            mountpoint = "/boot";
            mountOptions = [ "noatime" "fmask=0077" "umask=0077" ];
          };
        };

        root-live = {
          size = "100%";
          uuid = "d88eaf61-1e9e-4a2c-b4f1-ba6fae763f03";
          content = {
            type = "luks";
            name = "root-live-crypt";
            extraFormatArgs = [ "--uuid" "360d3dbf-af21-4ae8-87e5-40607f141bfa" ];
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [ "-U" "578d9057-5e0e-4652-9979-ca5c7de6ae92" ];
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
}
