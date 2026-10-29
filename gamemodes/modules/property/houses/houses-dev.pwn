CMD<ADMIN_LEVEL_TRIAL>:house(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], arg[24], value[12];

	if (sscanf(params,"s[12]S()[24]S()[12]",action,arg,value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /house list, rooms, info <key>, go <key>, enter <key>, fire <key> on|off|auto, grant <room no.>, vacate <room no.>, kit");
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new line[144];
		line[0] = EOS;

		for (new house = 0;house < HOUSE_SEED_COUNT;house++)
		{
			new part[24];
			format(part,sizeof(part),"%s ",g_HouseDefs[house][E_HOUSE_DEF_KEY]);

			if (strlen(line) + strlen(part) >= sizeof(line))
			{
				SendClientMessage(playerid,0xFFFFFFFF,line);
				line[0] = EOS;
			}

			strcat(line,part);
		}

		SendClientMessage(playerid,0xFFFFFFFF,line);
		return 1;
	}

	if (!strcmp(action,"rooms",true))
	{
		for (new room = 0;room < HOUSE_SEED_ROOMS;room++)
		{
			if (g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_RENTABLE])
			{
				new name[64];
				Houses_FormatRoomName(room,name);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d: %s, %d pfennig, %s",room,name,Houses_RoomRent(room),Houses_IsRoomHeld(room) ? sprintf("held by character %d",Houses_GetRoomHolder(room)) : ("free")));
			}
		}

		return 1;
	}

	if (!strcmp(action,"kit",true))
	{
		Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE,3);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_CHAIR),ITEM_CHAIR,1);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_CHEST),ITEM_CHEST,1);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_BARREL),ITEM_BARREL,1);
		Economy_Give(playerid,200,"staff");
		SendClientMessage(playerid,0xFFFFFFFF,"You have 3 candles, a chair, a chest, a barrel and 200 pfennig.");
		return 1;
	}

	if (!strcmp(action,"grant",true) || !strcmp(action,"vacate",true))
	{
		new room = strval(arg);

		if (room < 0 || room >= HOUSE_SEED_ROOMS || !g_HouseRoomDefs[room][E_HOUSE_ROOM_DEF_RENTABLE])
		{
			SendClientMessage(playerid,0xFFFFFFFF,"That's not a room to let. /house rooms lists them.");
			return 1;
		}

		if (!strcmp(action,"vacate",true))
		{
			Houses_Vacate(room,"staff");
			SendClientMessage(playerid,0xFFFFFFFF,"The room is free again; its chest went to the holder's claims.");
			return 1;
		}

		Economy_Give(playerid,Houses_RoomRent(room),"staff");
		Houses_TakeRoom(playerid,room);
		return 1;
	}

	new house = Houses_FindByKey(arg);

	if (house == -1)
	{
		house = Houses_GetInside(playerid);
	}

	if (house == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"No such house. /house list shows the keys.");
		return 1;
	}

	if (!strcmp(action,"info",true))
	{
		new seats = 0;

		for (new i = g_HouseDefs[house][E_HOUSE_DEF_FIRST][2], last = i + g_HouseDefs[house][E_HOUSE_DEF_COUNT][2];i < last;i++)
		{
			if (g_HouseSeatDefs[i][E_HOUSE_POSE_DEF_HOUSE] == house)
			{
				seats++;
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %s. %d room(s), %d bed(s), %d seat(s), %d spot(s), %d chest(s), %d candle slot(s). Hearth %s.",g_HouseDefs[house][E_HOUSE_DEF_KEY],g_HouseDefs[house][E_HOUSE_DEF_HOUSEHOLD],g_HouseDefs[house][E_HOUSE_DEF_COUNT][0],g_HouseDefs[house][E_HOUSE_DEF_COUNT][1],seats,g_HouseDefs[house][E_HOUSE_DEF_COUNT][3],g_HouseDefs[house][E_HOUSE_DEF_COUNT][4],g_HouseDefs[house][E_HOUSE_DEF_COUNT][5],Houses_IsFireLit(house) ? ("lit") : ("cold")));
		return 1;
	}

	if (!strcmp(action,"go",true))
	{
		Util_SafeTeleport(playerid,g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2] + 1.0,g_HouseDefs[house][E_HOUSE_DEF_DOOR][3],0,0);
		return 1;
	}

	if (!strcmp(action,"enter",true))
	{
		Houses_Enter(playerid,house);
		return 1;
	}

	if (!strcmp(action,"fire",true))
	{
		Houses_SetFireForced(house,!strcmp(value,"on",true) ? 1 : (!strcmp(value,"off",true) ? 0 : -1));
		SendClientMessage(playerid,0xFFFFFFFF,Houses_IsFireLit(house) ? ("The hearth burns.") : ("The hearth is cold."));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /house list, rooms, info <key>, go <key>, enter <key>, fire <key> on|off|auto, grant <room no.>, vacate <room no.>, kit");
	return 1;
}
