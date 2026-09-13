--!strict
-- Crop extension point. Only Coconut is playable in this prototype.
local SpeciesConfig = {
	Coconut = {
		DisplayName = "Coconut",
		SellValueKey = "Coconut",
		FutureSeeds = false,
	},
}

return table.freeze(SpeciesConfig)
