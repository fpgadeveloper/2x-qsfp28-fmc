FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# 2x QSFP28 FMC: enable the Si5328 CKOUT2 output (GBTCLK1, QSFP port 1) in the
# si5324 clk driver - the stock driver disables CKOUT2, leaving port 1 with no
# GT reference clock.
SRC_URI:append = " file://0001-clk-si5324-enable-ckout2-for-2x-qsfp28-fmc.patch"
