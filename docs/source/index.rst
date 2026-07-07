.. 100G/40G Ethernet Ref Designs for 2x QSFP28 FMC documentation master file.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

100G/40G Ethernet Ref Designs for 2x QSFP28 FMC
===============================================

This is the documentation for the 100G/40G Ethernet reference designs for the Opsero
`2x QSFP28 FMC`_. Each QSFP28 port is driven as a single 100GbE (CAUI-4) or 40GbE
(40GBASE-R4) channel by the Ethernet MAC suited to the target device: the Versal
Integrated MRMAC, the UltraScale+ Integrated 100G Ethernet (CMAC), or the soft
40G/50G Ethernet Subsystem.


.. toctree::
   :maxdepth: 2
   :caption: User Guide

   description
   requirements
   build_instructions
   echo_server
   petalinux
   yocto
   advanced
   troubleshooting
   revision_history


.. _2x QSFP28 FMC: https://docs.opsero.com/op120/datasheet/overview/
