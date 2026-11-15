# Save behavior

Version 19 stores four categories of game state, plus the format version:

- **Resources:** current inventory amounts.
- **Buildings:** type, position, direction, health, cargo, ammo, input buffers, original construction costs, links and roles, shields, booster supplies, and durable nuclear reserves.
- **Tech:** researched technology IDs.
- **Progress:** the current core position and the next wave to defend. Saving during a wave records that same wave for replay.

The compressed, checksummed payload has the keys `version`, `resources`, `buildings`, `tech`, and `progress`. The existing runtime array used by the history browser and preview renderer is reconstructed from this payload and is not written to disk.

## Loading

Loading pauses at the saved core with a fresh preparation timer. Interrupted combat restarts from the beginning of its wave when the player launches it; individual enemies, spawn queues, projectiles, radiation patches, and charging attacks are not restored. Resource amounts are the amounts at the moment of saving.

Captured core buildings and the authored spawn order determine converted gates and the active frontier. The saved wave determines completed waves at that frontier. Fog and navigation rebuild from the world, and the camera centers on the current core at 100 percent zoom.

Building maximum health and placement counts are derived from building types and research. Construction ghosts become active because no combat is loaded. Visual flashes, targeting, firing cooldowns, conveyor travel animations, temporary buffs, and simulation counters reset. Stored cargo, ammunition, fuel reserves, and applicable heat and shield reserves remain part of the buildings.

Tutorial and discovery state derive from resources, buildings, researched tech, and core/wave progress. Existing `tutorial.learned` files are ignored and no new tutorial-history file is written. Debug flags and accelerated speed are not restored.

## Compatibility

Older checkpoint arrays are migrated and projected into the same four-category model. Existing history browsing, previews, checksums, quick slots, expedition links, and branching continue to work. History filenames and slot reference files remain UI metadata rather than additional gameplay state.

Retired plutonium structures and technologies are skipped. Old phase barriers recover their underlying belts, and plutonium above a reduced buffer capacity returns to inventory.
