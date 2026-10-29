#include <pp-hooks>

hook OnGameModeInit()
{
	AnimPreload_Register("SUNBATHE");
}

hook OnMigrationRun()
{
	Migration_Add("character-1-characters", "CREATE TABLE IF NOT EXISTS characters (id INT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NOT NULL, slot TINYINT NOT NULL, name VARCHAR(20) NOT NULL, surname VARCHAR(20) NOT NULL, sex TINYINT NOT NULL DEFAULT 0, skin INT NOT NULL DEFAULT 26, alive TINYINT(1) NOT NULL DEFAULT 1, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, last_played_at DATETIME NULL, playtime_minutes INT UNSIGNED NOT NULL DEFAULT 0, pos_x FLOAT NOT NULL DEFAULT 0, pos_y FLOAT NOT NULL DEFAULT 0, pos_z FLOAT NOT NULL DEFAULT 0, angle FLOAT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, world INT NOT NULL DEFAULT 0, health FLOAT NOT NULL DEFAULT 100, PRIMARY KEY (id), UNIQUE KEY idx_account_slot (account_id, slot), UNIQUE KEY idx_full_name (name, surname), KEY idx_account (account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("character-2-creator", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS age TINYINT NOT NULL DEFAULT 20, ADD COLUMN IF NOT EXISTS origin TINYINT NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS willpower TINYINT NOT NULL DEFAULT 1, ADD COLUMN IF NOT EXISTS craftmanship TINYINT NOT NULL DEFAULT 1, ADD COLUMN IF NOT EXISTS intelligence TINYINT NOT NULL DEFAULT 1, ADD COLUMN IF NOT EXISTS honor_grace TINYINT NOT NULL DEFAULT 1, ADD COLUMN IF NOT EXISTS piety TINYINT NOT NULL DEFAULT 1, ADD COLUMN IF NOT EXISTS trait_a TINYINT NOT NULL DEFAULT 16, ADD COLUMN IF NOT EXISTS trait_b TINYINT NOT NULL DEFAULT 16, ADD COLUMN IF NOT EXISTS lifestyle TINYINT NOT NULL DEFAULT 0");
	Migration_Add("tutorial-1-done", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS tutorial_done TINYINT(1) NOT NULL DEFAULT 0");
	Migration_Add("tutorial-2-step", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS tutorial_step TINYINT UNSIGNED NOT NULL DEFAULT 0");
	Migration_Add("character-3-culture", "ALTER TABLE characters ADD COLUMN IF NOT EXISTS culture SMALLINT NOT NULL DEFAULT 0");
	Skins_AddRetireMigration();
}

hook OnPlayerConnect(playerid)
{
	Character_Reset(playerid);
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (Character_GetId(playerid) > 0)
	{
		Character_Save(playerid,true);
		pawn_call_public("Character_OnUnloaded","d",playerid);
	}

	Character_Reset(playerid);
}

hook Database_OnPlayerSave(playerid,E_SAVE_REASON:reason)
{
	if (!Session_HasCharacter(playerid))
	{
		return;
	}

	Character_Save(playerid,reason != E_SAVE_REASON_PERIODIC);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused to

	if (from == SESSION_PLAYING)
	{
		Character_CapturePosition(playerid);
		Character_RequestSave(playerid);
	}
}
