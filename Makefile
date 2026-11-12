.PHONY: check build clean

check:
	sh tests/check.sh

build:
	mkdir -p dist
	osacompile -o dist/safari-tab-tamer.scpt scripts/safari-tab-tamer.applescript

clean:
	rm -f dist/safari-tab-tamer.scpt
