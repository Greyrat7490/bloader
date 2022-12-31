name := bloader
asm_files := $(shell find . -name "*.asm")

.PHONY: all clean run

all: build/$(name).img

run: build/$(name).img
	qemu-system-x86_64 -drive format=raw,file=build/$(name).img

clean:
	rm -rf build

build/$(name).bin: $(asm_files)
	mkdir -p build
	nasm -f bin $(name).asm -o $@

build/$(name).img: build/$(name).bin
	rm -f $@
	dd if=/dev/zero of=$@ count=8 bs=1M
	dd if=$< of=$@ conv=notrunc
