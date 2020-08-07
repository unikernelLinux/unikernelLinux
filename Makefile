.PHONY: build-all build-linux build-glibc build-ukl-app build-min-initrd

build-ukl-app: build-glibc build-linux
	echo building ukl app
	make -C ukl fstest

build-linux:
	echo building linux
	cp Linux-Configs/ukl/golden_config-5.7 ./linux/.config
	make -C linux oldconfig
# This is supposed to fail at this stage
	- make -C linux -j$(nproc)

# This name is for compatibility with ukl
BUILD_DIR =build-glibc/glibc-build
BOGUS_PREFIX =/home/fedora/unikernel/build-glibc/glibc-build
build-glibc:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && \
		../../glibc/configure CFLAGS="-g -O2 -fthread-jumps -mcmodel=kernel -mno-red-zone" --prefix=$(BOGUS_PREFIX) --enable-hacker-mode --enable-timezone-tools --disable-build-nscd --disable-nscd --disable-pt_chown --enable-static-nss x86_64-ukl --disable-shared --disable-tunables build_alias=x86_64-ukl host_alias=x86_64-ukl target_alias=x86_64-ukl |& tee -a ../log

	make -j$(nproc) -C $(BUILD_DIR) |& tee -a ../log
	make -j$(nproc) -C $(BUILD_DIR) subdirs=nptl |& tee -a ../log
# This is a hack because glibc expects this file which doesn't exist.
	touch glibc/first-versions.h
	make -j$(nproc) -C $(BUILD_DIR) subdirs=math |& tee -a ../log

# For compatibility with ukl repo

launch-ukl-app: build-min-initrd
	echo launching ukl app
	make -C min-initrd
	make -C min-initrd runU
