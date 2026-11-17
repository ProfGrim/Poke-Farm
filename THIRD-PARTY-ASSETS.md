# Third-party assets

## Stylized Nature MegaKit

The ranch meadow and baked biome scene use selected geometry from **Stylized Nature MegaKit** by
**Quaternius**. The selected meshes are read from the ranch landscape and baked into
`map/biome_world.scn`; therefore the resulting scene contains adapted copies of that geometry rather than
external file references.

Confirmed source mesh names include:

- `CommonTree_3`
- `Birch_2`
- `Pine_2`
- `Fern_1`
- `Grass_Common_Short`
- `Flower_3_Group`
- `Bush_Long_1`

These are source-pack names recorded during landscape assembly. Godot's baked scene does not preserve those
original asset names, so searching `map/biome_world.scn` for them is not a useful provenance check.

License: **Creative Commons Zero v1.0 Universal (CC0 1.0)**.

Official sources:

- https://quaternius.com/packs/stylizednaturemegakit.html
- https://quaternius.itch.io/stylized-nature-megakit
- https://store.godotengine.org/asset/quaternius/stylized-nature-megakit/
- https://creativecommons.org/publicdomain/zero/1.0/

Quaternius states that the pack is free to use in personal, educational, and commercial projects. CC0 does
not require attribution, but this project credits the creator so the asset's origin remains clear.

## Free Fantasy Music Pack

The ranch's day/night soundtrack uses all ten tracks from **Free Fantasy Music Pack** by
**Donát Baracsi**:

- `Always`
- `Falling leaves`
- `Falling to silence`
- `Flower field`
- `Forever`
- `Living forest`
- `Returning home`
- `Under a sycamore`
- `Wandering soul`
- `Where the wind blows us`

The creator describes the pack as YouTube-safe and licensed for use without copyright claims or required
attribution, while requesting that projects credit Donát Baracsi or his YouTube channel when possible. This
project provides that requested credit here. The music remains the creator's work and is included only as
part of the game; do not redistribute the audio files as a standalone music pack.

Official source and terms:

- https://donat-baracsi.itch.io/free-fantasy-music-pack

## PKHeX.Core

The optional Windows **Save Reader** uses **PKHeX.Core** by Kurt (kwsch) to read supported Pokémon save
formats. PKHeX is licensed under the **GNU General Public License, version 3 (GPL-3.0)**.

Official source and license:

- https://github.com/kwsch/PKHeX
- https://github.com/kwsch/PKHeX/blob/master/LICENSE

Windows packages that include `Save Reader/PKHeX.Core.dll` must also include the GPL-3.0 license and make
the corresponding PKHeX source available as required by that license. The Save Reader is a separate helper
program launched by Poke-Farm; Poke-Farm itself does not incorporate PKHeX code into the Godot executable.

## Pokemon-related assets

Pokemon and related names and characters belong to their respective owners. The project is fan-made,
non-commercial, and is not affiliated with or endorsed by Nintendo, Game Freak, Creatures Inc., or The
Pokemon Company. See the main README for the model-catalog notice.
