# 100G/40G Ethernet Reference Designs for the Opsero 2x QSFP28 FMC

## Description

This project demonstrates the use of the Opsero [2x QSFP28 FMC] (OP120) with QSFP28 modules on
AMD Versal, Zynq UltraScale+ and Kintex UltraScale+ development boards. Each QSFP28 port carries
a single Ethernet channel over its four bonded transceiver lanes, at a line rate set by the
target board's transceivers:

* **100G (CAUI-4)** on the GTY-based boards, driven by a hardened 100G MAC — the
  [Integrated 100G Multirate Ethernet MAC (MRMAC)] on the Versal VCK190, or the
  [UltraScale+ Integrated 100G Ethernet (CMAC)] on the RFSoC boards (ZCU111/ZCU208/ZCU216)
  and the Kintex UltraScale+ KCU116.
* **40G (40GBASE-R4)** on the GTH-based ZCU102 and ZCU106, driven by the soft
  [40G/50G Ethernet Subsystem] MAC/PCS — also available as alternative `_ss` targets of
  the GTY boards.

In every design, packet data is moved to/from DDR by an AXI MCDMA; the ports are driven under
Linux (PetaLinux or Yocto) by the AXI Ethernet driver, or bare-metal by the included
echo-server application. The KCU116 has no processing system, so it gets a Linux-capable
MicroBlaze soft processor in front of the same datapath.

![2x QSFP28 FMC with VCK190](docs/source/images/vck190-with-2x-qsfp28-fmc_03.jpg "2x QSFP28 FMC with VCK190")

Important links:

* The user guide for these reference designs is hosted here: [2x QSFP28 FMC reference designs docs](https://qsfp28.ethernetfmc.com "2x QSFP28 FMC reference designs docs")
* To report a bug: [Report an issue](https://github.com/fpgadeveloper/2x-qsfp28-fmc/issues "Report an issue").
* For technical support: [Contact Opsero](https://opsero.com/contact-us "Contact Opsero").
* To purchase the mezzanine card: [2x QSFP28 FMC order page](https://opsero.com/product/2x-qsfp28-fmc "2x QSFP28 FMC order page").

## Requirements

This project is designed for version 2025.2 of the Xilinx tools (Vivado/Vitis/PetaLinux).
If you are using an older version of the Xilinx tools, then refer to the
[release tags](https://github.com/fpgadeveloper/2x-qsfp28-fmc/tags "releases")
to find the version of this repository that matches your version of the tools.

In order to test this design on hardware, you will need the following:

* Vivado 2025.2
* Vitis 2025.2
* PetaLinux Tools 2025.2
* [2x QSFP28 FMC]
* One of the target platforms listed below
* A license for the Ethernet MAC IP used by your target (see
  [Ethernet IP licensing](#ethernet-ip-licensing) below)

### Ethernet IP licensing

Every target design uses one of three AMD Ethernet MAC IPs, and all three require a license
to generate a bitstream — but they are licensed differently. The two hardened 100G MACs have
**no-cost** licenses that just need to be added to your account on the
[AMD licensing site](https://www.xilinx.com/getlicense), while the soft 40G/50G MAC used by
the 40G designs is a **purchased** core, with a 30-day evaluation license available for
testing:

| Ethernet MAC IP | License | Required by targets |
|-----------------|---------|---------------------|
| [Integrated 100G Multirate Ethernet MAC (MRMAC)] | No cost | `vck190_fmcp1` |
| [UltraScale+ Integrated 100G Ethernet (CMAC)] | No cost | `zcu111`, `zcu208`, `zcu216`, `kcu116` |
| [40G/50G Ethernet Subsystem] | Purchase (30-day evaluation available) | `zcu102_hpc0`, `zcu106_hpc0`, `zcu111_ss`, `zcu208_ss`, `zcu216_ss`, `kcu116_ss` |

## Target designs

This repo contains one or more designs that target various supported development boards and their
FMC connectors. The table below lists the target design name, the QSFP28 ports supported by the design and
the FMC connector on which to connect the 2x QSFP28 FMC.

<!-- updater start -->
### 40G designs

| Target board          | Target design      | Link speeds <br> supported | QSFP28 ports | FMC Slot    | Yocto | PetaLinux | Vivado<br> Edition | IP<br>License |
|-----------------------|--------------------|------------|-------------|-------------|-------|-------|-------|-------|
| [ZCU102]              | `zcu102_hpc0`      | 40G        | 2x          | HPC0        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU106]              | `zcu106_hpc0`      | 40G        | 2x          | HPC0        | :white_check_mark: | :white_check_mark: | Standard :free: | Required |
| [ZCU111]              | `zcu111_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU208]              | `zcu208_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU216]              | `zcu216_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [KCU116]              | `kcu116_ss`        | 40G        | 1x          | HPC         | :x:   | :white_check_mark: | Standard :free: | Required |

### 100G designs

| Target board          | Target design      | Link speeds <br> supported | QSFP28 ports | FMC Slot    | Yocto | PetaLinux | Vivado<br> Edition | IP<br>License |
|-----------------------|--------------------|------------|-------------|-------------|-------|-------|-------|-------|
| [VCK190]              | `vck190_fmcp1`     | 100G       | 2x          | FMCP1       | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU111]              | `zcu111`           | 100G       | 2x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU208]              | `zcu208`           | 100G       | 1x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU216]              | `zcu216`           | 100G       | 1x          | FMCP        | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [KCU116]              | `kcu116`           | 100G       | 1x          | HPC         | :x:   | :white_check_mark: | Standard :free: | Required |

[ZCU102]: https://www.xilinx.com/zcu102
[ZCU106]: https://www.xilinx.com/zcu106
[ZCU111]: https://www.xilinx.com/zcu111
[ZCU208]: https://www.xilinx.com/zcu208
[ZCU216]: https://www.xilinx.com/zcu216
[KCU116]: https://www.xilinx.com/kcu116
[VCK190]: https://www.xilinx.com/vck190
<!-- updater end -->

Notes:
1. The Vivado Edition column indicates which designs are supported by the Vivado *Standard* Edition, the
   FREE edition which can be used without a license. Vivado *Enterprise* Edition requires
   a license however a 30-day evaluation license is available from the AMD Xilinx Licensing site.
2. All of the designs use an Ethernet MAC IP that requires a license to generate a bitstream
   (see [Ethernet IP licensing](#ethernet-ip-licensing)): the 100G designs use a hardened MAC
   with a no-cost license (MRMAC on the VCK190, CMAC on all others), while the 40G designs use
   the 40G/50G Ethernet Subsystem, a purchased core with a 30-day evaluation license available.

## Software

These reference designs can be driven by a **standalone** (bare-metal) application or
from within an embedded **Linux** environment. The repository includes all the scripts
and code needed to build either one.

For Linux, two build flows are provided, both based on AMD's 2025.2 tools:

* **PetaLinux** — AMD's long-standing embedded Linux build tool (see the `PetaLinux/`
  directory).
* **Yocto / EDF** — AMD's Embedded Development Framework, the announced successor to
  PetaLinux, built with the `gen-machineconf parse-sdt` flow (see the `Yocto/`
  directory).

> [!IMPORTANT]
> **The PetaLinux flow is being retired for this repository.** Version 2025.2 is the
> last tool release for which we will support PetaLinux; from the next tool version
> onward, Linux images will be built with the Yocto / EDF flow only. New work should
> use the Yocto flow.

For 2025.2, both flows produce an equivalent Linux image with the same applications,
so you can pick whichever fits your workflow. The [target design tables](#target-designs)
show which boards are supported by each flow.

| Environment | Build flow          | Available applications |
|-------------|---------------------|------------------------|
| Standalone  | Vitis               | Raw-Ethernet echo server (ARP, ICMP ping, UDP echo on all QSFP28 ports) |
| Linux       | PetaLinux  /  Yocto | Built-in Linux commands<br>Additional tools: ethtool, iperf3<br>Bundled self-test: `qsfp-loopback-test` |

The standalone echo server brings up the QSFP28 ports and answers ARP, ICMP ping and
UDP echo on each of them, with no operating system involved. Under Linux, the same
ports come up as standard network interfaces driven by the AXI Ethernet driver, which
you can configure and test with the bundled tools.

## Build instructions

Clone the repo and change into its directory:
```
git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
cd 2x-qsfp28-fmc
```

### Cross-platform build runner

All builds are driven by `build.py` at the repo root, on both Windows
(git bash) and Linux. The `build.sh` / `build.bat` shim finds a suitable
Python 3 automatically (including the one bundled with the AMD tools).
Pick a target design label from the tables above (or run `./build.sh
list`), then run the build command for the stage(s) you want — each
command builds whatever it depends on automatically and skips anything
already built. On Windows without git bash, run the same commands from
Command Prompt or PowerShell using `build.bat` (e.g. `build.bat xsa
--target <target>`).

You don't need to source the AMD tools first — the build runner finds
Vivado, Vitis and PetaLinux automatically in their standard install
locations and sets up the environment each stage needs. If your tools
are installed somewhere non-standard and the runner can't find them,
source the tool settings yourself before running the build.

#### Build the Vivado project (bitstream + XSA)

```
./build.sh xsa --target <target>
```

#### Build the standalone application

Builds the Vitis workspace and the baremetal boot file (`BOOT.BIN`, or a
`qsfp_boot.bit` with the ELF embedded for the MicroBlaze targets):

```
./build.sh standalone --target <target>
```

#### Build PetaLinux (Linux only)

```
./build.sh petalinux --target <target>
```

#### Build everything

Builds all of the above that the target supports, then gathers the boot
images into `bootimages/*.zip`:

```
./build.sh all --target <target>
./build.sh all --target all          # every target in the repo
```

Also available: `status`, `clean`, `project` — see
`./build.sh --help`. On Windows, the PetaLinux and Yocto stages require a
Linux machine; the runner says so and prints the hand-off command. The
legacy `make` interface still works on Linux (each Makefile now wraps
`build.sh`) but is deprecated and will be removed at the next version
update.

## Contribute

We strongly encourage community contribution to these projects. Please make a pull request if you
would like to share your work:
* if you've spotted and fixed any issues
* if you've added designs for other target platforms

Thank you to everyone who supports us!

## About us

This project was developed by [Opsero Inc.](https://opsero.com "Opsero Inc."),
a tight-knit team of FPGA experts delivering FPGA products and design services to start-ups and tech companies.
Follow our blog, [FPGA Developer](https://www.fpgadeveloper.com "FPGA Developer"), for news, tutorials and
updates on the awesome projects we work on.

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[Integrated 100G Multirate Ethernet MAC (MRMAC)]: https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/mrmac.html
[UltraScale+ Integrated 100G Ethernet (CMAC)]: https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/cmac_usplus.html
[40G/50G Ethernet Subsystem]: https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/ef-di-50gemac.html
