static s_OrderDutySeason[MAX_PLAYERS] = {-1, ...};
static s_OrderDutyState[MAX_PLAYERS][sizeof(g_OrderDutyDefs)];
static s_OrderDutyPrevMissed[MAX_PLAYERS];
static s_OrderDutyOwed[MAX_PLAYERS];
static s_OrderDutyOwedSeason[MAX_PLAYERS][sizeof(g_OrderDutyDefs)];
static s_OrderDutyLastPay[MAX_PLAYERS];

forward bool:Orders_IsDutyValid(duty);

stock Orders_DutyCount()
{
	return sizeof(g_OrderDutyDefs);
}

stock Orders_DutyPay(duty)
{
	if (!Orders_IsDutyValid(duty) || g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_OWED])
	{
		return 0;
	}

	new item = g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_ITEM];
	return max(1,g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_QTY] * Item_GetPrice(Item_GetDefKind(item),item,ITEM_STARS_MIN) * ORDERS_DUTY_PAY_PERCENT / 100);
}

stock Orders_GetLastDutyPay(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_OrderDutyLastPay[playerid] : 0;
}

stock bool:Orders_IsDutyValid(duty)
{
	return duty >= 0 && duty < sizeof(g_OrderDutyDefs);
}

stock Orders_DutyGiver(duty)
{
	return Orders_IsDutyValid(duty) ? g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_GIVER] : -1;
}

stock Orders_DutyText(duty,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Orders_IsDutyValid(duty))
	{
		new goods[40];
		Orders_DutyGoods(duty,goods);
		format(dest,size,"the %s: %s (%s)",g_OrderGiverNames[g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_GIVER]],g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_TEXT],goods);
	}
}

stock Orders_DutyGoods(duty,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Orders_IsDutyValid(duty))
	{
		new item = g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_ITEM], name[32];
		Item_GetName(Item_GetDefKind(item),item,name);
		format(dest,size,"%d x %s",g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_QTY],name);
	}
}

stock bool:Orders_IsDutyOpen(duty)
{
	if (!Orders_IsDutyValid(duty))
	{
		return false;
	}

	if (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_FEAST])
	{
		return Events_FindKind(EVENT_FESTIVAL) != -1 || Realm_IsDecreeActive(REALM_DECREE_FEAST);
	}

	if (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_SEASON] != _:Calendar_GetSeason())
	{
		return false;
	}

	return !g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_FULL_MOON] || Calendar_GetMoon() == MOON_FULL;
}

stock bool:Orders_IsDutyThisSeason(duty)
{
	return Orders_IsDutyValid(duty) && (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_FEAST] || g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_SEASON] == _:Calendar_GetSeason());
}

static Orders_SyncDutySeason(playerid)
{
	new key = Orders_SeasonKey();

	if (s_OrderDutySeason[playerid] == key)
	{
		return;
	}

	s_OrderDutySeason[playerid] = key;

	for (new duty = 0;duty < sizeof(g_OrderDutyDefs);duty++)
	{
		s_OrderDutyState[playerid][duty] = ORDER_DUTY_OPEN;
	}
}

stock Orders_GetDutyState(playerid,duty)
{
	if (!Util_IsValidPlayer(playerid) || !Orders_IsDutyValid(duty))
	{
		return ORDER_DUTY_OPEN;
	}

	Orders_SyncDutySeason(playerid);
	return s_OrderDutyState[playerid][duty];
}

stock bool:Orders_IsDutyOwed(playerid,duty)
{
	return Util_IsValidPlayer(playerid) && Orders_IsDutyValid(duty) && (s_OrderDutyOwed[playerid] & (1 << duty)) != 0;
}

stock bool:Orders_MissedLastSeason(playerid,giver)
{
	for (new duty = 0;Util_IsValidPlayer(playerid) && duty < sizeof(g_OrderDutyDefs);duty++)
	{
		if ((s_OrderDutyPrevMissed[playerid] & (1 << duty)) && g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_GIVER] == giver)
		{
			return true;
		}
	}

	return false;
}

static Orders_SaveDuty(playerid,seasonKey,duty,dutyState)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO order_duty_marks (character_id, season_key, duty, state) VALUES (%d, %d, %d, %d) ON DUPLICATE KEY UPDATE state = VALUES(state)",Character_GetId(playerid),seasonKey,duty,dutyState));
}

stock Orders_SetDutyState(playerid,duty,dutyState,bool:isSaved = true)
{
	if (!Util_IsValidPlayer(playerid) || !Orders_IsDutyValid(duty))
	{
		return;
	}

	Orders_SyncDutySeason(playerid);
	s_OrderDutyState[playerid][duty] = dutyState;

	if (isSaved && Character_GetId(playerid) > 0)
	{
		Orders_SaveDuty(playerid,s_OrderDutySeason[playerid],duty,dutyState);
	}
}

stock Orders_SetDutyOwed(playerid,duty,seasonKey,bool:isOwed)
{
	if (!Util_IsValidPlayer(playerid) || !Orders_IsDutyValid(duty))
	{
		return;
	}

	if (isOwed)
	{
		s_OrderDutyOwed[playerid] |= (1 << duty);
		s_OrderDutyOwedSeason[playerid][duty] = seasonKey;
	}
	else
	{
		s_OrderDutyOwed[playerid] &= ~(1 << duty);
	}
}

stock Orders_DeliverDuty(playerid,duty)
{
	if (!Orders_IsDutyValid(duty))
	{
		return ORDER_GONE;
	}

	new bool:isOwed = Orders_IsDutyOwed(playerid,duty);

	if (!isOwed)
	{
		if (!Orders_IsDutyOpen(duty))
		{
			return ORDER_NOT_NOW;
		}

		if (Orders_GetDutyState(playerid,duty) == ORDER_DUTY_DONE)
		{
			return ORDER_DONE_ALREADY;
		}
	}

	new giver = Orders_FindGiverNear(playerid,g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_GIVER]);

	if (giver == -1)
	{
		return ORDER_TOO_FAR;
	}

	new item = g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_ITEM], qty = g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_QTY];

	if (Orders_CountHeld(playerid,Item_GetDefKind(item),item,ITEM_STARS_MIN) < qty)
	{
		return ORDER_MISSING_GOODS;
	}

	new starSum, key[ACTORS_KEY_LEN];
	Orders_TakeGoods(playerid,item,qty,ITEM_STARS_MIN,starSum);
	Actors_GetKey(giver,key);
	Orders_AddGoodwill(playerid,key,ORDERS_DUTY_GOODWILL);
	new pay = Orders_DutyPay(duty);
	s_OrderDutyLastPay[playerid] = pay > 0 && Realm_TreasuryCoin() >= pay && Realm_PayFromTreasury(playerid,pay,"duty",true) ? pay : 0;

	if (isOwed)
	{
		Orders_SaveDuty(playerid,s_OrderDutyOwedSeason[playerid][duty],duty,ORDER_DUTY_PAID_LATE);
		Orders_SetDutyOwed(playerid,duty,0,false);
	}
	else
	{
		Orders_SetDutyState(playerid,duty,ORDER_DUTY_DONE);
	}

	pawn_call_public("Orders_OnDutyDone","dd",playerid,duty);
	return ORDER_OK;
}

stock Orders_CloseSeasonFor(playerid,endedKey,E_SEASON:ended)
{
	if (!Orders_IsLoaded(playerid))
	{
		return;
	}

	s_OrderDutyPrevMissed[playerid] = 0;

	for (new duty = 0;duty < sizeof(g_OrderDutyDefs);duty++)
	{
		if (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_FEAST] || g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_SEASON] != _:ended)
		{
			continue;
		}

		new dutyState = s_OrderDutySeason[playerid] == endedKey ? s_OrderDutyState[playerid][duty] : ORDER_DUTY_OPEN;

		if (dutyState == ORDER_DUTY_DONE)
		{
			continue;
		}

		s_OrderDutyPrevMissed[playerid] |= (1 << duty);

		if (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_OWED])
		{
			Orders_SaveDuty(playerid,endedKey,duty,ORDER_DUTY_OWED);
			Orders_SetDutyOwed(playerid,duty,endedKey,true);
		}
		else
		{
			Orders_SaveDuty(playerid,endedKey,duty,ORDER_DUTY_MISSED);
		}
	}
}

stock Orders_ResetDuties(playerid)
{
	s_OrderDutySeason[playerid] = -1;
	s_OrderDutyPrevMissed[playerid] = 0;
	s_OrderDutyOwed[playerid] = 0;

	for (new duty = 0;duty < sizeof(g_OrderDutyDefs);duty++)
	{
		s_OrderDutyState[playerid][duty] = ORDER_DUTY_OPEN;
		s_OrderDutyOwedSeason[playerid][duty] = 0;
	}
}

stock Orders_AnnounceDuties(E_SEASON:season)
{
	new name[16], body[256];
	Calendar_SeasonName(season,name);
	body[0] = EOS;

	for (new duty = 0;duty < sizeof(g_OrderDutyDefs);duty++)
	{
		if (g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_SEASON] != _:season)
		{
			continue;
		}

		new line[72];
		format(line,sizeof(line),"%sthe %s asks %s",body[0] != EOS ? ("; ") : (""),g_OrderGiverNames[g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_GIVER]],g_OrderDutyDefs[duty][E_ORDER_DUTY_DEF_TEXT]);
		strcat(body,line);
	}

	if (body[0] != EOS)
	{
		strcat(body,".");
		Crier_Announce("duty",sprintf("The %s's duties",name),body);
	}
}

forward Task:Orders_LoadDuties(playerid,characterid);

#pragma warning push
#pragma warning disable 204
async Task:Orders_LoadDuties(playerid,characterid)
{
	new token = Account_GetToken(playerid), key = Orders_SeasonKey();
	Orders_ResetDuties(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT season_key, duty, state FROM order_duty_marks WHERE character_id = %d AND (season_key >= %d OR state = %d)",characterid,key - 1,ORDER_DUTY_OWED));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	Orders_SyncDutySeason(playerid);

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new seasonKey, duty, dutyState;
		cache_get_value_name_int(row,"season_key",seasonKey);
		cache_get_value_name_int(row,"duty",duty);
		cache_get_value_name_int(row,"state",dutyState);

		if (!Orders_IsDutyValid(duty))
		{
			continue;
		}

		if (dutyState == ORDER_DUTY_OWED)
		{
			Orders_SetDutyOwed(playerid,duty,seasonKey,true);
		}

		if (seasonKey == key)
		{
			s_OrderDutyState[playerid][duty] = dutyState;
		}
		else if (seasonKey == key - 1 && (dutyState == ORDER_DUTY_MISSED || dutyState == ORDER_DUTY_OWED))
		{
			s_OrderDutyPrevMissed[playerid] |= (1 << duty);
		}
	}

	return async 1;
}
#pragma warning pop

forward Orders_OnDutyDone(playerid,duty);

public Orders_OnDutyDone(playerid,duty)
{
	return 1;
}

forward Orders_SeasonDeferred(endedKey,ended,started);

public Orders_SeasonDeferred(endedKey,ended,started)
{
	foreach(new playerid : Player)
	{
		Orders_CloseSeasonFor(playerid,endedKey,E_SEASON:ended);
	}

	Orders_AnnounceDuties(E_SEASON:started);
	return 1;
}
