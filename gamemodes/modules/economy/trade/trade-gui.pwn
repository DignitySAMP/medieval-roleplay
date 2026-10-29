static bool:Trade_IsPanelShown(playerid)
{
	new title[KIT_TITLE_LEN];

	if (!Kit_IsOpen(playerid))
	{
		return false;
	}

	Kit_GetTitle(playerid,title);
	return !strcmp(title,TRADE_TITLE);
}

static Float:Trade_TileHeight(Float:size)
{
	return KIT_UNITS_Y(KIT_PIXELS_X(size));
}

static Trade_AddItemTile(playerid,Float:x,Float:y,Float:size,E_ITEM_KIND:kind,param,amount,stars,value)
{
	new icon[ITEM_ICON_LEN];
	Item_GetIcon(kind,param,icon);
	Kit_AddTile(playerid,x,y,size,Item_GetModel(kind,param),amount,false,value,false,icon,stars > ITEM_STARS_MIN ? stars : 0);
}

static Trade_AddEmptyTile(playerid,Float:x,Float:y,Float:size)
{
	Kit_AddSprite(playerid,x,y,size,Trade_TileHeight(size),KIT_SPRITE_PLATE,KIT_COLOUR_PLATE_EMPTY);
}

static Trade_DrawOffers(playerid,owner,Float:x,Float:y,Float:width,bool:canRemove)
{
	new E_ITEM_KIND:kind, param, stars, amount, line[TRADE_LINE_LEN], Float:tile = (width - TRADE_TILE_GAP * float(TRADE_OFFER_COLUMNS - 1)) / float(TRADE_OFFER_COLUMNS), Float:tileHeight = Trade_TileHeight(tile), count = Trade_GetOfferCount(owner);

	for (new i = 0;i < TRADE_OFFERS;i++)
	{
		new Float:tileX = x + float(i % TRADE_OFFER_COLUMNS) * (tile + TRADE_TILE_GAP), Float:tileY = y + float(i / TRADE_OFFER_COLUMNS) * (tileHeight + TRADE_TILE_GAP);

		if (i >= count)
		{
			Trade_AddEmptyTile(playerid,tileX,tileY,tile);
			continue;
		}

		Trade_GetOffer(owner,i,kind,param,stars,amount);
		Trade_AddItemTile(playerid,tileX,tileY,tile,kind,param,amount,stars,canRemove ? TRADE_PICK_OFFER + i : KIT_NONE);
	}

	new Float:textY = y + float((TRADE_OFFERS + TRADE_OFFER_COLUMNS - 1) / TRADE_OFFER_COLUMNS) * (tileHeight + TRADE_TILE_GAP) + 2.0;
	format(line,sizeof(line),"Coin: %d pfennig",Trade_GetCoin(owner));
	Kit_AddText(playerid,x,textY,line,KIT_COLOUR_ACCENT,KIT_TEXT_ROW);
	Kit_AddText(playerid,x,textY + KIT_ROW,Trade_HasAccepted(owner) ? ("Accepted") : ("Not accepted yet"),Trade_HasAccepted(owner) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,KIT_TEXT_ROW);
}

static Trade_Draw(playerid)
{
	new partner = Trade_GetPartner(playerid), Float:x, Float:y, Float:width, name[MAX_PLAYER_NAME * 2], line[TRADE_LINE_LEN], E_ITEM_KIND:kind, param, amount, shown = 0;
	new Float:contentWidth = TRADE_WIDTH * (1.0 - KIT_BOX_INSET_X * 2.0), Float:half = (contentWidth - TRADE_COLUMN_GAP) / 2.0;
	new Float:bagTile = (contentWidth - TRADE_TILE_GAP * float(TRADE_BAG_COLUMNS - 1)) / float(TRADE_BAG_COLUMNS), Float:bagTileHeight = Trade_TileHeight(bagTile);
	new Float:offerTile = (half - TRADE_TILE_GAP * float(TRADE_OFFER_COLUMNS - 1)) / float(TRADE_OFFER_COLUMNS), Float:offerTileHeight = Trade_TileHeight(offerTile);
	new bagRows = (INVENTORY_SLOTS + TRADE_BAG_COLUMNS - 1) / TRADE_BAG_COLUMNS, offerRows = (TRADE_OFFERS + TRADE_OFFER_COLUMNS - 1) / TRADE_OFFER_COLUMNS;
	new Float:offersY = KIT_ROW + float(bagRows) * (bagTileHeight + TRADE_TILE_GAP) + 4.0 + KIT_ROW;
	new Float:buttonsY = offersY + float(offerRows) * (offerTileHeight + TRADE_TILE_GAP) + 2.0 + KIT_ROW * 2.0 + 4.0;

	Nametag_GetKnownName(playerid,partner,name,sizeof(name));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TRADE_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,TRADE_WIDTH,buttonsY + KIT_ROW + 4.0,TRADE_TITLE,x,y,width);

	Kit_AddText(playerid,x,y,"Your bag: click an item to give one",KIT_COLOUR_ACCENT,0.75);

	for (new i = 0;i < Inventory_GetCount(playerid);i++)
	{
		if (!Inventory_GetSlot(playerid,i,kind,param,amount) || kind == ITEM_KIND_COIN || amount <= 0)
		{
			continue;
		}

		Trade_AddItemTile(playerid,x + float(shown % TRADE_BAG_COLUMNS) * (bagTile + TRADE_TILE_GAP),y + KIT_ROW + float(shown / TRADE_BAG_COLUMNS) * (bagTileHeight + TRADE_TILE_GAP),bagTile,kind,param,amount,Inventory_GetSlotStars(playerid,i),TRADE_PICK_BAG + i);
		shown++;
	}

	for (new i = shown;i < INVENTORY_SLOTS;i++)
	{
		Trade_AddEmptyTile(playerid,x + float(i % TRADE_BAG_COLUMNS) * (bagTile + TRADE_TILE_GAP),y + KIT_ROW + float(i / TRADE_BAG_COLUMNS) * (bagTileHeight + TRADE_TILE_GAP),bagTile);
	}

	Kit_AddText(playerid,x,y + offersY - KIT_ROW,"You give: click to take back",KIT_COLOUR_ACCENT,0.75);
	format(line,sizeof(line),"%s gives",name);
	Kit_AddText(playerid,x + half + TRADE_COLUMN_GAP,y + offersY - KIT_ROW,line,KIT_COLOUR_ACCENT,0.75);
	Trade_DrawOffers(playerid,playerid,x,y + offersY,half,true);
	Trade_DrawOffers(playerid,partner,x + half + TRADE_COLUMN_GAP,y + offersY,half,false);

	new Float:buttonY = y + buttonsY, Float:small = width * 0.1;
	Kit_AddButton(playerid,x,buttonY,small,"+1",TRADE_PICK_COIN_1);
	Kit_AddButton(playerid,x + small + 3.0,buttonY,small,"+10",TRADE_PICK_COIN_10);
	Kit_AddButton(playerid,x + (small + 3.0) * 2.0,buttonY,small,"+100",TRADE_PICK_COIN_100);
	Kit_AddButton(playerid,x + (small + 3.0) * 3.0,buttonY,small * 1.4,"No coin",TRADE_PICK_COIN_CLEAR);
	Kit_AddButton(playerid,x + width * 0.56,buttonY,width * 0.2,Trade_HasAccepted(playerid) ? ("Take it back") : ("Accept"),TRADE_PICK_ACCEPT,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width * 0.8,buttonY,width * 0.2,"Cancel",KIT_BACK,KIT_COLOUR_BAD);
}

stock Trade_RunPanel(playerid)
{
	new epoch = Gui_BeginFlow(playerid);

	while (Trade_IsTrading(playerid))
	{
		Trade_Draw(playerid);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Trade_IsTrading(playerid))
		{
			break;
		}

		if (pick == KIT_BACK)
		{
			Gui_Notify(playerid,"You called the trade off.");
			Trade_Cancel(playerid,"The other side called the trade off.");
			break;
		}

		if (pick >= TRADE_PICK_BAG && pick < TRADE_PICK_BAG + INVENTORY_SLOTS)
		{
			if (!Trade_AddFromSlot(playerid,pick - TRADE_PICK_BAG))
			{
				Gui_Notify(playerid,"You can't put more of that in the trade.");
			}
		}
		else if (pick >= TRADE_PICK_OFFER && pick < TRADE_PICK_OFFER + TRADE_OFFERS)
		{
			Trade_RemoveOffer(playerid,pick - TRADE_PICK_OFFER);
		}
		else if (pick == TRADE_PICK_COIN_1 || pick == TRADE_PICK_COIN_10 || pick == TRADE_PICK_COIN_100)
		{
			Trade_SetCoin(playerid,Trade_GetCoin(playerid) + (pick == TRADE_PICK_COIN_1 ? 1 : (pick == TRADE_PICK_COIN_10 ? 10 : 100)));
		}
		else if (pick == TRADE_PICK_COIN_CLEAR)
		{
			Trade_SetCoin(playerid,0);
		}
		else if (pick == TRADE_PICK_ACCEPT)
		{
			Trade_Accept(playerid);
		}
	}

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

forward Trade_OpenDeferred(playerid,token);

public Trade_OpenDeferred(playerid,token)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Trade_IsTrading(playerid) && !Trade_IsPanelShown(playerid))
	{
		Trade_RunPanel(playerid);
	}
}

forward Trade_RefreshDeferred(playerid,token);

public Trade_RefreshDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Trade_IsPanelShown(playerid))
	{
		Kit_Pick(playerid,TRADE_PICK_REFRESH);
	}

	return 1;
}

forward Trade_AskDeferred(playerid,token,askerid);

public Trade_AskDeferred(playerid,token,askerid)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Gui_IsBusy(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, name[MAX_PLAYER_NAME * 2], text[TRADE_LINE_LEN];
	Nametag_GetKnownName(playerid,askerid,name,sizeof(name));
	format(text,sizeof(text),"%s wants to trade with you.",name);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TRADE_ASK_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,GUI_MESSAGE_LINE + KIT_ROW + 12.0,TRADE_ASK_TITLE,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + GUI_MESSAGE_LINE + 8.0,width * 0.45,"Trade",1,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width * 0.55,y + GUI_MESSAGE_LINE + 8.0,width * 0.45,"No thanks",KIT_BACK);
	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	Kit_Close(playerid);

	if (pick != 1)
	{
		Nametag_GetKnownName(askerid,playerid,name,sizeof(name));
		format(text,sizeof(text),"%s doesn't want to trade right now.",name);
		Gui_Notify(askerid,text);
		return;
	}

	if (!IsPlayerConnected(askerid) || !Trade_Begin(askerid,playerid))
	{
		Gui_Notify(playerid,"The trade can't start right now.");
	}
}

forward bool:Trade_KeyContext(playerid);

public bool:Trade_KeyContext(playerid)
{
	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);
	#pragma unused updown, leftright
	return (keys & KEY_WALK) && !Trade_IsTrading(playerid) && Trade_FindFacing(playerid) != INVALID_PLAYER_ID;
}

#include <pp-hooks>

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || !(newkeys & KEY_WALK) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Trade_IsTrading(playerid) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new target = Trade_FindFacing(playerid), text[TRADE_LINE_LEN];

	if (target != INVALID_PLAYER_ID)
	{
		Trade_Ask(playerid,target,text);
		Gui_Notify(playerid,text);
	}
}
