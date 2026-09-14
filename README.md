# Grow an Island

> **Map-first rebuild:** the player world is authored by hand in Roblox Studio. Code loads, validates, animates, and runs that content; it does not generate islands, terrain, buildings, or decorations.

## The direction

You build the smallest details of every island yourself: its shape, terrain, props, landmarks, underwater space, and visual upgrade stages. The AI helps with the repetitive technical work:

- loading a saved Studio template into the live world;
- making an island rise, fade in, or otherwise arrive with an authored animation;
- wiring map markers to gameplay, prompts, rewards, and save data;
- validating the map before a playtest; and
- iterating on a clearly scoped feature after you have built its visual side.

The first release of this rebuild has **one hand-built starter island/grid only**. There is no 5×5 generated grid, random biome roll, or procedurally created terrain in the target design. Future islands remain possible, but each will be a Studio-authored template, never generated geometry.

## The easy architecture

Keep your editable map safe in ServerStorage; runtime code clones it into Workspace for a play session.

**Important Studio constraint:** Roblox Terrain is a Workspace singleton. It cannot live inside WorldTemplate or be cloned from ServerStorage. For the first island, use hand-built Parts and MeshParts for anything that must load or animate; this is the recommended, lowest-friction route. If you decide to sculpt Roblox Terrain, it stays as persistent, Studio-owned Workspace.Terrain. The loader must leave it alone and clone only the model assets around it.

~~~
ServerStorage
└── GrowAnIslandMapLibrary                 [MapLibrary tag]
    ├── WorldTemplate                      [MapTemplate tag]
    │   ├── StarterIsland                  -- your complete first playable island
    │   ├── OceanAndDiveArea               -- cloneable parts/meshes, water, props
    │   ├── ProgressVisuals                -- palm / shelter / travelator variants
    │   └── MapMarkers                     -- small invisible tagged helper objects
    └── IslandTemplates                    -- empty for the one-grid milestone
        └── <FutureIsland>                 [IslandTemplate tag]

Workspace
├── Terrain                                -- optional persistent hand-sculpted terrain
└── GrowAnIslandWorld                      -- disposable runtime clone; code owns this
    ├── <clone of WorldTemplate>
    └── Runtime                            -- code-created pickups, chests, VFX, etc.
~~~

This is deliberately asymmetric:

- **You own GrowAnIslandMapLibrary and any hand-sculpted Workspace.Terrain.** Do not let runtime code delete, rebuild, or alter either.
- **The game owns Workspace.GrowAnIslandWorld.** It may delete and recreate this runtime clone whenever a server starts or the player’s progress resets. It does not own Workspace.Terrain.
- **Rojo owns the source-controlled code under src/.** The current Rojo project does not map Workspace or ServerStorage, so your Studio map remains a Studio asset instead of generated code.

Keep a backup of the place before every significant map edit: save a local .rbxl copy in a studio/ folder in this repository (create it when you make the first copy) and publish the place. A .rbxl is binary, so name snapshots clearly, for example studio/GrowAnIsland-map-v001.rbxl; do not expect Git diffs to explain map changes.

## Status of the migration

The checked-in code still contains the legacy runtime WorldBuilder, which currently creates the ocean, tiles, props, and upgrade sites. This README defines the approved replacement design; the code migration is a separate next task.

Until that migration is implemented, Studio templates and the legacy builder are not connected. Do not delete the legacy system just because the template exists. The safe implementation order is in [the build guide](#bonus-first-island-build-guide).

## Map contract

Your visual models can be named however you like. Gameplay discovers the few functional objects below by **CollectionService tags and attributes**, never by Explorer paths or visual names. Tags and attributes are saved with the place, and can be set directly in Studio’s Properties window.

| Tag | Put it on | Required attributes | What it means |
| --- | --- | --- | --- |
| MapLibrary | The GrowAnIslandMapLibrary folder | — | The one protected source library in ServerStorage. |
| MapTemplate | The root, cloneable WorldTemplate model | MapVersion (number) | The complete starter-world model content to clone; it cannot contain Workspace.Terrain. |
| MapSpawn | Anchored part or attachment | SpawnId (string), ShelterLevel (number) | A safe respawn position for that progress stage. Start with SpawnId = Starter and ShelterLevel = 0. |
| InteractionTarget | The visible part/model a player uses | ActionId (string), optional ObjectId (string) | A server-wired interaction such as selling or buying an upgrade. |
| CoconutDropZone | Anchored, invisible, non-colliding part | — | A rectangle inside which hand-collected coconuts may land. |
| TravelatorStart / TravelatorEnd | Attachments or small anchored parts | — | The exact authored path endpoints for auto-sold coconuts. |
| ChestSpawn | Attachment or small anchored part | SpawnId (string) | A permitted treasure-chest location. |
| DiveZone | Anchored, invisible, non-colliding volume part | — | The water volume in which oxygen drains. |
| WaterSurface | Anchored, invisible, non-colliding part | — | Its Y position is the authored waterline. |
| ProgressVariant | A model or folder containing one visual state | FeatureId (string), Stage (number) | An authored upgrade appearance; code only shows the applicable state. |
| RuntimeContainer | A folder | RuntimeKind (string) | A safe parent for code-spawned objects such as Pickups, Chests, or VFX. |
| IslandTemplate | A future cloneable island model in IslandTemplates | IslandId (string), RevealStyle (string), RevealDuration (number), RevealOffset (Vector3) | A hand-built Parts/MeshParts island that code may clone and animate. Not needed for the first grid. |

ActionId values are a small allowlist, not free text: BuyCoconutPalm, BuyTravelator, UpgradeShelter, UpgradeOxygen, SellCoconuts, MoveCoconuts, and RequestRebirth. If we introduce an action, we add it to PROJECT_STACK.md and server validation in the same change.

For an upgrade feature, build every visual state in ProgressVisuals yourself. Example: make a CoconutPalm stage 0 model for the build site and stage 1 model for the grown palm. The future map service will select and optionally tween between those existing models; it must not synthesize palm parts.

## What to install and use

| Tool | Decision | Why |
| --- | --- | --- |
| **Roblox Studio Assistant** | Use now — it is built into Studio, not a plugin. | It can inspect the open place, edit instances, and generate or modify scripts. Give it exact names and constraints. |
| **Studio MCP server** | Use when you want an AI coding agent to operate your open Studio session. | Roblox’s official workflow lets an MCP-enabled agent read the data model, edit instances/scripts, and playtest. Enable it in Assistant → … → Manage MCP Servers → **Enable Studio as MCP server**. Connection availability is per session; never assume an agent is connected. |
| **Rojo 7** | Keep installed; this project already uses Rojo/Rokit/Wally. | It syncs the source-controlled code in this repository to Studio. It is not a map generator. Install only the official Rojo Foundation plugin. |
| **Moon Animator 2** | Optional later, only for character/NPC/cutscene animation. | It is a polished timeline tool, but it will not create island-arrival logic or make an AI understand your map. Skip it for the first island. |
| **Terrain Editor + Studio Tags/Attributes** | Use now — both are built into Studio. | They are the right tools for hand-sculpted terrain and the small functional contract above; no tag plugin is necessary. |

Do **not** install a random AI world builder or free-model plugin for this workflow. It cannot know your game’s rules, often has no relationship to your saved map template, and may insert scripts you did not ask for. Install Creator Store plugins only from their identifiable creator page, then inspect what they add before saving the place.

Roblox documents Studio Assistant and its MCP workflow, and its own guidance says AI is best for routine object/script work while creators retain environment design decisions. [AI on Roblox](https://create.roblox.com/docs/ai/accelerated-workflows) · [Assistant in Studio](https://create.roblox.com/docs/tutorials/curriculums/building/code-with-assistant) · [Rojo 7](https://create.roblox.com/store/asset/13916111004/Rojo-7) · [Moon Animator 2](https://create.roblox.com/store/asset/4725618216/Moon-Animator-2%2Bidk)

## Working with AI without losing control

Use this loop for every map feature:

1. **You build the visual model** in Studio and make it look right before asking for code.
2. **You give it a stable purpose:** add the tag and attributes from the map contract, then tell the AI the object’s tag, attributes, and intended behavior.
3. **The AI writes only the glue and animation.** It may clone, reveal, tween, connect prompts, and validate. It must not replace your art with generated primitives.
4. **You playtest in Studio** and tell the AI exactly what happened. A screenshot of Explorer plus a screenshot/video of the playtest is ideal.
5. **We keep the contract documented.** New tags, attributes, actions, or saved states are a design change, not a one-off script shortcut.

Use a request like this in a future conversation:

> I built and saved [FEATURE NAME] in ServerStorage.GrowAnIslandMapLibrary. Its root has the [TAG NAME] tag and these attributes: [ATTRIBUTE LIST]. Build only the server-side loader/validator and a [Rise, Fade, or Reveal] animation. Do not create or change any geometry, terrain, visual models, tags, or values in my source library. Before editing, inspect PROJECT_STACK.md.

## Bonus: first-island build guide

This guide gets you from today’s runtime-generated world to a safe hand-built starter island with the fewest moving parts.

1. **Make a recovery point.** In Studio, publish the current place, then use **File → Save to File As…** to save studio/GrowAnIsland-map-v001.rbxl. Leave the code repository and its existing uncommitted changes alone.

2. **Open the authoring panels.** In Studio, enable Explorer and Properties. In Properties, you will use the **Tags** and **Attributes** sections; no separate tagging plugin is required.

3. **Create the protected library.** Under ServerStorage, add a Folder named GrowAnIslandMapLibrary; add the MapLibrary tag. Add a Model named WorldTemplate inside it, add the MapTemplate tag, and add a number attribute MapVersion = 1.

4. **Build one small island inside WorldTemplate.** Start with a playable spawn area, one beach made from Parts/MeshParts, cloneable ocean/dive props if wanted, a market, and placeholders for the coconut palm and upgrades. Make it attractive at this scale before making anything larger. Keep every cloneable visual object inside the template. If you choose to hand-sculpt Roblox Terrain, leave it in Workspace.Terrain and tell the AI it is persistent source terrain, not a template asset.

5. **Create the functional markers.** Add small helper parts or attachments where gameplay needs an exact location. Make marker parts anchored, transparent, non-colliding, and clearly named for you. Apply the tags/attributes in the map-contract table:

   - one MapSpawn with SpawnId = Starter and ShelterLevel = 0;
   - one CoconutDropZone;
   - one InteractionTarget with ActionId = SellCoconuts;
   - one palm InteractionTarget with ActionId = BuyCoconutPalm;
   - an InteractionTarget for BuyTravelator and one for UpgradeShelter if you want those upgrades in the first map;
   - an InteractionTarget for UpgradeOxygen and a DiveZone only if diving belongs in this first map;
   - an InteractionTarget with ActionId = RequestRebirth only if rebirth belongs in this first map;
   - RuntimeContainer folders for Pickups, Chests, and VFX.

6. **Create visual progress states rather than code geometry.** Under ProgressVisuals, hand-build the palm site/palm, travelator site/travelator, and each shelter stage you intend to keep. Tag each state ProgressVariant; give it a shared FeatureId and a numeric Stage. It is fine to begin with only the stage-0/1 palm states.

7. **Save, duplicate, and test the asset.** Save the place again. Keep the source in ServerStorage; it is normal that it is invisible in the game until the future loader clones it. Do not move the source into Workspace as the final architecture.

8. **Ask for the first code migration.** Bring the request template above back to the next conversation. The first coding task will replace the legacy world-shell/tile construction with a MapService that validates and clones WorldTemplate. It will leave expansion loading disabled for the single-grid milestone.

9. **Playtest only after validation exists.** The loader should stop with one actionable error if a required tag/attribute is missing. Fix that marker in Studio, save, and retry. Silent fallbacks and guessed positions make map work painful later.

10. **Add future islands one at a time.** Only after the starter island feels good, build a complete Parts/MeshParts island model under IslandTemplates, tag it IslandTemplate, set its ID and reveal attributes, and ask the AI for its loading animation. The model begins at its final authored position; RevealOffset tells code where to stage it before it tweens into place. A Roblox Terrain island cannot use this clone-and-rise path.

## Existing gameplay rules

The game remains a one-player-per-server tropical tycoon. Its server must continue to validate currency, upgrades, interaction range, cooldowns, collectible ownership, oxygen, chest rewards, and rebirth conditions. Clients request actions; they never decide results. DataService remains the only owner of ProfileStore access.

Balance values currently live in src/shared/Config/EconomyConfig.luau. The map rebuild will remove the legacy expansion-grid and random-biome assumptions from that config, profile types, UI, and services as one coherent migration—never as a partial visual workaround.

See [PROJECT_STACK.md](PROJECT_STACK.md) for the binding technical contract and [AGENTS.md](AGENTS.md) for instructions every future coding agent must follow.
