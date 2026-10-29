#define CHARACTER_BUSY_MAX (24)
#define CHARACTER_BUSY_NAME_LEN (40)

static s_CharacterBusyChecks[CHARACTER_BUSY_MAX][CHARACTER_BUSY_NAME_LEN];
static s_CharacterBusyCount;

stock bool:Character_RegisterBusyCheck(const checkPublic[])
{
	for (new i = 0;i < s_CharacterBusyCount;i++)
	{
		if (!strcmp(s_CharacterBusyChecks[i],checkPublic))
		{
			return true;
		}
	}

	if (s_CharacterBusyCount >= CHARACTER_BUSY_MAX)
	{
		Log_Error("character","busy check table full - '%s' not registered",checkPublic);
		return false;
	}

	strcopy(s_CharacterBusyChecks[s_CharacterBusyCount],checkPublic,CHARACTER_BUSY_NAME_LEN);
	s_CharacterBusyCount++;
	return true;
}

stock bool:Character_IsBusy(playerid)
{
	if (!IsPlayerConnected(playerid) || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		return true;
	}

	for (new i = 0;i < s_CharacterBusyCount;i++)
	{
		if (pawn_call_public(s_CharacterBusyChecks[i],"d",playerid))
		{
			return true;
		}
	}

	return false;
}
