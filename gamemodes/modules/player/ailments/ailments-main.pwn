#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("ailment","Dev: give a player an ailment.");
	Command_Describe("ails","Dev: list a player's ailments.");
	Command_Describe("ailturn","Dev: move a player's ailments on a day.");
	Command_Describe("treat","Dev: treat a player's ailment.");
	Command_Describe("cure","Dev: cure a player's ailment.");
	Log_Info("ailments","%d ailment(s) in the catalogue",AILMENT_COUNT);
}

hook OnMigrationRun()
{
	Migration_Add("ailments-1-character-ailments", "CREATE TABLE IF NOT EXISTS character_ailments (character_id INT UNSIGNED NOT NULL, ailment SMALLINT NOT NULL, stage TINYINT NOT NULL DEFAULT 0, stage_turn INT NOT NULL DEFAULT 0, severity TINYINT NOT NULL DEFAULT 0, diagnosed TINYINT(1) NOT NULL DEFAULT 0, source VARCHAR(32) NOT NULL DEFAULT '', PRIMARY KEY (character_id, ailment)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("ailments-2-character-marks", "CREATE TABLE IF NOT EXISTS character_marks (character_id INT UNSIGNED NOT NULL, mark SMALLINT NOT NULL, since_turn INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id, mark)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
