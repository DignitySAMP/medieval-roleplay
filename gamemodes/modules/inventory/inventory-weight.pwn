#define CARRY_BASE_GRAMS (25000)
#define CARRY_WILLPOWER_GRAMS (3000)
#define CARRY_SATCHEL_GRAMS (4000)
#define CARRY_BACKPACK_GRAMS (10000)
#define CARRY_COIN_GRAMS (5)

enum
{
	CARRY_LIGHT,
	CARRY_HEAVY,
	CARRY_OVERLOADED,
}

stock Item_GetWeight(E_ITEM_KIND:kind,param)
{
	switch (kind)
	{
		case ITEM_KIND_COIN: return CARRY_COIN_GRAMS;
		case ITEM_KIND_CONTAINER:
		{
			switch (Container_GetOwnerType(param))
			{
				case CONTAINER_OWNER_COFFER: return 15000 + Container_ContentWeight(param);
				case CONTAINER_OWNER_BAG: return 300 + Container_ContentWeight(param);
			}

			return 100 + Container_ContentWeight(param);
		}
	}

	if (kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD)
	{
		return kind == ITEM_KIND_SHIELD ? 4000 : 1500;
	}

	return param >= 0 && param < ITEM_DEF_COUNT ? g_ItemWeights[param] : 0;
}

stock bool:Item_IsBulky(E_ITEM_KIND:kind,param)
{
	if (kind == ITEM_KIND_COIN)
	{
		return false;
	}

	if (kind == ITEM_KIND_CONTAINER)
	{
		return Container_GetOwnerType(param) == CONTAINER_OWNER_COFFER;
	}

	if (kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD)
	{
		return false;
	}

	return param >= 0 && param < ITEM_DEF_COUNT && g_ItemBulky[param];
}

stock Item_GetLoad(E_ITEM_KIND:kind,param)
{
	if (kind == ITEM_KIND_CONTAINER)
	{
		return Container_GetOwnerType(param) == CONTAINER_OWNER_COFFER ? 5 : 0;
	}

	if (kind == ITEM_KIND_COIN || kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD)
	{
		return 0;
	}

	return param >= 0 && param < ITEM_DEF_COUNT ? g_ItemLoad[param] : 0;
}

stock Container_ContentWeight(containerid)
{
	new grams = 0;

	for (new slot = 0;slot < Container_GetSlots(containerid);slot++)
	{
		new E_ITEM_KIND:kind, param, amount, stars;

		if (Container_GetSlot(containerid,slot,kind,param,amount,stars) && kind != ITEM_KIND_CONTAINER)
		{
			grams += Item_GetWeight(kind,param) * amount;
		}
	}

	return grams;
}

stock bool:Item_IsCarrier(E_ITEM_KIND:kind,param)
{
	if (kind == ITEM_KIND_COIN || kind == ITEM_KIND_CONTAINER)
	{
		return false;
	}

	switch (param)
	{
		case ITEM_SATCHEL, ITEM_BACKPACK, ITEM_BELT_POUCH, ITEM_BASKET, ITEM_WOVEN_BASKET, ITEM_CREEL: return true;
	}

	return false;
}

stock Item_CarrierSlots(param)
{
	switch (param)
	{
		case ITEM_SATCHEL: return 6;
		case ITEM_BACKPACK: return 10;
		case ITEM_BELT_POUCH: return 3;
		case ITEM_BASKET, ITEM_CREEL: return 6;
		case ITEM_WOVEN_BASKET: return 4;
	}

	return 0;
}

stock Inventory_GetWeight(playerid)
{
	new grams = 0, count = Inventory_GetCount(playerid);

	for (new index = 0;index < count;index++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (!Inventory_GetSlot(playerid,index,kind,param,amount))
		{
			continue;
		}

		grams += Item_GetWeight(kind,param) * amount;

		if (Item_IsCarrier(kind,param))
		{
			new containerid = Inventory_GetSlotData(playerid,index);

			if (containerid > 0 && Container_IsLoaded(containerid))
			{
				grams += Container_ContentWeight(containerid);
			}
		}
	}

	return grams;
}

stock bool:Inventory_HasItem(playerid,param)
{
	return Inventory_Count(playerid,Item_GetDefKind(param),param) > 0;
}

stock Inventory_GetCarryLimit(playerid)
{
	new grams = CARRY_BASE_GRAMS + CARRY_WILLPOWER_GRAMS * Character_GetAttribute(playerid,0);

	if (Inventory_HasItem(playerid,ITEM_BACKPACK))
	{
		grams += CARRY_BACKPACK_GRAMS;
	}
	else if (Inventory_HasItem(playerid,ITEM_SATCHEL))
	{
		grams += CARRY_SATCHEL_GRAMS;
	}

	return grams;
}

stock Inventory_LoadBandOf(grams,limit)
{
	if (grams > limit * 3 / 2)
	{
		return CARRY_OVERLOADED;
	}

	return grams > limit ? CARRY_HEAVY : CARRY_LIGHT;
}

stock Inventory_GetLoadBand(playerid)
{
	return Inventory_LoadBandOf(Inventory_GetWeight(playerid),Inventory_GetCarryLimit(playerid));
}

stock Inventory_CountBulky(playerid)
{
	new units = 0, count = Inventory_GetCount(playerid);

	for (new index = 0;index < count;index++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (Inventory_GetSlot(playerid,index,kind,param,amount) && Item_IsBulky(kind,param))
		{
			units += amount;
		}
	}

	return units;
}

stock Inventory_GetHeaviestBulky(playerid,&E_ITEM_KIND:kind,&param)
{
	new best = -1, bestGrams = 0, count = Inventory_GetCount(playerid);

	for (new index = 0;index < count;index++)
	{
		new E_ITEM_KIND:k, p, amount;

		if (!Inventory_GetSlot(playerid,index,k,p,amount) || !Item_IsBulky(k,p))
		{
			continue;
		}

		new grams = Item_GetWeight(k,p);

		if (grams > bestGrams)
		{
			best = index;
			bestGrams = grams;
			kind = k;
			param = p;
		}
	}

	return best;
}
