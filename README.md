# 100G Ethernet Reference Design for the Opsero 2x QSFP28 FMC

## Description

This project demonstrates the use of the Opsero [2x QSFP28 FMC] (OP120) with 100G QSFP28 modules
on AMD Versal adaptive SoC development boards. Each QSFP28 port is driven by the Versal
[Integrated 100G Multirate Ethernet MAC (MRMAC)] configured for a single 100GbE (CAUI-4) channel,
with packet data moved to/from DDR by an AXI MCDMA and driven under PetaLinux by the AXI Ethernet
driver.

![2x QSFP28 FMC with VCK190](docs/source/images/vck190-with-2x-qsfp28-fmc_03.jpg "2x QSFP28 FMC with VCK190")

Important links:

* The user guide for these reference designs is hosted here: [100G Ethernet for 2x QSFP28 FMC docs](https://qsfp28.ethernetfmc.com "100G Ethernet for 2x QSFP28 FMC docs")
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
* PetaLinux Tools 2025.2
* [2x QSFP28 FMC]
* One of the target platforms listed below
* [AMD Versal Integrated MRMAC License](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/mrmac.html)

## Target designs

This repo contains one or more designs that target various supported development boards and their
FMC connectors. The table below lists the target design name, the QSFP28 ports supported by the design and
the FMC connector on which to connect the 2x QSFP28 FMC.

<!-- updater start -->
### 40G designs

| Target board          | Target design      | Link speeds <br> supported | QSFP28 ports | FMC Slot    | Yocto | PetaLinux | Vivado<br> Edition | IP<br>License |
|-----------------------|--------------------|------------|-------------|-------------|-------|-------|-------|-------|
| [ZCU102]              | `zcu102_hpc0`      | 40G        | 2x          | HPC0        | :white_check_mark: | :x:   | Enterprise | Required |
| [ZCU106]              | `zcu106_hpc0`      | 40G        | 2x          | HPC0        | :white_check_mark: | :x:   | Standard :free: | Required |
| [ZCU111]              | `zcu111_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
| [ZCU208]              | `zcu208_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
| [ZCU216]              | `zcu216_ss`        | 40G        | 2x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
| [KCU116]              | `kcu116_ss`        | 40G        | 1x          | HPC         | :x:   | :white_check_mark: | Standard :free: | Required |

### 100G designs

| Target board          | Target design      | Link speeds <br> supported | QSFP28 ports | FMC Slot    | Yocto | PetaLinux | Vivado<br> Edition | IP<br>License |
|-----------------------|--------------------|------------|-------------|-------------|-------|-------|-------|-------|
| [VCK190]              | `vck190_fmcp1`     | 100G       | 2x          | FMCP1       | :white_check_mark: | :white_check_mark: | Enterprise | Required |
| [ZCU111]              | `zcu111`           | 100G       | 2x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
| [ZCU208]              | `zcu208`           | 100G       | 1x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
| [ZCU216]              | `zcu216`           | 100G       | 1x          | FMCP        | :white_check_mark: | :x:   | Enterprise | Required |
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
2. The Versal Integrated MRMAC requires a (free) license to generate a bitstream.

## Software

These reference designs can be driven within a PetaLinux environment.
The repository includes all necessary scripts and code to build the PetaLinux environments. The table
below outlines the corresponding applications available in each environment:

| Environment      | Available Applications  |
|------------------|-------------------------|
| PetaLinux        | Built-in Linux commands<br>Additional tools: ethtool, iperf3 |

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
