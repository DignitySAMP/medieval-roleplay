#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_FAITH,"What happens to the dead?","~w~A character who dies for good is buried in the ~y~nearest graveyard~w~ with a free plot. The grave shows their name, their dates and what took them. When the graveyards are full, they are laid in a niche in the ~y~crypt~w~.~n~~n~The bell tolls and the crier names the day. About an hour and a half later the priest holds the ~y~funeral~w~ at the grave. Anyone may come.");
	Help_Register(HELP_SECTION_FAITH,"How do I visit a grave?","~w~Stand at the grave or the niche and press ~y~Y~w~. You can light a ~y~candle~w~ (you need a candle and a flame), lay a posy of flowers once a day, or say a prayer for them.",false);
	Command_Describe("grave","Staff: mark graveyard plots, bury, settle, set the marker, hold a funeral now.");
	Command_Describe("crypt","Staff: place the crypt door, go in, grow it, seal test niches.");
	Boot_RegisterLoader("Graves_LoadOnBoot");
	Boot_RegisterLoader("Crypt_LoadOnBoot");
	Boot_RegisterLoader("Funeral_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Graves_PromptContext");
	SetTimer("Graves_Tick",GRAVES_TICK_MS,true);
	SetTimer("Graves_PromptTick",GRAVES_PROMPT_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("graves-1-plots", "CREATE TABLE IF NOT EXISTS graves (id INT UNSIGNED NOT NULL AUTO_INCREMENT, yard_key VARCHAR(24) NOT NULL, plot SMALLINT NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, character_id INT UNSIGNED NULL, marker TINYINT NOT NULL DEFAULT 0, dug_at INT NOT NULL DEFAULT 0, settled TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("graves-2-crypts", "CREATE TABLE IF NOT EXISTS crypts (id INT UNSIGNED NOT NULL AUTO_INCREMENT, crypt_key VARCHAR(24) NOT NULL, door_x FLOAT NOT NULL, door_y FLOAT NOT NULL, door_z FLOAT NOT NULL, door_a FLOAT NOT NULL, door_world INT NOT NULL DEFAULT 0, door_interior INT NOT NULL DEFAULT 0, chambers TINYINT NOT NULL DEFAULT 1, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    Migration_Add("graves-5-parish-door", "UPDATE crypts SET door_x = 1035.088, door_y = -3144.940, door_z = 40.967 WHERE crypt_key = 'parish' AND door_world = 0 AND door_interior = 0 AND ABS(door_x - 1033.778) < 0.02 AND ABS(door_y + 3145.858) < 0.02");
	Migration_Add("graves-3-niches", "CREATE TABLE IF NOT EXISTS crypt_niches (id INT UNSIGNED NOT NULL AUTO_INCREMENT, crypt_id INT UNSIGNED NOT NULL, niche SMALLINT NOT NULL, character_id INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (id), UNIQUE KEY uq_niche (crypt_id, niche), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("graves-4-funerals", "CREATE TABLE IF NOT EXISTS funerals (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, grave_id INT UNSIGNED NULL, niche_id INT UNSIGNED NULL, scheduled_at INT NOT NULL, held TINYINT NOT NULL DEFAULT 0, attendees SMALLINT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY idx_pending (held, scheduled_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
