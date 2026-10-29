#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"Where do I hear the news?","~w~The ~y~crier~w~ in Talmberg's market calls out every new notice, and the ~y~notice boards~w~ at the market, the church village and the guardhouse keep them pinned up for a few days. Stand at a board and press ~y~Y~w~.~n~~n~Notices are sorted under Realm, Church, Players and Events. Anyone can pin one under Players for 2 pfennig. It stays up for three days.");
	Command_Describe("notice","Staff: pin a realm, church or event notice to every board, list them, take one down, open a board.");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Notices_PromptContext");
	SetTimer("Notices_CryTick",NOTICES_CRY_MS,true);
	SetTimer("Notices_PromptTick",500,true);
	Boot_RegisterLoader("Notices_LoadOnBoot");
}

hook OnMigrationRun()
{
	Migration_Add("notices_notices","CREATE TABLE IF NOT EXISTS notices (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, county_id INT NULL, tab TINYINT NOT NULL, author_character_id INT UNSIGNED NULL, title VARCHAR(48) NOT NULL DEFAULT '', text VARCHAR(256) NOT NULL, starts_at INT NULL, expires_at INT NOT NULL, fee_paid INT NOT NULL DEFAULT 0, announced_count TINYINT NOT NULL DEFAULT 0, created_at INT NOT NULL DEFAULT 0, KEY live (expires_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

forward Notices_LoadOnBoot();

public Notices_LoadOnBoot()
{
	new count = await Notices_Load();
	Notices_RefreshBoards();
	Notices_PlaceCrier();
	Log_Info("notices","%d notices up on %d boards",count,NOTICE_SEED_BOARDS);
	Boot_LoaderDone();
	return 1;
}
