#define ACCOUNT_USERNAME_MIN (3)
#define ACCOUNT_USERNAME_MAX (20)
#define ACCOUNT_PASSWORD_MIN (6)
#define ACCOUNT_PASSWORD_MAX (64)
#define ACCOUNT_MAX_LOGIN_ATTEMPTS (3)
#define ACCOUNT_DB_RETRY_MS (400)
#define ACCOUNT_BCRYPT_COST (12)
#define ACCOUNT_CHARACTER_SLOTS (2)

enum E_ACCOUNT_AUTH
{
	E_ACCOUNT_AUTH_IDLE,
	E_ACCOUNT_AUTH_LOOKUP,
	E_ACCOUNT_AUTH_DIALOG,
	E_ACCOUNT_AUTH_VERIFYING,
	E_ACCOUNT_AUTH_DONE,
}

enum E_ACCOUNT
{
	E_ACCOUNT_ID,
	E_ACCOUNT_TOKEN,
	E_ACCOUNT_ATTEMPTS,
	E_ACCOUNT_ADMIN_LEVEL,
	bool:E_ACCOUNT_LOREMASTER,
	E_ACCOUNT_AUTH:E_ACCOUNT_AUTH_STATE,
	E_ACCOUNT_NAME[ACCOUNT_USERNAME_MAX + 1],
	E_ACCOUNT_LOOKUP_HASH[BCRYPT_HASH_LENGTH],
}

static s_Account[MAX_PLAYERS][E_ACCOUNT];
static s_AccountNextToken = 0;

stock Account_GetId(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Account[playerid][E_ACCOUNT_ID];
}

stock Account_GetName(playerid,dest[],size = sizeof(dest))
{
	if (!Util_IsValidPlayer(playerid))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Account[playerid][E_ACCOUNT_NAME],size);
}

stock Account_GetAdminLevel(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return ADMIN_LEVEL_NONE;
	}

	return Account_TestStageLevel(playerid,s_Account[playerid][E_ACCOUNT_ADMIN_LEVEL]);
}

stock bool:Account_IsLoremaster(playerid)
{
	return Util_IsValidPlayer(playerid) && (s_Account[playerid][E_ACCOUNT_LOREMASTER] || Account_GetAdminLevel(playerid) >= ADMIN_LEVEL_MANAGER);
}

stock Account_SetLoremaster(playerid,bool:isLoremaster)
{
	if (!Util_IsValidPlayer(playerid) || Account_GetId(playerid) <= 0)
	{
		return;
	}

	s_Account[playerid][E_ACCOUNT_LOREMASTER] = isLoremaster;
	mysql_tquery_s(g_Mysql,str_format("UPDATE accounts SET loremaster = %d WHERE id = %d",isLoremaster,Account_GetId(playerid)));
}

stock bool:Account_HasLoremasterRank(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Account[playerid][E_ACCOUNT_LOREMASTER];
}

Account_LoadLoremaster(playerid,bool:isLoremaster)
{
	s_Account[playerid][E_ACCOUNT_LOREMASTER] = isLoremaster;
}

stock bool:Account_IsAtLeast(playerid,level)
{
	return Account_GetAdminLevel(playerid) >= level;
}

stock Account_GetToken(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0;
	}

	return s_Account[playerid][E_ACCOUNT_TOKEN];
}

Account_NewToken(playerid)
{
	s_Account[playerid][E_ACCOUNT_TOKEN] = ++s_AccountNextToken;
	return s_Account[playerid][E_ACCOUNT_TOKEN];
}

Account_Reset(playerid)
{
	s_Account[playerid][E_ACCOUNT_ID] = 0;
	s_Account[playerid][E_ACCOUNT_TOKEN] = 0;
	s_Account[playerid][E_ACCOUNT_ATTEMPTS] = 0;
	s_Account[playerid][E_ACCOUNT_ADMIN_LEVEL] = ADMIN_LEVEL_NONE;
	s_Account[playerid][E_ACCOUNT_LOREMASTER] = false;
	s_Account[playerid][E_ACCOUNT_AUTH_STATE] = E_ACCOUNT_AUTH_IDLE;
	s_Account[playerid][E_ACCOUNT_NAME][0] = EOS;
	s_Account[playerid][E_ACCOUNT_LOOKUP_HASH][0] = EOS;
}

stock E_ACCOUNT_AUTH:Account_GetAuthState(playerid)
{
	return s_Account[playerid][E_ACCOUNT_AUTH_STATE];
}

Account_SetAuthState(playerid,E_ACCOUNT_AUTH:newState)
{
	s_Account[playerid][E_ACCOUNT_AUTH_STATE] = newState;
}

Account_GetAttempts(playerid)
{
	return s_Account[playerid][E_ACCOUNT_ATTEMPTS];
}

Account_BumpAttempts(playerid)
{
	return ++s_Account[playerid][E_ACCOUNT_ATTEMPTS];
}

Account_SetName(playerid,const name[])
{
	strcopy(s_Account[playerid][E_ACCOUNT_NAME],name,ACCOUNT_USERNAME_MAX + 1);
}

Account_SetLookup(playerid,accountid,const hash[],adminLevel)
{
	s_Account[playerid][E_ACCOUNT_ID] = accountid;
	s_Account[playerid][E_ACCOUNT_ADMIN_LEVEL] = adminLevel;
	strcopy(s_Account[playerid][E_ACCOUNT_LOOKUP_HASH],hash,BCRYPT_HASH_LENGTH);
}

Account_GetLookupHash(playerid,dest[],size = sizeof(dest))
{
	strcopy(dest,s_Account[playerid][E_ACCOUNT_LOOKUP_HASH],size);
}

Account_ClearLookupHash(playerid)
{
	s_Account[playerid][E_ACCOUNT_LOOKUP_HASH][0] = EOS;
}

Account_SetAdminLevel(playerid,level)
{
	s_Account[playerid][E_ACCOUNT_ADMIN_LEVEL] = level;
}

stock bool:Account_ValidateUsername(const name[])
{
	new len = strlen(name);
	if (len < ACCOUNT_USERNAME_MIN || len > ACCOUNT_USERNAME_MAX)
	{
		return false;
	}

	return Util_IsAlphanumeric(name);
}
