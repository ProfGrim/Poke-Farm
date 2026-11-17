"""Pack models/ into a few zips that each stay well under GitHub's 2 GB release-asset limit,
and write tools/models-manifest.json (file names and SHA-256) for tools/fetch_models.ps1.

    python tools/build_model_zips.py OUTPUT_DIR
"""
import hashlib, json, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 1_200_000_000      # bytes of models per zip
RELEASE_TAG = 'models-1'

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
files = sorted(p for p in (ROOT / 'models').iterdir() if p.suffix == '.glb')
groups, cur, size = [], [], 0
for p in files:
    if cur and size + p.stat().st_size > LIMIT:
        groups.append(cur); cur, size = [], 0
    cur.append(p); size += p.stat().st_size
groups.append(cur)

manifest = {'tag': RELEASE_TAG, 'count': len(files), 'zips': []}
for i, g in enumerate(groups, 1):
    name = f'PokeFarm-models-{i}.zip'
    path = out / name
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_STORED) as z:
        for p in g:
            z.write(p, p.name)
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    manifest['zips'].append({'name': name, 'files': len(g), 'bytes': path.stat().st_size, 'sha256': h.hexdigest()})
    print(name, len(g), 'files', path.stat().st_size // 1_000_000, 'MB', flush=True)

# Runtime visual companions are release assets too: palettes/atlases and effect
# textures plus meal props. Music and the meal bell intentionally stay out of the
# repository and asset release; they are included only in packaged Windows builds.
runtime_files = sorted(
    p for pattern in ('*.png', '*.glb')
    for p in (ROOT / 'map').glob(pattern)
)
runtime_name = 'PokeFarm-runtime-assets.zip'
runtime_path = out / runtime_name
with zipfile.ZipFile(runtime_path, 'w', zipfile.ZIP_STORED) as z:
    for p in runtime_files:
        z.write(p, f'map/{p.name}')
h = hashlib.sha256()
with open(runtime_path, 'rb') as f:
    for chunk in iter(lambda: f.read(1 << 20), b''):
        h.update(chunk)
manifest['runtime'] = {
    'name': runtime_name,
    'files': len(runtime_files),
    'bytes': runtime_path.stat().st_size,
    'sha256': h.hexdigest(),
}
print(runtime_name, len(runtime_files), 'files', runtime_path.stat().st_size // 1_000_000, 'MB', flush=True)
(ROOT / 'tools' / 'models-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
