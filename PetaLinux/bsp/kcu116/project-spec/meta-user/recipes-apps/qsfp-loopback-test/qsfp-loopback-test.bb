SUMMARY = "QSFP28 port-to-port loopback self-test script"
DESCRIPTION = "Installs /usr/bin/qsfp-loopback-test: a pktgen + netns + iperf3 \
loopback test for the 2x QSFP28 FMC. On dual-port targets connect a passive \
DAC cable between the two QSFP ports; on single-port targets fit a QSFP \
loopback plug and run with --single."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://qsfp-loopback-test"

S = "${WORKDIR}"

do_install() {
	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/qsfp-loopback-test ${D}${bindir}/qsfp-loopback-test
}

FILES:${PN} = "${bindir}/qsfp-loopback-test"

# iproute2: network namespaces for the IP phases (busybox 'ip' lacks netns).
# iperf3/ethtool: throughput phase and link diagnostics.
# pktgen is a kernel module - enabled as CONFIG_NET_PKTGEN=m in the BSP's
# kernel bsp.cfg; RRECOMMENDS pulls the package in wherever it is built.
RDEPENDS:${PN} += "iproute2 iperf3 ethtool"
RRECOMMENDS:${PN} += "kernel-module-pktgen"
