# Emberworks - Frontier

A native Godot factory-defense prototype with original SVG graphics, mining, conveyors, research, colored weapons, and an expanding frontier.

Open `project.godot` in Godot 4.3 or newer and press **F5**, or run:

```powershell
.\Godot_v4.7.2-stable_win64.exe --path .
```

## Tutorial and editable level

A new game starts with one core, no resources, and only **Press and hold on an ore deposit.** visible. The first mined resource reveals inventory; five copper reveals Structures and the Extractor. Tutorial prompts glow yellow at the upper center. The menu and newly introduced building glow across their backgrounds until clicked. Extractors use the normal five-copper base price (with inflation), or iron when copper is insufficient. Belts stay at one copper until an extractor connects to the core for the first time; disconnecting it does not restore the discount.

Building an extractor unlocks Belt while leaving the extractor selected. Structures and Belt only glow when the remaining guided route is affordable. If copper is insufficient to complete the remaining guided connection, the prompt says **Right click to deselect** while construction is selected, or **Mine some more ore.** after deselecting The same recovery applies if the designated extractor must be rebuilt. It remains until the next required building or remaining path is affordable. Select Belt to see a short, ore-avoiding route to the core, with **Drag** marking its start. Connecting an extractor to the core unlocks Solar turret; its suggested tile is eight tiles right of the core and glows only while Solar is selected. Wrong placements glow red and keep demolition guidance active before the first wave until unwanted structures are removed. Leaving demolition returns to the unfinished construction or mining step. Enter Demolish with X, remove unwanted buildings, then exit with X or right-click; if there is nothing unwanted left, the instruction is **Presss X to leave demolish mode.** A correct intro does not require demolition. Turrets are accepted anywhere within the build area. The designated extractor, belt path and any placed turret must all exist before the minimap, timer, Start and speed controls become available. Removing a designated structure before the first wave returns to its rebuilding step. Pause appears after the first wave is defeated. The Start button glows until pressed for the first time. Demolition is available with X; holding Z clears conveyor cargo under the mouse. Blueprints remain available with C or middle-drag, without a toolbar button. Defeating the first wave shows **Press space to pause and build.** Resuming before the Alt-info tutorial is finished shows **Press space to pause** again. After the first wave is completed, players who have paused see **Mouse over the scraps to collect.** only while scrap is present. Scrap piles pulse with a yellow glow while this instruction is visible. Scrap collection remains active while paused. Starting wave five while unpaused shows **Press E to speed up time.** until speed has been toggled. **Wait for enough copper extraction.** only appears after selecting an unaffordable Solar turret.

Collecting the first 3 scrap after pausing reveals the glowing Tech tree button. Its first upgrade, **Barriers**, costs **3 scrap + 20 copper**, including salvage from three small tanks, and glows until purchased. Unlocking it divides Structures into **Infrastructure** and **Defence**. Both category buttons glow after closing the tree until each has been visited. The second layer offers **Conveyor speed** for **5 scrap + 25 copper**, doubling belt throughput, and **Solar turret range** for **7 scrap + 30 copper**, adding two tiles to Solar only. Belts are darker gray before the speed upgrade and use the original colors afterward. Closing the tree then shows **Hold alt while mousing over something for info.** until the player views info while paused for two cumulative seconds or inspects three different things. That becomes **Press space to unpause** until the player resumes, completing the pause lesson. Only researched upgrades and their immediately available successors are visible. Researched nodes hide their prices. The tech window inventory and price icons only show discovered minerals; undiscovered requirements say **DISCOVER MATERIALS**. Construction is limited to a **20-tile radius** around any core, including every tile of larger buildings.

**Shift+P** skips the tutorial and unlocks the three starters. Press it again to unlock all research. This grants no resources and does not start the timer. **Shift+Z+L** fills every resource to 10,000 and sets capacity to exactly 10,000. All debug shortcuts are disabled in HTML5/WebAssembly builds.

Open **scenes/sector.tscn** in Godot to paint **RockWalls** and **OreDeposits**, which are separate TileMapLayers. Ore tiles provide copper, iron, or verdite through their resource metadata. Ground is also a saved TileMapLayer. Move **CoreSpawn** to choose the initial core position. Keep tiles within the 112 by 80 grid. The main scene instances this editable sector; playing never generates or overwrites terrain. The one-time authoring helper refuses to overwrite an existing sector.
## Factory and placement

Click **Structures**, or **Infrastructure / Defence** after researching Barriers, at the bottom to open a compact, animated tray above it. Locked designs are hidden from build menus; the original category buttons remain available in code for later use. Unaffordable buildings have a translucent black overlay and red prices. Attempts to construct them show floating red text naming the missing resources. **Tech tree** is on the left; clearing and demolition use keyboard shortcuts without toolbar buttons. Toolbar buttons use icons, with Alt-hover mouse popups showing their names, one-sentence descriptions, and shortcuts. Start is the only text button in the bottom toolbar.

- Extractors mine copper, iron and green **verdite**, and distribute ore equally among all adjacent outgoing conveyors, waiting when the next output is blocked. They have no placement rotation. With construction deselected, hold left-click on a visible, uncovered ore tile to gather one item per real second. Manual mining pauses with the game and respects storage caps.
- Belts start at **1 copper**. Conveyors transport **one item per second** (32 pixels per second). Arrows use the same speed and loop seamlessly across tiles and corners. Dragging turns belts automatically. Isolated neighboring belts auto-connect. Clicking an existing belt and dragging redirects its output and connects to a neighboring belt, preserving that neighbor's output. It rejects a neighbor already feeding into the source to prevent a two-belt loop. Automatic direction changes are limited to belts being placed in the current drag, preserving older routes. A new belt uses an adjacent extractor as input whenever no conveyor feeds it; multiple incoming conveyors display a straight piece. Older receivers are not reversed when a new placement drag changes direction. Straight and corner art have matching ports that meet at tile boundaries. **Shift** locks the drag to its first direction.
- Drag across an existing perpendicular conveyor to create a tunnel without disturbing it. Endpoints must be straight and at most **10 tiles apart**. Hover either endpoint to see the translucent white dotted connection; removing either removes both.
- The **Splitter** accepts any transported material and distributes it round-robin to adjacent outgoing conveyors. Belts pointing back into the splitter are inputs. It waits for the next selected output when blocked, preserving equal distribution; its indicator rotates after each item.
- **Hold Z / Clear conveyor** removes cargo under the pointer without changing the selected tool.
- **X** toggles Demolish mode; click or drag to remove buildings. **Delete** removes the hovered structure only in Demolish mode. Right-click cancels construction or the current tool, closes the structure tray, and never destroys buildings. Demolition adds a brief sprite collapse, debris, a crisp dismantling sound, and floating refund icons. Alt-hover previews the exact refund. Refunds are **10% of the actual construction materials paid, rounded down**. Core buildings are protected from player demolition.
- **Middle-click and drag**, or **C / Blueprint**, lets you drag a selection box around whole buildings, then repeatedly stamp the layout with a ghost preview. It preserves directions, complete tunnel pairs, and turret colors. Copies have normal construction costs. Copied turrets start with a fresh full magazine; stored crafting inputs are not duplicated. Invalid placements are rejected atomically. **Right-click cancels blueprint mode** without demolition.
- Repeated placements increase that building's price by **10%**, **5% for barriers**, or **1% for conveyors**, compounded and rounded to whole items. Prices are tied to the number of each building currently owned. Starting a wave never resets them, and removing a building lowers its type's price by one owned building. Blueprint quotes include repeated placements inside the same stamp.

The HUD uses black backgrounds with one-pixel tan outlines and no outer screen margins. Inventory is a vertical list at the left edge, showing only materials previously collected. The bottom bar spans the viewport. Building and research descriptions are omitted; Alt-hover popups explain actions and structures with eight-pixel padding, live stats, and a sentence describing their function. Popups fade in quickly above the rest of the interface. Stats use small icons, with colored warnings for damage, empty ammunition, and blocked outputs. Numeric stats omit redundant decimal zeros; turret popups include DPS, omit ammo for ammo-free towers, and show unlocked colors as colored dots. Enemy popups include live health, damage, DPS, range, speed and salvage; Alt-hover also draws their attack radius. Demolish mode glows red around the screen edges and uses a red filled cursor tile with a solid outline. Pausing adds a cyan screen-edge glow half the width of demolition glow and a faint world-aligned grid across the visible screen under the GUI. Both glows wrap around the exposed edges of GUI panels; both remain distinguishable when demolishing while paused. Building buttons have eight-pixel inner padding, lift on hover, recess when pressed, and highlight the active selection. Toggled controls use colored backgrounds. The speed button always uses double arrows. Introduced shortcuts appear as a small white list above the bottom-right controls, without a background. Once Alt is introduced, this becomes **Hold alt for info** unless Alt is held. Hovering previews material deductions at the top. Resource counts roll toward their actual value, grouped gains pulse the icon, and thin bars show capacity.

## Production and support

Research the **2 x 2 repair-alloy forge**. Feed it **2 copper + 2 iron** to produce **1 repair alloy every 3 seconds**. Inputs can enter any edge tile; **R** rotates its output.

The healing beacon requires repair alloy to research, construct, and operate. Supply **verdite + repair alloy**; each one-second pulse consumes one of each and heals **1% of maximum health** on every damaged building within a **two-tile circular radius**. Beacon supplies can be loaded during active waves; an already fueled beacon can keep healing between waves.

The five storage buildings each add **500 capacity** to their corresponding resource. Starting capacity is **40 copper** and **500 of each other material**. Full cores stop accepting that material, applying back pressure to belts. Removing storage enforces the reduced capacity. Storage construction requires scrap as well as other materials.

## Waves, affinity and salvage

The timer stays stopped until **Start** is pressed. Subsequent waves start after a **40-second countdown**, or early with the next-wave button. A large off-white MM:SS timer sits directly below the minimap, without a panel or border and with a surrounding black text shadow. Between waves, Start reads **Start Early**. **Space** or the pause/resume icon freezes simulation, enemies, towers, conveyors and the countdown, while construction, demolition and blueprint placement remain available. Ammo-fed turrets begin with a full 80-round magazine, including blueprint copies. Solar turrets require no ammunition and fire 3-damage shots every 0.6 seconds (**5 DPS**) within **3 tiles**. Small tanks cost **1 credit**, drop **1 scrap**, and have **36 base health** with tripled health growth. Heavy tanks cost **8 credits**, drop **8 scrap**, and have exactly **8 times** small-tank health at every wave. Spawn budgets and wave progression follow the level-authored spawner values. After that, ammunition can only arrive by conveyor; **E never reloads turrets**. Ammo is shown in a full-width, three-pixel bar flush inside the sprite bottom.

Turret affinities are researched separately for each turret type. Solar starts with red only. A turret with one unlocked color places directly; multiple colors open a radial picker with three equal 120-degree slices. Drag beyond the inner dead zone in the desired direction, even beyond the outer circle, and release. Locked slices cannot be selected; releasing without a color cancels placement. Copper turret and copper repeater use copper; iron cannon uses iron.

**Red beats green; green beats blue; blue beats red.** Turrets deal **200%** against their strong color, **100%** against the same color, and **50%** against their weak color. Wave colors come from the spawner's allowed palette. Seven enemy types include scouts, heavies, runners, skirmishers, bulwarks, siege crawlers and field menders. Enemies turn smoothly, wind up, accelerate and brake.

Each enemy costs credits. Wave planning first buys as many of the highest-cost eligible enemy as its budget allows, then spends the remainder randomly on cheaper enemies. Composition, color and spawn positions use a dedicated generator seeded with the **global wave number**, unaffected by combat or particle randomness. Small and heavy tanks have explicit scrap rewards of one and eight; other enemies leave **three scrap per spawn credit**. Moving the pointer within **two tiles** attracts scrap toward it and deposits it into storage on arrival. Full scrap storage leaves excess salvage on the ground.

## Configure the expedition

Select a child of **EnemySpawns** in `scenes/main.tscn`. Its exported inspector settings include:

| Setting | Purpose |
| --- | --- |
| `Order` | Lowest unconverted order activates first; matching orders activate together. |
| `waves_before_conversion` | Completed waves before the spawn becomes a new core. |
| `credits_per_wave` | Budget for each local wave; the final entry repeats if needed. |
| `possible_colors` | Default allowed red/green/blue palette. |
| `wave_color_palettes` | Optional allowed palette for each individual local wave. |
| `allowed_enemies` | Types available to that spawner, also gated by global-wave unlock level. |

Clearing a gate turns it into a core and activates the next order. The expedition has three gates with individually configured wave counts. Clear every gate to win. All cores share inventory and capacity. Losing a core ends the expedition.

Fog reveals a **20-tile radius around each core** and a **20-tile-wide corridor between the current core and active enemy spawns**. Future gates and their terrain remain hidden. Construction respects fog. The minimap follows the same visibility.

Enemy stats, unlock levels, and credit costs live in `scripts/content.gd`. The root game node exposes base material capacity and countdown durations in the inspector.

## Controls

| Control | Action |
| --- | --- |
| 1 / 2 / 3 / 4 | Belt / extractor / solar turret / barrier, when unlocked |
| Left click / drag | Place, inspect, or paint with the selected tool |
| Turret click, drag, release | Pick a turret affinity color |
| R | Rotate before placing |
| Shift while dragging belts | Lock to the first direction |
| Right click | Cancel selected construction or the current tool; never demolish |
| Z / X / C | Hold to clear conveyor / Demolish / Blueprint |
| Delete | Demolish hovered building, only in Demolish mode |
| E | Toggle x1 / x3 speed |
| T | Open tech tree |
| M | Mute/unmute generated sound effects |
| Alt + hover | Show building stats or action information |
| Space | Pause/resume; building tools keep working |
| WASD / arrows | Pan camera |
| Middle click + drag | Select a blueprint box, then left-click to stamp |
| Wheel | Zoom |
| F | Return to the current core |
| Click minimap | Move camera |
| Q | Start the next wave early |
| Escape | Close research or clear the current tool |

## Sound

Fourteen original generated WAV effects cover UI hover/click, construction, demolition, errors, gunfire, cannon fire, explosions, healing, research, wave alerts, gate conversion and defeat. Conveyor resource delivery is silent; manual mining and scrap collection play a short collection sound. Positional effects use a bounded voice pool and rate limiting. Use the speaker icon or **M** to mute/unmute. WAV files are in `assets/audio/`; regenerate them with:

```powershell
.\Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/generate_audio.gd
```

## Wave saves

Completing each wave writes a compact binary snapshot into the Godot user-data directory. Buildings use positional field arrays rather than repeated property names; static terrain, textures, UI, and temporary effects are omitted. Each snapshot uses whichever of Zstandard, Deflate, or Gzip produces the smallest result, plus a small versioned header and corruption checksum. Writes use a temporary file followed by an atomic rename.

Two icon buttons immediately left of Start return one checkpoint or open the complete save browser. Newest saves appear first. The timeline starts at the latest save on the right; dragging left selects and scrolls backward in time. Each row has a compressed screenshot of the revealed area around its core and a fixed elapsed-time label, such as **1h 2m ago**, with no seconds counter. Saves under a minute old say **Just now**. Ages are captured when the browser opens and do not update while it remains open. List rows highlight on hover without changing their positions. Dying opens the browser with **You Died** and **But it's not the end, our chronotech can turn back time.** The browser has Cancel and Confirm; restoring asks **Return to wave start** / **Are you sure you want to roll back time?** and immediately pauses the game. Later checkpoints remain available while paused. Resuming deletes future checkpoints and continues a new branch. Relaunching offers to continue the saved expedition, paused, or start a new expedition.

`tests/inspection_flow.gd` adds 37 checks for pre-wave rebuild recovery, repeatable cleanup guidance, persistent pause/Alt/unpause instructions, progressive shortcuts, enemy hover range, scrap glow, discovered-only research materials, hidden researched prices, and save continuity. `tests/inspection_capture.gd` captures those states. `tests/designated_tutorial.gd` adds 54 checks for designated-area rebuilding, demolition onboarding, staged controls, protected existing belts, ownership pricing, research layers, tank costs and health, greedy seeded spawning, collection audio, frozen save ages, and the paused grid. `tests/designated_capture.gd` captures the tutorial, grid and research states. `tests/chronotech.gd` adds 49 checks for affordable tutorial guidance, extractor input priority, second-belt reversal, tripled tank health, feedback, thumbnails, stable save rows, relative ages, death rollback, and minimap zoom. `tests/chrono_capture.gd` captures the resulting interface and feedback. `tests/scrap_progression.gd` adds 50 checks for mining recovery, belt auto-connection and redirection, clean stats, color dots, enemy info, scrap research, split categories, GUI-aware glow, save continuity, and six simulated combat matchups. `tests/scrap_capture.gd` captures the updated tutorial and interface. `tests/alt_info.gd` adds 41 checks for starter construction and discounted tutorial belts, resource caps, safe demolition, Alt-only popups, padding, stats, damage/pause/info prompts, and migration of older saves. `tests/alt_capture.gd` captures these visual states. `tests/wave_saves.gd` verifies checkpoint round trips, disk persistence, compression, restore confirmation, branching, corruption handling, extractor distribution, color research, radial geometry, hover popups, shortcuts, and tutorial changes. `tests/update_capture.gd` captures the toolbar, save browser, timeline, confirmation dialog, and radial picker.
## Source and validation

Artwork is editable SVG under `assets/`. No external assets or dependencies are required. `game.gd` owns simulation and placement; `content.gd` defines catalogs; `enemy_spawn.gd` configures gates; `hud.gd`, `affinity_picker.gd`, `minimap.gd`, and `fog.gd` handle presentation.

```powershell
.\Godot_v4.7.2-stable_win64.exe --headless --path . --script tests/simulation.gd
```

`tests/tutorial.gd` adds 78 checks for onboarding, painted-level round trips, UI gates, research visibility, solar combat, building radius, and desktop/web debug behavior. `tests/tutorial_capture.gd` captures each tutorial and initial research stage. The simulation suite covers transport and placement tools, research, crafting, healing, all affinity matchups, deterministic credit waves, gate progression, fog geometry, inflation, storage, scrap, and paused construction. `tests/logistics_update.gd` checks middle-drag blueprints, full magazines, conveyor-only reloads, ammo-bar geometry, fair splitter distribution, occupied-tile turns, and full-width framed HUD bars. `tests/control_input.gd` checks right-click selection cancellation, the X shortcut, and manual mining. `tests/ui_feedback.gd` adds asynchronous interface and audio checks (run with `--headless --audio-driver Dummy`). `tests/capture.gd` captures the native interface, categories, research, radial picker, tunnels, blueprint previews, combat, storage, and the next frontier.

Multiplayer and player-controlled units are not implemented.










Extractors produce one item per second. Conveyor handoffs resolve simultaneously so a full-rate line keeps moving regardless of placement order. Attack ranges round to whole tiles. Tech cards show stat changes above costs, and each known resource price is white when affordable or red when lacking. Rollbacks retain completed tutorial learning. The death timeline must load a checkpoint before it can close; normal browsing uses Cancel.



Enemies path around barriers toward reachable non-conveyor buildings; barriers become movement objectives only when no other structure is reachable. Nearby barriers and conveyors remain valid shooting targets. Conveyor SVGs automatically show T and cross junctions for their incoming connections, including in checkpoint thumbnails. The unpause instruction waits for Alt inspection and both Infrastructure/Defence category glows to finish. Death rewind hides Cancel and loads directly without a second confirmation. Heavy tanks retain 33% of their previous wave-scaled health, rounded down to tens, and fire for 15 damage once per second.


Demolish closes the building tray and deselects the current structure. Button shortcuts appear as small labels: S starts the next wave, T opens research, and 1–9 opens categories or selects buildings sequentially from the open tray. S is reserved for waves; use Down to pan down. Minimap left-drag moves the camera. Research keeps the simulation paused until it closes. The minimap timer shows Next Wave below it and begins counting down once the final enemy spawns; defeating the wave retains the remaining countdown. Construction checks every footprint tile against a core's twenty-tile radius.

Enemies prefer non-barrier, non-conveyor shooting targets in range. Building creation and removal immediately rebuild navigation and invalidate cached enemy routes. Weighted pathfinding favors routes outside turret ranges, with overlap increasing danger cost. Copper Storage follows Conveyor Speed: research costs 15 scrap and 35 copper; a Copper silo starts at 10 scrap and adds 50 copper capacity. T/cross conveyor rails meet straight and corner pieces at the same SVG port coordinates.


Current research branches are Barriers, Conveyor Speed, Solar Turret Range, Copper Storage, Auto Pickup Scraps, and Build Menu Hotkeys. Other research nodes remain in the catalog for later use but are hidden. All required materials are shown on tech prices, even before discovery. Auto Pickup Scraps follows Conveyor Speed for 30 scrap / 50 copper; Build Menu Hotkeys follows Turret Range for 50 scrap / 70 copper and enables numbered category/building selection. Copper silos add 50 capacity each. A middle click without dragging selects the structure beneath it and opens its building category.

Waves may overlap: the next wave can start after the current spawn queue finishes while earlier enemies remain. The interval is 120 seconds. Each wave keeps its own identity and completion checkpoint; version 7 checkpoints preserve active enemies, queues and pending waves and migrate older checkpoints. Overlapping waves advance authored budgets and color palettes normally. Fresh scraps wait two seconds before pickup, and Auto Pickup then attracts visible scraps from beyond the normal mouse radius. Enemies commit to the nearest turret when it is the nearest non-barrier/non-conveyor structure, even when reaching it requires entering turret coverage.


Runners ignore turrets as movement and shooting targets and use routes without turret-danger penalties. Each Enemy Spawn now exposes Wave Enemy Lists: entry 0 is its first local wave; empty/missing entries fall back to Allowed Enemies. Explicit nonempty wave lists can introduce an enemy before its usual unlock wave, provided the credit budget can afford it. Wave-specific lists remain seeded and use the same authored budget schedule, including overlapping waves.

Normal two-tile mouse-hover scrap pickup remains immediate both before and after Auto Pickup research. The two-second ground delay applies only to automatic attraction outside the hover radius. Loading a checkpoint plays the original descending rewind sound and a 0.48-second reverse-motion overlay; the simulation remains paused. The timeline includes clickable cyan core-capture markers and orange research markers, matching row summaries and an icon legend. Marker details use Alt-hover like other info popups and are derived from existing checkpoints without enlarging save files.


Turret prices compound by 25% per additional owned turret of the same type within the applicable core range. Demolition refunds 100% of the actual scrap paid and 10% of other materials. Enemy cannon SVGs rotate independently of their hulls and lerp toward their next shooting target. Barriers block enemy firing lines; the blocking barrier can still be targeted. Heavy tanks have four tiles of attack range.

Revealed UI and split Infrastructure/Defence categories persist through rewinding to early waves. Version 8 checkpoints migrate earlier saves and retain player knowledge while restoring world research and resources. Alt-hovering an enemy spawn shows the next wave's budget, enemy counts, total health and colors. Forecasts and actual spawning share the same pure seeded planner. Save rows show icon x amount summaries for non-turret buildings (including cores, excluding belts/barriers), turrets, unlocked techs and next-wave enemies. Summary layouts support multiple icon rows and timeline scrolling follows actual row positions.


Prices are local to each core's twenty-tile range. Overlaps use the newest core covering the placement tile; GUI prices use the core covering the camera center, while ghost prices always use the actual placement. Blueprints quote sequential local inflation across every affected core range. Turrets can replace barriers, dismantling the barrier with its normal refund. Unaffordable structures remain selectable without menu-click errors. Out-of-range placement shows Too far away...; red feedback lasts 2.2 seconds and drifts more slowly. Ghost previews show small material icons and prices beneath the building.

Enemy Spawn has a Turns Into Core toggle. A cleared spawn advances the frontier either way, but creates a core only when enabled. The newest created core is the active main core; inactive cores render red and enemies ignore them. The first new core introduces WASD to move camera / Move Right, then This is your next core to defend once seven tiles inside the horizontal viewport edges. Moving away temporarily shows Find your next core. The first building placed in that core's radius finishes this lesson. Core creation no longer automatically moves the camera. S pans down.

Q and the Start button request a two-second time warp instead of immediately starting the next wave. Simulation speed lerps from the chosen x1/x3 speed up to x10 and back, with fixed-size simulation steps; the next wave starts at the end. Pause suspends the warp and loading cancels it. Wave announcements are large Wave N labels above the bottom GUI, without leading zeros or the old incoming-wave notice under inventory.

Enemy navigation now chooses reachable firing positions, not only building centers. Enemies keep moving until a non-barrier/non-belt objective is within range and has an unobstructed shot. Both barriers and authored rock-wall tiles block firing lines, including corner crossings. Version 9 saves include the frontier lesson. A compact per-expedition tutorial.learned sidecar stores permanent tutorial completion, revealed controls, split categories and tutorial Barrier unlocks, so older checkpoints and reopened sessions cannot restart completed lessons. Ordinary world resources and non-tutorial research still rewind.

