# Build instructions

## Source code

The source code for the reference design is managed on this Github repository:

* [https://github.com/fpgadeveloper/2x-qsfp28-fmc](https://github.com/fpgadeveloper/2x-qsfp28-fmc)

To get the code, you can follow the link and use the **Download ZIP** option, or you can clone it
using this command:
```
git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
```

## License requirements

Every target design uses one of three AMD Ethernet MAC IPs, and all three require a license
to generate a bitstream — but they are licensed differently. The two hardened 100G MACs have
**no-cost** licenses that just need to be added to your account on the
[AMD licensing site](https://www.xilinx.com/getlicense), while the soft 40G/50G MAC used by
the 40G designs is a **purchased** core, with a 30-day evaluation license available for
testing:

| Ethernet MAC IP | License | Required by targets |
|-----------------|---------|---------------------|
| [Integrated 100G Multirate Ethernet MAC (MRMAC)](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/mrmac.html) | No cost | `vck190_fmcp1` |
| [UltraScale+ Integrated 100G Ethernet (CMAC)](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/cmac_usplus.html) | No cost | `zcu111`, `zcu208`, `zcu216`, `kcu116` |
| [40G/50G Ethernet Subsystem](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/ef-di-50gemac.html) | Purchase (30-day evaluation available) | `zcu102_hpc0`, `zcu106_hpc0`, `zcu111_ss`, `zcu208_ss`, `zcu216_ss`, `kcu116_ss` |

Separately from the IP licenses, some target boards require the Vivado *Enterprise* Edition
(a 30-day evaluation license is available from the AMD licensing site) — the **Vivado
Edition** column in the tables below shows which. The **IP License** column indicates the
designs that need a separately-licensed IP core to generate a bitstream.


## Target designs

This repo contains one or more designs that target the supported development board(s) and their
FMC connectors. The table below lists the target design name, the QSFP28 ports supported by the
design and the FMC connector on which to connect the mezzanine card.

{% for linkspeed in ["100"] %}
### {{ linkspeed }}G designs

These designs drive each QSFP28 port as a single {{ linkspeed }}GbE (CAUI-4) channel.

| Target board        | Target design     | Ports   | FMC Slot    | Vivado<br> Edition | IP<br>License |
|---------------------|-------------------|---------|-------------|-----|-----|
{% for design in data.designs %}{% if design.linkspeed == linkspeed and design.publish %}| [{{ design.board }}]({{ design.link }}) | `{{ design.label }}` | {{ design.lanes | length }}x | {{ design.connector }} | {{ "Enterprise" if design.license else "Standard 🆓" }} | {{ "Required" if design.ip_license else "-" }} |
{% endif %}{% endfor %}
{% endfor %}

Notes:

1. The Vivado Edition column indicates which designs are supported by the Vivado *Standard*
   Edition, the FREE edition which can be used without a license. Vivado *Enterprise* Edition
   requires a license, however a 30-day evaluation license is available from the AMD Xilinx
   Licensing site.
2. Regardless of the Vivado Edition, the Versal Integrated MRMAC requires a (free) license to
   generate a bitstream.

## Cross-platform build runner

All builds are driven by the `build.py` runner at the root of the repository,
on **both Windows and Linux** — the build instructions are the same for the
two operating systems. Each command builds whatever it depends on
automatically, skips anything that is already built, and locates the AMD
tools itself, so there is no need to source the settings scripts beforehand.

On Linux and on Windows (git bash), commands are run with the `build.sh`
shim, which finds a suitable Python 3 automatically (including the
interpreter bundled with the AMD tools). Windows users who prefer not to
use git bash can run the same commands from Command Prompt or PowerShell
using `build.bat` instead — the commands and arguments are otherwise
identical, for example `build.bat xsa --target <target>`.

To see the available targets and the state of a build:

```
./build.sh list                       # list the targets and their attributes
./build.sh status --target <target>   # show the per-stage artifact state
./build.sh clean --target <target>    # delete a target's generated outputs
```

```{note}
The embedded Linux images (PetaLinux) can only be built on a
native Linux machine; everything else builds on Windows too. On Windows, the
runner refuses the Linux-only stages up front and prints the exact command
to run on the Linux machine. For Versal targets on Windows, the runner also
verifies that the project path fits within the 260-character Windows path
limit before building, and explains the `subst` workaround if it does not.
```

```{attention}
The legacy `make` interface described in previous versions of
this documentation still works on Linux — each Makefile is now a thin
wrapper around `build.sh` — but it is deprecated and will be removed at the
next version update.
```

### Build Vivado project

This single command creates the Vivado project, generates the bitstream and
exports the hardware to an XSA file:

```
./build.sh xsa --target <target>
```

Valid targets are:
{% for design in data.designs if design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

If you want the Vivado project and block design without generating a
bitstream — for example, to explore or modify the design in the Vivado GUI —
run `./build.sh project --target <target>` instead, then open the project
from `Vivado/<target>/`.

### Build Vitis workspace

This creates the Vitis workspace and compiles the bare-metal
[echo server](echo_server), producing the boot file — a `BOOT.BIN` for the
Zynq UltraScale+ and Versal targets, or a `qsfp_boot.bit` (bitstream with
the ELF embedded) for the MicroBlaze targets. The Vivado XSA is built first
if it does not already exist:

```
./build.sh standalone --target <target>
```

Valid targets for the standalone application are:
{% for design in data.designs if design.baremetal and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The workspace is created in `Vitis/<target>_workspace` and the boot files
are gathered in `Vitis/boot/<target>/`.

### Build PetaLinux

The PetaLinux build requires a native Linux machine (one of the [supported
Linux distributions]) with PetaLinux Tools 2025.2 installed. The runner
locates and sources the PetaLinux `settings.sh` itself, and builds the
Vivado XSA first if it does not already exist:

```
./build.sh petalinux --target <target>
```

Valid targets for PetaLinux are:
{% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The output products are written to `PetaLinux/<target>/images/linux/`.

#### PetaLinux offline build

If you need to build the PetaLinux projects offline (without an internet
connection), you can follow these instructions.

1. Download the sstate-cache artefacts from the Xilinx downloads site (the
   same page where you downloaded PetaLinux tools). There are four of them:
   * aarch64 sstate-cache (for ZynqMP designs)
   * arm sstate-cache (for Zynq designs)
   * microblaze sstate-cache (for Microblaze designs)
   * Downloads (for all designs)
2. Extract the contents of those files to a single location on your hard
   drive, for this example we'll say `/home/user/petalinux-sstate`. That
   should leave you with the following directory structure:
   ```
   /home/user/petalinux-sstate
                             +---  aarch64
                             +---  arm
                             +---  downloads
                             +---  microblaze
   ```
3. Create a text file called `offline.txt` in the `PetaLinux` directory of
   the project repository. The file should contain a single line of text
   specifying the path where you extracted the sstate-cache files. In this
   example, the contents of the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is
   written with NO TRAILING FORWARD SLASH.

The PetaLinux builds will then be configured for offline build.

### Build Yocto

This builds the Yocto / EDF image (AMD's Embedded Development Framework,
the announced successor to PetaLinux) using AMD's recommended
`gen-machineconf` / `parse-sdt` flow. It requires a native Linux machine
with [Google's `repo` tool](https://gerrit.googlesource.com/git-repo/) on
the `PATH`; the `xsct`/`sdtgen` tools come from Vitis, which the runner
locates and sources itself. The Vivado XSA is built first if it does not
already exist:

```
./build.sh yocto --target <target>
```

Valid targets for Yocto are:
{% for design in data.designs if design.yocto and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The first build of a target runs `repo sync` (several GB of git history)
and bitbake from scratch, so it takes a while; subsequent builds are
incremental. The output products (`BOOT.BIN`, the kernel, `boot.scr`,
`system.dtb`, `rootfs.wic.xz`) are gathered into
`Yocto/<target>/images/linux/`.

#### Yocto offline build

To build the Yocto projects offline (or simply faster), point the build at
a locally extracted AMD sstate-cache mirror.

1. Download the sstate-cache artefacts from the Xilinx downloads site and
   extract them to a single location, for example `/home/user/yocto-sstate`,
   leaving the following directory structure:
   ```
   /home/user/yocto-sstate
                          +---  aarch64       (Zynq UltraScale+ and Versal)
                          +---  arm           (Zynq-7000)
                          +---  microblaze    (PMU/PLM firmware)
                          +---  downloads
   ```
2. Create a text file called `offline.txt` in the `Yocto` directory of the
   repository containing a single line with that path, written with NO
   TRAILING FORWARD SLASH:
   ```
   /home/user/yocto-sstate
   ```

The Yocto build will then auto-detect which architecture sub-directories
are present and configure the build to use the mirror.

### Build everything

This builds everything that the target supports — the Vivado project and XSA,
the standalone application, the PetaLinux image and the Yocto image — and
gathers the boot images into `bootimages/*.zip`:

```
./build.sh all --target <target>
./build.sh all --target all      # every target in the repo
```

On Windows, `all` builds everything that the host can build and reports the
Linux-only stages as `BLOCKED` rather than failing.

[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
