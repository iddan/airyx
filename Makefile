# Primary makefile for the Helium OS

TOPDIR := ${.CURDIR}
MAKEOBJDIRPREFIX := ${HOME}/obj.${MACHINE}
RLSDIR := ${MAKEOBJDIRPREFIX}${TOPDIR}/freebsd-src/${MACHINE}.${MACHINE}/release
BSDCONFIG := GENERIC
BUILDROOT := ${MAKEOBJDIRPREFIX}/buildroot

# Incremental build for quick tests or system update
build: prep freebsd-noclean helium

# Full release build with installation artifacts
world: prep freebsd helium release

prep:
	mkdir -p ${MAKEOBJDIRPREFIX} ${RLSDIR} ${TOPDIR}/dist ${BUILDROOT}

${TOPDIR}/freebsd-src/sys/${MACHINE}/compile/${BSDCONFIG}: ${TOPDIR}/freebsd-src/sys/${MACHINE}/conf/${BSDCONFIG}
	mkdir -p ${TOPDIR}/freebsd-src/sys/${MACHINE}/compile/${BSDCONFIG}
	(cd ${TOPDIR}/freebsd-src/sys/${MACHINE}/conf && config ${BSDCONFIG} 
		\ && cd ../compile/${BSDCONFIG} && make depend)

checkout:
	test -d ${TOPDIR}/freebsd-src || \
		(cd ${TOPDIR} && git clone https://github.com/freebsd/freebsd-src.git && \
		cd freebsd-src && git checkout stable/12)

freebsd: checkout ${TOPDIR}/freebsd-src/sys/${MACHINE}/compile/${BSDCONFIG}
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; make -C ${TOPDIR}/freebsd-src buildkernel buildworld

freebsd-noclean:
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; make -C ${TOPDIR}/freebsd-src -DNO_CLEAN buildkernel buildworld

helium: extradirs swift

# Update the build system with current source
install: installworld installkernel

installworld:
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; sudo make -C ${TOPDIR}/freebsd-src installworld

installkernel:
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; sudo make -C ${TOPDIR}/freebsd-src installkernel

extradirs:
	for x in System System/Library Library Users Applications Volumes; \
		do mkdir -p ${MAKEOBJDIRPREFIX}/buildroot/$$x; \
	done

swift: .PHONY
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; make -C swift BUILDROOT=${BUILDROOT} build install

helium-package:
	tar cJ -C ${MAKEOBJDIRPREFIX}/buildroot --gid 0 --uid 0 -f ${RLSDIR}/helium.txz .

# Create the standard BSD packages and MANIFEST with the packagesystem target,
# then add our packages to the MANIFEST. We remove the packagesystem dependency
# from the BSD release/Makefile so the modified MANIFEST is not overwritten
# by the image builds
distname=helium
dist=${distname}.txz
desc=Helium system (MANDATORY)
release: helium-package
	sed -e 's/: packagesystem$$/:/' ${TOPDIR}/freebsd-src/release/Makefile > ${TOPDIR}/freebsd-src/release/Makefile.helium
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; \
		sudo -E make -C ${TOPDIR}/freebsd-src/release -f Makefile.helium packagesystem
	cd ${RLSDIR}; \
		echo -e "${dist}\t$$(sha256 -q ${dist})\t$$(tar tvf ${dist} | wc -l | tr -d ' ')\t${distname}\t\"${desc}\"\ton" \
		| sudo tee -a MANIFEST
	export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX}; \
		sudo -E make -C ${TOPDIR}/freebsd-src/release -f Makefile.helium cdrom memstick mini-memstick ftp
	cp -fvR ${RLSDIR}/ftp ${RLSDIR}/*.img ${RLSDIR}/*.iso ${TOPDIR}/dist/
