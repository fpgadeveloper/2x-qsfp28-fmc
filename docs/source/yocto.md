# Yocto

The Yocto / EDF flow (AMD's Embedded Development Framework) is the announced successor to
PetaLinux. It can be built for the 2x QSFP28 FMC reference design with the cross-platform
`build.py` runner at the root of the repository, and produces a Linux image that exercises the
QSFP28 ports through the `xilinx_axienet` driver and MCDMA datapath.

```{note}
For 2025.2 both the PetaLinux (VCK190 only) and Yocto flows are supported and produce an
equivalent image. From the next tool version onward, the PetaLinux flow for this repository
will be retired and Yocto will be the only supported flow.
```

The Yocto flow is supported for ALL targets. The MAC depends on the target device family:

| Target(s) | MAC | Link rate |
| --- | --- | --- |
| `vck190_fmcp1` | Versal Integrated MRMAC (hard block) | 2x 100G |
| `zcu111` | UltraScale+ Integrated 100G Ethernet (CMAC hard block) | 2x 100G |
| `zcu208`, `zcu216` | UltraScale+ Integrated 100G Ethernet (CMAC hard block) | 1x 100G (port 0) |
| `zcu102_hpc0`, `zcu106_hpc0` | 40G/50G High Speed Ethernet Subsystem (soft MAC) | 2x 40G |

The MRMAC is supported natively by the `xilinx_axienet` driver; for the ZynqMP targets the
CMAC / 40G-50G MAC support is added by a kernel patch carried in the board BSPs
(`Yocto/bsp/<board>/meta-user/recipes-kernel/linux/`).

```{note}
On the ZCU208 and ZCU216 (ZU48DR/ZU49DR) only one of the two integrated CMAC blocks can
physically reach the FMC+ GT quads, so these targets implement a single 100G port (QSFP
port 0); the QSFP port 1 module is held in reset. The ZCU102/ZCU106 have GTH transceivers
(max ~16 Gb/s per lane), so their QSFP28 ports run at 40G (40GBASE-R4).
```

## Requirements

To build the Yocto projects you will need a physical or virtual machine running one of the
[supported Linux distributions], with the Vitis Core Development Kit installed — the flow uses
`xsct`/`sdtgen` (which ship with Vitis) to generate a System Device Tree from the Vivado XSA. You
also need [Google's repo tool](https://gerrit.googlesource.com/git-repo/) on your `PATH`.

```{attention}
You cannot build the Yocto projects in the Windows operating system. Windows users
are advised to use a Linux virtual machine to build the Yocto projects.
```

## How to build

The build runner locates and sources the Vivado and Vitis settings itself, so there is no
need to source them by hand; you only need [Google's repo tool](https://gerrit.googlesource.com/git-repo/)
on your `PATH` (see Requirements above).

1. From a command terminal, clone the Git repository (with its submodules) and `cd` into it:
   ```
   git clone --recurse-submodules https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
   cd 2x-qsfp28-fmc
   ```
2. Build the Yocto image for your target by running the following command, replacing
   `<target>` with one of the target design labels listed in the
   [build instructions](build_instructions.md#target-designs):
   ```
   ./build.sh yocto --target <target>
   ```

This command launches the corresponding Vivado build if that project has not already been
built and its hardware exported. The first build of a target downloads several GB of sources
(`repo sync`) and runs bitbake from scratch, so it takes a while; subsequent builds are
incremental. The output products are gathered into `Yocto/<target>/images/linux/`:

| File | Description |
| --- | --- |
| `BOOT.BIN` | Boot image (PLM + `.pdi` bitstream + U-Boot) |
| `boot.scr` | U-Boot boot script |
| `Image` | Linux kernel |
| `system.dtb` | Linux device tree |
| `rootfs.wic.xz` | Full SD-card disk image — this is what you flash |
| `rootfs.wic.bmap` | Block map for `bmaptool` (fast flashing) |
| `rootfs.tar.gz` | Root filesystem tarball |

## Boot from SD card

Unlike the PetaLinux flow (which produces separate boot files for a hand-partitioned card), the
Yocto flow produces a **full SD-card disk image** (`rootfs.wic.xz`) that already contains all
partitions. On Versal this image is self-contained — you flash it to the SD card's raw device and
the card boots with no manual file copy.

### Prepare the SD card

```{warning}
Flashing writes directly to a raw block device and cannot be undone. Be absolutely
certain you have identified the SD card's device node before running the commands below — if you
use the wrong device you risk destroying data on one of your hard drives.
```

1. Identify the SD card device. With the card **un**plugged, run `lsblk -o NAME,SIZE,RM,TYPE`,
   insert the card, and run it again. The new entry — typically `/dev/sdX`, with `RM=1`
   (removable) and a size matching your card — is your target. Replace `sdX` with that device,
   and `<target>` with your board, below.
2. Unmount any partitions the desktop auto-mounted:
   ```
   for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
   ```
3. Flash the wic image to the raw device. With `bmaptool` (fast — only writes used blocks):
   ```
   sudo bmaptool copy --bmap Yocto/<target>/images/linux/rootfs.wic.bmap \
                            Yocto/<target>/images/linux/rootfs.wic.xz \
                            /dev/sdX
   ```
   Or, as a fallback with `dd`:
   ```
   xzcat Yocto/<target>/images/linux/rootfs.wic.xz \
       | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
   ```{note}
   On Versal there is **no manual `BOOT.BIN` step**. The Versal EDF wks uses a 3-partition EFI
   layout (`esp`/`storage`/`root`) and places both `BOOT.BIN` and `boot.scr` onto the `esp`
   partition automatically, so the flashed card boots hands-free. (On Zynq-7000 and Zynq
   UltraScale+ designs the BootROM cannot read the ext4 `boot` partition the wic installs
   `BOOT.BIN` onto, so those flows require an extra copy onto `esp` — Versal does not.)
   ```
4. Eject the card cleanly so pending writes flush: `sudo eject /dev/sdX`.

### Boot

1. Plug the SD card into the target board and set it to boot from SD. Refer to the VCK190
   documentation for the SD boot-mode DIP-switch setting.
2. Connect the [2x QSFP28 FMC] to the target board's FMC connector and plug a 100G QSFP28 module
   (or passive loopback module) into the port(s) under test.
3. Connect the USB-UART to your PC and open a terminal emulator at 115200 baud (8N1) — see
   [UART terminal](petalinux.md#uart-terminal). On the VCK190 the console is on the second FTDI
   interface (typically `/dev/ttyUSB1`).
4. Connect and power your hardware.

## Using the QSFP28 ports

Once Linux has booted and you have logged in at the console, the 100G MRMAC ports are exercised
exactly as in the PetaLinux flow — see [Example Usage](petalinux.md#example-usage) for the
loopback self-test, link bring-up, IP assignment, `ethtool` and `iperf3` walkthrough.

```{note}
The two QSFP28 MRMAC ports appear as `eth0` and `eth1` (the VCK190's built-in PS GEM ports take
the systemd predictable `end0`/`end1` names). The MRMAC ports get their MAC addresses from the
`port-config.dtsi` overlay after the udev rename rule has already run, so they keep their
kernel-default `ethN` names — the same naming behaviour as the PetaLinux flow. Identify a port by
its MAC address (Port 0 = `00:0a:35:00:00:00`, Port 1 = `…:01`) or with `ethtool -i <name>`
(`xilinx_axienet` = a QSFP28 FMC port; `macb` = a VCK190 built-in GEM). See
[Port configurations](petalinux.md#port-configurations) for the full mapping.
```

## Patches and known issues

The per-board fixups applied in the Yocto flow live under `Yocto/bsp/` — the board
`system-user.dtsi` device-tree override, the per-target `port-config.dtsi` overlays, and the
kernel `bsp.cfg` fragment. See [advanced](advanced.md) for the full list. The notable ones:

* **MRMAC / external wiring (`port-config.dtsi`).** The Si5328 GT reference-clock generator, the
  QSFP module I2C buses and the GT reset/PLL control are not described by the XSA, so each target
  applies a port-config overlay (`ports-versal-0` for the single-port design, `ports-versal-01`
  for the two-port design) that binds the MRMAC to `xilinx_axienet`, forces 100G CAUI-4
  (`max-speed = <100000>`), wires the GT-control GPIOs, and overrides the MCDMA `compatible` to
  `xlnx,eth-dma` so the standalone dmaengine driver does not claim it.
* **ZOCL DRM node (`system-user.dtsi`).** Pins `zyxclmm_drm` to
  `compatible = "xlnx,zocl-versal"` for the Versal APU, matching the PetaLinux BSP.
* **Kernel config (`bsp.cfg`).** Enables `CONFIG_XILINX_AXI_EMAC` with `CONFIG_AXIENET_HAS_MCDMA`
  (the MRMAC datapath), plus `CONFIG_GPIO_XILINX` and `CONFIG_I2C_XILINX` for the QSFP sideband
  GPIO and the Si5328 / QSFP-module I2C buses.

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
