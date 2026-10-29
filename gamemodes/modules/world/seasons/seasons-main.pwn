#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("season","Staff: turn the season's look to autumn, winter or none, or back to the calendar.");
    Help_Register(HELP_SECTION_SURVIVAL,"When do rivers freeze?","~w~In a hard winter, the rivers, lake and swamp pools freeze. You can walk over the ice, but you cannot fish or wash there until it thaws.",false);
	Boot_RegisterLoader("Seasons_LoadOnBoot");
	SetTimer("Seasons_Tick",SEASONS_TICK_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("seasons-1-world-seasons", "CREATE TABLE IF NOT EXISTS world_seasons (id TINYINT UNSIGNED NOT NULL, snow_minutes INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

hook Models_OnRegister()
{
	for (new i = 0;i < SEASONS_OVERLAY_COUNT;i++)
	{
		for (new step = 0;step < SEASONS_STEPS;step++)
		{
			if (g_SeasonsOverlays[i][E_SEASONS_OVERLAY_MODELS][step] != 0)
			{
				Models_AddObject(g_SeasonsOverlays[i][E_SEASONS_OVERLAY_MODELS][step],g_SeasonsOverlays[i][E_SEASONS_OVERLAY_FILE],g_SeasonsStepTxds[g_SeasonsOverlays[i][E_SEASONS_OVERLAY_TXDS][step]],MAP_BASE_BLEND);
                Map_RegisterLodVariant(g_SeasonsOverlays[i][E_SEASONS_OVERLAY_MODELS][step], g_SeasonsStepTxds[g_SeasonsOverlays[i][E_SEASONS_OVERLAY_TXDS][step]]);
			}
		}

		if (g_SeasonsOverlays[i][E_SEASONS_OVERLAY_DEEP_MODEL] != 0)
		{
			Models_AddObject(g_SeasonsOverlays[i][E_SEASONS_OVERLAY_DEEP_MODEL],g_SeasonsOverlays[i][E_SEASONS_OVERLAY_DEEP_FILE],g_SeasonsStepTxds[SEASONS_STEPS - 1],MAP_BASE_BLEND);
                Map_RegisterLodVariant(g_SeasonsOverlays[i][E_SEASONS_OVERLAY_DEEP_MODEL], g_SeasonsStepTxds[SEASONS_STEPS - 1]);
		}
	}
}
