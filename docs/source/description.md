# Description

In this reference design, each port of the [2x QSFP28 FMC] is driven by a hardened or soft
Ethernet MAC that depends on the target device family: on Versal, the
[Integrated 100G Multirate Ethernet MAC (MRMAC)] configured for a single 100GbE (CAUI-4)
channel; on the Zynq UltraScale+ RFSoC boards, the UltraScale+ Integrated 100G Ethernet
(CMAC) hard block; and on the GTH-based ZynqMP boards (ZCU102/ZCU106), the 40G/50G High
Speed Ethernet Subsystem at 40G. All four transceiver lanes of a QSFP28 port are bonded into
one MAC. Packet data is moved to and from system memory (DDR) by an AXI MCDMA and the
ports are driven under Linux by the AXI Ethernet (`xilinx_axienet`) driver.

This contrasts with the Opsero [Quad SFP28 FMC] reference design, which uses the 10G/25G Ethernet
Subsystem with one independent channel per SFP28 port. Here, the 100G data rate per port and the
CAUI-4 lane bonding require the integrated MRMAC and a different datapath, described below.

## Block diagram

![Versal MRMAC 100G design block diagram](images/versal-mrmac-100g-block-diagram.png)

Each of the two QSFP28 ports is an independent, identical 100G subsystem:

* **MRMAC (1x100GbE CAUI-4).** The Versal integrated MRMAC is configured as a single 100GbE
  port using the `1x100GE CAUI-4 Wide` preset, with an independent 384-bit non-segmented client
  interface.
* **GT Quad (GTY).** Each port uses one GTY quad: four lanes, each running at 25.78125 Gb/s
  (raw, 80-bit datapath) off a 322.265625 MHz reference clock. Lane bonding into a single 100G
  MAC happens inside the MRMAC core. Because CAUI-4 requires all four lanes to align, the GT
  user-clocking is per-lane (each lane's recovered clock drives its own MRMAC serdes/core
  clock).
* **MRMAC client AXIS adapter.** The MRMAC 100G client is not a standard AXI4-Stream bus — its
  384-bit data rides on six 64-bit lane ports plus per-lane control words. A small custom RTL
  adapter packs/unpacks these six lanes into one standard 384-bit AXI4-Stream so that frames are
  delineated correctly (one `TLAST` per Ethernet frame).
* **Datapath to DDR.** A width converter (384 ↔ 512 bit) and an asynchronous CDC FIFO bridge the
  390.625 MHz MRMAC client clock domain to the system clock domain, where an AXI MCDMA moves
  packet data to and from DDR over three NoC AXI ports (scatter-gather, MM2S, S2MM).
* **Clocking.** A single Si5328 jitter-attenuating clock generator on the FMC sources both GT
  reference clocks (GBTCLK0 for port 0, GBTCLK1 for port 1) at 322.265625 MHz.
* **Control and sideband.** Per port, an AXI-Lite control path reaches the MRMAC, the MCDMA, and
  a GT-control AXI GPIO (which lets the Linux driver reset the transceiver and read reset-done).
  An AXI IIC controller per port reaches the QSFP module management bus, a shared AXI IIC reaches
  the Si5328, and the QSFP module sideband signals plus user LEDs (link status) are driven from
  AXI GPIO — held out of reset at power-on so an inserted optical module/AOC comes up enabled.

## ZynqMP targets (ZCU111, ZCU208, ZCU216, ZCU102, ZCU106)

ZynqMP devices have no MRMAC, so these targets use a different MAC while keeping the same
architecture (per-port MAC + AXI MCDMA to DDR, CPU handles all packets):

* **RFSoC boards (ZCU111/ZCU208/ZCU216) — 100G CMAC.** Each active port is an UltraScale+
  Integrated 100G Ethernet (CMAC) hard block in CAUI-4 mode (4 GTY lanes at 25.78125 Gb/s,
  322.265625 MHz refclk) with its in-core GT quad and a standard 512-bit AXI4-Stream client —
  no custom RTL adapters are needed. On the ZCU111 both ports run 100G; on the ZCU208/ZCU216
  only one of the two CMAC blocks can physically reach the FMC+ GT quads, so those targets
  implement a single 100G port (QSFP port 0) and hold the port 1 module in reset.
* **ZCU102/ZCU106 — 2x 40G.** The GTH transceivers on these boards max out below the 25.78125
  Gb/s CAUI-4 lane rate, so each port is a 40G/50G High Speed Ethernet Subsystem (soft
  MAC/PCS) in 40GBASE-R4 mode (4 GTH lanes at 10.3125 Gb/s, 156.25 MHz refclk) with a 256-bit
  AXI4-Stream client. This core requires an AMD license (an evaluation license works for
  testing).
* **Datapath to DDR.** Per port, an asynchronous CDC FIFO (plus a 512↔256-bit width converter
  on the 40G targets) bridges the MAC client clock to the 100 MHz system clock, where a
  512-bit AXI MCDMA moves packet data to and from the PS DDR through its own `S_AXI_HPx_FPD`
  port.
* **Linux driver.** The ports are driven by the same `xilinx_axienet` driver as the Versal
  MRMAC targets; CMAC / 40G-50G MAC support is added by a kernel patch carried in the Yocto
  board BSPs, including a carrier monitor that brings the link up automatically once the
  Si5328 reference clock is programmed and a partner signal is present.

## Supported Hardware Platforms

The hardware design provided in this reference is based on Vivado and supports the AMD Versal
evaluation board(s) listed below. The repository contains all necessary scripts and code to build
the design for the supported platform(s):

{% for group in data.groups %}
{% set boards = {} %}
{% for design in data.designs %}{% if design.publish and design.group == group.label %}
{% if design.board not in boards %}{% set _ = boards.update({design.board: {"link": design.link, "connectors": []}}) %}{% endif %}
{% if design.connector not in boards[design.board]["connectors"] %}{% set _ = boards[design.board]["connectors"].append(design.connector) %}{% endif %}
{% endif %}{% endfor %}
{% if boards | length > 0 %}
### {{ group.name }} boards

| Carrier board    | Supported FMC connector(s) | 100G support |
|------------------|----------------------------|--------------|
{% for name, board in boards.items() %}| [{{ name }}]({{ board.link }}) | {% for connector in board.connectors %}{{ connector }} {% endfor %} | ✅ |
{% endfor %}
{% endif %}
{% endfor %}

The 2x QSFP28 FMC requires a carrier board whose FMC connector routes eight gigabit transceivers
(two QSFP28 ports × four lanes) capable of 25.78125 Gb/s, and an AMD device that contains the
integrated MRMAC. The VCK190 satisfies both via its FMCP1 connector.

## Supported Software

This reference design is driven within a PetaLinux environment. The repository includes all
necessary scripts and code to build the PetaLinux environment. The table below outlines the
corresponding applications available:

| Environment      | Available Applications  |
|------------------|-------------------------|
| PetaLinux        | Built-in Linux commands<br>Additional tools: ethtool, iperf3<br>Bundled self-test: `mrmac-loopback-test` |

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[Quad SFP28 FMC]: https://docs.opsero.com/op081/datasheet/overview/
[Integrated 100G Multirate Ethernet MAC (MRMAC)]: https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/mrmac.html
