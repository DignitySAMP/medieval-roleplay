#include <pp-hooks>

hook OnGameModeInit()
{
	Character_RegisterBusyCheck("Wounds_BusyCheck");
	Command_Describe("woundme","Staff: give yourself a wound.");
	Command_Describe("unwound","Staff: heal all your wounds.");
	AnimPreload_Register("MEDIC");
	Log_Info("wounds","%d body parts, %d wound kinds, up to %d wounds each",WOUND_PART_COUNT,WOUND_KIND_COUNT,WOUND_MAX);
}

hook OnMigrationRun()
{
	Migration_Add("wounds-1-character-wounds", "CREATE TABLE IF NOT EXISTS character_wounds (character_id INT UNSIGNED NOT NULL, part TINYINT NOT NULL, kind TINYINT NOT NULL, severity TINYINT NOT NULL, flags TINYINT NOT NULL DEFAULT 0, bleed FLOAT NOT NULL DEFAULT 0, heal_left INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, part, kind)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
