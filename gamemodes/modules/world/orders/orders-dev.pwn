CMD<ADMIN_LEVEL_ADMIN>:orders(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], value, extra;

	if (sscanf(params,"s[12]I(-1)I(0)",action,value,extra))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/orders list | roll | expire | clear | goodwill <player> <n> | daily <player> | duties <player> | warrant <player> <trade>");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d errands open (%d pf promised), %d contracts, treasury %d pf.",Orders_Count(),Orders_OpenPay(),Contracts_Count(),Realm_TreasuryCoin()));

		for (new slot = 0;slot < ORDERS_MAX;slot++)
		{
			if (Orders_IsValid(slot))
			{
				new text[ORDERS_TEXT_LEN], key[ACTORS_KEY_LEN];
				Orders_FormatText(slot,text);
				Orders_GetGiverKey(slot,key);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("#%d %s: %s, %d pf, until day %d, taker %d",slot,key,text,Orders_GetPay(slot),Orders_GetExpires(slot),Orders_GetTaker(slot)));
			}
		}

		return 1;
	}

	if (!strcmp(action,"roll",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d errands posted.",Orders_RollAll()));
		return 1;
	}

	if (!strcmp(action,"expire",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d errands and %d contracts expired.",Orders_ExpireAll(Orders_Today() + ORDERS_LIFE_DAYS + 1),Contracts_ExpireAll(gettime() + ORDERS_CONTRACT_DAYS * 86400 + 1)));
		return 1;
	}

	if (!strcmp(action,"clear",true))
	{
		new cleared = 0;

		for (new slot = 0;slot < ORDERS_MAX;slot++)
		{
			if (Orders_IsValid(slot) && Orders_GetTaker(slot) == 0)
			{
				Orders_Remove(slot);
				cleared++;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d untaken errands cleared.",cleared));
		return 1;
	}

	if (!IsPlayerConnected(value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"That player isn't here.");
		return 1;
	}

	if (!strcmp(action,"goodwill",true))
	{
		new index = Actors_FindNear(playerid);

		if (index == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Stand by a giver.");
			return 1;
		}

		new key[ACTORS_KEY_LEN];
		Actors_GetKey(index,key);
		Orders_SetGoodwillByKey(value,key,extra);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Goodwill with %s set to %d.",key,Orders_GetGoodwillByKey(value,key)));
		return 1;
	}

	if (!strcmp(action,"daily",true))
	{
		Orders_SetDaily(value,Orders_Today(),0);
		SendClientMessage(playerid,0xFFFFFFFF,"Today's deliveries reset.");
		return 1;
	}

	if (!strcmp(action,"duties",true))
	{
		for (new duty = 0;duty < Orders_DutyCount();duty++)
		{
			new text[72];
			Orders_DutyText(duty,text);
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d %s: state %d, open %d, owed %d",duty,text,Orders_GetDutyState(value,duty),Orders_IsDutyOpen(duty),Orders_IsDutyOwed(value,duty)));
		}

		return 1;
	}

	if (!strcmp(action,"warrant",true))
	{
		Orders_SetTrial(value,extra,ORDERS_TRIAL_NEEDED);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Trial in trade %d filled; asking now: %s.",extra,g_OrderResultTexts[Orders_CanAskWarrant(value,extra)]));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Unknown /orders action.");
	return 1;
}
