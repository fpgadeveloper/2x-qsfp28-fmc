# Testing under Linux

This page describes how to use and test the QSFP28 ports once the [PetaLinux](petalinux) or
[Yocto](yocto) image has booted. Both images contain the same drivers and tools, so
everything here applies to both. The commands are run as the default user with `sudo`
(`petalinux` on PetaLinux, `amd-edf` on Yocto).

The examples below were captured on a `vck190_fmcp1` (2x 100G MRMAC) and on a `zcu102_hpc0`
(2x 40G, 40G/50G Ethernet Subsystem) with a QSFP28 cable between QSFP28 port 0 and port 1.
Substitute your own interface names (see below).

## Interface names

The QSFP28 ports are bound to the `xilinx_axienet` driver; the board's own Ethernet ports use
the `macb` driver and get the systemd predictable names `endN`. The QSFP28 ports receive
their MAC addresses from the device tree after the interface-rename rule has run, so they keep
the kernel's `ethN` names:

| Target family | QSFP28 port 0 | QSFP28 port 1 | Board Ethernet |
|---------------|---------------|---------------|----------------|
| Versal (`vck190_fmcp1`) | `eth0` (`80000000.mrmac`) | `eth1` (`80010000.mrmac`) | `end0` (GEM0), `end1` (GEM1) |
| Zynq UltraScale+ (`zcu102_hpc0`, `zcu106_hpc0`) | `eth1` (`80060000.l_ethernet`) | `eth2` (`80080000.l_ethernet`) | `end0` (GEM3) |

On every target QSFP28 port 0 has the MAC address `00:0a:35:00:00:00` and port 1
`00:0a:35:00:00:01`, which is the most reliable way to tell the ports apart (on the
single-port targets there is only one QSFP28 interface). Other ways to check the mapping:

```
$ ip -br link
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
end0             UP             00:0a:35:06:21:02 <BROADCAST,MULTICAST,UP,LOWER_UP>
eth1             UP             00:0a:35:00:00:00 <BROADCAST,MULTICAST,UP,LOWER_UP>
eth2             UP             00:0a:35:00:00:01 <BROADCAST,MULTICAST,UP,LOWER_UP>

$ ethtool -i eth1
driver: xaxienet
version: 1.00a
bus-info: 80060000.l_ethernet
...
```

`bus-info` is the address of the port's MAC in the design's address map (see
[Address maps](advanced.md#address-and-interrupt-maps)).

## Link bring-up and monitoring

The MACs of this design have no PHY and raise no link-change interrupt, so the driver runs a
background **link monitor** for each port. When the interface is opened, it comes up with the
carrier off; the monitor then drives the carrier from the MAC's RX status and keeps
re-attempting alignment while the link is down. There is no need to bounce the interface or
reset anything by hand: a port comes up on its own at boot, when a cable is plugged in, or
when the link partner powers up, and it recovers on its own after the partner goes away and
comes back. `ip link` shows a port `UP`/`LOWER_UP` only while it has a link.

### Versal (MRMAC)

```
xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 100000 (link monitored)
xilinx_axienet 80000000.mrmac eth0: MRMAC link up at 100000 (0 recovery resets)
xilinx_axienet 80000000.mrmac eth0: MRMAC link down
```

The link-up message reports how many recovery resets it took.

### Zynq UltraScale+ (CMAC and 40G/50G Ethernet Subsystem)

The kernel messages of the HSE ("high-speed Ethernet") link monitor:

| Message | Meaning |
|---------|---------|
| `HSE MAC link up at 40000 Mbps (N recovery resets)` | The port has a link (100000 Mbps on the CMAC targets). |
| `HSE MAC link down (rx_sts … blk_lck … gt_done … , N recovery resets)` | The carrier was dropped after three bad samples 200 ms apart. The raw RX status, per-lane block lock and GT reset-done values are printed for diagnosis. |
| `HSE MAC link still down (…, N recovery resets)` | Repeated (rate-limited) while the link stays down. |
| `HSE RX not aligned (…), rechecking` / `HSE RX decoding errors (rx_sts … bad_code … bip_max …), rechecking` | The first bad sample of an episode: lanes not aligned, or (40G) a flood of bad 64b/66b codes or per-lane BIP errors. |
| `HSE RX recovered after N bad sample(s) in M ms, carrier kept` | A short episode that healed by itself before the carrier was dropped. |
| `HSE RX lost alignment/lock since the previous check (…), healed, carrier kept` | The RX lost alignment between two checks and was healthy again at the check (for example while the partner restarted its transmitter). |
| `HSE RX wedged (N good frames at the MAC, none received), restarting the interface` | The MAC kept receiving good frames but none reached Linux; the driver closed and reopened the interface (at most every 30 s). |

How the monitor recovers a 40G port that is down: as long as there is no usable signal (no
block lock on all four lanes, for example no light or no module), it only resets the GT
**receive** datapath — every 500 ms for the first three attempts, then less often — and never
resets the transmitter, so the link partner keeps receiving a stable signal. A full GT reset
is used only when the GT itself is not ready (reference clock or PLL) or when a usable signal
is present but three RX-only resets did not bring the link up. The CMAC targets use the
CMAC's only GT reset (reset-all).

Typical messages on a ZCU102 while port 1 receives no signal for a few seconds and then
recovers (excerpts):

```
xilinx_axienet 80080000.l_ethernet eth2: HSE RX not aligned (rx_sts 0xc8 bad_code 0 bip_max 0), rechecking
xilinx_axienet 80080000.l_ethernet eth2: HSE MAC link down (rx_sts 0xc0/0xc0 blk_lck 0x0/0xd (interval/now) gt_done 0x3 lane_sync 0x0 sts1 0x0 bad_code 0 bip_max 0, 0 recovery resets)
xilinx_axienet 80080000.l_ethernet eth2: HSE MAC link still down (rx_sts 0xc0/0xc0 blk_lck 0x0/0xd (interval/now) gt_done 0x3 lane_sync 0x0 sts1 0x0 bad_code 0 bip_max 0, 4 recovery resets)
xilinx_axienet 80080000.l_ethernet eth2: HSE MAC link up at 40000 Mbps (8 recovery resets)
```

Follow the messages live with `sudo dmesg -w`, or list them with
`sudo dmesg | grep -E "HSE|MRMAC|si53"`.

## The loopback self-test: `qsfp-loopback-test`

Every image includes `qsfp-loopback-test`, which validates the complete datapath of the
QSFP28 ports (GT, MAC, RX frame FIFO, CDC FIFOs, MCDMA, DDR and the driver) without a link
partner.

* **Port-to-port mode** (dual-port targets): connect a QSFP28 cable between QSFP28 port 0 and
  port 1 and run `sudo qsfp-loopback-test`.
* **Single mode** (any target; the only mode on single-port targets): fit a passive QSFP28
  loopback module in each port to test and run `sudo qsfp-loopback-test --single`. Every
  QSFP28 port with a loopback module is tested.

The test finds the QSFP28 interfaces itself (the ones bound to `xilinx_axienet`) and runs four
phases:

1. **Link check:** waits up to 30 s for the carrier.
2. **L2 frame blast:** the kernel `pktgen` module sends 500000 frames of 1500 bytes from
   port 0 to port 1 and back. Every frame must arrive, full size, with zero RX errors.
3. **IPv4 ping** across the cable. Each port is moved into its own network namespace first,
   so the traffic really crosses the cable (otherwise the kernel would short-circuit the two
   local addresses).
4. **iperf3 TCP throughput** in both directions. The result is reported, not judged: the
   CPU, not the link, limits it.

A passing run on a `zcu102_hpc0` (2x 40G):

```
===========================================================================
 QSFP28 loopback test
   mode   : port-to-port (DAC cable between the two QSFP ports)
   port A : eth1  (00:0a:35:00:00:00)
   port B : eth2  (00:0a:35:00:00:01)
   pktgen : 500000 frames x 1500 bytes per direction
===========================================================================

[1/4] Link check ... PASS (carrier on after 0s)
[2/4] L2 frame blast (pktgen)
      eth1 -> eth2: rx 500000/500000 frames, avg 1500B, 0 rx_errors, 61666pps
      eth2 -> eth1: rx 500000/500000 frames, avg 1500B, 0 rx_errors, 61402pps
[3/4] IPv4 ping across the cable ... PASS (0% packet loss)
[4/4] iperf3 TCP throughput
      A->B : 929 Mbits/sec
      B->A : 930 Mbits/sec

============================ summary =====================================
  link             : PASS
  L2 eth1 -> eth2  : PASS
  L2 eth2 -> eth1  : PASS
  IPv4 ping        : PASS
  iperf3           : PASS   (throughput is CPU-bound, informational)
  VERDICT: PASS
===========================================================================
```

and on a `vck190_fmcp1` (2x 100G), the frame blast and TCP phases:

```
[2/4] L2 frame blast (pktgen)
      eth0 -> eth1: rx 500000/500000 frames, avg 1500B, 0 rx_errors, 78024pps
      eth1 -> eth0: rx 500001/500000 frames, avg 1499B, 0 rx_errors, 77870pps
[3/4] IPv4 ping across the cable ... PASS (0% packet loss)
[4/4] iperf3 TCP throughput
      A->B : 1.38 Gbits/sec
      B->A : 1.27 Gbits/sec
```

(A received count one higher than the sent count, as in the second blast above, is a
background frame — for example an IPv6 neighbour discovery frame — that crossed the cable
during the blast; the test accepts it.) The options of the test (`qsfp-loopback-test -h`):

```
Usage:  qsfp-loopback-test [options] [iface0 iface1]
  -c COUNT   pktgen frames per direction   (default: 500000)
  -s SIZE    pktgen frame size in bytes    (default: 1500)
  -t SECS    iperf3 duration per direction (default: 5)
  -w SECS    link-up wait timeout          (default: 30)
  --single [iface]   self-loopback mode: test the given port, or every
                     detected QSFP port (loopback plugs fitted)
  --no-iperf         skip the iperf3 phase
  iface0 iface1      override auto-detection of the QSFP interfaces
```

If the self-test passes but traffic to a real peer does not work, the problem is in the link
or the peer (FEC setting, cable, addressing), not in the FPGA design.

## Inspecting a port with `ethtool`

```
$ ethtool eth0
Settings for eth0:
        Speed: 100000Mb/s
        Duplex: Full
        Link detected: yes
```

`Link detected: yes` with the port's line rate as `Speed` confirms that the four bonded
lanes have acquired the link.

### RX ring size

The RX descriptor ring of every QSFP28 port defaults to 1024 descriptors (`ethtool -g`):

```
$ ethtool -g eth1
...
Current hardware settings:
RX:             1024
TX:             128
```

These MACs cannot pause their receive stream, so when the CPU falls behind, the MCDMA drops
incoming frames as soon as the ring has no free descriptor; a large ring absorbs scheduling
gaps. You can change the size with `sudo ethtool -G eth1 rx <n>` while the interface is down.

### Port statistics

`ethtool -S <iface>` shows the driver's per-queue counters, followed by these design-specific
counters:

| Counter | Ports | Meaning |
|---------|-------|---------|
| `rx_dma_pkt_drop` | all | Frames the MCDMA dropped because no RX descriptor was free (CPU too slow to replenish the ring). These frames never reach Linux and appear in no other counter. Kept across interface down/up. |
| `hse_link_down` | CMAC, 40G | Number of times the monitor dropped the carrier. |
| `hse_rx_unaligned_events`, `hse_rx_unaligned_samples` | CMAC, 40G | RX alignment-loss episodes (including those that healed without a carrier drop), and the bad samples in them. |
| `hse_rx_error_samples` | 40G | Samples with a flood of bad 64b/66b codes or BIP errors. |
| `hse_gt_rx_resets`, `hse_gt_reset_alls` | CMAC, 40G | Recovery resets of the GT receive datapath only, and full GT resets, issued by the monitor. |
| `hse_rx_wedge_restarts` | 40G | Interface restarts after an RX wedge (see the message table above). |
| `hse_mac_rx_total`, `hse_mac_rx_good`, `hse_mac_rx_bad_fcs`, `hse_mac_rx_stomped_fcs`, `hse_mac_rx_fragment`, `hse_mac_rx_truncated`, `hse_mac_rx_bad_code` | 40G | The MAC's own receive statistics, accumulated by the monitor into 64-bit counters (updated about once per second). |

All `hse_*` counters are kept across interface down/up. For example, on a 40G port after
boot:

```
$ ethtool -S eth1 | grep -E "rx_dma_pkt_drop|hse_"
     rx_dma_pkt_drop: 0
     hse_link_down: 0
     hse_rx_unaligned_events: 0
     hse_rx_unaligned_samples: 0
     hse_rx_error_samples: 0
     hse_gt_rx_resets: 0
     hse_gt_reset_alls: 0
     hse_rx_wedge_restarts: 0
     hse_mac_rx_total: 15
     hse_mac_rx_good: 15
     hse_mac_rx_bad_fcs: 0
     hse_mac_rx_stomped_fcs: 0
     hse_mac_rx_fragment: 0
     hse_mac_rx_truncated: 0
     hse_mac_rx_bad_code: 0
```

How to read them:

* A healthy, idle link shows no increments of `hse_link_down`, `hse_rx_unaligned_events` or
  `hse_rx_error_samples`. Every partner outage (cable pulled, partner reboot, partner
  transmitter restart) increments `hse_rx_unaligned_events` or `hse_link_down`.
* `hse_mac_rx_bad_code` counts bad 64b/66b blocks; it grows quickly during link-up and while
  the RX is re-aligning, so judge it by whether it increases on a link that is up and stable.
* Frames the MAC received good = frames received by Linux (`rx_packets` in
  `ip -s link`) + `rx_dma_pkt_drop` + the frames the RX frame FIFO dropped (see
  [RX drop counters](advanced.md#rx-drop-counters)). The `hse_mac_*` values trail the
  netdev counters by up to one monitor interval (about a second) right after traffic.
* The driver's monitor latches the MAC statistics itself; a tool that writes the MAC's
  statistics `TICK_REG` would take those windows away from the `hse_mac_*` counters.

### Protocol-level counters: `nstat`

On the Yocto image, `nstat` (from iproute2) shows the kernel's IP/TCP/UDP counters, which tell
you whether frames that reached Linux were dropped higher up:

```
$ nstat -asz | grep -E "TcpRetransSegs|UdpInErrors|UdpRcvbufErrors|InCsumErrors"
```

`UdpRcvbufErrors` counts datagrams dropped because the receiving application was too slow (a
CPU limit, not a link problem); checksum-error counters must stay at 0.

## Connecting to a host PC or switch

1. Turn FEC **off** on the partner port and make sure it runs at the target's line rate
   (100GbE CAUI-4 for the 100G targets, 40GBASE-R4 for the 40G targets). On a Linux host:
   ```
   sudo ethtool --set-fec <host-iface> encoding off
   ```
   A partner on FEC `auto` keeps probing RS-FEC and the link flaps; see
   [troubleshooting](troubleshooting).
2. Plug the cable. The port's `link up` message appears on the board within about a second.
3. Give each side an address. Each QSFP28 port of the board must be on its own subnet:
   ```
   board$ sudo ip addr add 192.168.1.10/24 dev eth1
   host$  sudo ip addr add 192.168.1.1/24 dev <host-iface>
   board$ ping -c 3 192.168.1.1
   ```
4. Measure throughput with `iperf3` (server on one side, client on the other; `-R` reverses the
   direction, `-P <n>` runs parallel streams, `-u -b <rate>` uses UDP):
   ```
   host$  iperf3 -s
   board$ iperf3 -c 192.168.1.1 -t 30
   ```

## What to expect: throughput

The links run at 100 Gb/s or 40 Gb/s, but every packet is handled by the processor (kernel
network stack and the single-queue `xilinx_axienet` MCDMA driver), so the throughput you can
measure under Linux is a small fraction of the line rate. These are the figures measured
port-to-port over a cable between the two QSFP28 ports of one board:

| Measurement | VCK190, 100G (Cortex-A72) | ZCU102 / ZCU106, 40G (Cortex-A53) |
|-------------|---------------------------|-----------------------------------|
| `qsfp-loopback-test` TCP, each direction | 1.27 – 1.38 Gbit/s | 0.92 – 0.93 Gbit/s |
| `iperf3` TCP, one stream, 30 s / 300 s | 1.23 – 1.37 Gbit/s, 0 retransmits | 0.91 – 0.92 Gbit/s, 0 retransmits |
| `pktgen` 1500-byte frames, one direction | about 127000 frames/s (1.5 Gbit/s) | about 61000 frames/s (in the self-test) |
| `pktgen` 64-byte frames, one direction | about 230000 frames/s | — |

With UDP at offered rates above what the receiving CPU can process, the receiver's
`UdpRcvbufErrors` (in `nstat`) grows: the drops happen in the socket buffer, not on the link.
Against a host PC's 100G NIC, a VCK190 sending 8 parallel TCP streams
(`iperf3 -c <host> -P 8 -t 20`) reached about 1.9 Gbit/s aggregate.

### Where the bottleneck is and what the solution is

The link layer operates at full rate, as `ethtool` (`Speed`, `Link detected: yes`) and the
loopback self-test (full-size frames through the MAC and MCDMA with zero errors) confirm. The
limit is the embedded CPU: each packet traverses the kernel TCP/IP stack and the driver's
single-queue DMA path. Note also that the MCDMA S2MM (receive) path of each port is 512 bits
wide at 100 MHz, i.e. 51.2 Gb/s: on the 100G targets a sustained 100G burst is absorbed by the
RX frame FIFO only up to its size, after which whole frames are dropped (and counted, see
[RX drop counters](advanced.md#rx-drop-counters)).

Designs that require sustained 100G throughput structure the datapath as a split control /
data plane, removing the CPU from the bulk-traffic path:

* **Data plane in fabric.** Incoming packets are parsed at the MAC's AXI4-Stream client
  interface by a packet classifier in the PL, typically matching on Ethernet / IP / UDP header
  fields, VLAN tag, or a protocol-specific marker. Matched flows are routed directly to fabric
  processing blocks — raw sensor/ADC data into a DSP pipeline, video frames into a vision
  pipeline, or application-specific compute kernels. On Versal, bulk traffic is typically
  handed off from the PL to the AI Engine array. This traffic does not transit the
  processor, so both QSFP28 ports can sustain wire rate concurrently.
* **Control plane on the CPU.** The classifier forwards a small subset of traffic — ARP,
  ICMP, DHCP, SSH, management protocols, application configuration — up the MCDMA path to the
  kernel. This traffic is low-volume and the Linux network stack handles it without
  difficulty.

The 2x QSFP28 FMC and the per-port MACs provide the building blocks; the design choice is the
partitioning of work between fabric and processor. For benchmarking a fabric datapath,
iperf3 over the Linux network stack is not appropriate; hardware counters in the PL (or the
frame-level checks of `qsfp-loopback-test`) are the meaningful measurement.

## QSFP28 module access

Each QSFP28 port has its own AXI IIC bus to the module's management interface (SFF-8636,
I2C address `0x50`), and `i2c-tools` is included in the images. The bus numbers depend on the
probe order; find the bus of each port from the controller's address (see the address maps
in [advanced](advanced.md#address-and-interrupt-maps)):

```
$ for b in /sys/bus/i2c/devices/i2c-*; do echo "$(basename $b): $(cat $b/name)"; done
i2c-0: xiic-i2c 80020000.i2c        <- Si5328 (zcu102_hpc0)
i2c-1: xiic-i2c 80030000.i2c        <- QSFP28 port 0
i2c-2: xiic-i2c 80040000.i2c        <- QSFP28 port 1
...
$ sudo i2cget -y 1 0x50 0           # identifier: 0x11 = QSFP28
$ sudo i2cdump -y 1 0x50            # whole lower page and upper page 00h
```

Bytes 148–163 of the module hold the vendor name and bytes 168–183 the part number.

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
