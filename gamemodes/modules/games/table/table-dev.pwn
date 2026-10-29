static Table_DevPlaceRegular(playerid,const name[],style)
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:angle, Float:spotX, Float:spotY, Float:spotZ, Float:hitX, Float:hitY, Float:hitZ;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,angle);
	spotX = x + TABLE_REGULAR_SPOT_AHEAD * floatsin(-angle,degrees);
	spotY = y + TABLE_REGULAR_SPOT_AHEAD * floatcos(-angle,degrees);
	spotZ = CA_RayCastLine(spotX,spotY,z + 0.5,spotX,spotY,z - TABLE_GROUND_PROBE,hitX,hitY,hitZ) ? hitZ : z - TABLE_GROUND_DROP;

	new regular = await Table_CreateRegular(name,Skins_GetStarter(0,random(max(1,Skins_CountStarter(0)))),style,x,y,z,angle,spotX,spotY,spotZ,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	if (regular == TABLE_EMPTY)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"The regular couldn't be saved. The list may be full.");
		return;
	}

	SetPlayerPos(playerid,x + 1.2 * floatsin(-(angle + 90.0),degrees),y + 1.2 * floatcos(-(angle + 90.0),degrees),z);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Placed %s here. Style: %s, %d pfennig a day.",name,g_TableStyleNames[style],g_TableStylePurses[style]));
}

CMD<ADMIN_LEVEL_TRIAL>:regular(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], styleName[12], name[TABLE_REGULAR_NAME_LEN];

	if (sscanf(params,"s[12]S()[12]S()[24]",action,styleName,name))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /regular place <careful|even|bold> <name>, /regular remove, /regular list");
		return 1;
	}

	if (!strcmp(action,"place",true))
	{
		new style = -1;

		for (new i = 0;i < TABLE_STYLE_COUNT;i++)
		{
			if (!strcmp(styleName,g_TableStyleNames[i],true))
			{
				style = i;
			}
		}

		if (style == -1 || name[0] == EOS)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /regular place <careful|even|bold> <name>. Stand on the seat, facing the table.");
			return 1;
		}

		Table_DevPlaceRegular(playerid,name,style);
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		new regular = Table_FindRegularNear(playerid,3.0), who[TABLE_REGULAR_NAME_LEN];

		if (regular == TABLE_EMPTY)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"There's no regular within 3 m of you.");
			return 1;
		}

		if (Table_GetRegularTable(regular) != TABLE_EMPTY)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"That regular is in a game. Wait until it ends.");
			return 1;
		}

		Table_GetRegularName(regular,who);
		Table_RemoveRegular(regular);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s was removed.",who));
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new count = 0, who[TABLE_REGULAR_NAME_LEN];

		for (new i = 0;i < TABLE_REGULARS_MAX;i++)
		{
			if (Table_IsValidRegular(i))
			{
				Table_GetRegularName(i,who);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %s, %d pfennig left today, %s.",who,g_TableStyleNames[Table_GetRegularStyle(i)],Table_GetRegularPurse(i),Table_GetRegularTable(i) == TABLE_EMPTY ? ("free") : ("in a game")));
				count++;
			}
		}

		if (count == 0)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No regulars are placed yet.");
		}

		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /regular place <careful|even|bold> <name>, /regular remove, /regular list");
	return 1;
}
