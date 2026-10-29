enum E_ORDER
{
	E_ORDER_ID,
	E_ORDER_DEF_INDEX,
	E_ORDER_GIVER[ACTORS_KEY_LEN],
	E_ORDER_ITEM,
	E_ORDER_QTY,
	E_ORDER_STARS,
	E_ORDER_PAY,
	E_ORDER_POSTED,
	E_ORDER_EXPIRES,
	E_ORDER_TAKER,
	bool:E_ORDER_USED,
}

static s_Orders[ORDERS_MAX][E_ORDER];
static s_OrderGoodwillKey[MAX_PLAYERS][ORDERS_GOODWILL_SLOTS][ACTORS_KEY_LEN];
static s_OrderGoodwill[MAX_PLAYERS][ORDERS_GOODWILL_SLOTS];
static s_OrderDailyDay[MAX_PLAYERS];
static s_OrderDailyCount[MAX_PLAYERS];
static bool:s_OrdersLoaded[MAX_PLAYERS];
static s_OrdersReeve = -1;
static s_OrdersBailiff = -1;

forward Orders_CountCarried(playerid);
forward bool:Orders_IsNearActor(playerid,index,Float:range = ORDERS_REACH);
forward bool:Orders_HasDef(const key[],def);
forward Orders_NoteTrial(playerid,trade);

stock Orders_Today()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year);
}

stock Orders_SeasonKey()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return ((year - CALENDAR_EPOCH_YEAR) * CALENDAR_MONTHS + month) / 3;
}

stock bool:Orders_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_OrdersLoaded[playerid];
}

stock Orders_SetLoaded(playerid,bool:isLoaded)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_OrdersLoaded[playerid] = isLoaded;
	}
}

stock Orders_GetReeve()
{
	return s_OrdersReeve;
}

stock Orders_GetBailiff()
{
	return s_OrdersBailiff;
}

stock Orders_PlaceOfficers()
{
	new skins = Skins_CountStarter(0);

	if (s_OrdersReeve == -1 && (g_OrdersReeveSpot[0] != 0.0 || g_OrdersReeveSpot[1] != 0.0))
	{
		s_OrdersReeve = Actors_Register("orders:reeve",ACTOR_ROLE_REEVE,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,7 % skins) : 1,"Mikulas Rychtar","Reeve of Talmberg");

		if (s_OrdersReeve != -1)
		{
			Actors_SetPlace(s_OrdersReeve,g_OrdersReeveSpot[0],g_OrdersReeveSpot[1],g_OrdersReeveSpot[2] + 1.0,g_OrdersReeveSpot[3],0,0);
			Actors_Place(s_OrdersReeve);
		}
	}

	if (s_OrdersBailiff == -1 && (g_OrdersBailiffSpot[0] != 0.0 || g_OrdersBailiffSpot[1] != 0.0))
	{
		s_OrdersBailiff = Actors_Register("orders:bailiff",ACTOR_ROLE_BAILIFF,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,9 % skins) : 1,"Vaclav Drab","Bailiff of the county");

		if (s_OrdersBailiff != -1)
		{
			Actors_SetPlace(s_OrdersBailiff,g_OrdersBailiffSpot[0],g_OrdersBailiffSpot[1],g_OrdersBailiffSpot[2] + 1.0,g_OrdersBailiffSpot[3],0,0);
			Actors_Place(s_OrdersBailiff);
		}
	}
}

stock Orders_GiverKindOf(index)
{
	if (!Actors_IsValid(index))
	{
		return -1;
	}

	new E_ACTOR_ROLE:role = Actors_GetRole(index);

	for (new kind = 0;kind < ORDER_GIVER_COUNT;kind++)
	{
		if (g_OrderGiverRoles[kind] == role)
		{
			return kind;
		}
	}

	return -1;
}

stock bool:Orders_IsGiver(index)
{
	new kind = Orders_GiverKindOf(index);

	if (kind == -1)
	{
		return false;
	}

	new rank = 0;

	for (new other = 0;other < index;other++)
	{
		if (Actors_IsValid(other) && Actors_GetRole(other) == g_OrderGiverRoles[kind])
		{
			rank++;
		}
	}

	return rank < g_OrderGiverCaps[kind];
}

stock Orders_FindGiverNear(playerid,kind,Float:range = ORDERS_REACH)
{
	for (new index = 0;index < ACTORS_MAX;index++)
	{
		if (Orders_GiverKindOf(index) == kind && !Actors_IsDead(index) && Orders_IsNearActor(playerid,index,range))
		{
			return index;
		}
	}

	return -1;
}

stock bool:Orders_IsNearActor(playerid,index,Float:range = ORDERS_REACH)
{
	new Float:x, Float:y, Float:z;
	return Actors_GetPos(index,x,y,z) && IsPlayerInRangeOfPoint(playerid,range,x,y,z);
}

stock bool:Orders_IsValid(slot)
{
	return slot >= 0 && slot < ORDERS_MAX && s_Orders[slot][E_ORDER_USED];
}

stock Orders_GetId(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_ID] : 0;
}

stock Orders_GetDef(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_DEF_INDEX] : -1;
}

stock Orders_GetItem(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_ITEM] : -1;
}

stock Orders_GetQty(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_QTY] : 0;
}

stock Orders_GetStars(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_STARS] : 0;
}

stock Orders_GetPay(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_PAY] : 0;
}

stock Orders_GetExpires(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_EXPIRES] : 0;
}

stock Orders_GetTaker(slot)
{
	return Orders_IsValid(slot) ? s_Orders[slot][E_ORDER_TAKER] : 0;
}

stock Orders_GetGiverKey(slot,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Orders_IsValid(slot))
	{
		strcopy(dest,s_Orders[slot][E_ORDER_GIVER],size);
	}
}

stock Orders_GetGiver(slot)
{
	return Orders_IsValid(slot) ? Actors_FindByKey(s_Orders[slot][E_ORDER_GIVER]) : -1;
}

stock Orders_GetGoodwillNeeded(slot)
{
	return Orders_IsValid(slot) ? g_OrderDefs[s_Orders[slot][E_ORDER_DEF_INDEX]][E_ORDER_DEF_GOODWILL] : 0;
}

stock Orders_FormatText(slot,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Orders_IsValid(slot))
	{
		format(dest,size,g_OrderDefs[s_Orders[slot][E_ORDER_DEF_INDEX]][E_ORDER_DEF_TEXT],s_Orders[slot][E_ORDER_QTY]);
	}
}

stock Orders_Count()
{
	new count = 0;

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (s_Orders[slot][E_ORDER_USED])
		{
			count++;
		}
	}

	return count;
}

stock Orders_CountForGiver(const key[])
{
	new count = 0;

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (s_Orders[slot][E_ORDER_USED] && !strcmp(s_Orders[slot][E_ORDER_GIVER],key))
		{
			count++;
		}
	}

	return count;
}

stock Orders_CountTaken(playerid)
{
	new count = 0, characterid = Character_GetId(playerid);

	for (new slot = 0;characterid > 0 && slot < ORDERS_MAX;slot++)
	{
		if (s_Orders[slot][E_ORDER_USED] && s_Orders[slot][E_ORDER_TAKER] == characterid)
		{
			count++;
		}
	}

	return count;
}

stock Orders_OpenPay()
{
	new total = 0;

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (s_Orders[slot][E_ORDER_USED])
		{
			total += s_Orders[slot][E_ORDER_PAY];
		}
	}

	return total;
}

stock Orders_PriceOf(item,qty,stars)
{
	if (qty <= 0)
	{
		return 0;
	}

	return max(1,qty * Item_GetPrice(Item_GetDefKind(item),item,stars) * ORDERS_PAY_PERCENT / 100);
}

stock Orders_CountHeld(playerid,E_ITEM_KIND:kind,item,minStars)
{
	new total = 0;

	for (new stars = max(minStars,ITEM_STARS_MIN);stars <= ITEM_STARS_MAX;stars++)
	{
		for (new nth = 0, member;(member = Item_GetGroupMember(item,nth)) != -1;nth++)
		{
			total += Inventory_Count(playerid,nth == 0 ? kind : Item_GetDefKind(member),member,stars);
		}
	}

	return total;
}

stock Orders_TakeGoods(playerid,item,amount,minStars,&starSum,bool:toTreasury = true,claimFor = 0,const reason[] = "")
{
	new E_ITEM_KIND:kind = Item_GetDefKind(item), left = amount, pay = 0;
	starSum = 0;

	for (new stars = max(minStars,ITEM_STARS_MIN);stars <= ITEM_STARS_MAX && left > 0;stars++)
	{
		for (new nth = 0, member;left > 0 && (member = Item_GetGroupMember(item,nth)) != -1;nth++)
		{
			new E_ITEM_KIND:memberKind = nth == 0 ? kind : Item_GetDefKind(member), take = min(left,Inventory_Count(playerid,memberKind,member,stars));

			if (take <= 0 || !Inventory_Take(playerid,memberKind,member,take,stars))
			{
				continue;
			}

			left -= take;
			starSum += take * stars;
			pay += take * Item_GetPrice(memberKind,member,stars) * ORDERS_PAY_PERCENT / 100;

			if (toTreasury)
			{
				Realm_StoreInTreasury(memberKind,member,take,stars);
			}
			else if (claimFor > 0)
			{
				Claims_Give(claimFor,memberKind,member,take,stars,reason);
			}
		}
	}

	return pay;
}

stock Orders_FindFree()
{
	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (!s_Orders[slot][E_ORDER_USED])
		{
			return slot;
		}
	}

	return -1;
}

stock Orders_Add(id,def,const giver[],item,qty,stars,pay,posted,expires,taker)
{
	new slot = Orders_FindFree();

	if (slot == -1 || def < 0 || def >= sizeof(g_OrderDefs))
	{
		return -1;
	}

	s_Orders[slot][E_ORDER_ID] = id;
	s_Orders[slot][E_ORDER_DEF_INDEX] = def;
	strcopy(s_Orders[slot][E_ORDER_GIVER],giver,ACTORS_KEY_LEN);
	s_Orders[slot][E_ORDER_ITEM] = item;
	s_Orders[slot][E_ORDER_QTY] = qty;
	s_Orders[slot][E_ORDER_STARS] = stars;
	s_Orders[slot][E_ORDER_PAY] = pay;
	s_Orders[slot][E_ORDER_POSTED] = posted;
	s_Orders[slot][E_ORDER_EXPIRES] = expires;
	s_Orders[slot][E_ORDER_TAKER] = taker;
	s_Orders[slot][E_ORDER_USED] = true;
	return slot;
}

stock Orders_Remove(slot)
{
	if (!Orders_IsValid(slot))
	{
		return;
	}

	if (s_Orders[slot][E_ORDER_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM orders WHERE id = %d",s_Orders[slot][E_ORDER_ID]));
	}

	s_Orders[slot][E_ORDER_USED] = false;
	s_Orders[slot][E_ORDER_ID] = 0;
	s_Orders[slot][E_ORDER_TAKER] = 0;
}

static Orders_SaveTaker(slot)
{
	if (s_Orders[slot][E_ORDER_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE orders SET taken_by = NULLIF(%d, 0) WHERE id = %d",s_Orders[slot][E_ORDER_TAKER],s_Orders[slot][E_ORDER_ID]));
	}
}

forward Task:Orders_Insert(slot);

public Task:Orders_Insert(slot)
{
	new Task:done = task_new(), def = s_Orders[slot][E_ORDER_DEF_INDEX];
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO orders (giver_key, def, item, qty, min_stars, pay, posted_day, expires_day) VALUES ('%e', %d, %d, %d, %d, %d, %d, %d)",s_Orders[slot][E_ORDER_GIVER],def,s_Orders[slot][E_ORDER_ITEM],s_Orders[slot][E_ORDER_QTY],s_Orders[slot][E_ORDER_STARS],s_Orders[slot][E_ORDER_PAY],s_Orders[slot][E_ORDER_POSTED],s_Orders[slot][E_ORDER_EXPIRES]));
	new id = cache_insert_id();

	if (s_Orders[slot][E_ORDER_USED] && s_Orders[slot][E_ORDER_DEF_INDEX] == def && s_Orders[slot][E_ORDER_ID] == 0)
	{
		s_Orders[slot][E_ORDER_ID] = id;
		Orders_SaveTaker(slot);
	}
	else if (id > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM orders WHERE id = %d",id));
	}

	task_set_result(done,id);
	return done;
}

static Orders_PickDef(giver,E_SEASON:season,const key[])
{
	new picks[sizeof(g_OrderDefs)], count = 0;

	for (new def = 0;def < sizeof(g_OrderDefs);def++)
	{
		if (g_OrderDefs[def][E_ORDER_DEF_GIVER] != giver || !(g_OrderDefs[def][E_ORDER_DEF_SEASONS] & ORDERS_SEASON(season)) || Orders_HasDef(key,def))
		{
			continue;
		}

		picks[count++] = def;
	}

	return count > 0 ? picks[random(count)] : -1;
}

stock bool:Orders_HasDef(const key[],def)
{
	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (s_Orders[slot][E_ORDER_USED] && s_Orders[slot][E_ORDER_DEF_INDEX] == def && !strcmp(s_Orders[slot][E_ORDER_GIVER],key))
		{
			return true;
		}
	}

	return false;
}

stock Orders_Roll(index)
{
	new giver = Orders_GiverKindOf(index);

	if (giver == -1 || !Orders_IsGiver(index) || Actors_IsDead(index))
	{
		return 0;
	}

	new key[ACTORS_KEY_LEN], want = 1 + random(ORDERS_PER_GIVER), posted = 0, today = Orders_Today(), E_SEASON:season = Calendar_GetSeason();
	Actors_GetKey(index,key);

	while (Orders_CountForGiver(key) < want)
	{
		new def = Orders_PickDef(giver,season,key);

		if (def == -1)
		{
			break;
		}

		new qty = g_OrderDefs[def][E_ORDER_DEF_QTY_MIN] + random(g_OrderDefs[def][E_ORDER_DEF_QTY_MAX] - g_OrderDefs[def][E_ORDER_DEF_QTY_MIN] + 1), item = g_OrderDefs[def][E_ORDER_DEF_ITEM], stars = g_OrderDefs[def][E_ORDER_DEF_STARS], pay = Orders_PriceOf(item,qty,stars);

		if (Realm_TreasuryCoin() < Orders_OpenPay() + pay)
		{
			break;
		}

		new slot = Orders_Add(0,def,key,item,qty,stars,pay,today,today + ORDERS_LIFE_DAYS,0);

		if (slot == -1)
		{
			break;
		}

		Orders_Insert(slot);
		posted++;
		pawn_call_public("Orders_OnPosted","d",slot);
	}

	return posted;
}

stock Orders_RollAll()
{
	new posted = 0;

	for (new index = 0;index < ACTORS_MAX;index++)
	{
		if (Orders_GiverKindOf(index) != -1)
		{
			posted += Orders_Roll(index);
		}
	}

	return posted;
}

stock Orders_ExpireAll(today)
{
	new expired = 0;

	for (new slot = 0;slot < ORDERS_MAX;slot++)
	{
		if (!s_Orders[slot][E_ORDER_USED] || s_Orders[slot][E_ORDER_EXPIRES] >= today)
		{
			continue;
		}

		new taker = s_Orders[slot][E_ORDER_TAKER];

		if (taker > 0)
		{
			new playerid = Claims_FindPlayer(taker), text[ORDERS_TEXT_LEN];

			if (playerid != INVALID_PLAYER_ID)
			{
				Orders_FormatText(slot,text);
				Subtitle_Show(playerid,sprintf("~w~Too late: the %s no longer wants %s.",g_OrderGiverNames[g_OrderDefs[s_Orders[slot][E_ORDER_DEF_INDEX]][E_ORDER_DEF_GIVER]],text));
			}
		}

		pawn_call_public("Orders_OnExpired","d",slot);
		Orders_Remove(slot);
		expired++;
	}

	return expired;
}

stock Orders_Accept(playerid,slot)
{
	if (!Orders_IsValid(slot))
	{
		return ORDER_GONE;
	}

	new characterid = Character_GetId(playerid);

	if (s_Orders[slot][E_ORDER_TAKER] != 0)
	{
		return s_Orders[slot][E_ORDER_TAKER] == characterid ? ORDER_OK : ORDER_TAKEN;
	}

	if (Orders_CountCarried(playerid) >= ORDERS_TAKEN_MAX)
	{
		return ORDER_TOO_MANY;
	}

	if (Orders_GetGoodwillByKey(playerid,s_Orders[slot][E_ORDER_GIVER]) < Orders_GetGoodwillNeeded(slot))
	{
		return ORDER_GOODWILL;
	}

	s_Orders[slot][E_ORDER_TAKER] = characterid;
	Orders_SaveTaker(slot);
	pawn_call_public("Orders_OnAccepted","dd",playerid,slot);
	return ORDER_OK;
}

stock Orders_Abandon(playerid,slot)
{
	if (!Orders_IsValid(slot))
	{
		return ORDER_GONE;
	}

	if (s_Orders[slot][E_ORDER_TAKER] != Character_GetId(playerid))
	{
		return ORDER_NOT_YOURS;
	}

	s_Orders[slot][E_ORDER_TAKER] = 0;
	Orders_SaveTaker(slot);
	return ORDER_OK;
}

stock Orders_GetDailyCount(playerid)
{
	return Util_IsValidPlayer(playerid) && s_OrderDailyDay[playerid] == Orders_Today() ? s_OrderDailyCount[playerid] : 0;
}

stock Orders_SetDaily(playerid,day,count)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_OrderDailyDay[playerid] = day;
		s_OrderDailyCount[playerid] = count;
	}
}

static Orders_NoteDelivery(playerid)
{
	new today = Orders_Today();

	if (s_OrderDailyDay[playerid] != today)
	{
		s_OrderDailyDay[playerid] = today;
		s_OrderDailyCount[playerid] = 0;
	}

	s_OrderDailyCount[playerid]++;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO order_daily (character_id, day, count) VALUES (%d, %d, %d) ON DUPLICATE KEY UPDATE day = VALUES(day), count = VALUES(count)",Character_GetId(playerid),today,s_OrderDailyCount[playerid]));
}

stock Orders_Deliver(playerid,slot)
{
	if (!Orders_IsValid(slot))
	{
		return ORDER_GONE;
	}

	if (s_Orders[slot][E_ORDER_TAKER] != Character_GetId(playerid))
	{
		return ORDER_NOT_YOURS;
	}

	new giver = Actors_FindByKey(s_Orders[slot][E_ORDER_GIVER]);

	if (giver == -1 || Actors_IsDead(giver))
	{
		return ORDER_GIVER_DEAD;
	}

	if (!Orders_IsNearActor(playerid,giver))
	{
		return ORDER_TOO_FAR;
	}

	if (Orders_GetDailyCount(playerid) >= ORDERS_DAILY_DELIVERIES)
	{
		return ORDER_DAILY_CAP;
	}

	new item = s_Orders[slot][E_ORDER_ITEM], qty = s_Orders[slot][E_ORDER_QTY], stars = s_Orders[slot][E_ORDER_STARS], E_ITEM_KIND:kind = Item_GetDefKind(item);

	if (Orders_CountHeld(playerid,kind,item,stars) < qty)
	{
		return ORDER_MISSING_GOODS;
	}

	if (Realm_TreasuryCoin() < s_Orders[slot][E_ORDER_PAY])
	{
		return ORDER_PURSE;
	}

	new starSum, pay = max(s_Orders[slot][E_ORDER_PAY],Orders_TakeGoods(playerid,item,qty,stars,starSum));
	pay = min(pay,Realm_TreasuryCoin());

	Realm_PayFromTreasury(playerid,pay,"work order",true);

	new average = starSum / max(qty,1), key[ACTORS_KEY_LEN];
	strcopy(key,s_Orders[slot][E_ORDER_GIVER]);
	Orders_AddGoodwill(playerid,key,average >= stars + ORDERS_BONUS_STARS ? 2 : 1);
	Orders_NoteDelivery(playerid);

	if (average >= ORDERS_TRIAL_STARS)
	{
		Orders_NoteTrial(playerid,Trader_GetItemTrade(kind,item));
	}

	pawn_call_public("Orders_OnDelivered","ddd",playerid,slot,average);
	Orders_Remove(slot);
	return ORDER_OK;
}

stock Orders_FindGoodwillSlot(playerid,const key[])
{
	for (new i = 0;i < ORDERS_GOODWILL_SLOTS;i++)
	{
		if (s_OrderGoodwillKey[playerid][i][0] != EOS && !strcmp(s_OrderGoodwillKey[playerid][i],key))
		{
			return i;
		}
	}

	return -1;
}

stock Orders_GetGoodwillByKey(playerid,const key[])
{
	if (!Util_IsValidPlayer(playerid) || key[0] == EOS)
	{
		return 0;
	}

	new i = Orders_FindGoodwillSlot(playerid,key);
	return i == -1 ? 0 : s_OrderGoodwill[playerid][i];
}

stock Orders_GetGoodwill(playerid,index)
{
	new key[ACTORS_KEY_LEN];
	Actors_GetKey(index,key);
	return Orders_GetGoodwillByKey(playerid,key);
}

stock Orders_SetGoodwillByKey(playerid,const key[],value,bool:isSaved = true)
{
	if (!Util_IsValidPlayer(playerid) || key[0] == EOS)
	{
		return;
	}

	new i = Orders_FindGoodwillSlot(playerid,key);

	if (i == -1)
	{
		for (new free = 0;free < ORDERS_GOODWILL_SLOTS;free++)
		{
			if (s_OrderGoodwillKey[playerid][free][0] == EOS)
			{
				i = free;
				break;
			}
		}
	}

	if (i == -1)
	{
		return;
	}

	strcopy(s_OrderGoodwillKey[playerid][i],key,ACTORS_KEY_LEN);
	s_OrderGoodwill[playerid][i] = clamp(value,0,ORDERS_GOODWILL_MAX);

	if (isSaved && Character_GetId(playerid) > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO order_goodwill (character_id, giver_key, goodwill) VALUES (%d, '%e', %d) ON DUPLICATE KEY UPDATE goodwill = VALUES(goodwill)",Character_GetId(playerid),key,s_OrderGoodwill[playerid][i]));
	}
}

stock Orders_AddGoodwill(playerid,const key[],delta)
{
	Orders_SetGoodwillByKey(playerid,key,Orders_GetGoodwillByKey(playerid,key) + delta);
}

stock Orders_GoodwillWords(goodwill,dest[],size = sizeof(dest))
{
	if (goodwill >= 12)
	{
		strcopy(dest,"They trust you with anything.",size);
	}
	else if (goodwill >= 6)
	{
		strcopy(dest,"They think well of you.",size);
	}
	else if (goodwill >= 2)
	{
		strcopy(dest,"They know your face.",size);
	}
	else
	{
		strcopy(dest,"They don't know you yet.",size);
	}
}

stock Orders_ResetPlayer(playerid)
{
	for (new i = 0;i < ORDERS_GOODWILL_SLOTS;i++)
	{
		s_OrderGoodwillKey[playerid][i][0] = EOS;
		s_OrderGoodwill[playerid][i] = 0;
	}

	s_OrderDailyDay[playerid] = -1;
	s_OrderDailyCount[playerid] = 0;
	s_OrdersLoaded[playerid] = false;
}

forward Task:Orders_Load();

#pragma warning push
#pragma warning disable 204
async Task:Orders_Load()
{
	new loaded = 0;
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, giver_key, def, item, qty, min_stars, pay, posted_day, expires_day, IFNULL(taken_by, 0) AS taker FROM orders"));

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, key[ACTORS_KEY_LEN], def, item, qty, stars, pay, posted, expires, taker;
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name(row,"giver_key",key);
		cache_get_value_name_int(row,"def",def);
		cache_get_value_name_int(row,"item",item);
		cache_get_value_name_int(row,"qty",qty);
		cache_get_value_name_int(row,"min_stars",stars);
		cache_get_value_name_int(row,"pay",pay);
		cache_get_value_name_int(row,"posted_day",posted);
		cache_get_value_name_int(row,"expires_day",expires);
		cache_get_value_name_int(row,"taker",taker);

		if (def < 0 || def >= sizeof(g_OrderDefs) || Orders_Add(id,def,key,item,qty,stars,pay,posted,expires,taker) == -1)
		{
			mysql_tquery_s(g_Mysql,str_format("DELETE FROM orders WHERE id = %d",id));
			continue;
		}

		loaded++;
	}

	return async loaded;
}
#pragma warning pop

forward Task:Orders_LoadPlayer(playerid,characterid);

#pragma warning push
#pragma warning disable 204
async Task:Orders_LoadPlayer(playerid,characterid)
{
	new token = Account_GetToken(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT giver_key, goodwill FROM order_goodwill WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new key[ACTORS_KEY_LEN], goodwill;
		cache_get_value_name(row,"giver_key",key);
		cache_get_value_name_int(row,"goodwill",goodwill);
		Orders_SetGoodwillByKey(playerid,key,goodwill,false);
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT day, count FROM order_daily WHERE character_id = %d",characterid));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return async 0;
	}

	if (cache_num_rows() > 0)
	{
		new day, count;
		cache_get_value_name_int(0,"day",day);
		cache_get_value_name_int(0,"count",count);
		Orders_SetDaily(playerid,day,count);
	}

	return async 1;
}
#pragma warning pop

forward Orders_OnPosted(slot);

public Orders_OnPosted(slot)
{
	return 1;
}

forward Orders_OnAccepted(playerid,slot);

public Orders_OnAccepted(playerid,slot)
{
	return 1;
}

forward Orders_OnDelivered(playerid,slot,stars);

public Orders_OnDelivered(playerid,slot,stars)
{
	return 1;
}

forward Orders_OnExpired(slot);

public Orders_OnExpired(slot)
{
	return 1;
}

forward Orders_DayDeferred();

public Orders_DayDeferred()
{
	Orders_ExpireAll(Orders_Today());
	Orders_RollAll();
	return 1;
}
