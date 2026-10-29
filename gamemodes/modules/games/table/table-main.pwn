forward Table_LoadOnBoot();

public Table_LoadOnBoot()
{
	yield 1;

	new refunded = await Table_RefundOpenGames();
	new placed = await Table_LoadRegulars();
	Log_Info("games","%d stake(s) refunded from unfinished games, %d regular(s) seated",refunded,placed);
	Boot_LoaderDone();
}

#include <pp-hooks>

hook OnGameModeInit()
{
	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Carry a set of ~y~dice~w~, open your bag and press ~y~Games~w~. Pick who to play from the people standing next to you, the stake and the score to reach.~n~~n~Everyone puts the stake in the pot. The server holds it until the game ends and the winner takes all of it. If you walk away, go down or log off during a game, you lose your stake.~n~~n~Someone who turns you down %d times can't be asked by you again for %d minutes.",TABLE_REFUSALS_MAX,TABLE_REFUSAL_SECONDS / 60);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do I challenge someone to dice?",answer);
	format(answer,sizeof(answer),"~w~Yes. Stand next to a ~y~regular~w~ in a tavern and press ~y~Y~w~, then pick dice or Lansquenet. Regulars bring their own dice and cards and bet from their own purse.~n~~n~A regular whose purse runs dry is done for the day. Once you've won %d pfennig from the regulars in a day, they won't play you again until the next day.",TABLE_REGULAR_WIN_CAP);
	Help_Register(HELP_SECTION_ROLEPLAY,"Can I play against the tavern regulars?",answer);
	Command_Describe("regular","Staff: place, remove or list the tavern regulars who play dice.");
	Boot_RegisterLoader("Table_LoadOnBoot");
	Keys_RegisterContext(KEY_YES,KEYS_PRIO_MENU,"Table_RegularContext");
	Inventory_AddMenuButton("Games","Table_OpenGamesDeferred");
	SetTimer("Table_Tick",TABLE_TICK_MS,true);
	SetTimer("Table_RegularPromptTick",TABLE_REGULAR_PROMPT_MS,true);
}

hook OnMigrationRun()
{
	Migration_Add("games-1-played", "CREATE TABLE IF NOT EXISTS games_played (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind TINYINT UNSIGNED NOT NULL, stake INT NOT NULL DEFAULT 0, pot INT NOT NULL DEFAULT 0, with_regular TINYINT NOT NULL DEFAULT 0, opened_at INT UNSIGNED NOT NULL DEFAULT 0, started_at INT UNSIGNED NULL, ended_at INT UNSIGNED NULL, winner_character_id INT UNSIGNED NULL, winner_regular_id INT UNSIGNED NULL, refunded TINYINT NOT NULL DEFAULT 0, PRIMARY KEY (id), KEY ended (ended_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("games-2-seats", "CREATE TABLE IF NOT EXISTS games_seats (game_id INT UNSIGNED NOT NULL, seat TINYINT UNSIGNED NOT NULL, character_id INT UNSIGNED NULL, regular_id INT UNSIGNED NULL, stake INT NOT NULL DEFAULT 0, result INT NOT NULL DEFAULT 0, left_reason TINYINT NULL, PRIMARY KEY (game_id, seat), KEY character_id (character_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("games-3-regulars", "CREATE TABLE IF NOT EXISTS games_regulars (id INT UNSIGNED NOT NULL AUTO_INCREMENT, name VARCHAR(24) NOT NULL, skin INT NOT NULL, style TINYINT NOT NULL DEFAULT 1, purse INT NOT NULL DEFAULT 0, purse_day INT NOT NULL DEFAULT 0, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, a FLOAT NOT NULL, spot_x FLOAT NOT NULL, spot_y FLOAT NOT NULL, spot_z FLOAT NOT NULL, world INT NOT NULL DEFAULT 0, interior INT NOT NULL DEFAULT 0, PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
