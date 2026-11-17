# Public catalog metadata

The checked-in runtime catalogs intentionally omit synthetic save locations.

- `roster.json` does not publish its synthetic box labels or generated specimen IDs. The ranch falls back
  to a deterministic model-key/runtime-slot identity for cosmetic sleep-effect variation.
- `ranch-dex.json` retains the source game and gender provenance used by the catalog, but omits synthetic
  volume, box, and slot coordinates.
- `supplement.json` contains model identity and scale metadata only; it never contained save-slot IDs and
  is unchanged.

The full local provenance files are stored under `local-data/private-catalog/`, which is excluded from Git.
Run `tools/sanitize-public-catalog.ps1` after intentionally rebuilding the public catalogs from private
metadata.
