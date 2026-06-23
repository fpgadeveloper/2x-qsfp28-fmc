# Yocto / EDF builds

This folder builds Linux images for the 2x QSFP28 FMC (100G MRMAC Ethernet)
reference design using the AMD Yocto / Embedded Development Framework (EDF) flow
— the announced successor to PetaLinux Tools.

## How it works: the parse-sdt flow

The build generates a **custom Yocto MACHINE directly from the Vivado XSA** —
there is no dependency on an AMD-provided machine config. This is what lets a
customer change the PS in Vivado and have it flow through automatically, with no
hand-curated PL device tree:

```
XSA  --sdtgen-->  System Device Tree  --gen-machineconf parse-sdt-->  MACHINE + DTS
```

`scripts/configure-build.sh` runs `xsct`/`sdtgen` on the XSA to produce a System
Device Tree (which includes `pl.dtsi`, the PL hardware extracted from the
design), then runs `gen-machineconf parse-sdt` to emit
`conf/machine/qsfp-<target>.conf` plus the lopper-generated per-domain device
trees (`cortexa72-linux.dts` for the Versal APU). The PL **MRMAC + MCDMA**
Ethernet datapath therefore comes from the design's own SDT — no hand-curated PL
device tree. Because no PL overlay is requested, the Vivado boot artifact (the
`.pdi`) is embedded into `BOOT.BIN` (the PLM programs the PL at boot, before
Linux comes up).

The off-chip board hardware, however, is **not** in the XSA, so it is layered on
top of the generated tree with two small hand-written device-tree files:

* **`bsp/vck190/…/system-user.dtsi`** — SoC-side board quirks (see "Per-board
  fixups").
* **`bsp/port-configs/<ports-versal-*>/…/port-config.dtsi`** — the per-target
  external wiring: the Si5328 GT reference-clock generator, the MRMAC binding
  to the `xilinx_axienet` driver, the MCDMA datapath and the GT reset/PLL
  control GPIOs (see "Port-config overlays").

## Prerequisites

Host packages on Ubuntu 22.04 / 24.04:

```
sudo apt-get install repo gawk wget git diffstat unzip texinfo gcc \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 bmap-tools
```

Plus Vivado 2025.2 (used to produce the XSA this flow consumes) and Vitis
2025.2 — `sdtgen`/`xsct` (used to turn the XSA into a System Device Tree)
ship with Vitis, not Vivado, in 2025.2. The build runner locates and sources
the Vitis environment itself; sourcing it manually is only needed when
running the `scripts/` engine by hand:

```
source <xilinx-install>/2025.2/Vivado/settings64.sh
source <xilinx-install>/2025.2/Vitis/settings64.sh
```

## Build

Yocto images are built with the cross-platform build runner at the repo root
(this stage requires a native Linux machine; on Windows the runner refuses
it up front and prints the hand-off command):

```
./build.sh yocto --target vck190_fmcp1    # or any target from `./build.sh list`
```

The runner builds the Vivado XSA first if one isn't already present, then
sequences the four scripts in `scripts/` — the engine of the flow
(init-workspace, configure-build, build-image, package-output). The legacy
`cd Yocto && make yocto TARGET=<target>` still works on Linux (the Makefile
is now a thin wrapper around `build.sh`) but is deprecated.

The first build for a target:

1. Builds the Vivado project and exports the XSA if one isn't already
   present.
2. Initializes a manifest workspace under `Yocto/<TARGET>/` with
   `repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2025.2 -m default-edf.xml`
   and `repo sync` (≈5 GB of git history).
3. Sources `edf-init-build-env` to set up the bitbake environment.
4. Generates the System Device Tree from the XSA and runs
   `gen-machineconf parse-sdt` to create `MACHINE = "qsfp-<target>"`
   (gen-machineconf builds its own native helpers — `kconfig-frontends-native`,
   `lopper`, etc. — via bitbake on first run).
5. Layers `bsp/vck190/conf/local.conf.append` (hostname, kernel cmdline) and
   `bsp/vck190/meta-user/` (kernel config, `system-user.dtsi` board fixups,
   image bbappend) over the EDF default config, plus the
   `bsp/port-configs/<ports-versal-*>/meta-user/` overlay layer selected for the
   target's populated QSFP28 ports.
6. Runs `bitbake edf-linux-disk-image`.
7. Gathers `BOOT.BIN` (with the PL `.pdi` embedded), `Image`, `system.dtb`,
   `boot.scr`, `rootfs.tar.gz`, `rootfs.wic.xz`, and `rootfs.wic.bmap` into
   `Yocto/<TARGET>/images/linux/`.

Subsequent builds skip `repo sync`. To force a re-config (e.g. after editing
`bsp/vck190/conf/local.conf.append`), remove `Yocto/<TARGET>/configdone.txt`.

`./build.sh yocto --target all` builds every target; `./build.sh status --target all`
reports which are built.

## Port-config overlays (`port-config.dtsi`)

The external board hardware (the Si5328 GT reference-clock generator, the QSFP28
module I2C buses, the GT reset/PLL control) is board knowledge the XSA does not
carry, and the set of active 100G ports differs per target. The wiring is
therefore factored into per-config overlay **layers** rather than into the board
BSP, keyed by which QSFP28 ports the design populates:

```
bsp/port-configs/
  ports-versal-0/meta-user/    single-port design  (qsfp_port0 only)
  ports-versal-01/meta-user/   two-port design     (qsfp_port0 + qsfp_port1)
```

Each overlay is a small Yocto layer (its own `BBFILE_COLLECTIONS` name,
`port-config`) whose `device-tree.bbappend` adds its `port-config.dtsi` to the
Linux device tree via `EXTRA_DT_INCLUDE_FILES`. Which overlay applies is derived
per target from the design's populated ports in `config/data.json` (lanes
`["0"]` → `ports-versal-0`, lanes `["0","1"]` → `ports-versal-01`);
`configure-build.sh` adds `bsp/port-configs/<that-config>/meta-user` to
`bblayers.conf` alongside the board layer. A target with no port config simply
gets no overlay — the mechanism is a no-op there, so the scripts stay identical
across repos.

For each active port, `port-config.dtsi`:

* Attaches the **Si5328** jitter-attenuating clock generator on its dedicated
  `&axi_iic_clk` bus and programs its output to the 322.265625 MHz CAUI-4 GT
  reference clock (one Si5328 sources both ports' GT refclks in the two-port
  overlay).
* Overrides the `&qsfp_portN_mrmac` node so the **`xilinx_axienet`** driver
  binds: sets `axistream-connected` to the MCDMA, the `local-mac-address`, the
  per-port MCDMA `mm2s`/`s2mm` IRQs, and forces `max-speed = <100000>` so the
  MAC bonds all four GT lanes as 100G CAUI-4 (the auto-generated `pl.dtsi`
  otherwise emits the 25G per-lane rate, which would bring the port up as 25G
  single-lane).
* Wires the **GT reset / reset-done control GPIOs** (`gt-ctrl-gpios`,
  `gt-tx-dpath-gpios`, …) from the `axi_gpio_gtN` dual-channel AXI GPIO, which
  the driver uses to reset the GT and poll reset-done (resolving the "unable to
  get GT PLL resource" probe failure).
* Disables the three unused per-MAC sub-nodes (`mrmac_1/_2/_3`) that the SDT
  emits for the bonded lanes, and overrides the MCDMA `compatible` to
  `"xlnx,eth-dma"` so the standalone `xilinx_dma` dmaengine driver does not
  claim the MCDMA region out from under `axienet` (which would fail its probe
  with `-EBUSY`).

## Per-board fixups (`system-user.dtsi`)

`bsp/vck190/meta-user/recipes-bsp/device-tree/files/system-user.dtsi` is layered
onto the generated Linux device tree (via `EXTRA_DT_INCLUDE_FILES`, guarded so it
only applies to the Linux/APU domain DT — the PLM/PSM domain DTs don't define the
SoC peripheral labels). It carries only SoC-side board quirks, not PL hardware or
port wiring (that's the port-config overlay):

* **`zyxclmm_drm` `compatible = "xlnx,zocl-versal"`** under `&amba` — pins the
  ZOCL (Xilinx Runtime) DRM node to the Versal variant, matching the proven
  2x QSFP28 FMC PetaLinux BSP.

Kernel config fragments live in
`bsp/vck190/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`:

* `CONFIG_XILINX_AXI_EMAC` + `CONFIG_AXIENET_HAS_MCDMA` — the AXI Ethernet
  driver the MRMAC binds to, with the MCDMA datapath enabled.
* `CONFIG_GPIO_XILINX` + `CONFIG_I2C_XILINX` — the AXI GPIO (QSFP sideband / GT
  control) and AXI IIC (Si5328 + QSFP module) drivers.

The rootfs adds the design's test/utility tools (`ethtool`, `iperf3`,
`phytool`, `pciutils`, …) via
`bsp/vck190/meta-user/recipes-core/images/edf-linux-disk-image.bbappend`.

## Flashing to SD card

The build produces a full wic disk image (`rootfs.wic.xz`). Flash it to the SD
card's raw device; per-partition file copies do **not** work because the boot
script boots from the device it finds itself on.

On **Versal** the EDF wks uses a 3-partition EFI layout (`esp` (vfat), `storage`
(vfat), `root` (ext4)). Unlike the ZynqMP / Zynq-7000 wks, this BSP places both
`BOOT.BIN` and a `boot.scr` onto the `esp` partition automatically (via
`IMAGE_EFI_BOOT_FILES`), so **there is no manual `BOOT.BIN` copy step** — the
flashed card boots hands-free. (The Versal BootROM FAT-boots `BOOT.BIN` from
`esp`; U-Boot's bootcmd then runs `boot.scr`, which loads `Image` and boots with
the device tree the PLM loaded.)

### 1. Identify the SD card device — carefully

`dd`-style writes to a block device cannot be undone. With the SD card
**un**plugged, run `lsblk -o NAME,SIZE,RM,TYPE,MOUNTPOINT`; insert the card and
re-run it. The new entry (typically `/dev/sdX`, `RM=1`, size matching your card)
is your target. Confirm with
`udevadm info --query=property --name=/dev/sdX | grep -E "ID_BUS|ID_MODEL"`
(`ID_BUS=usb`). **Do not proceed until you are certain `/dev/sdX` is your SD card
and not an internal disk.**

### 2. Unmount any auto-mounted partitions

```
for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
```

### 3. Flash the wic image to the raw device

```
sudo bmaptool copy \
    --bmap Yocto/<TARGET>/images/linux/rootfs.wic.bmap \
          Yocto/<TARGET>/images/linux/rootfs.wic.xz \
          /dev/sdX
```

Fallback (slower): `xzcat …/rootfs.wic.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync`.

### 4. Eject and boot

Eject the card cleanly (`sudo eject /dev/sdX`) so pending writes flush. Insert it
into the board, set the boot-mode switches to SD (refer to the VCK190
documentation for the SD boot-mode setting), power-cycle, and attach a UART
terminal at 115200 8N1 (the console is on the second FTDI interface, typically
`/dev/ttyUSB1`).

## Offline / faster builds

Place the absolute path to a directory containing an extracted AMD sstate-cache
mirror in `Yocto/offline.txt` — `configure-build.sh` auto-detects which
architecture subdirs exist under it and wires one `SSTATE_MIRRORS` entry per
arch (plus `SOURCE_MIRROR_URL` if a `downloads/` dir is present).

Expected layout under that path:

```
<sstate root>/
  aarch64/      (Versal APU Linux)
  microblaze/   (the Versal PLM/PSM firmware multiconfig)
  downloads/    (optional — the source-mirror tarballs)
```

Both `aarch64` and `microblaze` are useful: the generated MACHINE builds the
Versal PLM/PSM firmware as a MicroBlaze multiconfig. The sstate-cache and
downloads archives are available behind login at the AMD Embedded Design Tools
download page under "sstate-cache & Downloads - 2025.2".

## Layout

```
Yocto/
  Makefile                  deprecated thin wrapper around ../build.sh
  README.md                 this file
  .gitignore                excludes per-target workspaces + local state
  offline.txt               (optional, gitignored) path to an extracted sstate mirror
  scripts/
    init-workspace.sh       repo init + sync
    configure-build.sh      sdtgen + gen-machineconf parse-sdt + apply BSP (+ overlay) + sstate
    build-image.sh          bitbake the image recipe
    package-output.sh       gather deploy artifacts into images/linux/
  bsp/
    vck190/                 the Versal board BSP
      conf/local.conf.append   board overrides (hostname, kernel cmdline)
      meta-user/               Yocto layer: kernel cfg, system-user.dtsi, image bbappend
    port-configs/
      ports-versal-0/, ports-versal-01/   per-target QSFP28 port overlay layers
  <TARGET>/                 (gitignored) per-target workspace built by the runner
  logs/                     (gitignored) build logs
```

## Architectural notes

* **The four scripts are universal** — identical across all of our reference
  repos. The per-repo data (target list, `BD_NAME`, each target's template and
  optional port config) lives in `config/data.json`, which `build.py` reads at
  runtime — nothing is generated into this folder.

* **The MACHINE is generated from the XSA** by `gen-machineconf parse-sdt` (the
  flow AMD recommends; `parse-xsa` is deprecated). There is no pinned
  AMD-validated MACHINE and no per-target flow selection. The custom machine is
  named `${BD_NAME}-<target>` (i.e. `qsfp-<target>`); `configure-build.sh`
  takes `BD_NAME` as an argument so the script stays repo-agnostic.

* **The bitstream lives in BOOT.BIN**, not loaded at runtime via FPGA manager.
  Because no PL overlay is requested, the `.pdi` `sdtgen` extracted from the XSA
  is embedded into `BOOT.BIN` and the PLM programs the PL during boot, so the
  MRMAC datapath is live before Linux starts.

* **`system-user.dtsi` and `port-config.dtsi` are scoped to the Linux device
  tree** (via a guard on `CONFIG_DTFILE`). The PLM/PSM domain device-trees don't
  define the SoC peripheral / `mrmac` labels the overrides reference, so
  including them there makes `dtc` fail with "Label or path … not found".

* **Adding a target**: set `"yocto": true` for the design in `config/data.json`
  and run `config/update.py` (regenerates the README table), then create
  `bsp/<board>/` following the existing `vck190` board. If the target uses a
  port count not already covered, add a `bsp/port-configs/<ports-versal-XXXX>/`
  overlay.
```
