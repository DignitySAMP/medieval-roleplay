CMD<ADMIN_LEVEL_TRIAL>:dice(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], kindName[12], amount = 1, faces[DICE_COUNT];

	if (sscanf(params,"s[12]S()[12]I(1)",action,kindName,amount))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /dice give <plain|weighted|heavy|lucky|devil> [amount], /dice rig <six faces>");
		return 1;
	}

	if (!strcmp(action,"give",true))
	{
		static const names[DICE_KIND_COUNT][] = {"plain", "weighted", "heavy", "lucky", "devil"};
		new kind = -1, name[ITEM_NAME_LEN];

		for (new i = 0;i < DICE_KIND_COUNT;i++)
		{
			if (!strcmp(kindName,names[i],true))
			{
				kind = i;
			}
		}

		if (kind == -1 || amount < 1 || amount > 6)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /dice give <plain|weighted|heavy|lucky|devil> [1-6]");
			return 1;
		}

		Item_GetName(DICE_ITEM_KIND,g_DiceKindItems[kind],name);

		if (!Inventory_Give(playerid,DICE_ITEM_KIND,g_DiceKindItems[kind],amount))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Your bag is full.");
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("You got %d %s.",amount,name));
		return 1;
	}

	if (!strcmp(action,"rig",true))
	{
		new table = Table_GetPlayerTable(playerid);

		if (sscanf(params,"{s[12]}a<i>[6]",faces) || !Dice_IsRunning(table))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /dice rig <six faces>, during a game of dice. The next roll lands on those faces.");
			return 1;
		}

		for (new die = 0;die < DICE_COUNT;die++)
		{
			if (faces[die] < 1 || faces[die] > DICE_FACES)
			{
				SendClientMessage(playerid,0xFFFFFFFF,"Each face is a number from 1 to 6.");
				return 1;
			}
		}

		Dice_RigNextRoll(table,faces);
		SendClientMessage(playerid,0xFFFFFFFF,"The next roll at your table is rigged.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /dice give <plain|weighted|heavy|lucky|devil> [amount], /dice rig <six faces>");
	return 1;
}
