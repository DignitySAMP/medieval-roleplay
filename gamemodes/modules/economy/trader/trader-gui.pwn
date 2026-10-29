static s_TraderPrompt[MAX_PLAYERS] = {-1, ...};
static s_TraderPromptInfobox[MAX_PLAYERS];

static Trader_SellableSlots(playerid,slots[],size = sizeof(slots))
{
	new count = 0, E_ITEM_KIND:kind, param, amount;

	for (new i = 0;i < Inventory_GetCount(playerid) && count < size;i++)
	{
		if (Inventory_GetSlot(playerid,i,kind,param,amount) && amount > 0 && Trader_Buys(kind,param))
		{
			slots[count++] = i;
		}
	}

	return count;
}

static Float:Trader_TileSize(Float:width)
{
	return (width - TRADER_TILE_GAP * float(TRADER_TILE_COLUMNS - 1)) / float(TRADER_TILE_COLUMNS);
}

static Float:Trader_TileRowHeight(Float:width)
{
	return KIT_UNITS_Y(KIT_PIXELS_X(Trader_TileSize(width))) + KIT_ROW * 0.85;
}

static Trader_AddPriceTile(playerid,Float:x,Float:y,Float:size,E_ITEM_KIND:kind,param,amount,stars,price,value)
{
	new icon[ITEM_ICON_LEN], label[24];
	Item_GetIcon(kind,param,icon);
	Kit_AddTile(playerid,x,y,size,Item_GetModel(kind,param),amount,false,value,false,icon,stars > ITEM_STARS_MIN ? stars : 0);
	format(label,sizeof(label),"%d pf",price);
	Kit_AddText(playerid,x + size / 2.0,y + KIT_UNITS_Y(KIT_PIXELS_X(size)) + 1.0,label,KIT_COLOUR_ACCENT,TRADER_PRICE_SIZE,TEXT_DRAW_FONT_1,true,size);
}

static Trader_Draw(playerid,trader,view,const slots[],count)
{
	new Float:x, Float:y, Float:width, name[TRADER_NAME_LEN], line[TRADER_LINE_LEN], value[32], Float:contentWidth = TRADER_WIDTH * (1.0 - KIT_BOX_INSET_X * 2.0), Float:tile = Trader_TileSize(contentWidth), Float:rowHeight = Trader_TileRowHeight(contentWidth);
	Trader_GetName(trader,name);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TRADER_TITLE);

	if (view == TRADER_VIEW_MENU)
	{
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TRADER_WIDTH,KIT_ROW * (2.4 + TRADER_BUTTON_GAP * 5.0) + 6.0,TRADER_TITLE,x,y,width);
		format(line,sizeof(line),"%s buys your goods and sells imports. %d pfennig left to buy with today.",name,Trader_GetPurse(trader));
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
		Kit_AddButton(playerid,x,y + KIT_ROW * 2.4,width,"Sell goods",TRADER_PICK_SELL,KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x,y + KIT_ROW * (2.4 + TRADER_BUTTON_GAP),width,"Buy imports",TRADER_PICK_BUY,KIT_COLOUR_ACCENT);
		Kit_AddButton(playerid,x,y + KIT_ROW * (2.4 + TRADER_BUTTON_GAP * 2.0),width,"Change coin",TRADER_PICK_CHANGE,KIT_COLOUR_ACCENT);
		format(value,sizeof(value),"Fill your water skin - %d pf",TRADER_FILL_FEE);
		Kit_AddButton(playerid,x,y + KIT_ROW * (2.4 + TRADER_BUTTON_GAP * 3.0),width,value,TRADER_PICK_FILL,Trader_FindStartedSkin(playerid) != -1 ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width * 0.6,y + KIT_ROW * (2.4 + TRADER_BUTTON_GAP * 4.0) + 4.0,width * 0.4,"Leave",KIT_BACK,KIT_COLOUR_BAD);
		return;
	}

	if (view == TRADER_VIEW_CHANGE)
	{
		new rowNumber = 0, big[ITEM_NAME_LEN];
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TRADER_WIDTH,KIT_ROW * (1.6 + TRADER_BUTTON_GAP * float((COIN_TIER_COUNT - 1) * 2 + 1)) + 6.0,TRADER_TITLE,x,y,width);
		format(line,sizeof(line),"The trader changes coin for %d pfennig a time.",TRADER_CHANGE_FEE);
		Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

		for (new tier = COIN_TIER_COUNT - 1;tier > COIN_PFENNIG;tier--)
		{
			Item_GetName(ITEM_KIND_COIN,tier,big);
			new Float:rowY = y + KIT_ROW * (1.6 + TRADER_BUTTON_GAP * float(rowNumber));
			format(line,sizeof(line),"Break a %s",big);
			Kit_AddButton(playerid,x,rowY,width * 0.62,line,TRADER_PICK_BREAK + tier,KIT_COLOUR_ACCENT);
			format(value,sizeof(value),"you have %d",Economy_CountCoins(playerid,tier));
			Kit_AddText(playerid,x + width * 0.66,rowY + 1.0,value,KIT_COLOUR_MUTED,KIT_TEXT_ROW);
			format(line,sizeof(line),"Make a %s",big);
			Kit_AddButton(playerid,x,rowY + KIT_ROW * TRADER_BUTTON_GAP,width * 0.62,line,TRADER_PICK_MAKE + tier,KIT_COLOUR_ACCENT);
			rowNumber += 2;
		}

		Kit_AddButton(playerid,x + width * 0.7,y + KIT_ROW * (1.6 + TRADER_BUTTON_GAP * float(rowNumber)) + 4.0,width * 0.3,"Back",TRADER_PICK_BACK);
		return;
	}

	new total = view == TRADER_VIEW_SELL ? count : sizeof(g_TraderStock), rows = max(1,(total + TRADER_TILE_COLUMNS - 1) / TRADER_TILE_COLUMNS);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TRADER_WIDTH,KIT_ROW * 1.6 + float(rows) * rowHeight + KIT_ROW * 1.4 + 6.0,TRADER_TITLE,x,y,width);

	if (view == TRADER_VIEW_SELL)
	{
		format(line,sizeof(line),"Click an item to sell one. %s has %d pfennig left today.",name,Trader_GetPurse(trader));
	}
	else
	{
		strcopy(line,"Click an item to buy one.");
	}

	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	if (total == 0)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * 1.6,"You have nothing the trader wants.",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
	}

	for (new i = 0;i < total;i++)
	{
		new Float:tileX = x + float(i % TRADER_TILE_COLUMNS) * (tile + TRADER_TILE_GAP), Float:tileY = y + KIT_ROW * 1.6 + float(i / TRADER_TILE_COLUMNS) * rowHeight;

		if (view == TRADER_VIEW_SELL)
		{
			new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,slots[i]);
			Inventory_GetSlot(playerid,slots[i],kind,param,amount);
			Trader_AddPriceTile(playerid,tileX,tileY,tile,kind,param,amount,stars,Trader_BuyPrice(playerid,kind,param,stars),TRADER_PICK_ROW + i);
		}
		else
		{
			Trader_AddPriceTile(playerid,tileX,tileY,tile,g_TraderStock[i][E_TRADER_STOCK_KIND],g_TraderStock[i][E_TRADER_STOCK_ITEM],0,0,Trader_SellPrice(playerid,g_TraderStock[i][E_TRADER_STOCK_KIND],g_TraderStock[i][E_TRADER_STOCK_ITEM]),TRADER_PICK_ROW + i);
		}
	}

	Kit_AddButton(playerid,x + width * 0.7,y + KIT_ROW * 1.6 + float(rows) * rowHeight + 4.0,width * 0.3,"Back",TRADER_PICK_BACK);
}

stock Trader_RunPanel(playerid,trader)
{
	new epoch = Gui_BeginFlow(playerid), view = TRADER_VIEW_MENU, slots[INVENTORY_SLOTS], count = 0, line[TRADER_LINE_LEN];

	for (;;)
	{
		count = Trader_SellableSlots(playerid,slots);
		Trader_Draw(playerid,trader,view,slots,count);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Trader_IsNear(playerid,trader,TRADER_REACH + 1.0))
		{
			Gui_Notify(playerid,"You walked away from the trader.");
			break;
		}

		if (!Trader_IsPresent(trader))
		{
			Gui_Notify(playerid,"The trader has packed up for the night. Come back at dawn.");
			break;
		}

		if (pick == KIT_BACK && view == TRADER_VIEW_MENU)
		{
			break;
		}

		if (pick == KIT_BACK || pick == TRADER_PICK_BACK)
		{
			view = TRADER_VIEW_MENU;
		}
		else if (pick == TRADER_PICK_SELL)
		{
			view = TRADER_VIEW_SELL;
		}
		else if (pick == TRADER_PICK_BUY)
		{
			view = TRADER_VIEW_BUY;
		}
		else if (pick == TRADER_PICK_CHANGE)
		{
			view = TRADER_VIEW_CHANGE;
		}
		else if (pick == TRADER_PICK_FILL)
		{
			Trader_FillSkin(playerid,trader,line);
			Gui_Notify(playerid,line);
		}
		else if (pick > TRADER_PICK_BREAK && pick < TRADER_PICK_BREAK + COIN_TIER_COUNT)
		{
			Trader_Change(playerid,trader,pick - TRADER_PICK_BREAK,true,line);
			Gui_Notify(playerid,line);
		}
		else if (pick > TRADER_PICK_MAKE && pick < TRADER_PICK_MAKE + COIN_TIER_COUNT)
		{
			Trader_Change(playerid,trader,pick - TRADER_PICK_MAKE,false,line);
			Gui_Notify(playerid,line);
		}
		else if (pick >= TRADER_PICK_ROW && pick < TRADER_PICK_ROW + INVENTORY_SLOTS + sizeof(g_TraderStock))
		{
			new index = pick - TRADER_PICK_ROW;

			if (view == TRADER_VIEW_SELL && index < count)
			{
				Trader_SellSlot(playerid,trader,slots[index],line);
				Gui_Notify(playerid,line);
			}
			else if (view == TRADER_VIEW_BUY)
			{
				Trader_BuyStock(playerid,trader,index,line);
				Gui_Notify(playerid,line);
			}
		}
	}

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

forward Float:Yard_GetWellDistance(playerid);

static Trader_ClearPrompt(playerid)
{
	if (s_TraderPrompt[playerid] != -1 && s_TraderPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_TraderPromptInfobox[playerid]);
	}

	s_TraderPrompt[playerid] = -1;
	s_TraderPromptInfobox[playerid] = 0;
}

static Trader_UpdatePrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Character_IsBusy(playerid) || !Trader_IsOpen())
	{
		Trader_ClearPrompt(playerid);
		return;
	}

	new trader = Trader_FindNear(playerid), Float:wellDistance = Yard_GetWellDistance(playerid);

	if (trader == -1 || (wellDistance >= 0.0 && !Trader_IsNear(playerid,trader,wellDistance)))
	{
		Trader_ClearPrompt(playerid);
		return;
	}

	if (trader == s_TraderPrompt[playerid] && Infobox_IsShown(playerid,s_TraderPromptInfobox[playerid]))
	{
		return;
	}

	new name[TRADER_NAME_LEN], text[TRADER_LINE_LEN];
	Trader_GetName(trader,name);
	format(text,sizeof(text),"Press ~y~Y~w~ to trade with %s.",name);
	s_TraderPrompt[playerid] = trader;
	s_TraderPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_TraderPromptInfobox[playerid],"Trader",text,1);
}

forward Trader_OpenDeferred(playerid,trader);

public Trader_OpenDeferred(playerid,trader)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || !Trader_IsPresent(trader))
	{
		return;
	}

	Trader_RunPanel(playerid,trader);
}

forward Trader_PromptTick();

public Trader_PromptTick()
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Trader_UpdatePrompt(playerid);
		}
	}

	return 1;
}

forward bool:Trader_KeyContext(playerid);

public bool:Trader_KeyContext(playerid)
{
	return s_TraderPrompt[playerid] != -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Trader_SetMark(playerid,-1,0,0);
	s_TraderPrompt[playerid] = -1;
	s_TraderPromptInfobox[playerid] = 0;
}

hook Calendar_OnDawn()
{
	for (new trader = 0;trader < TRADER_MAX;trader++)
	{
		Trader_Show(trader);
	}
}

hook Calendar_OnNightfall()
{
	for (new trader = 0;trader < TRADER_MAX;trader++)
	{
		Trader_Hide(trader);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !(newkeys & KEY_WALK) && s_TraderPrompt[playerid] != -1 && !Infobox_IsPromptBlocked(playerid,s_TraderPromptInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		new trader = s_TraderPrompt[playerid];
		Trader_ClearPrompt(playerid);

		if (!Trader_IsOpen())
		{
			Gui_Notify(playerid,"The market is closed for the night. The trader is back at dawn.");
			return;
		}

		SetTimerEx("Trader_OpenDeferred",0,false,"dd",playerid,trader);
	}
}
