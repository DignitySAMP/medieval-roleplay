#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("friends","See which of your friends are online.","","Friends");
	Command_Describe("addfriend","Add someone to your friends list.","","Friends");
	Command_Describe("unfriend","Take someone off your friends list.","","Friends");
}

hook OnMigrationRun()
{
	Migration_Add("friends-1-friends", "CREATE TABLE IF NOT EXISTS account_friends (account_id INT UNSIGNED NOT NULL, friend_id INT UNSIGNED NOT NULL, added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (account_id, friend_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
