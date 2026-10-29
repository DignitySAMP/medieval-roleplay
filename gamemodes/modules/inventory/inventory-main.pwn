#include <pp-hooks>

hook OnGameModeInit()
{
    Help_Register(HELP_SECTION_START,"How do I open and use my bag?","~w~Press ~y~N~w~ while on foot and out of combat to open your bag. Click an item to see its actions. Food has ~y~Eat~w~, drinks have ~y~Drink~w~, Other actions include ~y~Use~w~, ~y~Carry it~w~ and ~y~Strap it on~w~. Pick ~y~Examine~w~ to read the item's details. Press ~y~ESC~w~ to close the panel.",true);
    Help_Register(HELP_SECTION_START,"How do I drop and pick up items?","~w~Open your bag with ~y~N~w~, click an item and choose ~y~Drop~w~ to leave it on the ground. Stand beside a dropped item and press ~y~Walk (left Alt)~w~ to pick it up. You'll need room in your bag.",false);
    Help_Register(HELP_SECTION_START,"How do I put things in a container?","~w~Open your bag with ~y~N~w~, click a container and choose ~y~Open~w~. Click an item inside to take it into your bag. Choose ~y~Put something in~w~, then click an item in your bag to store it. Baskets hold produce and creels hold fish and bait. A container needs a free slot and must accept the item.",false);
	SetTimer("Inventory_FreshTick",INVENTORY_FRESH_TICK_MS,true);
	Item_SetPerishable(ITEM_FISH,ITEM_FISH_FRESH_SECONDS,ITEM_SPOILED_FISH);
	Item_SetPerishable(ITEM_FISH_RARE,ITEM_FISH_FRESH_SECONDS,ITEM_SPOILED_FISH);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I give something to another player?","~w~Stand next to them, open your ~y~bag (N)~w~ and click the item. If someone is within arm's reach you'll see ~y~Give~w~ beside Use and Drop. Pick it, then pick who gets it.~n~~n~One item goes across at a time, with its stars and freshness. If their bag is full, you keep it.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I look closer at an item?","~w~Open your ~y~bag (N)~w~, click an item and pick ~y~Examine~w~. You'll see what kind of thing it is, its quality in stars, what it's worth and how fresh or worn it is.",false);
	Keys_RegisterContext(KEY_NO,KEYS_PRIO_MENU,"Inventory_KeyContext");
	Keys_RegisterContext(KEY_WALK,KEYS_PRIO_WORLD,"Drop_KeyContext");
	Boot_RegisterLoader("Drop_LoadOnBoot");
	Inventory_AddMenuButton("Claims","Claims_OpenMenuDeferred");
}

hook Models_OnRegister()
{
	for (new tier = 0;tier < COIN_TIER_COUNT;tier++)
	{
		Models_AddObject(g_CoinDefs[tier][E_COIN_DEF_MODEL],g_CoinDefs[tier][E_COIN_DEF_DFF],ITEM_COIN_TXD);
	}

	Models_AddObject(ITEM_WATER_SKIN_MODEL,ITEM_WATER_SKIN_DFF,ITEM_WATER_SKIN_TXD);
}

hook OnMigrationRun()
{
	Migration_Add("inventory-1-character-items", "CREATE TABLE IF NOT EXISTS character_items (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount TINYINT NOT NULL DEFAULT 1, PRIMARY KEY (id), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("inventory-2-dropped-items", "CREATE TABLE IF NOT EXISTS dropped_items (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, param INT NOT NULL, amount TINYINT NOT NULL DEFAULT 1, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, dropped_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("inventory-3-items-stars", "ALTER TABLE character_items ADD COLUMN IF NOT EXISTS stars TINYINT NOT NULL DEFAULT 1, MODIFY amount SMALLINT NOT NULL DEFAULT 1");
	Migration_Add("inventory-4-drops-stars", "ALTER TABLE dropped_items ADD COLUMN IF NOT EXISTS stars TINYINT NOT NULL DEFAULT 1, MODIFY amount SMALLINT NOT NULL DEFAULT 1");
	Migration_Add("inventory-5-containers", "CREATE TABLE IF NOT EXISTS containers (id INT UNSIGNED NOT NULL AUTO_INCREMENT, owner_type TINYINT NOT NULL, owner_id INT NOT NULL DEFAULT 0, slots TINYINT NOT NULL, label VARCHAR(32) NOT NULL DEFAULT '', PRIMARY KEY (id), KEY idx_owner (owner_type, owner_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("inventory-6-container-items", "CREATE TABLE IF NOT EXISTS container_items (id INT UNSIGNED NOT NULL AUTO_INCREMENT, container_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount SMALLINT NOT NULL DEFAULT 1, stars TINYINT NOT NULL DEFAULT 1, PRIMARY KEY (id), KEY idx_container (container_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("inventory-7-claims", "CREATE TABLE IF NOT EXISTS claims (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount SMALLINT NOT NULL DEFAULT 1, stars TINYINT NOT NULL DEFAULT 1, reason VARCHAR(32) NOT NULL DEFAULT '', expires_at DATETIME NOT NULL, PRIMARY KEY (id), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("inventory-8-items-used", "ALTER TABLE character_items ADD COLUMN IF NOT EXISTS used TINYINT NOT NULL DEFAULT 0");
	Migration_Add("inventory-9-items-fresh-wear", "ALTER TABLE character_items ADD COLUMN IF NOT EXISTS fresh_at INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS wear TINYINT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-10-containers-fresh-wear", "ALTER TABLE container_items ADD COLUMN IF NOT EXISTS fresh_at INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS wear TINYINT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-11-drops-fresh-wear", "ALTER TABLE dropped_items ADD COLUMN IF NOT EXISTS fresh_at INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS wear TINYINT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-12-claims-fresh-wear", "ALTER TABLE claims ADD COLUMN IF NOT EXISTS fresh_at INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS wear TINYINT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-13-containers-label", "ALTER TABLE containers MODIFY label VARCHAR(64) NOT NULL DEFAULT ''");
	Migration_Add("inventory-14-items-data", "ALTER TABLE character_items ADD COLUMN IF NOT EXISTS data INT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-15-containers-data", "ALTER TABLE container_items ADD COLUMN IF NOT EXISTS data INT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-16-drops-data", "ALTER TABLE dropped_items ADD COLUMN IF NOT EXISTS data INT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-17-claims-data", "ALTER TABLE claims ADD COLUMN IF NOT EXISTS data INT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("inventory-18-drops-interior", "ALTER TABLE dropped_items ADD COLUMN IF NOT EXISTS interior INT NOT NULL DEFAULT -1");
}
