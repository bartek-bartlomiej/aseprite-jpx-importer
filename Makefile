SHELL=/bin/bash

SOURCE_DIR := source
BUILD_DIR := build

SOURCE_PATH := ./$(SOURCE_DIR)
BUILD_PATH := ./$(BUILD_DIR)

SOURCES := $(shell find $(SOURCE_PATH) -name '*.moon')
LICENCES := $(shell find $(SOURCE_PATH) -name 'LICENCE')

TO_TRANSPILE := $(SOURCES:%.moon=%.lua)


.PHONY: all clean

all: $(BUILD_PATH) $(BUILD_PATH)/jpx-importer.aseprite-extension

$(SOURCE_PATH)/%.lua: $(SOURCE_PATH)/%.moon
	moonc -o $@ $<

$(BUILD_PATH):
	mkdir $@

$(BUILD_PATH)/jpx-importer.aseprite-extension: $(SOURCE_PATH)/package.json $(TO_TRANSPILE) $(LICENCES)
	pushd $(SOURCE_PATH) ; \
	zip -r ../$@ $(^:$(SOURCE_DIR)/%=%) ; \
	popd

clean:
	rm -rf $(BUILD_PATH)
	rm $(TO_TRANSPILE)
