# Revision History

## 2025.2

First release, built for Vivado / Vitis / PetaLinux / Yocto (AMD EDF) 2025.2.

### Targets and flows

* **Versal VCK190 (`vck190_fmcp1`):** both QSFP28 ports as 1x100GbE CAUI-4, each driven by a
  Versal Integrated MRMAC with an AXI MCDMA datapath to DDR over the NoC.
* **Zynq UltraScale+ RFSoC (`zcu111`, `zcu208`, `zcu216`):** 100G ports driven by the
  UltraScale+ Integrated 100G Ethernet (CMAC) — both ports on the ZCU111, port 0 on the
  ZCU208/ZCU216 (only one CMAC reaches the FMC+ transceivers there).
* **Zynq UltraScale+ 40G (`zcu102_hpc0`, `zcu106_hpc0`, `zcu111_ss`, `zcu208_ss`,
  `zcu216_ss`):** both QSFP28 ports as 40GBASE-R4 with the 40G/50G Ethernet Subsystem.
* **Kintex UltraScale+ KCU116 (`kcu116`, `kcu116_ss`):** one QSFP28 port (100G CMAC or 40G
  subsystem) behind a MicroBlaze, standalone application only.
* **Standalone echo server** for every target: a raw-Ethernet application answering ARP, ICMP
  ping and UDP echo on all QSFP28 ports, with no operating system.
* **PetaLinux** images for all Zynq UltraScale+ and Versal targets, and **Yocto / AMD EDF**
  images (gen-machineconf `parse-sdt` flow) for the same targets. 2025.2 is the last version
  with a PetaLinux flow; the Yocto flow replaces it from the next version.
* **Cross-platform build runner** (`build.py`, `build.sh` / `build.bat`) for all stages on
  Windows and Linux; `./build.sh package` rewrites a boot-image zip whenever the artifacts it
  gathers are newer than the zip, so a rebuilt image is never left behind by an old zip.

### Hardware design

* MRMAC client AXI4-Stream adapters (`mrmac_axis_adapter.v`) that pack the MRMAC's six-lane
  100G client interface into a standard AXI4-Stream, so frames are delineated correctly.
* Per-lane CAUI-4 GT user clocking on Versal, required for four-lane alignment; GT quad
  configured for the MRMAC's 100G CAUI-4 datapath (80-bit RAW, 25.78125 Gb/s, LCPLL
  integer-N, 322.265625 MHz reference clock); MRMACs placed next to their GT quads.
* **RX frame FIFO on every target** (store-and-forward, 2048 entries per port). The MACs of
  this design cannot pause their receive stream, and the DMA path behind them can stall (and
  at 100G is slower than the line rate). Previously, a full FIFO in the receive path could
  silently lose individual data beats, so truncated or merged frames could reach Linux while
  the MAC counters stayed clean. Now frames are only ever dropped whole — on overflow, when
  the MAC flags them as errored, or when a MAC reset cuts them — and every drop is counted in
  registers readable over AXI (see [RX drop counters](advanced.md#rx-drop-counters)).
* **40G receive datapath clocking (ZCU102, ZCU106, `_ss` and `kcu116_ss` targets).** The
  40G/50G Ethernet Subsystem's RX stream is now captured with the clock that launches it (the
  core's transmit clock). Previously the RX logic ran on the recovered receive clock, which
  could corrupt received data, lose frames silently or wedge a port after an interface
  re-open or a loss of signal.
* **RX flush guard (Zynq UltraScale+, MicroBlaze).** The receive chain is no longer reset by
  MAC or GT resets, which could cut a frame being delivered and merge it with the next one;
  it is flushed only when the DMA's receive channel is reset, and traffic is released to the
  DMA on a frame boundary.
* **TX frame gate (40G targets).** After a reset on the MAC side of the transmit path, the
  remaining tail of a frame whose start was flushed is discarded instead of being transmitted
  as a frame of its own.
* QSFP28 module sideband held out of reset at configuration time (`axi_gpio_qsfp`
  `C_DOUT_DEFAULT = 0x2`), so optical modules and AOCs power up enabled.
* The project's top module is pinned to the block-design wrapper.
* KCU116: legal configuration rate and 128 MB QSPI flash size for the configuration memory.

### Linux

* Kernel patch enabling the Si5328 CKOUT2 output, so QSFP28 port 1's reference clock
  (GBTCLK1) runs.
* **MRMAC link monitor (Versal).** A port with a link partner comes up automatically at boot
  and recovers on cable re-seat or partner power-on (`MRMAC link up` / `MRMAC link down`),
  with the link state reflected in the netdev carrier; no manual `ip link` bounce is needed.
* **CMAC and 40G/50G Ethernet Subsystem support (Zynq UltraScale+)** in the `xilinx_axienet`
  driver, with the 40G subsystem's own register map (fixes a kernel panic at the first
  interface up) and a correct read of the latched link status (fixes a 40G link that never
  came up on an idle system).
* **HSE link monitor (Zynq UltraScale+).**
  * A port that aligns but receives a flood of decoding errors (most of its frames lost while
    the carrier stayed up) is now detected and recovered with a receive-only GT reset,
    normally within one second.
  * Recovery uses receive-only GT resets; a full GT reset (which also restarts the port's
    transmitter and disturbs the link partner) is used only when the GT itself is not ready,
    or when a usable signal is present on all lanes and receive-only resets did not help.
    While there is no signal at all (no light, no module), a dark port no longer resets its
    transmitter over and over.
  * Short partner outages that heal before the carrier is dropped are now visible: they are
    logged (rate-limited) and counted in `ethtool -S` (`hse_rx_unaligned_events` etc.).
  * The carrier is dropped only after three bad samples, so transients do not take a working
    link down.
  * A port whose MAC keeps receiving good frames while Linux receives none is restarted
    automatically (`HSE RX wedged ...`).
  * New `ethtool -S` counters: `hse_link_down`, `hse_rx_unaligned_events`,
    `hse_rx_unaligned_samples`, `hse_rx_error_samples`, `hse_gt_rx_resets`,
    `hse_gt_reset_alls`, `hse_rx_wedge_restarts`, and the MAC's receive statistics as 64-bit
    counters (`hse_mac_rx_total`, `_good`, `_bad_fcs`, `_stomped_fcs`, `_fragment`,
    `_truncated`, `_bad_code`). The 40G subsystem's statistics are latched correctly (they
    previously read 0).
* **RX ring default of 1024 descriptors** on all QSFP28 ports (was 128): with a small ring, any
  short scheduling gap made the DMA drop frames, visible only as TCP retransmits.
* **`rx_dma_pkt_drop`** in `ethtool -S`: frames the DMA dropped for lack of a free receive
  descriptor, which previously appeared in no counter. Kept across interface down/up.
* **Kernel command line and hostname applied in the Yocto images.** The design's kernel
  arguments (`cma=…`, `clk_ignore_unused` on Versal) are added to the EDF boot script /
  boot entry, and the hostname is `<board>-qsfp-2025-2` (previously the EDF default
  `amd-edf`). The VCK190 PetaLinux BSP now uses the same hostname scheme and `cma=1536M`.
* **VCK190 U-Boot enables the FMC VADJ rail** (1.5 V) before every boot in both Linux flows, so
  the FMC's Si5328 and modules are powered when Linux probes them.
* Board Ethernet port fixed on the Zynq UltraScale+ and Versal images: the board's DP83867
  PHY is described with its RGMII delays (it previously linked at 1G but passed no packets)
  and gets a fixed MAC address.
* Bundled `qsfp-loopback-test` self-test in every image: with a QSFP28 cable between the two
  ports it validates both datapaths end to end (pktgen frame blast, then ping and iperf3
  across the cable in separate network namespaces); with loopback modules, `--single`
  self-tests every plugged port.
* Image tools: `ethtool`, `iperf3`, `iproute2` (with `nstat` on Yocto), `i2c-tools`,
  `phytool` and the kernel `pktgen` module.

### Standalone

* The echo server programs the Si5328 and the VADJ rail (VCK190) itself, re-attempts
  alignment while a port is down, and reports `link UP` / `link DOWN`.
* On the 40G targets it keeps the MAC's statistics latching on the statistics tick register
  (`MODE_REG` bit 30), so the MAC statistics counters work.
* MicroBlaze: the UART16550 is programmed before the first console output.

### Known limitations

* The link partner must have FEC turned off (forced off, not `auto`).
* Linux throughput is limited by the processor (about 1.2–1.4 Gbit/s TCP per port on the
  VCK190, about 0.9 Gbit/s on the ZCU102/ZCU106), far below the line rate; see
  [what to expect](linux_usage.md#what-to-expect-throughput).
* The MCDMA receive path of each port is 512 bits × 100 MHz = 51.2 Gb/s; at 100G, sustained
  line-rate bursts beyond the RX frame FIFO's size are dropped (whole frames, counted).
* ZCU208/ZCU216 100G targets have one QSFP28 port; KCU116 targets have one QSFP28 port and
  no Linux flow.
