CMD<ADMIN_LEVEL_ADMIN>:fire(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], which[16], value;

	if (sscanf(params,"s[12]S(near)[16]I(0)",action,which,value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/fire list | start|out|gut|rebuild|paid <key or near> | heat <key or near> <0-100>");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d buildings can burn: %d burning, %d gutted. Growth now %d a tick.",FIRE_SEED_BUILDINGS,Fire_CountBurning(),Fire_CountGutted(),Fire_GetGrowth()));

		for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
		{
			if (Fire_GetState(building) != FIRE_STATE_SOUND)
			{
				new name[28];
				Fire_GetName(building,name);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s (%s): %s, heat %d, from %s",name,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],g_FireStateNames[Fire_GetState(building)],Fire_GetHeat(building),Fire_GetCause(building) >= 0 && Fire_GetCause(building) < FIRE_CAUSE_COUNT ? g_FireCauseNames[Fire_GetCause(building)] : ("nothing")));
			}
		}

		return 1;
	}

	new building = !strcmp(which,"near",true) ? Fire_FindNearPlayer(playerid,20.0) : Fire_FindByKey(which);

	if (building == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No building there: stand by one or give its key (/fire list).");
		return 1;
	}

	new name[28];
	Fire_GetName(building,name);

	if (!strcmp(action,"start",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Fire_Start(building,FIRE_CAUSE_STAFF) ? sprintf("%s is alight.",name) : ("It's burning or burnt already."));
	}
	else if (!strcmp(action,"out",true))
	{
		Fire_PutOut(building);
		SendClientMessage(playerid,0xFFFFFFFF,"Put out.");
	}
	else if (!strcmp(action,"gut",true))
	{
		Fire_Gut(building);
		SendClientMessage(playerid,0xFFFFFFFF,"Gutted.");
	}
	else if (!strcmp(action,"rebuild",true))
	{
		Fire_Rebuild(building);
		SendClientMessage(playerid,0xFFFFFFFF,"Rebuilt.");
	}
	else if (!strcmp(action,"paid",true))
	{
		Fire_SetRebuildPaid(building);
		SendClientMessage(playerid,0xFFFFFFFF,"Paid for: rebuilt at dawn.");
	}
	else if (!strcmp(action,"heat",true))
	{
		Fire_SetHeat(building,value);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Heat %d.",Fire_GetHeat(building)));
	}
	else
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Unknown: /fire for the list.");
	}

	return 1;
}
