.PHONY: test lint format-check

NVIM_BIN ?= nvim
STYLUA ?= npx -y @johnnymorganz/stylua-bin

TESTS := $(sort $(wildcard tests/*.lua))

test:
	@for test in $(TESTS); do \
		echo "==> $$test"; \
		$(NVIM_BIN) --headless --clean -l $$test || exit $$?; \
	done

lint:
	luacheck lua tests

format-check:
	$(STYLUA) --check .
