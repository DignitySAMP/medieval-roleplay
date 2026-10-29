#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_SURVIVAL,"How do I get a horse?","~w~Buy one from the ~y~horse trader~w~ at the Talmberg horse yard or the outer stable, or tame a wild one in the meadows: walk up slowly with a ~y~halter and rope~w~ and press ~y~Y~w~. The market ~y~traders~w~ sell the halter and rope. You also need one to lead a horse that isn't devoted to you yet. You can keep two horses.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"How do I look after my horse?","~w~Stand by it and press ~y~Y~w~. Feed it ~y~oats or hay~w~, water it at a trough or a stream, groom it with ~y~straw~w~, have it shod with a smith's ~y~horseshoes~w~ and put a ~y~blanket~w~ on it in winter. A hungry horse won't gallop for long. A starved one dies.",true);
	Help_Register(HELP_SECTION_SURVIVAL,"How do I call my horse?","~w~Hold ~y~F~w~ with no horse nearby. It comes from farther away the more it trusts you. Trust grows when you ride it, feed it and groom it every day.",true);
	Help_Register(HELP_SECTION_WORK,"What does a stable do?","~w~Talk to the keeper. A stabled horse is safe from thieves and the winter: 2 pfennig a day, 5 with feed. Pay when you fetch it; after ten unpaid days it's sold on. Keepers also treat sickness, geld stallions, read a horse's blood and arrange coverings.",false);
	Help_Register(HELP_SECTION_WORK,"How do I breed horses?","~w~Bring a mare in season to a stable keeper in spring or summer and book a covering with a stallion at stud there. She foals eleven days later; the foal follows her and is grown ten days after. Foals take their traits from both parents.",false);
	Help_Register(HELP_SECTION_WORK,"What are a horse's traits?","~w~Speed, stamina, health and temper, each in three steps. Horses can hide a weaker trait they pass to their foals. A keeper can read the hidden blood for a fee.",false);
	Command_Describe("horses","Staff: give or tame-test horses, set bond, needs and age, foal, kill, reroll the trader.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Horses_CarePromptContext");
	SetTimer("Horses_RideTick",1000,true);
	SetTimer("Horses_CareTick",500,true);
	SetTimer("Horses_HudTick",1000,true);
	SetTimer("Horses_SaveTick",HORSES_SAVE_MS,true);
	Boot_RegisterLoader("Horses_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("horses-1-horses","CREATE TABLE IF NOT EXISTS horses (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(24) NOT NULL DEFAULT '', owner_character_id INT UNSIGNED NULL, type TINYINT NOT NULL DEFAULT 0, sex TINYINT NOT NULL DEFAULT 0, breed TINYINT NOT NULL DEFAULT 0, sire_id INT UNSIGNED NULL, dam_id INT UNSIGNED NULL, inbred TINYINT NOT NULL DEFAULT 0, born_day INT NOT NULL DEFAULT 0, genes CHAR(20) NOT NULL DEFAULT '', proven SMALLINT NOT NULL DEFAULT 0, revealed TINYINT NOT NULL DEFAULT 0, bond TINYINT NOT NULL DEFAULT 0, hunger FLOAT NOT NULL DEFAULT 100, thirst FLOAT NOT NULL DEFAULT 100, condition_pct FLOAT NOT NULL DEFAULT 80, shoes_wear INT NOT NULL DEFAULT -1, needs_at INT NOT NULL DEFAULT 0, bond_day INT NOT NULL DEFAULT 0, gain_ride TINYINT NOT NULL DEFAULT 0, gain_feed TINYINT NOT NULL DEFAULT 0, groomed TINYINT NOT NULL DEFAULT 0, called TINYINT NOT NULL DEFAULT 0, forced TINYINT NOT NULL DEFAULT 0, touched_day INT NOT NULL DEFAULT 0, status TINYINT NOT NULL DEFAULT 0, location_kind TINYINT NOT NULL DEFAULT 0, stable_id INT UNSIGNED NULL, stabled_day INT NOT NULL DEFAULT 0, feed_included TINYINT NOT NULL DEFAULT 0, hold_until INT NOT NULL DEFAULT 0, saddlebag_container_id INT UNSIGNED NULL, x FLOAT NOT NULL DEFAULT 0, y FLOAT NOT NULL DEFAULT 0, z FLOAT NOT NULL DEFAULT 0, a FLOAT NOT NULL DEFAULT 0, in_foal_by INT UNSIGNED NULL, covered_day INT NOT NULL DEFAULT 0, due_day INT NOT NULL DEFAULT 0, foal_genes CHAR(20) NOT NULL DEFAULT '', foal_inbred TINYINT NOT NULL DEFAULT 0, foal_sire_breed TINYINT NOT NULL DEFAULT 0, covered_season INT NOT NULL DEFAULT 0, covers TINYINT NOT NULL DEFAULT 0, covers_season INT NOT NULL DEFAULT 0, stud_fee INT NOT NULL DEFAULT -1, lame_until INT NOT NULL DEFAULT 0, sick_until INT NOT NULL DEFAULT 0, last_ridden INT NOT NULL DEFAULT 0, lend_character_id INT UNSIGNED NOT NULL DEFAULT 0, lend_until INT NOT NULL DEFAULT 0, blanket TINYINT NOT NULL DEFAULT 0, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY idx_owner (owner_character_id, status), KEY idx_stable (stable_id, location_kind)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("horses-2-stables","CREATE TABLE IF NOT EXISTS horse_stables (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(28) NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, capacity TINYINT NOT NULL DEFAULT 12, fee_pfennig INT NOT NULL DEFAULT 2, keeper_character_id INT UNSIGNED NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("horses-3-events","CREATE TABLE IF NOT EXISTS horse_events (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, horse_id INT UNSIGNED NOT NULL, at INT NOT NULL, kind TINYINT NOT NULL, actor_character_id INT UNSIGNED NULL, note VARCHAR(48) NOT NULL DEFAULT '', KEY idx_horse (horse_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Horses_LoadOnBoot();

public Horses_LoadOnBoot()
{
	await Horses_LoadStables();
	Horses_PlaceKeepers();
	new wild = Horses_SpawnAllWild();
	Horses_DailySweep();
	Log_Info("horses","%d stables, %d wild horses in %d meadows",HORSE_SEED_STABLES,wild,HORSE_SEED_MEADOWS);
	Boot_LoaderDone();
	return 1;
}

hook OnGameModeExit()
{
	Horses_FlushDirty();
}
