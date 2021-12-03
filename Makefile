all:
	nasm -f elf64 instr.asm
	gcc -Wall simulation.c instr.o -o simulation

clean:
	@rm instr.o simulation &> /dev/null