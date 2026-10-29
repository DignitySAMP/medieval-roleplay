static PlayerText:s_DiceTimerText[MAX_PLAYERS] = {PlayerText:INVALID_PLAYER_TEXT_DRAW, ...};

static bool:Dice_IsPanelShown(playerid)
{
	new title[KIT_TITLE_LEN];

	if (!Kit_IsOpen(playerid))
	{
		return false;
	}

	Kit_GetTitle(playerid,title);
	return !strcmp(title,DICE_PANEL_TITLE);
}

static Dice_DrawDie(playerid,Float:x,Float:y,table,seat,die,bool:canPick)
{
	new Float:height = KIT_UNITS_Y(KIT_PIXELS_X(DICE_BOX)), Float:rimY = KIT_UNITS_Y(KIT_PIXELS_X(DICE_PICK_RIM)), sprite[32], bool:aside = !Dice_IsDieFree(table,die), bool:picked = (Dice_GetPicked(table) & (1 << die)) != 0;

	if (picked && !aside)
	{
		Kit_AddBox(playerid,x - DICE_PICK_RIM,y - rimY,DICE_BOX + DICE_PICK_RIM * 2.0,height + rimY * 2.0,KIT_COLOUR_ACCENT);
	}

	format(sprite,sizeof(sprite),"mdl%d:dc_%s_%d",MODEL_GAMES_SPRITES,g_DiceKindSprites[Dice_GetDieKind(table,seat,die)],Dice_GetFace(table,die));
	Kit_AddSprite(playerid,x,y,DICE_BOX,height,sprite,aside ? DICE_COLOUR_ASIDE : -1);

	if (canPick && !aside)
	{
		Kit_AddHit(playerid,x,y,DICE_BOX,height,DICE_PICK_DIE + die);
	}
}

static Dice_DrawPanel(playerid,table)
{
	new Float:x, Float:y, Float:width, line[TABLE_LINE_LEN], name[TABLE_NAME_LEN], seat = Table_GetPlayerSeat(playerid), turn = Dice_GetTurn(table), bool:myTurn = seat == turn, Float:dieHeight = KIT_UNITS_Y(KIT_PIXELS_X(DICE_BOX));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,DICE_PANEL_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,DICE_PANEL_WIDTH,KIT_ROW * float(TABLE_SEATS + 6) + dieHeight + 10.0,DICE_PANEL_TITLE,x,y,width);
	format(line,sizeof(line),"Pot: %d pfennig. The first to %d wins.",Table_GetPot(table),Dice_GetTarget(table));
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	new Float:rowY = y + KIT_ROW * 1.3;

	for (new other = 0;other < TABLE_SEATS;other++)
	{
		if (!Table_IsSeatIn(table,other) && !Table_HasSeatLeft(table,other))
		{
			continue;
		}

		Table_GetSeatNameFor(table,other,playerid,name);

		if (Table_HasSeatLeft(table,other))
		{
			strcat(name," (left)");
		}

		valstr(line,Dice_GetScore(table,other));
		Kit_AddText(playerid,x,rowY,name,other == turn ? KIT_COLOUR_ACCENT : (Table_IsSeatIn(table,other) ? KIT_COLOUR_TEXT : KIT_COLOUR_MUTED),KIT_TEXT_ROW);
		Kit_AddText(playerid,x + width * 0.78,rowY,line,other == turn ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW);
		rowY += KIT_ROW;
	}

	rowY += KIT_ROW * 0.4;
	Table_GetSeatNameFor(table,turn,playerid,name);

	if (Dice_IsBusted(table))
	{
		format(line,sizeof(line),myTurn ? ("You rolled nothing that scores. Your turn is over.") : ("%s rolled nothing that scores."),name);
	}
	else if (myTurn)
	{
		format(line,sizeof(line),"Your turn. %d points so far this turn.",Dice_GetTurnPoints(table));
	}
	else
	{
		format(line,sizeof(line),"%s's turn. %d points so far this turn.",name,Dice_GetTurnPoints(table));
	}

	Kit_AddText(playerid,x,rowY,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	rowY += KIT_ROW * 1.3;

	if (Dice_HasRolled(table))
	{
		new Float:rowWidth = float(DICE_COUNT) * DICE_BOX + float(DICE_COUNT - 1) * DICE_BOX_GAP, Float:dieX = x + (width - rowWidth) / 2.0;

		for (new die = 0;die < DICE_COUNT;die++)
		{
			Dice_DrawDie(playerid,dieX + float(die) * (DICE_BOX + DICE_BOX_GAP),rowY,table,turn,die,myTurn && !Dice_IsBusted(table));
		}
	}
	else
	{
		Kit_AddText(playerid,x + width / 2.0,rowY + dieHeight / 2.0 - KIT_ROW / 2.0,myTurn ? ("Roll the dice to start your turn.") : ("Waiting for the first roll."),KIT_COLOUR_MUTED,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,true,width);
	}

	rowY += dieHeight + 4.0;

	if (myTurn && Dice_HasRolled(table) && !Dice_IsBusted(table))
	{
		new score = Dice_PickScore(table);

		if (Dice_GetPicked(table) == 0)
		{
			strcopy(line,"Click the dice you want to keep.");
		}
		else if (score <= 0)
		{
			strcopy(line,"Those dice don't score together.");
		}
		else
		{
			format(line,sizeof(line),"Kept: %d points.",score);
		}

		Kit_AddText(playerid,x,rowY,line,score > 0 ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,KIT_TEXT_ROW);
	}

	rowY += KIT_ROW * 1.2;

	if (myTurn && !Dice_IsBusted(table))
	{
		if (Dice_HasRolled(table))
		{
			Kit_AddButton(playerid,x,rowY,width * 0.3,"Roll the rest",DICE_PICK_ROLL,KIT_COLOUR_ACCENT);
			Kit_AddButton(playerid,x + width * 0.35,rowY,width * 0.3,"Bank",DICE_PICK_BANK,KIT_COLOUR_GOOD);
		}
		else
		{
			Kit_AddButton(playerid,x,rowY,width * 0.65,"Roll",DICE_PICK_ROLL,KIT_COLOUR_ACCENT);
		}
	}

	Kit_AddButton(playerid,x + width * 0.7,rowY,width * 0.3,"Leave",DICE_PICK_LEAVE,KIT_COLOUR_BAD);
	rowY += KIT_ROW * 1.5;
	s_DiceTimerText[playerid] = Kit_AddText(playerid,x,rowY,"_",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
	Dice_UpdateTimer(playerid,table);
}

stock Dice_UpdateTimer(playerid,table)
{
	if (s_DiceTimerText[playerid] == PlayerText:INVALID_PLAYER_TEXT_DRAW || !Dice_IsPanelShown(playerid))
	{
		return;
	}

	new text[48], turn = Dice_GetTurn(table);

	if (Dice_IsBusted(table) || Table_IsSeatRegular(table,turn))
	{
		strcopy(text,"_");
	}
	else
	{
		format(text,sizeof(text),"%d s left in this turn",Dice_GetSecondsLeft(table));
	}

	PlayerTextDrawSetString(playerid,s_DiceTimerText[playerid],text);
}

static bool:Dice_ConfirmLeave(playerid,table)
{
	new Float:x, Float:y, Float:width, text[TABLE_LINE_LEN];
	format(text,sizeof(text),"You'll lose your stake of %d pfennig.~n~The pot stays with the others.",Table_GetStake(table));
	Kit_Begin(playerid,KIT_LAYER_SCREEN,DICE_LEAVE_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,GUI_MESSAGE_LINE * 2.0 + KIT_ROW + 12.0,DICE_LEAVE_TITLE,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + GUI_MESSAGE_LINE * 2.0 + 8.0,width * 0.45,"Leave",1,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width * 0.55,y + GUI_MESSAGE_LINE * 2.0 + 8.0,width * 0.45,"Back",KIT_BACK);
	new pick = await Kit_Present(playerid);
	return pick == 1;
}

static Dice_HandlePick(playerid,table,pick)
{
	if (Table_GetPlayerSeat(playerid) != Dice_GetTurn(table))
	{
		Gui_Notify(playerid,"Wait for your turn.");
		return;
	}

	if (pick == DICE_PICK_ROLL)
	{
		if (!Dice_Roll(table))
		{
			Gui_Notify(playerid,"Keep at least one scoring die before you roll the rest.");
		}
	}
	else if (pick == DICE_PICK_BANK)
	{
		if (!Dice_Bank(table))
		{
			Gui_Notify(playerid,"Keep at least one scoring die to bank your points.");
		}
	}
	else if (pick >= DICE_PICK_DIE && pick < DICE_PICK_DIE + DICE_COUNT)
	{
		Dice_TogglePick(table,pick - DICE_PICK_DIE);
	}
}

stock Dice_RunPanel(playerid,table)
{
	new serial = Table_GetSerial(table), epoch = Gui_BeginFlow(playerid), line[TABLE_LINE_LEN];

	while (Dice_IsRunning(table) && Table_GetSerial(table) == serial && Table_GetPlayerTable(playerid) == table)
	{
		Dice_DrawPanel(playerid,table);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Dice_IsRunning(table) || Table_GetSerial(table) != serial || Table_GetPlayerTable(playerid) != table)
		{
			break;
		}

		if (pick == TABLE_PICK_REFRESH)
		{
			continue;
		}

		if (pick == KIT_BACK || pick == DICE_PICK_LEAVE)
		{
			new bool:leave = Dice_ConfirmLeave(playerid,table);

			if (!Gui_IsFlowCurrent(playerid,epoch))
			{
				return;
			}

			if (leave && Table_GetPlayerTable(playerid) == table)
			{
				format(line,sizeof(line),"You left the game and lost your stake of %d pfennig.",Table_GetStake(table));
				Table_Leave(playerid,TABLE_LEFT_QUIT);
				Table_Notify(playerid,line);
				break;
			}

			continue;
		}

		Dice_HandlePick(playerid,table,pick);
	}

	s_DiceTimerText[playerid] = PlayerText:INVALID_PLAYER_TEXT_DRAW;

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

stock Dice_RefreshSeats(table)
{
	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = Table_GetSeatPlayer(table,seat);

		if (Table_IsSeatIn(table,seat) && playerid != INVALID_PLAYER_ID)
		{
			SetTimerEx("Dice_RefreshDeferred",0,false,"ddd",playerid,Account_GetToken(playerid),table);
		}
	}
}

forward Dice_RefreshDeferred(playerid,token,table);

public Dice_RefreshDeferred(playerid,token,table)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return;
	}

	if (Dice_IsPanelShown(playerid))
	{
		Kit_Pick(playerid,TABLE_PICK_REFRESH);
		return;
	}

	if (!Gui_IsBusy(playerid) && Table_GetPlayerTable(playerid) == table && Dice_IsRunning(table))
	{
		Dice_RunPanel(playerid,table);
	}
}

forward Dice_CloseDeferred(playerid,token);

public Dice_CloseDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Dice_IsPanelShown(playerid))
	{
		Kit_Pick(playerid,TABLE_PICK_REFRESH);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_DiceTimerText[playerid] = PlayerText:INVALID_PLAYER_TEXT_DRAW;
}

hook Dice_OnChanged(table)
{
	Dice_RefreshSeats(table);
}

hook Dice_OnEnded(table,winner)
{
	#pragma unused winner

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = Table_GetSeatPlayer(table,seat);

		if (playerid != INVALID_PLAYER_ID && IsPlayerConnected(playerid))
		{
			SetTimerEx("Dice_CloseDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
		}
	}
}

hook Table_OnPlayerLeft(table,playerid,reason)
{
	#pragma unused table,reason

	if (IsPlayerConnected(playerid))
	{
		SetTimerEx("Dice_CloseDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
	}
}

hook Table_OnReopen(table,playerid)
{
	if (Dice_IsRunning(table) && !Gui_IsBusy(playerid))
	{
		SetTimerEx("Dice_RefreshDeferred",0,false,"ddd",playerid,Account_GetToken(playerid),table);
	}
}
