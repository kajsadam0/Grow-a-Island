--!strict

export type TileBiomeMap = { [string]: string }

export type TutorialState = {
	PalmBought: boolean,
	Collected: boolean,
	Sold: boolean,
	TravelatorBought: boolean,
	TreasureFound: boolean,
	Expanded: boolean,
}

export type PlayerData = {
	SchemaVersion: number,
	Coins: number,
	CoconutPalmPurchased: boolean,
	TravelatorPurchased: boolean,
	CarriedCoconuts: number,
	StoredCoconuts: number,
	OxygenUpgradeLevel: number,
	ShelterLevel: number,
	PurchasedTiles: TileBiomeMap,
	Tutorial: TutorialState,
	RebirthCount: number,
	RebirthMultiplier: number,
}

export type ClientState = {
	Ready: boolean,
	Coins: number,
	CarriedCoconuts: number,
	CarryCapacity: number,
	StoredCoconuts: number,
	StorageCapacity: number,
	Oxygen: number,
	OxygenMaximum: number,
	Underwater: boolean,
	OxygenUpgradeLevel: number,
	ShelterLevel: number,
	CoconutPalmPurchased: boolean,
	TravelatorPurchased: boolean,
	PurchasedTiles: TileBiomeMap,
	RebirthCount: number,
	RebirthMultiplier: number,
	RebirthReady: boolean,
	Tutorial: TutorialState,
}

return {}
