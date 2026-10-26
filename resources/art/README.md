# Original pixel art

Every pixel is drawn by this repository's own text/code. No external images,
image-generation models, traced art, or code copied from another project are used.
The source files are authoritative; the committed PNGs are deterministic exports.

## Build and inspect

From the repository root, with Node.js:

```sh
node tools/resources/art.mjs build
node tools/resources/art.mjs verify
node tools/resources/art.mjs sheet
node --test tests/art.test.mjs
```

No dependencies or engine installation are needed. `lib/png.mjs` is an original
RGBA8 PNG codec using Node's built-in zlib. Encoding uses filter 0, fixed Huffman
blocks, and no timestamps or metadata. Decoding validates chunk CRCs and supports
all five PNG row filters. `lib/pixel.mjs` provides integer drawing, clipping,
character frames, palette-safe recoloring, and nearest-neighbor stamps.

`verify` redraws every source and compares all PNG and manifest bytes. It validates
palette colors, binary alpha, frame dimensions, anchors, animation references and
hashes; checks explicit art references in content JSON (`art_ids` in D0); and warns
about unreferenced assets. It never writes exports. A missing `content/` or `godot/`
is allowed so this directory and the CLI can be extracted as a standalone pipeline.
The review labels are an original tiny alphabet used only on contact sheets, never
for game text.

## Palette

`palette.json` contains the **exact 47 named RGB colors** in
`docs/art/art-direction.md`, a unique character symbol per color, and three complete
47-entry remaps. `.` is transparent, with zero RGB. Every visible pixel has alpha
255; no intermediate alpha is permitted.

- `dream`: night and silver bands, grouped by luminance.
- `dark_slot`: darker, cool night-band mapping.
- `ghost`: gold bands; any runtime translucency belongs to the engine.

## Asset index

| ID | Source | Frame size | Anchor | Frames | Usage |
|---|---|---|---|---|---|
| `char.cupper` | `source/char/cupper.json` | 24×32 | [12,31] | 4 | Original hovering cup magician; half porcelain smile mask, two inverted brass cups, velvet coat with gold trim. Idle at 4 fps with held poses, ±1-pixel bob and a blink. |
| `stage.frame` | `source/stage/frame.mjs` | 640×360 | [0,0] | 1 | Original wooden proscenium, velvet scallops and tied curtains, gold trim, warm footlights, twin moons and five standing positions. |

`export/manifest.json` uses `{ "format": "art/1", "assets": [...] }`. Each entry
records `id`, `file` relative to `export/`, `size` per frame, integer `frames`,
`anchor`, `animations`, and a SHA-256 `hash`. Frames are laid out horizontally.

### Composition contract

- Title-safe region: x180–460, y70–145.
- Five floor-slot centers: x144, 232, 320, 408, 496; floor baseline near y258.
- Lower control-safe region: x116–524, y302–344.
- Artwork has no baked-in game text or buttons. Runtime text uses the project font.
- The stage is a complete opaque D0 title composition, not yet a separately layered
  backdrop/curtain system. Animation of footlights and curtains is deferred.

## Review evidence

`export/sheets/d0-contact.png` displays all four cupper frames, its silhouette,
three palette remaps and the stage at **3× nearest-neighbor scale**. The generated
sheet was opened and visually inspected: crisp edges, distinct half-mask silhouette,
readable separated cups, five clear slots, subdued scenery and clear title/control
space. Game composition and text must additionally be inspected in the Godot title
screen by the integrating task; this art-only task does not launch the GUI.
