#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I join a guild or a band?","~w~Its members swear you in: a member allowed to invite stands beside you and asks, and you agree. You can be sworn to three groups at most, one of each kind. Your groups are under ~y~Groups~w~ in your character panel (~y~Sprint + Walk~w~).",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I found a guild?","~w~Three of one trade, each at level 4 or more, go to the steward in the ducal fortress together and ask for a charter. It costs a gulden, paid to the county. A household is founded there by a lord, a band for hire by anyone for ten groschen, an order at the church door by a prior, and an outlaw band at a cold fire pit deep in the woods.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"What can my group do?","~w~Every group has a roll with ranks, a treasury and a storehouse. The faction team grants more as the group earns it: a hall where members wake and keep their things, a board, duty and a livery, kit issued by rank, guild rules, contracts for hire. Group word is out of character only: type ~y~/g~w~ and your words.",false);
	Help_Register(HELP_SECTION_WORK,"How do I become a master of my trade?","~w~Level ten in a crafting trade needs a masterpiece: the trade's longest recipe, open at level nine (a feast cake, a folded longsword, a watertight tun, an illuminated book...). Make it at five stars and present it to your guild's masters; two of them must pass it. With no guild of your trade in the county, the steward in the ducal fortress judges it.",true);
	Help_Register(HELP_SECTION_WORK,"Why join a guild?","~w~Goods of the guild's trade at or above its standard sell under the guild's mark and fetch more from the traders. Working beside a master of your guild, you learn your trade faster.",true);
	Command_Describe("g","Out-of-character word to every member of your group online; pick which group in its panel.");
	Command_Describe("group","Faction team: list groups, grant features, review, add or remove members, judge masterpieces, close contracts, tune the tabard.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Groups_PromptContext");
	SetTimer("Groups_Tick",GROUPS_TICK_MS,true);
	SetTimer("Groups_TrainTick",GROUPS_TRAIN_MS,true);
	Boot_RegisterLoader("Groups_LoadOnBoot");

	for (new hideout = 0;hideout < GROUPS_SEED_HIDEOUTS;hideout++)
	{
		Work_KeepSpotsClear(g_GroupsHideouts[hideout][0],g_GroupsHideouts[hideout][1],g_GroupsHideouts[hideout][2],GROUPS_HIDEOUT_CLEAR);
	}
}

hook OnMigrationRun()
{
	Migration_Add("groups-1-groups","CREATE TABLE IF NOT EXISTS `groups` (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT NOT NULL, name VARCHAR(32) NOT NULL, county_id INT NULL, founder_character_id INT UNSIGNED NOT NULL DEFAULT 0, livery INT NOT NULL DEFAULT 0, treasury_container_id INT NOT NULL DEFAULT 0, store_container_id INT NOT NULL DEFAULT 0, chartered TINYINT NOT NULL DEFAULT 0, features INT NOT NULL DEFAULT 0, reviewed TINYINT NOT NULL DEFAULT 0, trade TINYINT NOT NULL DEFAULT -1, min_stars TINYINT NOT NULL DEFAULT 4, price_floor INT NOT NULL DEFAULT 80, price_ceiling INT NOT NULL DEFAULT 150, hall_x FLOAT NOT NULL DEFAULT 0, hall_y FLOAT NOT NULL DEFAULT 0, hall_z FLOAT NOT NULL DEFAULT 0, hall_a FLOAT NOT NULL DEFAULT 0, hall_world INT NOT NULL DEFAULT 0, hall_interior INT NOT NULL DEFAULT 0, hideout TINYINT NOT NULL DEFAULT -1, created_at INT NOT NULL, disbanded_at INT NULL, PRIMARY KEY (id), UNIQUE KEY name (name)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-2-members","CREATE TABLE IF NOT EXISTS group_members (group_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, `rank` TINYINT NOT NULL DEFAULT 0, joined_at INT NOT NULL, spawn_hall TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (group_id, character_id), KEY character_id (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-3-ranks","CREATE TABLE IF NOT EXISTS group_ranks (group_id INT UNSIGNED NOT NULL, `rank` TINYINT NOT NULL, name VARCHAR(20) NOT NULL, perms INT NOT NULL DEFAULT 0, PRIMARY KEY (group_id, `rank`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-4-contracts","CREATE TABLE IF NOT EXISTS contracts (id INT UNSIGNED NOT NULL AUTO_INCREMENT, group_id INT UNSIGNED NOT NULL, client_character_id INT UNSIGNED NOT NULL, terms VARCHAR(128) NOT NULL, pay INT NOT NULL, upfront INT NOT NULL DEFAULT 0, state TINYINT NOT NULL DEFAULT 0, created_at INT NOT NULL, settled_at INT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY group_id (group_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-5-notices","CREATE TABLE IF NOT EXISTS group_notices (id INT UNSIGNED NOT NULL AUTO_INCREMENT, group_id INT UNSIGNED NOT NULL, author_character_id INT UNSIGNED NOT NULL, text VARCHAR(144) NOT NULL, public TINYINT NOT NULL DEFAULT 0, posted_at INT NOT NULL, PRIMARY KEY (id), KEY group_id (group_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-6-kits","CREATE TABLE IF NOT EXISTS group_kits (group_id INT UNSIGNED NOT NULL, `rank` TINYINT NOT NULL, line TINYINT NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount INT NOT NULL, PRIMARY KEY (group_id, `rank`, line)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-7-issued","CREATE TABLE IF NOT EXISTS group_issued (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, group_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, amount INT NOT NULL, PRIMARY KEY (id), KEY character_id (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-8-masterpieces","CREATE TABLE IF NOT EXISTS group_masterpieces (id INT UNSIGNED NOT NULL AUTO_INCREMENT, group_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL, trade TINYINT NOT NULL, kind TINYINT NOT NULL, param INT NOT NULL, stars TINYINT NOT NULL, state TINYINT NOT NULL DEFAULT 0, votes_for TINYINT NOT NULL DEFAULT 0, votes_against TINYINT NOT NULL DEFAULT 0, voters VARCHAR(96) NOT NULL DEFAULT ',', returned TINYINT NOT NULL DEFAULT 0, created_at INT NOT NULL, PRIMARY KEY (id), KEY character_id (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("groups-9-log","CREATE TABLE IF NOT EXISTS group_log (id INT UNSIGNED NOT NULL AUTO_INCREMENT, group_id INT UNSIGNED NOT NULL, character_id INT UNSIGNED NOT NULL DEFAULT 0, what VARCHAR(144) NOT NULL, at INT NOT NULL, PRIMARY KEY (id), KEY group_id (group_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Groups_LoadOnBoot();

public Groups_LoadOnBoot()
{
	new count = await Groups_Load(), kits = await Groups_LoadKits(), marks = Groups_InitMarks();

	for (new hideout = 0;hideout < GROUPS_SEED_HIDEOUTS;hideout++)
	{
		Groups_RefreshHideout(hideout);
	}

	Log_Info("groups","%d groups, %d kit lines, %d goods marked by trade, %d hideouts",count,kits,marks,GROUPS_SEED_HIDEOUTS);
	Boot_LoaderDone();
	return 1;
}
