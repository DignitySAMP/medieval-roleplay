#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"What can I do at the pillory?","~w~Walk up to someone in the ~y~pillory~w~ or the ~y~stocks~w~ and press ~y~Y~w~. You can throw a rotten cabbage, jeer, or give them water. Setting them free is a crime unless you're a guard on duty.~n~~n~Time in the pillory only passes while the prisoner plays.",false);
	Boot_RegisterLoader("Pillory_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Pillory_PromptContext");
	AnimPreload_Register("GRENADE");
	SetTimer("Pillory_PromptTick",LAW_PROMPT_MS,true);
	SetTimer("Pillory_Tick",5000,true);
}

hook OnMigrationRun()
{
	Migration_Add("law-8-devices", "CREATE TABLE IF NOT EXISTS law_devices (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
