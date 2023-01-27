SHELL=/bin/bash

.PHONY: all clean

all: build build/jpx-importer.aseprite-extension

transpiled/main.lua: main.moon
	moonc -o $@ $<

build:
	mkdir $@

build/jpx-importer.aseprite-extension: package.json transpiled/main.lua
	zip $@ -j $^

clean:
	rm -rf transpiled build
