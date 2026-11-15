# Plutonium and the fourth core

Plutonium uses normal extractors and belts; `verdite` remains its internal save-compatible ID. Seven plutonium structures remain, all gated to core four. Each new construction and research price uses at most two materials, and the tech tree wraps at four cards per row.

| Structure | Size | HP | Range | Construction | Research | Parent |
|---|---|---|---|---|---|---|
| Reactor | 3×3 | 500 | 11×11 square | 50 iron + 12 plutonium | 80 iron + 20 plutonium | Turret Color |
| Isotope Lance | 2×2 | 250 | 9-tile radius | 40 iron + 15 plutonium | 70 iron + 20 plutonium | Reactor |
| Decay Mortar | 3×3 | 220 | 3–12-tile radius | 55 iron + 18 plutonium | 90 copper + 25 plutonium | Isotope Lance |
| Emergency Injector | 1×1 | 120 | 5×5 square | 25 copper + 6 plutonium | 45 iron + 12 plutonium | Reactor |
| Breach Beacon | 2×2 | 600 | 8-tile radius | 35 iron + 8 plutonium | 70 copper + 15 plutonium | Reactor |
| Chrono Capacitor | 2×2 | 180 | 9×9 square | 50 iron + 18 plutonium | 90 iron + 25 plutonium | Emergency Injector |
| Containment Engine | 3×3 | 400 | 10-tile radius | 90 iron + 35 plutonium | 150 iron + 50 plutonium | Decay Mortar + Chrono Capacitor |

Copper and iron retain their visible names, Chicken Nuggets and Fish Scales.

## Operating behavior

- **Reactor:** boosts working extractors and distilleries by 50%. Uses one plutonium per three active seconds and holds twenty. Reactors have no heat mechanic, and overlapping boosts never stack.
- **Isotope Lance:** fires a piercing 35-damage beam every three seconds; ten shots per plutonium. Holds ten plutonium. Shots add 25 heat; passive cooling removes five per second. Shuts down at 100 heat until below 40. Coolant is no longer required or accepted.
- **Decay Mortar:** spends one plutonium per six-second shot, dealing 15 impact damage within two tiles and leaving six seconds of radiation at five damage per second. Radiation does not stack.
- **Emergency Injector:** spends five plutonium to grant a turret below half health a 50-HP temporary shield and double fire rate for six seconds. Holds ten plutonium. Cooldown remains thirty seconds; boosts do not stack.
- **Breach Beacon:** now a laser tower, dealing one percent of the target's maximum HP per second. Retains one plutonium per fifteen active firing seconds and holds ten. It no longer lures enemies.
- **Chrono Capacitor:** targets an unslowed enemy in its square and waits one second. The countdown is canceled if that target leaves, dies, or becomes slowed elsewhere, without spending fuel. A successful pulse spends two plutonium and slows unslowed enemies in range by 40% for five seconds. Holds six plutonium. The old quiet-period charge and group-size requirement are removed; overlapping capacitors do not refresh or duplicate the same slow.
- **Containment Engine:** spends three plutonium, charges for three seconds, pulls for two seconds, and detonates for 120 damage in a three-tile radius. Cooldown remains fifteen seconds. It no longer needs coolant.

Core Lifeboat, Scrap Reclaimer, Magnetic Funnel, Coolant Pump, and Phase Barrier are removed from construction and research. Loading older saves skips retired structures and technology, preserving belts that were underneath phase barriers. Plutonium above a newly reduced buffer capacity returns to inventory.

Tooltips use one sentence followed by compact icon-led stats. Save format 19 retains only resources, durable building state, research, and core/wave progress; combat effects are rebuilt.

## Asset provenance

The current material sprite is an original faceted SVG at `assets/items/plutonium.svg`, with a scattered deposit design at `assets/terrain/plutonium.svg`. These replace the initial generated PNGs. Structure sprites are original repository-native SVGs in `assets/buildings/`; coolant is `assets/items/coolant.svg`. The refined artwork uses stepped silhouettes, beveled metal, recessed machinery, pale highlights, and layered luminous cores, and is rasterized by the existing pixel-art pipeline at each zoom density.

The initial raster concept was made with the built-in image-generation tool using this prompt; the final SVGs are authored vector artwork:

> Create one game inventory sprite: a small chunky radioactive plutonium ore crystal cluster, top down three-quarter pixel art, luminous lime-green crystalline chunks with pale yellow-green facets and very dark green edges. Match a compact factory tower-defense game's clean low-resolution sprite aesthetic. Single centered isolated object, square canvas, transparent background, no text, no symbols, no border, no shadow outside object, sharp stepped pixel contours, broad readable shapes that remain clear at 16x16 pixels. The whole object occupies about 80 percent of canvas.

## Research and build filters

Turret Color unlocks at core four after Heal Beacon and costs 20 fish scales and 10 plutonium. It unlocks red, green, and blue for every turret. Reactor and the separate Plutonium Silos technology both follow it. Plutonium Silos costs 30 fish scales and 10 plutonium; each silo retains 500 additional storage capacity.

Hidden technologies and their individual color upgrades are removed, along with Copper Repeater, Iron Cannon, Repair Alloy, its forge, and its silo. Legacy saves discard these entries safely. Plutonium Silos remains available.

Two 32-pixel HUD bars sit above the bottom toolbar. The lower bar has 64-pixel icon-only material toggles; nuggets and scales share one button. Buildings are grouped by their highest-tier construction material, with plutonium silos in the plutonium group. The upper bar provides mutually exclusive turret colors after research and shows the hovered building description on its right. All menu turrets and newly placed turrets use the selected color.

Turret colors affect selected sprite panels, coil lights, and barrel bands while preserving metal, shadows, and transparency. This applies to the build menu, placed turrets, construction/blueprint previews, and save previews. Color buttons are visible only while the Defence structure menu is open.
