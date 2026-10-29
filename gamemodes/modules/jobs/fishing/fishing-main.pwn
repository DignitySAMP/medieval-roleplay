#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_WORK,"How do I fish?","~w~You need a ~y~fishing rod~w~ and ~y~bait~w~ in your bag: worms, grubs, maggots, bread, a cut of meat or a small fish. With a rod you see ripples on fishing spots. Face one from the bank and press ~y~Y~w~.~n~~n~Bait the hook, cast, wait for a bite, strike when the float dips, reel it in and land it. What bites depends on the water, the season, the hour, the moon and your bait.~n~~n~~r~Raw fish goes off within an hour.~w~ Cook, salt or smoke it.");
	Fishing_RegisterItems();
	Work_SetKindRule(FISHING_NODE_KIND,ITEM_FISHING_ROD,FISHING_CAST_MAX);
	Work_SetKindFx(FISHING_NODE_KIND,g_FishingRippleModels,sizeof(g_FishingRippleModels),FISHING_RIPPLE_LIFT);
	Command_Describe("fishspot","Staff: place a fishing spot on the water in front of you.");
	Boot_RegisterLoader("Fishing_SeedOnBoot","Work_LoadNodesOnBoot");
	Log_Info("fishing","map water: %d cells in %d bodies",sizeof(g_FishingWaterCells),FISHING_WATER_BODIES);
}

hook OnMigrationRun()
{
	Migration_Add("fishing-1-records", "CREATE TABLE IF NOT EXISTS fishing_records (item INT NOT NULL, character_id INT UNSIGNED NOT NULL, grams INT NOT NULL, caught_at DATETIME NOT NULL, PRIMARY KEY (item)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Fishing_SeedOnBoot();

public Fishing_SeedOnBoot()
{
	yield 1;

	new sown = await Fishing_SeedSpots();

	if (sown > 0)
	{
		Log_Info("fishing","%d fishing spot(s) seeded",sown);
	}

	Boot_LoaderDone();
}
