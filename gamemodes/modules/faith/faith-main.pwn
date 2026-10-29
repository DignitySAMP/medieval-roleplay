#include <pp-hooks>

hook OnGameModeInit()
{
	Character_RegisterBusyCheck("Faith_BusyCheck");
	Command_Describe("service","Staff: start or stop a mass now, or see when the next one is.");
	Command_Describe("ordain","Staff, as the bishop: set anyone's rank in the Church, holy orders included.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Faith_KneelContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Faith_PrayerPromptContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Faith_PrayerContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Faith_FontContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Faith_RiteContext");
	Keys_RegisterContext(KEY_NO,KEYS_PRIO_SCENE,"Faith_PrayerContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Infirmary_PromptContext");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_SCENE,"Infirmary_LyingContext");
	Keys_RegisterContext(KEY_NO,KEYS_PRIO_SCENE,"Infirmary_LyingContext");
	SetTimer("Faith_PrayerPromptTick",FAITH_PRAYER_PROMPT_MS,true);
	SetTimer("Faith_ScheduleTick",1000,true);
	Faith_PlaceProps();
	Infirmary_PlaceBeds();
	AnimPreload_Register(INFIRMARY_LIE_LIB);
	Log_Info("faith","%d text(s), %d line(s); mass at 14:00, 19:00 and 22:00 local time (%02d:%02d now)",FAITH_TEXT_COUNT,FAITH_LINE_COUNT,Faith_LocalSeconds() / 3600,(Faith_LocalSeconds() % 3600) / 60);
}

hook OnMigrationRun()
{
	Migration_Add("faith-1-blessing", "CREATE TABLE IF NOT EXISTS character_faith (character_id INT NOT NULL, blessed_left INT NOT NULL DEFAULT 0, blessed_led TINYINT NOT NULL DEFAULT 0, blessing_broken TINYINT NOT NULL DEFAULT 0, paid_day INT NOT NULL DEFAULT 0, held_day INT NOT NULL DEFAULT 0, held_today INT NOT NULL DEFAULT 0, PRIMARY KEY (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("faith-3-banns", "CREATE TABLE IF NOT EXISTS character_banns (character_id INT UNSIGNED NOT NULL, spouse_name VARCHAR(24) NOT NULL, spouse_age TINYINT NOT NULL, church TINYINT NOT NULL DEFAULT 0, asked_day INT NOT NULL, read_count TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (character_id), KEY idx_church (church, read_count)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("clergy-1-members", "CREATE TABLE IF NOT EXISTS church_members (character_id INT UNSIGNED NOT NULL, church_rank TINYINT NOT NULL, church TINYINT NOT NULL DEFAULT 0, since_day INT NOT NULL DEFAULT 0, appointed_by INT UNSIGNED NULL, PRIMARY KEY (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("faith-2-shrine", "ALTER TABLE character_faith ADD COLUMN IF NOT EXISTS shrine_paid_day INT NOT NULL DEFAULT 0");
}
