#define ECONOMY_SOURCE_LEN (24)
#define ECONOMY_FORMAT_LEN (48)

enum E_PAY_RESULT
{
	PAY_OK,
	PAY_SHORT,
	PAY_NO_ROOM,
}

enum E_LEDGER_KIND
{
	LEDGER_PAY,
	LEDGER_GIVE,
	LEDGER_CHANGE,
	LEDGER_ORIGIN,
}

stock Economy_Split(pfennig,counts[COIN_TIER_COUNT])
{
	new left = pfennig;
	for (new tier = COIN_TIER_COUNT - 1; tier >= COIN_PFENNIG; tier--)
	{
		counts[tier] = left / Item_CoinWorth(tier);
		left -= counts[tier] * Item_CoinWorth(tier);
	}
}

stock Economy_Format(pfennig,dest[],size = sizeof(dest))
{
	if (pfennig <= 0)
	{
		strcopy(dest,"No coin",size);
		return;
	}

	new counts[COIN_TIER_COUNT], name[ITEM_NAME_LEN];
	Economy_Split(pfennig,counts);
	dest[0] = EOS;
	for (new tier = COIN_TIER_COUNT - 1; tier >= COIN_PFENNIG; tier--)
	{
		if (counts[tier] <= 0)
		{
			continue;
		}

		Item_GetName(ITEM_KIND_COIN,tier,name);
		for (new i = 0; name[i] != EOS; i++)
		{
			name[i] = tolower(name[i]);
		}

		format(dest,size,"%s%s%d %s",dest,dest[0] == EOS ? ("") : (" "),counts[tier],name);
	}
}

static stock Economy_PurseAt(playerid,bagIndex)
{
	new E_ITEM_KIND:kind, param, amount;
	if (!Inventory_GetSlot(playerid,bagIndex,kind,param,amount) || kind != ITEM_KIND_CONTAINER || !Container_IsCoinPurse(param))
	{
		return INVALID_CONTAINER_ID;
	}

	return param;
}

static stock Economy_CountTier(playerid,tier)
{
	new total = Inventory_Count(playerid,ITEM_KIND_COIN,tier), count = Inventory_GetCount(playerid);
	for (new i = 0; i < count; i++)
	{
		new purse = Economy_PurseAt(playerid,i);
		if (purse != INVALID_CONTAINER_ID)
		{
			total += Container_Count(purse,ITEM_KIND_COIN,tier);
		}
	}

	return total;
}

static stock Economy_TakeTier(playerid,tier,amount)
{
	new loose = Inventory_Count(playerid,ITEM_KIND_COIN,tier), left = amount;
	if (loose > 0)
	{
		new take = loose > left ? left : loose;
		Inventory_Take(playerid,ITEM_KIND_COIN,tier,take);
		left -= take;
	}

	new count = Inventory_GetCount(playerid);
	for (new i = 0; i < count && left > 0; i++)
	{
		new purse = Economy_PurseAt(playerid,i);
		if (purse == INVALID_CONTAINER_ID)
		{
			continue;
		}

		new have = Container_Count(purse,ITEM_KIND_COIN,tier), take = have > left ? left : have;
		if (take > 0 && Container_TakeStars(purse,ITEM_KIND_COIN,tier,take,ITEM_STARS_MIN))
		{
			left -= take;
		}
	}

	return amount - left;
}

static stock Economy_GiveTier(playerid,tier,amount)
{
	new room = Inventory_Room(playerid,ITEM_KIND_COIN,tier), left = amount;
	if (room > 0)
	{
		new give = room > left ? left : room;
		Inventory_Give(playerid,ITEM_KIND_COIN,tier,give);
		left -= give;
	}

	new count = Inventory_GetCount(playerid);
	for (new i = 0; i < count && left > 0; i++)
	{
		new purse = Economy_PurseAt(playerid,i);
		if (purse == INVALID_CONTAINER_ID)
		{
			continue;
		}

		new fits = Container_Room(purse,ITEM_KIND_COIN,tier), give = fits > left ? left : fits;
		if (give > 0 && Container_Add(purse,ITEM_KIND_COIN,tier,give))
		{
			left -= give;
		}
	}

	return amount - left;
}

static stock bool:Economy_GiveCounts(playerid,const counts[COIN_TIER_COUNT])
{
	new given[COIN_TIER_COUNT];
	for (new tier = COIN_TIER_COUNT - 1; tier >= COIN_PFENNIG; tier--)
	{
		given[tier] = Economy_GiveTier(playerid,tier,counts[tier]);
		if (given[tier] < counts[tier])
		{
			for (new back = COIN_TIER_COUNT - 1; back >= tier; back--)
			{
				Economy_TakeTier(playerid,back,given[back]);
			}

			return false;
		}
	}

	return true;
}

static stock bool:Economy_ContainerTryAdd(containerid,const counts[COIN_TIER_COUNT])
{
	for (new tier = COIN_TIER_COUNT - 1; tier >= COIN_PFENNIG; tier--)
	{
		if (counts[tier] > 0 && !Container_Add(containerid,ITEM_KIND_COIN,tier,counts[tier]))
		{
			for (new back = COIN_TIER_COUNT - 1; back > tier; back--)
			{
				if (counts[back] > 0)
				{
					Container_TakeStars(containerid,ITEM_KIND_COIN,back,counts[back],ITEM_STARS_MIN);
				}
			}

			return false;
		}
	}

	return true;
}

static stock bool:Economy_ContainerConsolidate(containerid)
{
	new worth = 0;

	for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
	{
		worth += Container_Count(containerid,ITEM_KIND_COIN,tier) * Item_CoinWorth(tier);
	}

	if (worth <= 0)
	{
		return false;
	}

	for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
	{
		new held = Container_Count(containerid,ITEM_KIND_COIN,tier);

		if (held > 0)
		{
			Container_TakeStars(containerid,ITEM_KIND_COIN,tier,held,ITEM_STARS_MIN);
		}
	}

	new counts[COIN_TIER_COUNT];
	Economy_Split(worth,counts);
	Economy_ContainerTryAdd(containerid,counts);
	return true;
}

static stock bool:Economy_ContainerAddCounts(containerid,const counts[COIN_TIER_COUNT])
{
	return Economy_ContainerTryAdd(containerid,counts) || (Economy_ContainerConsolidate(containerid) && Economy_ContainerTryAdd(containerid,counts));
}

stock Economy_Worth(playerid)
{
	if (!Inventory_IsLoaded(playerid))
	{
		return 0;
	}

	new worth = 0;
	for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
	{
		worth += Economy_CountTier(playerid,tier) * Item_CoinWorth(tier);
	}

	return worth;
}

stock Economy_Log(E_LEDGER_KIND:kind,const source[],amount,fromCharacter = 0,toCharacter = 0,containerid = INVALID_CONTAINER_ID)
{
	mysql_pquery_s(g_Mysql,str_format("INSERT INTO coin_ledger (kind, source, amount, from_character_id, to_character_id, container_id) VALUES (%d, '%e', %d, NULLIF(%d, 0), NULLIF(%d, 0), NULLIF(%d, 0))",_:kind,source,amount,fromCharacter,toCharacter,containerid));
}

stock bool:Economy_Give(playerid,pfennig,const source[])
{
	if (!Inventory_IsLoaded(playerid) || pfennig <= 0)
	{
		return false;
	}

	new counts[COIN_TIER_COUNT];
	Economy_Split(pfennig,counts);
	if (!Economy_GiveCounts(playerid,counts))
	{
		return false;
	}

	Economy_Log(LEDGER_GIVE,source,pfennig,0,Character_GetId(playerid));
	pawn_call_public("Economy_OnCoinChanged","d",playerid);
	return true;
}

stock Economy_CountCoins(playerid,tier)
{
	return tier >= COIN_PFENNIG && tier < COIN_TIER_COUNT ? Economy_CountTier(playerid,tier) : 0;
}

stock bool:Economy_BreakCoin(playerid,tier,fee)
{
	if (!Inventory_IsLoaded(playerid) || tier <= COIN_PFENNIG || tier >= COIN_TIER_COUNT || Economy_CountTier(playerid,tier) < 1 || fee < 0 || fee >= Item_CoinWorth(tier))
	{
		return false;
	}

	new counts[COIN_TIER_COUNT], left = Item_CoinWorth(tier) - fee;

	for (new lower = tier - 1;lower >= COIN_PFENNIG;lower--)
	{
		counts[lower] = left / Item_CoinWorth(lower);
		left -= counts[lower] * Item_CoinWorth(lower);
	}

	if (Economy_TakeTier(playerid,tier,1) < 1)
	{
		return false;
	}

	if (!Economy_GiveCounts(playerid,counts))
	{
		Economy_GiveTier(playerid,tier,1);
		return false;
	}

	Economy_Log(LEDGER_CHANGE,"break coin",Item_CoinWorth(tier),Character_GetId(playerid),Character_GetId(playerid));
	pawn_call_public("Economy_OnCoinChanged","d",playerid);
	return true;
}

stock bool:Economy_MakeCoin(playerid,tier,fee)
{
	if (!Inventory_IsLoaded(playerid) || tier <= COIN_PFENNIG || tier >= COIN_TIER_COUNT || fee < 0)
	{
		return false;
	}

	new need = Item_CoinWorth(tier) + fee, small = 0, taken[COIN_TIER_COUNT];

	for (new lower = COIN_PFENNIG;lower < tier;lower++)
	{
		small += Economy_CountTier(playerid,lower) * Item_CoinWorth(lower);
	}

	if (small < need)
	{
		return false;
	}

	new left = need;

	for (new lower = tier - 1;lower >= COIN_PFENNIG && left > 0;lower--)
	{
		taken[lower] = min(Economy_CountTier(playerid,lower),left / Item_CoinWorth(lower));
		left -= taken[lower] * Item_CoinWorth(lower);
	}

	for (new lower = COIN_PFENNIG;lower < tier && left > 0;lower++)
	{
		new spare = Economy_CountTier(playerid,lower) - taken[lower];

		while (spare > 0 && left > 0)
		{
			taken[lower]++;
			spare--;
			left -= Item_CoinWorth(lower);
		}
	}

	new change = left < 0 ? -left : 0;

	for (new lower = COIN_PFENNIG;lower < tier;lower++)
	{
		Economy_TakeTier(playerid,lower,taken[lower]);
	}

	new counts[COIN_TIER_COUNT], back[COIN_TIER_COUNT];
	counts[tier] = 1;
	Economy_Split(change,back);

	for (new t = COIN_PFENNIG;t < COIN_TIER_COUNT;t++)
	{
		counts[t] += back[t];
	}

	if (!Economy_GiveCounts(playerid,counts))
	{
		Economy_GiveCounts(playerid,taken);
		return false;
	}

	Economy_Log(LEDGER_CHANGE,"make coin",Item_CoinWorth(tier),Character_GetId(playerid),Character_GetId(playerid));
	pawn_call_public("Economy_OnCoinChanged","d",playerid);
	return true;
}

stock Economy_GiveOrClaim(playerid,characterid,pfennig,const source[])
{
	if (pfennig <= 0 || characterid <= 0)
	{
		return;
	}

	if (Util_IsValidPlayer(playerid) && Character_GetId(playerid) == characterid && Economy_Give(playerid,pfennig,source))
	{
		return;
	}

	new counts[COIN_TIER_COUNT];
	Economy_Split(pfennig,counts);

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Claims_Give(characterid,ITEM_KIND_COIN,tier,counts[tier],ITEM_STARS_MIN,source);
		}
	}

	Economy_Log(LEDGER_GIVE,source,pfennig,0,characterid);
}

stock E_PAY_RESULT:Economy_Pay(playerid,pfennig,containerid = INVALID_CONTAINER_ID,const source[] = "pay")
{
	if (!Inventory_IsLoaded(playerid) || pfennig <= 0 || Economy_Worth(playerid) < pfennig)
	{
		return PAY_SHORT;
	}

	new counts[COIN_TIER_COUNT], taken[COIN_TIER_COUNT], remaining = pfennig;
	for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
	{
		counts[tier] = Economy_CountTier(playerid,tier);
		taken[tier] = remaining / Item_CoinWorth(tier);
		if (taken[tier] > counts[tier])
		{
			taken[tier] = counts[tier];
		}

		remaining -= taken[tier] * Item_CoinWorth(tier);
	}

	new change = 0;
	if (remaining > 0)
	{
		for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
		{
			if (counts[tier] - taken[tier] > 0)
			{
				taken[tier]++;
				change = Item_CoinWorth(tier) - remaining;
				remaining = 0;
				break;
			}
		}
	}

	for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
	{
		Economy_TakeTier(playerid,tier,taken[tier]);
	}

	new price[COIN_TIER_COUNT];
	Economy_Split(pfennig,price);
	if (containerid != INVALID_CONTAINER_ID && !Economy_ContainerAddCounts(containerid,price))
	{
		Economy_GiveCounts(playerid,taken);
		return PAY_NO_ROOM;
	}

	if (change > 0)
	{
		new back[COIN_TIER_COUNT];
		Economy_Split(change,back);
		if (!Economy_GiveCounts(playerid,back))
		{
			if (containerid != INVALID_CONTAINER_ID)
			{
				for (new tier = COIN_PFENNIG; tier < COIN_TIER_COUNT; tier++)
				{
					if (price[tier] > 0)
					{
						Container_TakeStars(containerid,ITEM_KIND_COIN,tier,price[tier],ITEM_STARS_MIN);
					}
				}
			}

			Economy_GiveCounts(playerid,taken);
			return PAY_NO_ROOM;
		}
	}

	Economy_Log(LEDGER_PAY,source,pfennig,Character_GetId(playerid),0,containerid);
	pawn_call_public("Economy_OnCoinChanged","d",playerid);
	return PAY_OK;
}

static stock Economy_GrantOriginCoin(characterid,pfennig)
{
	new counts[COIN_TIER_COUNT];
	Economy_Split(pfennig,counts);
	for (new tier = COIN_TIER_COUNT - 1; tier >= COIN_PFENNIG; tier--)
	{
		if (counts[tier] > 0)
		{
			mysql_tquery_s(g_Mysql,str_format("INSERT INTO character_items (character_id, kind, param, amount, stars) VALUES (%d, %d, %d, %d, 1)",characterid,_:ITEM_KIND_COIN,tier,counts[tier]));
		}
	}

	Economy_Log(LEDGER_ORIGIN,"origin",pfennig,0,characterid);
}

forward Economy_OnCoinChanged(playerid);

public Economy_OnCoinChanged(playerid)
{
	return 1;
}

#include <pp-hooks>

hook Character_OnCreated(playerid,characterid)
{
	new pfennig = Creator_OriginCoin(Creator_GetOrigin(playerid));
	if (pfennig > 0)
	{
		Economy_GrantOriginCoin(characterid,pfennig);
	}
}
