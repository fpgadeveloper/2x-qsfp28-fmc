# PetaLinux

PetaLinux can be built for the Zynq UltraScale+ and Versal targets of this reference design
with the cross-platform `build.py` runner at the root of the repository. The resulting image
contains the same QSFP28 drivers, kernel patches and test tools as the [Yocto](yocto) image.

```{attention}
**The PetaLinux flow is being retired for this repository.** 2025.2 is the last tool
version for which the PetaLinux flow is supported; from the next version onward, Linux
images are built with the [Yocto](yocto) flow only. The MicroBlaze-based KCU116 targets
have no PetaLinux image (an unsupported classic-MicroBlaze BSP remains in
`PetaLinux/bsp/kcu116/` for reference); use the [echo server](echo_server) on those.
```

## Requirements

* A physical or virtual machine running one of the [supported Linux distributions], with
  Vivado 2025.2 and PetaLinux Tools 2025.2 installed. PetaLinux cannot be built on Windows.
* The license for the target's Ethernet MAC IP (needed to build the bitstream).
* The hardware listed in [requirements](requirements), and a microSD card.

## How to build

The build runner locates and sources the PetaLinux and Vivado settings itself, so there
is no need to source them by hand. See the [build instructions](build_instructions) for
the full description of the runner.

1. Clone the repository and `cd` into it:
   ```
   git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
   cd 2x-qsfp28-fmc
   ```
2. Build the PetaLinux image for your target, replacing `<target>` with one of the target
   labels from the [build instructions](build_instructions.md#target-designs):
   ```
   ./build.sh petalinux --target <target>
   ```
   This first builds the Vivado project and exports its hardware, if that has not been
   done already.
3. Optionally gather the boot files into a zip:
   ```
   ./build.sh package --target <target>
   ```

The output products are in `PetaLinux/<target>/images/linux/` (`BOOT.BIN`, `image.ub`,
`boot.scr`, `rootfs.tar.gz`, …), and the zip is
`bootimages/2x-qsfp28-fmc_<target>_petalinux-2025-2.zip`, with the boot files arranged in
`boot/` and `root/` folders.

## What is in the image

| Item | Value |
|------|-------|
| Hostname | `<board>-qsfp-2025-2` (for example `zcu102-qsfp-2025-2`) |
| Login | user `petalinux`; you set its password at the first login (it has `sudo` rights) |
| Root filesystem | ext4 on the second SD card partition (`/dev/mmcblk0p2`) |
| Kernel command line (ZynqMP) | `earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait cma=512M` |
| Kernel command line (Versal) | `console=ttyAMA0 earlycon=pl011,mmio32,0xFF000000,115200n8 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait rootfs=ext4 uio_pdrv_genirq.of_id=generic-uio cma=1536M` |
| Test tools | `qsfp-loopback-test`, `ethtool`, `iperf3`, `iproute2` (`ip`), `i2c-tools`, `phytool`, kernel `pktgen` module |
| Remote access | OpenSSH server |

The QSFP28 drivers and fixes in the image (kernel patches, device-tree overlays) are listed
in [advanced](advanced.md#linux-bsps).

## Boot from SD card

### Prepare the SD card

The PetaLinux image boots from a card with two partitions: a FAT32 `boot` partition and an
ext4 `root` partition.

1. Plug the SD card into your Linux computer and find its device name, for example with
   `lsblk -o NAME,SIZE,RM,TYPE` before and after inserting it. It will be something like
   `/dev/sdX`; replace `X` in the instructions below.

```{warning}
Do not continue until you are certain that you have found the correct device name for the
SD card. If you use the wrong device name in the following steps, you risk losing data on
one of your hard drives.
```

2. Partition and format the card:
   * Run `sudo fdisk /dev/sdX`.
   * Make the `boot` partition: type `n` for a new partition, `p` for primary, accept the
     default partition number and first sector, and type `+1G` for the last sector.
   * Make it bootable by typing `a`.
   * Make the `root` partition: type `n`, `p`, and accept the defaults.
   * Write the partition table by typing `w`.
   * Format the partitions:
     ```
     sudo mkfs.vfat -F 32 -n boot /dev/sdX1
     sudo mkfs.ext4 -L root /dev/sdX2
     ```
3. Mount the partitions (for example on `/media/user/boot` and `/media/user/root`) and copy
   the files — either from `PetaLinux/<target>/images/linux/`, or from the `boot/` and
   `root/` folders of the PetaLinux zip:
   ```
   sudo cp BOOT.BIN boot.scr image.ub /media/user/boot/
   sudo tar xzf rootfs.tar.gz -C /media/user/root/
   sync
   ```
4. Unmount both partitions and eject the card.

### Boot

1. Plug the SD card into the target board.
2. Set the board to boot from SD:
   * **VCK190:** DIP switch SW1 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU102, ZCU106:** DIP switch SW6 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU111, ZCU208, ZCU216:** see the boot-mode switch table in the board's user guide
3. Fit the [2x QSFP28 FMC] on the target's FMC connector (FMCP1 on the VCK190, HPC0 on the
   ZCU102/ZCU106, FMCP on the RFSoC boards) and plug in the cable or modules for your test.
4. Connect the USB-UART to your PC and open a terminal at 115200 baud (see
   [UART terminal](#uart-terminal)).
5. Optionally connect the board's own Ethernet port to your network, for SSH access.
6. Power up the board.

The boot passes through the boot loader and U-Boot, then the kernel. On the VCK190 U-Boot
first enables the FMC VADJ rail (1.5 V). With a cable between the two QSFP28 ports, the
ports come up during boot. The PetaLinux and Yocto images print the same driver messages;
for example on a ZCU102:

```
[    2.339191] si5324 0-0068: si5328 probed
[    2.405228] si5324 0-0068: si5328 probe successful
...
xilinx_axienet 80060000.l_ethernet eth1: HSE MAC link up at 40000 Mbps (0 recovery resets)
xilinx_axienet 80080000.l_ethernet eth2: HSE MAC link up at 40000 Mbps (0 recovery resets)
```

and on the VCK190:

```
xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 100000 (link monitored)
xilinx_axienet 80000000.mrmac eth0: MRMAC link up at 100000 (0 recovery resets)
xilinx_axienet 80010000.mrmac eth1: MRMAC setup at 100000 (link monitored)
xilinx_axienet 80010000.mrmac eth1: MRMAC link up at 100000 (0 recovery resets)
```

### Log in

At the console, log in as `petalinux`. On the first login you are asked to choose a
password:

```
zcu106-qsfp-2025-2 login: petalinux
You are required to change your password immediately (administrator enforced).
New password:
Retype new password:
```

Use `sudo` for commands that need root (the self-test, `ethtool -G`, `ip` configuration).
Once the password is set you can also log in over SSH on the board's own Ethernet port
(`end0`, see [interface names](linux_usage.md#interface-names)), which obtains its address by
DHCP if your network provides one.

## Boot via JTAG

```{tip}
You need to install the cable drivers before being able to boot via JTAG.
Note that the Vitis installer does not automatically install the cable drivers, it must be done separately.
For instructions, read section
[installing the cable drivers](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Installing-Cable-Drivers)
from the Vivado release notes.
```

```{warning}
The root filesystem is on the SD card, so you must still prepare and insert the SD card
before booting via JTAG. Without it, the boot hangs at a message similar to:
`Waiting for root device /dev/mmcblk0p2...`
```

1. Prepare the SD card as [described above](#prepare-the-sd-card) and insert it.
2. Set the board to JTAG boot mode (VCK190: SW1 = 1111; ZCU102/ZCU106: SW6 = 1111; RFSoC
   boards: see the board's user guide), connect the FMC, the USB-UART and the USB-JTAG cable,
   and power up.
3. From the PetaLinux project directory, download the bitstream / device image, the boot
   firmware and the kernel:
   ```
   cd PetaLinux/<target>
   petalinux-boot jtag --kernel --fpga
   ```

## UART terminal

Connect with a baud rate of 115200 (8N1).

* **Windows:** find the COM port of the USB-UART in Device Manager and use a terminal
  emulator such as [PuTTY](https://www.putty.org/).
* **Linux:** list the serial devices with `dmesg | grep tty`, then for example
  `sudo screen /dev/ttyUSB1 115200`. The boards present several USB-UART interfaces; on the
  VCK190 the Linux console is on the second interface (typically `/dev/ttyUSB1`), on the
  ZCU102 and ZCU106 it is on the first one (typically `/dev/ttyUSB0`).

## Using the QSFP28 ports

The QSFP28 ports are exercised exactly as in the Yocto image: see
[Testing under Linux](linux_usage) for the interface names, the link messages, the
`qsfp-loopback-test` self-test, `ethtool` and its counters, `iperf3` and the expected results.

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
