#define INVENTORY_FRESH_TICK_MS (60000)
#define ITEM_FISH_FRESH_SECONDS (3600)
#define ITEM_PERISHABLE_MAX (64)

enum E_PERISHABLE
{
	E_PERISHABLE_ITEM,
	E_PERISHABLE_SECONDS,
	E_PERISHABLE_SPOILS_TO,
}

static s_Perishables[ITEM_PERISHABLE_MAX][E_PERISHABLE];
static s_PerishableCount;

stock bool:Item_SetPerishable(item,seconds,spoilsTo)
{
	if (s_PerishableCount >= ITEM_PERISHABLE_MAX || item < 0 || item >= ITEM_DEF_COUNT)
	{
		return false;
	}

	s_Perishables[s_PerishableCount][E_PERISHABLE_ITEM] = item;
	s_Perishables[s_PerishableCount][E_PERISHABLE_SECONDS] = seconds;
	s_Perishables[s_PerishableCount][E_PERISHABLE_SPOILS_TO] = spoilsTo;
	s_PerishableCount++;
	return true;
}

static Item_FindPerishable(E_ITEM_KIND:kind,param)
{
	if (param < 0 || param >= ITEM_DEF_COUNT || Item_GetDefKind(param) != kind)
	{
		return -1;
	}

	for (new i = 0;i < s_PerishableCount;i++)
	{
		if (s_Perishables[i][E_PERISHABLE_ITEM] == param)
		{
			return i;
		}
	}

	return -1;
}

stock Item_GetSpoilSeconds(E_ITEM_KIND:kind,param)
{
	new index = Item_FindPerishable(kind,param);
	return index == -1 ? 0 : s_Perishables[index][E_PERISHABLE_SECONDS];
}

stock Item_ResolveFresh(E_ITEM_KIND:kind,param,freshAt)
{
	if (Item_FindPerishable(kind,param) == -1)
	{
		return 0;
	}

	return freshAt == ITEM_FRESH_NOW ? gettime() : freshAt;
}

stock Item_OlderFresh(first,second)
{
	if (first == 0)
	{
		return second;
	}

	if (second == 0)
	{
		return first;
	}

	return min(first,second);
}

stock Inventory_GetFreshLeft(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount))
	{
		return -1;
	}

	new seconds = Item_GetSpoilSeconds(kind,param), freshAt = Inventory_GetSlotFresh(playerid,index);

	if (seconds == 0 || freshAt == 0)
	{
		return -1;
	}

	return max(0,freshAt + seconds - gettime());
}

stock Inventory_SpoilCheck(playerid)
{
	new spoiled = 0, name[ITEM_NAME_LEN];

	for (new index = Inventory_GetCount(playerid) - 1;index >= 0;index--)
	{
		if (Inventory_GetFreshLeft(playerid,index) != 0)
		{
			continue;
		}

		new E_ITEM_KIND:kind, param, amount, perishable;
		Inventory_GetSlot(playerid,index,kind,param,amount);
		perishable = Item_FindPerishable(kind,param);
		Item_GetName(kind,param,name);

		if (Inventory_TakeSlot(playerid,index,amount))
		{
			new into = s_Perishables[perishable][E_PERISHABLE_SPOILS_TO];
			Inventory_Give(playerid,Item_GetDefKind(into),into,amount,ITEM_STARS_MIN,0);
			spoiled++;
		}
	}

	if (spoiled == 1)
	{
		Gui_Notify(playerid,sprintf("Your %s went off. Cook fish within an hour of catching it.",name));
	}
	else if (spoiled > 1)
	{
		Gui_Notify(playerid,"Some of your fish went off. Cook fish within an hour of catching it.");
	}

	return spoiled;
}

forward Inventory_FreshTick();

public Inventory_FreshTick()
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Inventory_IsLoaded(playerid))
		{
			Inventory_SpoilCheck(playerid);
		}
	}

	return 1;
}

#include <pp-hooks>

hook Inventory_OnLoaded(playerid)
{
	Inventory_SpoilCheck(playerid);
}
