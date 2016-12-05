.PHONY: all
all: clean sgp4.a test

CXXFLAGS += $(if $(debug),-g -O0)
CXXFLAGS += $(if $(release),-O3 -flto)

sgp4.a: sgp4ext.o sgp4io.o sgp4unit.o
	gcc-ar rcs sgp4.a sgp4ext.o sgp4io.o sgp4unit.o

test: test.cpp sgp4.a
	$(LINK.cc) -o test test.cpp sgp4.a -lm

.PHONY: clean
clean:
	rm -Rf sgp4ext.o sgp4io.o sgp4unit.o sgp4.a test
	rm -Rf *.e tcp*.out
