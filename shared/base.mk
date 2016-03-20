MAKEADFDIR=../tools/makeadf/
MAKEADF=$(MAKEADFDIR)/out/makeadf
HOST_WARNINGS=-pedantic-errors -Wfatal-errors -Wall -Werror -Wextra -Wno-unused-parameter -Wshadow
HOST_CFLAGS=$(HOST_WARNINGS)
IMAGECONDIR=../tools/imagecon
IMAGECON=$(IMAGECONDIR)/out/imagecon
SHRINKLERDIR=../tools/external/shrinkler
SHRINKLEREXE=$(SHRINKLERDIR)/build/native/Shrinkler
RESIZEDIR=../tools/resize
RESIZE=$(RESIZEDIR)/out/resize
A500_RUN_SCRIPT=~/Google\ Drive/Amiga/amiga500.sh
A600_RUN_SCRIPT=~/Google\ Drive/Amiga/amiga600.sh

#VASM_ARGS=-phxass -Fhunk -quiet -spaces
VASM_ARGS=-Fhunk -quiet -esc 

ifndef FLOPPY
FLOPPY=bin/$(EXAMPLE_NAME).adf
endif

ifndef MODULE
MODULE=$(EXAMPLE_NAME).s
endif

ifndef SHRINKLER
SHRINKLER=0
endif

ifndef BASE_ADDRESS
BASE_ADDRESS=70000
endif

ifndef DECOMPRESS_ADDRESS
DECOMPRESS_ADDRESS=10000
endif

ifndef RUN_SCRIPT
RUN_SCRIPT=$(A500_RUN_SCRIPT)
endif


ifeq ($(SHRINKLER),1)
ifndef BOOTBLOCK_ASM
BOOTBLOCK_ASM=../shared/shrinkler_bootblock.s
endif
PROGRAM_BIN=out/shrunk.bin
VASM_EXTRA_BOOTBLOCK_ARGS=-DSHRINKLER=$(SHRINKLER) -DDECOMPRESS_ADDRESS="\$$$(DECOMPRESS_ADDRESS)"
else
ifndef BOOTBLOCK_ASM
BOOTBLOCK_ASM=../shared/bootblock.s
endif
PROGRAM_BIN=out/main.bin
VASM_EXTRA_BOOTBLOCK_ARGS=-DSHRINKLER=$(SHRINKLER)
endif

ifndef LINK_COMMANDLINE
LINK_COMMANDLINE=vlink -Ttext 0x$(BASE_ADDRESS) -brawbin1 $< $(OBJS) -o $@
endif

all: bin out $(MAKEADF) $(FLOPPY)

gdrive: all
	cp $(FLOPPY) ~/Google\ Drive

test: all
	cp $(FLOPPY) ~/Projects/amiga/test.adf

go: test
	 $(RUN_SCRIPT)

list:
	m68k-amigaos-objdump  -b binary --disassemble-all out/bootblock.bin -m m68k > out/bootblock.txt

bin:
	mkdir bin

out:
	mkdir out

ic:
	make -C $(IMAGECONDIR)

$(IMAGECON):
	make -C $(IMAGECONDIR)

$(SHRINKLEREXE):
	make -C $(SHRINKLERDIR)

$(RESIZE):
	make -C $(RESIZEDIR)

$(MAKEADF):
	make -C $(MAKEADFDIR)

$(FLOPPY): out/bootblock.bin
	$(MAKEADF) out/bootblock.bin > $(FLOPPY)
	@ls -lh out/bootblock.bin

out/bootblock.bin: out/bootblock.o
	vlink -brawbin1 $< -o $@

out/bootblock.o: $(BOOTBLOCK_ASM) $(PROGRAM_BIN)
	vasmm68k_mot $(VASM_ARGS) $(VASM_EXTRA_BOOTBLOCK_ARGS) -DUSERSTACK_ADDRESS="\$$$(USERSTACK_ADDRESS)" -DBASE_ADDRESS="\$$$(BASE_ADDRESS)"  $< -o $@ -I/usr/local/amiga/os-include

out/main.o: $(MODULE) $(EXTRA)
	vasmm68k_mot $(VASM_ARGS) $(VASM_EXTRA_ARGS) $< -o $@ -I/usr/local/amiga/os-include

out/%.o: %.s
	vasmm68k_mot $(VASM_ARGS) $(VASM_EXTRA_ARGS) $< -o $@ -I/usr/local/amiga/os-include

out/%.o: %.c
	vc -O3 -c $< -o $@
	-@vc -O3 -S $< -o out/$*.s > /dev/null 2> /dev/null
	-@vc -O0 -S $< -o out/$*-noopt.s > /dev/null 2> /dev/null

out/main.bin: out/main.o $(OBJS)
	@#-T ../link.script
	$(LINK_COMMANDLINE)

out/shrunk.bin: $(SHRINKLER_EXE) out/main.bin
	$(SHRINKLEREXE) -d out/main.bin out/shrunk.bin

clean:
	rm -rf out bin *~
