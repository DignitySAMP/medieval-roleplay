#include <pp-hooks>

hook OnGameModeInit()
{
	Log_Info("talents","%d talent node(s)",Talent_GetNodeCount());
}

hook OnMigrationRun()
{
	Migration_Add("talents-1-points", "CREATE TABLE IF NOT EXISTS talent_points (character_id INT UNSIGNED NOT NULL, earned INT NOT NULL DEFAULT 0, spent INT NOT NULL DEFAULT 0, active_minutes INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("talents-2-unlocks", "CREATE TABLE IF NOT EXISTS talent_unlocks (character_id INT UNSIGNED NOT NULL, node_key VARCHAR(16) NOT NULL, cost SMALLINT NOT NULL DEFAULT 0, unlocked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (character_id, node_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
