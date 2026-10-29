#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"Why do flies follow me?","~w~You stink. Sweat, work, blood and the odd rotten cabbage make you dirty over time. When you stink, flies follow you, people see it over your head, villagers remark on it, shopkeepers charge you more and families won't have you at their table once you reek.~n~~n~Wash at a ~y~washtub~w~ (the market, the church village, the guardhouse) or in a river. The character panel shows how clean you are.");
	Command_Describe("dirt","Staff: read or set your own dirt (0-100).");
	SetTimer("Hygiene_Tick",HYGIENE_TICK_MS,true);
	SetTimer("Hygiene_FliesTick",HYGIENE_FLIES_MS,true);
}

hook Models_OnRegister()
{
	Models_AddObject(MODEL_HYGIENE_FLIES,"hygiene/flies.dff","light/light.txd",MAP_BASE_STATIC);
}

hook OnMigrationRun()
{
	Migration_Add("hygiene_hygiene","CREATE TABLE IF NOT EXISTS hygiene (character_id INT UNSIGNED NOT NULL PRIMARY KEY, dirt TINYINT UNSIGNED NOT NULL DEFAULT 0, updated_at INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
