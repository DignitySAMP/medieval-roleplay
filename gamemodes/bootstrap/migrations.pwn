#define MIGRATION_MAX (256)
#define MIGRATION_KEY_LEN (48)
#define SEEDER_MAX (64)
#define SEEDER_NAME_LEN (32)

static s_MigrationKeys[MIGRATION_MAX][MIGRATION_KEY_LEN];
static List:s_MigrationSql = List:0;
static s_MigrationCount;
static s_SeederKeys[SEEDER_MAX][MIGRATION_KEY_LEN];
static s_SeederCallbacks[SEEDER_MAX][SEEDER_NAME_LEN];
static s_SeederCount;

static s_MigrationApplied[MIGRATION_MAX][MIGRATION_KEY_LEN];
static s_MigrationAppliedCount;
static s_MigrationRunning = -1;
static s_MigrationRan;
static s_MigrationSkipped;
static s_MigrationFailed;

stock Migration_Add(const key[], const sql[])
{
	if (s_MigrationCount >= MIGRATION_MAX)
	{
		Log_Warn("migrations", "no room for %s", key);
		return;
	}

	if (s_MigrationSql == List:0)
	{
		s_MigrationSql = list_new();
	}

	format(s_MigrationKeys[s_MigrationCount], MIGRATION_KEY_LEN, "%s", key);
	list_add_str(s_MigrationSql, sql);
	s_MigrationCount++;
}

stock Seeder_Add(const key[], const callback[])
{
	if (s_SeederCount >= SEEDER_MAX)
	{
		Log_Warn("migrations", "no room for seeder %s", key);
		return;
	}

	format(s_SeederKeys[s_SeederCount], MIGRATION_KEY_LEN, "%s", key);
	format(s_SeederCallbacks[s_SeederCount], SEEDER_NAME_LEN, "%s", callback);
	s_SeederCount++;
}

stock Migration_GetCount()
{
	return s_MigrationCount;
}

stock Migration_GetKey(index, dest[], size = sizeof(dest))
{
	if (index < 0 || index >= s_MigrationCount)
	{
		dest[0] = EOS;
		return;
	}

	format(dest, size, "%s", s_MigrationKeys[index]);
}

stock Migration_GetRan()
{
	return s_MigrationRan;
}

stock Migration_GetSkipped()
{
	return s_MigrationSkipped;
}

stock Migration_GetFailedCount()
{
	return s_MigrationFailed;
}

stock Seeder_GetCount()
{
	return s_SeederCount;
}

stock Seeder_GetCallback(index, dest[], size = sizeof(dest))
{
	if (index < 0 || index >= s_SeederCount)
	{
		dest[0] = EOS;
		return;
	}

	format(dest, size, "%s", s_SeederCallbacks[index]);
}

static bool:Migrations_IsListed(const keys[][], count, const key[])
{
	for (new i = 0;i < count;i++)
	{
		if (!strcmp(keys[i], key))
		{
			return true;
		}
	}

	return false;
}

stock Migrations_Run()
{
	pawn_call_public("OnMigrationRun", "");
	pawn_call_public("Migrations_RunOnBoot", "");
}

forward OnMigrationRun();

public OnMigrationRun()
{
	return 1;
}

forward Migrations_RunOnBoot();

public Migrations_RunOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql, str_new("CREATE TABLE IF NOT EXISTS schema_migrations (migration_key VARCHAR(48) NOT NULL, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (migration_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"));

	await mysql_aquery_s(g_Mysql, str_new("SHOW COLUMNS FROM schema_migrations LIKE 'migration_key'"));

	if (cache_num_rows() == 0)
	{
		await mysql_aquery_s(g_Mysql, str_new("RENAME TABLE schema_migrations TO schema_migrations_legacy"));
		await mysql_aquery_s(g_Mysql, str_new("CREATE TABLE IF NOT EXISTS schema_migrations (migration_key VARCHAR(48) NOT NULL, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (migration_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"));
		printf("[migrations] legacy schema_migrations parked as schema_migrations_legacy");
	}

	await mysql_aquery_s(g_Mysql, str_new("CREATE TABLE IF NOT EXISTS seeders (seeder_key VARCHAR(48) NOT NULL, seeded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (seeder_key)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"));

	s_MigrationAppliedCount = 0;

	await mysql_aquery_s(g_Mysql, str_new("SELECT migration_key FROM schema_migrations"));

	for (new row = 0, rows = cache_num_rows();row < rows && s_MigrationAppliedCount < MIGRATION_MAX;row++)
	{
		cache_get_value_name(row, "migration_key", s_MigrationApplied[s_MigrationAppliedCount], MIGRATION_KEY_LEN);
		s_MigrationAppliedCount++;
	}

	s_MigrationRan = 0;
	s_MigrationSkipped = 0;
	s_MigrationFailed = 0;

	Migrations_Step(0);
	return 1;
}

static Migrations_Step(from)
{
	for (new i = from;i < s_MigrationCount;i++)
	{
		if (Migrations_IsListed(s_MigrationApplied, s_MigrationAppliedCount, s_MigrationKeys[i]))
		{
			s_MigrationSkipped++;
			continue;
		}

		s_MigrationRunning = i;
		mysql_tquery_s(g_Mysql, list_get_str_s(s_MigrationSql, i), "Migrations_OnStatement", "d", i);
		return;
	}

	printf("[migrations] %d applied, %d already in place, %d failed", s_MigrationRan, s_MigrationSkipped, s_MigrationFailed);
	pawn_call_public("Migrations_RunSeeders", "");
}

forward Migrations_OnStatement(index);

public Migrations_OnStatement(index)
{
	if (index != s_MigrationRunning)
	{
		return 1;
	}

	s_MigrationRunning = -1;
	mysql_pquery_s(g_Mysql, str_format("INSERT IGNORE INTO schema_migrations (migration_key) VALUES ('%e')", s_MigrationKeys[index]));
	s_MigrationRan++;

	Migrations_Step(index + 1);
	return 1;
}

forward Migrations_RunSeeders();

public Migrations_RunSeeders()
{
	yield 1;

	new seeded[SEEDER_MAX][MIGRATION_KEY_LEN];
	new seededCount;

	await mysql_aquery_s(g_Mysql, str_new("SELECT seeder_key FROM seeders"));

	for (new row = 0, rows = cache_num_rows();row < rows && seededCount < SEEDER_MAX;row++)
	{
		cache_get_value_name(row, "seeder_key", seeded[seededCount], MIGRATION_KEY_LEN);
		seededCount++;
	}

	new sown = 0;

	for (new i = 0;i < s_SeederCount;i++)
	{
		if (Migrations_IsListed(seeded, seededCount, s_SeederKeys[i]))
		{
			continue;
		}

		pawn_call_public(s_SeederCallbacks[i], "");
		mysql_pquery_s(g_Mysql, str_format("INSERT IGNORE INTO seeders (seeder_key) VALUES ('%e')", s_SeederKeys[i]));
		sown++;
	}

	if (s_SeederCount > 0)
	{
		printf("[migrations] %d seeder(s) run, %d already sown", sown, s_SeederCount - sown);
	}

	Boot_Next();
	return 1;
}

#include <pp-hooks>

hook OnQueryError(errorid, const error[], const callback[], const query[], MySQL:handle)
{
	#pragma unused error
	#pragma unused query
	#pragma unused handle

	if (s_MigrationRunning == -1 || strcmp(callback, "Migrations_OnStatement") != 0)
	{
		return;
	}

	new index = s_MigrationRunning;
	s_MigrationRunning = -1;

	Log_Warn("migrations", "%s failed with error %d, it gets another go on the next boot", s_MigrationKeys[index], errorid);
	s_MigrationFailed++;

	Migrations_Step(index + 1);
}
