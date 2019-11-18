.PHONY: spec
spec: deps
	crystal spec

.PHONY: deps
deps: src/predict/ext/sgp4.a

src/predict/ext/sgp4.a: $(shell find src/predict/ext -type f \( -name '*.c' -o -name Makefile \))
	make -C src/predict/ext clean sgp4.a

.PHONY: clean
clean:
	make -C src/predict/ext clean
