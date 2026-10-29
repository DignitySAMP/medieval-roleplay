#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("warm","Staff: stay comfortable in any cold.");
	Command_Describe("breath","Staff: cold breath automatic, always or off.");
}

hook OnMigrationRun()
{
	Migration_Add("warmth-1-column", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS warmth SMALLINT NOT NULL DEFAULT 0");
}
