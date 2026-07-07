# Stand-alone Echo Server

The repository includes a bare-metal test application that runs an echo server on **all QSFP28
ports at once** (both ports on the dual-port targets, port 0 on the single-port targets). Note
that this is *not* the usual lwIP echo-server template that ships with Vitis — lwIP has no
adapter for any of this design's MACs (Versal MRMAC, UltraScale+ 100G CMAC, or the 40G/50G
Ethernet Subsystem) — so this design implements a small **raw-Ethernet** echo server instead
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
| `zcu102_hpc0`, `zcu106_hpc0`, `zcu111_ss`, `zcu208_ss`, `zcu216_ss`, `kcu116_ss` | 40G/50G Ethernet Subsystem (l_ethernet) | `hse.c` |

On startup the application performs the full hardware bring-up itself: it programs the FMC
VADJ rail where the board needs it (VCK190, 1.5V, via `Vitis/common/src/vadj.c`), programs the
FMC's Si5328 to output the GT reference clock on **both** of its outputs — 322.265625 MHz for
the 100G targets, 156.25 MHz for the 40G targets (`si5328.c`) — resets and configures each
port's MAC and GT, sets up the MCDMA buffer-descriptor rings, and then polls the MCDMA RX
rings in a loop. Roughly once per second it re-checks link state; while a port is down it
re-issues that port's MAC/GT reset to re-attempt alignment — the same strategy as the design's
Linux carrier monitors (see [advanced](advanced)).

## Building the Vitis workspace

To build the Vitis workspace and the echo server application, follow the
[build instructions](/build_instructions.md#build-vitis-workspace) — the
steps are the same on Windows and Linux.

In short, from the repository root:

```
./build.sh standalone --target <target>
```

builds the Vivado XSA (if it does not already exist), the Vitis workspace and
the echo server application, and packages the boot file into
`Vitis/boot/<target>/` — a `BOOT.BIN` for the Zynq UltraScale+ and Versal
targets, or a `qsfp_boot.bit` (bitstream with the ELF embedded) for the
MicroBlaze targets. The echo server is also gathered into the "standalone"
boot image zip when you run `./build.sh all --target <target>`.

## Run the application

You must have followed the build instructions before you can run the application.

1. Launch the Xilinx Vitis GUI.
2. When asked to select the workspace path, select the `Vitis/<target>_workspace` directory.
3. Power up your hardware platform and ensure that the JTAG is connected properly.
4. In the Vitis Explorer panel, double-click on the System project that you want to run -
   this will reveal the application contained in the project. The System project will have 
   the postfix "_system".
5. Now right click on the application "echo_server" then navigate the
   drop down menu to **Run As->Launch on Hardware (Single Application Debug (GDB)).**

Alternatively, copy the `BOOT.BIN` from `Vitis/boot/<target>/` (or from the standalone zip in
`bootimages/`) to an SD card and boot the board from SD. The MicroBlaze targets (KCU116) have
no CPU-accessible SD card: boot the `qsfp_boot.bit` over JTAG, or write it to the QSPI
configuration flash.

The run configuration will first program the device, then load and run the application. The UART
output (115200 baud) of a `zcu106_hpc0` run appears as follows:

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

A `port N: link UP` line is printed as each connected port achieves RX alignment; `link DOWN`
is printed if a link is subsequently lost (e.g. cable unplugged).

## Example usage

Connect a QSFP28 port to a PC's 100G NIC (or a 40G-capable NIC for the 40G targets) and
configure the PC's interface with a fixed IP address on the matching subnet — for port 0, for
example, `192.168.10.20/24`. The IP addresses are fixed (there is no DHCP client in the
application).

```{note}
The 100G targets are built without RS-FEC, so the link partner must have forward error
correction disabled (e.g. `ethtool --set-fec <iface> encoding off`) for the link to align
over a DAC cable.
```

### Ping a port

```
$ ping 192.168.10.10
PING 192.168.10.10 (192.168.10.10) 56(84) bytes of data.
64 bytes from 192.168.10.10: icmp_seq=1 ttl=64 time=0.06 ms
```

This pings port 0; use `192.168.20.10` for port 1.

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
