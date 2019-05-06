.PHONY: all
all:
	dune build @default
	$(MAKE) help

help:
	dune build \
		merge-fmt-help.txt \
		merge-fmt-mergetool-help.txt \
		merge-fmt-setup-mergetool-help.txt \
		merge-fmt-setup-merge-help.txt
.PHONY: test
test:
	dune build @runtest

.PHONY: clean
clean:
	dune clean
