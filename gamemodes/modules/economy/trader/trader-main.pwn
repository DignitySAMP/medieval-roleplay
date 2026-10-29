#include <pp-hooks>

hook OnGameModeInit()
{
	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Take your goods to a ~y~trader~w~ and press ~y~Y~w~ next to them. A trader buys almost anything for about %d%% of its worth, more for better stars. They also sell iron, salt, spice, seeds, rope, parchment, water skins and a few special dice for about %d%% of their worth. The ~y~halter and rope~w~ you need to tame or lead a horse is on their shelf too. They'll also fill your ~y~water skin~w~ for %d pfennig.~n~~n~Traders close at night. A trader only has so much coin each day. Players who buy and sell for themselves will usually give you a better deal.",TRADER_BUY_PERCENT,TRADER_SELL_PERCENT,TRADER_FILL_FEE);
	Help_Register(HELP_SECTION_WORK,"How do I sell what I make?",answer);
	Command_Describe("trader","Staff: place, remove or list the traders.");
	Boot_RegisterLoader("Trader_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Trader_KeyContext");
	SetTimer("Trader_PromptTick",TRADER_PROMPT_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("trader-1-traders", "CREATE TABLE IF NOT EXISTS traders (id INT UNSIGNED NOT NULL AUTO_INCREMENT, name VARCHAR(24) NOT NULL, skin INT NOT NULL, purse INT NOT NULL DEFAULT 0, purse_day INT NOT NULL DEFAULT 0, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
