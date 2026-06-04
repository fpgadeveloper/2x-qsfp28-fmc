FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# 2x QSFP28 FMC: enable the Si5328 CKOUT2 output (GBTCLK1, QSFP port 1) in the
# si5324 clk driver - the stock driver disables CKOUT2, leaving port 1 with no
# GT reference clock.
SRC_URI:append = " file://0001-clk-si5324-enable-ckout2-for-2x-qsfp28-fmc.patch"

# 2x QSFP28 FMC: MRMAC has no PHY/phylink and no link-change IRQ, so the stock
# axienet driver only checks RX block lock once at open() and fails if the link
# isn't already up (needs a manual "ip link" bounce; never recovers if the peer
# comes up later). Add a 1 Hz carrier monitor that drives netdev carrier from
# block-lock so the link comes up automatically whenever both ends are lasing.
SRC_URI:append = " file://0002-net-axienet-mrmac-carrier-link-monitor.patch"
