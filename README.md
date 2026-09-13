# Grow an Island

A single-player-per-server, runtime-generated Roblox tropical island tycoon. Rojo syncs only code; the server builds the island, ocean Terrain water, decorations, shelters, coconut systems, dive chests, and all interaction parts at startup beneath Workspace.GrowAnIslandWorld.

## Play loop

1. Spend the starting $25 on the fixed coconut palm site.
2. Hand-collect the server-spawned coconuts and sell them at the outdoor market.
3. Build the travelator for visible, automatic coconut sales.
4. Dive for modest, server-rolled treasure rewards while managing the exact 10-second base oxygen supply.
5. Buy adjacent island markers, each of which receives one server-rolled, persisted visual biome.
6. Build camp, then hut, then the finished tropical shelter; complete the island, then Rebirth for permanent income efficiency.

All balance values and extension points live in src/shared/Config/EconomyConfig.luau. Coconuts are intentionally the only crop in this first playable; no products, passes, MarketplaceService calls, combat, bananas, or multiplayer island systems are included.

## Studio / publishing setup

- Sync default.project.json with Rojo into a blank place.
- Set the published experience **Max Players to 1** in Game Settings. The server independently enforces MAX_ACTIVE_PLAYERS = 1 and politely removes additional arrivals.
- For live persistence, enable Studio API Services only when you want to test live datastore behaviour. Studio otherwise uses ProfileStore's session-owning mock store; live servers use GrowAnIsland_PlayerData_v1.
- No workspace placement, imported assets, plugins, or external asset IDs are required.

## Authority

Clients only send narrow requests with allowlisted IDs. The server independently validates profile readiness, owner identity, cooldowns, server-measured distances, tagged object identity, capacity, currency, prerequisites, tile adjacency, chest availability, oxygen, rewards, biome rolls, and rebirth conditions. ProfileStore is accessed only by DataService.
