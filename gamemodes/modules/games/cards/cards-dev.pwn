CMD<ADMIN_LEVEL_TRIAL>:cards(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12];

	if (sscanf(params,"s[12]",action) || strcmp(action,"give",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /cards give");
		return 1;
	}

	if (!Inventory_Give(playerid,CARDS_ITEM_KIND,ITEM_CARDS))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Your bag is full.");
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"You got a deck of cards.");
	return 1;
}
