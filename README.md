# 100G Ethernet Reference Design for the Opsero 2x QSFP28 FMC

## Description

This project demonstrates the use of the Opsero [2x QSFP28 FMC] (OP120) with 100G QSFP28 modules
on AMD Versal adaptive SoC development boards. Each QSFP28 port is driven by the Versal
[Integrated 100G Multirate Ethernet MAC (MRMAC)] configured for a single 100GbE (CAUI-4) channel,
with packet data moved to/from DDR by an AXI MCDMA and driven under PetaLinux by the AXI Ethernet
driver.

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
### 100G designs

| Target board          | Target design      | Link speeds <br> supported | QSFP28 ports | FMC Slot    | Vivado<br> Edition |
|-----------------------|--------------------|------------|-------------|-------------|-------|
| [VCK190]              | `vck190_fmcp1`     | 100G       | 2x          | FMCP1       | Enterprise |

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

Clone the repo:
```
git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
```

Source Vivado and PetaLinux tools:

```
source <path-to-petalinux>/2025.2/settings.sh
source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
```

Build all (Vivado project and PetaLinux):

```
cd 2x-qsfp28-fmc/PetaLinux
make petalinux TARGET=vck190_fmcp1
```

## Troubleshooting

### PetaLinux build fails with `bitbake petalinux-image-minimal failed` and sstate fetch errors

If a `make petalinux TARGET=<board>` run ends with errors like

```
ERROR: <package>-<ver>-r0 do_..._setscene: Fetcher failure: Unable to find file file://.../sstate:...
[ERROR] Command bitbake petalinux-image-minimal failed
```

the actual build is not broken. These `_setscene` errors come from
bitbake trying to pull prebuilt artifacts from the public Xilinx
sstate-cache mirror, which occasionally returns 404 for individual
packages. Bitbake falls back to building those packages locally and
succeeds, but still exits non-zero because of the failed fetches —
so the Makefile stops before the `petalinux-package` step that
produces `BOOT.BIN`.

**Fix: just re-run the same command.** The second attempt finds the
missing packages in the local sstate cache (populated by the first
run) and completes cleanly, producing `BOOT.BIN`. The reference
design itself is fine; this is a transient issue with the public
mirror.

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
