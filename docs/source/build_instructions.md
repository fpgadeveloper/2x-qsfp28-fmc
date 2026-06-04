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

The design uses the Versal Integrated MRMAC, which requires a (free, no-cost) license to generate
a bitstream. The license can be obtained from the AMD Xilinx Licensing site. The VCK190 target
also requires the Vivado *Enterprise* Edition (a 30-day evaluation license is available from the
AMD Xilinx Licensing site).

## Target designs

This repo contains one or more designs that target the supported development board(s) and their
FMC connectors. The table below lists the target design name, the QSFP28 ports supported by the
design and the FMC connector on which to connect the mezzanine card.

{% for linkspeed in ["100"] %}
### {{ linkspeed }}G designs

These designs drive each QSFP28 port as a single {{ linkspeed }}GbE (CAUI-4) channel.

| Target board        | Target design     | Ports   | FMC Slot    | Vivado<br> Edition |
|---------------------|-------------------|---------|-------------|-----|
{% for design in data.designs %}{% if design.linkspeed == linkspeed and design.publish %}| [{{ design.board }}]({{ design.link }}) | `{{ design.label }}` | {{ design.lanes | length }}x | {{ design.connector }} | {{ "Enterprise" if design.license else "Standard 🆓" }} |
{% endif %}{% endfor %}
{% endfor %}

Notes:

1. The Vivado Edition column indicates which designs are supported by the Vivado *Standard*
   Edition, the FREE edition which can be used without a license. Vivado *Enterprise* Edition
   requires a license, however a 30-day evaluation license is available from the AMD Xilinx
   Licensing site.
2. Regardless of the Vivado Edition, the Versal Integrated MRMAC requires a (free) license to
   generate a bitstream.

## Windows users

Windows users will be able to build the Vivado project, however Linux is required to build the
PetaLinux project.

```{tip}
If you wish to build the PetaLinux project,
we recommend that you build the entire project (including the Vivado project) on a machine (either 
physical or virtual) running one of the [supported Linux distributions].
```

### Build Vivado project in Windows

1. Download the repo as a zip file and extract the files to a directory
   on your hard drive --OR-- clone the repo to your hard drive
2. Open Windows Explorer, browse to the repo files on your hard drive.
3. In the `Vivado` directory, double click on the `build-vivado.bat` batch file.
   You will be prompted to select a target design to build. You will find the project in
   the folder `Vivado/<target>`.
4. Run Vivado and open the project that was just created.
5. Click Generate bitstream.
6. When the bitstream is successfully generated, select **File->Export->Export Hardware**.
   In the window that opens, tick **Include bitstream** and use the default name and location
   for the XSA file.

## Linux users

This project can be built using a machine (either physical or virtual) with one of the 
[supported Linux distributions].

```{tip}
The build steps can be completed in the order shown below, or
you can go directly to the [build PetaLinux](#build-petalinux-project-in-linux) instructions below
to build the Vivado and PetaLinux projects with a single command.
```

### Build Vivado project in Linux

1. Open a command terminal and launch the setup script for Vivado:
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   ```
2. Clone the Git repository and `cd` into the `Vivado` folder of the repo:
   ```
   git clone https://github.com/fpgadeveloper/2x-qsfp28-fmc.git
   cd 2x-qsfp28-fmc/Vivado
   ```
3. Run make to create the Vivado project for the target board. You must replace `<target>` with a valid
   target (alternatively, skip to step 5):
   ```
   make project TARGET=<target>
   ```
   Valid target labels are:
   {% for design in data.designs if design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
   That will create the Vivado project and block design without generating a bitstream or exporting to XSA.
4. Open the generated project in the Vivado GUI and click **Generate Bitstream**. Once the build is
   complete, select **File->Export->Export Hardware** and be sure to tick **Include bitstream** and use
   the default name and location for the XSA file.
5. Alternatively, you can create the Vivado project, generate the bitstream and export to XSA (steps 3 and 4),
   all from a single command:
   ```
   make xsa TARGET=<target>
   ```
   
### Build PetaLinux project in Linux

These steps will build the PetaLinux project for the target design. You are not required to have built the
Vivado design before following these steps, as the Makefile triggers the Vivado build for the corresponding
design if it has not already been done.

1. Launch the setup script for Vivado (only if you skipped the Vivado build steps above):
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2025.2/settings.sh
   ```
3. Build the PetaLinux project for your specific target platform by running the following
   command, replacing `<target>` with a valid value from below:
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   Valid target labels for PetaLinux projects are:
   {% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
   Note that if you skipped the Vivado build steps above, the Makefile will first generate and
   build the Vivado project, and then build the PetaLinux project.

### PetaLinux offline build

If you need to build the PetaLinux project offline (without an internet connection), you can
follow these instructions.

1. Download the sstate-cache artefacts from the Xilinx downloads site (the same page where you downloaded
   PetaLinux tools). For this Versal design you need:
   * aarch64 sstate-cache
   * Downloads (for all designs)
2. Extract the contents of those files to a single location on your hard drive, for this example
   we'll say `/home/user/petalinux-sstate`. That should leave you with the following directory 
   structure:
   ```
   /home/user/petalinux-sstate
                             +---  aarch64
                             +---  downloads
   ```
3. Create a text file called `offline.txt` in the `PetaLinux` directory of the project repository. The file should contain
   a single line of text specifying the path where you extracted the sstate-cache files. In this example, the contents of 
   the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is written with NO TRAILING 
   FORWARD SLASH.

Now when you use `make` to build the PetaLinux project, it will be configured for offline build.

[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
