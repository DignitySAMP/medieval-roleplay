static s_TradePartner[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static s_TradePartnerToken[MAX_PLAYERS];
static s_TradeAsked[MAX_PLAYERS] = {INVALID_PLAYER_ID, ...};
static s_TradeAskedUntil[MAX_PLAYERS];
static s_TradeOffers[MAX_PLAYERS][TRADE_OFFERS][E_TRADE_OFFER];
static s_TradeOfferCount[MAX_PLAYERS];
static s_TradeCoin[MAX_PLAYERS];
static bool:s_TradeAccepted[MAX_PLAYERS];
static bool:s_TradeSwapping;

stock bool:Trade_IsTrading(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TradePartner[playerid] != INVALID_PLAYER_ID;
}

stock Trade_GetPartner(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TradePartner[playerid] : INVALID_PLAYER_ID;
}

stock Trade_GetOfferCount(playerid)
{
	return s_TradeOfferCount[playerid];
}

stock Trade_GetOffer(playerid,index,&E_ITEM_KIND:kind,&param,&stars,&amount)
{
	kind = s_TradeOffers[playerid][index][E_TRADE_OFFER_KIND];
	param = s_TradeOffers[playerid][index][E_TRADE_OFFER_PARAM];
	stars = s_TradeOffers[playerid][index][E_TRADE_OFFER_STARS];
	amount = s_TradeOffers[playerid][index][E_TRADE_OFFER_AMOUNT];
}

stock Trade_GetCoin(playerid)
{
	return s_TradeCoin[playerid];
}

stock bool:Trade_HasAccepted(playerid)
{
	return s_TradeAccepted[playerid];
}

stock Trade_FindFacing(playerid)
{
	new Float:distance, other = Util_GetClosestPlayer(playerid,TRADE_RANGE,distance);

	if (other == INVALID_PLAYER_ID || IsPlayerNPC(other) || !Session_IsPlaying(other) || !Combat_IsFacing(playerid,other,TRADE_FACING_CONE))
	{
		return INVALID_PLAYER_ID;
	}

	return other;
}

stock bool:Trade_IsNear(playerid,otherid)
{
	if (!Util_IsValidPlayer(playerid) || !Util_IsValidPlayer(otherid) || playerid == otherid || IsPlayerNPC(otherid) || !Session_IsPlaying(otherid) || GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(otherid))
	{
		return false;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return IsPlayerInRangeOfPoint(otherid,TRADE_RANGE,x,y,z);
}

stock Trade_GetNearby(playerid,ids[],max = sizeof(ids))
{
	new count = 0;

	foreach (new other : Player)
	{
		if (count < max && Trade_IsNear(playerid,other))
		{
			ids[count++] = other;
		}
	}

	return count;
}

static Trade_ClearSide(playerid)
{
	s_TradePartner[playerid] = INVALID_PLAYER_ID;
	s_TradePartnerToken[playerid] = 0;
	s_TradeOfferCount[playerid] = 0;
	s_TradeCoin[playerid] = 0;
	s_TradeAccepted[playerid] = false;
}

static Trade_Changed(playerid)
{
	new partner = s_TradePartner[playerid];
	s_TradeAccepted[playerid] = false;

	if (partner != INVALID_PLAYER_ID)
	{
		s_TradeAccepted[partner] = false;
		SetTimerEx("Trade_RefreshDeferred",0,false,"dd",partner,Account_GetToken(partner));
	}

	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

stock Trade_Cancel(playerid,const reason[] = "")
{
	new partner = s_TradePartner[playerid];

	if (partner == INVALID_PLAYER_ID)
	{
		return;
	}

	Trade_ClearSide(playerid);

	if (Util_IsValidPlayer(partner) && s_TradePartner[partner] == playerid)
	{
		Trade_ClearSide(partner);
		SetTimerEx("Trade_RefreshDeferred",0,false,"dd",partner,Account_GetToken(partner));

		if (reason[0] != EOS)
		{
			Gui_Notify(partner,reason);
		}
	}

	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

stock bool:Trade_Begin(playerid,partner)
{
	if (Trade_IsTrading(playerid) || Trade_IsTrading(partner) || !Session_IsPlaying(playerid) || !Session_IsPlaying(partner))
	{
		return false;
	}

	Trade_ClearSide(playerid);
	Trade_ClearSide(partner);
	s_TradePartner[playerid] = partner;
	s_TradePartner[partner] = playerid;
	s_TradePartnerToken[playerid] = Account_GetToken(partner);
	s_TradePartnerToken[partner] = Account_GetToken(playerid);
	SetTimerEx("Trade_OpenDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	SetTimerEx("Trade_OpenDeferred",0,false,"dd",partner,Account_GetToken(partner));
	return true;
}

static Trade_Offered(playerid,E_ITEM_KIND:kind,param,stars)
{
	for (new i = 0;i < s_TradeOfferCount[playerid];i++)
	{
		if (s_TradeOffers[playerid][i][E_TRADE_OFFER_KIND] == kind && s_TradeOffers[playerid][i][E_TRADE_OFFER_PARAM] == param && s_TradeOffers[playerid][i][E_TRADE_OFFER_STARS] == stars)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Trade_AddFromSlot(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Trade_IsTrading(playerid) || !Inventory_GetSlot(playerid,index,kind,param,amount) || kind == ITEM_KIND_COIN || amount <= 0)
	{
		return false;
	}

	new stars = Inventory_GetSlotStars(playerid,index), entry = Trade_Offered(playerid,kind,param,stars);

	if (entry == -1)
	{
		if (s_TradeOfferCount[playerid] >= TRADE_OFFERS)
		{
			return false;
		}

		entry = s_TradeOfferCount[playerid]++;
		s_TradeOffers[playerid][entry][E_TRADE_OFFER_KIND] = kind;
		s_TradeOffers[playerid][entry][E_TRADE_OFFER_PARAM] = param;
		s_TradeOffers[playerid][entry][E_TRADE_OFFER_STARS] = stars;
		s_TradeOffers[playerid][entry][E_TRADE_OFFER_AMOUNT] = 0;
	}

	if (s_TradeOffers[playerid][entry][E_TRADE_OFFER_AMOUNT] >= Inventory_Count(playerid,kind,param,stars))
	{
		return false;
	}

	s_TradeOffers[playerid][entry][E_TRADE_OFFER_AMOUNT]++;
	Trade_Changed(playerid);
	return true;
}

stock bool:Trade_RemoveOffer(playerid,entry)
{
	if (!Trade_IsTrading(playerid) || entry < 0 || entry >= s_TradeOfferCount[playerid])
	{
		return false;
	}

	if (--s_TradeOffers[playerid][entry][E_TRADE_OFFER_AMOUNT] <= 0)
	{
		for (new i = entry;i < s_TradeOfferCount[playerid] - 1;i++)
		{
			s_TradeOffers[playerid][i] = s_TradeOffers[playerid][i + 1];
		}

		s_TradeOfferCount[playerid]--;
	}

	Trade_Changed(playerid);
	return true;
}

stock bool:Trade_SetCoin(playerid,pfennig)
{
	if (!Trade_IsTrading(playerid))
	{
		return false;
	}

	s_TradeCoin[playerid] = Util_ClampInt(pfennig,0,Economy_Worth(playerid));
	Trade_Changed(playerid);
	return true;
}

static bool:Trade_SideHolds(playerid)
{
	if (Economy_Worth(playerid) < s_TradeCoin[playerid])
	{
		return false;
	}

	for (new i = 0;i < s_TradeOfferCount[playerid];i++)
	{
		if (Inventory_Count(playerid,s_TradeOffers[playerid][i][E_TRADE_OFFER_KIND],s_TradeOffers[playerid][i][E_TRADE_OFFER_PARAM],s_TradeOffers[playerid][i][E_TRADE_OFFER_STARS]) < s_TradeOffers[playerid][i][E_TRADE_OFFER_AMOUNT])
		{
			return false;
		}
	}

	return true;
}

static Trade_Hand(from,to)
{
	new characterid = Character_GetId(to);

	for (new i = 0;i < s_TradeOfferCount[from];i++)
	{
		new E_ITEM_KIND:kind = s_TradeOffers[from][i][E_TRADE_OFFER_KIND], param = s_TradeOffers[from][i][E_TRADE_OFFER_PARAM], stars = s_TradeOffers[from][i][E_TRADE_OFFER_STARS], amount = s_TradeOffers[from][i][E_TRADE_OFFER_AMOUNT];
		new freshAt = Inventory_OldestFresh(from,kind,param,stars), wear = Inventory_GetSlotWear(from,Inventory_Find(from,kind,param,stars)), data = Inventory_GetSlotData(from,Inventory_Find(from,kind,param,stars));

		if (!Inventory_Take(from,kind,param,amount,stars))
		{
			continue;
		}

		if (freshAt <= 0)
		{
			freshAt = ITEM_FRESH_NOW;
		}

		new each = Item_Stacks(kind,param) ? amount : 1;

		for (new given = 0;given < amount;given += each)
		{
			if (!Inventory_Give(to,kind,param,each,stars,freshAt,wear,data))
			{
				Claims_Give(characterid,kind,param,each,stars,"trade",freshAt,wear,data);
			}
		}
	}

	if (s_TradeCoin[from] > 0 && Economy_Pay(from,s_TradeCoin[from],INVALID_CONTAINER_ID,"trade") == PAY_OK)
	{
		Economy_GiveOrClaim(to,characterid,s_TradeCoin[from],"trade");
	}
}

static Trade_Execute(playerid)
{
	new partner = s_TradePartner[playerid];

	if (!Trade_SideHolds(playerid) || !Trade_SideHolds(partner))
	{
		Gui_Notify(playerid,"Something in the trade isn't in a bag any more. Check it again and accept.");
		Gui_Notify(partner,"Something in the trade isn't in a bag any more. Check it again and accept.");
		Trade_Changed(playerid);
		return;
	}

	s_TradeSwapping = true;
	Trade_Hand(playerid,partner);
	Trade_Hand(partner,playerid);
	s_TradeSwapping = false;
	Trade_ClearSide(playerid);
	Trade_ClearSide(partner);
	Gui_Notify(playerid,"The trade is done.");
	Gui_Notify(partner,"The trade is done.");
	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",partner,Account_GetToken(partner));
}

stock Trade_Accept(playerid)
{
	new partner = s_TradePartner[playerid];

	if (partner == INVALID_PLAYER_ID)
	{
		return;
	}

	s_TradeAccepted[playerid] = !s_TradeAccepted[playerid];

	if (s_TradeAccepted[playerid] && s_TradeAccepted[partner])
	{
		Trade_Execute(playerid);
		return;
	}

	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",partner,Account_GetToken(partner));
	SetTimerEx("Trade_RefreshDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

stock bool:Trade_Ask(playerid,targetid,dest[],size = sizeof(dest))
{
	new name[MAX_PLAYER_NAME * 2];
	dest[0] = EOS;
	Nametag_GetKnownName(playerid,targetid,name,sizeof(name));

	if (Trade_IsTrading(playerid) || Trade_IsTrading(targetid))
	{
		format(dest,size,"%s is already trading.",name);
		return false;
	}

	if (Gui_IsBusy(targetid) || Character_IsBusy(targetid))
	{
		format(dest,size,"%s is busy right now. Ask again in a moment.",name);
		return false;
	}

	s_TradeAsked[targetid] = playerid;
	s_TradeAskedUntil[targetid] = gettime() + TRADE_ASK_SECONDS;
	SetTimerEx("Trade_AskDeferred",0,false,"ddd",targetid,Account_GetToken(targetid),playerid);
	format(dest,size,"You asked %s to trade.",name);
	return true;
}

forward Trade_Tick();

public Trade_Tick()
{
	foreach (new playerid : Player)
	{
		new partner = s_TradePartner[playerid];

		if (partner == INVALID_PLAYER_ID || playerid > partner)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(partner,x,y,z);

		if (!IsPlayerConnected(partner) || Account_GetToken(partner) != s_TradePartnerToken[playerid] || GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(partner) || GetPlayerDistanceFromPoint(playerid,x,y,z) > TRADE_KEEP_RANGE)
		{
			Gui_Notify(playerid,"You're too far apart. The trade is off.");
			Trade_Cancel(playerid,"You're too far apart. The trade is off.");
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Trade_ClearSide(playerid);
	s_TradeAsked[playerid] = INVALID_PLAYER_ID;
	s_TradeAskedUntil[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Trade_Cancel(playerid,"The other side left. The trade is off.");
}

hook Character_OnUnloaded(playerid)
{
	Trade_Cancel(playerid,"The other side left. The trade is off.");
}

hook Inventory_OnChanged(playerid)
{
	if (s_TradeSwapping || !Trade_IsTrading(playerid))
	{
		return;
	}

	for (new i = s_TradeOfferCount[playerid] - 1;i >= 0;i--)
	{
		new have = Inventory_Count(playerid,s_TradeOffers[playerid][i][E_TRADE_OFFER_KIND],s_TradeOffers[playerid][i][E_TRADE_OFFER_PARAM],s_TradeOffers[playerid][i][E_TRADE_OFFER_STARS]);

		if (s_TradeOffers[playerid][i][E_TRADE_OFFER_AMOUNT] > have)
		{
			s_TradeOffers[playerid][i][E_TRADE_OFFER_AMOUNT] = have;
		}

		if (s_TradeOffers[playerid][i][E_TRADE_OFFER_AMOUNT] <= 0)
		{
			for (new j = i;j < s_TradeOfferCount[playerid] - 1;j++)
			{
				s_TradeOffers[playerid][j] = s_TradeOffers[playerid][j + 1];
			}

			s_TradeOfferCount[playerid]--;
		}
	}

	if (s_TradeCoin[playerid] > Economy_Worth(playerid))
	{
		s_TradeCoin[playerid] = Economy_Worth(playerid);
	}

	Trade_Changed(playerid);
}
