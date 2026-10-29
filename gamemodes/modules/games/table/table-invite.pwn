enum E_TABLE_REFUSAL
{
	E_TABLE_REFUSAL_FROM,
	E_TABLE_REFUSAL_COUNT,
	E_TABLE_REFUSAL_SINCE,
	E_TABLE_REFUSAL_UNTIL,
}

static s_TableRefusals[MAX_PLAYERS][TABLE_REFUSAL_SLOTS][E_TABLE_REFUSAL];
static s_TableRegularPrompt[MAX_PLAYERS] = {TABLE_EMPTY, ...};
static s_TableRegularPromptInfobox[MAX_PLAYERS];

stock Table_GetBlockLeft(targetid,hostid)
{
	new from = Character_GetId(hostid), now = gettime();

	for (new i = 0;i < TABLE_REFUSAL_SLOTS;i++)
	{
		if (s_TableRefusals[targetid][i][E_TABLE_REFUSAL_FROM] == from && s_TableRefusals[targetid][i][E_TABLE_REFUSAL_UNTIL] > now)
		{
			return s_TableRefusals[targetid][i][E_TABLE_REFUSAL_UNTIL] - now;
		}
	}

	return 0;
}

stock Table_NoteRefusal(targetid,hostid)
{
	new from = Character_GetId(hostid), now = gettime(), slot = -1, oldest = 0;

	for (new i = 0;i < TABLE_REFUSAL_SLOTS;i++)
	{
		if (s_TableRefusals[targetid][i][E_TABLE_REFUSAL_FROM] == from)
		{
			slot = i;
			break;
		}

		if (s_TableRefusals[targetid][i][E_TABLE_REFUSAL_SINCE] < s_TableRefusals[targetid][oldest][E_TABLE_REFUSAL_SINCE])
		{
			oldest = i;
		}
	}

	if (slot == -1)
	{
		slot = oldest;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_FROM] = from;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_COUNT] = 0;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_SINCE] = now;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_UNTIL] = 0;
	}

	if (now - s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_SINCE] > TABLE_REFUSAL_SECONDS)
	{
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_COUNT] = 0;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_SINCE] = now;
	}

	if (++s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_COUNT] >= TABLE_REFUSALS_MAX)
	{
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_UNTIL] = now + TABLE_REFUSAL_SECONDS;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_COUNT] = 0;
		s_TableRefusals[targetid][slot][E_TABLE_REFUSAL_SINCE] = now;
	}
}

static Table_ResetRefusals(playerid)
{
	for (new i = 0;i < TABLE_REFUSAL_SLOTS;i++)
	{
		s_TableRefusals[playerid][i][E_TABLE_REFUSAL_FROM] = 0;
		s_TableRefusals[playerid][i][E_TABLE_REFUSAL_COUNT] = 0;
		s_TableRefusals[playerid][i][E_TABLE_REFUSAL_SINCE] = 0;
		s_TableRefusals[playerid][i][E_TABLE_REFUSAL_UNTIL] = 0;
	}
}

stock bool:Table_CheckAsk(hostid,targetid,dest[],size = sizeof(dest))
{
	new name[TABLE_NAME_LEN], Float:x, Float:y, Float:z;
	dest[0] = EOS;
	Nametag_GetKnownName(hostid,targetid,name);

	if (!Session_IsPlaying(targetid) || targetid == hostid)
	{
		format(dest,size,"%s can't play right now.",name);
		return false;
	}

	if (Table_GetPlayerTable(targetid) != TABLE_EMPTY)
	{
		format(dest,size,"%s is already in a game.",name);
		return false;
	}

	if (Gui_IsBusy(targetid) || Character_IsBusy(targetid))
	{
		format(dest,size,"%s is busy right now. Ask again in a moment.",name);
		return false;
	}

	GetPlayerPos(targetid,x,y,z);

	if (GetPlayerVirtualWorld(targetid) != GetPlayerVirtualWorld(hostid) || GetPlayerDistanceFromPoint(hostid,x,y,z) > TABLE_INVITE_RANGE + 1.0)
	{
		format(dest,size,"%s is too far away. Stand next to them to ask.",name);
		return false;
	}

	new left = Table_GetBlockLeft(targetid,hostid);

	if (left > 0)
	{
		format(dest,size,"%s turned you down three times. You can ask again in %d minutes.",name,(left + 59) / 60);
		return false;
	}

	return true;
}

stock Table_GetNearbyPlayers(playerid,results[],maxResults = sizeof(results))
{
	new Float:x, Float:y, Float:z, found[MAX_PLAYERS], kept = 0;
	GetPlayerPos(playerid,x,y,z);
	new count = Util_GetPlayersInRange(x,y,z,TABLE_INVITE_RANGE,found,sizeof(found));

	for (new i = 0;i < count && kept < maxResults;i++)
	{
		new other = found[i];

		if (other == playerid || IsPlayerNPC(other) || !Session_IsPlaying(other) || GetPlayerVirtualWorld(other) != GetPlayerVirtualWorld(playerid))
		{
			continue;
		}

		results[kept++] = other;
	}

	return kept;
}

stock bool:Table_Invite(table,targetid)
{
	if (Table_Ask(table,targetid) == -1)
	{
		return false;
	}

	SetTimerEx("Table_InviteDeferred",0,false,"ddd",targetid,table,Table_GetSerial(table));
	return true;
}

stock Table_CloseInvite(playerid)
{
	new title[KIT_TITLE_LEN];

	if (!Util_IsValidPlayer(playerid) || !Kit_IsOpen(playerid))
	{
		return;
	}

	Kit_GetTitle(playerid,title);

	if (!strcmp(title,TABLE_INVITE_TITLE))
	{
		Kit_Pick(playerid,TABLE_PICK_EXPIRED);
	}
}

stock Table_CheckGathering(table)
{
	if (Table_GetState(table) != TABLE_GATHERING || Table_CountAsked(table) > 0)
	{
		return;
	}

	if (Table_CountIn(table) >= 2)
	{
		Table_Start(table);
		return;
	}

	Gui_Notify(Table_GetSeatPlayer(table,0),"Nobody took up your challenge. Your stake is back in your purse.");
	Table_Close(table);
}

static Table_PokeHost(table)
{
	new host = Table_GetSeatPlayer(table,0);

	if (Util_IsValidPlayer(host))
	{
		SetTimerEx("Table_PokeDeferred",0,false,"dd",host,Account_GetToken(host));
	}
}

static Table_DrawInvite(playerid,table)
{
	new Float:x, Float:y, Float:width, text[TABLE_LINE_LEN * 2], host[TABLE_NAME_LEN], game[TABLE_TITLE_LEN], offer[TABLE_LINE_LEN];
	Table_GetSeatNameFor(table,0,playerid,host);
	Table_GetGameName(Table_GetGame(table),game);
	Table_GetOffer(table,offer);
	format(text,sizeof(text),"%s wants to play %s with you.~n~You each put %d pfennig in the pot.~n~%s",host,game,Table_GetStake(table),offer);

	new Float:textHeight = Gui_TextHeight(text,TABLE_INVITE_WIDTH);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TABLE_INVITE_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TABLE_INVITE_WIDTH,textHeight + KIT_ROW + 12.0,TABLE_INVITE_TITLE,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddButton(playerid,x,y + textHeight + 8.0,width * 0.45,"Play",1,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width * 0.55,y + textHeight + 8.0,width * 0.45,"No thanks",KIT_BACK);
}

static Table_DrawGathering(playerid,table)
{
	new Float:x, Float:y, Float:width, line[TABLE_LINE_LEN], name[TABLE_NAME_LEN], in = Table_CountIn(table);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TABLE_GATHER_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TABLE_GATHER_WIDTH,KIT_ROW * float(TABLE_SEATS + 3) + 14.0,TABLE_GATHER_TITLE,x,y,width);
	format(line,sizeof(line),"Stake: %d pfennig each. Pot: %d pfennig.",Table_GetStake(table),Table_GetPot(table));
	Kit_AddText(playerid,x,y,line,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new Float:rowY = y + KIT_ROW * (float(seat) + 1.5);

		if (Table_IsSeatIn(table,seat))
		{
			Table_GetSeatNameFor(table,seat,playerid,name);
			Kit_AddText(playerid,x,rowY,name,KIT_COLOUR_TEXT,KIT_TEXT_ROW);
			Kit_AddText(playerid,x + width * 0.66,rowY,"In",KIT_COLOUR_GOOD,KIT_TEXT_ROW);
		}
		else if (Table_IsSeatAsked(table,seat))
		{
			Table_GetSeatNameFor(table,seat,playerid,name);
			Kit_AddText(playerid,x,rowY,name,KIT_COLOUR_TEXT,KIT_TEXT_ROW);
			Kit_AddText(playerid,x + width * 0.66,rowY,"Asked",KIT_COLOUR_ACCENT,KIT_TEXT_ROW);
		}
		else
		{
			Kit_AddText(playerid,x,rowY,"Empty seat",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		}
	}

	new Float:buttonY = y + KIT_ROW * (float(TABLE_SEATS) + 2.0);
	Kit_AddButton(playerid,x,buttonY,width * 0.45,"Start",TABLE_PICK_START,in >= 2 ? KIT_COLOUR_ACCENT : KIT_COLOUR_MUTED);
	Kit_AddButton(playerid,x + width * 0.55,buttonY,width * 0.45,"Call it off",TABLE_PICK_CALL_OFF,KIT_COLOUR_BAD);
}

stock Table_RunGathering(playerid,table,serial)
{
	new epoch = Gui_BeginFlow(playerid);

	while (Table_IsCurrent(table,serial) && Table_GetState(table) == TABLE_GATHERING && Table_GetPlayerSeat(playerid) == 0)
	{
		Table_DrawGathering(playerid,table);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (!Table_IsCurrent(table,serial) || Table_GetState(table) != TABLE_GATHERING)
		{
			break;
		}

		if (pick == TABLE_PICK_START)
		{
			if (Table_CountIn(table) < 2)
			{
				Gui_Notify(playerid,"You need at least one other player in before you can start.");
			}
			else
			{
				Table_Start(table);
			}
		}
		else if (pick == TABLE_PICK_CALL_OFF || pick == KIT_BACK)
		{
			Table_NotifySeats(table,"The game was called off. You got your stake back.",0);
			Table_Close(table);
			Gui_Notify(playerid,"You called the game off. Everyone got their stake back.");
		}
	}

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);

		if (Table_IsCurrent(table,serial) && Table_GetState(table) == TABLE_PLAYING)
		{
			pawn_call_public("Table_OnReopen","dd",table,playerid);
		}
	}
}

static Table_DrawSetup(playerid,game,regular,const nearby[],count,chosen,bool:withRegular,stakeIndex,option)
{
	new Float:x, Float:y, Float:width, name[TABLE_NAME_LEN], value[32], title[KIT_TITLE_LEN], rows = count + (regular != TABLE_EMPTY ? 1 : 0), options = Table_CountGameOptions(game);
	Table_GetGameName(game,name);
	format(title,sizeof(title),"Play %s",name);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,TABLE_SETUP_WIDTH,KIT_ROW * float(max(rows,1) + (options > 0 ? 5 : 4)) + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,"Who plays with you",KIT_COLOUR_ACCENT,KIT_TEXT_ROW);

	new Float:rowY = y + KIT_ROW * 1.2;

	if (regular != TABLE_EMPTY)
	{
		Table_GetRegularName(regular,name);
		strcat(name," (regular)");
		Kit_AddChoice(playerid,x,rowY,width,name,TABLE_PICK_REGULAR,KIT_COLOUR_TEXT,withRegular ? ("Plays") : ("-"),withRegular ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,0.72);
		rowY += KIT_ROW;
	}

	for (new i = 0;i < count;i++)
	{
		new known[NAMETAG_LEN];
		Nametag_GetKnownName(playerid,nearby[i],known);
		format(name,sizeof(name),"%s (%d)",known,nearby[i]);
		Kit_AddChoice(playerid,x,rowY,width,name,TABLE_PICK_PLAYER + i,KIT_COLOUR_TEXT,(chosen & (1 << i)) ? ("Asked") : ("-"),(chosen & (1 << i)) ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED,0.72);
		rowY += KIT_ROW;
	}

	if (rows == 0)
	{
		Kit_AddText(playerid,x,rowY,"There's nobody next to you to play with.",KIT_COLOUR_MUTED,KIT_TEXT_ROW);
		rowY += KIT_ROW;
	}

	rowY += KIT_ROW * 0.5;
	format(value,sizeof(value),"%d pfennig each",g_TableStakes[stakeIndex]);
	Kit_AddChoice(playerid,x,rowY,width,"Stake",TABLE_PICK_STAKE,KIT_COLOUR_TEXT,value,KIT_COLOUR_ACCENT,0.42);
	rowY += KIT_ROW;

	if (options > 0)
	{
		new label[TABLE_OPTION_LEN];
		Table_GetGameOptionLabel(game,label);
		Table_GetGameOption(game,option,value);
		Kit_AddChoice(playerid,x,rowY,width,label,TABLE_PICK_OPTION,KIT_COLOUR_TEXT,value,KIT_COLOUR_ACCENT,0.42);
		rowY += KIT_ROW;
	}

	rowY += KIT_ROW * 0.6;
	Kit_AddButton(playerid,x,rowY,width * 0.45,"Challenge",TABLE_PICK_CHALLENGE,KIT_COLOUR_GOOD);
	Kit_AddButton(playerid,x + width * 0.55,rowY,width * 0.45,"Back",KIT_BACK);
}

stock Table_RunSetup(playerid,game,regular)
{
	new epoch = Gui_BeginFlow(playerid), nearby[TABLE_SETUP_ROWS], count = Table_GetNearbyPlayers(playerid,nearby,TABLE_SETUP_ROWS), chosen = 0, bool:withRegular = regular != TABLE_EMPTY, stakeIndex = 1, option = 0, line[TABLE_LINE_LEN];

	for (;;)
	{
		Table_DrawSetup(playerid,game,regular,nearby,count,chosen,withRegular,stakeIndex,option);
		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch))
		{
			return;
		}

		if (pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		if (pick == TABLE_PICK_REGULAR)
		{
			withRegular = !withRegular;
		}
		else if (pick >= TABLE_PICK_PLAYER && pick < TABLE_PICK_PLAYER + count)
		{
			new bit = 1 << (pick - TABLE_PICK_PLAYER);

			if ((chosen & bit) == 0 && Table_CountBits(chosen) + (withRegular ? 1 : 0) >= TABLE_SEATS - 1)
			{
				format(line,sizeof(line),"A game has room for %d players.",TABLE_SEATS);
				Table_Notify(playerid,line);
			}
			else
			{
				chosen ^= bit;
			}
		}
		else if (pick == TABLE_PICK_STAKE)
		{
			stakeIndex = (stakeIndex + 1) % sizeof(g_TableStakes);
		}
		else if (pick == TABLE_PICK_OPTION)
		{
			option = (option + 1) % max(1,Table_CountGameOptions(game));
		}
		else if (pick == TABLE_PICK_CHALLENGE)
		{
			new stake = g_TableStakes[stakeIndex];

			if (chosen == 0 && !withRegular)
			{
				Gui_Notify(playerid,"Pick at least one person to play with.");
				continue;
			}

			if (Economy_Worth(playerid) < stake)
			{
				format(line,sizeof(line),"You don't have %d pfennig for the stake.",stake);
				Table_Notify(playerid,line);
				continue;
			}

			if (Table_GetPlayerTable(playerid) != TABLE_EMPTY)
			{
				Kit_Close(playerid);
				return;
			}

			if (withRegular && regular != TABLE_EMPTY)
			{
				new name[TABLE_REGULAR_NAME_LEN], won = await Table_WonFromRegularsToday(Character_GetId(playerid));

				if (!Gui_IsFlowCurrent(playerid,epoch))
				{
					return;
				}

				Table_GetRegularName(regular,name);

				if (won >= TABLE_REGULAR_WIN_CAP)
				{
					format(line,sizeof(line),"You've won %d pfennig from the regulars today. They won't play you again until tomorrow.",won);
					Table_Notify(playerid,line);
					continue;
				}

				if (Table_GetRegularTable(regular) != TABLE_EMPTY)
				{
					format(line,sizeof(line),"%s is already in a game.",name);
					Table_Notify(playerid,line);
					continue;
				}

				if (Table_GetRegularPurse(regular) < stake)
				{
					format(line,sizeof(line),"%s only has %d pfennig left today. Pick a smaller stake.",name,Table_GetRegularPurse(regular));
					Table_Notify(playerid,line);
					continue;
				}
			}

			new bool:canAsk = true;

			for (new i = 0;i < count;i++)
			{
				if ((chosen & (1 << i)) && !Table_CheckAsk(playerid,nearby[i],line))
				{
					Table_Notify(playerid,line);
					chosen &= ~(1 << i);
					canAsk = false;
				}
			}

			if (!canAsk)
			{
				continue;
			}

			break;
		}
	}

	Kit_Close(playerid);

	new stake = g_TableStakes[stakeIndex], table = await Table_Open(game,playerid,stake,option);

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	if (table == TABLE_EMPTY)
	{
		format(line,sizeof(line),"The game couldn't be set up. Check you still have %d pfennig for the stake.",stake);
		Table_Notify(playerid,line);
		return;
	}

	new serial = Table_GetSerial(table);
	Table_FormatOffer(game,option,line);
	Table_SetOffer(table,line);

	if (withRegular && regular != TABLE_EMPTY && !Table_SeatRegular(table,regular))
	{
		Gui_Notify(playerid,"The regular can't play right now.");
	}

	for (new i = 0;i < count;i++)
	{
		if ((chosen & (1 << i)) && Table_CheckAsk(playerid,nearby[i],line))
		{
			Table_Invite(table,nearby[i]);
		}
	}

	Table_CheckGathering(table);

	if (Table_IsCurrent(table,serial) && Table_GetState(table) == TABLE_GATHERING)
	{
		Table_RunGathering(playerid,table,serial);
	}
}

stock Table_UpdateRegularPrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Character_IsBusy(playerid) || Table_GetPlayerTable(playerid) != TABLE_EMPTY || Wounds_IsDown(playerid))
	{
		Table_ClearRegularPrompt(playerid);
		return;
	}

	new regular = Table_FindRegularNear(playerid);

	if (regular == TABLE_EMPTY || Table_GetRegularTable(regular) != TABLE_EMPTY)
	{
		Table_ClearRegularPrompt(playerid);
		return;
	}

	if (regular == s_TableRegularPrompt[playerid] && Infobox_IsShown(playerid,s_TableRegularPromptInfobox[playerid]))
	{
		return;
	}

	new name[TABLE_REGULAR_NAME_LEN], text[TABLE_LINE_LEN];
	Table_GetRegularName(regular,name);
	format(text,sizeof(text),"Press ~y~Y~w~ to play dice or Lansquenet with %s. Regulars bring their own dice and cards.",name);
	s_TableRegularPrompt[playerid] = regular;
	s_TableRegularPromptInfobox[playerid] = Infobox_ShowPrompt(playerid,s_TableRegularPromptInfobox[playerid],"Tavern regular",text,2);
}

stock Table_ClearRegularPrompt(playerid)
{
	if (s_TableRegularPrompt[playerid] != TABLE_EMPTY && s_TableRegularPromptInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_TableRegularPromptInfobox[playerid]);
	}

	s_TableRegularPrompt[playerid] = TABLE_EMPTY;
	s_TableRegularPromptInfobox[playerid] = 0;
}

forward Table_InviteDeferred(playerid,table,serial);

public Table_InviteDeferred(playerid,table,serial)
{
	yield 1;

	new seat = Table_GetPlayerSeat(playerid);

	if (!Table_IsCurrent(table,serial) || Table_GetPlayerTable(playerid) != table || !Table_IsSeatAsked(table,seat))
	{
		return;
	}

	new host = Table_GetSeatPlayer(table,0), name[TABLE_NAME_LEN], line[TABLE_LINE_LEN];
	Table_GetSeatName(table,seat,name);

	if (Gui_IsBusy(playerid))
	{
		format(line,sizeof(line),"%s is busy right now. Ask again in a moment.",name);
		Table_Notify(host,line);
		Table_Decline(table,seat);
		Table_CheckGathering(table);
		return;
	}

	new epoch = Gui_BeginFlow(playerid);
	Table_DrawInvite(playerid,table);
	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	Kit_Close(playerid);

	if (pick == TABLE_PICK_EXPIRED)
	{
		return;
	}

	seat = Table_GetPlayerSeat(playerid);

	if (!Table_IsCurrent(table,serial) || Table_GetPlayerTable(playerid) != table || !Table_IsSeatAsked(table,seat))
	{
		Gui_Notify(playerid,"That game has already started or been called off.");
		return;
	}

	if (pick == 1)
	{
		if (Table_Accept(table,seat))
		{
			Gui_Notify(playerid,"You're in. The game starts when everyone has answered.");
			format(line,sizeof(line),"%s is in.",name);
		}
		else
		{
			format(line,sizeof(line),"You don't have %d pfennig for the stake.",Table_GetStake(table));
			Table_Notify(playerid,line);
			format(line,sizeof(line),"%s can't cover the stake.",name);
		}
	}
	else
	{
		Table_Decline(table,seat);
		Table_NoteRefusal(playerid,host);
		format(line,sizeof(line),"%s turned down your challenge.",name);
	}

	Table_Notify(host,line);
	Table_CheckGathering(table);
}

forward Table_OpenSetupDeferred(playerid,game,regular);

public Table_OpenSetupDeferred(playerid,game,regular)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && Table_GetPlayerTable(playerid) == TABLE_EMPTY && Table_IsGameRegistered(game))
	{
		Table_RunSetup(playerid,game,regular);
	}
}

forward Table_ChooseDeferred(playerid,regular);

public Table_ChooseDeferred(playerid,regular)
{
	yield 1;

	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, name[TABLE_TITLE_LEN], rows = 0;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,TABLE_GAMES_TITLE);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,220.0,KIT_ROW * float(TABLE_GAME_COUNT + 1) + 8.0,TABLE_GAMES_TITLE,x,y,width);

	for (new game = TABLE_GAME_NONE + 1;game < TABLE_GAME_COUNT;game++)
	{
		if (Table_IsGameRegistered(game) && (regular != TABLE_EMPTY || Table_HasGameItem(playerid,game)))
		{
			Table_GetGameName(game,name);
			name[0] = toupper(name[0]);
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,name,TABLE_PICK_GAME + game);
		}
	}

	Kit_AddButton(playerid,x + width * 0.55,y + KIT_ROW * float(rows) + 6.0,width * 0.45,"Back",KIT_BACK);
	new pick = await Kit_Present(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return;
	}

	if (pick > TABLE_PICK_GAME && pick < TABLE_PICK_GAME + TABLE_GAME_COUNT && Table_GetPlayerTable(playerid) == TABLE_EMPTY)
	{
		Table_RunSetup(playerid,pick - TABLE_PICK_GAME,regular);
		return;
	}

	Kit_Close(playerid);
}

forward Table_GatherDeferred(playerid,table,serial);

public Table_GatherDeferred(playerid,table,serial)
{
	yield 1;

	if (IsPlayerConnected(playerid) && !Gui_IsBusy(playerid))
	{
		Table_RunGathering(playerid,table,serial);
	}
}

forward Table_PokeDeferred(playerid,token);

public Table_PokeDeferred(playerid,token)
{
	new title[KIT_TITLE_LEN];

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || !Kit_IsOpen(playerid))
	{
		return 1;
	}

	Kit_GetTitle(playerid,title);

	if (!strcmp(title,TABLE_GATHER_TITLE))
	{
		Kit_Pick(playerid,TABLE_PICK_REFRESH);
	}

	return 1;
}

forward Table_OpenGamesDeferred(playerid);

public Table_OpenGamesDeferred(playerid)
{
	if (!IsPlayerConnected(playerid) || !Session_IsPlaying(playerid))
	{
		return 1;
	}

	new table = Table_GetPlayerTable(playerid);

	if (table != TABLE_EMPTY)
	{
		if (Table_GetState(table) == TABLE_GATHERING && Table_GetPlayerSeat(playerid) == 0)
		{
			SetTimerEx("Table_GatherDeferred",0,false,"ddd",playerid,table,Table_GetSerial(table));
		}
		else
		{
			pawn_call_public("Table_OnReopen","dd",table,playerid);
		}

		return 1;
	}

	new first = TABLE_GAME_NONE, count = 0;

	for (new game = TABLE_GAME_NONE + 1;game < TABLE_GAME_COUNT;game++)
	{
		if (Table_HasGameItem(playerid,game))
		{
			if (first == TABLE_GAME_NONE)
			{
				first = game;
			}

			count++;
		}
	}

	if (count == 1)
	{
		SetTimerEx("Table_OpenSetupDeferred",0,false,"ddd",playerid,first,TABLE_EMPTY);
		return 1;
	}

	if (count > 1)
	{
		SetTimerEx("Table_ChooseDeferred",0,false,"dd",playerid,TABLE_EMPTY);
		return 1;
	}

	Gui_Notify(playerid,"You need a set of dice to start a game. A carpenter can carve you one. You can also play a regular in a tavern.");
	return 1;
}

forward Table_OnReopen(table,playerid);

public Table_OnReopen(table,playerid)
{
	return 1;
}

forward Table_RegularPromptTick();

public Table_RegularPromptTick()
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Table_UpdateRegularPrompt(playerid);
		}
	}

	return 1;
}

forward bool:Table_RegularContext(playerid);

public bool:Table_RegularContext(playerid)
{
	return s_TableRegularPrompt[playerid] != TABLE_EMPTY;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Table_ResetRefusals(playerid);
	s_TableRegularPrompt[playerid] = TABLE_EMPTY;
	s_TableRegularPromptInfobox[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	s_TableRegularPrompt[playerid] = TABLE_EMPTY;
	s_TableRegularPromptInfobox[playerid] = 0;
}

hook Table_OnChanged(table)
{
	Table_PokeHost(table);
}

hook Table_OnStarted(table)
{
	Table_PokeHost(table);
}

hook Table_OnClosing(table,winner)
{
	#pragma unused winner

	Table_PokeHost(table);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !(newkeys & KEY_WALK) && s_TableRegularPrompt[playerid] != TABLE_EMPTY && !Infobox_IsPromptBlocked(playerid,s_TableRegularPromptInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		new regular = s_TableRegularPrompt[playerid];
		Table_ClearRegularPrompt(playerid);
		SetTimerEx("Table_ChooseDeferred",0,false,"dd",playerid,regular);
	}
}
