name := bloader
test_kernel_asm := test.asm
test_kernel_bin := build/test
test_img := build/$(name)_test.img

asm_files := $(shell find . -name "*.asm")
img := build/$(name).img
bin := build/$(name).bin


.PHONY: all clean test release

all: $(img)
release: $(img)

test: $(test_img)
	qemu-system-x86_64 -drive format=raw,file=$(img)

monitor: $(test_img)
	qemu-system-x86_64 -drive format=raw,file=$(img) -no-reboot -no-shutdown -monitor stdio

log: $(test_img)
	qemu-system-x86_64 -drive format=raw,file=$(img) -D log -d int -no-reboot -no-shutdown

clean:
	rm -rf build


$(bin): $(asm_files)
	mkdir -p build
	nasm -f bin $(name).asm -o $@

$(test_kernel_bin): $(test_kernel_asm)
	mkdir -p build
	nasm -f elf64 $< -o $(test_kernel_bin).o
	ld -o $(test_kernel_bin) $(test_kernel_bin).o

$(img): $(bin)
	rm -f $(img)
	dd if=/dev/zero of=$(img) count=8 bs=1M
	dd if=$(bin) of=$(img) conv=notrunc

$(test_img): $(img) $(test_kernel_bin)
	# mount img without root permissions
	tmp_loop=$$(udisksctl loop-setup -f $(img) | awk '{gsub(/.$$/,""); print $$NF}') && \
	tmp_mnt=$$(udisksctl mount -b $$tmp_loop | awk '{print $$NF}') && \
	cp $(test_kernel_bin) $$tmp_mnt/KERNEL && \
	udisksctl unmount -b $$tmp_loop	&& \
	udisksctl loop-delete -b $$tmp_loop
