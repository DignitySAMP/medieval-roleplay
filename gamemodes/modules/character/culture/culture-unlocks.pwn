static const s_CultureOpenByDefault[][CULTURE_NAME_LEN] = {"German", "Bohemian", "Polish", "Hungarian"};

static s_CultureUnlocked[MAX_PLAYERS][CULTURE_COUNT char];
static s_CulturePoints[MAX_PLAYERS];
static bool:s_CultureUnlocksLoaded[MAX_PLAYERS];

stock bool:Culture_IsOpenByDefault(culture)
{
	if (!Culture_IsValid(culture))
	{
		return false;
	}

	new name[CULTURE_NAME_LEN];
	Culture_GetName(culture,name);

	for (new i = 0;i < sizeof(s_CultureOpenByDefault);i++)
	{
		if (!strcmp(name,s_CultureOpenByDefault[i]))
		{
			return true;
		}
	}

	return false;
}

stock bool:Culture_IsAvailable(playerid,culture)
{
	return Culture_IsOpenByDefault(culture) || (Util_IsValidPlayer(playerid) && Culture_IsValid(culture) && s_CultureUnlocked[playerid]{culture});
}

stock Culture_CountAvailableInGroup(playerid,group)
{
	new count = 0;

	for (new i = 0;i < Culture_CountInGroup(group);i++)
	{
		if (Culture_IsAvailable(playerid,Culture_GetFromGroup(group,i)))
		{
			count++;
		}
	}

	return count;
}

stock Culture_GetUnlockPoints(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CulturePoints[playerid] : 0;
}

static Culture_SavePoints(playerid)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO culture_points (account_id, points) VALUES (%d, %d) ON DUPLICATE KEY UPDATE points = VALUES(points)",Account_GetId(playerid),s_CulturePoints[playerid]));
}

stock Culture_GiveUnlockPoints(playerid,amount)
{
	if (!Util_IsValidPlayer(playerid) || Account_GetId(playerid) <= 0 || amount == 0)
	{
		return;
	}

	s_CulturePoints[playerid] = max(0,s_CulturePoints[playerid] + amount);
	Culture_SavePoints(playerid);
}

stock bool:Culture_SpendUnlockPoint(playerid,culture)
{
	if (!Util_IsValidPlayer(playerid) || !Culture_IsValid(culture) || Culture_IsAvailable(playerid,culture) || s_CulturePoints[playerid] <= 0 || Account_GetId(playerid) <= 0)
	{
		return false;
	}

	s_CulturePoints[playerid]--;
	s_CultureUnlocked[playerid]{culture} = true;
	Culture_SavePoints(playerid);
	mysql_tquery_s(g_Mysql,str_format("INSERT IGNORE INTO culture_unlocks (account_id, culture) VALUES (%d, %d)",Account_GetId(playerid),culture));
	return true;
}

static Culture_ResetUnlocks(playerid)
{
	for (new i = 0;i < CULTURE_COUNT;i++)
	{
		s_CultureUnlocked[playerid]{i} = false;
	}

	s_CulturePoints[playerid] = 0;
	s_CultureUnlocksLoaded[playerid] = false;
}

forward Culture_LoadUnlocksDeferred(playerid,token);

public Culture_LoadUnlocksDeferred(playerid,token)
{
	yield 1;

	new accountid = Account_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT culture FROM culture_unlocks WHERE account_id = %d",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	for (new row = 0, culture;row < cache_num_rows();row++)
	{
		cache_get_value_name_int(row,"culture",culture);

		if (Culture_IsValid(culture))
		{
			s_CultureUnlocked[playerid]{culture} = true;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT points FROM culture_points WHERE account_id = %d",accountid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"points",s_CulturePoints[playerid]);
	}

	s_CultureUnlocksLoaded[playerid] = true;
}

forward Culture_UnlockCommandGate(playerid);

public Culture_UnlockCommandGate(playerid)
{
	return Account_IsLoremaster(playerid);
}

CMD<ADMIN_LEVEL_NONE>:cultureunlock(cmdid, playerid, params[])
{
	if (!Account_IsLoremaster(playerid))
	{
		Commands_ReplyUnknown(playerid,"cultureunlock");
		return 1;
	}

	new targetid, amount;

	if (sscanf(params,"uI(1)",targetid,amount) || !IsPlayerConnected(targetid) || Account_GetId(targetid) <= 0)
	{
		Command_Usage(playerid,cmdid,"<player> [points]");
		return 1;
	}

	Culture_GiveUnlockPoints(targetid,amount);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Gave %d culture unlock point(s). They have %d now.",amount,Culture_GetUnlockPoints(targetid)));
	SendClientMessage(targetid,0xFFFFFFFF,sprintf("A loremaster gave you %d culture unlock point(s). Use them when you pick a culture for a new character.",amount));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Culture_ResetUnlocks(playerid);
}

hook Account_OnAuthenticated(playerid,accountid)
{
	#pragma unused accountid

	SetTimerEx("Culture_LoadUnlocksDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}
