-include config.mk

ifndef C
$(error C must be defined)
endif

include ${C}/config.mk

BUILDDIR := $(shell mktemp -d -t imgbldr-XXXXX)
BASEDIR := $(dir $(realpath $(firstword ${MAKEFILE_LIST})))

FILES = ${BUILDDIR}/files
#files = files

#CONFIGS = config.mk ${C}/config.mk
#DEPS += $(shell find ${files} -type f,l)
#DEPS += $(shell [ -d ${C}/files ] && find ${C}/files -type f,l)
#DEPS += ${CONFIGS}

HOSTS ?= ${C}

IMAGE ?= squashfs-sysupgrade.bin

imagebuilder ?= openwrt-imagebuilder-${RELEASE}-${TARGET}-${SUBTARGET}.Linux-x86_64

image ?= openwrt-${RELEASE}-${TARGET}-${SUBTARGET}-${PLATFORM}-${IMAGE}

comment = \#%
parts = $(filter-out ${comment}, $(foreach f,$1,$(file < ${BASEDIR}/lists/$f)))
#PACKAGES = $(addprefix -,$(call parts,${REMOVE_LISTS})) $(addprefix -,$(foreach p,${REMOVE_PKGS},$p)) $(call parts,${INSTALL_LISTS}) $(foreach p,${INSTALL_PKGS},$p)
PACKAGES = $(addprefix -,$(call parts,${REMOVE_LISTS})) $(addprefix -,$(foreach p,${REMOVE_PKGS},$p)) $(call parts,${INSTALL_LISTS}) $(filter-out ${comment}, $(foreach p,${INSTALL_PKGS},$p))


all: copy

listpks:
	@echo ${PACKAGES}

imagebuilder: ${BUILDDIR}/${imagebuilder}

${BUILDDIR}/${imagebuilder}: ${imagebuilder}.tar.xz
	tar --touch -C ${BUILDDIR} -xf $<

${imagebuilder}.tar.xz:
	wget -c https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/${SUBTARGET}/$@

image: ${C}/${image}

install = rsync --mkpath ${1} ${FILES}${2}

${FILES}:
	mkdir ${FILES}
	${FILES_INSTALL}
	[ ! -d ${C}/files ] || cp -r -T -f ${C}/files ${FILES}

files: ${FILES}


${C}/${image}: ${BUILDDIR}/${imagebuilder} ${FILES} ${DEPS}
	umask 022; $(MAKE) -C $< image PROFILE=${PLATFORM} PACKAGES="${PACKAGES}" FILES=${FILES}
	cp ${BUILDDIR}/${imagebuilder}/bin/targets/${TARGET}/${SUBTARGET}/${image} $@
ifndef LEAVE_BUILD
	rm -rf ${BUILDDIR}
else
	@echo ${BUILDDIR}
endif

copy: ${C}/${image}
	$(foreach h,${HOSTS},scp ${SCPOPTS} $< $h:/tmp&)

install: copy
	$(foreach h,${HOSTS},ssh $h sysupgrade -v /tmp/${image}&)

.PHONY: copy listpks image
