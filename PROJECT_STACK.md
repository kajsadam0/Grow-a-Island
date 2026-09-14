# Project stack and architecture

This is the binding technical contract for **Grow an Island**. Read it before changing code, the Rojo project, or Studio map content.

## Product direction

The game is a single-player-per-server tropical-island tycoon. The map is now **Studio-authored, template-driven content**:

- The creator hand-builds every island, terrain shape, prop, landmark, upgrade appearance, and dive area in Roblox Studio.
- Server code loads copies of those templates into a disposable runtime world.
- Code may animate, reveal, enable, disable, validate, and connect authored content.
- Code must never fabricate the map’s visual geometry, terrain water, foliage, buildings, or upgrade models from primitives.

The current milestone is exactly **one authored starter island/grid**. Expansion templates, procedural biomes, a 5×5 tile grid, and random tile rolls are out of scope until the starter island is complete.

The repository still contains a legacy WorldBuilder that generates the current world at runtime. It is an implementation being replaced, not the architecture to extend. The migration must be deliberate and complete; do not mix legacy generated map sections with the new source template in a shipped state.

Roblox Terrain is a Workspace singleton and cannot be included in a cloneable ServerStorage model. The recommended one-grid workflow uses hand-authored Parts and MeshParts for all copyable/animated island content. If the creator sculpts Workspace.Terrain, it is persistent Studio source content: runtime code must neither clear nor generate it, and template loading covers the cloneable models around it only.

## Toolchain

| Area | Approved choice |
| --- | --- |
| Code-to-Studio sync | Rojo |
| Tool installation/version pinning | Rokit |
| Package manager | Wally |
| Persistence | ProfileStore; only DataService may access it |
| Cleanup/lifetimes | Trove |
| Tag components | Component |
| Typed networking | TypedRemote |
| UI | Fusion |
| Developer commands | Cmdr |
| Engine features | Roblox built-ins: TweenService, Lighting, ParticleEmitter, Beam, Animation, MarketplaceService |

Do not introduce another framework or a community map/animation dependency without explicit approval.

The **official Roblox Studio Assistant** is encouraged for routine Studio work. The official **Studio MCP server** is the preferred way to let an MCP-enabled coding agent inspect, edit, and playtest the open Studio session. It is optional and connection state must be verified each session; an agent must never claim it can see or alter Studio unless the connection is actually available.

## Authority and ownership

| Owner | Owns | Must not own |
| --- | --- | --- |
| Creator in Studio | ServerStorage.GrowAnIslandMapLibrary cloneable models; persistent Workspace.Terrain if used; visual art, positions, lighting choices, marker placement | Server-side rules, rewards, saves, or remote validation |
| Server code | Runtime clone in Workspace, gameplay state, validation, prompts, spawned pickups/chests/VFX, animation | The protected source library or visual model design |
| Client code | Input, presentation, camera/UI/VFX requests | Currency, rewards, ownership, persistent state, server animation authority |
| Rojo source | src/, package references, project configuration | Direct representation of Workspace/ServerStorage map art |

Workspace.GrowAnIslandWorld is a runtime-only clone and may be cleared by the server. ServerStorage.GrowAnIslandMapLibrary and any hand-sculpted Workspace.Terrain are protected source content and must never be mutated, moved, or deleted during normal play.

The Rojo project intentionally has no Workspace or ServerStorage source mapping. Keep it that way unless the creator explicitly approves a reviewed map-export workflow. Save map backups as named local .rbxl snapshots under a future studio/ directory and publish intentionally.

## Template library contract

The library contains cloneable Models, not Roblox Terrain. It is discovered by MapLibrary, not a hardcoded Workspace path. The expected Explorer names are human-friendly conventions, but code must resolve functional instances by tags and attributes, then ensure they descend from the selected map root.

~~~
ServerStorage
└── GrowAnIslandMapLibrary                   [MapLibrary]
    ├── WorldTemplate                        [MapTemplate; MapVersion = number]
    │   ├── StarterIsland
    │   ├── OceanAndDiveArea
    │   ├── ProgressVisuals
    │   └── MapMarkers
    └── IslandTemplates
        └── <future hand-built models>       [IslandTemplate]
~~~

At runtime:

~~~
Workspace
├── Terrain                                  -- optional persistent Studio-owned terrain
└── GrowAnIslandWorld                        -- server-owned, disposable
    ├── Map                                 -- clone of the selected MapTemplate
    └── Runtime
        ├── Pickups
        ├── Chests
        └── VFX
~~~

The loader must take a fresh clone for every new runtime world. Do not parent an editable source template directly into Workspace.

## Tags and attributes

Tags are the stable integration API between hand-authored map content and code. Add them in Studio’s Properties panel. Attributes are IDs/configuration, not decoration. All tags and attribute names below are case-sensitive.

| Tag | Class expectation | Required attributes | Notes |
| --- | --- | --- | --- |
| MapLibrary | Folder | — | Exactly one active source library. |
| MapTemplate | Cloneable Model | MapVersion: number | Exactly one active starter-world model template; it cannot contain Workspace.Terrain. |
| MapSpawn | BasePart or Attachment | SpawnId: string, ShelterLevel: number | Spawn keyed by player progress stage. |
| InteractionTarget | BasePart or Model | ActionId: string; ObjectId: string where the action needs one | The object passed to range/identity validation. |
| CoconutDropZone | BasePart | — | An invisible bounding region, not a guessed coordinate. |
| TravelatorStart / TravelatorEnd | BasePart or Attachment | — | Exact endpoints for dynamic coconut travel. |
| ChestSpawn | BasePart or Attachment | SpawnId: string | One unique ID per point. |
| DiveZone | BasePart | — | An invisible authored volume. |
| WaterSurface | BasePart | — | The part’s Y coordinate is the waterline. Exactly one per map. |
| ProgressVariant | Model or Folder | FeatureId: string, Stage: number | A creator-made visual state selected by persistent progression. |
| RuntimeContainer | Folder | RuntimeKind: string | One each for Pickups, Chests, and VFX. |
| IslandTemplate | Cloneable Model | IslandId: string, RevealStyle: string, RevealDuration: number, RevealOffset: Vector3 | Future Parts/MeshParts content only; the model is fully hand-built at final position. |

Supported interaction ActionIds are currently:

- BuyCoconutPalm
- BuyTravelator
- UpgradeShelter
- UpgradeOxygen
- SellCoconuts
- MoveCoconuts
- RequestRebirth

Add a new action only when its typed remote (if one is needed), server validation, UI, documentation, and map contract are added together. Do not make behavior depend on a marker’s Explorer name.

### Progress visuals

Every visible state is a handcrafted ProgressVariant. For a feature with an unbuilt and built appearance, use the same FeatureId and successive numeric Stages. The server:

1. selects the variant indicated by validated profile state;
2. makes that existing instance active;
3. optionally tween-animates its authored parts; and
4. connects its interaction marker(s).

The server does **not** construct replacement parts, roofs, palms, belts, labels, or decoration from code.

### Future island reveal animation

When expansions return, each new island is fully assembled from Parts/MeshParts in IslandTemplates at its final pivot. RevealOffset is its temporary offset from that final pivot, RevealDuration controls the tween, and RevealStyle is a small reviewed allowlist such as Rise, Fade, or Instant. A Roblox Terrain island cannot follow this clone-and-reveal mechanism.

The animation service clones the model, stages the clone at final pivot plus RevealOffset, and tweens it to its original pivot. It must preserve the creator’s parts/materials/terrain and must not generate terrain or decorations. The server validates purchase/unlock state before starting the animation and does not accept a client-supplied model, duration, or destination.

## Required map services

The migration will replace WorldBuilder with narrow responsibilities:

| Service | Responsibility |
| --- | --- |
| MapService | Find/validate the library, clone the MapTemplate, expose tag-constrained map queries, switch ProgressVariants, and destroy only the runtime root. |
| MapAnimationService | Reveal a valid, server-approved IslandTemplate and run visual progress transitions using TweenService. |
| GameService | Keeps authoritative gameplay orchestration and asks map services for locations/targets instead of using coordinates. |
| WorldBehaviours | Retains small safe server physics defaults for tagged runtime instances; it does not build map content. |

Avoid a second all-purpose world builder. A service that creates visual islands is not permitted under a different name.

The first implementation must:

1. validate the sole MapLibrary and MapTemplate;
2. clone the one starter template under a new runtime root;
3. resolve starter spawn, runtime containers, and any installed map markers by tag;
4. provide actionable errors for missing/duplicate required markers; and
5. leave expansion loading disabled.

Only after that passes Studio playtests should gameplay locations move from legacy constants to tagged queries. Delete the legacy generator only when its map responsibilities have an equivalent template-backed implementation.

## Security and networking

Clients request; the server validates and decides.

The server must independently validate:

- profile readiness and one-player owner identity;
- all currency and prerequisite checks;
- action and animation cooldowns;
- distance to the tagged target within the active runtime map;
- tag identity, map-root ancestry, and any required ObjectId;
- inventory/storage capacity and collectible/chest availability;
- oxygen state using tagged dive/water markers;
- map-template IDs, island unlock state, reveal settings, and profile mutation;
- rebirth conditions.

No client may choose an island template, target position, visual stage, reward, biome, price, or data mutation. ProfileStore access remains confined to DataService.

## Persistence and migration

The old profile currently stores PurchasedTiles as random tile-to-biome data, and the UI/config/game services expect the legacy grid. The one-grid release must remove that concept as a coordinated schema migration:

1. raise SchemaVersion;
2. migrate old profiles safely, preserving coins/upgrades/rebirth values;
3. replace legacy tile fields and tutorial/UI steps with an explicit one-grid completion state only if gameplay requires one;
4. update EconomyConfig, profile types, remotes, client UI, GameService, and rebirth validation in one review; and
5. test both a fresh profile and a migrated legacy profile.

Do not silently reinterpret a stored tile biome as a Studio template ID. If future islands are added, persist only stable creator-assigned IslandIds and unlock state; never persist a generated visual description.

## Engineering rules

- Use --!strict in Luau modules.
- Use CollectionService tags plus attributes instead of hardcoded Workspace paths or world coordinates for authored objects.
- Query tags once through a validated map index; avoid arbitrary global GetTagged results without checking they are descendants of the active runtime map.
- Use Trove for connections and transient instances. Destroy only the runtime trove/root.
- Keep static UI in Fusion. Use Roblox built-ins for tweens, lighting, particles, beams, and animations.
- Make missing/multiple marker errors direct and actionable: include the tag, expected count/type/attributes, and template version.
- Never use a client-created marker or a template located outside the protected library.
- Keep temporary code-spawned content under tagged runtime containers; never add it to the source template.
- Do not add opaque or unreviewed scripts from Creator Store/free models to the place.

## Verification

Before handing off a map-system change:

1. Run the repository’s available formatter/type/test checks.
2. Open Studio and verify the Rojo sync did not move/delete the source library.
3. Playtest a fresh server: the starter model clones once, source template stays in ServerStorage, persistent Workspace.Terrain remains untouched if used, and all required markers validate.
4. Test every available progress visual stage, interaction, respawn, coconut path, chest marker, and dive/water boundary.
5. Test invalid/missing/duplicate markers and confirm the error identifies the exact repair.
6. Test a legacy save migration when the old grid fields are removed.
7. For a future island, test reveal animation once, rejoin, and confirm no duplicate runtime island or mutation occurs.
