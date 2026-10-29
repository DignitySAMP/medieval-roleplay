enum
{
	CART_PICK_OPEN,
	CART_PICK_PUSH,
	CART_PICK_LET_GO,
	CART_PICK_LOCK,
	CART_PICK_UNLOCK,
	CART_PICK_PACK,
	CART_PICK_CLIMB_IN,
	CART_PICK_CLIMB_DOWN,
	CART_PICK_STAMP,
	CART_PICK_PRISONER_IN,
	CART_PICK_PRISONERS_OUT,
	CART_PICK_BREAK_OUT,
	CART_PICK_HIRE,
}

static s_CartPrompt[MAX_PLAYERS] = {-1, ...};
static s_CartInfobox[MAX_PLAYERS];

static Carts_ClearPrompt(playerid)
{
	if (s_CartInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_CartInfobox[playerid]);
	}

	s_CartPrompt[playerid] = -1;
	s_CartInfobox[playerid] = 0;
}

static Carts_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		Carts_ClearPrompt(playerid);
		return;
	}

	new cart = -1, text[96], title[32];

	if (Carts_GetSeat(playerid) != -1 && Carts_IsService(Carts_GetSeat(playerid)))
	{
		Carts_ClearPrompt(playerid);
		return;
	}

	if (Carts_GetSeat(playerid) != -1)
	{
		cart = Carts_GetSeat(playerid);

		if (Carts_IsPrisonerSeated(playerid))
		{
			strcopy(text,"You're barred in.");
		}
		else
		{
			strcopy(text,"Press ~y~Y~w~ for the cart or ~y~F~w~ to climb down.");
		}
	}
	else if (Mount_IsRiding(playerid))
	{
		if (Carts_GetOfPlayer(playerid) == -1)
		{
			for (new c = 0;c < CARTS_MAX;c++)
			{
				if (!Carts_IsValid(c) || !g_CartDefs[Carts_GetKind(c)][E_CART_DEF_HITCHED])
				{
					continue;
				}

				new Float:sx, Float:sy, Float:x, Float:y, Float:z, Float:a;
				Carts_ShaftPoint(c,sx,sy);
				Carts_GetPos(c,x,y,z,a);

				if (IsPlayerInRangeOfPoint(playerid,CARTS_SHAFT_REACH,sx,sy,z + 1.5))
				{
					cart = c;
					strcopy(text,Carts_IsService(c) || Carts_IsDriven(c) || Carts_GetMover(c) != INVALID_PLAYER_ID ? ("Press ~y~Y~w~ to check the hitch.") : ("Press ~y~Y~w~ to hitch your horse to it."));
					break;
				}
			}
		}
		else
		{
			cart = Carts_GetOfPlayer(playerid);
			strcopy(text,"Press ~y~Y~w~ to unhitch the cart.");
		}
	}
	else if (GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
	{
		cart = Carts_GetOfPlayer(playerid) != -1 ? Carts_GetOfPlayer(playerid) : Carts_FindNear(playerid);
		strcopy(text,"Press ~y~Y~w~ for the cart.");
	}

	if (cart == -1)
	{
		Carts_ClearPrompt(playerid);
		return;
	}

	if (cart == s_CartPrompt[playerid] && Infobox_IsShown(playerid,s_CartInfobox[playerid]))
	{
		return;
	}

	strcopy(title,g_CartDefs[Carts_GetKind(cart)][E_CART_DEF_NAME]);
	title[0] = toupper(title[0]);
	s_CartPrompt[playerid] = cart;
    s_CartInfobox[playerid] = Infobox_ShowPrompt(playerid,s_CartInfobox[playerid],title,text,3,true);
}

stock Carts_NearestBound(playerid)
{
	new best = INVALID_PLAYER_ID, Float:bestDistance = 4.0, Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new other : Player)
	{
		if (other == playerid || !Law_IsBound(other) || Carts_GetSeat(other) != -1)
		{
			continue;
		}

		new Float:distance = GetPlayerDistanceFromPoint(other,x,y,z);

		if (distance < bestDistance)
		{
			best = other;
			bestDistance = distance;
		}
	}

	return best;
}

forward Task:Carts_ReadStamp(playerid,cart);
#pragma warning push
#pragma warning disable 204
async Task:Carts_ReadStamp(playerid,cart)
{
	new owner = Carts_GetOwner(cart);

	if (owner == 0)
	{
		Gui_Notify(playerid,"It's branded with the county's mark: a cart of the guard.");
		wait_ticks(1);
		return async 1;
	}

	await mysql_aquery_s(g_Mysql,str_format("SELECT CONCAT(name, ' ', surname) AS n FROM characters WHERE id = %d",owner));
	new name[48] = "someone long gone";

	if (cache_num_rows() > 0)
	{
		cache_get_value_name(0,"n",name);
	}

	if (IsPlayerConnected(playerid))
	{
		Gui_Notify(playerid,sprintf("A stamp is burnt into the tailboard: %s.",name));
	}

	return async 1;
}
#pragma warning pop

stock Carts_OpenMenu(playerid,cart)
{
	if (!Carts_IsValid(cart))
	{
		return;
	}

	new E_CART_KIND:kind = Carts_GetKind(cart), bool:mine = Carts_MayHandle(playerid,cart), picks[10], labels[10][44], count = 0, title[24];
	new bool:seated = Carts_GetSeat(playerid) == cart, bool:prisonCart = g_CartSeatPrisoner[kind], bool:guard = Law_IsGuard(playerid);

	if (seated)
	{
		if (!prisonCart)
		{
			strcopy(labels[count],"Climb down");
			picks[count++] = CART_PICK_CLIMB_DOWN;
		}
	}
	else
	{
		if (g_CartDefs[kind][E_CART_DEF_SLOTS] > 4 || kind == CART_KIND_HANDCART || kind == CART_KIND_CART)
		{
			strcopy(labels[count],Carts_IsLocked(cart) && !mine ? ("Open the load (locked)") : ("Open the load"));
			picks[count++] = CART_PICK_OPEN;
		}

		if (!g_CartDefs[kind][E_CART_DEF_HITCHED])
		{
			if (Carts_GetOfPlayer(playerid) == cart)
			{
				strcopy(labels[count],"Let go of it");
				picks[count++] = CART_PICK_LET_GO;
			}
			else if (Carts_GetMover(cart) == INVALID_PLAYER_ID)
			{
				strcopy(labels[count],mine ? ("Pull it") : ("Pull it away (it isn't yours)"));
				picks[count++] = CART_PICK_PUSH;
			}
		}

		if (!prisonCart && Carts_FreeSeat(cart) != -1 && Carts_GetMover(cart) != playerid)
		{
			strcopy(labels[count],"Climb in");
			picks[count++] = CART_PICK_CLIMB_IN;
		}

		if (prisonCart)
		{
			if (guard && Carts_FreeSeat(cart) != -1 && Carts_NearestBound(playerid) != INVALID_PLAYER_ID)
			{
				strcopy(labels[count],"Put the bound prisoner in");
				picks[count++] = CART_PICK_PRISONER_IN;
			}

			if (Carts_CountSeated(cart) > 0)
			{
				if (guard)
				{
					strcopy(labels[count],"Let the prisoners out");
					picks[count++] = CART_PICK_PRISONERS_OUT;
				}
				else
				{
					strcopy(labels[count],"Break the prisoners out (a crime)");
					picks[count++] = CART_PICK_BREAK_OUT;
				}
			}
		}

		if (mine && Carts_GetOwner(cart) != 0)
		{
			strcopy(labels[count],Carts_IsLocked(cart) ? ("Unlock the load") : ("Lock the load"));
			picks[count++] = Carts_IsLocked(cart) ? CART_PICK_UNLOCK : CART_PICK_LOCK;

			if (g_CartDefs[kind][E_CART_DEF_ITEM] != -1)
			{
				strcopy(labels[count],"Take it apart (an empty cart)");
				picks[count++] = CART_PICK_PACK;
			}

			if ((kind == CART_KIND_COACH || kind == CART_KIND_WAGON) && Carts_GetMover(cart) == INVALID_PLAYER_ID)
			{
				strcopy(labels[count],"Hire a coachman to drive you");
				picks[count++] = CART_PICK_HIRE;
			}
		}
	}

	strcopy(labels[count],"Look at the owner's stamp");
	picks[count++] = CART_PICK_STAMP;

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	strcopy(title,g_CartDefs[kind][E_CART_DEF_NAME]);
	title[0] = toupper(title[0]);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,230.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i],picks[i] == CART_PICK_PACK || picks[i] == CART_PICK_BREAK_OUT ? KIT_COLOUR_BAD : KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || !Carts_IsValid(cart))
	{
		return;
	}

	switch (pick)
	{
		case CART_PICK_OPEN:
		{
			if (Carts_IsLocked(cart) && !mine)
			{
				Gui_Notify(playerid,"The load is locked.");
				return;
			}

			ContainerGui_Show(playerid,Carts_GetContainer(cart));
		}
		case CART_PICK_PUSH:
		{
			if (Carts_Push(playerid,cart))
			{
				Gui_Notify(playerid,"You take the handles and pull it behind you. Walk, don't run, or you let go.");
			}
		}
		case CART_PICK_LET_GO: Carts_Release(cart);
		case CART_PICK_LOCK:
		{
			Carts_SetLocked(cart,true);
			Gui_Notify(playerid,"You lock the load. Only you can open it now.");
		}
		case CART_PICK_UNLOCK:
		{
			Carts_SetLocked(cart,false);
			Gui_Notify(playerid,"You unlock the load.");
		}
		case CART_PICK_PACK:
		{
			if (Container_GetCount(Carts_GetContainer(cart)) > 0)
			{
				Gui_Notify(playerid,"Empty the load first.");
				return;
			}

			new item = g_CartDefs[kind][E_CART_DEF_ITEM];

			if (!Inventory_Give(playerid,Item_GetDefKind(item),item,1))
			{
				Gui_Notify(playerid,"There's no room in your bag for it.");
				return;
			}

			Carts_Remove(cart);
			Gui_Notify(playerid,"You take the cart apart and pack it up.");
		}
		case CART_PICK_CLIMB_IN:
		{
			if (Carts_Sit(playerid,cart,Carts_FreeSeat(cart)))
			{
				Gui_Notify(playerid,"You climb in. Press the mount key or Y to climb down.");
			}
			else
			{
				Gui_Notify(playerid,"There's no room for you.");
			}
		}
		case CART_PICK_CLIMB_DOWN: Carts_Stand(playerid);
		case CART_PICK_HIRE: pawn_call_public("Carts_OnHireCoachman","dd",playerid,cart);
		case CART_PICK_STAMP: Carts_ReadStamp(playerid,cart);
		case CART_PICK_PRISONER_IN:
		{
			new prisoner = Carts_NearestBound(playerid);

			if (prisoner == INVALID_PLAYER_ID || !Carts_Sit(prisoner,cart,Carts_FreeSeat(cart)))
			{
				Gui_Notify(playerid,"There's nobody bound beside you to put in.");
				return;
			}

			Gui_Notify(prisoner,"You're pushed into the prisoner cart and the door is barred behind you.");
			Gui_Notify(playerid,"You bar the prisoner in.");
		}
		case CART_PICK_PRISONERS_OUT, CART_PICK_BREAK_OUT:
		{
			for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
			{
				new prisoner = Carts_GetSeated(cart,seat);

				if (prisoner != INVALID_PLAYER_ID)
				{
					Carts_Stand(prisoner);
					Gui_Notify(prisoner,"The door of the prisoner cart swings open.");
				}
			}

			if (pick == CART_PICK_BREAK_OUT)
			{
				Law_Commit(playerid,LAW_CRIME_FREEING);
				Gui_Notify(playerid,"You wrench the bar off the door. The prisoners are out.");
			}
		}
	}
}

forward Task:Carts_PlaceFromBag(playerid,E_CART_KIND:kind);
#pragma warning push
#pragma warning disable 204
async Task:Carts_PlaceFromBag(playerid,E_CART_KIND:kind)
{
	new item = g_CartDefs[kind][E_CART_DEF_ITEM], Float:x, Float:y, Float:z, Float:a;

	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		Gui_Notify(playerid,"Set the cart down outside.");
		wait_ticks(1);
		return async -1;
	}

	if (!Inventory_Take(playerid,Item_GetDefKind(item),item,1))
	{
		wait_ticks(1);
		return async -1;
	}

	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x -= floatsin(a,degrees) * 2.2;
	y += floatcos(a,degrees) * 2.2;
	new cart = await Carts_Create(kind,Character_GetId(playerid),x,y,z - 1.0,a);

	if (cart == -1)
	{
		Inventory_Give(playerid,Item_GetDefKind(item),item,1);
		return async -1;
	}

	Gui_Notify(playerid,g_CartDefs[kind][E_CART_DEF_HITCHED] ? ("You set the cart down. Ride up to its shafts and press Y to hitch your horse.") : ("You set the handcart down. Press Y beside it to pull it or open its load."));
	return async cart;
}
#pragma warning pop

Timer_Declare(Carts_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Carts_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward Carts_OnHireCoachman(playerid,cart);

public Carts_OnHireCoachman(playerid,cart)
{
	return 1;
}

forward Carts_MenuDeferred(playerid,cart);

public Carts_MenuDeferred(playerid,cart)
{
	if (IsPlayerConnected(playerid))
	{
		Carts_OpenMenu(playerid,cart);
	}

	return 1;
}

forward Carts_PlaceDeferred(playerid,kind);

public Carts_PlaceDeferred(playerid,kind)
{
	if (IsPlayerConnected(playerid))
	{
		Carts_PlaceFromBag(playerid,E_CART_KIND:kind);
	}

	return 1;
}

forward bool:Carts_PromptContext(playerid);

public bool:Carts_PromptContext(playerid)
{
	return s_CartPrompt[playerid] != -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CartPrompt[playerid] = -1;
	s_CartInfobox[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_SECONDARY_ATTACK) && !(oldkeys & KEY_SECONDARY_ATTACK) && Carts_GetSeat(playerid) != -1)
	{
		if (Carts_IsPrisonerSeated(playerid))
		{
			Gui_Notify(playerid,"The door is barred from outside.");
		}
		else
		{
			Carts_Stand(playerid);
		}

		return;
	}

	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_CartPrompt[playerid] == -1 || Infobox_IsPromptBlocked(playerid,s_CartInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new cart = s_CartPrompt[playerid];
	Carts_ClearPrompt(playerid);

	if (Mount_IsRiding(playerid))
	{
		if (Carts_GetOfPlayer(playerid) == cart)
		{
			Carts_Release(cart);
			Gui_Notify(playerid,"You unhitch the cart.");
		}
		else if (Carts_Hitch(playerid,cart))
		{
			Gui_Notify(playerid,"You hitch your horse to the cart. Ride on; get down to leave it standing.");
		}

		return;
	}

	SetTimerEx("Carts_MenuDeferred",0,false,"dd",playerid,cart);
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, index

	for (new E_CART_KIND:k = CART_KIND_HANDCART;k < CART_KIND_COUNT;k++)
	{
		if (g_CartDefs[k][E_CART_DEF_ITEM] == param && E_ITEM_KIND:kind == Item_GetDefKind(param))
		{
			Inventory_CloseBagAfterUse(playerid);
			SetTimerEx("Carts_PlaceDeferred",0,false,"dd",playerid,_:k);
			return;
		}
	}
}

hook Container_OnChanged(containerid)
{
	for (new cart = 0;cart < CARTS_MAX;cart++)
	{
		if (Carts_IsValid(cart) && Carts_GetContainer(cart) == containerid)
		{
			Carts_RefreshLoad(cart);
			return;
		}
	}
}
