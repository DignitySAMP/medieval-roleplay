#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_WORK,"How do I repair a house?","~w~Buildings weather a little every day, and storms and fires knock them about. Stand by the walls of one in need of repair and press ~y~Y~w~ to set out the work: it's posted on the boards. Bring the materials to its stockpile, then take turns at the work there. Use a hammer for timber and roof patches, or a chisel for stone. Anyone can clear worn roofing or mix mortar.",true);
	Help_Register(HELP_SECTION_WORK,"Why tend the roof?","~w~Choose Tend the roof at the building site to repair its timbers and covering. The building looks the same when you finish. Roof care prevents fires from lightning and dropped torches, and halves the chance of fire spreading from nearby buildings. Whoever holds a room in the house, a priest or the county's lord can set out this work.",false);
	Command_Describe("build","Staff: list building works, set a building's condition or roof, start, advance, finish or stop work, weather everything.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Build_PromptContext");
	SetTimer("Build_PromptTick",BUILD_PROMPT_MS,true);
	Boot_RegisterLoader("Build_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("construction-1-condition","ALTER TABLE buildings ADD COLUMN IF NOT EXISTS `condition` TINYINT NOT NULL DEFAULT 100, ADD COLUMN IF NOT EXISTS roof TINYINT NOT NULL DEFAULT 0");
	Migration_Add("construction-2-projects","CREATE TABLE IF NOT EXISTS build_projects (id INT UNSIGNED NOT NULL AUTO_INCREMENT, building_key VARCHAR(16) NOT NULL, kind TINYINT NOT NULL, commissioned_by INT UNSIGNED NOT NULL DEFAULT 0, stockpile_container_id INT NOT NULL DEFAULT 0, stage TINYINT NOT NULL DEFAULT 0, state TINYINT NOT NULL DEFAULT 0, created_at INT NOT NULL, done_at INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("construction-3-stages","CREATE TABLE IF NOT EXISTS project_stages (project_id INT UNSIGNED NOT NULL, idx TINYINT NOT NULL, stage TINYINT NOT NULL, need INT NOT NULL, done INT NOT NULL DEFAULT 0, PRIMARY KEY (project_id, idx)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("construction-4-labour","CREATE TABLE IF NOT EXISTS project_labour (project_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, scenes INT NOT NULL DEFAULT 0, PRIMARY KEY (project_id, character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("construction-5-roof-notices","UPDATE notices SET title = 'Work wanted: Tend the roof' WHERE BINARY title = 'Work wanted: A tiled roof' AND text LIKE 'Building work at %. Bring % to the stockpile there and lend a hand.'");
}

forward Build_LoadOnBoot();

public Build_LoadOnBoot()
{
	new projects = await Build_Load();
	Log_Info("construction","%d building works under way",projects);
	Boot_LoaderDone();
	return 1;
}
