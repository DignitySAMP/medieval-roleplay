#define ORDERS_CONTRACTS_PER_POSTER (3)
#define ORDERS_POSTER_LEN (MAX_PLAYER_NAME + 8)

enum E_CONTRACT
{
	E_CONTRACT_ID,
	E_CONTRACT_POSTER,
	E_CONTRACT_POSTER_NAME[ORDERS_POSTER_LEN],
	E_CONTRACT_ITEM,
	E_CONTRACT_QTY,
	E_CONTRACT_STARS,
	E_CONTRACT_PAY,
	E_CONTRACT_EXPIRES,
	E_CONTRACT_TAKER,
	bool:E_CONTRACT_USED,
}

static s_Contracts[ORDERS_CONTRACTS_MAX][E_CONTRACT];

stock bool:Contracts_IsValid(slot)
{
	return slot >= 0 && slot < ORDERS_CONTRACTS_MAX && s_Contracts[slot][E_CONTRACT_USED];
}

stock Contracts_GetId(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_ID] : 0;
}

stock Contracts_GetPoster(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_POSTER] : 0;
}

stock Contracts_GetPosterName(slot,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Contracts_IsValid(slot))
	{
		strcopy(dest,s_Contracts[slot][E_CONTRACT_POSTER_NAME],size);
	}
}

stock Contracts_GetItem(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_ITEM] : -1;
}

stock Contracts_GetQty(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_QTY] : 0;
}

stock Contracts_GetStars(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_STARS] : 0;
}

stock Contracts_GetPay(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_PAY] : 0;
}

stock Contracts_GetExpires(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_EXPIRES] : 0;
}

stock Contracts_GetTaker(slot)
{
	return Contracts_IsValid(slot) ? s_Contracts[slot][E_CONTRACT_TAKER] : 0;
}

stock Contracts_FormatText(slot,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Contracts_IsValid(slot))
	{
		return;
	}

	new name[32], item = s_Contracts[slot][E_CONTRACT_ITEM];
	Item_GetName(Item_GetDefKind(item),item,name);

	if (s_Contracts[slot][E_CONTRACT_STARS] > ITEM_STARS_MIN)
	{
		format(dest,size,"%d x %s, %d stars or better",s_Contracts[slot][E_CONTRACT_QTY],name,s_Contracts[slot][E_CONTRACT_STARS]);
	}
	else
	{
		format(dest,size,"%d x %s",s_Contracts[slot][E_CONTRACT_QTY],name);
	}
}

stock Contracts_Count()
{
	new count = 0;

	for (new slot = 0;slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (s_Contracts[slot][E_CONTRACT_USED])
		{
			count++;
		}
	}

	return count;
}

stock Contracts_CountPosted(characterid)
{
	new count = 0;

	for (new slot = 0;characterid > 0 && slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (s_Contracts[slot][E_CONTRACT_USED] && s_Contracts[slot][E_CONTRACT_POSTER] == characterid)
		{
			count++;
		}
	}

	return count;
}

stock Contracts_CountTaken(playerid)
{
	new count = 0, characterid = Character_GetId(playerid);

	for (new slot = 0;characterid > 0 && slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (s_Contracts[slot][E_CONTRACT_USED] && s_Contracts[slot][E_CONTRACT_TAKER] == characterid)
		{
			count++;
		}
	}

	return count;
}

public Orders_CountCarried(playerid)
{
	return Orders_CountTaken(playerid) + Contracts_CountTaken(playerid);
}

stock Contracts_FindItem(const text[])
{
	new name[32], prefix = -1, length = strlen(text);

	if (length < 2)
	{
		return -1;
	}

	for (new item = 0;item < ITEM_DEF_COUNT;item++)
	{
		new E_ITEM_KIND:kind = Item_GetDefKind(item);

		if (kind == ITEM_KIND_COIN || !Item_IsValid(kind,item))
		{
			continue;
		}

		Item_GetName(kind,item,name);

		if (!strcmp(name,text,true))
		{
			return item;
		}

		if (prefix == -1 && !strcmp(name,text,true,length))
		{
			prefix = item;
		}
	}

	return prefix;
}

static Contracts_FindFree()
{
	for (new slot = 0;slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (!s_Contracts[slot][E_CONTRACT_USED])
		{
			return slot;
		}
	}

	return -1;
}

stock Contracts_Add(id,poster,const posterName[],item,qty,stars,pay,expires,taker)
{
	new slot = Contracts_FindFree();

	if (slot == -1)
	{
		return -1;
	}

	s_Contracts[slot][E_CONTRACT_ID] = id;
	s_Contracts[slot][E_CONTRACT_POSTER] = poster;
	strcopy(s_Contracts[slot][E_CONTRACT_POSTER_NAME],posterName,ORDERS_POSTER_LEN);
	s_Contracts[slot][E_CONTRACT_ITEM] = item;
	s_Contracts[slot][E_CONTRACT_QTY] = qty;
	s_Contracts[slot][E_CONTRACT_STARS] = stars;
	s_Contracts[slot][E_CONTRACT_PAY] = pay;
	s_Contracts[slot][E_CONTRACT_EXPIRES] = expires;
	s_Contracts[slot][E_CONTRACT_TAKER] = taker;
	s_Contracts[slot][E_CONTRACT_USED] = true;
	return slot;
}

static Contracts_Remove(slot)
{
	if (s_Contracts[slot][E_CONTRACT_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM order_contracts WHERE id = %d",s_Contracts[slot][E_CONTRACT_ID]));
	}

	s_Contracts[slot][E_CONTRACT_USED] = false;
	s_Contracts[slot][E_CONTRACT_ID] = 0;
	s_Contracts[slot][E_CONTRACT_TAKER] = 0;
}

static Contracts_SaveTaker(slot)
{
	if (s_Contracts[slot][E_CONTRACT_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE order_contracts SET taken_by = NULLIF(%d, 0) WHERE id = %d",s_Contracts[slot][E_CONTRACT_TAKER],s_Contracts[slot][E_CONTRACT_ID]));
	}
}

forward Task:Contracts_Insert(slot);

public Task:Contracts_Insert(slot)
{
	new Task:done = task_new(), poster = s_Contracts[slot][E_CONTRACT_POSTER];
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO order_contracts (poster_id, poster_name, item, qty, min_stars, pay, expires_at) VALUES (%d, '%e', %d, %d, %d, %d, %d)",poster,s_Contracts[slot][E_CONTRACT_POSTER_NAME],s_Contracts[slot][E_CONTRACT_ITEM],s_Contracts[slot][E_CONTRACT_QTY],s_Contracts[slot][E_CONTRACT_STARS],s_Contracts[slot][E_CONTRACT_PAY],s_Contracts[slot][E_CONTRACT_EXPIRES]));
	new id = cache_insert_id();

	if (s_Contracts[slot][E_CONTRACT_USED] && s_Contracts[slot][E_CONTRACT_POSTER] == poster && s_Contracts[slot][E_CONTRACT_ID] == 0)
	{
		s_Contracts[slot][E_CONTRACT_ID] = id;
		Contracts_SaveTaker(slot);
	}
	else if (id > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM order_contracts WHERE id = %d",id));
	}

	task_set_result(done,id);
	return done;
}

stock Contracts_Post(playerid,item,qty,stars,pay)
{
	new characterid = Character_GetId(playerid);

	if (characterid <= 0 || !Item_IsValid(Item_GetDefKind(item),item) || Item_GetDefKind(item) == ITEM_KIND_COIN || qty < 1 || qty > ORDERS_CONTRACT_QTY_MAX || !Item_IsValidStars(stars) || pay < 1 || pay > ORDERS_CONTRACT_PAY_MAX)
	{
		return ORDER_BAD_INPUT;
	}

	if (Contracts_CountPosted(characterid) >= ORDERS_CONTRACTS_PER_POSTER || Contracts_FindFree() == -1)
	{
		return ORDER_TOO_MANY;
	}

	if (Economy_Pay(playerid,pay,INVALID_CONTAINER_ID,"contract escrow") != PAY_OK)
	{
		return ORDER_NO_COIN;
	}

	new name[ORDERS_POSTER_LEN], slot;
	Character_GetName(playerid,name);
	slot = Contracts_Add(0,characterid,name,item,qty,stars,pay,gettime() + ORDERS_CONTRACT_DAYS * 86400,0);
	Contracts_Insert(slot);
	pawn_call_public("Contracts_OnPosted","dd",playerid,slot);
	return ORDER_OK;
}

stock Contracts_Take(playerid,slot)
{
	if (!Contracts_IsValid(slot))
	{
		return ORDER_GONE;
	}

	new characterid = Character_GetId(playerid);

	if (s_Contracts[slot][E_CONTRACT_POSTER] == characterid)
	{
		return ORDER_NOT_YOURS;
	}

	if (s_Contracts[slot][E_CONTRACT_TAKER] != 0)
	{
		return s_Contracts[slot][E_CONTRACT_TAKER] == characterid ? ORDER_OK : ORDER_TAKEN;
	}

	if (Orders_CountCarried(playerid) >= ORDERS_TAKEN_MAX)
	{
		return ORDER_TOO_MANY;
	}

	s_Contracts[slot][E_CONTRACT_TAKER] = characterid;
	Contracts_SaveTaker(slot);
	return ORDER_OK;
}

stock Contracts_Drop(playerid,slot)
{
	if (!Contracts_IsValid(slot))
	{
		return ORDER_GONE;
	}

	if (s_Contracts[slot][E_CONTRACT_TAKER] != Character_GetId(playerid))
	{
		return ORDER_NOT_YOURS;
	}

	s_Contracts[slot][E_CONTRACT_TAKER] = 0;
	Contracts_SaveTaker(slot);
	return ORDER_OK;
}

stock Contracts_Deliver(playerid,slot,bool:needsBoard = true)
{
	if (!Contracts_IsValid(slot))
	{
		return ORDER_GONE;
	}

	new characterid = Character_GetId(playerid);

	if (s_Contracts[slot][E_CONTRACT_TAKER] != characterid)
	{
		return ORDER_NOT_YOURS;
	}

	if (needsBoard && Notices_FindBoardNear(playerid) == -1)
	{
		return ORDER_NO_BOARD;
	}

	new item = s_Contracts[slot][E_CONTRACT_ITEM], qty = s_Contracts[slot][E_CONTRACT_QTY], stars = s_Contracts[slot][E_CONTRACT_STARS];

	if (Orders_CountHeld(playerid,Item_GetDefKind(item),item,stars) < qty)
	{
		return ORDER_MISSING_GOODS;
	}

	new starSum, pay = s_Contracts[slot][E_CONTRACT_PAY], poster = s_Contracts[slot][E_CONTRACT_POSTER];
	Orders_TakeGoods(playerid,item,qty,stars,starSum,false,poster,"contract delivered");
	Economy_GiveOrClaim(playerid,characterid,pay,"contract paid");
	new posterid = Claims_FindPlayer(poster), text[64];

	if (posterid != INVALID_PLAYER_ID)
	{
		Contracts_FormatText(slot,text);
		Subtitle_Show(posterid,sprintf("~w~Your contract is done: ~y~%s~w~ delivered.",text));
	}

	pawn_call_public("Contracts_OnDelivered","dd",playerid,slot);
	Contracts_Remove(slot);
	return ORDER_OK;
}

stock Contracts_Cancel(playerid,slot)
{
	if (!Contracts_IsValid(slot))
	{
		return ORDER_GONE;
	}

	new characterid = Character_GetId(playerid);

	if (s_Contracts[slot][E_CONTRACT_POSTER] != characterid)
	{
		return ORDER_NOT_YOURS;
	}

	if (s_Contracts[slot][E_CONTRACT_TAKER] != 0)
	{
		return ORDER_TAKEN;
	}

	Economy_GiveOrClaim(playerid,characterid,s_Contracts[slot][E_CONTRACT_PAY],"contract refund");
	Contracts_Remove(slot);
	return ORDER_OK;
}

stock Contracts_ExpireAll(now)
{
	new expired = 0;

	for (new slot = 0;slot < ORDERS_CONTRACTS_MAX;slot++)
	{
		if (!s_Contracts[slot][E_CONTRACT_USED] || s_Contracts[slot][E_CONTRACT_EXPIRES] > now)
		{
			continue;
		}

		new poster = s_Contracts[slot][E_CONTRACT_POSTER];
		Economy_GiveOrClaim(Claims_FindPlayer(poster),poster,s_Contracts[slot][E_CONTRACT_PAY],"contract refund");
		Contracts_Remove(slot);
		expired++;
	}

	return expired;
}

stock Contracts_SetExpires(slot,expires)
{
	if (Contracts_IsValid(slot))
	{
		s_Contracts[slot][E_CONTRACT_EXPIRES] = expires;
	}
}

forward Task:Contracts_Load();

#pragma warning push
#pragma warning disable 204
async Task:Contracts_Load()
{
	new loaded = 0;
	await mysql_aquery_s(g_Mysql,str_new("SELECT id, poster_id, poster_name, item, qty, min_stars, pay, expires_at, IFNULL(taken_by, 0) AS taker FROM order_contracts"));

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, poster, name[ORDERS_POSTER_LEN], item, qty, stars, pay, expires, taker;
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name_int(row,"poster_id",poster);
		cache_get_value_name(row,"poster_name",name);
		cache_get_value_name_int(row,"item",item);
		cache_get_value_name_int(row,"qty",qty);
		cache_get_value_name_int(row,"min_stars",stars);
		cache_get_value_name_int(row,"pay",pay);
		cache_get_value_name_int(row,"expires_at",expires);
		cache_get_value_name_int(row,"taker",taker);

		if (Contracts_Add(id,poster,name,item,qty,stars,pay,expires,taker) != -1)
		{
			loaded++;
		}
	}

	return async loaded;
}
#pragma warning pop

forward Contracts_OnPosted(playerid,slot);

public Contracts_OnPosted(playerid,slot)
{
	return 1;
}

forward Contracts_OnDelivered(playerid,slot);

public Contracts_OnDelivered(playerid,slot)
{
	return 1;
}

forward Contracts_Tick();

public Contracts_Tick()
{
	Contracts_ExpireAll(gettime());
	return 1;
}
