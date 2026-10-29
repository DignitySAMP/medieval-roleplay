#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("spouse","Staff: wed a character to an NPC spouse so they can have children and an heir.");
}

hook OnMigrationRun()
{
	Migration_Add("family-1-spouses", "CREATE TABLE IF NOT EXISTS character_spouses (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, name VARCHAR(24) NOT NULL, sex TINYINT NOT NULL, age_at_wed TINYINT NOT NULL, wed_day INT NOT NULL, dies_at TINYINT NOT NULL, ended_day INT NULL, due_day INT NULL, willpower TINYINT NOT NULL DEFAULT 1, craftmanship TINYINT NOT NULL DEFAULT 1, intelligence TINYINT NOT NULL DEFAULT 1, honor_grace TINYINT NOT NULL DEFAULT 1, piety TINYINT NOT NULL DEFAULT 1, trait TINYINT NOT NULL DEFAULT 16, PRIMARY KEY (id), KEY idx_character (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("family-2-children", "CREATE TABLE IF NOT EXISTS character_children (id INT UNSIGNED NOT NULL AUTO_INCREMENT, parent_character_id INT UNSIGNED NOT NULL, spouse_id INT UNSIGNED NOT NULL, name VARCHAR(24) NOT NULL DEFAULT '', sex TINYINT NOT NULL, born_day INT NOT NULL, grown TINYINT NOT NULL DEFAULT 0, willpower TINYINT NOT NULL DEFAULT 1, craftmanship TINYINT NOT NULL DEFAULT 1, intelligence TINYINT NOT NULL DEFAULT 1, honor_grace TINYINT NOT NULL DEFAULT 1, piety TINYINT NOT NULL DEFAULT 1, trait_a TINYINT NOT NULL DEFAULT 16, trait_b TINYINT NOT NULL DEFAULT 16, heir_character_id INT UNSIGNED NULL, PRIMARY KEY (id), KEY idx_parent (parent_character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("family-4-baptism", "ALTER TABLE character_children ADD COLUMN IF NOT EXISTS baptised TINYINT NOT NULL DEFAULT 0");
	Migration_Add("family-3-estates", "CREATE TABLE IF NOT EXISTS character_estates (character_id INT UNSIGNED NOT NULL, coin INT NOT NULL DEFAULT 0, heir_character_id INT UNSIGNED NULL, claimed TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (character_id), KEY idx_heir (heir_character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
