#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"What is the gaol like?","~w~The gaol lies under the guardhouse. A prisoner gets hungry, thirsty and cold like anyone else, so friends and family bring food. Visitors may walk down to the cells. The cells stay locked: a guard on duty unlocks one with ~y~Y~w~ at its door, and it locks again when he walks away.~n~~n~Time counts in full while you play and at half while you're away. A desperate prisoner can work at the cell's ~y~grate~w~, a little at a time, but a guard nearby will hear it.",false);
	Boot_RegisterLoader("Gaol_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Gaol_PromptContext");
	SetTimer("Gaol_PromptTick",LAW_PROMPT_MS,true);
	SetTimer("Gaol_Tick",2000,true);
}

hook Models_OnRegister()
{
	Models_AddObject(MODEL_GAOL_WALL_DOOR,"gaol/gaol_wall_door.dff","gaol/gaol.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_GAOL_WALL_DOOR_SHUT,"gaol/gaol_wall_door_shut.dff","gaol/gaol.txd",MAP_BASE_STATIC);
	Models_AddObject(MODEL_GAOL_WALL_WINDOW,"gaol/gaol_wall_window.dff","gaol/gaol.txd",MAP_BASE_STATIC);
}

hook OnMigrationRun()
{
	Migration_Add("law-9-cells", "CREATE TABLE IF NOT EXISTS law_cells (cell TINYINT NOT NULL, progress TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (cell)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
