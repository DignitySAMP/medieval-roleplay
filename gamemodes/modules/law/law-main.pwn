#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"What happens if I commit a crime?","~w~If someone sees you strike a person down, steal or kill, they know you did it. By day they see you from far off; in the dark only close by, unless a light is near.~n~~n~A crime someone saw puts you on the ~y~roll of the wanted~w~ with a bounty. The guards and anyone else may bind you and hand you over. Pay your fine at the ~y~gaol register~w~ by the guardhouse to clear your name.");
	Help_Register(HELP_SECTION_ROLEPLAY,"How do the guards work?","~w~The county's guards are appointed by the count. On duty they take the county's arms at the ~y~gaol register~w~ and may bind and arrest anyone who is down or bound. They choose the gaol, the pillory, the stocks or a fine.~n~~n~Anyone with a ~y~rope~w~ may bind someone who is down and hand them over at the register for the bounty.",false);
	Command_Describe("law","Staff: guards, crimes, the roll of the wanted, sentences, the pillory and the gaol.");
	Character_RegisterBusyCheck("Law_BusyCheck");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Law_PromptContext");
	SetTimer("Law_Tick",LAW_TICK_MS,true);
	SetTimer("Law_PromptTick",LAW_PROMPT_MS,true);
	Law_PlaceRegister();
}

hook OnMigrationRun()
{
	Migration_Add("law-1-crimes", "CREATE TABLE IF NOT EXISTS crimes (id INT UNSIGNED NOT NULL AUTO_INCREMENT, county_id INT NOT NULL DEFAULT 1, kind TINYINT NOT NULL, offender_character_id INT UNSIGNED NOT NULL, victim_character_id INT UNSIGNED NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, at INT NOT NULL, witnessed TINYINT NOT NULL DEFAULT 0, reported TINYINT NOT NULL DEFAULT 0, description VARCHAR(96) NOT NULL DEFAULT '', PRIMARY KEY (id), KEY idx_offender (offender_character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-2-wanted", "CREATE TABLE IF NOT EXISTS wanted (character_id INT UNSIGNED NOT NULL, county_id INT NOT NULL DEFAULT 1, bounty INT NOT NULL DEFAULT 0, crime TINYINT NOT NULL DEFAULT 0, description VARCHAR(96) NOT NULL DEFAULT '', since INT NOT NULL, expires_at INT NOT NULL, PRIMARY KEY (character_id, county_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-3-sentences", "CREATE TABLE IF NOT EXISTS sentences (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, kind TINYINT NOT NULL, county_id INT NOT NULL DEFAULT 1, minutes INT NOT NULL DEFAULT 0, served INT NOT NULL DEFAULT 0, fine INT NOT NULL DEFAULT 0, sentenced_by INT UNSIGNED NOT NULL DEFAULT 0, at INT NOT NULL, ticked_at INT NOT NULL DEFAULT 0, done TINYINT NOT NULL DEFAULT 0, outcome VARCHAR(24) NOT NULL DEFAULT '', PRIMARY KEY (id), KEY idx_active (character_id, done)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-4-marks", "CREATE TABLE IF NOT EXISTS law_marks (character_id INT UNSIGNED NOT NULL, flogged SMALLINT NOT NULL DEFAULT 0, branded TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-5-banishments", "CREATE TABLE IF NOT EXISTS banishments (character_id INT UNSIGNED NOT NULL, county_id INT NOT NULL DEFAULT 1, until INT NULL, PRIMARY KEY (character_id, county_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-6-guards", "CREATE TABLE IF NOT EXISTS law_guards (character_id INT UNSIGNED NOT NULL, county_id INT NOT NULL DEFAULT 1, rank TINYINT NOT NULL DEFAULT 1, appointed_by INT UNSIGNED NOT NULL DEFAULT 0, since INT NOT NULL, issued TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("law-7-bounties", "CREATE TABLE IF NOT EXISTS bounties_paid (id INT UNSIGNED NOT NULL AUTO_INCREMENT, character_id INT UNSIGNED NOT NULL, target_character_id INT UNSIGNED NOT NULL, amount INT NOT NULL, at INT NOT NULL, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
