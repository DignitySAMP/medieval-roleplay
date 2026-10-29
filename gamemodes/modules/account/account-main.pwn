#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("loremaster","Give or take the loremaster rank.","","Staff tools");
	Command_Describe("quizreset","Let a name take the roleplay quiz again and lift a quiz ban on its address.","","Staff tools");

	new answer[HELP_ANSWER_LEN];
	format(answer,sizeof(answer),"~w~Every new account takes a short quiz about roleplay here before it's made. You get ~y~%d questions~w~ drawn at random and need ~y~%d~w~ right. If you don't pass, you can try again after ~y~%d minutes~w~. Failing %d times within %d hours gets you banned. You can appeal on our Discord at ~y~%s~w~.",ACCOUNT_QUIZ_DRAW,ACCOUNT_QUIZ_PASS,ACCOUNT_QUIZ_COOLDOWN_MIN,ACCOUNT_QUIZ_CAP_FAILS,ACCOUNT_QUIZ_CAP_HOURS,ACCOUNT_QUIZ_APPEAL);
	Help_Register(HELP_SECTION_START,"What is the roleplay quiz?",answer,false);
	Help_Register(HELP_SECTION_ROLEPLAY,"What does in character and out of character mean?","~w~~y~In character~w~ (IC) is what your character says and does in the world. ~y~Out of character~w~ (OOC) is you, the player. Keep OOC talk short and put it in ~y~/b~w~, the local OOC chat.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"What is metagaming?","~w~Using something your character couldn't know. What you read on Discord, saw on a stream or heard in ~y~/b~w~ stays out of the game. Your character only knows what they saw and heard in the world.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"What is powergaming?","~w~Forcing an outcome on someone, or doing what your character couldn't do. Write what your character ~y~tries~w~ and give the other player a chance to react before you play out what happens.",true);
	Help_Register(HELP_SECTION_ROLEPLAY,"What does it mean to play fear?","~w~Your character wants to live. With a blade at their throat or outnumbered, they're afraid. Talk, give in or try to slip away, the way a real person would.",true);
	bcrypt_set_thread_limit(2);
}

hook OnMigrationRun()
{
	Migration_Add("account-1-accounts", "CREATE TABLE IF NOT EXISTS accounts (id INT UNSIGNED NOT NULL AUTO_INCREMENT, name VARCHAR(20) NOT NULL, password_hash CHAR(60) NOT NULL, email VARCHAR(120) NULL, admin_level TINYINT NOT NULL DEFAULT 0, registered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, last_login_at DATETIME NULL, last_ip VARCHAR(45) NULL, banned_until DATETIME NULL, ban_reason VARCHAR(128) NULL, PRIMARY KEY (id), UNIQUE KEY idx_name (name)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("account-2-auth-log", "CREATE TABLE IF NOT EXISTS account_auth_log (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NULL, username VARCHAR(20) NOT NULL, event_type VARCHAR(32) NOT NULL, ip VARCHAR(45) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id), KEY idx_account (account_id), KEY idx_created (created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	Migration_Add("account-3-loremaster", "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS loremaster TINYINT(1) NOT NULL DEFAULT 0");
	Migration_Add("account-4-whitelist", "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS whitelist TINYINT NOT NULL DEFAULT 1");
	Migration_Add("account-5-quiz-attempts", "CREATE TABLE IF NOT EXISTS account_quiz_attempts (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NULL, name VARCHAR(20) NOT NULL, ip VARCHAR(45) NOT NULL, score TINYINT NOT NULL, asked TINYINT NOT NULL, passed TINYINT(1) NOT NULL, cleared TINYINT(1) NOT NULL DEFAULT 0, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id), KEY idx_name (name, created_at), KEY idx_ip (ip, created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
