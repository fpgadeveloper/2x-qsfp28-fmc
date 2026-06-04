# PetaLinux

PetaLinux can be built for this reference design by using the Makefile in the `PetaLinux` directory
of the repository.

## Requirements

To build the PetaLinux project, you will need a physical or virtual machine running one of the 
[supported Linux distributions] with Vivado 2025.2 and PetaLinux Tools 2025.2 installed.

```{attention}
You cannot build the PetaLinux project in the Windows operating system. Windows
users are advised to use a Linux virtual machine to build the PetaLinux project.
```

## How to build

1. From a command terminal, clone the Git repository and `cd` into it.
   ```
   git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
   cd 2x-qsfp28-fmc
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2025.2/settings.sh
   ```
3. Launch Vivado by sourcing the `settings64.sh` bash script, eg:
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   ```
4. Build the Vivado and PetaLinux project for your specific target platform by running the following
   commands and replacing `<target>` with one of the target design labels listed in build instructions.
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   
The last command will launch the build process for the corresponding Vivado project if that project
has not already been built and its hardware exported.

## Boot from SD card

### Prepare the SD card

Once the build process is complete, you must prepare the SD card for booting PetaLinux.

1. The SD card must first be prepared with two partitions: one for the boot files and another 
   for the root file system.

   * Plug the SD card into your computer and find its device name using the `dmesg` command.
     The SD card should be found at the end of the log, and its device name should be something
     like `/dev/sdX`, where `X` is a letter such as a,b,c,d, etc. Note that you should replace
     the `X` in the following instructions.
     
```{warning}
Do not continue these steps until you are certain that you have found the correct
device name for the SD card. If you use the wrong device name in the following steps, you risk
losing data on one of your hard drives.
```
   * Run `fdisk` by typing the command `sudo fdisk /dev/sdX`
   * Make the `boot` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number and first sector. For the last sector, type 
     `+1G` to allocate 1GB to this partition.
   * Make the `boot` partition bootable by typing `a`
   * Make the `root` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number, first sector and last sector.
   * Save the partition table by typing `w`
   * Format the `boot` partition (FAT32) by typing `sudo mkfs.vfat -F 32 -n boot /dev/sdX1`
   * Format the `root` partition (ext4) by typing `sudo mkfs.ext4 -L root /dev/sdX2`

2. Copy the following files to the `boot` partition of the SD card:
   Assuming the `boot` partition was mounted to `/media/user/boot`, follow these instructions:
   ```
   $ cd /media/user/boot/
   $ sudo cp /<petalinux-project>/images/linux/BOOT.BIN .
   $ sudo cp /<petalinux-project>/images/linux/boot.scr .
   $ sudo cp /<petalinux-project>/images/linux/image.ub .
   ```

3. Create the root file system by extracting the `rootfs.tar.gz` file to the `root` partition.
   Assuming the `root` partition was mounted to `/media/user/root`, follow these instructions:
   ```
   $ cd /media/user/root/
   $ sudo cp /<petalinux-project>/images/linux/rootfs.tar.gz .
   $ sudo tar xvf rootfs.tar.gz -C .
   $ sync
   ```
   
   Once the `sync` command returns, you will be able to eject the SD card from the machine.

```{tip}
The `bootimages/` directory of the repo (and the release zip) contains the boot files
already arranged into `boot/` and `root/` folders, so you can simply copy the contents of `boot/`
to the FAT32 partition and extract `root/rootfs.tar.gz` to the ext4 partition.
```

### Boot PetaLinux

1. Plug the SD card into your target board.
2. Ensure that the target board is configured to boot from SD card:
   * **VCK190:** DIP switch SW1 is set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
3. Connect the [2x QSFP28 FMC] to the FMCP1 connector of the target board.
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.
5. Connect and power your hardware.

The default login is username `petalinux`; on first login you will be prompted to set a password.

## Boot via JTAG

```{tip}
You need to install the cable drivers before being able to boot via JTAG.
Note that the Vitis installer does not automatically install the cable drivers, it must be done separately.
For instructions, read section 
[installing the cable drivers](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Installing-Cable-Drivers) 
from the Vivado release notes.
```

```{warning}
The Versal design stores the root filesystem on the SD card, so you must still
prepare and connect the SD card before booting via JTAG. If you boot via JTAG without the SD card,
the boot will hang at a message similar to: `Waiting for root device /dev/mmcblk0p2...`
```

### Setup hardware

1. Prepare the SD card according to the [instructions above](#prepare-the-sd-card) and plug the SD card 
   into your target board.
2. Ensure that the target board is configured to boot from JTAG:
   * **VCK190:** DIP switch SW1 is set to 1111 (1=ON,2=ON,3=ON,4=ON)
3. Connect the [2x QSFP28 FMC] to the FMCP1 connector of the target board.
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.
5. Connect and power your hardware.

### Boot PetaLinux

To boot PetaLinux on hardware via JTAG, use the following commands in a Linux command terminal:

1. Change current directory to the PetaLinux project directory for your target design:
   ```
   cd <project-dir>/PetaLinux/<target>
   ```
2. Download the device image to the Versal device and boot the kernel:
   ```
   petalinux-boot --jtag --kernel
   ```

## UART terminal

You will need to setup a terminal emulator to use the PetaLinux command line over the USB-UART connection.
Connect with a baud rate of 115200.

### In Windows

You will need to find the comport for the USB-UART in Windows Device Manager. As a terminal emulator, you
can use the open source and free [Putty](https://www.putty.org/).

### In Linux

The VCK190 presents a multi-port FTDI USB-UART; the PetaLinux console is on the second interface
(typically `/dev/ttyUSB1`). You can find the tty devices by running `dmesg | grep tty`. To open a
terminal emulator, you can use the following command:

```
sudo screen /dev/ttyUSB1 115200
```

## Port configurations

The two QSFP28 ports are driven by the MRMAC and appear as `eth0` and `eth1`. The VCK190's two
built-in PS Ethernet (GEM) ports use persistent `endN` names. The numbering arises from how the
network interfaces are renamed at boot:

| Interface | Driver           | Connector                       | MAC address         |
|-----------|------------------|---------------------------------|---------------------|
| `end0`    | macb             | VCK190 built-in Ethernet (GEM0) | (board-assigned)    |
| `end1`    | macb             | VCK190 built-in Ethernet (GEM1) | (board-assigned)    |
| `eth0`    | xilinx_axienet   | 2x QSFP28 FMC port 0            | `00:0a:35:00:00:00` |
| `eth1`    | xilinx_axienet   | 2x QSFP28 FMC port 1            | `00:0a:35:00:00:01` |

> **Note on the mixed `endN` / `ethN` names.** The PS GEM ports have their MAC address assigned at
> netdev-creation time, so they pick up the persistent `endN` rename. The two MRMAC ports get
> their MAC addresses later, from the `port-config.dtsi` overlay, after the udev rename rule has
> already run, so they keep their kernel-default `ethN` names. The interfaces work identically;
> only the names differ. Use `ethtool -i <name>` to confirm which driver is behind each interface
> (`xilinx_axienet` = a QSFP28 FMC port; `macb` = a VCK190 built-in GEM).

All interfaces are auto-configured for DHCP at boot.

### Identifying the mapping at runtime

`ip -br link` lists the interfaces (including those that are `DOWN`, which a bare `ifconfig`
hides), and `ethtool -i <name>` or the kernel bring-up messages in `dmesg` tell you which driver
is behind each one:

```sh
$ ip -br link
end0    DOWN    xx:xx:xx:xx:xx:xx <NO-CARRIER,BROADCAST,MULTICAST,UP>
end1    DOWN    xx:xx:xx:xx:xx:xx <NO-CARRIER,BROADCAST,MULTICAST,UP>
eth0    UP      00:0a:35:00:00:00 <BROADCAST,MULTICAST,UP,LOWER_UP>
eth1    UP      00:0a:35:00:00:01 <BROADCAST,MULTICAST,UP,LOWER_UP>
lo      UNKNOWN 00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>

$ ethtool -i eth0 | head -1
driver: xilinx_axienet      # -> 2x QSFP28 FMC port

$ dmesg | grep -iE "mrmac|axienet|si53|block lock|link"
```

A healthy bring-up prints `MRMAC setup at 100000 (link monitored)` for each port and the Si5328
clock at 322265625 Hz (`cat /sys/kernel/debug/clk/clk_summary | grep clk0`). A port with a 100G
link partner connected then prints `MRMAC link up at 100000` — see [Link bring-up and
monitoring](#link-bring-up-and-monitoring) below.

## Example Usage

The examples below were captured on a `vck190_fmcp1` build. Substitute your own interface name
(see the [Port configurations](#port-configurations) section above for the mapping).

### Loopback self-test

The rootfs includes a bundled self-test, `mrmac-loopback-test`, that validates a port's full
datapath (MRMAC ↔ AXIS adapter ↔ MCDMA ↔ DDR) without needing a link partner. Plug a **100G
QSFP28 passive loopback module** into the port under test, then run the test as root:

```
# mrmac-loopback-test eth0
```

The script uses the kernel `pktgen` module to blast frames out the interface to its own MAC
address (which loop back through the passive module), then checks that the received frame count
matches the transmitted count and that frames arrive intact (full-size, no errors). A passing run
looks like this:

```
== mrmac-loopback-test: iface=eth0 count=1000000 pkt_size=1500 ==
TX frames        : 1000002
RX frames        : 1000002
RX avg frame size: 1499 bytes
RX errors        : 0
RX dropped       : 0
ethtool -S eth0  : tx_bytes=1500002401 rx_bytes=1500002401
VERDICT: PASS
```

`TX frames == RX frames` with an RX average frame size of ~1500 bytes and zero errors confirms
that frames traverse the 100G datapath and return intact. (An RX average frame size of ~48 bytes
would indicate a frame-delineation problem in the client datapath.) Repeat for the second port
with a loopback module in slot 1:

```
# mrmac-loopback-test eth1
```

### Link bring-up and monitoring

Each MRMAC port carries no PHY and emits no link-change interrupt, so the
`xilinx_axienet` driver in this design runs a background **carrier monitor** (see the
*Modifications layered on the stock BSP* section of [advanced](advanced)). With a 100G link
partner connected — an optical module/AOC or a DAC to another 100G CAUI-4 device — the port comes
up **automatically**; no `ip link` bounce or manual reset is needed:

```
[   12.663049] xilinx_axienet 80000000.mrmac eth0: MRMAC setup at 100000 (link monitored)
[   12.672764] xilinx_axienet 80000000.mrmac eth0: MRMAC link up at 100000
```

Carrier tracks the physical link, so the port reads `UP` in `ip link` only while a partner is
present, and the monitor follows cable events — unplug and re-seat the module and the link drops
and recovers on its own:

```
[   73.074149] xilinx_axienet 80000000.mrmac eth0: MRMAC link down
[   79.026154] xilinx_axienet 80000000.mrmac eth0: MRMAC link up at 100000
```

```{note}
This design runs CAUI-4 with **FEC disabled**, so the link partner must also have FEC off — a 100G
NIC or switch port set to RS-FEC (Clause 91) will not link up against it. See
[troubleshooting](troubleshooting).
```

### Assign an IP address

The link itself comes up on its own (above); to pass IP traffic, give the port an address. Each
port must be on its own subnet.

```
# ip addr add 192.168.1.10/24 dev eth0
# ip link set eth0 up
# ping 192.168.1.1
```

### Inspect port settings with ethtool

```
# ethtool eth0
Settings for eth0:
        Speed: 100000Mb/s
        Duplex: Full
        Link detected: yes
```

`Link detected: yes` along with `Speed: 100000Mb/s` confirms the four bonded GTY lanes have
acquired the CAUI-4 link.

### Throughput test with iperf3

`iperf3` is the standard tool for measuring TCP/UDP throughput over a link. Run it as a server on
one end and a client on the other; data flows from client to server by default (use `-R` to
reverse). The 2x QSFP28 FMC ports connect at 100G, but single-stream throughput on these embedded
SoCs is **CPU-bound** — the path traverses the kernel TCP/IP stack and the single-queue
`xilinx_axienet` MCDMA driver on a Cortex-A72 — so the measured figures are far below line rate.

#### On the host PC (server side)

```
$ sudo apt install iperf3
$ iperf3 -s
-----------------------------------------------------------
Server listening on 5201 (test #1)
-----------------------------------------------------------
```

#### On the PetaLinux target (client side)

A single TCP stream is limited by one CPU core, so use several parallel streams (`-P`). The figures
below were captured on a `vck190_fmcp1` target driving a host PC's 100G NIC over an optical link
(target `eth0` → host `192.168.1.1`):

```
# iperf3 -c 192.168.1.1 -P 8 -t 20
...
[SUM]   0.00-20.04  sec  4.44 GBytes  1.90 Gbits/sec  12800             sender
[SUM]   0.00-20.04  sec  4.43 GBytes  1.90 Gbits/sec                    receiver
```

That is about **1.9 Gbit/s** aggregate — far short of the 100 Gbit/s line rate — with TCP
retransmits accumulating as the sender's socket buffers and the single MCDMA queue saturate the
CPU. Reversing the direction (`-R`, host → target) or switching to UDP (`-u -b <rate>`) exercises
the other paths, but all are bounded by the same embedded-CPU ceiling, not by the link.

#### Where the bottleneck is and what the solution is

The link layer operates at 100 Gbit/s, as confirmed by `ethtool eth0` (`Speed: 100000Mb/s`,
`Link detected: yes`) and by the loopback self-test (which moves frames through the MRMAC and
MCDMA at full frame size with zero errors). The single-stream iperf3 ceiling is set by the
embedded CPU: each packet traverses the kernel TCP/IP stack and the `xilinx_axienet` driver's
single-queue DMA path before reaching (or leaving) DDR. On a Cortex-A72 the resulting limit is a
small fraction of 100G, independent of link speed.

Designs that require sustained 100G throughput structure the datapath as a split control / data
plane, removing the CPU from the bulk-traffic path:

* **Data plane in fabric.** Incoming packets are parsed at the MRMAC's AXI-Stream client
  interface by a packet classifier in PL, typically matching on Ethernet / IP / UDP header
  fields, VLAN tag, or a protocol-specific marker. Matched flows are routed directly to fabric
  processing blocks — raw sensor/ADC data into a DSP pipeline, video frames into a Vitis Vision
  pipeline, or application-specific compute kernels. On Versal, bulk traffic is typically handed
  off from PL to an AI Engine array. This traffic does not transit the PS, so both QSFP28 ports
  can sustain wire-rate concurrently.
* **Control plane on the CPU.** The classifier forwards a small subset of traffic — ARP, ICMP,
  DHCP, SSH, management protocols, application configuration — up the MCDMA path to the kernel.
  This traffic is low-volume and the Linux network stack handles it without difficulty.

The 2x QSFP28 FMC and the per-port MRMAC provide the building blocks; the design choice is the
partitioning of work between fabric and PS. For benchmarking a fabric datapath, iperf3 over the
Linux network stack is not appropriate; an AXI-Stream loopback in PL with hardware counters (or
the `mrmac-loopback-test` above) is the meaningful measurement.

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
