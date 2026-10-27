VERILATOR ?= verilator
TOP       := tb_async_fifo
RTL       := $(wildcard rtl/*.sv)
TB        := tb/$(TOP).sv
SEEDS     ?= 1 2 3 4 5
# Apple clang defaults to C++98 and Verilator's verilated.mk adds no -std, so
# pin it explicitly (gnu++20 matches what Verilator uses for --timing coroutines).
# -Wno-unknown-warning-option silences flags baked in by a newer build compiler
# (e.g. -Wno-vla-cxx-extension in the Homebrew bottle); GCC ignores it.
CXXSTD    ?= -std=gnu++20
VFLAGS    := --binary --timing -Wall -j 0 -Irtl --top-module $(TOP) \
             -CFLAGS "$(CXXSTD) -Wno-unknown-warning-option"

define build
	mkdir -p build/$(1) && $(VERILATOR) $(VFLAGS) $(2) -Mdir build/$(1) $(RTL) $(TB)
endef

define run_seeds
	for s in $(SEEDS); do ./build/$(1)/V$(TOP) +seed=$$s || exit 1; done
endef

.PHONY: lint sim stress meta broken waves clean

lint:
	$(VERILATOR) --lint-only -Wall --timing -Irtl --top-module $(TOP) $(RTL) $(TB)

sim:
	$(call build,sim,)
	./build/sim/V$(TOP) +seed=1

stress:
	$(call build,stress,+define+STRESS)
	$(call run_seeds,stress)

meta:
	$(call build,meta,+define+STRESS +define+INJECT_META)
	$(call run_seeds,meta)

broken:
	$(call build,broken,+define+STRESS +define+INJECT_META +define+BROKEN_BINARY)
	! ./build/broken/V$(TOP) +seed=1

waves:
	$(call build,waves,--trace-fst +define+DUMP)
	./build/waves/V$(TOP) +seed=1

clean:
	rm -rf build *.fst
