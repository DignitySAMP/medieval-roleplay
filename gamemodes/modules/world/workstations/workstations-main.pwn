#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_WORK,"How do I make things?","~w~You make things at ~y~stations~w~. Open ~y~Crafting~w~ in your bag to see which ones you can build and what they need.~n~~n~New stations cost ~y~talent points~w~. You earn one for every half hour you play. Stations run on ~y~fuel~w~. If it runs out, the station burns out and you only get half its materials back.");
	Help_Register(HELP_SECTION_WORK,"How does work at a station go?","~w~Working at a station is done by hand. Press the ~y~keys it shows~w~, in order and on time. Doing it well gives you better goods and raises your ~y~trade~w~ level.");
	Help_Register(HELP_SECTION_WORK,"Why can't I see sparks on herbs or ore?","~w~Sparks mark a gathering spot that still has something to take. Trunks, herb patches, fruit bushes, ore seams, clay pits and wild hives only show them once you've learned that trade's ~y~eye~w~ talent, like the Herbalist's eye.~n~~n~You learn it in your bag (~y~N~w~) > Crafting > Talents.");
	Help_Register(HELP_SECTION_WORK,"Where do I make remedies, butter and cheese?","~w~Remedies, ink and poisons are made at the ~y~herbalist's table~w~. Butter is churned at the ~y~butter churn~w~ and cheese is pressed at the ~y~cheese press~w~.~n~~n~Learn each one in your bag (~y~N~w~) > Crafting > Talents, then build it under Stations.");
	Help_Register(HELP_SECTION_WORK,"What are the market stall and the herald's table?","~w~Both are stations you can build once you've learned them under Merchant. Selling from the stall isn't ready yet. At the herald's table you can sign the roll, which only counts towards your merchant level for now.",false);
	Help_Register(HELP_SECTION_WORK,"Where do I find herbs?","~w~Herbs grow wild in meadows, along forest edges, under the trees, by the water and just outside the villages. What grows depends on the ~y~season~w~: the chamomile in a summer meadow is gone by winter, when only willow by the water is left.~n~~n~Walk up to a plant and press ~y~Y~w~ to gather it. You need a ~y~knife~w~.");
	Help_Register(HELP_SECTION_WORK,"Why did I pick the wrong herb?","~w~Some plants look alike. Wild carrot and hemlock pass for yarrow, foxglove for comfrey, mayweed for chamomile and nightshade berries for bilberries. Until you reach ~y~herbalist level 3~w~ you see the name of the plant it looks like, and you only find out what you picked once it's in your bag.~n~~n~Poisonous and useless plants don't go into remedies.");
	Help_Register(HELP_SECTION_WORK,"When can I find moonwort and wolfsbane?","~w~Only on ~y~full-moon nights~w~. Moonwort comes up in meadows and forests from spring to autumn. Wolfsbane only grows by rocks and water on the full moon of the ~y~Wolf Moon~w~, in January. Both wither at dawn.");
	Help_Register(HELP_SECTION_WORK,"Which herbs go into a poultice or tincture?","~w~Any healing herb: yarrow, ribwort plantain, comfrey, willow bark, chamomile, St John's wort, stinging nettle, valerian, water mint, wormwood, mugwort, betony, agrimony, elderflower and wild garlic. Bundles of ~y~Common herbs~w~ still count too.",false);
	Work_RegisterHerbItems();
	Character_RegisterBusyCheck("Work_BusyCheck");
	Command_Describe("station","Staff: station tools and test supplies.");
	Command_Describe("node","Staff: gathering node tools.");
	Command_Describe("workpanel","Staff: show the work panel for testing.");
	Boot_RegisterLoader("Work_LoadStationsOnBoot");
	Boot_RegisterLoader("Work_LoadNodesOnBoot");
	Boot_RegisterLoader("Work_LoadWildOnBoot");
	Boot_RegisterLoader("Work_LoadMoonHerbsOnBoot");
	Boot_RegisterLoader("Work_LoadHerbDriftsOnBoot");
	AnimPreload_Register("BOMBER");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Work_KeyContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Keys_RegisterContext(KEY_NO,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Keys_RegisterContext(KEY_CTRL_BACK,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Keys_RegisterContext(KEY_SPRINT,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Keys_RegisterContext(KEY_SECONDARY_ATTACK,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Keys_RegisterContext(KEY_WALK,KEYS_PRIO_SCENE,"Work_SceneKeyContext");
	Timer_Start(Work_PromptTick,WORK_PROMPT_MS);
	Timer_Start(Work_BurnTick,WORK_BURN_TICK_MS);
	Inventory_AddMenuButton("Crafting","Craft_OpenDeferred");
	Log_Info("workstations","%d station and node kind(s)",Work_GetKindCount());
}

hook Models_OnRegister()
{
	Models_AddObject(MODEL_UI_GLYPHS,"ui/sprite_model.dff","ui/ui_glyphs.txd");

	for (new i = 0;i < WORK_PART_COUNT;i++)
	{
		if (g_WorkPartDefs[i][E_WORK_PART_DEF_MODEL] != 0)
		{
			Models_AddObject(g_WorkPartDefs[i][E_WORK_PART_DEF_MODEL],g_WorkPartDefs[i][E_WORK_PART_DEF_DFF],strfind(g_WorkPartDefs[i][E_WORK_PART_DEF_DFF],WORK_NEXT_FOLDER) == 0 ? WORK_NEXT_TXD : WORK_PART_TXD,MAP_BASE_STATIC);
		}
	}

	for (new i = 0;i < WORK_NODE_STAGE_COUNT;i++)
	{
		if (g_WorkNodeStageDefs[i][E_WORK_NODE_STAGE_DEF_MODEL] != 0)
		{
			Models_AddObject(g_WorkNodeStageDefs[i][E_WORK_NODE_STAGE_DEF_MODEL],g_WorkNodeStageDefs[i][E_WORK_NODE_STAGE_DEF_DFF],WORK_PART_TXD,g_WorkNodeStageDefs[i][E_WORK_NODE_STAGE_DEF_BASE]);
		}
	}
}

hook OnMigrationRun()
{
	Migration_Add("workstations-1-stations", "CREATE TABLE IF NOT EXISTS stations (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind VARCHAR(16) NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, stand_x FLOAT NOT NULL, stand_y FLOAT NOT NULL, stand_z FLOAT NOT NULL, stand_a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, workplace_id INT UNSIGNED NULL, shot_dist FLOAT NOT NULL DEFAULT 1, shot_lift FLOAT NOT NULL DEFAULT 0, shot_aim FLOAT NOT NULL DEFAULT 0, shot_side FLOAT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-2-work-nodes", "CREATE TABLE IF NOT EXISTS work_nodes (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind VARCHAR(16) NOT NULL, species SMALLINT NOT NULL DEFAULT 0, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, stock SMALLINT NOT NULL, max_stock SMALLINT NOT NULL, regrow_left SMALLINT NOT NULL DEFAULT 0, holder_character_id INT UNSIGNED NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-3-job-levels", "CREATE TABLE IF NOT EXISTS job_levels (character_id INT UNSIGNED NOT NULL, trade TINYINT NOT NULL, level TINYINT NOT NULL DEFAULT 1, practice INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, trade)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-10-job-mastered", "ALTER TABLE job_levels ADD COLUMN IF NOT EXISTS mastered TINYINT NOT NULL DEFAULT 0");
	Migration_Add("workstations-5-station-owners", "ALTER TABLE stations ADD COLUMN IF NOT EXISTS owner_character_id INT UNSIGNED NULL, ADD COLUMN IF NOT EXISTS placed_at INT NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS grace_until INT NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS fuel_item INT NOT NULL DEFAULT -1, ADD COLUMN IF NOT EXISTS fuel_units SMALLINT NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS fuel_seconds INT NOT NULL DEFAULT 0");
	Migration_Add("workstations-8-kind-views", "CREATE TABLE IF NOT EXISTS station_kind_views (kind VARCHAR(16) NOT NULL, stand_right FLOAT NOT NULL, stand_ahead FLOAT NOT NULL, stand_lift FLOAT NOT NULL, stand_turn FLOAT NOT NULL, shot_dist FLOAT NOT NULL, shot_lift FLOAT NOT NULL, shot_aim FLOAT NOT NULL, shot_side FLOAT NOT NULL, PRIMARY KEY (kind)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-7-node-spots", "ALTER TABLE work_nodes ADD COLUMN IF NOT EXISTS spot SMALLINT NOT NULL DEFAULT -1");
	Migration_Add("workstations-6-station-invites", "CREATE TABLE IF NOT EXISTS station_invites (station_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, PRIMARY KEY (station_id, character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-4-work-reservations", "CREATE TABLE IF NOT EXISTS work_reservations (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount INT NOT NULL, stars TINYINT NOT NULL, PRIMARY KEY (id), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("workstations-9-reservations-fresh", "ALTER TABLE work_reservations ADD COLUMN IF NOT EXISTS fresh_at INT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("workstations-11-account-settings", "CREATE TABLE IF NOT EXISTS account_settings (account_id INT UNSIGNED NOT NULL, setting VARCHAR(32) NOT NULL, value INT NOT NULL, PRIMARY KEY (account_id, setting)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
