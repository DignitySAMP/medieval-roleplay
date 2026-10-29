#define QUEUE_QUERY_SIZE (1536)
#define QUEUE_PRUNE_INTERVAL_MS (3600000)
#define QUEUE_LOG_RETENTION_DAYS (14)
#define QUEUE_ACTIVITY_RETENTION_DAYS (30)

static Queue_CreateTables()
{
	mysql_tquery(g_Mysql,"CREATE TABLE IF NOT EXISTS server_log (log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, level VARCHAR(8) NOT NULL, tag VARCHAR(32) NOT NULL, message VARCHAR(512) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, announced_at DATETIME NULL, PRIMARY KEY (log_id), KEY idx_pending (announced_at, log_id), KEY idx_created (created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	mysql_tquery(g_Mysql,"CREATE TABLE IF NOT EXISTS activity_events (event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NULL, kind VARCHAR(32) NOT NULL, line VARCHAR(512) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, announced_at DATETIME NULL, PRIMARY KEY (event_id), KEY idx_pending (announced_at, event_id), KEY idx_account (account_id), KEY idx_created (created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

static Queue_Prune()
{
	if (!g_DatabaseReady)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("DELETE FROM server_log WHERE announced_at IS NOT NULL AND created_at < (NOW() - INTERVAL %d DAY)",QUEUE_LOG_RETENTION_DAYS));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM activity_events WHERE announced_at IS NOT NULL AND created_at < (NOW() - INTERVAL %d DAY)",QUEUE_ACTIVITY_RETENTION_DAYS));
}

forward Queue_WriteLog(const level[],const tag[],const message[]);

public Queue_WriteLog(const level[],const tag[],const message[])
{
	if (!g_DatabaseReady || isnull(message))
	{
		return 0;
	}

	mysql_tquery_s(g_Mysql,str_format("INSERT INTO server_log (level,tag,message) VALUES ('%e','%e','%e')",level,tag,message));
	return 1;
}

forward Queue_WriteLogSync(const level[],const tag[],const message[]);

public Queue_WriteLogSync(const level[],const tag[],const message[])
{
	if (!g_DatabaseReady || isnull(message))
	{
		return 0;
	}

	mysql_query_s(g_Mysql,str_format("INSERT INTO server_log (level,tag,message) VALUES ('%e','%e','%e')",level,tag,message),false);
	return 1;
}

forward Queue_WriteActivity(accountid,const kind[],const line[]);

public Queue_WriteActivity(accountid,const kind[],const line[])
{
	if (!g_DatabaseReady || isnull(line))
	{
		return 0;
	}

	new String:query;

	if (accountid > 0)
	{
		query = str_format("INSERT INTO activity_events (account_id,kind,line) VALUES (%d,'%e','%e')",accountid,kind,line);
	}
	else
	{
		query = str_format("INSERT INTO activity_events (account_id,kind,line) VALUES (NULL,'%e','%e')",kind,line);
	}

	mysql_tquery_s(g_Mysql,query);
	return 1;
}

forward Queue_PruneTick();

public Queue_PruneTick()
{
	Queue_Prune();
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Queue_CreateTables();
	Queue_Prune();
	SetTimer("Queue_PruneTick",QUEUE_PRUNE_INTERVAL_MS,true);
}
