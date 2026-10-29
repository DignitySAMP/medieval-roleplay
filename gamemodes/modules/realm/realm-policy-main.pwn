#include <pp-hooks>

hook OnMigrationRun()
{
	Migration_Add("realm-1-duchy","CREATE TABLE IF NOT EXISTS duchy (id TINYINT UNSIGNED NOT NULL PRIMARY KEY, duke_character_id INT UNSIGNED NULL, treasury_container_id INT UNSIGNED NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-2-counties","CREATE TABLE IF NOT EXISTS counties (id INT UNSIGNED NOT NULL PRIMARY KEY, name VARCHAR(32) NOT NULL, count_character_id INT UNSIGNED NULL, regent_character_id INT UNSIGNED NULL, treasury_container_id INT UNSIGNED NULL, count_seen_at INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-3-policy","CREATE TABLE IF NOT EXISTS county_policy (county_id INT UNSIGNED NOT NULL, policy_key VARCHAR(32) NOT NULL, value INT NOT NULL, set_by INT UNSIGNED NOT NULL DEFAULT 0, set_at INT NOT NULL DEFAULT 0, PRIMARY KEY (county_id, policy_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-4-bounds","CREATE TABLE IF NOT EXISTS duchy_bounds (policy_key VARCHAR(32) NOT NULL PRIMARY KEY, min_value INT NOT NULL, max_value INT NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-5-decrees","CREATE TABLE IF NOT EXISTS decrees (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, kind TINYINT NOT NULL, text VARCHAR(144) NOT NULL, params VARCHAR(64) NOT NULL DEFAULT '', starts_at INT NOT NULL, ends_at INT NOT NULL, issued_by INT UNSIGNED NOT NULL DEFAULT 0, KEY idx_ends (ends_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-6-levies","CREATE TABLE IF NOT EXISTS levies (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, county_id INT UNSIGNED NOT NULL, due_turn INT NOT NULL, coin INT NOT NULL, grain INT NOT NULL, paid TINYINT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-7-dues","CREATE TABLE IF NOT EXISTS dues_owed (county_id INT UNSIGNED NOT NULL, village_key VARCHAR(16) NOT NULL, coin INT NOT NULL DEFAULT 0, updated_at INT NOT NULL DEFAULT 0, PRIMARY KEY (county_id, village_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-8-log","CREATE TABLE IF NOT EXISTS realm_log (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, at INT NOT NULL, actor_character_id INT UNSIGNED NOT NULL DEFAULT 0, what VARCHAR(128) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("realm-9-carried","CREATE TABLE IF NOT EXISTS dues_carried (character_id INT UNSIGNED NOT NULL PRIMARY KEY, coin INT NOT NULL DEFAULT 0, since INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

hook OnGameModeInit()
{
	Boot_RegisterLoader("Realm_LoadOnBoot");
}

forward Realm_LoadOnBoot();

public Realm_LoadOnBoot()
{
	await Realm_Load();
	Log_Info("realm","county %d: count %d, regent %d, duke %d, %s; %d decrees in force",REALM_COUNTY,Realm_GetCount(),Realm_GetRegent(),Realm_GetDuke(),Realm_IsVacant() ? ("held by the steward") : ("ruled"),Realm_CountDecrees());
	Boot_LoaderDone();
	return 1;
}
