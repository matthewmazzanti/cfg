#! @bash@/bin/sh -e

target=/boot # Target directory

while getopts "t:c:d:g:" opt; do
    case "$opt" in
        d) target="$OPTARG" ;;
        *) ;;
    esac
done

copyForced() {
    local src="$1"
    local dst="$2"
    cp $src $dst.tmp
    mv $dst.tmp $dst
}

# Call the extlinux builder
"@extlinuxConfBuilder@" "$@"

# Add the firmware files
fwdir=@firmware@/share/raspberrypi/boot/
copyForced $fwdir/bootcode.bin  $target/bootcode.bin
# Add raspberry pi 4 files (Removed non-pi4 files - may need to readd)
copyForced $fwdir/fixup4.dat    $target/fixup4.dat
copyForced $fwdir/fixup4cd.dat  $target/fixup4cd.dat
copyForced $fwdir/fixup4db.dat  $target/fixup4db.dat
copyForced $fwdir/fixup4x.dat   $target/fixup4x.dat
copyForced $fwdir/start4.elf    $target/start4.elf
copyForced $fwdir/start4cd.elf  $target/start4cd.elf
copyForced $fwdir/start4db.elf  $target/start4db.elf
copyForced $fwdir/start4x.elf   $target/start4x.elf

# A more generic implementation would include more of the DTB
copyForced $fwdir/bcm2711-rpi-4-b.dtb  $target/bcm2711-rpi-4-b.dtb
copyForced @armstubs@/armstub8-gic.bin $target/armstub8-gic.bin

# Add the uboot file
copyForced @uboot@/u-boot.bin $target/u-boot-rpi.bin

# Add the config.txt
copyForced @configTxt@ $target/config.txt
