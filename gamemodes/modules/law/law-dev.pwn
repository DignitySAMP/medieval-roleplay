static Law_DevDevice(playerid,kind)
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:a, Float:groundZ;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += 1.6 * floatsin(-a,degrees);
	y += 1.6 * floatcos(-a,degrees);

	if (!Placement_FindSurface(x,y,z + 0.5,3.0,groundZ))
	{
		groundZ = z - 1.0;
	}

	new device = await Pillory_Create(kind,x,y,groundZ,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (IsPlayerConnected(playerid))
	{
		SendClientMessage(playerid,0xFFFFFFFF,device == -1 ? ("It couldn't be saved.") : ("Placed 1.6 m ahead, the crowd side facing you."));
	}
}

static Law_DevFindKind(const name[])
{
	for (new i = 0;i < LAW_CRIME_COUNT;i++)
	{
		if (strfind(g_LawCrimeDefs[i][E_LAW_CRIME_DEF_NAME],name,true) == 0)
		{
			return i;
		}
	}

	return -1;
}

static Law_DevFindSentence(const name[])
{
	for (new i = 1;i < LAW_SENTENCE_COUNT;i++)
	{
		if (strfind(g_LawSentenceNames[i],name,true) == 0)
		{
			return i;
		}
	}

	return -1;
}

CMD<ADMIN_LEVEL_TRIAL>:law(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], target = INVALID_PLAYER_ID, word[24], value;

	if (sscanf(params,"s[12]U(-1)S()[24]D(0)",action,target,word,value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /law appoint|duty|crime|wanted|clear|sentence|release|bind|untie|kit|pillory|stocks|removedevice|gaol|status");
		return 1;
	}

	if (!strcmp(action,"pillory",true) || !strcmp(action,"stocks",true))
	{
		Law_DevDevice(playerid,!strcmp(action,"stocks",true) ? LAW_DEVICE_STOCKS : LAW_DEVICE_PILLORY);
		return 1;
	}

	if (!strcmp(action,"removedevice",true))
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		new device = Pillory_FindNear(x,y,z,GetPlayerVirtualWorld(playerid),4.0);

		if (device == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"There's no pillory or stocks within 4 m.");
			return 1;
		}

		Pillory_Remove(device);
		SendClientMessage(playerid,0xFFFFFFFF,"Removed.");
		return 1;
	}

	if (!strcmp(action,"gaol",true))
	{
		Gaol_Enter(playerid);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("The gaol: %d of %d cells free. Grates: %d%%, %d%%, %d%% loose.",Gaol_CountFree(),GAOL_CELLS,Gaol_GetProgress(0),Gaol_GetProgress(1),Gaol_GetProgress(2)));
		return 1;
	}

	if (!strcmp(action,"kit",true))
	{
		Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_ROPE,2);
		Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_ROTTEN_CABBAGE,5);
		Inventory_Give(playerid,ITEM_KIND_DRINK,ITEM_WATER_SKIN,1);
		SendClientMessage(playerid,0xFFFFFFFF,"You have 2 ropes, 5 rotten cabbages and a water skin.");
		return 1;
	}

	if (!strcmp(action,"status",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d guard(s) on duty, %d pillory/stocks, %d free cell(s).",Law_CountGuardsOnDuty(),Pillory_CountDevices(),Gaol_CountFree()));
		return 1;
	}

	if (target == -1)
	{
		target = playerid;
	}

	if (!IsPlayerConnected(target) || !Session_IsPlaying(target))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"That player isn't playing.");
		return 1;
	}

	if (!strcmp(action,"appoint",true))
	{
		new rank = LAW_RANK_NONE;

		for (new i = 0;i < LAW_RANK_COUNT;i++)
		{
			if (!strcmp(word,g_LawRankNames[i],true))
			{
				rank = i;
			}
		}

		Law_Appoint(target,rank,playerid);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Rank set to %s.",g_LawRankNames[rank]));
		return 1;
	}

	if (!strcmp(action,"duty",true))
	{
		if (Law_GetRank(target) == LAW_RANK_NONE)
		{
			Law_Appoint(target,LAW_RANK_SERGEANT,playerid);
		}

		Law_SetDuty(target,!Law_IsGuard(target));
		return 1;
	}

	if (!strcmp(action,"crime",true) || !strcmp(action,"wanted",true))
	{
		new kind = Law_DevFindKind(word);

		if (kind == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Crimes: murder, assault, theft, poaching, poisoning, breaking, trespass, freeing, bribery, escape, arson, going");
			return 1;
		}

		if (!strcmp(action,"crime",true))
		{
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("Logged: %d witness(es).",Law_Commit(target,kind)));
			return 1;
		}

		new description[LAW_DESCRIPTION_LEN];
		Law_Describe(target,description);
		Law_SetWanted(target,kind,description);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Wanted, bounty %d pfennig.",Law_GetBounty(target)));
		return 1;
	}

	if (!strcmp(action,"clear",true))
	{
		Law_ClearWanted(target);
		SendClientMessage(playerid,0xFFFFFFFF,"Struck from the roll.");
		return 1;
	}

	if (!strcmp(action,"sentence",true))
	{
		new kind = Law_DevFindSentence(word);

		if (kind == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Sentences: fine, pillory, stocks, gaol, flogging, branding, banishment, execution. /law sentence <player> <kind> <minutes or pfennig>");
			return 1;
		}

		SendClientMessage(playerid,0xFFFFFFFF,Law_Sentence(target,kind,max(value,1),max(value,1),playerid) ? ("Sentenced.") : ("It couldn't be carried out (already serving, or no free place)."));
		return 1;
	}

	if (!strcmp(action,"release",true))
	{
		Law_Release(target,"released by staff");
		SendClientMessage(playerid,0xFFFFFFFF,"Released.");
		return 1;
	}

	if (!strcmp(action,"bind",true))
	{
		Law_Bind(target,playerid);
		return 1;
	}

	if (!strcmp(action,"untie",true))
	{
		Law_Untie(target);
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /law appoint|duty|crime|wanted|clear|sentence|release|bind|untie|kit|pillory|stocks|removedevice|gaol|status");
	return 1;
}
