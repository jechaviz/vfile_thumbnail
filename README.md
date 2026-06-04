# vfile_thumbnail

Pure V thumbnail and web image variant generation for document files.

This library mirrors Teedy's image variant sizing:

- `web`: max 1280 px
- `thumb`: max 256 px
- generated image variants are JPEG
- non-renderable files can use PNG placeholders

It is intentionally separate from `vfile_preview`, which only models preview UI
metadata, and from `vdoc_extract`, which extracts searchable text.
