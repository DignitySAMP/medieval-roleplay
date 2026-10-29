static PlayerText:s_CardsTimerText[MAX_PLAYERS] = {PlayerText:INVALID_PLAYER_TEXT_DRAW, ...};

static bool:Cards_IsPanelShown(playerid)
{
	new title[KIT_TITLE_LEN];

	if (!Kit_IsOpen(playerid))
	{
		return false;
	}

	Kit_GetTitle(playerid,title);
	return !strcmp(title,CARDS_PANEL_TITLE);
}

static Cards_DrawCard(playerid,Float:x,Float:y,card)
{
	new Float:height = KIT_UNITS_Y(KIT_PIXELS_X(CARDS_BOX)) * 1.4, sprite[32];

	if (!Cards_IsValid(card))
	{
		Kit_AddBox(playerid,x,y,CARDS_BOX,height,KIT_COLOUR_TILE);
		return;
	}

	format(sprite,sizeof(sprite),"mdl%d:cd_%s_%s",MODEL_GAMES_SPRITES,g_CardsSpriteSuits[Cards_Suit(card)],g_CardsSpriteRanks[Cards_Rank(card)]);
	Kit_AddSprite(playerid,x,y,CARDS_BOX,height,sprite);
}

static Cards_DrawPanel(playerid,table)
{
	new Float:x, Float:y, Float:width, line[TABLE_LINE_LEN], name[TABLE_NAME_LEN], card[CARDS_NAME_LEN], seat = Table_GetPlayerSeat(playerid), actor = Cards_GetActor(table), bool:myTurn = seat == actor, Float:cardHeight = KIT_UNITS_Y(KIT_PIXELS_X(CARDS_BOX)) * 1.4;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,CARDS_PANEL_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,CARDS_PANEL_WIDTH,KIT_ROW * float(TABLE_SEATS + 5) + cardHeight + 10.0,CARDS_PANEL_TITLE,x,y,width);
	format(line,sizeof(line),"Pot: %d pfennig. %d cards left in the deck.",Table_GetPot(table),Cards_GetLeft(table));
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new Float:rowY = y + KIT_ROW * 1.3;

	for (new other = 0;other < TABLE_SEATS;other++)
	{
		if (!Table_IsSeatIn(table,other) && !Table_HasSeatLeft(table,other))
		{
			continue;
		}

		Table_GetSeatNameFor(table,other,playerid,name);
		Cards_Name(Cards_GetHand(table,other),card);

		if (Table_HasSeatLeft(table,other))
		{
			strcopy(card,"left");
		}
		else if (Cards_HasFolded(table,other))
		{
			strcopy(card,"folded");
		}

		Kit_AddText(playerid,x,rowY,name,other == actor ? KIT_COLOUR_ACCENT : (Cards_IsActive(table,other) ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED),KIT_TEXT_ROW);
		Kit_AddText(playerid,x + width * 0.55,rowY,card,Cards_IsActive(table,other) ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		rowY += KIT_ROW;
	}

	rowY += KIT_ROW * 0.4;
	Kit_AddText(playerid,x,rowY,"Middle",KIT_COLOUR_MUTED,0.7);
	Kit_AddText(playerid,x + CARDS_BOX + 12.0,rowY,"Last discards",KIT_COLOUR_MUTED,0.7);
	rowY += KIT_ROW;
	Cards_DrawCard(playerid,x,rowY,Cards_GetMiddle(table));

	for (new i = 0;i < CARDS_BURN;i++)
	{
		Cards_DrawCard(playerid,x + CARDS_BOX + 12.0 + float(i) * (CARDS_BOX + 4.0),rowY,Cards_GetBurned(table,i));
	}

	rowY += cardHeight + 4.0;
	Table_GetSeatNameFor(table,actor,playerid,name);

	if (myTurn)
	{
		new owed = Cards_GetOwed(table,seat);

		if (owed > 0)
		{
			format(line,sizeof(line),"Your turn. Meet the raise of %d pfennig or fold.",owed);
		}
		else
		{
			strcopy(line,"Your turn. Stay, raise or fold.");
		}
	}
	else
	{
		format(line,sizeof(line),"%s's turn.",name);
	}

	Kit_AddText(playerid,x,rowY,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	rowY += KIT_ROW * 1.3;

	if (myTurn)
	{
		new owed = Cards_GetOwed(table,seat), label[24];

		if (owed > 0)
		{
			format(label,sizeof(label),"Meet %d",owed);
			Kit_AddButton(playerid,x,rowY,width * 0.22,label,CARDS_PICK_ACT + CARDS_ACT_MEET,KIT_COLOUR_ACCENT);
		}
		else
		{
			Kit_AddButton(playerid,x,rowY,width * 0.22,"Stay",CARDS_PICK_ACT + CARDS_ACT_STAY,KIT_COLOUR_ACCENT);
		}

		format(label,sizeof(label),"Raise %d",Table_GetStake(table));
		Kit_AddButton(playerid,x + width * 0.24,rowY,width * 0.22,label,CARDS_PICK_ACT + CARDS_ACT_RAISE,Cards_CanRaise(table,seat) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		Kit_AddButton(playerid,x + width * 0.48,rowY,width * 0.2,"Fold",CARDS_PICK_ACT + CARDS_ACT_FOLD,KIT_COLOUR_BAD);
	}

	Kit_AddButton(playerid,x + width * 0.72,rowY,width * 0.28,"Leave",CARDS_PICK_LEAVE,KIT_COLOUR_BAD);
	rowY += KIT_ROW * 1.5;
	s_CardsTimerText[playerid] = Kit_AddText(playerid,x,rowY,"_",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
	Cards_UpdateTimer(playerid,table);
}

stock Cards_UpdateTimer(playerid,table)
{
	if (s_CardsTimerText[playerid] == PlayerText:INVALID_PLAYER_TEXT_DRAW || !Cards_IsPanelShown(playerid))
	{
		return;
	}

	new text[48];

	if (Table_IsSeatRegular(table,Cards_GetActor(table)))
	{
		strcopy(text,"_");
	}
	else
	{
		format(text,sizeof(text),"%d s left in this turn",Cards_GetSecondsLeft(table));
	}

	PlayerTextDrawSetString(playerid,s_CardsTimerText[playerid],text);
}

static bool:Cards_ConfirmLeave(playerid,table)
{
	new Float:x, Float:y, Float:width, text[TABLE_LINE_LEN];
	format(text,sizeof(text),"You'll lose the %d pfennig you've put in.~n~The pot stays with the others.",Table_GetSeatPaid(table,Table_GetPlayerSeat(playerid)));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,CARDS_LEAVE_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,GUI_MESSAGE_LINE * 2.0 + KIT_ROW + 12.0,CARDS_LEAVE_TITLE,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + GUI_MESSAGE_LINE * 2.0 + 8.0,width * 0.45,"Leave",1,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width * 0.55,y + GUI_MESSAGE_LINE * 2.0 + 8.0,width * 0.45,"Back",KIT_BACK);
	new pick = await Kit_Present(playerid);
	return pick == 1;
}

static Cards_HandlePick(playerid,table,pick)
{
	new line[TABLE_LINE_LEN];

	if (Table_GetPlayerSeat(playerid) != Cards_GetActor(table))
	{
		Gui_Notify(playerid,"Wait for your turn.");
		return;
	}

	if (pick == CARDS_PICK_ACT + CARDS_ACT_RAISE && !Cards_CanRaise(table,Table_GetPlayerSeat(playerid)))
	{
		format(line,sizeof(line),"You can't raise. Each player puts in at most %d pfennig.",TABLE_STAKE_MAX);
		Table_Notify(playerid,line);
		return;
	}

	new owed = Cards_GetOwed(table,Table_GetPlayerSeat(playerid));

	if (pick == CARDS_PICK_ACT + CARDS_ACT_STAY && owed > 0)
	{
		format(line,sizeof(line),"You owe %d pfennig. Meet the raise or fold.",owed);
		Table_Notify(playerid,line);
		return;
	}

	if (pick >= CARDS_PICK_ACT && pick <= CARDS_PICK_ACT + CARDS_ACT_FOLD && !Cards_Act(table,pick - CARDS_PICK_ACT))
	{
		format(line,sizeof(line),"You don't have %d pfennig for that.",owed + Table_GetStake(table));
		Table_Notify(playerid,line);
	}
}

stock Cards_RunPanel(playerid,table)
{
	new serial = Table_GetSerial(table), epoch = Gui_BeginFlow(playerid), line[TABLE_LINE_LEN];

	while (Cards_IsRunning(table) && Table_GetSerial(table) == serial && Table_GetPlayerTable(playerid) == table)
	{
		Cards_DrawPanel(playerid,table);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Cards_IsRunning(table) || Table_GetSerial(table) != serial || Table_GetPlayerTable(playerid) != table)
		{
			break;
		}

		if (pick == TABLE_PICK_REFRESH)
		{
			continue;
		}

		if (pick == KIT_BACK || pick == CARDS_PICK_LEAVE)
		{
			new bool:leave = Cards_ConfirmLeave(playerid,table);

			if (!Gui_IsFlowCurrent(playerid,epoch))
			{
				return;
			}

			if (leave && Table_GetPlayerTable(playerid) == table)
			{
				format(line,sizeof(line),"You left the hand and lost the %d pfennig you put in.",Table_GetSeatPaid(table,Table_GetPlayerSeat(playerid)));
				Table_Leave(playerid,TABLE_LEFT_QUIT);
				Table_Notify(playerid,line);
				break;
			}

			continue;
		}

		Cards_HandlePick(playerid,table,pick);
	}

	s_CardsTimerText[playerid] = PlayerText:INVALID_PLAYER_TEXT_DRAW;

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

stock Cards_RefreshSeats(table)
{
	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = Table_GetSeatPlayer(table,seat);

		if (Table_IsSeatIn(table,seat) && playerid != INVALID_PLAYER_ID)
		{
			SetTimerEx("Cards_RefreshDeferred",0,false,"ddd",playerid,Account_GetToken(playerid),table);
		}
	}
}

forward Cards_RefreshDeferred(playerid,token,table);

public Cards_RefreshDeferred(playerid,token,table)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (Cards_IsPanelShown(playerid))
	{
		Kit_Pick(playerid,TABLE_PICK_REFRESH);
		return;
	}

	if (!Gui_IsBusy(playerid) && Table_GetPlayerTable(playerid) == table && Cards_IsRunning(table))
	{
		Cards_RunPanel(playerid,table);
	}
}

forward Cards_CloseDeferred(playerid,token);

public Cards_CloseDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Cards_IsPanelShown(playerid))
	{
		Kit_Pick(playerid,TABLE_PICK_REFRESH);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CardsTimerText[playerid] = PlayerText:INVALID_PLAYER_TEXT_DRAW;
}

hook Cards_OnChanged(table)
{
	Cards_RefreshSeats(table);
}

hook Cards_OnEnded(table,winner)
{
	#pragma unused winner

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = Table_GetSeatPlayer(table,seat);

		if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
		{
			SetTimerEx("Cards_CloseDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
		}
	}
}

hook Table_OnPlayerLeft(table,playerid,reason)
{
	#pragma unused reason

	if (Table_GetGame(table) == TABLE_GAME_CARDS && IsPlayerConnected(playerid))
	{
		SetTimerEx("Cards_CloseDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	}
}

hook Table_OnReopen(table,playerid)
{
	if (Cards_IsRunning(table) && !Gui_IsBusy(playerid))
	{
		SetTimerEx("Cards_RefreshDeferred",0,false,"ddd",playerid,Account_GetToken(playerid),table);
	}
}
