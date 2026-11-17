# Poke-Farm Save Reader source

This source and the resulting `Inventory.exe` helper are licensed under **GPL-3.0-only**. This is the separate
helper distributed with the Windows build. It reads a
save locally and writes the inventory as JSON; it does not edit or upload the save.

The helper links to **PKHeX.Core 24.3.26.0**, built from PKHeX commit
[`c95d56bfd6a0299ffd6aa9baf2aa11ecb675af46`](https://github.com/kwsch/PKHeX/commit/c95d56bfd6a0299ffd6aa9baf2aa11ecb675af46).
PKHeX is GPL-3.0 licensed. Its complete corresponding source is available from that link and the repository
archive for that commit. Place the matching `PKHeX.Core.dll` beside this project before building with .NET 9.

The GPL-3.0 license text is included as `LICENSE-PKHEX.txt` in source and binary distributions.
