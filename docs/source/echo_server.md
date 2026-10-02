# Stand-alone Echo Server

The repository includes a bare-metal test application that runs an echo server on **all QSFP28
ports at once** (both ports on the dual-port targets, port 0 on the single-port targets). It is
the quickest way to check the hardware without building Linux, and it is the only software
flow of the MicroBlaze-based KCU116 targets.

This is *not* the usual lwIP echo-server template that ships with Vitis — lwIP has no adapter
for any of this design's MACs (Versal MRMAC, UltraScale+ 100G CMAC, or the 40G/50G Ethernet
Subsystem) — so the design implements a small **raw-Ethernet** echo server instead
(`Vitis/common/src/main.c`). Per port it answers:

* **ARP** requests for the port's IP address
* **ICMP** echo requests (ping)
* **UDP** datagrams to *any* port number: the payload is echoed back to the sender

Each port has its own MAC address and lives on its own subnet:

| QSFP28 port | MAC address         | IP address         |
|-------------|---------------------|--------------------|
| 0           | `00:0a:35:00:0e:00` | `192.168.10.10/24` |
| 1           | `00:0a:35:00:0e:01` | `192.168.20.10/24` |

The same application sources serve every target; the MAC-specific bring-up is selected at
compile time to match the target's Ethernet IP:

| Targets                         | MAC                                    | Bring-up module |
|---------------------------------|----------------------------------------|-----------------|
| `vck190_fmcp1`                  | Versal Integrated MRMAC (1x100GE CAUI-4) | `mrmac.c`     |
| `zcu111`, `zcu208`, `zcu216`, `kcu116` | UltraScale+ Integrated 100G CMAC | `hse.c`         |
| `zcu102_hpc0`, `zcu106_hpc0`, `zcu111_ss`, `zcu208_ss`, `zcu216_ss`, `kcu116_ss` | 40G/50G Ethernet Subsystem | `hse.c` |

On startup the application performs the full hardware bring-up itself: it programs the FMC
VADJ rail where the board needs it (VCK190, 1.5V, via `Vitis/common/src/vadj.c`), programs the
FMC's Si5328 to output the GT reference clock on **both** of its outputs — 322.265625 MHz for
the 100G targets, 156.25 MHz for the 40G targets (`si5328.c`) — resets and configures each
port's MAC and GT, sets up the MCDMA buffer-descriptor rings, and then polls the MCDMA RX
rings in a loop. Roughly once per second it re-checks link state; while a port is down it
re-issues that port's MAC/GT reset to re-attempt alignment.

## Build the application

The build runs on Windows or Linux and needs Vivado and Vitis 2025.2 (plus the license for
the target's MAC IP). From the repository root:

```
./build.sh standalone --target <target>
```

This builds the Vivado XSA (if it does not already exist), the Vitis workspace
(`Vitis/<target>_workspace`) and the echo server, and packages the boot file into
`Vitis/boot/<target>/`:

| Target family | Boot file | How to run it |
|---------------|-----------|---------------|
| Zynq UltraScale+ (`zcu*`), Versal (`vck190_fmcp1`) | `BOOT.BIN` | SD card, or JTAG from Vitis |
| MicroBlaze (`kcu116`, `kcu116_ss`) | `qsfp_boot.bit` (bitstream with the ELF embedded) | JTAG (Vivado Hardware Manager), or the QSPI configuration flash |

`./build.sh all --target <target>` (or `./build.sh package --target <target>`) also gathers
the boot file into `bootimages/2x-qsfp28-fmc_<target>_standalone-2025-2.zip`. See the
[build instructions](build_instructions.md#build-vitis-workspace) for details.

## Set up the hardware

1. Fit the [2x QSFP28 FMC] on the FMC connector of the target (see the target tables in the
   [build instructions](build_instructions.md#target-designs): FMCP1 on the VCK190, HPC0 on
   the ZCU102/ZCU106, FMCP on the RFSoC boards, HPC on the KCU116).
2. Plug the cable or module for your test into the QSFP28 port(s) (see
   [Example usage](#example-usage) below).
3. Connect the USB-UART to your PC and open a terminal at 115200 baud, 8N1. The console is
   on the USB-UART of the board's processor (on the KCU116, the AXI UART16550 in the FPGA,
   which also uses the board's USB-UART).
4. Connect the USB-JTAG cable if you will boot over JTAG.

## Run the application

### Boot from SD card (Zynq UltraScale+ and Versal)

1. Copy `BOOT.BIN` (from `Vitis/boot/<target>/` or from the standalone zip) to the first
   (FAT32) partition of an SD card. Nothing else is needed on the card.
2. Set the board to boot from SD:
   * **VCK190:** DIP switch SW1 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU102, ZCU106:** DIP switch SW6 = 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF)
   * **ZCU111, ZCU208, ZCU216:** see the boot-mode switch table in the board's user guide
     ([ZCU111](https://www.xilinx.com/zcu111), [ZCU208](https://www.xilinx.com/zcu208),
     [ZCU216](https://www.xilinx.com/zcu216))
3. Insert the SD card and power up the board.

### Boot over JTAG

* **Zynq UltraScale+ and Versal:** set the board to JTAG boot mode (VCK190 SW1 = 1111,
  ZCU102/ZCU106 SW6 = 1111), open the `Vitis/<target>_workspace` workspace in the Vitis IDE,
  select the `echo_server` application and run it on the hardware. The run configuration
  programs the device and then loads and starts the application.
* **KCU116:** program `qsfp_boot.bit` into the FPGA with the Vivado Hardware Manager (Open
  Target → Program Device). The bitstream already contains the application, so it starts
  immediately.
* **KCU116 from flash:** the KCU116's microSD slot is not connected to the FPGA. To start
  the echo server at power-up, convert `qsfp_boot.bit` to a configuration-memory file with
  Vivado's `write_cfgmem` (128 MB, SPIx4 interface, as set in `config/data.json`) and
  program the board's QSPI configuration flash from the Vivado Hardware Manager.

```{tip}
JTAG boot needs the AMD cable drivers, which the Vitis installer does not install
automatically; see
[installing the cable drivers](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Installing-Cable-Drivers).
```

### What the console shows

The UART output of a `zcu106_hpc0` run with a cable between the two ports:

```
-------------------------------------------------
2x QSFP28 FMC echo server - ZCU106
Line rate: 40G per port, 2 ports
-------------------------------------------------
Si5328 programmed: GT refclk 156.25 MHz on both outputs
port 0: MAC 00:0a:35:00:0e:00  IP 192.168.10.10
port 1: MAC 00:0a:35:00:0e:01  IP 192.168.20.10
Echo server running: answers ARP, ICMP ping and UDP echo

port 0: link UP
```

and of a `kcu116` run with a 100G link partner on port 0:

```
-------------------------------------------------
2x QSFP28 FMC echo server - KCU116
Line rate: 100G per port, 1 port
-------------------------------------------------
Si5328 programmed: GT refclk 322.265625 MHz on both outputs
port 0: MAC 00:0a:35:00:0e:00  IP 192.168.10.10
Echo server running: answers ARP, ICMP ping and UDP echo
port 0: link UP
```

On the VCK190 a `VADJ enabled (1.5V)` line follows the banner. A `port N: link UP` line is
printed as each connected port achieves RX alignment; `link DOWN` is printed if a link is
subsequently lost (for example when the cable is unplugged), and the application keeps
re-trying until the link comes back.

## Example usage

Connect a QSFP28 port to a PC's NIC at the target's line rate (100G NIC for the 100G
targets, a 40GbE-capable NIC for the 40G targets) and give the PC's interface a fixed IP
address on the matching subnet — for port 0, for example, `192.168.10.20/24`. The echo
server has no DHCP client; its addresses are fixed.

```{important}
The design runs without forward error correction, so the link partner must have FEC
**forced off** (on a Linux host: `sudo ethtool --set-fec <iface> encoding off`). A partner
left on FEC `auto` or RS-FEC will not link up, or will link up and flap. See
[troubleshooting](troubleshooting).
```

On a Linux host:

```
$ sudo ethtool --set-fec enp1s0f0 encoding off      # use your NIC's interface name
$ sudo ip addr add 192.168.10.20/24 dev enp1s0f0
$ sudo ip link set enp1s0f0 up
```

### Ping a port

```
$ ping 192.168.10.10
PING 192.168.10.10 (192.168.10.10) 56(84) bytes of data.
64 bytes from 192.168.10.10: icmp_seq=1 ttl=64 time=0.06 ms
```

This pings port 0; use `192.168.20.10` for port 1 (with the PC on the `192.168.20.0/24`
subnet).

### UDP echo

The echo server echoes UDP datagrams sent to **any** port number back to the sender. Using
netcat from a PC connected to QSFP28 port 1:

```
$ echo hello | nc -u 192.168.20.10 7
hello
```

```{note}
The echo server answers ARP, ICMP ping and UDP only. There is no TCP stack, so a telnet
connection (as used with the lwIP echo servers of our other reference designs) will not work.
```

### Without a link partner

With a cable between QSFP28 port 0 and port 1 (dual-port targets), or a passive loopback
module in a port, the console's `port N: link UP` lines confirm that the GTs, the MAC and the
Si5328 reference clock work: the link only aligns when both directions of every lane carry a
valid signal. Pinging needs a host on the other end of the link; for an end-to-end datapath
test without a host, use the Linux `qsfp-loopback-test` (see
[Testing under Linux](linux_usage)).

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
