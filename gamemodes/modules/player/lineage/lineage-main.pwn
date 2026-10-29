#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("lifeclock","Staff: set how many deaths a character's life clock has left.");
}

hook OnMigrationRun()
{
	Migration_Add("lineage-1-clock", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS life_clock TINYINT NULL, ADD COLUMN IF NOT EXISTS born_day INT NULL, ADD COLUMN IF NOT EXISTS died_at DATETIME NULL, ADD COLUMN IF NOT EXISTS death_cause VARCHAR(24) NULL, MODIFY slot TINYINT NULL");
	Migration_Add("lineage-2-grave", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS died_age TINYINT NULL, ADD COLUMN IF NOT EXISTS died_day INT NULL");
	Migration_Add("lineage-3-retired", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS retired TINYINT NOT NULL DEFAULT 0");
	Migration_Add("lineage-5-bonus", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS life_bonus TINYINT NOT NULL DEFAULT 0");
	Migration_Add("lineage-4-held", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS age_held_minutes INT NOT NULL DEFAULT 0");
	Migration_Add("lineage-6-rites", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS last_rites TINYINT NOT NULL DEFAULT 0");
}
