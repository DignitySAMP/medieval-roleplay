new MySQL:g_Mysql = MYSQL_INVALID_HANDLE;
new g_ServerDbId = DB_SERVER_LOCAL;
new bool:g_DatabaseReady = false;
new bool:g_DatabaseSchemaReady = false;
new g_DatabaseProbeTries = 0;

#define DATABASE_PROBE_MS (250)
#define DATABASE_PROBE_MAX (40)
#define DATABASE_PROBE_TABLES (2)

enum E_SAVE_REASON
{
	E_SAVE_REASON_PERIODIC,
	E_SAVE_REASON_DISCONNECT,
	E_SAVE_REASON_SHUTDOWN,
	E_SAVE_REASON_MANUAL,
}

#define DATABASE_SAVE_INTERVAL_MS (120000)

static Database_MarkSchemaReady()
{
	g_DatabaseSchemaReady = true;
	pawn_call_public("Database_OnReady","");
}

static Database_Connect()
{
	g_Mysql = mysql_connect_file("mysql.ini");
	if (g_Mysql == MYSQL_INVALID_HANDLE || mysql_errno(g_Mysql) != 0)
	{
		printf("[mysql] FATAL could not connect (errno %d)",mysql_errno(g_Mysql));
		return;
	}

	g_ServerDbId = DB_SERVER_LOCAL;
	g_DatabaseReady = true;
	mysql_log(WARNING | ERROR);
	SetTimer("Database_SaveTick",DATABASE_SAVE_INTERVAL_MS,true);
	SetTimer("Database_SchemaProbe",DATABASE_PROBE_MS,false);
	printf("[mysql] connected (env %d)",g_ServerDbId);
}

forward bool:IsDatabaseReady();

public bool:IsDatabaseReady()
{
	return g_DatabaseReady;
}

forward bool:Database_IsSchemaReady();

public bool:Database_IsSchemaReady()
{
	return g_DatabaseSchemaReady;
}

forward Database_OnReady();

public Database_OnReady()
{
	return 1;
}

forward Database_OnSchemaProbe();

public Database_OnSchemaProbe()
{
	new present = 0;

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"present",present);
	}

	if (present >= DATABASE_PROBE_TABLES)
	{
		printf("[mysql] schema ready after %d probe(s)",g_DatabaseProbeTries + 1);
		Database_MarkSchemaReady();
		return 1;
	}

	g_DatabaseProbeTries++;

	if (g_DatabaseProbeTries >= DATABASE_PROBE_MAX)
	{
		printf("[mysql] WARNING schema probe gave up with %d/%d login tables present - accepting logins anyway",present,DATABASE_PROBE_TABLES);
		Database_MarkSchemaReady();
		return 1;
	}

	SetTimer("Database_SchemaProbe",DATABASE_PROBE_MS,false);
	return 1;
}

forward Database_SchemaProbe();

public Database_SchemaProbe()
{
	mysql_tquery(g_Mysql,"SELECT COUNT(*) AS present FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('accounts','characters')","Database_OnSchemaProbe","");
	return 1;
}

forward Database_OnPlayerSave(playerid,E_SAVE_REASON:reason);

public Database_OnPlayerSave(playerid,E_SAVE_REASON:reason)
{
	return true;
}

forward Database_SaveTick();

public Database_SaveTick()
{
	foreach(new i : Player)
	{
		pawn_call_public("Database_OnPlayerSave","dd",i,_:E_SAVE_REASON_PERIODIC);
	}
	return 1;
}

public OnQueryError(errorid,const error[],const callback[],const query[],MySQL:handle)
{
	printf("[mysql] query error %d in '%s': %s",errorid,callback,error);
	printf("[mysql] failed query: %s",query);
	return 1;
}

public pp_on_error(source[],message[],error_level:level,&retval)
{
	printf("[mysql] pawnplus error (level %d): %s %s",_:level,source,message);
	PrintBacktrace();
	retval = 0;
	return retval;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	Database_Connect();
}

hook OnPlayerDisconnect(playerid,reason)
{
	if (g_DatabaseReady)
	{
		pawn_call_public("Database_OnPlayerSave","dd",playerid,_:E_SAVE_REASON_DISCONNECT);
	}
}

hook OnGameModeExit()
{
	foreach(new i : Player)
	{
		pawn_call_public("Database_OnPlayerSave","dd",i,_:E_SAVE_REASON_SHUTDOWN);
	}

	if (g_Mysql != MYSQL_INVALID_HANDLE)
	{
		pawn_call_public("Queue_WriteLogSync","sss","info","boot","Medieval Roleplay stopped");
		printf("[boot] Medieval Roleplay stopped");

		g_DatabaseReady = false;
		mysql_close(g_Mysql);
	}
}
