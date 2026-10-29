CMD<ADMIN_LEVEL_MANAGER>:realm(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[48];

	if (sscanf(params,"s[12]S()[48]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/realm duke|count|regent <player> (0 clears) | policy <key> <value> | dues <village 0-2> <coin> | info");
		return 1;
	}

	if (!strcmp(action,"duke",true) || !strcmp(action,"count",true) || !strcmp(action,"regent",true))
	{
		new target;

		if (sscanf(rest,"r",target))
		{
			Realm_SetOffice(!strcmp(action,"duke",true) ? 0 : (!strcmp(action,"count",true) ? 1 : 2),0);
			SendClientMessage(playerid,0xFFFFFFFF,"The office is empty.");
			return 1;
		}

		Realm_SetOffice(!strcmp(action,"duke",true) ? 0 : (!strcmp(action,"count",true) ? 1 : 2),Character_GetId(target));
		SendClientMessage(playerid,0xFFFFFFFF,"The office is filled.");
		return 1;
	}

	if (!strcmp(action,"policy",true))
	{
		new key[REALM_KEY_LEN], value;

		if (sscanf(rest,"s[32]i",key,value) || Realm_FindPolicy(key) == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"/realm policy <key> <value>");
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Set to %d (clamped to the duke's bounds).",Realm_SetPolicy(REALM_COUNTY,Realm_FindPolicy(key),value,Character_GetId(playerid))));
		return 1;
	}

	if (!strcmp(action,"dues",true))
	{
		new village, coin;

		if (!sscanf(rest,"ii",village,coin))
		{
			Realm_AddDues(REALM_COUNTY,village,coin);
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Dues: %d / %d / %d.",Realm_GetDues(0),Realm_GetDues(1),Realm_GetDues(2)));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Count %d, regent %d, duke %d, vacant %d, treasury %d pf, %d decrees, steward actor %d, %d tolls.",Realm_GetCount(),Realm_GetRegent(),Realm_GetDuke(),Realm_IsVacant(),Realm_TreasuryCoin(),Realm_CountDecrees(),Realm_GetSteward(),REALM_SEED_TOLLS));
	return 1;
}
