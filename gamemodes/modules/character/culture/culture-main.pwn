#include <pp-hooks>

hook OnMigrationRun()
{
	Migration_Add("culture-1-points", "CREATE TABLE IF NOT EXISTS culture_points (account_id INT UNSIGNED NOT NULL, points INT NOT NULL DEFAULT 0, PRIMARY KEY (account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("culture-2-unlocks", "CREATE TABLE IF NOT EXISTS culture_unlocks (account_id INT UNSIGNED NOT NULL, culture SMALLINT NOT NULL, PRIMARY KEY (account_id, culture)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

hook OnGameModeInit()
{
	Command_Describe("language","Choose which tongue you speak: Common or your own.","","Talking");
	Command_Describe("cultureunlock","Give someone culture unlock points (loremasters).","Culture_UnlockCommandGate","Culture");
	Log_Info("culture","%d culture(s) in %d group(s), %d language(s)",CULTURE_COUNT,CULTURE_GROUP_COUNT,LANGUAGE_COUNT);
}
