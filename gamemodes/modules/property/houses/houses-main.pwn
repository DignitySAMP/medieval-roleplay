#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"How do I get a home?","~w~Families in the villages let rooms. Go to the ~y~county register~w~ in the reeve's clerk's house in Talmberg and ask the steward. A room costs a season's rent up front.~n~~n~Your room has a ~y~chest~w~ and a bed, and its house door opens for you at night. You can share it with one other person and furnish it with your own chairs, chests and barrels.");
	Help_Register(HELP_SECTION_SURVIVAL,"Why is it so dark inside?","~w~At night the hearth goes out and a house is dark unless a ~y~candle~w~ burns. Stand where a candle belongs and press ~y~Y~w~ to light one, or carry your own light.",false);
	Help_Register(HELP_SECTION_SURVIVAL,"What happens if I don't pay the rent?","~w~When your paid seasons run out, or you don't come back for three weeks, the room goes back to the county. Everything in your chest and your furniture waits for you under ~y~Claims~w~ in your bag.",false);
	Command_Describe("house","Staff: list houses and rooms, go to a house, light its hearth, grant or free a room.");
	Character_RegisterBusyCheck("Houses_BusyCheck");
	Boot_RegisterLoader("Houses_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Houses_PromptContext");
    Keys_RegisterContext(KEY_YES,HOUSE_EXIT_KEY_PRIO,"Houses_ExitContext");
	AnimPreload_Register("INT_HOUSE");
	Houses_FindRegister();
	SetTimer("Houses_PromptTick",HOUSE_PROMPT_MS,true);
	SetTimer("Houses_DarkTick",2000,true);
	SetTimer("Houses_Tick",HOUSE_TICK_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("houses-1-holds", "CREATE TABLE IF NOT EXISTS home_holds (id INT UNSIGNED NOT NULL AUTO_INCREMENT, room_key VARCHAR(48) NOT NULL, character_id INT UNSIGNED NOT NULL, co_character_id INT UNSIGNED NOT NULL DEFAULT 0, since INT NOT NULL, paid_until INT NOT NULL, active_at INT NOT NULL, chest_id INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (id), UNIQUE KEY uq_room (room_key), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("houses-2-furniture", "CREATE TABLE IF NOT EXISTS home_furniture (id INT UNSIGNED NOT NULL AUTO_INCREMENT, room_key VARCHAR(48) NOT NULL, item INT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rx FLOAT NOT NULL, ry FLOAT NOT NULL, rz FLOAT NOT NULL, PRIMARY KEY (id), KEY idx_room (room_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
