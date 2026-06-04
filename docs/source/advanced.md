# Advanced: project structure and customization

This section is intended for users who want to modify the reference
design — adding IP to the block design, changing constraints, adding
packages or drivers to the PetaLinux project, and so on. It describes
how the repository is laid out, how the Make-driven build flow works,
how the block design assembles the MRMAC subsystem, how the PetaLinux
BSP is composed from layered fragments, and what modifications have been
added on top of the stock AMD BSP.

The actual *build* instructions are in [build_instructions](build_instructions);
this section is about understanding the project well enough to modify
it.

## Repository layout

```
.
├── Makefile                   <- Top-level build entry point
├── README.md
├── config/                    <- Source-of-truth design metadata and auto-generation
│   ├── data.json
│   └── update.py
├── docs/                      <- This documentation (Sphinx + Read the Docs)
├── PetaLinux/
│   ├── Makefile               <- PetaLinux build orchestration
│   └── bsp/                   <- Board and port-config BSP fragments
│       ├── vck190/            <-   board-specific overlay
│       ├── ports-versal-0/    <-   port-config overlay: port 0 only
│       └── ports-versal-01/   <-   port-config overlay: ports 0 and 1
└── Vivado/
    ├── Makefile               <- Vivado build orchestration
    ├── build-vivado.bat       <- Windows project-creation helper
    ├── scripts/
    │   ├── build.tcl          <- Project creation + block design assembly
    │   └── xsa.tcl            <- Synthesis, implementation, XSA export
    └── src/
        ├── bd/
        │   └── bd_versal.tcl  <- Block design for all (Versal) targets
        ├── constraints/
        │   └── <target>.xdc   <- One XDC per target (pin assignments)
        └── hdl/
            └── mrmac_axis_adapter.v  <- MRMAC 100G client ↔ AXI4-Stream adapters
```

Per-target build outputs are written to `Vivado/<target>/` and
`PetaLinux/<target>/`; packaged boot-image zips are written to
`bootimages/`. None of these are committed.

## Target naming

A `TARGET` is the canonical handle for a single design and is the only
parameter passed through the build flow. It encodes the board and the
FMC connector:

```
<board>_<connector>
```

For this repo the (currently single) target is `vck190_fmcp1`. The first
underscore-delimited token (`vck190`) is taken as the *target board* and
is what `PetaLinux/Makefile` uses to select the BSP under
`PetaLinux/bsp/<board>/`.

The complete list of valid targets is in the `UPDATER START` block of
each Makefile and is generated from `config/data.json` (see below).

## `config/data.json` and `config/update.py`

`config/data.json` is the canonical source of truth for the set of
supported designs and their per-target metadata (board name, board URL,
line rate, FMC connector, etc.). `config/update.py` reads `data.json`
and regenerates the auto-managed sections of the Makefiles, the Vivado
`build.tcl` target dictionary, the top-level `README.md`, and
`.gitignore` — the sections delimited by `UPDATER START` / `UPDATER END`
(or `<!-- updater start -->` / `<!-- updater end -->`) comment markers.
The Sphinx documentation also reads `data.json` directly to render the
supported-board and target-design tables.

```{note}
Terminology: the `lanes` field of each design holds the list of QSFP28
*ports* the design instantiates (`["0"]` for port 0 only, `["0","1"]`
for both ports). Each QSFP28 port is a single 100GbE (CAUI-4) MRMAC that
uses four GTY lanes internally. This mirrors how the Quad SFP28 FMC repo
uses `lanes` to mean SFP28 ports, so the same update machinery is reused
unchanged.
```

When adding or modifying a target, edit `data.json` and re-run
`update.py` (from the `config/` directory). Do not hand-edit content
between the updater markers; it will be overwritten on the next
regeneration. Note that `update.py` derives the PetaLinux port-config
overlay name from the populated ports: `lanes=["0"]` selects
`bsp/ports-versal-0/`, `lanes=["0","1"]` selects `bsp/ports-versal-01/`.

## Make-driven build flow

There are three Makefiles in the repository, each scoped to a stage of
the build:

| Makefile               | Scope                                                                                  |
|------------------------|----------------------------------------------------------------------------------------|
| `./Makefile`           | Top-level orchestration; assembles boot-image zips for one or all targets.             |
| `./Vivado/Makefile`    | Creates the Vivado project, runs synthesis and implementation, exports the XSA.        |
| `./PetaLinux/Makefile` | Creates the PetaLinux project from the XSA, applies BSP overlays, builds, packages.    |

A `make bootimage TARGET=<t>` invocation at the top level cascades:

```
make bootimage TARGET=t
  -> ensures PetaLinux build output exists
       PetaLinux/Makefile petalinux TARGET=t
         -> ensures Vivado XSA exists
              Vivado/Makefile xsa TARGET=t
                -> vivado -mode batch -source scripts/build.tcl   (creates project + block design)
                -> vivado -mode batch -source scripts/xsa.tcl     (synth, impl, device image, XSA export)
         -> petalinux-create --template versal --name t
         -> petalinux-config --get-hw-description <XSA>
         -> copy bsp/<board>/project-spec/* into the project
         -> copy bsp/<port-config>/project-spec/* into the project   (overlay)
         -> petalinux-config --silentconfig
         -> petalinux-build
         -> petalinux-package boot --plm --psmfw --u-boot --dtb
  -> zip the resulting boot files into bootimages/
```

The dependency chain means a clean `make bootimage TARGET=t` from
scratch will perform every step in order. Re-running after an
intermediate step has succeeded picks up where the previous run left
off. Per-target lock files (`.<target>.lock`) prevent two concurrent
builds of the same target from clobbering each other.

```{tip}
`make project TARGET=<t>` (in `Vivado/`) creates the block design and
runs `validate_bd_design` **without** synthesis — use it to catch
block-design wiring errors fast before committing to the long XSA build.
```

## Vivado side

### Block design

There is one block-design TCL, `Vivado/src/bd/bd_versal.tcl`. It is
parameterised by the `ports` list (passed in from `build.tcl`'s
`target_dict`), and builds the design as follows:

1. **CIPS + NoC + DDR.** The Versal CIPS is added and configured by the
   `xilinx.com:bd_rule:cips` automation (DDR branch, one DDR memory
   controller), then extended with a per-board `PS_PMC_CONFIG` (M_AXI_LPD
   enabled, 16 PL→PS interrupts, two PL clocks).
2. **Clocking.** A clock wizard generates the 100 MHz system clock (all
   AXI-Lite control and the MCDMA/NoC datapath), and a second clock
   wizard generates the 390.625 MHz MRMAC AXIS client clock.
3. **Per-port GT quad.** For each port, a `gt_quad_base` (GTY) is
   configured for four lanes and given its own reference clock
   (`gt_ref_clk_0` = GBTCLK0 for port 0, `gt_ref_clk_1` = GBTCLK1 for
   port 1) and an APB3 bridge for its DRP.
4. **Per-port MRMAC subsystem.** The `create_qsfp_port` proc (called once
   per port) builds the MRMAC, its per-lane GT user-clock buffers, the
   MRMAC client AXIS adapter, the width-converter/CDC-FIFO datapath, the
   AXI MCDMA, the AXI-Lite control SmartConnect, the GT-control GPIO, the
   QSFP sideband GPIO, the per-port module-management IIC, and the user
   LEDs.
5. **Structural scaling.** The NoC slave-port count, the control
   SmartConnect master count, the interrupt list, and the shared Si5328
   IIC are sized from the number of ports so the same script builds both
   single-port and two-port designs.

After sourcing the BD script, `build.tcl` runs `validate_bd_design
-force`, which triggers parameter propagation and connection automation.
To see the netlist as actually built, inspect the saved `.bd` under
`Vivado/<target>/<target>.gen/sources_1/bd/qsfp/` or use `write_bd_tcl`.

`build.tcl` checks `XILINX_VIVADO` against the `version_required` constant
(`2025.2`) and refuses to build with a different Vivado version — the BD
TCL APIs are not stable across major releases.

### The MRMAC datapath, in detail

These are the design choices that are specific to driving a QSFP28 port
as 1x100GbE CAUI-4. If you modify the block design, these are the parts
most likely to need care.

#### GT Quad configuration

The GT quad uses `PRESET None` and specifies the full PROT0 field set
manually: GTY, four lanes at 25.78125 Gb/s, **LCPLL integer-N**,
322.265625 MHz reference clock, 80-bit RAW datapath. The MRMAC requires
an 80-bit RAW GT datapath that no named Ethernet preset provides, which
is why `PRESET None` is used and every field is set explicitly. The
field set is merged onto the 2025.2 IP's default LR0 dictionary, applying
only field names that exist in this IP version (so the configuration
stays robust if the IP's field set changes between releases).

#### Per-lane CAUI-4 user clocking

CAUI-4 bonds four lanes and requires them to align, so each lane's
recovered RX clock must drive that lane's MRMAC serdes/core clock:

* **RX:** each of the four GT lanes gets its own pair of `BUFG_GT`
  buffers — a full-rate `usrclk` and a half-rate (`/2`) `usrclk2`. The
  MRMAC `rx_serdes_clk`/`rx_core_clk` buses take the per-lane full-rate
  clocks; `rx_alt_serdes_clk` takes the per-lane half-rate clocks; the GT
  `chN_rxusrclk` inputs take the per-lane half-rate clocks.
* **TX:** all four lanes share the TX PLL, so a single `ch0` pair drives
  all four TX lanes (`tx_core_clk` = ch0 full-rate ×4; `tx_alt_serdes_clk`
  and the GT `chN_txusrclk` inputs = ch0 half-rate).

```{warning}
Driving the MRMAC RX serdes/core clocks from `ch0` alone (broadcasting
one lane's recovered clock to all four) leaves lanes 1–3 sampled in the
wrong clock domain — those PCS lanes never block-lock and 100G alignment
never completes, **even with a passive loopback**. The per-lane clocking
above is mandatory for CAUI-4. (The AXIS *client* clocks
`tx_axi_clk`/`rx_axi_clk` are a separate, single 390.625 MHz domain — do
not confuse the two clock buses.)
```

#### MRMAC client AXIS adapter

The MRMAC 100G "Independent 384b Non-Segmented" client is **not** a
standard AXI4-Stream bus. In the block design its `axis_rx_port0` /
`axis_tx_port0` interfaces are handshake-only (they map only
TVALID/TLAST/TREADY, so IP integrator reports `TDATA_NUM_BYTES=0`). The
384-bit data actually rides on six separate 64-bit lane ports
(`rx`/`tx_axis_tdata0..5`) plus six per-lane `tkeep_user0..5[10:0]`
control words. Feeding that handshake-only interface straight into a
stock `axis_dwidth_converter` mis-delineates frames (one packet per
384-bit beat — frames arrive fragmented into ~48-byte pieces).

`Vivado/src/hdl/mrmac_axis_adapter.v` provides two purely-combinational
adapters (`mrmac_rx_axis_adapter`, `mrmac_tx_axis_adapter`) that
pack/unpack the six 64-bit lanes into a single standard 384-bit AXIS
stream (`tdata[383:0]`, `tkeep[47:0]`, `tlast`, `tvalid`), so the
downstream width-converter / CDC-FIFO / MCDMA chain delineates frames
correctly (one `TLAST` per Ethernet frame). `build.tcl` adds
`src/hdl/*.v` to the project **before** sourcing the BD so
`create_bd_cell -type module -reference` can resolve the modules.

```{note}
This packing is specific to 1x100GbE CAUI-4, which bonds all six client
lanes into one frame. A design running independent 10G/25G ports (one
64-bit lane straight into its own MCDMA per port) would not need it.
```

#### Width conversion, CDC and MCDMA

The MRMAC client runs at 390.625 MHz / 384-bit; the MCDMA and NoC run at
the 100 MHz system clock / 512-bit. Each direction has an
`axis_dwidth_converter` (384 ↔ 512 bit) and an asynchronous
`axis_data_fifo` for the clock-domain crossing. The AXI MCDMA
(`c_num_mm2s_channels`/`c_num_s2mm_channels` = 1, 512-bit, 64-bit
addressing) moves packet data to/from DDR over three NoC AXI master
ports (scatter-gather, MM2S, S2MM).

#### MRMAC placement

Both MRMACs default to `MRMAC_LOCATION_C0 = MRMAC_X0Y0`, which makes
port 1 fail placement ("bel is occupied"). The proc pins each port's
MRMAC to the integrated-MAC site in the clock region of its GT quad:

```
port 0 : GTY_QUAD_X1Y1 (region X9Y1) -> MRMAC_X0Y0
port 1 : GTY_QUAD_X1Y2 (region X9Y2) -> MRMAC_X0Y2
```

### Address and interrupt maps

The control peripherals are mapped from `M_AXI_LPD`:

| Peripheral            | Port 0       | Port 1       |
|-----------------------|--------------|--------------|
| MRMAC `s_axi`         | `0x80000000` | `0x80010000` |
| QSFP sideband GPIO    | `0x80020000` | `0x80030000` |
| GT-control GPIO       | `0x80070000` | `0x80090000` |
| AXI MCDMA             | `0x80080000` | `0x800A0000` |
| QSFP module IIC       | `0x80050000` | `0x80060000` |
| Si5328 clock IIC (shared) | `0x80040000` |          |

Interrupts are connected to `pl_ps_irq0..6` (SPI = 84 + index):

| `pl_ps_irq` | SPI | Source                 |
|-------------|-----|------------------------|
| 0           | 84  | Port 0 MCDMA `mm2s`    |
| 1           | 85  | Port 0 MCDMA `s2mm`    |
| 2           | 86  | Port 0 QSFP module IIC |
| 3           | 87  | Port 1 MCDMA `mm2s`    |
| 4           | 88  | Port 1 MCDMA `s2mm`    |
| 5           | 89  | Port 1 QSFP module IIC |
| 6           | 90  | Si5328 clock IIC       |

### Constraints

`Vivado/src/constraints/<target>.xdc` contains the pin assignments. For
`vck190_fmcp1` it covers both FMC slots: the eight GTY lanes (DP0–3 for
port 0, DP4–7 for port 1), the two GT reference clocks (GBTCLK0/GBTCLK1),
the three IIC buses (shared Si5328 on LA02, QSFP0 on LA03, QSFP1 on
LA17_CC), and the per-slot QSFP module sideband I/O and user LEDs.

### Modifying the block design

Edit `Vivado/src/bd/bd_versal.tcl`. Most per-port logic lives in the
`create_qsfp_port` proc, which is called once per entry in `ports`;
structural counts (NoC slave ports, control SmartConnect masters,
interrupts) are derived from the number of ports, so adding or removing a
port is largely a matter of changing the `lanes` list in `data.json`.
After editing, delete the existing project directory and rebuild:

```
rm -rf Vivado/<target>
cd Vivado
make xsa TARGET=<target>
```

## PetaLinux side

### BSP composition

The PetaLinux project is composed at build time from two BSP fragments
copied into the target's project directory:

1. A **board BSP** at `PetaLinux/bsp/vck190/`. Provides the board kernel
   and U-Boot configuration, `system-user.dtsi` (which includes
   `port-config.dtsi`), the kernel patches, and the rootfs configuration.
2. A **port-config overlay** at `PetaLinux/bsp/ports-versal-<ports>/`.
   Provides `port-config.dtsi` — the device-tree fragment that wires up
   the MRMAC, MCDMA, IIC, GPIO and Si5328 nodes for the ports active on
   this target. `ports-versal-0` is port 0 only; `ports-versal-01` is
   both ports.

The mapping from target to (board BSP, port-config overlay) is encoded
in `PetaLinux/Makefile`'s `UPDATER` block, for example:

```
vck190_fmcp1_target := versal 0 0 ports-versal-01
```

The first column is the PetaLinux template (`versal`); the last is the
port-config overlay name. The board BSP is derived from the first token
of the target name (`vck190`). At build time both `project-spec/` trees
are copied in, with the port-config overlay copied *after* the board BSP.

### The `port-config.dtsi` overlay

This is the device-tree fragment that makes the MRMAC ports work. Per
port it sets, on the SDT-generated `mrmac@…` node:

* `axistream-connected` → the port's MCDMA node, plus the MCDMA channel
  interrupts (`mm2s_ch1_introut`/`s2mm_ch1_introut`) and their GIC
  `interrupts`. The `xilinx_axienet` MCDMA probe looks the interrupts up
  *by name on the MRMAC node*, so both `interrupt-names` and the matching
  `interrupt-parent`/`interrupts` must be present here.
* `local-mac-address`, `xlnx,channel-ids`, `xlnx,num-queues`,
  `xlnx,addrwidth`.
* `max-speed = <100000>` **and** `xlnx,mrmac-rate = <100000>`. The driver
  reads `max-speed` first; without it, the auto-generated `pl.dtsi`
  `max-speed = <25000>` (the per-lane GT rate) wins and the port comes up
  at 25G single-lane instead of 100G.
* `gt-ctrl-gpios`, `gt-tx-dpath-gpios`, `gt-rx-dpath-gpios`,
  `gt-ctrl-rate-gpios`, `gt-tx-rst-done-gpios`, `gt-rx-rst-done-gpios`
  (all on the port's GT-control AXI GPIO) and `xlnx,gtlane = <0>`. These
  let the driver reset the GT and poll reset-done (see below).

It also overrides each MCDMA node's `compatible` to `"xlnx,eth-dma"`, and
disables the three phantom `mrmac_1/_2/_3` nodes the SDT emits per MRMAC.
Finally it instantiates the Si5328 (see below).

### Modifications layered on the stock BSP

The board BSP started as the stock AMD VCK190 reference BSP. This list is
the answer to *"what would I lose if I overwrote the BSP with the stock
one?"*

* **AXI Ethernet + MCDMA driver.** Kernel configs enable the
  `xilinx_axienet` driver with MCDMA support
  (`CONFIG_XILINX_AXI_EMAC`, `CONFIG_AXIENET_HAS_MCDMA`,
  `CONFIG_GPIO_XILINX`, `CONFIG_I2C_XILINX`). The MRMAC binds to
  `xilinx_axienet`, not to phylink/SFP as the Quad SFP28 FMC design does.

* **MCDMA `compatible` override (device tree).** `xilinx_axienet`
  ioremaps the MCDMA registers itself, but the standalone `xilinx_dma`
  dmaengine driver also matches the MCDMA node and claims the region
  first, so axienet's probe fails with `-EBUSY`. Because
  `CONFIG_XILINX_AXI_EMAC` *depends on* `XILINX_DMA`, the dmaengine
  driver cannot simply be disabled. The fix is the
  `compatible = "xlnx,eth-dma"` override in `port-config.dtsi`:
  `xilinx_dma`'s of-match table does not bind `eth-dma`, and axienet
  finds the MCDMA via the `axistream-connected` phandle (not by
  compatible), so the region is left for axienet.

* **GT-control GPIO binding.** The `xilinx_axienet` MRMAC driver needs to
  reset the GT and read reset-done/PLL status from the PS. The block
  design exposes a dual-channel AXI GPIO per port (`axi_gpio_gt*`): five
  outputs (gt_reset_all, gt_reset_tx_datapath, gt_reset_rx_datapath, plus
  two spare gt-ctrl-rate lines) and two inputs (gt_tx/rx_reset_done). The
  `gt-*-gpios` properties in `port-config.dtsi` point the driver at these
  GPIO lines. Without this, the driver fails with `unable to get GT PLL
  resource`.

* **Si5328 clock generator (device tree).** `port-config.dtsi`
  instantiates a `silabs,si5328` `clock-generator@68` node on the shared
  clock IIC bus, with a fixed-clock 114.285 MHz crystal input and a
  `clk0@0` output programmed to 322.265625 MHz (the 100G GT reference
  clock). The Linux `clk-si5324` driver programs the device from this
  node on probe.

* **Si5328 CKOUT2 kernel patch.** For the two-port design, port 1's GT
  reference clock is GBTCLK1, which the FMC routes from the Si5328's
  CKOUT2 output. The stock Xilinx `clk-si5324` driver hard-disables
  CKOUT2 and only programs CKOUT1's divider, so port 1's GT never gets a
  reference clock and fails with `GT TX Reset Done not achieved`. The
  kernel patch
  `recipes-kernel/linux/linux-xlnx/0001-clk-si5324-enable-ckout2-for-2x-qsfp28-fmc.patch`
  enables CKOUT2 (sets the dual-LVDS output format and clears the CKOUT2
  disable bit) and mirrors CKOUT1's divider to CKOUT2 (both outputs share
  the same PLL, so they run at the same frequency). It is registered via
  `SRC_URI:append` in `recipes-kernel/linux/linux-xlnx_%.bbappend`.

* **Loopback self-test app.** The `mrmac-loopback-test` recipe
  (`recipes-apps/mrmac-loopback-test/`) installs the self-test script
  described in [petalinux](petalinux); it is force-installed via
  `IMAGE_INSTALL:append` in `meta-user/conf/petalinuxbsp.conf`.

* **Root filesystem additions.** `ethtool` and `iperf3`.

### Adding a kernel config option, patch, package or device-tree node

The mechanisms are the standard PetaLinux ones:

* **Kernel config:** append `CONFIG_<name>=y` to
  `bsp/vck190/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`.
* **Kernel patch:** drop the `.patch` into
  `recipes-kernel/linux/linux-xlnx/` and add a `SRC_URI:append` line to
  `linux-xlnx_%.bbappend`. Force a re-patch with
  `petalinux-build -c kernel -x cleansstate && petalinux-build`.
* **Rootfs package:** add `CONFIG_<package>=y` to
  `configs/rootfs_config` (and declare it in
  `meta-user/conf/user-rootfsconfig` if it is not in the default menu).
* **Per-board device tree:** edit
  `meta-user/recipes-bsp/device-tree/files/system-user.dtsi`.
* **Per-port device tree:** edit the
  `bsp/ports-versal-<ports>/…/port-config.dtsi` overlay.

```{tip}
After a *structurally-changed* XSA (new peripherals/addresses), a
`petalinux-config --get-hw-description` on an existing project keeps the
stale SDT ("workspace already set up, leaving as-is"). Remove
`<target>/components/plnx_workspace` before re-importing to force a fresh
SDT, then rebuild (this reuses the sstate cache, so it is incremental).
```

## Where build outputs land

| Path                                | Contents                                                  |
|-------------------------------------|-----------------------------------------------------------|
| `Vivado/<target>/`                  | Vivado project. `qsfp_wrapper.xsa` is the export.         |
| `Vivado/<target>/<target>.runs/impl_1/qsfp_wrapper.bit` | Device image / bitstream.             |
| `Vivado/logs/`                      | Per-target Vivado build logs (xpr + xsa).                 |
| `PetaLinux/<target>/`               | PetaLinux project. All Yocto build state lives here.      |
| `PetaLinux/<target>/images/linux/`  | `BOOT.BIN`, `image.ub`, `boot.scr`, `rootfs.tar.gz`, etc. |
| `bootimages/`                       | Per-target zipped boot files (`<prj>_<target>_petalinux-<ver>.zip`). |

None of these directories are committed to the repository.
