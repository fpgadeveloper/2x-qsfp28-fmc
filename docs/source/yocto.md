# Yocto

The Yocto / EDF flow (AMD's Embedded Development Framework) is the announced successor to
PetaLinux and the recommended Linux flow for this design. It is built with the
cross-platform `build.py` runner at the root of the repository, and produces a Linux image
that drives the QSFP28 ports through the `xilinx_axienet` driver and the MCDMA datapath.

```{note}
For 2025.2 both the PetaLinux and Yocto flows are supported and produce an equivalent
image. From the next tool version onward, the PetaLinux flow for this repository will be
retired and Yocto will be the only supported Linux flow. The MicroBlaze-based KCU116
targets have no Linux flow (EDF does not support Linux on MicroBlaze) — they are supported
with the standalone application only.
```

The Yocto flow supports every Zynq UltraScale+ and Versal target:

| Target(s) | MAC | Link rate |
| --- | --- | --- |
| `vck190_fmcp1` | Versal Integrated MRMAC (hard block) | 2x 100G |
| `zcu111` | UltraScale+ Integrated 100G Ethernet (CMAC hard block) | 2x 100G |
| `zcu208`, `zcu216` | UltraScale+ Integrated 100G Ethernet (CMAC hard block) | 1x 100G (port 0) |
| `zcu102_hpc0`, `zcu106_hpc0` | 40G/50G Ethernet Subsystem (soft MAC) | 2x 40G |
| `zcu111_ss`, `zcu208_ss`, `zcu216_ss` | 40G/50G Ethernet Subsystem (soft MAC) | 2x 40G |

The MRMAC is supported by the stock `xilinx_axienet` driver (plus a link monitor added by
this design); for the ZynqMP targets the CMAC / 40G-50G subsystem support is added by
kernel patches carried in the board BSPs (`Yocto/bsp/<board>/meta-user/recipes-kernel/linux/`).

## Requirements

* A physical or virtual machine running one of the [supported Linux distributions] (for
  example Ubuntu 22.04 or 24.04). The Yocto flow cannot be built on Windows; Windows users
  can build the XSA on Windows and the Yocto image on a Linux machine or virtual machine.
* Vivado 2025.2 (for the XSA) and Vitis 2025.2 — the flow uses `xsct`/`sdtgen`, which
  ship with Vitis, to generate a System Device Tree from the Vivado XSA. The runner locates
  and sources both tools itself.
* [Google's repo tool](https://gerrit.googlesource.com/git-repo/) on your `PATH`, and the
  Yocto host packages, for example on Ubuntu:
  ```
  sudo apt-get install repo gawk wget git diffstat unzip texinfo gcc \
      build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
      xz-utils debianutils iputils-ping python3-git python3-jinja2 \
      python3-subunit zstd liblz4-tool file locales libacl1 bmap-tools
  ```
* Disk space: a Yocto workspace for one target takes in the order of 60 GB.
* The license for the target's Ethernet MAC IP (needed to build the bitstream).

## How to build

1. Clone the repository and `cd` into it:
   ```
   git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
   cd 2x-qsfp28-fmc
   ```
2. Build the Yocto image for your target, replacing `<target>` with one of the target
   labels listed in the [build instructions](build_instructions.md#target-designs):
   ```
   ./build.sh yocto --target <target>
   ```
   This builds the Vivado project and XSA first if they do not exist yet. The first build
   of a target downloads several GB of sources (`repo sync`) and runs bitbake from scratch,
   so it takes a while; subsequent builds are incremental. To build from a local
   sstate-cache mirror, see [Yocto offline build](build_instructions.md#yocto-offline-build).
3. Gather the SD card files into a zip:
   ```
   ./build.sh package --target <target>
   ```

The output products are gathered into `Yocto/<target>/images/linux/`:

| File | Description |
| --- | --- |
| `rootfs.wic.xz` | Full SD-card disk image — this is what you flash |
| `rootfs.wic.bmap` | Block map for `bmaptool` (fast flashing) |
| `BOOT.BIN` | Boot image (boot firmware, bitstream / device image, U-Boot) — copied to the card separately, see below |
| `boot.scr`, `Image`, `system.dtb` | U-Boot script, Linux kernel and device tree (also inside the disk image) |
| `rootfs.tar.gz` | Root filesystem tarball |

and the zip `bootimages/2x-qsfp28-fmc_<target>_yocto-2025-2.zip` contains `rootfs.wic.xz`,
`rootfs.wic.bmap`, `BOOT.BIN`, a `readme.txt` with the flashing steps and, for the VCK190,
`BOOTAA64.EFI`.

## What is in the image

| Item | Value |
|------|-------|
| Hostname | `<board>-qsfp-2025-2` (for example `vck190-qsfp-2025-2`, `zcu102-qsfp-2025-2`) |
| Login | user `amd-edf`; you set its password at the first login (it has `sudo` rights) |
| Kernel command line (ZynqMP) | built by `boot.scr`: `earlycon console=ttyPS0,115200 clk_ignore_unused init_fatal_sh=1 root=/dev/mmcblk<N>p3 ro rootwait uio_pdrv_genirq.of_id=generic-uio` plus the BSP's `cma=512M` |
| Kernel command line (Versal) | the systemd-boot entry: `console=ttyAMA0 earlycon=pl011,… root=PARTUUID=… ro rootwait uio_pdrv_genirq.of_id=generic-uio` plus the BSP's `clk_ignore_unused cma=1536M` |
| Test tools | `qsfp-loopback-test`, `ethtool`, `iperf3`, `iproute2` (`ip`, `nstat`), `i2c-tools`, `phytool`, kernel `pktgen` module, `pciutils`, `mtd-utils`, `can-utils`, `nfs-utils` |
| Remote access | OpenSSH server |

The root filesystem is mounted read-only first and remounted read-write by systemd during
boot.

## Boot from SD card

Unlike the PetaLinux flow (which produces separate boot files for a hand-partitioned card),
the Yocto flow produces a **full SD-card disk image** (`rootfs.wic.xz`) that already contains
all partitions. You flash it to the card's raw device, then copy `BOOT.BIN` onto the first
partition: the disk image does not carry `BOOT.BIN` where the BootROM looks for it, so a
card without it does not boot. On the VCK190 you also install the systemd-boot loader
(`BOOTAA64.EFI`), because the disk image's `EFI/BOOT/` directory is empty.

### Prepare the SD card

```{warning}
Flashing writes directly to a raw block device and cannot be undone. Be absolutely
certain you have identified the SD card's device node before running the commands below — if you
use the wrong device you risk destroying data on one of your hard drives.
```

The card must be 16 GB or larger (the disk image is about 8.6 GB). The commands below use
the files of the Yocto zip (or of `Yocto/<target>/images/linux/`).

1. Identify the SD card device. With the card **un**plugged, run `lsblk -o NAME,SIZE,RM,TYPE`,
   insert the card, and run it again. The new entry — typically `/dev/sdX`, with `RM=1`
   (removable) and a size matching your card — is your target. Replace `sdX` with that
   device below.
2. Unmount any partitions the desktop auto-mounted:
   ```
   for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
   ```
3. Flash the disk image to the raw device. With `bmaptool` (fast — only writes used blocks):
   ```
   sudo bmaptool copy --bmap rootfs.wic.bmap rootfs.wic.xz /dev/sdX
   ```
   or, as a fallback, with `dd`:
   ```
   xzcat rootfs.wic.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
4. Copy `BOOT.BIN` onto the first partition (FAT32):
   ```
   sudo mount /dev/sdX1 /mnt
   sudo cp BOOT.BIN /mnt/
   ```
5. **VCK190 only:** also install systemd-boot:
   ```
   sudo mkdir -p /mnt/EFI/BOOT
   sudo cp BOOTAA64.EFI /mnt/EFI/BOOT/
   ```
   Without it, U-Boot stops at its prompt instead of booting Linux.
6. Unmount and eject the card so that pending writes are flushed:
   ```
   sudo umount /mnt
   sudo eject /dev/sdX
   ```

### Boot

1. Plug the SD card into the target board and set it to boot from SD:
   * **VCK190:** DIP switch SW1 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU102, ZCU106:** DIP switch SW6 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU111, ZCU208, ZCU216:** see the boot-mode switch table in the board's user guide
2. Fit the [2x QSFP28 FMC] on the target's FMC connector (FMCP1 on the VCK190, HPC0 on the
   ZCU102/ZCU106, FMCP on the RFSoC boards) and plug in the cable or modules for your test.
3. Connect the USB-UART to your PC and open a terminal emulator at 115200 baud (8N1) — see
   [UART terminal](petalinux.md#uart-terminal).
4. Optionally connect the board's own Ethernet port to your network, for SSH access.
5. Power up the board.

On the VCK190, U-Boot enables the FMC VADJ rail (1.5 V) before it loads Linux, so that the
FMC's Si5328 and QSFP28 modules are powered when the kernel probes them. The QSFP28 ports
come up during boot when a cable or partner is connected; for example on a ZCU102 with a
cable between the two ports:

```
[    2.249594] xilinx_axienet 80060000.l_ethernet: Ethernet core IRQ not defined
[    2.257662] xilinx_axienet 80080000.l_ethernet: Ethernet core IRQ not defined
[    2.339191] si5324 0-0068: si5328 probed
[    2.405228] si5324 0-0068: si5328 probe successful
...
[   12.704181] xilinx_axienet 80060000.l_ethernet eth1: HSE MAC link up at 40000 Mbps (0 recovery resets)
[   12.704425] xilinx_axienet 80080000.l_ethernet eth2: HSE MAC link up at 40000 Mbps (0 recovery resets)
```

(The `Ethernet core IRQ not defined` lines are expected: these MACs have no interrupt of
their own; the MCDMA interrupts are used.) On the VCK190:

```
[   13.809084] xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 100000 (link monitored)
[   13.811970] xilinx_axienet 80000000.mrmac eth0: MRMAC link up at 100000 (0 recovery resets)
[   13.923686] xilinx_axienet 80010000.mrmac eth1: MRMAC setup at 100000 (link monitored)
[   13.926158] xilinx_axienet 80010000.mrmac eth1: MRMAC link up at 100000 (0 recovery resets)
```

### Log in

At the console, log in as `amd-edf`. On the first login you are asked to choose a
password:

```
zcu102-qsfp-2025-2 login: amd-edf
You are required to change your password immediately (administrator enforced).
New password:
Retype new password:
```

Use `sudo` for commands that need root. Once the password is set you can also log in over
SSH (`ssh amd-edf@<board-ip>`) on the board's own Ethernet port (`end0`), which obtains its
address by DHCP if your network provides one (`ip -br addr show end0` shows it).

## Using the QSFP28 ports

See [Testing under Linux](linux_usage) for the interface names, the link messages, the
`qsfp-loopback-test` self-test, `ethtool` and its counters, `iperf3` and the expected
results. They are the same for the PetaLinux and Yocto images.

## BSP layout and fixes

The Yocto BSPs live under `Yocto/bsp/`: one board layer per board (`vck190`, `zcu102`,
`zcu106`, `zcu111`, `zcu208`, `zcu216`) and the per-target port-config overlays under
`Yocto/bsp/port-configs/`. The notable content:

* **Port-config overlays (`port-config.dtsi`).** The Si5328 GT reference-clock generator,
  the MAC-to-driver binding and the MCDMA wiring are not fully described by the XSA, so each
  target applies an overlay: `ports-versal-01` (VCK190, both MRMAC ports),
  `ports-zu100g-01` (ZCU111 CMAC, both ports), `ports-zu100g-0` (ZCU208/ZCU216 CMAC,
  port 0) and `ports-zu40g-01` (all 40G targets). They program the Si5328 output
  (322.265625 MHz or 156.25 MHz), set each port's MAC address (`00:0a:35:00:00:00` for
  port 0, `…:01` for port 1) and `max-speed`, bind the ports to `xilinx_axienet` and
  override the MCDMA `compatible` so the generic DMA driver does not claim it.
* **Board device tree (`board-user.dtsi` / `system-user.dtsi`).** Describes the board's
  TI DP83867 Ethernet PHY(s) with their RGMII delays, which the System Device Tree flow does
  not derive from the XSA (without it the board's own Ethernet port negotiates 1G but passes
  no packets), and gives that port a fixed MAC address. If you use several boards of the
  same type on one network, change `local-mac-address` in this file.
* **Kernel patches and configuration (`recipes-kernel/linux/`).** The Si5328 CKOUT2 enable
  (port 1's reference clock), the MRMAC link monitor (Versal) or the CMAC / 40G-50G
  subsystem support with its link monitor (ZynqMP), the 1024-descriptor RX ring default and
  the `rx_dma_pkt_drop` counter; see [Linux BSPs](advanced.md#linux-bsps) for the full list.
* **Kernel command line and hostname (`conf/local.conf.append`).** `BSP_EXTRA_BOOTARGS`
  holds the design's kernel arguments; on ZynqMP they are appended to the `boot.scr`
  command line (`u-boot-edf-scr_%.bbappend`), on Versal to the systemd-boot entry
  (`systemd-bootconf-edf_%.bbappend`). The hostname is set to `<board>-qsfp-2025-2`.
* **VCK190 U-Boot (`recipes-bsp/u-boot/`).** Enables the FMC VADJ rail at every boot, and
  raises U-Boot's device-tree size headroom for the large two-port device tree.
* **Image contents (`recipes-core/images/edf-linux-disk-image.bbappend`).** Adds the test
  and utility tools listed above, including the `qsfp-loopback-test` recipe
  (`recipes-apps/qsfp-loopback-test/`).

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
