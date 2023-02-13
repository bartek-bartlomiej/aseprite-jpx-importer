# Aseprite JPX Importer

An [Aseprite extension](https://www.aseprite.org/docs/extensions/) that allows to import [JPixel](https://emad.itch.io/jpixel) projects as Aseprite projects.


# Installation

1. Download `jpx-importer.asepritex-extension` package from Releases page (not supported yet) or build project.
2. Install extension (`Edit > Preferences... > Extensions > Add extension`) and relaunch application.


# Build instruction

Run

```bash
make
```
and localise `jpx-importer.asepritex-extension` package in `build/` folder.


# How to use

1. Select `File > Import JPX file`.
2. Choose `Select file` to localise JPixel project.
3. Select `Import` to start process.

During import process, script will ask for read access.


# Limitations
An Aseprite project is represented by matrix of layers and frames with cels as matrix cells, where in a JPixel project each frame can be treated as an individual stack of layers (images) with own naming and visibility setting.

To avoid confclits, two methods of import are provided:
- import successive frames as stack of cels:
  - pros: simple matrix of cells,
  - cons: information about names and visibility is lost;
- import layers at same stack position as Layer Group (not supported yet):
  - pros: names and visibility of layers are imported,
  - cons: more complex structure of project.


Currently, following features of JPixel projects are not supported:
- palette;
- tileset;
- background image;
- layer names and visibility.