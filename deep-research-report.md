# Roblox “Grow a Tiny Planet” Vibecoding Stack

For this particular game, I would **not** build a giant Roblox framework stack. Your loop—claim plot → buy organism → place → wait/grow → harvest → sell → reinvest—is structurally simple, and Roblox already provides most of the engine-level pieces for animation, lighting, effects, networking, persistence primitives, monetisation, testing and profiling. The best stack is therefore a **small number of dependable Luau packages around Roblox's built-ins**, rather than a dependency for every feature.

You already have an unusually good base in VS Code: **Rojo, Luau Language Server, Selene and StyLua**. The main missing pieces are a reproducible command-line toolchain, a package manager, persistence, cleanup/lifecycle helpers, a consistent UI approach, typed networking conventions and developer/admin tooling. Rojo's own documentation now points developers towards **Rokit** as its toolchain manager, while the older Aftman project was archived in July 2025 and explicitly states that it is no longer maintained. citeturn4view2turn4view0turn4view1

My recommended starting stack is:

| Layer | Recommendation | Priority |
|---|---|---|
| Toolchain versions | **Rokit** | **Install now** |
| Luau packages | **Wally** | **Install now** |
| Player persistence | **ProfileStore** | **Install now** |
| Resource/connection cleanup | **Trove** | **Install now** |
| Tagged object behaviours | **Component + CollectionService** | **Install now / early MVP** |
| Client/server contract | **TypedRemote** or carefully wrapped native remotes | **Recommended** |
| UI | **Fusion** | **Recommended** |
| UI development in Studio | **UI Labs** | **Recommended Studio plugin** |
| Developer/admin commands | **Cmdr** | **Recommended** |
| Spring/tween motion | Roblox **TweenService**, optionally **Ripple** | Built-in first |
| VFX | Roblox **ParticleEmitter + Beam** | Built-in first |
| Lighting | Roblox **Lighting** | Built-in |
| Rig animation | Roblox **Animation Editor** | Built-in |
| Complex animation authoring | **Moon Animator 2** | Optional Studio plugin |
| Camera shake | RbxUtil **Shake** | Optional |
| Complex zones | **ZonePlus** | Optional |
| Rich server→client state replication | **Replica** | Later |
| Promises | **Promise** | Only when genuinely useful |
| High-performance networking | **ByteNet** | Probably unnecessary |
| Zap networking | **Do not adopt yet** | Currently undergoing rewrite |
| pesde | Good alternative to Wally | Choose one, don't mix casually |
| Aftman | **Do not start with it** | Archived |
| TestEZ | **Do not start a new test stack with it** | Archived |

The key principle is: **give your AI coding assistant a fixed architecture and approved dependency list, then tell it not to invent new frameworks unless there is a concrete need.**

## Toolchain and dependency management

### Add Rokit first

Rokit describes itself as a next-generation toolchain manager for Roblox projects. It can pin and install project tools and is intended as a friendlier successor to Foreman/Aftman-style workflows. Its commands include `rokit init`, `rokit add`, `rokit install`, `rokit list` and `rokit update`. Aftman, in contrast, is now archived and explicitly unmaintained. citeturn4view0turn4view1

This matters especially in your setup because **installing the Rojo VS Code extension does not itself put the `rojo` CLI on your PATH**. Rojo consists of the command-line/server side plus the Studio plugin; the VS Code extension is not a substitute for installing the CLI. citeturn4view2

So conceptually your development machine should become:

```text
VS Code
├── Rojo extension
├── Luau Language Server
├── Selene
└── StyLua

Rokit-managed CLI tools
├── Rojo
├── Wally
├── Selene
└── StyLua
```

You can initialise Rokit in the project and use it to pin the tools your repository expects:

```bash
rokit init

# Then add the Roblox command-line tools used by the project,
# for example Rojo and Wally, and install the pinned versions.

rokit install
```

The exact benefit here is reproducibility: you want an AI assistant opening your repository six months from now to see **which tools belong to the project**, rather than assuming whatever happens to be installed globally.

### Use Wally as the package manager

Wally is a Roblox package manager inspired by Cargo/npm. It uses `wally.toml` for dependency declarations and `wally.lock` to resolve exact package versions. Wally supports ordinary shared dependencies, server-only dependencies and development dependencies; its lockfile is specifically intended to ensure that everyone working on a project gets the same resolved versions. citeturn2view0turn30view0turn30view3

That is almost ideal for vibecoding because the repository itself can tell the AI:

> These are the allowed libraries. Do not reimplement them and do not silently substitute another library.

The normal flow is roughly:

```bash
wally init
# edit wally.toml
wally install
```

Wally supports `install`, `update`, `search` and package manifests using semantic version requirements. citeturn2view0turn30view2

A sensible starting manifest for the packages whose current identifiers/versions can be verified directly from their maintainers is:

```toml
[package]
name = "yourname/tiny-planet"
description = "Grow a Tiny Planet Roblox experience"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"
private = true

[dependencies]
Trove = "sleitnick/trove@1.8.0"
Component = "sleitnick/component@2.4.8"
TypedRemote = "sleitnick/typed-remote@0.3.0"

# Useful when you add weather impacts / camera reactions:
Shake = "sleitnick/shake@1.1.0"

[server-dependencies]
ProfileStore = "lm-loleris/profilestore@1.0.3"
```

The RbxUtil repository currently declares Trove `1.8.0`, Component `2.4.8`, TypedRemote `0.3.0`, Shake `1.1.0`, Signal `2.0.3`, Spring `1.0.0`, Timer `2.0.0` and Comm `1.0.1`; ProfileStore's own Wally manifest identifies it as `lm-loleris/profilestore` version `1.0.3` and server-realm code. citeturn7view0turn17view0

I would commit both `wally.toml` **and `wally.lock`**. Wally explicitly uses the lockfile to preserve the exact package resolution. citeturn30view0

### Wally versus pesde

**pesde** is a credible modern alternative. It describes itself as a Luau package manager supporting multiple runtimes, including Roblox and Lune. citeturn2view2

For your project, however, I would use **Wally** initially. A large amount of established Roblox/Luau library documentation already supplies Wally package identifiers, including ProfileStore, Fusion, RbxUtil and Ripple. Mixing Wally and pesde without a particular reason would give your AI assistant two package models to understand instead of one. citeturn17view0turn17view1turn25view0turn7view0

## Runtime libraries worth standardising on

### The core package set

The most important distinction is between libraries that solve a recurring architectural problem and libraries that merely save a few lines of code. For this MVP, the former are valuable; the latter can become dependency noise.

| Library | What it should do in Tiny Planet | Recommendation |
|---|---|---|
| **ProfileStore** | Cash, inventory, unlocked planting slots, permanent upgrades, planted-organism metadata | **Core** |
| **Trove** | Clean up event connections, instances, tasks and object lifecycles | **Core** |
| **Component** | Attach Luau behaviours to tagged plots, slots, organisms, shops, sell areas and VFX anchors | **Core/strongly recommended** |
| **TypedRemote** | Give remotes explicit names/types so AI does not invent arbitrary networking patterns | **Recommended** |
| **Fusion** | Shop, inventory, timers, currency HUD, notifications, mutation popups | **Recommended** |
| **Cmdr** | Development commands such as giving currency, forcing weather, instant growth, profile inspection | **Recommended** |
| **Ripple** | Spring/tween motion outside or alongside your UI framework | **Optional** |
| **Shake** | Camera response to meteor/lightning/weather events | **Optional** |
| **Signal** | Custom in-process application events when an `RBXScriptSignal` isn't available | **Optional** |
| **ZonePlus** | Complex or irregular zones | **Optional** |
| **Replica** | Structured selective server→client replicated state | **Later** |
| **Promise** | Composable/cancellable asynchronous workflows | **Only if needed** |
| **ByteNet** | Highly optimised typed buffer networking | **Probably later/never for this game** |

### ProfileStore for persistence

ProfileStore is explicitly designed as a Roblox DataStore wrapper around player-oriented persistence, with automatic saving and session locking intended to prevent the same player profile being opened simultaneously by multiple servers. Its documentation also warns that it is not intended as a general leaderboard/global-state system. citeturn6view0

That maps almost perfectly to your persisted data:

```luau
export type ProfileData = {
    SchemaVersion: number,

    Cash: number,

    Inventory: {
        [string]: number, -- SpeciesId -> quantity
    },

    UnlockedSlots: number,

    Upgrades: {
        HarvestMultiplier: number,
        GrowthMultiplier: number,
    },

    Planted: {
        [string]: { -- SlotId
            SpeciesId: string,
            PlantedAt: number,
            ReadyAt: number,
            MutationId: string?,
        },
    },
}
```

Roblox's underlying DataStoreService persists information such as inventory between sessions and makes an experience's stored data accessible from different servers/places. Roblox also warns that datastore operations can fail, recommends error handling, and notes that `UpdateAsync()` is the safer primitive when multiple servers may write the same key. citeturn14view0

**Do not make growth depend on one long-running `task.wait()` or `task.delay()` per plant.** Persist `PlantedAt` and `ReadyAt`, then derive whether a plant is mature from the timestamp whenever needed. That way a server shutdown, reconnect or player absence does not destroy the logical timer; this design follows naturally from using persistent player data rather than treating a particular running server as the source of truth. citeturn14view0turn6view0

### Trove should become your default cleanup pattern

RbxUtil is a collection of focused Roblox utility modules. Its currently declared modules include **Trove, Component, Signal, Timer, Spring, Shake, Comm and TypedRemote**, among others. citeturn7view0

For AI-generated Roblox code, Trove is particularly useful because generated systems frequently create lots of:

```luau
someEvent:Connect(...)
RunService.Heartbeat:Connect(...)
Instance.new(...)
task.spawn(...)
```

The architectural rule should be:

> Any controller/component that owns temporary connections or instances gets a Trove, and destroying that controller/component cleans the Trove.

That gives your AI one consistent lifecycle convention instead of repeatedly inventing manual `Disconnect()` logic.

### Component plus CollectionService is excellent for your object-heavy game

Roblox's built-in `CollectionService` can add/remove tags, retrieve all tagged instances and notify scripts when instances carrying a tag are added or removed. citeturn29view3

RbxUtil's Component is designed specifically to bind components to Roblox instances using CollectionService tags. citeturn24search3turn7view0

That makes the following object taxonomy extremely clean:

```text
Tags
├── Plot
├── PlantSlot
├── OrganismDisplay
├── SpeciesShop
├── SellZone
├── HarvestPrompt
├── WeatherAffected
└── VFXAnchor
```

Instead of the AI writing:

```luau
workspace.Planets.Planet1.Folder.Folder2.SpecialPart...
```

it can work against meaning:

```luau
CollectionService:GetTagged("PlantSlot")
```

or a `PlantSlotComponent`.

That is exactly the sort of convention that makes vibecoding dramatically less fragile.

### TypedRemote is enough networking for this game

RbxUtil describes TypedRemote as a simple package for typed `RemoteEvent` and `RemoteFunction` usage. citeturn7view0

Your game simply does not have shooter-like networking requirements. The common calls are going to be things such as:

```text
RequestPurchaseSpecies
RequestPlaceSpecies
RequestHarvest
RequestSell
RequestUpgrade
WeatherChanged
InventoryChanged
CashChanged
```

You therefore do **not** need an aggressively optimised networking stack on day one.

ByteNet is a more specialised buffer-based networking library that serialises Luau data into buffers and provides a strict typed packet API. It can be useful where bandwidth and packet efficiency genuinely matter, but that solves a problem your low-frequency farming/placement game probably does not yet have. citeturn10view0

Zap is another buffer networking option, but its repository currently states that it is undergoing a rewrite, with its older 0.6.x branch maintained separately. For a vibecoded MVP where stability is more important than squeezing bytes out of the wire, I would **not make Zap a foundational dependency right now**. citeturn10view1

Most importantly, **typed networking does not equal secure networking**. Roblox's current security guidance states that every piece of client-supplied data must be validated by the server, including context/permission, type/structure and value checks; it also recommends server-side rate limiting for client-triggerable server logic. citeturn21view0

### Fusion is my UI choice for you

Fusion is a Roblox/Luau reactive UI library whose repository explicitly positions it around declarative UI, reactive state management and animation. citeturn8view0

For a vibe-coded game, that is preferable to having the AI manually mutate dozens of GUI properties from arbitrary controller code.

Conceptually:

```text
Game state
    ↓
Fusion reactive state
    ↓
Currency HUD
Shop
Inventory
Growth timer cards
Mutation notification
Weather banner
Upgrade menu
```

There is one version-management detail worth knowing: Fusion's current `main` branch manifest identifies the package as `elttob/fusion` but is presently marked `0.4.0-dev1`. I would therefore use **the latest stable Wally release appropriate to your project rather than blindly copying the development version from `main`**. citeturn17view1

Two alternatives are legitimate, but I would not install them alongside Fusion:

**Vide** is a concise reactive Luau UI framework, describes itself as fully Luau-typecheckable, and carries both Wally and pesde manifests. It is probably my second choice for you. citeturn9view0turn9view1

**React Lua** is the community-maintained Lua/Luau React ecosystem derived from Roblox's React work. It makes sense if you already think naturally in React components/hooks; otherwise it adds a larger conceptual model than you need for this project. citeturn8view1

So put this in your AI instructions:

> **Use Fusion for game UI. Do not introduce React, Vide, Roact or another UI framework unless explicitly authorised.**

That one sentence will prevent a surprising amount of AI-generated architectural chaos.

### Ripple is useful, but not mandatory

Ripple describes itself as a lightweight Roblox motion library for simple transitions and animations. It provides springs and tweens and supports Roblox data types including numbers, `Vector2`, `Vector3`, `Color3`, `UDim2` and `CFrame`. Its Wally identifier is `littensy/ripple`. citeturn25view0

Use it when you want code such as:

```text
shop panel springs open
organism gently bobs
harvested crystal pops upward
button compresses and rebounds
planet decoration eases into place
```

But don't install it merely because “animations need a library”. Roblox already gives you TweenService, and Fusion can cover substantial UI motion itself. Ripple becomes worthwhile when you repeatedly want physics-style spring motion throughout the game. Roblox's TweenService provides tween creation and interpolation functionality natively. citeturn14view1turn25view0

### Cmdr will save enormous development time

Cmdr is an extensible, type-safe Roblox command framework intended for developer tools, admin workflows and in-game command systems. Its current repository emphasises server authority and validation as well as custom commands, arguments and autocomplete. citeturn17view3

For this game, I would create development-only/admin commands such as:

```text
cash me 100000
give-species me CrystalFern 20
grow-all me
reset-plot me
set-weather MeteorShower
set-weather Aurora
mutation-all Gold
unlock-slots me 12
inspect-profile me
save-profile me
```

That is vastly better than asking the AI to keep inserting temporary debug buttons or changing your saved data manually.

Make sure production permissions are strict; the command framework does not mean ordinary players should gain developer commands.

### Packages I would postpone

**Replica** is a server-to-client state replication library in which server-created state can be selectively subscribed to by clients, with clients receiving state-change notifications. It becomes attractive if your replicated state grows complex—for example hundreds of dynamic objects, party/shared goals and lots of reactive UI—but it is unnecessary for your first farming loop. citeturn6view1

**Promise** provides Promise/A+-style asynchronous composition for Roblox and is particularly helpful for cancellation and coordination of asynchronous operations without uncontrolled yields. citeturn6view2 You do not need to turn every shop transaction or plant action into a promise chain, though.

**ZonePlus** provides dynamic zones based on region checking, raycasting and touch-related mechanisms. citeturn15view0 It is handy for irregular multi-part areas, but a tiny planet containing fixed planting slots and one sell pad does not justify it initially.

## Studio plugins and Roblox features you should use instead of libraries

Your Studio installation currently contains only Rojo. I would intentionally keep the Studio plugin list much shorter than the VS Code/package list.

### Recommended Studio setup

| Studio tool | Verdict | Use |
|---|---|---|
| **Rojo** | Keep | VS Code ↔ Studio synchronisation |
| **UI Labs** | Add | Developing coded UI components |
| **Moon Animator 2** | Optional | More involved animation authoring |
| Roblox **Animation Editor** | Use built-in | Character/tool animations |
| Roblox **MicroProfiler** | Use built-in | Performance debugging |
| Device / multi-client / network simulation | Use built-in | Testing |

UI Labs is specifically a Roblox Storybook-style plugin for declarative interfaces such as Fusion/Roact. Its documentation highlights hot-reloading, editable controls and sandboxed UI stories. citeturn23search6

For your workflow, that means the AI can produce:

```text
Shop.story.luau
Inventory.story.luau
SpeciesCard.story.luau
CurrencyHUD.story.luau
WeatherBanner.story.luau
MutationPopup.story.luau
```

and you can iterate on UI without repeatedly launching the complete game loop.

### Don't install a separate animation system just to animate things

Roblox Studio already ships an Animation Editor accessible from Studio's Avatar tools. It supports rig poses, keyframes, easing, looping, priority and keyframe optimisation. citeturn25view3

Use the built-in editor for:

```text
player planting animation
harvesting animation
tool swing
NPC/vendor idle
small creature animation
pet/organism rig idle
```

Moon Animator 2 is available through Roblox's Creator ecosystem and is worth considering only when your animation requirements outgrow the built-in workflow, for example elaborate multi-object sequences or cinematic authoring. Roblox's own Creator Store search result for the older standalone Animation Editor explicitly tells users to use the version already integrated into Studio, which is another reason not to install unnecessary animation plugins. citeturn24search8turn23search2

### For “lighting”, use Roblox Lighting

If by “lightning” you partly meant **lighting**, do not install a lighting library.

Roblox's `Lighting` service directly controls global colour, illumination intensity, shadows, appearance and environmental time-of-day settings. Its current lighting system includes `Realistic` and `Soft` lighting styles as well as properties for ambient colour, brightness, exposure, shadows and clock time. citeturn22view3

For Tiny Planet, I would build reusable weather presets:

```luau
WeatherPresets = {
    Clear = { ... },
    GoldenHour = { ... },
    Rain = { ... },
    Aurora = { ... },
    MeteorShower = { ... },
    Storm = { ... },
}
```

Then your `WeatherController` interpolates between them rather than scattering lighting constants throughout the codebase.

### For literal lightning, use Beam + ParticleEmitter

You also do **not** need a dedicated lightning dependency initially.

A Roblox `Beam` renders a textured visual between two attachments and supports curves, width, gradients and transparency. `ParticleEmitter` emits configurable particles and is designed for effects such as sparks, smoke and fire. citeturn29view2turn29view1

A perfectly adequate alien-storm lightning strike is:

```text
two or more Attachments
       ↓
curved Beam(s)
       +
spark ParticleEmitter
       +
brief Lighting brightness flash
       +
Sound
       +
optional Shake
```

For stylised weather events, that gives you spores, rain splashes, cosmic dust, crystal bursts, aurora particles, meteor trails and lightning without pulling in a large VFX framework. Roblox also explicitly recommends checking particle/beam effects at both lower and higher graphics quality because their visual presentation can vary with device graphics settings. citeturn29view1turn29view2

For camera movement during a strike, RbxUtil currently includes `Shake` as a dedicated utility module. citeturn7view0

### Use CollectionService for objects instead of hardcoded folders

This is possibly the most important “objects etc.” recommendation in the entire report.

Use Roblox tags as the semantic layer for world objects:

| Tag | Meaning |
|---|---|
| `Plot` | Player-ownable tiny planet/plot |
| `PlantSlot` | Valid organism placement position |
| `SpeciesShop` | Shop interaction |
| `SellZone` | Harvest selling interaction |
| `OrganismDisplay` | Spawned visual plant/organism |
| `HarvestPrompt` | Harvestable interaction |
| `WeatherAffected` | Receives weather visuals |
| `VFXAnchor` | Attachment/position for local effects |

CollectionService supports retrieving tagged objects and receiving signals when tagged instances appear or disappear. citeturn29view3

The AI should never need to guess which specific nested folder contains the shop or planting slot. It asks for the appropriate tag/component.

## Tiny Planet architecture I would actually build

The following architecture is deliberately boring. That is a strength: an AI coding agent can understand it quickly, and every gameplay feature has an obvious home.

```text
src/
├── client/
│   ├── Controllers/
│   │   ├── PlacementController.luau
│   │   ├── InteractionController.luau
│   │   ├── WeatherController.luau
│   │   └── VFXController.luau
│   │
│   └── UI/
│       ├── App.luau
│       ├── Components/
│       ├── Screens/
│       └── Stories/
│
├── server/
│   ├── Services/
│   │   ├── DataService.luau
│   │   ├── PlotService.luau
│   │   ├── PlantService.luau
│   │   ├── EconomyService.luau
│   │   ├── ShopService.luau
│   │   ├── WeatherService.luau
│   │   └── MonetizationService.luau
│   │
│   └── Admin/
│       └── Commands/
│
└── shared/
    ├── Config/
    │   ├── SpeciesConfig.luau
    │   ├── MutationConfig.luau
    │   ├── WeatherConfig.luau
    │   ├── EconomyConfig.luau
    │   └── ProductConfig.luau
    │
    ├── Net/
    │   └── Remotes.luau
    │
    ├── Components/
    ├── Types/
    └── Util/
```

### DataService

`DataService` is the **only subsystem allowed to directly deal with ProfileStore/profile lifecycle**.

Everything else asks something like:

```luau
DataService:GetProfile(player)
DataService:GetData(player)
```

The rest of your code should not create its own datastores.

ProfileStore's purpose is specifically player-oriented DataStore persistence with autosaving/session locking, while Roblox itself recommends isolating DataStore access and correctly handling datastore failures. citeturn6view0turn14view0

### PlotService

`PlotService` should:

```text
assign an available plot
record player ↔ plot ownership on the server
spawn persistent planted organisms
expose valid planting slot IDs
clean the plot on leave
```

Do **not** initially persist a giant copy of every Roblox Instance in the plot.

For fixed planting points, persist:

```text
SlotId = "A07"
SpeciesId = "CrystalMoss"
PlantedAt = ...
ReadyAt = ...
MutationId = "Iridescent"
```

Then rebuild the visuals from configuration.

That will make save migration, anti-cheat and AI-generated code much simpler.

### PlantService

Put the actual species catalogue in data, not giant `if/elseif` trees:

```luau
return {
    CrystalMoss = {
        DisplayName = "Crystal Moss",
        BuyPrice = 25,
        SellPrice = 45,
        GrowSeconds = 30,
        ModelName = "CrystalMoss",
        Rarity = "Common",
    },

    NebulaFern = {
        DisplayName = "Nebula Fern",
        BuyPrice = 175,
        SellPrice = 290,
        GrowSeconds = 120,
        ModelName = "NebulaFern",
        Rarity = "Rare",
    },
}
```

Then adding a species should mostly mean **adding configuration and assets, not rewriting gameplay code**.

This is especially AI-friendly: you can ask “add ten species” and the model should touch `SpeciesConfig`, not rewrite `PlantService`.

### PlacementController and server-side placement validation

Client:

```text
raycast cursor/touch
show ghost organism
snap to valid slot
show green/red validity
send requested SpeciesId + SlotId
```

Server:

```text
does player own this plot?
does SlotId actually belong to this plot?
is slot empty?
does SpeciesId exist?
does inventory contain one?
is request rate reasonable?
if yes:
    consume inventory
    create plant data
    spawn authoritative organism
```

The client should **never** send:

```text
"subtract exactly 25 cash"
"give me this model"
"sell this for 10000"
"this plant has matured"
"this mutation rolled Legendary"
```

Roblox's current security guidance explicitly says the server should validate client context/permissions as well as types and values, and gives an in-game shop as an example where the server—not the client—confirms affordability. It also calls out currency and item values as data requiring particularly careful validation. citeturn21view0

### EconomyService

The server should know prices from `SpeciesConfig`.

Bad:

```luau
BuySpecies:FireServer("NebulaFern", 1)
```

Worse:

```luau
BuySpecies:FireServer({
    Species = "NebulaFern",
    Price = 1,
})
```

Better:

```luau
BuySpecies:FireServer("NebulaFern")
```

The server looks up the actual price.

Roblox specifically illustrates an attack where a malicious client attempts to supply manipulated shop/item information and recommends server-side verification of the actual item and its state. citeturn21view0

### Growth

Do not make every organism a permanently running script.

Treat growth as data:

```text
ReadyAt - current time
```

Visual stage can then be calculated:

```text
0–25%    seed/spore
25–60%   sprout
60–99%   mature-looking
100%     harvestable
```

Only update visual timers for objects that need to be shown to the client.

This architecture also means a player can leave for ten minutes and return to mature organisms because the persisted timestamp—not a running coroutine—is the source of truth. ProfileStore and DataStoreService are designed around persisted session-to-session state. citeturn6view0turn14view0

### Weather and mutations

Split weather into two layers:

```text
WeatherService        SERVER
├── chooses current weather
├── chooses start/end
├── determines gameplay modifiers
└── determines mutation outcomes

WeatherController     CLIENT
├── Lighting transition
├── particles
├── beams
├── sounds
├── camera shake
└── decorative visuals
```

For example:

```text
Aurora:
    +5% rare mutation chance
    client adds alien-coloured atmosphere/particles

Meteor Shower:
    occasional mutation opportunities
    client spawns meteor VFX

Storm:
    growth multiplier
    client renders rain/lightning

Solar Bloom:
    faster growth
    warmer lighting
```

Roblox's own security documentation happens to include almost exactly the relevant example: it describes a client-triggered **lightning effect** and warns that merely relaying a client request to all other clients allows spam, malformed values and unauthorised effects. Roblox recommends server validation and rate limiting before broadcasting the effect. citeturn21view0

That is precisely the model I would use for your weather events.

### Fusion UI hierarchy

Keep one root application:

```text
App
├── HUD
│   ├── CashDisplay
│   ├── InventoryButton
│   └── WeatherIndicator
├── ShopScreen
├── InventoryScreen
├── SpeciesDetails
├── PlotUpgradeScreen
├── MonetisationScreen
├── Notifications
└── Tutorial
```

The AI should create reusable components such as:

```text
Button
Panel
SpeciesCard
CurrencyAmount
RarityBadge
ProgressBar
Countdown
ProductCard
Tooltip
Toast
```

Do not let every feature invent its own button implementation.

Fusion's declarative/reactive design is intended for exactly this state-to-interface style. UI Labs adds an isolated storybook workflow with hot reloading and interactive controls for coded interfaces. citeturn8view0turn23search6

## Security, monetisation, persistence and testing

### Adopt one non-negotiable networking rule

> **The client requests; the server decides.**

Every one of these must be authoritative server operations:

```text
buy
place
harvest
sell
upgrade
roll mutation
award currency
unlock slot
grant monetised item
```

Roblox explicitly states that any time a client can trigger server behaviour there is potential for abuse, and that every piece of client data must be validated before use. It recommends context/permission checks, type/structure validation, value validation and server-side rate limiting. citeturn21view0

This also applies to things that don't look like remotes. Roblox warns that `ProximityPrompt`, `ClickDetector` and `DragDetector` interactions still require server validation; for example, clients can manipulate or trigger several interaction behaviours in ways you should not trust. citeturn21view0

Therefore:

```text
ProximityPrompt fires
        ↓
server still checks:
player distance
plot ownership
plant maturity
interaction state
cooldown
```

### ProfileStore does not remove the need for DataStore discipline

Roblox warns that DataStore calls can fail and should be protected appropriately. Studio access to live API services is also disabled by default, and Roblox warns that enabling Studio DataStore access against a live experience can be dangerous; it recommends working against a separate test version rather than risking production data. citeturn14view0

So use at least:

```text
Tiny Planet - Development
Tiny Planet - Production
```

Do not let your normal Studio testing session write into real-player production profiles.

### Monetisation maps cleanly to native Roblox APIs

Your proposed monetisation does **not** require a monetisation package.

Roblox defines **passes** as one-time Robux purchases for lasting privileges/permanent power-ups, whereas **developer products** are items or abilities users can buy repeatedly. citeturn22view0turn22view2

For your concept:

| Offer | Roblox mechanism I would use |
|---|---|
| Permanent extra planting slots | **Pass** |
| Permanent better tool | **Pass** |
| Permanent cosmetic plot theme | **Pass** or normal in-game unlock |
| VIP cosmetic pack | **Pass** |
| 15-minute growth boost | **Developer Product** |
| Temporary mutation-luck boost | **Developer Product** |
| Currency bundle | **Developer Product** |
| One-off convenience consumable | **Developer Product** |
| Premium seasonal track | New **Pass per season** is simplest |
| Purely cosmetic earned season track | Your own profile data |

This matches Roblox's distinction between permanent/one-time privileges and repeat-purchase consumables. citeturn22view0turn22view2

For developer products, the important implementation rule is **ProcessReceipt**. Roblox explicitly requires developers to process receipts, validate them and acknowledge the receipt after granting the product; its documentation specifically warns **not to use `PromptProductPurchaseFinished` as proof that a purchase succeeded**. `MarketplaceService.ProcessReceipt` is a server-side callback and can only be assigned once. citeturn22view0turn22view1

Therefore have exactly one:

```text
MonetizationService
    ↓
MarketplaceService.ProcessReceipt
    ↓
ProductId -> handler
```

Do not let individual UI buttons or separate scripts each implement their own receipt handling.

### Cmdr plus built-in Studio testing is enough for the MVP

Roblox Studio has significantly richer testing facilities than many older Roblox tutorials suggest.

Current Studio supports:

- solo client/server switching;
- multi-client simulation with up to eight simulated clients;
- device simulation;
- network simulation including latency, jitter and packet loss;
- scripted multi-client testing through Studio-only testing services. citeturn27view1

For your game, the highest-value tests are:

```text
two clients cannot claim the same plot
player A cannot harvest player B's plant
two harvest requests do not double-pay
disconnect during planting doesn't corrupt data
rejoin restores planted organisms
growth completes correctly while offline
weather applies exactly once
purchase receipt cannot double-grant
mobile UI remains usable
network delay doesn't duplicate interactions
```

I would test those before spending time building an elaborate unit-test framework.

That recommendation is also influenced by the current ecosystem state: Roblox's TestEZ repository was archived on 14 September 2024 and is read-only. TestEZ still exists and historically provided BDD-style testing, but I would not make an archived testing framework a new project's core dependency in September 2026. citeturn27view0

### Use the built-in MicroProfiler before adding optimisation libraries

Roblox's MicroProfiler is already available in Studio and the Roblox client. It provides frame-level timing information for engine tasks such as scripts, physics, animation and rendering. citeturn27view2

Do not pre-optimise this farming game with object-pool frameworks, ECS frameworks or specialised networking.

First profile.

Potential future hotspots are more likely to be:

```text
hundreds of visible organisms
too many individual Heartbeat connections
excessive particle fill-rate
too many constantly animating UI elements
too many physical/unanchored objects
rebuilding whole plots repeatedly
```

Roblox's particle documentation specifically notes that particle size/fill-rate can affect GPU performance, which matters if you eventually cover planets in spores, fog and sparkles. citeturn29view1

### Don't install third-party analytics yet

Roblox already provides an analytics dashboard covering retention, engagement, acquisition, demographics, feedback and monetisation metrics. Experiences become eligible for all dashboard KPIs after meeting Roblox's current activity criteria. citeturn29view0

For an MVP, focus your instrumentation around the actual funnel:

```text
Join
↓
Claim plot
↓
Open shop
↓
Buy first organism
↓
Place first organism
↓
Harvest first organism
↓
Sell first organism
↓
Buy second organism / upgrade
```

That is much more useful to your game's design than installing an analytics SDK merely because one exists.

## The final stack I would give your AI

The best way to make vibecoding reliable is to place a short architecture contract directly into the repository. Call it something obvious such as:

```text
PROJECT_STACK.md
```

Then point whichever AI coding assistant you use at it.

A good version for this project would be:

```markdown
# Tiny Planet Technical Contract

## Toolchain

This is a Roblox Luau project developed primarily in VS Code.

Use:
- Rojo for filesystem <-> Roblox Studio synchronisation.
- Rokit for command-line tool versions.
- Wally for Luau package dependencies.
- Luau Language Server for Luau typing/intellisense.
- Selene for linting.
- StyLua for formatting.

Do not introduce another package manager.

## Runtime libraries

Approved:
- ProfileStore: persistent player profiles.
- Trove: lifecycle/resource cleanup.
- Component: behaviours attached to CollectionService tagged Instances.
- TypedRemote: typed network declarations.
- Fusion: UI.
- Cmdr: developer/admin commands.

Optional when explicitly useful:
- Shake: camera shake.
- Ripple: spring/tween motion.
- Signal: custom application events.
- ZonePlus: complex zones.
- Replica: complex server -> client state replication.
- Promise: complex asynchronous workflows.

Do not add another framework/library without explaining why Roblox
built-ins or the approved packages cannot solve the problem.

## Roblox built-ins

Prefer Roblox engine functionality for:
- TweenService: normal tweens.
- Animation Editor / Animator: rig animations.
- Lighting: world lighting.
- Beam: beams and lightning.
- ParticleEmitter: VFX.
- CollectionService: object tags.
- MarketplaceService: monetisation.
- DataStoreService only through DataService/ProfileStore.
- Studio testing tools for multiplayer/device/network tests.
- MicroProfiler for profiling.

## Architecture

Server services:
- DataService
- PlotService
- PlantService
- EconomyService
- ShopService
- WeatherService
- MonetizationService

Client controllers:
- PlacementController
- InteractionController
- WeatherController
- VFXController

UI:
- Fusion only.

Shared configuration:
- SpeciesConfig
- MutationConfig
- WeatherConfig
- EconomyConfig
- ProductConfig

Shared types:
- All important payloads and saved structures should have Luau types.

## Networking rules

The client requests.
The server validates and decides.

Never trust the client for:
- cash
- prices
- rewards
- growth completion
- inventory quantities
- mutations
- ownership
- product grants
- placement validity

Validate:
- remote argument types
- IDs against config tables
- plot ownership
- distances where relevant
- cooldowns/rate limits
- inventory/currency
- slot availability

Do not create remotes dynamically for individual plants.

## Persistence rules

Player profile is authoritative for:
- Cash
- Inventory
- UnlockedSlots
- Permanent upgrades
- Persistent planted organisms

Plants persist:
- SlotId
- SpeciesId
- PlantedAt
- ReadyAt
- MutationId if present

Never persist a running countdown.
Persist timestamps and derive remaining time.

Only DataService directly interacts with ProfileStore.

## Object rules

Use CollectionService tags instead of deeply hardcoded workspace paths.

Expected tags:
- Plot
- PlantSlot
- OrganismDisplay
- SpeciesShop
- SellZone
- HarvestPrompt
- WeatherAffected
- VFXAnchor

Use Component when tagged objects need reusable behaviour.

## Species design

Species behaviour should be data-driven through SpeciesConfig.

Adding a normal species should not require editing PlantService.

Server owns:
- buy price
- sell value
- grow duration
- mutation logic

Client can read replicated display data but does not determine rewards.

## Weather design

WeatherService chooses gameplay state on the server.

WeatherController creates cosmetic effects on each client.

Use Roblox Lighting, Beam and ParticleEmitter before adding VFX packages.

Weather visuals must not determine authoritative mutation/reward outcomes.

## UI rules

Fusion only.

Build reusable components:
- Button
- Panel
- SpeciesCard
- CurrencyDisplay
- ProgressBar
- Countdown
- RarityBadge
- ProductCard
- Toast
- Tooltip

Do not manually create independent ScreenGuis for every feature.

## Monetisation

Permanent entitlement -> Pass.
Repeatable consumable -> Developer Product.

One MonetizationService owns MarketplaceService.ProcessReceipt.

Never grant developer products based only on purchase-finished UI events.

## Cleanup

Controllers/components that create temporary events, instances or tasks
must clean them through Trove.

Avoid uncontrolled permanent Heartbeat/RenderStepped connections.

## Development commands

Use Cmdr instead of temporary debug GUIs.

Useful commands:
- cash
- give-species
- grow-all
- reset-plot
- set-weather
- unlock-slots
- inspect-profile

Production admin permissions must be restricted.

## Scope control

Do not introduce:
- a second UI framework
- a second networking framework
- an ECS
- an object pool
- a separate datastore framework
- a VFX framework
- a full game framework

unless profiling or game complexity demonstrates a real need.
```

That file is arguably **more valuable to AI-assisted development than another ten packages**, because it prevents the assistant from solving the same architectural question differently every time.

My practical install sequence would therefore be:

| Stage | Add |
|---|---|
| **Immediately** | Rokit, Wally |
| **First gameplay code** | ProfileStore, Trove |
| **Object architecture** | Component, CollectionService tags |
| **Networking** | TypedRemote + strict server validation |
| **UI** | Fusion + UI Labs |
| **Development productivity** | Cmdr |
| **Polish** | Shake and possibly Ripple |
| **Only if needed later** | ZonePlus, Replica, Promise, ByteNet |
| **Do not adopt for this new project** | Aftman, TestEZ as your main testing stack, Zap while the rewrite is in flux |

This leaves you with a deliberately small core of roughly **six meaningful runtime/development dependencies**, while Roblox itself handles animation, VFX, lighting, particles, beams, monetisation, analytics, multiplayer simulation and profiling. That division is well suited to your cosy 8–20 minute farming/collection loop: third-party code handles the repetitive software-engineering problems, while Roblox handles the engine problems. citeturn25view3turn29view1turn29view2turn22view3turn22view0turn27view1turn27view2turn29view0