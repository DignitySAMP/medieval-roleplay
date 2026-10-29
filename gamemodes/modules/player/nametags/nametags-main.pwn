#include <pp-hooks>

hook OnGameModeInit()
{
	Keys_RegisterContext(KEY_CTRL_BACK,KEYS_PRIO_AMBIENT,"Nametag_KeyContext");
}

hook OnMigrationRun()
{
	Migration_Add("nametags-1-aliases", "CREATE TABLE IF NOT EXISTS character_aliases (viewer_id INT UNSIGNED NOT NULL, target_id INT UNSIGNED NOT NULL, alias VARCHAR(44) NOT NULL, PRIMARY KEY (viewer_id, target_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
