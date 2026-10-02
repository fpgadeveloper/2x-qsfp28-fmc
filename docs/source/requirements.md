# Requirements

## Tools and licenses

* Vivado 2025.2 (every target). The Vivado *Standard* Edition (free) is enough for the
  ZCU106 and KCU116 targets; the other boards need the *Enterprise* Edition (a 30-day
  evaluation license is available) — see the target tables in the
  [build instructions](build_instructions).
* Vitis 2025.2 — for the standalone echo server, and for the Yocto flow (which uses the
  `xsct`/`sdtgen` tools that ship with Vitis).
* PetaLinux Tools 2025.2 — only for the PetaLinux flow.
* For the Yocto flow: [Google's repo tool](https://gerrit.googlesource.com/git-repo/) and the
  usual Yocto host packages (see [Yocto](yocto)).
* A license for the target's Ethernet MAC IP — no cost for the hardened 100G MACs (Versal
  MRMAC, UltraScale+ CMAC), purchased (30-day evaluation available) for the 40G/50G Ethernet
  Subsystem used by the 40G targets; see the license requirements in the
  [build instructions](build_instructions).
* Host operating system: the Vivado and Vitis builds run on Windows or Linux; the PetaLinux
  and Yocto builds require a Linux machine (one of the [supported Linux distributions]).

## Hardware

* The [2x QSFP28 FMC] (OP120)
* One of the supported carrier boards listed below, with its power supply, USB-UART cable
  (console, 115200 baud) and USB-JTAG cable
* A microSD card for booting the Zynq UltraScale+ and Versal targets from SD: 16 GB or
  larger for the Yocto images (the Yocto disk image is about 8.6 GB, slightly more than
  most "8 GB" cards hold)
* Something to connect the QSFP28 ports to, depending on the test:
  * **Port-to-port test** (dual-port targets): a QSFP28 cable between QSFP28 port 0 and
    port 1 — a passive copper DAC is the safest choice for both line rates. For the 100G
    targets a 100G AOC also works.
  * **Self-loopback test** (any target, the only option on single-port targets): a passive
    QSFP28 loopback module in each port under test.
  * **Link partner**: a NIC or switch port at the same line rate as the target (100GbE
    CAUI-4 for the 100G targets, 40GBASE-R4 for the 40G targets), with **FEC turned off**
    on the partner (see [troubleshooting](troubleshooting)).

```{note}
The 40G targets run each lane at 10.3125 Gb/s. Many 100G AOCs and 100G SR4 optics are not
rated for that lane rate, so use passive copper (DAC or loopback modules) or optics and
cables rated for 40GBASE-R4 with the 40G targets.
```

## List of supported boards

{% for group in data.groups %}
{% set boards = {} %}
{% for design in data.designs %}{% if design.publish and design.group == group.label %}
{% if design.board not in boards %}{% set _ = boards.update({design.board: {"link": design.link, "connectors": []}}) %}{% endif %}
{% if design.connector not in boards[design.board]["connectors"] %}{% set _ = boards[design.board]["connectors"].append(design.connector) %}{% endif %}
{% endif %}{% endfor %}
{% if boards | length > 0 %}
### {{ group.name }} boards

| Carrier board        | Supported FMC connector(s)    |
|---------------------|--------------|
{% for name, board in boards.items() %}| [{{ name }}]({{ board.link }}) | {% for connector in board.connectors %}{{ connector }} {% endfor %} |
{% endfor %}
{% endif %}
{% endfor %}

For the list of target designs showing the number of QSFP28 ports supported, refer to the
[build instructions](build_instructions).

[2x QSFP28 FMC]: https://docs.opsero.com/op120/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
