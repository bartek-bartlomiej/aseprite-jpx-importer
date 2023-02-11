SHELL=/bin/bash

SOURCE_DIR := source
BUILD_DIR := build

SOURCE_PATH := ./$(SOURCE_DIR)
BUILD_PATH := ./$(BUILD_DIR)

SOURCES := $(shell find $(SOURCE_PATH) -name '*.moon')
LICENCES := ./LICENCE $(shell find $(SOURCE_PATH) -name 'LICENCE')

source_dirs = $(dir $(SOURCES))
source_names = $(notdir $(SOURCES))
trimmed_dirs = $(source_dirs:$(SOURCE_PATH)%=%)
flatten_sources = $(join $(trimmed_dirs:/%/=/%-), $(source_names:%.moon=%.lua))

TRANSPILED := $(addprefix $(BUILD_PATH),$(flatten_sources))

.PHONY: all clean

all: $(BUILD_PATH) $(BUILD_PATH)/jpx-importer.aseprite-extension

$(BUILD_PATH):
	mkdir $@

$(BUILD_PATH)/jpx-importer.aseprite-extension: $(SOURCE_PATH)/package.json $(TRANSPILED) $(BUILD_PATH)/LICENCE
	zip $@ -j $^

$(BUILD_PATH)/LICENCE: $(LICENCES)
	for file in $^; do \
		cat $$file; echo ''; \
	done > $@

$(TRANSPILED) &: $(SOURCES)
	input=($(SOURCES)); \
	output=($(TRANSPILED)); \
	for (( i = 0; i < $${#input[@]}; i++ )); \
	do \
		moonc -o $${output[$$i]} $${input[$$i]} ; \
	done


clean:
	rm -rf $(BUILD_PATH)
