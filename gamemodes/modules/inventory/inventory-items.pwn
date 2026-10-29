stock bool:Item_IsValid(E_ITEM_KIND:kind,param)
{
	switch (kind)
	{
		case ITEM_KIND_WEAPON: return Weapon_IsValid(param);
		case ITEM_KIND_SHIELD: return Shield_IsValid(param);
		case ITEM_KIND_FOOD, ITEM_KIND_DRINK, ITEM_KIND_TOOL, ITEM_KIND_MISC, ITEM_KIND_MATERIAL, ITEM_KIND_CLOTHING: return param >= 0 && param < ITEM_DEF_COUNT && g_ItemDefs[param][E_ITEM_DEF_KIND] == kind;
		case ITEM_KIND_COIN: return param >= COIN_PFENNIG && param < COIN_TIER_COUNT;
		case ITEM_KIND_CONTAINER: return param > 0;
		case ITEM_KIND_COUNT: return false;
	}

	return false;
}

stock E_ITEM_KIND:Item_GetDefKind(item)
{
	if (item < 0 || item >= ITEM_DEF_COUNT)
	{
		return ITEM_KIND_COUNT;
	}

	return g_ItemDefs[item][E_ITEM_DEF_KIND];
}

stock bool:Item_IsValidStars(stars)
{
	return stars >= ITEM_STARS_MIN && stars <= ITEM_STARS_MAX;
}

stock Float:Item_StarFactor(stars)
{
	if (!Item_IsValidStars(stars))
	{
		return 1.0;
	}

	return 1.0 + 0.25 * float(stars - ITEM_STARS_MIN);
}

stock Item_GetName(E_ITEM_KIND:kind,param,dest[],size = sizeof(dest))
{
	if (!Item_IsValid(kind,param))
	{
		strcopy(dest,"Nothing",size);
		return;
	}

	switch (kind)
	{
		case ITEM_KIND_WEAPON: Weapon_GetName(param,dest,size);
		case ITEM_KIND_SHIELD: format(dest,size,"Shield %d",param + 1);
		case ITEM_KIND_COIN: strcopy(dest,g_CoinDefs[param][E_COIN_DEF_NAME],size);
		case ITEM_KIND_CONTAINER: Container_GetLabel(param,dest,size);
		default: strcopy(dest,g_ItemDefs[param][E_ITEM_DEF_NAME],size);
	}
}

stock Item_GetModel(E_ITEM_KIND:kind,param,data = 0)
{
	if (!Item_IsValid(kind,param))
	{
		return 0;
	}

	switch (kind)
	{
		case ITEM_KIND_WEAPON: return Weapon_GetModel(param);
		case ITEM_KIND_SHIELD: return Shield_GetModel(param);
		case ITEM_KIND_COIN: return g_CoinDefs[param][E_COIN_DEF_MODEL];
		case ITEM_KIND_CONTAINER: return ITEM_CONTAINER_MODEL;
	}

    if (kind == ITEM_KIND_MATERIAL && param == ITEM_CARCASS)
    {
        return Hunting_GetItemModel(data);
    }

	new delivered = Item_GetDeliveredModel(param);
	return delivered != 0 ? delivered : g_ItemDefs[param][E_ITEM_DEF_MODEL];
}

stock Item_GetIcon(E_ITEM_KIND:kind,param,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Item_IsValid(kind,param))
	{
		return;
	}

	switch (kind)
	{
		case ITEM_KIND_WEAPON: strcopy(dest,g_WeaponIcons[param],size);
		case ITEM_KIND_SHIELD: strcopy(dest,param < sizeof(g_ShieldIcons) ? g_ShieldIcons[param] : ITEM_ICON_UNKNOWN,size);
		case ITEM_KIND_COIN: strcopy(dest,g_CoinIcons[param],size);
		case ITEM_KIND_CONTAINER: Container_GetIcon(param,dest,size);
		default: strcopy(dest,g_ItemIcons[param],size);
	}
}

stock Item_GetValue(E_ITEM_KIND:kind,param)
{
	if (!Item_IsValid(kind,param) || kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD || kind == ITEM_KIND_CONTAINER)
	{
		return 0;
	}

	if (kind == ITEM_KIND_COIN)
	{
		return g_CoinDefs[param][E_COIN_DEF_WORTH];
	}

	return g_ItemDefs[param][E_ITEM_DEF_VALUE];
}

stock Item_GetPortions(E_ITEM_KIND:kind,param)
{
	if (kind != ITEM_KIND_FOOD && kind != ITEM_KIND_DRINK)
	{
		return 1;
	}

	return Util_ClampInt((Item_GetValue(kind,param) + ITEM_PORTION_VALUE / 2) / ITEM_PORTION_VALUE,1,ITEM_PORTIONS_MAX);
}

stock Inventory_NotifyStarted(playerid,E_ITEM_KIND:kind,param)
{
	new name[ITEM_NAME_LEN];
	Item_GetName(kind,param,name);
	name[0] = tolower(name[0]);
	Gui_Notify(playerid,sprintf("You've already started the %s. Finish it before you put it down.",name));
}

stock Item_StarPricePercent(stars)
{
	return Item_IsValidStars(stars) ? g_ItemStarPricePercent[stars] : 100;
}

stock Item_GetPrice(E_ITEM_KIND:kind,param,stars = ITEM_STARS_MIN)
{
	if (!Item_IsValid(kind,param))
	{
		return 0;
	}

	new base = 0;
	switch (kind)
	{
		case ITEM_KIND_WEAPON:
		{
			new type = _:Weapon_GetType(param);
			base = type >= 0 && type < ITEM_WEAPON_TYPE_COUNT ? g_WeaponTypePrice[type] : 0;
		}
		case ITEM_KIND_SHIELD: base = ITEM_SHIELD_PRICE;
		case ITEM_KIND_COIN: return g_CoinDefs[param][E_COIN_DEF_WORTH];
		case ITEM_KIND_CONTAINER: return 0;
		default: base = g_ItemDefs[param][E_ITEM_DEF_PRICE];
	}

	return base * Item_StarPricePercent(stars) / 100;
}

stock Item_CoinWorth(tier)
{
	if (tier < COIN_PFENNIG || tier >= COIN_TIER_COUNT)
	{
		return 0;
	}

	return g_CoinDefs[tier][E_COIN_DEF_WORTH];
}

stock bool:Item_Stacks(E_ITEM_KIND:kind,param)
{
	if (!Item_IsValid(kind,param) || kind == ITEM_KIND_WEAPON || kind == ITEM_KIND_SHIELD || kind == ITEM_KIND_CONTAINER)
	{
		return false;
	}

	if (kind == ITEM_KIND_COIN)
	{
		return true;
	}

	return g_ItemDefs[param][E_ITEM_DEF_STACKS];
}

stock Item_GetStackMax(E_ITEM_KIND:kind,param)
{
	if (!Item_Stacks(kind,param))
	{
		return 1;
	}

	return kind == ITEM_KIND_COIN ? COIN_STACK_MAX : INVENTORY_STACK_MAX;
}

static s_ItemGroups[ITEM_GROUP_MAX][2];
static s_ItemGroupCount;

stock bool:Item_IsInGroup(group,member)
{
	if (group == member)
	{
		return true;
	}

	for (new i = 0;i < s_ItemGroupCount;i++)
	{
		if (s_ItemGroups[i][0] == group && s_ItemGroups[i][1] == member)
		{
			return true;
		}
	}

	return false;
}

stock bool:Item_AddToGroup(group,member)
{
	if (s_ItemGroupCount >= ITEM_GROUP_MAX || group == member || Item_IsInGroup(group,member))
	{
		return false;
	}

	s_ItemGroups[s_ItemGroupCount][0] = group;
	s_ItemGroups[s_ItemGroupCount][1] = member;
	s_ItemGroupCount++;
	return true;
}

stock Item_GetGroupMember(group,nth)
{
	if (nth == 0)
	{
		return group;
	}

	for (new i = 0, seen = 0;i < s_ItemGroupCount;i++)
	{
		if (s_ItemGroups[i][0] == group && ++seen == nth)
		{
			return s_ItemGroups[i][1];
		}
	}

	return -1;
}

stock Item_AppendStars(name[],stars,size = sizeof(name))
{
	if (stars <= ITEM_STARS_MIN || !Item_IsValidStars(stars))
	{
		return;
	}

	format(name,size,"%s (%d*)",name,stars);
}

stock bool:Item_CarriedAccepts(carrier,E_ITEM_KIND:kind,param)
{
	if (kind == ITEM_KIND_CONTAINER)
	{
		return false;
	}

	if (kind != ITEM_KIND_COIN && kind != ITEM_KIND_WEAPON && kind != ITEM_KIND_SHIELD && param >= 0 && param < ITEM_DEF_COUNT && g_ItemBulky[param])
	{
		return false;
	}

	switch (carrier)
	{
		case ITEM_BELT_POUCH:
		{
			if (kind == ITEM_KIND_COIN || (kind == ITEM_KIND_MATERIAL && param >= ITEM_HERB_FIRST && param <= ITEM_HERB_LAST))
			{
				return true;
			}

			switch (param)
			{
				case ITEM_HERBS, ITEM_HERBS_RARE, ITEM_BAIT, ITEM_WORMS, ITEM_GRUBS, ITEM_MAGGOTS, ITEM_SEED, ITEM_SEED_WILD, ITEM_SPICE, ITEM_SALT, ITEM_FLINT, ITEM_NEEDLE, ITEM_KEY_COPY, ITEM_SEAL_RING, ITEM_DICE, ITEM_DIE_WEIGHTED, ITEM_DIE_HEAVY, ITEM_DIE_LUCKY, ITEM_DIE_DEVIL, ITEM_CARDS, ITEM_LETTER, ITEM_LETTER_SEALED, ITEM_LETTER_OPENED, ITEM_POULTICE, ITEM_TINCTURE, ITEM_SALVE: return true;
			}

			return false;
		}
		case ITEM_BASKET, ITEM_WOVEN_BASKET:
		{
			if (kind != ITEM_KIND_MATERIAL && kind != ITEM_KIND_FOOD)
			{
				return false;
			}

			if (kind == ITEM_KIND_MATERIAL && param >= ITEM_HERB_FIRST && param <= ITEM_HERB_LAST)
			{
				return true;
			}

			switch (param)
			{
				case ITEM_CABBAGE, ITEM_ONION, ITEM_LEEK, ITEM_TURNIP, ITEM_PEAR, ITEM_PLUM, ITEM_CHERRIES, ITEM_EGGS, ITEM_BERRIES, ITEM_NUTS, ITEM_MUSHROOMS, ITEM_MUSHROOM_RARE, ITEM_HERBS, ITEM_HERBS_RARE, ITEM_APPLE, ITEM_CIDER_APPLES, ITEM_BREAD, ITEM_RYE_LOAF, ITEM_CHEESE, ITEM_BUTTER, ITEM_DYE_PLANT, ITEM_POPPY, ITEM_OAK_GALLS: return true;
			}

			return false;
		}
		case ITEM_CREEL:
		{
			return kind == ITEM_KIND_MATERIAL && (param == ITEM_FISH || param == ITEM_FISH_RARE || param == ITEM_SPOILED_FISH || param == ITEM_BAIT || param == ITEM_WORMS || param == ITEM_MAGGOTS || (param >= ITEM_FISH_GUDGEON && param <= ITEM_FISH_SWORDFISH));
		}
	}

	return kind != ITEM_KIND_COIN || carrier == ITEM_SATCHEL || carrier == ITEM_BACKPACK;
}
