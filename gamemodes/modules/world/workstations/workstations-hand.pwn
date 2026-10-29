#define WORK_HAND_INPUTS (3)
#define WORK_CRUDE_STAR_CAP (3)
#define WORK_CRUDE_BREAK_ODDS (6)

enum E_WORK_HAND_DEF
{
	E_WORK_HAND_DEF_ITEM,
	E_WORK_HAND_DEF_AMOUNT,
	E_WORK_HAND_DEF_IN[WORK_HAND_INPUTS],
	E_WORK_HAND_DEF_IN_AMOUNT[WORK_HAND_INPUTS],
}

static const s_WorkHandDefs[][E_WORK_HAND_DEF] = {
	{ITEM_CRUDE_AXE, 1, {ITEM_BRANCH, ITEM_FLINT, -1}, {1, 1, 0}},
	{ITEM_FLINT_KNIFE, 1, {ITEM_FLINT, ITEM_BRANCH, -1}, {1, 1, 0}},
	{ITEM_DIGGING_STICK, 1, {ITEM_BRANCH, -1, -1}, {2, 0, 0}},
	{ITEM_STONE_PICK, 1, {ITEM_BRANCH, ITEM_FLINT, -1}, {1, 2, 0}},
	{ITEM_WOVEN_BASKET, 1, {ITEM_BRANCH, -1, -1}, {4, 0, 0}},
	{ITEM_KINDLING, 3, {ITEM_BRANCH, -1, -1}, {1, 0, 0}},
	{ITEM_SPLINT, 1, {ITEM_BRANCH, ITEM_BARK, -1}, {2, 1, 0}}
};

enum E_WORK_CRUDE_DEF
{
	E_WORK_CRUDE_DEF_CRUDE,
	E_WORK_CRUDE_DEF_TOOL,
}

static const s_WorkCrudeDefs[][E_WORK_CRUDE_DEF] = {
	{ITEM_CRUDE_AXE, ITEM_AXE},
	{ITEM_FLINT_KNIFE, ITEM_KNIFE},
	{ITEM_DIGGING_STICK, ITEM_SHOVEL},
	{ITEM_STONE_PICK, ITEM_PICKAXE},
	{ITEM_WOVEN_BASKET, ITEM_BASKET}
};

stock Work_GetHandCount()
{
	return sizeof(s_WorkHandDefs);
}

stock bool:Work_GetHandOutput(hand,&item,&amount)
{
	if (hand < 0 || hand >= sizeof(s_WorkHandDefs))
	{
		return false;
	}

	item = s_WorkHandDefs[hand][E_WORK_HAND_DEF_ITEM];
	amount = s_WorkHandDefs[hand][E_WORK_HAND_DEF_AMOUNT];
	return true;
}

stock bool:Work_GetHandInput(hand,slot,&item,&amount)
{
	if (hand < 0 || hand >= sizeof(s_WorkHandDefs) || slot < 0 || slot >= WORK_HAND_INPUTS || s_WorkHandDefs[hand][E_WORK_HAND_DEF_IN][slot] == -1)
	{
		return false;
	}

	item = s_WorkHandDefs[hand][E_WORK_HAND_DEF_IN][slot];
	amount = s_WorkHandDefs[hand][E_WORK_HAND_DEF_IN_AMOUNT][slot];
	return true;
}

stock bool:Work_CanMakeByHand(playerid,hand)
{
	if (hand < 0 || hand >= sizeof(s_WorkHandDefs))
	{
		return false;
	}

	for (new slot = 0, item, amount;slot < WORK_HAND_INPUTS;slot++)
	{
		if (Work_GetHandInput(hand,slot,item,amount) && Inventory_Count(playerid,Item_GetDefKind(item),item) < amount)
		{
			return false;
		}
	}

	return true;
}

stock bool:Work_MakeByHand(playerid,hand)
{
	if (!Work_CanMakeByHand(playerid,hand))
	{
		return false;
	}

	for (new slot = 0, item, amount;slot < WORK_HAND_INPUTS;slot++)
	{
		if (Work_GetHandInput(hand,slot,item,amount))
		{
			Inventory_Take(playerid,Item_GetDefKind(item),item,amount);
		}
	}

	new item = s_WorkHandDefs[hand][E_WORK_HAND_DEF_ITEM], amount = s_WorkHandDefs[hand][E_WORK_HAND_DEF_AMOUNT];

	if (!Inventory_Give(playerid,Item_GetDefKind(item),item,amount))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		Drop_Create(Item_GetDefKind(item),item,amount,x,y,z - 0.9,GetPlayerVirtualWorld(playerid),.interior = GetPlayerInterior(playerid));
	}

	if (!Character_IsBusy(playerid))
	{
		ApplyAnimation(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
	}

	return true;
}

stock Work_FindCrudeFor(tool)
{
	for (new i = 0;i < sizeof(s_WorkCrudeDefs);i++)
	{
		if (s_WorkCrudeDefs[i][E_WORK_CRUDE_DEF_TOOL] == tool)
		{
			return s_WorkCrudeDefs[i][E_WORK_CRUDE_DEF_CRUDE];
		}
	}

	return -1;
}

stock Work_FindToolForCrude(crude)
{
	for (new i = 0;i < sizeof(s_WorkCrudeDefs);i++)
	{
		if (s_WorkCrudeDefs[i][E_WORK_CRUDE_DEF_CRUDE] == crude)
		{
			return s_WorkCrudeDefs[i][E_WORK_CRUDE_DEF_TOOL];
		}
	}

	return -1;
}

stock Work_GetCrudeInUse(playerid,tool)
{
	if (tool == RECIPE_NO_TOOL || Inventory_Count(playerid,Item_GetDefKind(tool),tool) > 0)
	{
		return -1;
	}

	new crude = Work_FindCrudeFor(tool);
	return crude != -1 && Inventory_Count(playerid,Item_GetDefKind(crude),crude) > 0 ? crude : -1;
}

stock bool:Work_WearCrudeTool(playerid,crude)
{
	if (crude == -1 || random(WORK_CRUDE_BREAK_ODDS) != 0)
	{
		return false;
	}

	new name[ITEM_NAME_LEN];
	Inventory_Take(playerid,Item_GetDefKind(crude),crude,1);
	Item_GetName(Item_GetDefKind(crude),crude,name);
	Gui_Notify(playerid,sprintf("Your %s falls apart.",name));
	return true;
}
