# Revision History

## 2025.2

* First revision.
* Built for Vivado / PetaLinux 2025.2 and the AMD VCK190 (FMCP1).
* Each QSFP28 port driven as a single 100GbE (CAUI-4) channel by the
  Versal Integrated MRMAC, with an AXI MCDMA datapath to DDR over the
  NoC, driven under PetaLinux by the `xilinx_axienet` driver.
* Custom RTL adapter (`mrmac_axis_adapter.v`) that packs the MRMAC's
  six-lane 100G client interface into a single standard AXI4-Stream so
  frames are delineated correctly.
* Per-lane CAUI-4 GT user-clocking required for four-lane block lock.
* GT quad configured for the MRMAC's 100G CAUI-4 datapath (PRESET None,
  80-bit RAW, 25.78125 Gb/s, LCPLL integer-N, 322.265625 MHz reference
  clock).
* PetaLinux BSP composed from a board fragment (`bsp/vck190/`) plus a
  port-config overlay (`bsp/ports-versal-0/` for one port,
  `bsp/ports-versal-01/` for both). See [advanced](advanced) for the
  full layout.
* Device-tree bindings for MRMAC bring-up: GT-control GPIO
  (`gt-*-gpios`), MCDMA `compatible = "xlnx,eth-dma"` override,
  `max-speed = <100000>`, and the Si5328 clock-generator node.
* Kernel patch enabling the Si5328 CKOUT2 output so the second QSFP28
  port's GT reference clock (GBTCLK1) is driven.
* QSFP module sideband held out of reset at configuration time
  (`axi_gpio_qsfp` `C_DOUT_DEFAULT = 0x2`), so optical modules / AOCs power
  up enabled rather than held dark in reset.
* Kernel patch adding an MRMAC link carrier monitor: a port with a 100G
  partner comes up automatically over a cable and recovers on cable
  re-seat or partner power-on (`MRMAC link up` / `MRMAC link down`), with
  link state reflected in the netdev carrier.
* Bundled `mrmac-loopback-test` rootfs self-test for validating each
  port's datapath with a passive 100G loopback module.
