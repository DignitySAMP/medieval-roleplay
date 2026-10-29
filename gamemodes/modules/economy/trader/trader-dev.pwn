static Trader_DevPlace(playerid,const name[])
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:angle;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,angle);

	new trader = await Trader_Create(name,Skins_GetStarter(0,random(max(1,Skins_CountStarter(0)))),x,y,z,angle,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid));

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	if (trader == -1)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"The trader couldn't be saved. The list may be full.");
		return;
	}

	SetPlayerPos(playerid,x + 1.2 * floatsin(-(angle + 90.0),degrees),y + 1.2 * floatcos(-(angle + 90.0),degrees),z);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Placed %s here, with %d pfennig to buy with each day.",name,TRADER_PURSE_DAILY));
}

CMD<ADMIN_LEVEL_TRIAL>:trader(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], name[TRADER_NAME_LEN];

	if (sscanf(params,"s[12]S()[24]",action,name))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /trader place <name>, /trader remove, /trader list");
		return 1;
	}

	if (!strcmp(action,"place",true))
	{
		if (name[0] == EOS)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /trader place <name>. Stand where the trader should stand, facing out.");
			return 1;
		}

		Trader_DevPlace(playerid,name);
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		new trader = Trader_FindNear(playerid,3.0), who[TRADER_NAME_LEN];

		if (trader == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"There's no trader within 3 m of you.");
			return 1;
		}

		Trader_GetName(trader,who);
		Trader_Remove(trader);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s was removed.",who));
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new count = 0, who[TRADER_NAME_LEN];

		for (new i = 0;i < TRADER_MAX;i++)
		{
			if (Trader_IsValid(i))
			{
				Trader_GetName(i,who);
				SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s: %d pfennig left today.",who,Trader_GetPurse(i)));
				count++;
			}
		}

		if (count == 0)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No traders are placed yet.");
		}

		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /trader place <name>, /trader remove, /trader list");
	return 1;
}
