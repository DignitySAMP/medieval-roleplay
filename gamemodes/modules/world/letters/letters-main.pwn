#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I write a letter?","~w~You need a ~y~parchment sheet~w~, an ~y~ink pot~w~ and a ~y~quill~w~. Stand close to the courier's table and face it, then press ~y~Y~w~. You can also use the parchment in your bag. Address the letter, then click a line to write it. Fold it when you're done.~n~~n~A ~y~signet ring~w~ and ~y~wax~w~ seal it, and whoever opens it breaks your seal. Hand it over yourself, or give it to a ~y~courier~w~ at the courier's table in Talmberg or the church village for 3 pfennig. It reaches them within the hour, even if they're away.");
	Command_Describe("letter","Staff: get a writing kit, write a letter, make every letter on the road arrive now.");
	SetTimer("Letters_CourierTick",LETTERS_COURIER_TICK_MS,true);
	Boot_RegisterLoader("Letters_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("letters_writings","CREATE TABLE IF NOT EXISTS writings (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, author_character_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL DEFAULT 0, title VARCHAR(64) NOT NULL DEFAULT '', body TEXT NOT NULL, sealed_by INT UNSIGNED NULL, seal_broken TINYINT NOT NULL DEFAULT 0, created_at INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Letters_AddDataMigrations();
	Migration_Add("letters_couriers","CREATE TABLE IF NOT EXISTS couriers (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, letter_writing_id INT UNSIGNED NOT NULL, item SMALLINT NOT NULL, from_character_id INT UNSIGNED NOT NULL DEFAULT 0, from_x FLOAT NOT NULL DEFAULT 0, from_y FLOAT NOT NULL DEFAULT 0, to_character_id INT UNSIGNED NOT NULL, due_at INT NOT NULL, state TINYINT NOT NULL DEFAULT 0, KEY pending (state, due_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

static Letters_AddDataMigrations()
{
	new const tables[][] = {"character_items", "container_items", "dropped_items", "claims"};
	new const params[] = {ITEM_LETTER, ITEM_LETTER_SEALED, ITEM_LETTER_OPENED};
	new key[MIGRATION_KEY_LEN], sql[160];

	for (new i = 0;i < sizeof(tables);i++)
	{
		format(key,sizeof(key),"letters-data-%s",tables[i]);
		Inventory_FormatWearToData(sql,tables[i],params,sizeof(params));
		Migration_Add(key,sql);
	}
}

forward Letters_LoadOnBoot();

public Letters_LoadOnBoot()
{
	Letters_PlacePosts();
	Log_Info("letters","%d courier tables",LETTERS_SEED_POSTS);
	Boot_LoaderDone();
	return 1;
}
