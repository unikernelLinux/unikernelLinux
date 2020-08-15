.PHONY: build-all build-linux build-glibc build-ukl-app build-min-initrd
PARALLEL= -j$(shell nproc)

build-ukl-app: build-glibc build-linux
	echo building ukl app
	make -C ukl fstest

build-linux:
	echo building linux
	cp Linux-Configs/ukl/golden_config-5.7 ./linux/.config
	make -C linux oldconfig
# This is supposed to fail at this stage
	- make -C linux $(PARALLEL)

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


gcc:
	git clone --depth 1 --branch releases/gcc-8.3.0 'https://github.com/gcc-mirror/gcc.git'
	cd ./gcc; ./contrib/download_prerequisites

# If you want to try a large build.
gcc-build-large: gcc
	mkdir $@
	mkdir gcc-install
	cd $@; \
	  TARGET=x86_64-elf ../gcc/configure --target=$(TARGET) \
	  --disable-nls --enable-languages=c,c++ --without-headers \
	  --prefix=/home/tommyu/localInstall/gcc-install/ \
	  --with-multilib-list=m64 #--disable-multilib
	make -C $@ all-gcc $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=large -mno-red-zone' $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=large -mno-red-zone'
	make -C $@ install-gcc
	make -C $@ install-target-libgcc

# Gives libgcc.a and libgcc_eh.a
gcc-build: gcc
	mkdir $@
	mkdir gcc-install
	cd $@; \
	  TARGET=x86_64-elf ../gcc/configure --target=$(TARGET) \
	  --disable-nls --enable-languages=c,c++ --without-headers \
	  --prefix=/home/tommyu/localInstall/gcc-install/ \
	  --with-multilib-list=m64 --disable-multilib
	make -C $@ all-gcc $(PARALLEL)

# Expect this to fail.
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mno-red-zone -mcmodel=kernel' $(PARALLEL)

# Double check everything that could finish did by removing parallelism
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mno-red-zone -mcmodel=kernel'

# Flip pic flag
	sed -i 's/PICFLAG/DISABLED_PICFLAG/g' gcc-build/x86_64-pc-linux-gnu/libgcc/Makefile

# Think this is supposed to succede, but it fails.
	make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone -mcmodel=kernel'
# make -C $@ install-gcc $(PARALLEL)
# make -C $@ install-target-libgcc $(PARALLEL)

# libgcc.a libstdc++... crts...
gcc-build-cpp: gcc
	mkdir $@
	mkdir gcc-install
# Build for 64 bit only
	cd $@; \
	  TARGET=x86_64-elf ../gcc/configure --target=$(TARGET) \
	  --disable-shared --disable-nls --enable-languages=c,c++ --without-headers \
	  --prefix=/mnt/unikernelLinux/gcc-install/ \
	  --with-multilib-list=m64 --disable-multilib
	make -C $@ all-gcc $(PARALLEL)

# Expect this to fail.
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mno-red-zone -mcmodel=kernel' $(PARALLEL)

# Double check everything that could finish did by removing parallelism
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mno-red-zone -mcmodel=kernel'

	- make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone' CXXFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone' $(PARALLEL)
	- make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone' CXXFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone'

# Flip pic flag
	sed -i 's/PICFLAG/DISABLED_PICFLAG/g' $@/x86_64-pc-linux-gnu/libgcc/Makefile

# Think this is supposed to succede, but it fails.
	make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone'
	make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone' CXXFLAGS_FOR_TARGET='-g -O2 -mcmodel=kernel -mno-red-zone' 

	- make -C $@ install-gcc $(PARALLEL)
	- make -C $@ install-target-libgcc $(PARALLEL)
	- make -C $@ install-target-libstdc++-v3 $(PARALLEL)

gcc-clean:
	rm -rf gcc-build gcc-install gcc-build-large gcc-build-cpp
