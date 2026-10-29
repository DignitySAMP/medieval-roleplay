CMD<ADMIN_LEVEL_TRIAL>:cart(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[24];

	if (sscanf(params,"s[12]S()[24]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/cart spawn [handcart|cart|wagon|coach|village|prisoner] | list | remove");
		return 1;
	}

	if (!strcmp(action,"spawn",true))
	{
		new E_CART_KIND:kind = CART_KIND_HANDCART;

		for (new E_CART_KIND:k = CART_KIND_HANDCART;k < CART_KIND_COUNT;k++)
		{
			if (strfind(g_CartDefs[k][E_CART_DEF_NAME],rest,true) != -1 && rest[0] != EOS)
			{
				kind = k;
				break;
			}
		}

		new Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		Carts_Create(kind,Character_GetId(playerid),x - floatsin(a,degrees) * 3.0,y + floatcos(a,degrees) * 3.0,z - 1.0,a);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("A %s stands in front of you.",g_CartDefs[kind][E_CART_DEF_NAME]));
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new count = 0, moving = 0;

		for (new cart = 0;cart < CARTS_MAX;cart++)
		{
			if (Carts_IsValid(cart))
			{
				count++;

				if (Carts_GetMover(cart) != INVALID_PLAYER_ID)
				{
					moving++;
				}
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Carts: %d in the world, %d moving.",count,moving));
		return 1;
	}

	if (!strcmp(action,"remove",true))
	{
		new cart = Carts_FindNear(playerid,6.0);

		if (cart == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"No cart near you.");
			return 1;
		}

		Carts_Remove(cart);
		SendClientMessage(playerid,0xFFFFFFFF,"The cart is gone (its load container stays in the database).");
	}

	return 1;
}
