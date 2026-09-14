# Instructions for coding agents

## First action

Read PROJECT_STACK.md completely before changing this project. It is the binding architecture and map contract.

## Core stack

- Use Rojo, Rokit, and Wally.
- Approved libraries: ProfileStore, Trove, Component, TypedRemote, Fusion, Cmdr.
- Do not introduce another framework or a third-party map/animation dependency without asking.
- Use --!strict for Luau modules.
- Use Fusion for UI.
- Prefer Roblox built-ins for TweenService, Lighting, ParticleEmitter, Beam, Animation, and MarketplaceService.
- Only DataService may access ProfileStore.
- Clients request; the server validates and decides.

## Map-first rules

This project is migrating from a procedural WorldBuilder to hand-authored Studio templates.

- The creator owns all map visuals: islands, terrain, water, props, buildings, upgrade appearances, and their placement.
- Server code may clone, validate, reveal, tween, enable, disable, and connect that content. It must not create replacement visual geometry or terrain with code.
- ServerStorage.GrowAnIslandMapLibrary is protected source content. Runtime code must never mutate, reparent, clear, or destroy it.
- Workspace.GrowAnIslandWorld is a disposable runtime clone. Code may create/destroy only this root and its runtime children.
- Roblox Terrain cannot live inside a cloneable ServerStorage model. Use creator-made Parts/MeshParts for template-loaded and reveal-animated islands. If hand-sculpted Workspace.Terrain exists, treat it as persistent source content and never clear, clone, or generate it.
- The current milestone is one authored starter island/grid. Do not add or retain new generated-grid, random-biome, or procedural-island behavior.
- Do not extend the legacy WorldBuilder except for a tightly scoped, reviewed migration/removal step. New map work belongs in the template-backed services described in PROJECT_STACK.md.
- Never delete legacy runtime generation until the equivalent template-backed behavior is implemented and verified.

## Tags and authored objects

- Use CollectionService tags plus documented attributes; do not depend on hardcoded Workspace paths, arbitrary Explorer names, or hand-entered world coordinates for authored map objects.
- Resolve tagged objects only after confirming they descend from the active runtime map root. A global tag query is not authorization to use an object.
- Follow the exact tag/attribute names and cardinality in PROJECT_STACK.md.
- When adding a map marker, interaction, persistent feature, tag, attribute, or action ID, update PROJECT_STACK.md and README.md in the same change.
- Map validation must fail loudly and repairably for missing, duplicate, wrong-type, or malformed markers. Do not silently substitute a guessed coordinate or a generated placeholder.
- Dynamic pickups, chests, and VFX belong only in validated RuntimeContainers in the runtime clone.
- For progress, select and animate creator-made ProgressVariants. Do not build the visual stages from parts in code.

## Map and Studio safety

- Do not change the Rojo project to own Workspace or ServerStorage map art without the creator’s explicit approval.
- Do not overwrite, remove, or reorganize map templates while implementing code.
- Do not import or execute scripts from Toolbox/free models/plugins without explicit user approval and review.
- A coding agent cannot claim to see or change Studio content unless a live Studio MCP connection has been confirmed for the current session.
- If the user says they built a Studio feature, ask for its tag/attributes, an Explorer screenshot or manifest, and the intended behavior before assuming its structure.

## Server authority

For every player-triggered map interaction or future island animation, validate server-side:

- owner/profile readiness and cooldown;
- active-runtime-map ancestry, tag identity, and required attributes;
- server-measured distance;
- currency, prerequisites, capacity, and saved unlock state;
- allowlisted action/template/reveal values; and
- all profile mutations through DataService.

Never accept a client-chosen map model, CFrame, animation duration, reward, action ID, template ID, biome, or persistent state.

## Before editing

1. Inspect git status and preserve unrelated user changes.
2. Read the relevant code and PROJECT_STACK.md.
3. For map work, identify whether the task is legacy behavior, template-loader migration, map validation, progress visuals, or a future-island reveal.
4. State any architecture assumption that would change the creator’s authored content or save schema before making that change.

## Before handoff

- Run relevant formatting, typechecking, and tests.
- For map changes, verify source templates are untouched and playtest the disposable runtime clone.
- Test invalid marker cases, not only the happy path.
- Report changed files, validation performed, and any Studio steps the creator must perform.
