# Troubleshooting

## Build failures

### General build issues

Check the following if the project fails to build or generate a bitstream:

1. **Are you using the correct version of Vivado for this version of the repository?**
   This design is built for Vivado 2025.2. `build.tcl` checks the installed Vivado version
   and refuses to build with any other version. If you are using a different version of the
   tools, refer to the [release tags](https://github.com/fpgadeveloper/2x-qsfp28-fmc/tags) to
   find a matching commit of the repository.

2. **Do you have the license for the target's Ethernet MAC?**
   Every target needs one: the Versal MRMAC and the UltraScale+ CMAC (100G targets) have free,
   no-cost licenses; the 40G/50G Ethernet Subsystem (40G targets) needs a purchased or 30-day
   evaluation license. Without it the build fails at bitstream / device-image generation with
   a licensing error. Note that an evaluation license expires: a build that worked before can
   fail after the evaluation period ends. A `CRITICAL WARNING` about an evaluation license
   (`[Vivado 12-1790]`) on its own is not a failure.

3. **Do you have the right Vivado edition?** Most boards need the Vivado *Enterprise* Edition
   (see the target tables in the [build instructions](build_instructions)).

4. **Did you copy/clone the repo into a short directory structure?**
   Windows doesn't cope well with long directory structures, so copy/clone the repo into a
   short directory structure such as `C:\projects\`. The runner checks the path length for the
   Versal targets and explains the `subst` workaround if it is too long.

### PetaLinux build fails with `bitbake petalinux-image-minimal failed` and sstate fetch errors

If a `./build.sh petalinux --target <target>` run ends with errors like

```
ERROR: <package>-<ver>-r0 do_..._setscene: Fetcher failure: Unable to find file file://.../sstate:...
[ERROR] Command bitbake petalinux-image-minimal failed
```

the actual build is not broken. These `_setscene` errors come from bitbake trying to pull
prebuilt artifacts from the public sstate-cache mirror, which occasionally returns 404 for
individual packages. Bitbake falls back to building those packages locally and succeeds, but
still exits non-zero because of the failed fetches, so the runner stops before packaging.
**Fix: re-run the same command.** The second attempt finds the missing packages in the local
sstate cache and completes cleanly.

### Yocto build

* `repo: command not found` — install Google's `repo` tool and make sure it is on your `PATH`.
* The first build of a target needs internet access (`repo sync` and source downloads) and in
  the order of 60 GB of disk space per target. Use the
  [offline / sstate mirror](build_instructions.md#yocto-offline-build) option to speed up
  repeated builds.
* The PetaLinux and Yocto stages are refused on Windows; build them on a Linux machine.

## Booting

### A Yocto SD card does not boot (nothing after the boot ROM, or a U-Boot prompt)

The Yocto disk image (`rootfs.wic.xz`) does not contain `BOOT.BIN` where the BootROM looks for
it, and on the VCK190 its `EFI/BOOT/` directory is empty. After flashing, copy `BOOT.BIN` to
the first (FAT32) partition of the card, and on the VCK190 also copy `BOOTAA64.EFI` to
`EFI/BOOT/` on that partition (see [Yocto](yocto.md#prepare-the-sd-card)). Both files are in
the Yocto zip. Without `BOOTAA64.EFI`, the VCK190 stops at the U-Boot prompt.

### JTAG-booted PetaLinux waits for the root device

`Waiting for root device /dev/mmcblk0p2...`: the root filesystem is on the SD card even when
booting over JTAG; prepare the SD card and insert it.

### The FMC does not respond on the VCK190 (no Si5328, no modules)

The VCK190's FMC VADJ rail must be on (1.5 V for this design) before the FMC's Si5328 and
QSFP28 modules can be reached. The Linux images enable it from U-Boot before every boot, and
the echo server enables it itself (`VADJ enabled (1.5V)`). If you use your own boot flow,
enable VADJ first (or set it from the board's System Controller).

## Link problems

The link messages are in the kernel log. The most useful diagnostic is:

```
sudo dmesg | grep -E "HSE|MRMAC|si53|axienet"
```

A healthy port prints `MRMAC link up at 100000` (Versal) or `HSE MAC link up at 40000 Mbps` /
`HSE MAC link up at 100000 Mbps` (Zynq UltraScale+) once a partner signal is present. See
[link bring-up and monitoring](linux_usage.md#link-bring-up-and-monitoring) for the meaning of
all messages.

### A connected port never reports `link up`

The driver's link monitor keeps re-trying in the background, so a port that cannot align does
not fail; it simply shows `NO-CARRIER` in `ip -br link`, and the 40G ports repeat
`HSE MAC link still down (...)` now and then. The port comes up on its own as soon as the cause
is resolved — no reboot is needed. Check, in order:

1. **Is FEC off on the link partner?** This design runs without FEC (no RS-FEC on CAUI-4, no
   FEC on 40GBASE-R4), so the partner must have FEC turned off. A 100G NIC or switch port set
   to RS-FEC (Clause 91) will not link up. **Force it off — do not rely on `auto`:** a NIC left
   on FEC `auto` keeps probing RS-FEC and the link flaps continuously with nearly all packets
   lost, yet `ethtool --show-fec` may still report `Active: Off`, so that readout is not proof.
   With an Intel E810 NIC (`ice` driver), FEC `auto` gives a flapping link and a forced `off`
   gives a stable link that locks within a millisecond. On a Linux host:
   ```
   sudo ethtool --set-fec <iface> encoding off
   ```
2. **Is the partner at the same line rate?** 100GbE CAUI-4 for the 100G targets, 40GBASE-R4
   (4 × 10.3125 Gb/s) for the 40G targets. Some NICs do not support 40GbE at all (for example
   the Intel E810 series), so they cannot be the partner of a 40G target; use the
   port-to-port cable or a loopback module instead.
3. **Is the cable / module right for the lane rate?** On the 40G targets, use passive copper
   (DAC or loopback modules) or parts rated for 40GBASE-R4: many 100G AOCs and SR4 optics are
   not rated for the 10.3125 Gb/s lane rate. For a self-test, use a passive QSFP28 loopback
   module (not an SFP or 25G loopback).
4. **Is the Si5328 programmed?** The boot log must contain `si5328 probe successful`, and
   `sudo cat /sys/kernel/debug/clk/clk_summary | grep clk0` should show the GT reference clock
   at `322265625` (100G) or `156250000` (40G).
5. **Is the QSFP28 module out of reset and present?** `ResetL` is released by default in the
   bitstream; if you have changed the sideband GPIO default or driven it from software, make
   sure `ResetL` is high (see
   [QSFP28 module sideband](advanced.md#qsfp28-module-sideband-and-power-on-reset)). A real
   optical module or AOC stays dark while held in reset, even though a passive electrical
   loopback would link. Reading the module's identifier byte over I2C (see
   [QSFP28 module access](linux_usage.md#qsfp28-module-access)) confirms that it is present
   and powered.
6. **ZCU208 / ZCU216 at 100G:** only QSFP28 port 0 is implemented; port 1's module is held in
   reset. Use the `_ss` (40G) targets for two ports.
7. If you have modified the Versal block design, verify that the per-lane CAUI-4 GT user
   clocking is intact (see [Per-lane CAUI-4 user clocking](advanced.md#per-lane-caui-4-user-clocking))
   — broadcasting one lane's recovered clock to all four lanes is the classic cause of this
   symptom even with a good loopback.

### The link flaps or shows bursts of errors

* Check the partner's FEC setting first (see above).
* `hse_rx_unaligned_events`, `hse_link_down` and `hse_rx_error_samples` in `ethtool -S`
  count the episodes; the kernel log shows each one. Every partner outage (cable pulled,
  partner reboot or transmitter restart) is counted — that is expected. Steady increments
  on an undisturbed link point to the cable, the module or the partner.
* A 40G port that receives a flood of decoding errors while it is aligned (`HSE RX decoding
  errors (...)`) is recovered automatically with a receive-only GT reset, normally within one
  second, without disturbing the other direction.

### Port 1 reports `GT TX Reset Done not achieved` (Versal)

```
xilinx_axienet 80010000.mrmac eth1: GT TX Reset Done not achieved (Status=0x0)
```

while port 0 comes up fine: port 1's GT reference clock is GBTCLK1, from the Si5328's CKOUT2
output, which the stock clock driver disables. The BSPs carry a kernel patch that enables it
(`0001-clk-si5324-enable-ckout2-for-2x-qsfp28-fmc.patch`). If you see this message, the patch
was not applied to your kernel; in PetaLinux, force a re-patch with
`petalinux-build -c kernel -x cleansstate && petalinux-build`.

### A port comes up at 25 Gbps instead of 100 Gbps (Versal)

```
xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 25000
```

The driver reads the `max-speed` device-tree property first. The generated device tree sets
it to the per-lane rate (25000); the `port-config.dtsi` overlay overrides it with `100000`. If
you see 25G, that override is missing from the device tree built into your image.

### A port fails to probe with `-EBUSY` / `iormeap failed for the dma`

```
xilinx_axienet 80080000.mrmac: error -16: can't request region ... iormeap failed for the dma
```

The standalone `xilinx_dma` dmaengine driver grabbed the MCDMA register region before
`xilinx_axienet` could. The `port-config.dtsi` overlay prevents this by overriding the MCDMA
node's `compatible` to `"xlnx,eth-dma"`; if you hit this, that override is missing from your
device tree.

### `Ethernet core IRQ not defined` at boot (Zynq UltraScale+)

Harmless: the CMAC and 40G/50G MACs have no interrupt in this design; the driver uses the
MCDMA interrupts.

## Traffic problems (link is up)

1. **Check the interface-to-port assignment.** See
   [interface names](linux_usage.md#interface-names); the QSFP28 ports have the MAC addresses
   `00:0a:35:00:00:00` (port 0) and `…:01` (port 1).
2. **Each port must be on its own subnet.** If you assign `eth1` to 192.168.1.10, then `eth2`
   must be on a different subnet (e.g. 192.168.2.10). Two ports of one board on the same
   subnet will not work (the self-test uses network namespaces to avoid this).
3. **Use the bundled self-test to isolate link vs. host problems.** `qsfp-loopback-test`
   (port-to-port cable) or `qsfp-loopback-test --single` (loopback modules) validates the
   whole datapath of the ports independently of any link partner. If it passes but traffic to
   a real peer does not, the problem is in the link or the peer, not the FPGA design.
4. **Frames are lost under load.** This is normally the CPU limit, not the link:
   * `rx_dma_pkt_drop` (`ethtool -S`) growing: the CPU did not replenish the RX descriptor
     ring in time. The ring defaults to 1024 descriptors; reduce the load or the number of
     concurrent tasks.
   * The RX frame FIFO's drop counters growing (see
     [RX drop counters](advanced.md#rx-drop-counters)): the MCDMA S2MM path (51.2 Gb/s) or
     the DMA could not keep up with a burst. At 100G this is expected for sustained line-rate
     bursts.
   * `UdpRcvbufErrors` in `nstat` growing: the receiving application was too slow.

   See [what to expect](linux_usage.md#what-to-expect-throughput) for the throughput these
   designs reach under Linux.
