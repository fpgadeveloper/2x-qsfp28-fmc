# Troubleshooting

## Build failures

### PetaLinux build fails with `bitbake petalinux-image-minimal failed` and sstate fetch errors

If a `make petalinux TARGET=<target>` run ends with errors like

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

### General build issues

Check the following if the project fails to build or generate a bitstream:

1. **Are you using the correct version of Vivado for this version of the repository?**   
   This design is built for Vivado/PetaLinux 2025.2. `build.tcl` checks the installed Vivado
   version and refuses to build with any other version. If you are using a different version of
   the tools, refer to the [release tags](https://github.com/fpgadeveloper/2x-qsfp28-fmc/tags) to
   find a matching commit of the repository.

2. **Do you have the MRMAC license?**   
   The Versal Integrated MRMAC requires a (free, no-cost) license to generate a bitstream. If the
   implementation fails at device-image generation with a licensing error, obtain the MRMAC
   license from the AMD Xilinx Licensing site.

3. **Did you correctly follow the build instructions?**   
   Please check the build instructions carefully as you may have missed a step.

4. **Did you copy/clone the repo into a short directory structure?**   
   Windows doesn't cope well with long directory structures, so copy/clone the repo into a short
   directory structure such as `C:\projects\`. When working in long directory structures, you can
   get errors relating to missing files.

## PetaLinux / hardware issues

The MRMAC bring-up messages are in the kernel log. The single most useful diagnostic is:

```
dmesg | grep -iE "mrmac|axienet|si53|block lock|link|reset done"
```

A healthy port prints `MRMAC setup at 100000` and the link comes up at 100 Gbps.

### A port reports `MRMAC block lock not complete`

```
xilinx_axienet 80000000.mrmac eth0: MRMAC block lock not complete! Cross-check the MAC ref clock configuration
xilinx_axienet 80000000.mrmac eth0: Link is down
```

This means the four CAUI-4 lanes did not align. Check, in order:

1. **Is there a valid 100G link?** For a standalone test, plug a **100G QSFP28 passive loopback
   module** into the port (not a 25G/SFP loopback). For a live link, the partner must also be
   100GbE CAUI-4.
2. **Is the Si5328 programmed?** `cat /sys/kernel/debug/clk/clk_summary | grep clk0` should show
   the GT reference clock at `322265625`. If it is wrong or zero, the Si5328 device tree node or
   the `clk-si5324` driver is not programming the clock.
3. If you have modified the block design, verify the per-lane CAUI-4 GT user-clocking is intact
   (see the *Per-lane CAUI-4 user clocking* part of [advanced](advanced)) — broadcasting one
   lane's recovered clock to all four lanes is the classic cause of this symptom even with a good
   loopback.

### Port 1 reports `GT TX Reset Done not achieved`

```
xilinx_axienet 80010000.mrmac eth1: GT TX Reset Done not achieved (Status=0x0)
```

while port 0 (`eth0`) comes up fine. Port 1's GT reference clock is GBTCLK1, sourced from the
Si5328's CKOUT2 output, which the stock `clk-si5324` driver disables. This design ships a kernel
patch that enables CKOUT2 (see the *Modifications layered on the stock BSP* section of
[advanced](advanced)). If you see this symptom, the patch
did not get applied — rebuild the kernel forcing a re-patch:

```
cd PetaLinux/<target>
petalinux-build -c kernel -x cleansstate
petalinux-build
```

### A port comes up at 25 Gbps instead of 100 Gbps

```
xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 25000
```

The driver reads the `max-speed` device-tree property first and only falls back to
`xlnx,mrmac-rate` if it is absent. The auto-generated `pl.dtsi` sets `max-speed = <25000>` (the
per-lane GT rate). The `port-config.dtsi` overlay overrides this with `max-speed = <100000>`; if
you see 25G, that override is missing from the device tree that was built into your image.

### A port fails to probe with `-EBUSY` / `iormeap failed for the dma`

```
xilinx_axienet 80080000.mrmac: error -16: can't request region ... iormeap failed for the dma
```

The standalone `xilinx_dma` dmaengine driver grabbed the MCDMA register region before
`xilinx_axienet` could. The `port-config.dtsi` overlay works around this by overriding the MCDMA
node's `compatible` to `"xlnx,eth-dma"` (see the *Modifications layered on the stock BSP* section
of [advanced](advanced)). If you hit this, that override is
missing from your device tree.

### Ports not working under Linux (link is up)

1. **Check the interface-to-port assignment for your design.**   
   The two MRMAC ports appear as `eth0` (port 0) and `eth1` (port 1); the VCK190 built-in GEMs
   appear as `end0`/`end1`. Use `ip -br link` and `ethtool -i <name>` to confirm. The full
   mapping is documented in the *Port configurations* section of [petalinux](petalinux).

2. **Each port must be assigned to a different subnet.**   
   If you assign `eth0` to 192.168.1.10, then `eth1` must be on a different subnet (e.g.
   192.168.2.10). Multiple ports managed under Linux on the same subnet will not work.

3. **Use the bundled self-test to isolate link vs. host problems.**   
   `mrmac-loopback-test eth0` (with a passive loopback module) validates the entire MRMAC → MCDMA
   → DDR datapath independently of any link partner. If the self-test passes but traffic to a real
   peer does not, the problem is in the link or the peer, not the FPGA design.
