static s_OrderTrialSeason[MAX_PLAYERS] = {-1, ...};
static s_OrderTrial[MAX_PLAYERS][TRADE_COUNT];
static s_OrderWarrants[MAX_PLAYERS];

forward bool:Orders_HasWarrant(playerid,trade);

stock Orders_ResetSteward(playerid)
{
	s_OrderTrialSeason[playerid] = -1;
	s_OrderWarrants[playerid] = 0;

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		s_OrderTrial[playerid][trade] = 0;
	}
}

static Orders_SyncTrialSeason(playerid)
{
	new key = Orders_SeasonKey();

	if (s_OrderTrialSeason[playerid] == key)
	{
		return;
	}

	s_OrderTrialSeason[playerid] = key;

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		s_OrderTrial[playerid][trade] = 0;
	}
}

stock Orders_GetTrial(playerid,trade)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade))
	{
		return 0;
	}

	Orders_SyncTrialSeason(playerid);
	return s_OrderTrial[playerid][trade];
}

stock Orders_SetTrial(playerid,trade,count,bool:isSaved = true)
{
	if (!Util_IsValidPlayer(playerid) || !Trade_IsValid(trade))
	{
		return;
	}

	Orders_SyncTrialSeason(playerid);
	s_OrderTrial[playerid][trade] = max(count,0);

	if (isSaved && Character_GetId(playerid) > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO order_trials (character_id, trade, season_key, count) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE count = VALUES(count)",Character_GetId(playerid),trade,s_OrderTrialSeason[playerid],s_OrderTrial[playerid][trade]));
	}
}

public Orders_NoteTrial(playerid,trade)
{
	if (!Trade_IsValid(trade) || Orders_CraftOccupation(trade) == -1)
	{
		return 0;
	}

	new count = Orders_GetTrial(playerid,trade) + 1;
	Orders_SetTrial(playerid,trade,count);

	if (count == ORDERS_TRIAL_NEEDED - 1 && !Orders_HasWarrant(playerid,trade))
	{
		new name[24], text[ORDERS_LEDGER_LEN];
		Trade_GetName(trade,name);
		format(text,sizeof(text),"One more order at three stars and the steward may grant a %s's warrant.",name);
		Ledger_Suggest(playerid,text);
	}

	return 1;
}

stock Orders_CraftOccupation(trade)
{
	for (new occupation = 0;occupation < OCCUPATION_COUNT;occupation++)
	{
		if (Occupation_GetTrade(occupation) == trade && Occupation_GetRung(occupation) == RUNG_CRAFTSMAN)
		{
			return occupation;
		}
	}

	return -1;
}

stock bool:Orders_HasWarrant(playerid,trade)
{
	return Util_IsValidPlayer(playerid) && trade >= 0 && trade < 32 && (s_OrderWarrants[playerid] & (1 << trade)) != 0;
}

stock Orders_CountWarrants(playerid)
{
	new count = 0;

	for (new trade = 0;trade < TRADE_COUNT;trade++)
	{
		if (Orders_HasWarrant(playerid,trade))
		{
			count++;
		}
	}

	return count;
}

stock Orders_SetWarrant(playerid,trade,bool:isGranted)
{
	if (!Util_IsValidPlayer(playerid) || trade < 0 || trade >= 32)
	{
		return;
	}

	if (isGranted)
	{
		s_OrderWarrants[playerid] |= (1 << trade);
	}
	else
	{
		s_OrderWarrants[playerid] &= ~(1 << trade);
	}
}

stock Orders_WarrantFee()
{
	return Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_PETITION_CRAFT);
}

stock Orders_CanAskWarrant(playerid,trade)
{
	if (!Trade_IsValid(trade) || Orders_CraftOccupation(trade) == -1)
	{
		return ORDER_BAD_INPUT;
	}

	if (Orders_HasWarrant(playerid,trade))
	{
		return ORDER_DONE_ALREADY;
	}

	if (!Realm_IsVacant())
	{
		return ORDER_NOT_NOW;
	}

	if (Orders_GetTrial(playerid,trade) < ORDERS_TRIAL_NEEDED || Work_GetLevel(playerid,trade) < ORDERS_TRIAL_LEVEL)
	{
		return ORDER_GOODWILL;
	}

	return ORDER_OK;
}

stock Orders_GrantWarrant(playerid,trade)
{
	new result = Orders_CanAskWarrant(playerid,trade);

	if (result != ORDER_OK)
	{
		return result;
	}

	new fee = Orders_WarrantFee();

	if (fee > 0 && Economy_Pay(playerid,fee,Realm_GetTreasury(),"craft warrant") != PAY_OK)
	{
		return ORDER_NO_COIN;
	}

	Orders_SetWarrant(playerid,trade,true);
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO order_warrants (character_id, trade, granted_by) VALUES (%d, %d, 'steward') ON DUPLICATE KEY UPDATE granted_by = VALUES(granted_by), granted_at = NOW()",Character_GetId(playerid),trade));
	pawn_call_public("Orders_OnWarrant","dd",playerid,trade);
	return ORDER_OK;
}

forward Task:Orders_LoadSteward(playerid,characterid);

#pragma warning push
#pragma warning disable 204
async Task:Orders_LoadSteward(playerid,characterid)
{
	new token = Account_GetToken(playerid), key = Orders_SeasonKey();
	Orders_ResetSteward(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT trade, count FROM order_trials WHERE character_id = %d AND season_key = %d",characterid,key));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	Orders_SyncTrialSeason(playerid);

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new trade, count;
		cache_get_value_name_int(row,"trade",trade);
		cache_get_value_name_int(row,"count",count);

		if (Trade_IsValid(trade))
		{
			s_OrderTrial[playerid][trade] = count;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT trade FROM order_warrants WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return async 0;
	}

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new trade;
		cache_get_value_name_int(row,"trade",trade);
		Orders_SetWarrant(playerid,trade,true);
	}

	return async 1;
}
#pragma warning pop

forward Orders_OnWarrant(playerid,trade);

public Orders_OnWarrant(playerid,trade)
{
	return 1;
}
