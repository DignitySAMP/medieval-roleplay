#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"What do I do when a house burns?","~w~When the bell rings, take a ~y~bucket~w~ to a trough, a well or the river and press ~y~Y~w~ to fill it, then ~y~Y~w~ again by the fire to throw. Throws close together from several people put a fire out much faster. Don't stand in the flames, and get out of a house filling with smoke.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"What happens to a burnt house?","~w~A house left to burn is gutted: nobody can go in, what was in its chests is lost and the work stations in it stop. Anyone can pay the carpenters at its door, a gulden to the county, and it stands again by the next dawn.",false);
	Command_Describe("fire","Staff: list fires and set one alight, put it out, gut or rebuild a building, set its heat.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Fire_PromptContext");
	SetTimer("Fire_Tick",FIRE_TICK_MS,true);
	SetTimer("Fire_PromptTick",FIRE_PROMPT_MS,true);
	Boot_RegisterLoader("Fire_LoadOnBoot","Notices_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("fire-1-buildings","CREATE TABLE IF NOT EXISTS buildings (id INT UNSIGNED NOT NULL AUTO_INCREMENT, building_key VARCHAR(16) NOT NULL, county_id INT NULL, x FLOAT NOT NULL DEFAULT 0, y FLOAT NOT NULL DEFAULT 0, z FLOAT NOT NULL DEFAULT 0, radius FLOAT NOT NULL DEFAULT 0, flammable TINYINT NOT NULL DEFAULT 1, state TINYINT NOT NULL DEFAULT 0, burned_at INT NOT NULL DEFAULT 0, rebuild_paid TINYINT NOT NULL DEFAULT 0, workplace_id INT NULL, home_id INT NULL, PRIMARY KEY (id), UNIQUE KEY building_key (building_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("fire-2-fires","CREATE TABLE IF NOT EXISTS fires (id INT UNSIGNED NOT NULL AUTO_INCREMENT, building_key VARCHAR(16) NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, intensity TINYINT NOT NULL, started_at INT NOT NULL, cause TINYINT NOT NULL, arsonist INT UNSIGNED NOT NULL DEFAULT 0, ended_at INT NOT NULL DEFAULT 0, outcome TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Fire_LoadOnBoot();

public Fire_LoadOnBoot()
{
	new gutted = await Fire_Load();
	Log_Info("fire","%d buildings can burn, %d gutted",FIRE_SEED_BUILDINGS,gutted);
	Boot_LoaderDone();
	return 1;
}
