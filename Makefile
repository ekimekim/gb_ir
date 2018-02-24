
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean tests debug

ASMS := $(wildcard *.asm)
OBJS := $(ASMS:.asm=.o)
INCLUDES := $(wildcard include/*.asm)

all: rom.gb

%.o: %.asm $(INCLUDES)
	rgbasm -i include/ -v -o $@ $<

rom.gb: $(OBJS)
# pad with C7 = restart 0 = HaltForever
	rgblink -n rom.sym -o $@ -p 0xC7 $^
	rgbfix -v -p 0 -C $@

bgb: rom.gb
	bgb $<

clean:
	rm -f *.o *.sym rom.gb

debug:
	./debug

copy: rom.gb
	copy-rom ir-test rom.gb
