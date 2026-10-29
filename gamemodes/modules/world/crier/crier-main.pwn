#include <pp-hooks>

hook OnMigrationRun()
{
	Migration_Add("crier-1-news", "CREATE TABLE IF NOT EXISTS realm_news (id INT UNSIGNED NOT NULL AUTO_INCREMENT, kind VARCHAR(16) NOT NULL, title VARCHAR(80) NOT NULL, body VARCHAR(600) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, announced_at DATETIME NULL, PRIMARY KEY (id), KEY idx_pending (announced_at, id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}
