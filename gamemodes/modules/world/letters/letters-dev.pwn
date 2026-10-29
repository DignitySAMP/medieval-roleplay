CMD<ADMIN_LEVEL_TRIAL>:letter(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12];

	if (sscanf(params,"s[12]",action))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/letter kit | write | deliver");
		return 1;
	}

	if (!strcmp(action,"kit",true))
	{
		Inventory_Give(playerid,Item_GetDefKind(ITEM_PARCHMENT),ITEM_PARCHMENT,3);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_INK),ITEM_INK,1);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_QUILL),ITEM_QUILL,1);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_SEAL_RING),ITEM_SEAL_RING,1);
		Inventory_Give(playerid,Item_GetDefKind(ITEM_WAX),ITEM_WAX,2);
		SendClientMessage(playerid,0xFFFFFFFF,"Parchment, ink, a quill, a signet ring and wax are in your bag.");
	}
	else if (!strcmp(action,"write",true))
	{
		SetTimerEx("Letters_WriteDeferred",0,false,"d",playerid);
	}
	else if (!strcmp(action,"deliver",true))
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE couriers SET due_at = %d WHERE state = %d",gettime(),COURIER_STATE_ON_THE_ROAD));
		SendClientMessage(playerid,0xFFFFFFFF,"Every letter on the road arrives at the next courier round (within 30 seconds).");
	}

	return 1;
}
