#include <pp-hooks>

hook OnGameModeInit()
{
    AnimPreload_Register("BEACH");
    AnimPreload_Register("INT_OFFICE");
	Help_Register(HELP_SECTION_WORK,"How do I move goods?","~w~A ~y~handcart~w~ you pull on foot: use it from your bag to set it down, press ~y~Y~w~ beside it and pick Pull it. It trails behind you; walk, don't run. A ~y~horse cart~w~ you hitch: ride up to its shafts and press ~y~Y~w~; get down to leave it standing.~n~~n~Both carry a load you open with ~y~Y~w~. Lock it if you leave it. Taking someone else's cart is theft, and people see it.");
	Command_Describe("cart","Staff: spawn a cart of any kind, count them, remove the one near you.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Carts_PromptContext");
	SetTimer("Carts_Tick",CARTS_TICK_MS,true);
	SetTimer("Carts_PromptTick",500,true);
	Boot_RegisterLoader("Carts_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("transport_carts","CREATE TABLE IF NOT EXISTS carts (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, kind TINYINT NOT NULL, owner_character_id INT UNSIGNED NOT NULL DEFAULT 0, container_id INT UNSIGNED NOT NULL DEFAULT 0, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, locked TINYINT NOT NULL DEFAULT 0, hitched_mount_id INT UNSIGNED NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Carts_LoadOnBoot();

public Carts_LoadOnBoot()
{
	new loaded = await Carts_LoadAll();
	Log_Info("carts","%d carts",loaded);
	Boot_LoaderDone();
	return 1;
}
