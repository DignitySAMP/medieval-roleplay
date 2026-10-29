#include <pp-hooks>

hook OnMigrationRun()
{
	Migration_Add("economy-1-coin-ledger", "CREATE TABLE IF NOT EXISTS coin_ledger (id INT UNSIGNED NOT NULL AUTO_INCREMENT, at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, county_id INT NULL, kind TINYINT NOT NULL, source VARCHAR(24) NOT NULL DEFAULT '', amount INT NOT NULL, from_character_id INT UNSIGNED NULL, to_character_id INT UNSIGNED NULL, container_id INT UNSIGNED NULL, PRIMARY KEY (id), KEY idx_at (at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

hook OnGameModeInit()
{
    new answer[HELP_ANSWER_LEN];
    format(answer,sizeof(answer),"~w~Money is carried as coins in your bag or a coin purse. A groschen is worth %d pfennig. A gulden is worth %d pfennig. Shops take payment and give change automatically. To pay another player, stand face to face and press ~y~Walk + Y (left Alt + Y)~w~. Add coin in the trade panel and both choose ~y~Accept~w~.",Item_CoinWorth(COIN_GROSCHEN),Item_CoinWorth(COIN_GULDEN));
    Help_Register(HELP_SECTION_START,"How do money and coins work?",answer,true);
}
