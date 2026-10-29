#define WORK_LEVEL_MAX (10)
#define WORK_PRACTICE_PER_LEVEL (100)
#define WORK_PRACTICE_PER_STAR (10)
#define WORK_LEVEL_UNMASTERED (9)

static s_WorkLevel[MAX_PLAYERS][TRADE_COUNT char];
static s_WorkPractice[MAX_PLAYERS][TRADE_COUNT];
static bool:s_WorkLevelsLoaded[MAX_PLAYERS];
static s_WorkLevelsCharacter[MAX_PLAYERS];
static s_WorkMastered[MAX_PLAYERS];
static s_WorkPracticeBonus[MAX_PLAYERS][2];

static Work_ResetLevels(playerid)
{
	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		s_WorkLevel[playerid]{trade} = 1;
		s_WorkPractice[playerid][trade] = 0;
	}

	s_WorkLevelsLoaded[playerid] = false;
	s_WorkLevelsCharacter[playerid] = 0;
	s_WorkMastered[playerid] = 0;
	s_WorkPracticeBonus[playerid][0] = -1;
	s_WorkPracticeBonus[playerid][1] = 0;
}

stock Work_GetLevel(playerid,trade)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade))
	{
		return 1;
	}

	return s_WorkLevel[playerid]{trade};
}

stock bool:Work_AreLevelsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WorkLevelsLoaded[playerid];
}

stock Work_GetPractice(playerid,trade)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade))
	{
		return 0;
	}

	return s_WorkPractice[playerid][trade];
}

forward bool:Work_IsMastered(playerid,trade);

stock Work_GetLevelCap(playerid,trade)
{
	new cap = Talent_GetTradeLevelCap(playerid,trade);
	return Work_IsMastered(playerid,trade) || !Trade_HasMasterpiece(trade) ? cap : min(cap,WORK_LEVEL_UNMASTERED);
}

stock bool:Work_IsMastered(playerid,trade)
{
	return Util_IsValidPlayer(playerid) && Trade_IsValid(trade) && (s_WorkMastered[playerid] & (1 << trade)) != 0;
}

stock Work_SetMastered(playerid,trade,bool:isMastered)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade))
	{
		return;
	}

	if (isMastered)
	{
		s_WorkMastered[playerid] |= 1 << trade;
	}
	else
	{
		s_WorkMastered[playerid] &= ~(1 << trade);
	}

	if (s_WorkLevelsCharacter[playerid] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO job_levels (character_id, trade, level, practice, mastered) VALUES (%d, %d, %d, %d, %d) ON DUPLICATE KEY UPDATE mastered = VALUES(mastered)",s_WorkLevelsCharacter[playerid],trade,s_WorkLevel[playerid]{trade},s_WorkPractice[playerid][trade],_:isMastered));
	}
}

stock Work_SetPracticeBonus(playerid,trade,percent)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WorkPracticeBonus[playerid][0] = percent > 0 && Trade_IsValid(trade) ? trade : -1;
		s_WorkPracticeBonus[playerid][1] = Util_ClampInt(percent,0,100);
	}
}

stock Work_GetPracticeBonus(playerid,trade)
{
	return Util_IsValidPlayer(playerid) && s_WorkPracticeBonus[playerid][0] == trade ? s_WorkPracticeBonus[playerid][1] : 0;
}

stock Work_GetPracticeToNext(level)
{
	return WORK_PRACTICE_PER_LEVEL * level;
}

stock Work_AddPractice(playerid,trade,amount)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade) || amount <= 0)
	{
		return;
	}

	new level = s_WorkLevel[playerid]{trade}, cap = Work_GetLevelCap(playerid,trade);
	s_WorkPractice[playerid][trade] += amount + amount * Work_GetPracticeBonus(playerid,trade) / 100;

	while (level < cap && level < WORK_LEVEL_MAX && s_WorkPractice[playerid][trade] >= Work_GetPracticeToNext(level))
	{
		s_WorkPractice[playerid][trade] -= Work_GetPracticeToNext(level);
		level++;
		s_WorkLevel[playerid]{trade} = level;
		pawn_call_public("Work_OnLevel","ddd",playerid,trade,level);
	}

	if (level >= cap)
	{
		s_WorkPractice[playerid][trade] = min(s_WorkPractice[playerid][trade],Work_GetPracticeToNext(level));
	}

	if (s_WorkLevelsCharacter[playerid] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO job_levels (character_id, trade, level, practice) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE level = VALUES(level), practice = VALUES(practice)",s_WorkLevelsCharacter[playerid],trade,level,s_WorkPractice[playerid][trade]));
	}
}

static Work_LoadLevels(playerid,characterid)
{

	await mysql_aquery_s(g_Mysql,str_format("SELECT trade, level, practice, mastered FROM job_levels WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return;
	}

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new trade, level, practice, mastered;
		cache_get_value_name_int(r,"trade",trade);
		cache_get_value_name_int(r,"level",level);
		cache_get_value_name_int(r,"practice",practice);
		cache_get_value_name_int(r,"mastered",mastered);

		if (Trade_IsValid(trade))
		{
			if (mastered != 0 || level >= WORK_LEVEL_MAX)
			{
				s_WorkMastered[playerid] |= 1 << trade;
			}

			s_WorkLevel[playerid]{trade} = Util_ClampInt(level,1,WORK_LEVEL_MAX);
			s_WorkPractice[playerid][trade] = max(practice,0);
		}
	}

	s_WorkLevelsCharacter[playerid] = characterid;
	s_WorkLevelsLoaded[playerid] = true;
}

forward Work_LoadLevelsDeferred(playerid,characterid);

public Work_LoadLevelsDeferred(playerid,characterid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid)
	{
		Work_LoadLevels(playerid,characterid);
	}
}

forward Work_OnLevel(playerid,trade,level);

public Work_OnLevel(playerid,trade,level)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Work_ResetLevels(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	Work_ResetLevels(playerid);
	SetTimerEx("Work_LoadLevelsDeferred",0,false,"dd",playerid,characterid);
}

hook Character_OnUnloaded(playerid)
{
	Work_ResetLevels(playerid);
}
