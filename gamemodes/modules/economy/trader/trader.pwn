enum E_TRADER
{
	E_TRADER_ROW,
	E_TRADER_SKIN,
	E_TRADER_PURSE,
	E_TRADER_PURSE_DAY,
	E_TRADER_ACTOR,
	STREAMER_TAG_3D_TEXT_LABEL:E_TRADER_LABEL,
	Float:E_TRADER_X,
	Float:E_TRADER_Y,
	Float:E_TRADER_Z,
	Float:E_TRADER_A,
	E_TRADER_WORLD,
	E_TRADER_INTERIOR,
	bool:E_TRADER_USED,
	bool:E_TRADER_PRESENT,
}

static s_Traders[TRADER_MAX][E_TRADER];
static s_TraderNames[TRADER_MAX][TRADER_NAME_LEN];
static s_TraderItemTrade[ITEM_DEF_COUNT char];
static s_TraderMark[MAX_PLAYERS][3];
static s_TraderScarcity;
static s_TraderRevision;

stock bool:Trader_IsValid(trader)
{
	return trader >= 0 && trader < TRADER_MAX && s_Traders[trader][E_TRADER_USED];
}

stock Trader_GetRevision()
{
	return s_TraderRevision;
}

stock Trader_GetCount()
{
	new count = 0;

	for (new trader = 0;trader < TRADER_MAX;trader++)
	{
		if (s_Traders[trader][E_TRADER_USED])
		{
			count++;
		}
	}

	return count;
}

stock bool:Trader_StocksItem(item)
{
	for (new row = 0;row < sizeof(g_TraderStock);row++)
	{
		if (g_TraderStock[row][E_TRADER_STOCK_ITEM] == item && Item_GetDefKind(item) == g_TraderStock[row][E_TRADER_STOCK_KIND])
		{
			return true;
		}
	}

	return false;
}

stock Trader_GetName(trader,dest[],size = sizeof(dest))
{
	if (!Trader_IsValid(trader))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_TraderNames[trader],size);
}

stock bool:Trader_IsNear(playerid,trader,Float:range)
{
	return Trader_IsPresent(trader) && GetPlayerVirtualWorld(playerid) == s_Traders[trader][E_TRADER_WORLD] && GetPlayerDistanceFromPoint(playerid,s_Traders[trader][E_TRADER_X],s_Traders[trader][E_TRADER_Y],s_Traders[trader][E_TRADER_Z]) <= range;
}

stock Trader_FindNear(playerid,Float:range = TRADER_REACH)
{
	new best = -1, Float:bestDistance = range, world = GetPlayerVirtualWorld(playerid), interior = GetPlayerInterior(playerid);

	for (new i = 0;i < TRADER_MAX;i++)
	{
		if (!s_Traders[i][E_TRADER_USED] || !s_Traders[i][E_TRADER_PRESENT] || s_Traders[i][E_TRADER_WORLD] != world || s_Traders[i][E_TRADER_INTERIOR] != interior)
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(playerid,s_Traders[i][E_TRADER_X],s_Traders[i][E_TRADER_Y],s_Traders[i][E_TRADER_Z]);

		if (distance <= bestDistance)
		{
			best = i;
			bestDistance = distance;
		}
	}

	return best;
}

static Trader_Today()
{
	return gettime() / TRADER_DAY_SECONDS;
}

static Trader_SavePurse(trader)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE traders SET purse = %d, purse_day = %d WHERE id = %d",s_Traders[trader][E_TRADER_PURSE],s_Traders[trader][E_TRADER_PURSE_DAY],s_Traders[trader][E_TRADER_ROW]));
}

stock Trader_GetPurse(trader)
{
	if (!Trader_IsValid(trader))
	{
		return 0;
	}

	if (s_Traders[trader][E_TRADER_PURSE_DAY] != Trader_Today())
	{
		s_Traders[trader][E_TRADER_PURSE] = TRADER_PURSE_DAILY;
		s_Traders[trader][E_TRADER_PURSE_DAY] = Trader_Today();
		Trader_SavePurse(trader);
	}

	return s_Traders[trader][E_TRADER_PURSE];
}

static Trader_AddPurse(trader,amount)
{
	Trader_GetPurse(trader);
	s_Traders[trader][E_TRADER_PURSE] = max(0,s_Traders[trader][E_TRADER_PURSE] + amount);
	Trader_SavePurse(trader);
}

forward bool:Trader_IsMarked(playerid,E_ITEM_KIND:kind,param,stars);

stock Trader_BuyPrice(playerid,E_ITEM_KIND:kind,param,stars)
{
	new base = Item_GetPrice(kind,param,stars);

	if (base <= 0)
	{
		return 0;
	}

	new price = max(1,base * TRADER_BUY_PERCENT * (200 - Traits_Get(playerid,TRAIT_EFFECT_SHOP_PRICE)) / 10000 * Hygiene_PriceFactor(playerid) / 100);

	if (s_TraderScarcity > 0 && (kind == ITEM_KIND_FOOD || kind == ITEM_KIND_DRINK))
	{
		price = price * (100 + s_TraderScarcity) / 100;
	}

	return Trader_IsMarked(playerid,kind,param,stars) ? price * (100 + s_TraderMark[playerid][2]) / 100 : price;
}

stock Trader_SetScarcity(percent)
{
	s_TraderScarcity = Util_ClampInt(percent,0,200);
}

stock Trader_GetScarcity()
{
	return s_TraderScarcity;
}

stock Trader_SetItemTrade(param,trade)
{
	if (param >= 0 && param < ITEM_DEF_COUNT)
	{
		s_TraderItemTrade{param} = trade + 1;
	}
}

stock Trader_GetItemTrade(E_ITEM_KIND:kind,param)
{
	if (kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD || kind == ITEM_KIND_COIN || kind == ITEM_KIND_CONTAINER || param < 0 || param >= ITEM_DEF_COUNT)
	{
		return -1;
	}

	return s_TraderItemTrade{param} - 1;
}

stock Trader_SetMark(playerid,trade,minStars,percent)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_TraderMark[playerid][0] = trade + 1;
	s_TraderMark[playerid][1] = minStars;
	s_TraderMark[playerid][2] = percent;
}

stock bool:Trader_IsMarked(playerid,E_ITEM_KIND:kind,param,stars)
{
	if (!Util_IsValidPlayer(playerid) || s_TraderMark[playerid][0] == 0)
	{
		return false;
	}

	new trade = Trader_GetItemTrade(kind,param);
	return trade != -1 && trade == s_TraderMark[playerid][0] - 1 && stars >= s_TraderMark[playerid][1];
}

stock Trader_SellPrice(playerid,E_ITEM_KIND:kind,param)
{
	new base = Item_GetPrice(kind,param,ITEM_STARS_MIN), price = max(1,base * TRADER_SELL_PERCENT * Traits_Get(playerid,TRAIT_EFFECT_SHOP_PRICE) / 10000 * (Hygiene_IsReeking(playerid) ? 85 : 100) / 100);
	return s_TraderScarcity > 0 && (kind == ITEM_KIND_FOOD || kind == ITEM_KIND_DRINK) ? price * (100 + s_TraderScarcity) / 100 : price;
}

stock bool:Trader_IsOpen()
{
	return !Calendar_IsNight();
}

stock bool:Trader_Buys(E_ITEM_KIND:kind,param)
{
	return kind != ITEM_KIND_COIN && kind != ITEM_KIND_CONTAINER && Item_GetPrice(kind,param,ITEM_STARS_MIN) > 0;
}

stock bool:Trader_SellSlot(playerid,trader,index,dest[],size = sizeof(dest))
{
	new E_ITEM_KIND:kind, param, amount, name[ITEM_NAME_LEN];
	dest[0] = EOS;

	if (!Trader_IsPresent(trader) || !Inventory_GetSlot(playerid,index,kind,param,amount) || amount <= 0)
	{
		strcopy(dest,"That item isn't in your bag any more.",size);
		return false;
	}

	Item_GetName(kind,param,name);

	if (!Trader_Buys(kind,param))
	{
		format(dest,size,"The trader has no use for %s.",name);
		return false;
	}

	if (Inventory_GetSlotUsed(playerid,index) > 0)
	{
		format(dest,size,"The trader won't buy %s you've already started on.",name);
		return false;
	}

	new price = Trader_BuyPrice(playerid,kind,param,Inventory_GetSlotStars(playerid,index));

	if (Trader_GetPurse(trader) < price)
	{
		strcopy(dest,"The trader has no more coin today. Come back tomorrow.",size);
		return false;
	}

	if (!Inventory_TakeSlot(playerid,index,1))
	{
		strcopy(dest,"That item isn't in your bag any more.",size);
		return false;
	}

	Trader_AddPurse(trader,-price);
	Economy_GiveOrClaim(playerid,Character_GetId(playerid),price,"trader");
	format(dest,size,"You sold %s for %d pfennig.",name,price);
	return true;
}

stock bool:Trader_BuyStock(playerid,trader,row,dest[],size = sizeof(dest))
{
	new name[ITEM_NAME_LEN];
	dest[0] = EOS;

	if (!Trader_IsPresent(trader) || row < 0 || row >= sizeof(g_TraderStock))
	{
		return false;
	}

	new E_ITEM_KIND:kind = g_TraderStock[row][E_TRADER_STOCK_KIND], item = g_TraderStock[row][E_TRADER_STOCK_ITEM], price = Trader_SellPrice(playerid,kind,item);
	Item_GetName(kind,item,name);

	if (!Inventory_CanGive(playerid,kind,item))
	{
		strcopy(dest,"Your bag is full. Make room first.",size);
		return false;
	}

	if (Economy_Pay(playerid,price,INVALID_CONTAINER_ID,"trader") != PAY_OK)
	{
		format(dest,size,"You need %d pfennig for %s.",price,name);
		return false;
	}

	Inventory_Give(playerid,kind,item);
	Trader_AddPurse(trader,price);
	format(dest,size,"You bought %s for %d pfennig.",name,price);
	return true;
}

stock Trader_FindStartedSkin(playerid)
{
	new E_ITEM_KIND:kind, param, amount;

	for (new i = 0;i < Inventory_GetCount(playerid);i++)
	{
		if (Inventory_GetSlot(playerid,i,kind,param,amount) && kind == ITEM_KIND_DRINK && param == ITEM_WATER_SKIN && Inventory_GetSlotUsed(playerid,i) > 0)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Trader_FillSkin(playerid,trader,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Trader_IsPresent(trader))
	{
		return false;
	}

	new slot = Trader_FindStartedSkin(playerid);

	if (slot == -1)
	{
		strcopy(dest,Inventory_Count(playerid,ITEM_KIND_DRINK,ITEM_WATER_SKIN) > 0 ? ("Your water skin is already full.") : ("You have no water skin to fill. You can buy one under Buy imports."),size);
		return false;
	}

	if (Economy_Pay(playerid,TRADER_FILL_FEE,INVALID_CONTAINER_ID,"trader") != PAY_OK)
	{
		format(dest,size,"You need %d pfennig to fill your water skin.",TRADER_FILL_FEE);
		return false;
	}

	Inventory_RefillSlot(playerid,slot);
	Trader_AddPurse(trader,TRADER_FILL_FEE);
	format(dest,size,"The trader fills your water skin for %d pfennig.",TRADER_FILL_FEE);
	return true;
}

stock Trader_Show(trader)
{
	if (!Trader_IsValid(trader) || s_Traders[trader][E_TRADER_PRESENT] || (Trader_IsMarketTrader(trader) && !Market_IsOpen()))
	{
		return;
	}

	new label[TRADER_NAME_LEN + 12], actor = CreateActor(s_Traders[trader][E_TRADER_SKIN],s_Traders[trader][E_TRADER_X],s_Traders[trader][E_TRADER_Y],s_Traders[trader][E_TRADER_Z],s_Traders[trader][E_TRADER_A]);
	s_Traders[trader][E_TRADER_ACTOR] = actor;
	s_Traders[trader][E_TRADER_PRESENT] = true;
	format(label,sizeof(label),"%s, trader",s_TraderNames[trader]);
	s_Traders[trader][E_TRADER_LABEL] = CreateDynamic3DTextLabel(label,TRADER_LABEL_COLOUR,s_Traders[trader][E_TRADER_X],s_Traders[trader][E_TRADER_Y],s_Traders[trader][E_TRADER_Z] + 1.1,TRADER_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,s_Traders[trader][E_TRADER_WORLD],s_Traders[trader][E_TRADER_INTERIOR]);

	if (IsValidActor(actor))
	{
		SetActorVirtualWorld(actor,s_Traders[trader][E_TRADER_WORLD]);
		Actors_RegisterBody(sprintf("trader:%d",trader),actor,0,s_TraderNames[trader],"Trader",s_Traders[trader][E_TRADER_WORLD],s_Traders[trader][E_TRADER_INTERIOR],"trader",trader);
		SetActorInvulnerable(actor,true);
		ApplyActorAnimation(actor,"PED","IDLE_CHAT",4.1,true,false,false,false,0);
	}
}

stock Trader_Hide(trader)
{
	if (!Trader_IsValid(trader))
	{
		return;
	}

	if (IsValidActor(s_Traders[trader][E_TRADER_ACTOR]))
	{
		Actors_UnregisterBody(s_Traders[trader][E_TRADER_ACTOR]);
		DestroyActor(s_Traders[trader][E_TRADER_ACTOR]);
	}

	if (IsValidDynamic3DTextLabel(s_Traders[trader][E_TRADER_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Traders[trader][E_TRADER_LABEL]);
	}

	s_Traders[trader][E_TRADER_ACTOR] = INVALID_ACTOR_ID;
	s_Traders[trader][E_TRADER_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	s_Traders[trader][E_TRADER_PRESENT] = false;
}

stock bool:Trader_IsPresent(trader)
{
	return Trader_IsValid(trader) && s_Traders[trader][E_TRADER_PRESENT];
}

stock bool:Trader_Change(playerid,trader,tier,bool:isBreaking,dest[],size = sizeof(dest))
{
    if (!Trader_IsPresent(trader))
    {
        strcopy(dest,"The trader has packed up.",size);
        return false;
    }

	new coin[ITEM_NAME_LEN];
	Item_GetName(ITEM_KIND_COIN,tier,coin);

	if (isBreaking ? !Economy_BreakCoin(playerid,tier,TRADER_CHANGE_FEE) : !Economy_MakeCoin(playerid,tier,TRADER_CHANGE_FEE))
	{
		if (isBreaking)
		{
			format(dest,size,"You need a %s to break, and room in your bag for the change.",coin);
		}
		else
		{
			format(dest,size,"You don't have enough small coin to make a %s, plus %d pfennig for the trader.",coin,TRADER_CHANGE_FEE);
		}

		return false;
	}

	Trader_AddPurse(trader,TRADER_CHANGE_FEE);
	format(dest,size,isBreaking ? ("The trader broke your %s for a fee of %d pfennig.") : ("The trader made you a %s for a fee of %d pfennig."),coin,TRADER_CHANGE_FEE);
	return true;
}

stock Trader_Add(row,const name[],skin,purse,purseDay,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	new trader = -1;

	for (new i = 0;i < TRADER_MAX;i++)
	{
		if (!s_Traders[i][E_TRADER_USED])
		{
			trader = i;
			break;
		}
	}

	if (trader == -1)
	{
		return -1;
	}

	s_Traders[trader][E_TRADER_USED] = true;
	s_Traders[trader][E_TRADER_ROW] = row;
	s_Traders[trader][E_TRADER_SKIN] = skin;
	s_Traders[trader][E_TRADER_PURSE] = purse;
	s_Traders[trader][E_TRADER_PURSE_DAY] = purseDay;
	s_Traders[trader][E_TRADER_X] = x;
	s_Traders[trader][E_TRADER_Y] = y;
	s_Traders[trader][E_TRADER_Z] = z;
	s_Traders[trader][E_TRADER_A] = a;
	s_Traders[trader][E_TRADER_WORLD] = world;
	s_Traders[trader][E_TRADER_INTERIOR] = interior;
	strcopy(s_TraderNames[trader],name,TRADER_NAME_LEN);

	s_Traders[trader][E_TRADER_ACTOR] = INVALID_ACTOR_ID;
	s_Traders[trader][E_TRADER_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	s_Traders[trader][E_TRADER_PRESENT] = false;

	s_TraderRevision++;

	if (Trader_IsOpen())
	{
		Trader_Show(trader);
	}

	return trader;
}

stock Trader_Remove(trader)
{
	if (!Trader_IsValid(trader))
	{
		return;
	}

	Trader_Hide(trader);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM traders WHERE id = %d",s_Traders[trader][E_TRADER_ROW]));
	s_Traders[trader][E_TRADER_USED] = false;
	s_TraderNames[trader][0] = EOS;
	s_TraderRevision++;
}

stock Trader_FindAt(Float:x,Float:y,Float:z,world,interior,Float:range)
{
	for (new i = 0;i < TRADER_MAX;i++)
	{
		if (s_Traders[i][E_TRADER_USED] && s_Traders[i][E_TRADER_WORLD] == world && s_Traders[i][E_TRADER_INTERIOR] == interior && Util_GetDistance3D(x,y,z,s_Traders[i][E_TRADER_X],s_Traders[i][E_TRADER_Y],s_Traders[i][E_TRADER_Z]) <= range)
		{
			return i;
		}
	}

	return -1;
}

#pragma warning push
#pragma warning disable 204
forward Task:Trader_Create(const name[],skin,Float:x,Float:y,Float:z,Float:a,world,interior);

async Task:Trader_Create(const name[],skin,Float:x,Float:y,Float:z,Float:a,world,interior)
{
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO traders (name, skin, purse, purse_day, x, y, z, a, world, interior) VALUES ('%e', %d, %d, %d, %f, %f, %f, %f, %d, %d)",name,skin,TRADER_PURSE_DAILY,Trader_Today(),x,y,z,a,world,interior));

	new row = cache_insert_id();
	return async row > 0 ? Trader_Add(row,name,skin,TRADER_PURSE_DAILY,Trader_Today(),x,y,z,a,world,interior) : -1;
}

forward Task:Trader_SeedSquares();

async Task:Trader_SeedSquares()
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT 1 FROM seeders WHERE seeder_key = '%e'",TRADER_SEED_KEY));

	if (cache_num_rows())
	{
		return async 0;
	}

	new sown = 0, looks = Skins_CountStarter(0);

	for (new i = 0;i < TRADER_SEED_COUNT;i++)
	{
		new Float:x = g_TraderSeedDefs[i][E_TRADER_SEED_DEF_POS][0], Float:y = g_TraderSeedDefs[i][E_TRADER_SEED_DEF_POS][1], Float:z = g_TraderSeedDefs[i][E_TRADER_SEED_DEF_POS][2];

		if (Trader_FindAt(x,y,z,0,0,TRADER_SEED_GAP) != -1)
		{
			continue;
		}

		new trader = await Trader_Create(g_TraderSeedDefs[i][E_TRADER_SEED_DEF_NAME],looks > 0 ? Skins_GetStarter(0,g_TraderSeedDefs[i][E_TRADER_SEED_DEF_LOOK] % looks) : 1,x,y,z,g_TraderSeedDefs[i][E_TRADER_SEED_DEF_POS][3],0,0);

		if (trader != -1)
		{
			sown++;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT IGNORE INTO seeders (seeder_key) VALUES ('%e')",TRADER_SEED_KEY));
	return async sown;
}
#pragma warning pop

forward Trader_LoadOnBoot();

public Trader_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, name, skin, purse, purse_day, x, y, z, a, world, interior FROM traders ORDER BY id"));

	new placed = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, name[TRADER_NAME_LEN], skin, purse, purseDay, Float:pos[4], world, interior;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"name",name);
		cache_get_value_name_int(r,"skin",skin);
		cache_get_value_name_int(r,"purse",purse);
		cache_get_value_name_int(r,"purse_day",purseDay);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);

		if (Trader_Add(row,name,skin,purse,purseDay,pos[0],pos[1],pos[2],pos[3],world,interior) != -1)
		{
			placed++;
		}
	}

	new sown = await Trader_SeedSquares();

	if (sown > 0)
	{
		Log_Info("trader","%d trader(s) seeded at the village squares",sown);
	}

	Log_Info("trader","%d trader(s) placed",placed + sown);
	Boot_LoaderDone();
}

stock bool:Trader_IsMarketTrader(trader)
{
    return Trader_IsValid(trader) && Market_Contains(s_Traders[trader][E_TRADER_X],s_Traders[trader][E_TRADER_Y],s_Traders[trader][E_TRADER_WORLD],s_Traders[trader][E_TRADER_INTERIOR]);
}

stock Trader_RefreshMarket()
{
    for (new trader = 0; trader < TRADER_MAX; trader++)
    {
        if (!Trader_IsMarketTrader(trader))
        {
            continue;
        }
        if (Market_IsOpen())
        {
            Trader_Show(trader);
        }
        else
        {
            Trader_Hide(trader);
        }
    }
}

stock Trader_CountMarketPresent()
{
    new count;
    for (new trader = 0; trader < TRADER_MAX; trader++)
    {
        if (Trader_IsMarketTrader(trader) && Trader_IsPresent(trader))
        {
            count++;
        }
    }
    return count;
}

#include <pp-hooks>
hook Market_OnChanged(open)
{
    #pragma unused open
    Trader_RefreshMarket();
}
