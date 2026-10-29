enum E_DICE_GAME
{
	E_DICE_SERIAL,
	E_DICE_TURN,
	E_DICE_TURNS,
	E_DICE_TURN_POINTS,
	bool:E_DICE_ROLLED,
	bool:E_DICE_BUSTED,
	E_DICE_ASIDE,
	E_DICE_PICKED,
	E_DICE_DEADLINE,
	E_DICE_ROLLS,
	bool:E_DICE_RIGGED,
}

static s_DiceGames[TABLE_MAX][E_DICE_GAME];
static s_DiceFaces[TABLE_MAX][DICE_COUNT];
static s_DiceRig[TABLE_MAX][DICE_COUNT];
static s_DiceScores[TABLE_MAX][TABLE_SEATS];
static s_DiceKinds[TABLE_MAX][TABLE_SEATS][DICE_COUNT];
static bool:s_DiceLuckyUsed[TABLE_MAX][TABLE_SEATS];

stock bool:Dice_IsRunning(table)
{
	return Table_GetGame(table) == TABLE_GAME_DICE && Table_GetState(table) == TABLE_PLAYING && s_DiceGames[table][E_DICE_SERIAL] != 0 && s_DiceGames[table][E_DICE_SERIAL] == Table_GetSerial(table);
}

stock Dice_GetTurn(table)
{
	return s_DiceGames[table][E_DICE_TURN];
}

stock Dice_GetTurns(table)
{
	return s_DiceGames[table][E_DICE_TURNS];
}

stock Dice_GetTurnPoints(table)
{
	return s_DiceGames[table][E_DICE_TURN_POINTS];
}

stock bool:Dice_HasRolled(table)
{
	return s_DiceGames[table][E_DICE_ROLLED];
}

stock bool:Dice_IsBusted(table)
{
	return s_DiceGames[table][E_DICE_BUSTED];
}

stock Dice_GetAside(table)
{
	return s_DiceGames[table][E_DICE_ASIDE];
}

stock Dice_GetPicked(table)
{
	return s_DiceGames[table][E_DICE_PICKED];
}

stock Dice_GetRolls(table)
{
	return s_DiceGames[table][E_DICE_ROLLS];
}

stock Dice_GetFace(table,die)
{
	return s_DiceFaces[table][die];
}

stock Dice_GetDieKind(table,seat,die)
{
	return s_DiceKinds[table][seat][die];
}

stock Dice_GetScore(table,seat)
{
	return s_DiceScores[table][seat];
}

stock Dice_GetTarget(table)
{
	new option = Table_GetOption(table);
	return g_DiceTargets[option >= 0 && option < sizeof(g_DiceTargets) ? option : 0];
}

stock Dice_GetSecondsLeft(table)
{
	return max(0,(s_DiceGames[table][E_DICE_DEADLINE] - GetTickCount() + 999) / 1000);
}

stock bool:Dice_IsDieFree(table,die)
{
	return s_DiceGames[table][E_DICE_ROLLED] && (s_DiceGames[table][E_DICE_ASIDE] & (1 << die)) == 0;
}

stock bool:Dice_SeatHasKind(table,seat,kind)
{
	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (s_DiceKinds[table][seat][die] == kind)
		{
			return true;
		}
	}

	return false;
}

stock Dice_ScoreMask(table,mask)
{
	new faces[DICE_COUNT], count = 0, seat = s_DiceGames[table][E_DICE_TURN];

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (mask & (1 << die))
		{
			faces[count++] = Dice_ScoringFace(s_DiceKinds[table][seat][die],s_DiceFaces[table][die]);
		}
	}

	return count == 0 ? -1 : Dice_Score(faces,count);
}

stock Dice_PickScore(table)
{
	return Dice_ScoreMask(table,s_DiceGames[table][E_DICE_PICKED]);
}

stock Dice_FreeMask(table)
{
	return DICE_ALL & ~s_DiceGames[table][E_DICE_ASIDE];
}

stock Dice_CountMask(mask)
{
	new count = 0;

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (mask & (1 << die))
		{
			count++;
		}
	}

	return count;
}

stock Dice_BestPick(table)
{
	new faces[DICE_COUNT], index[DICE_COUNT], count = 0, used = 0, seat = s_DiceGames[table][E_DICE_TURN], free = Dice_FreeMask(table);

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (free & (1 << die))
		{
			index[count] = die;
			faces[count++] = Dice_ScoringFace(s_DiceKinds[table][seat][die],s_DiceFaces[table][die]);
		}
	}

	Dice_BestScore(faces,count,used);

	new mask = 0;

	for (new i = 0;i < count;i++)
	{
		if (used & (1 << i))
		{
			mask |= 1 << index[i];
		}
	}

	return mask;
}

stock bool:Dice_NpcShouldBank(style,turnTotal,remaining,score,target)
{
	if (score + turnTotal >= target)
	{
		return true;
	}

	if (remaining == 0)
	{
		return false;
	}

	if (turnTotal >= g_DiceStyleBankAt[style])
	{
		return true;
	}

	return remaining < g_DiceStyleMinDice[style];
}

stock Dice_RigNextRoll(table,const faces[DICE_COUNT])
{
	for (new die = 0;die < DICE_COUNT;die++)
	{
		s_DiceRig[table][die] = faces[die];
	}

	s_DiceGames[table][E_DICE_RIGGED] = true;
}

stock Dice_SetPicked(table,mask)
{
	if (!Dice_IsRunning(table) || !s_DiceGames[table][E_DICE_ROLLED] || s_DiceGames[table][E_DICE_BUSTED])
	{
		return;
	}

	s_DiceGames[table][E_DICE_PICKED] = mask & Dice_FreeMask(table);
	Dice_Changed(table);
}

static Dice_Changed(table)
{
	pawn_call_public("Dice_OnChanged","d",table);
}

static Dice_LoadKinds(table,seat)
{
	for (new die = 0;die < DICE_COUNT;die++)
	{
		s_DiceKinds[table][seat][die] = DICE_KIND_PLAIN;
	}

	new playerid = Table_GetSeatPlayer(table,seat), slot = 0;

	if (playerid == INVALID_PLAYER_ID || !Table_IsSeatIn(table,seat))
	{
		return;
	}

	for (new i = 0;i < sizeof(g_DiceSpecialOrder) && slot < DICE_COUNT;i++)
	{
		new kind = g_DiceSpecialOrder[i];

		for (new have = Inventory_Count(playerid,DICE_ITEM_KIND,g_DiceKindItems[kind]);have > 0 && slot < DICE_COUNT;have--)
		{
			s_DiceKinds[table][seat][slot++] = kind;
		}
	}
}

static Dice_SeatName(table,seat,dest[],size = sizeof(dest))
{
	Table_GetSeatName(table,seat,dest,size);
}

static Dice_StartTurn(table,seat)
{
	s_DiceGames[table][E_DICE_TURN] = seat;
	s_DiceGames[table][E_DICE_TURNS]++;
	s_DiceGames[table][E_DICE_TURN_POINTS] = 0;
	s_DiceGames[table][E_DICE_ROLLED] = false;
	s_DiceGames[table][E_DICE_BUSTED] = false;
	s_DiceGames[table][E_DICE_ASIDE] = 0;
	s_DiceGames[table][E_DICE_PICKED] = 0;
	s_DiceGames[table][E_DICE_DEADLINE] = GetTickCount() + DICE_TURN_MS;
	Dice_Changed(table);
	pawn_call_public("Dice_OnTurn","dd",table,seat);
}

static Dice_NextTurn(table)
{
	new next = Table_NextSeatIn(table,s_DiceGames[table][E_DICE_TURN]);

	if (next != -1)
	{
		Dice_StartTurn(table,next);
	}
}

stock Dice_Begin(table)
{
	s_DiceGames[table][E_DICE_SERIAL] = Table_GetSerial(table);
	s_DiceGames[table][E_DICE_TURNS] = 0;
	s_DiceGames[table][E_DICE_ROLLS] = 0;
	s_DiceGames[table][E_DICE_RIGGED] = false;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		s_DiceScores[table][seat] = 0;
		s_DiceLuckyUsed[table][seat] = false;
		Dice_LoadKinds(table,seat);
	}

	for (new die = 0;die < DICE_COUNT;die++)
	{
		s_DiceFaces[table][die] = die + 1;
	}

	new line[TABLE_LINE_LEN];
	format(line,sizeof(line),"A game of dice starts. The first to %d points wins the pot of %d pfennig.",Dice_GetTarget(table),Table_GetPot(table));
	Table_Log(table,line);
	Dice_StartTurn(table,Table_FirstSeatIn(table,true));
}

static Dice_RollFree(table)
{
	new seat = s_DiceGames[table][E_DICE_TURN], free = Dice_FreeMask(table);

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (free & (1 << die))
		{
			s_DiceFaces[table][die] = s_DiceGames[table][E_DICE_RIGGED] ? s_DiceRig[table][die] : Dice_RollFace(s_DiceKinds[table][seat][die]);
		}
	}

	s_DiceGames[table][E_DICE_RIGGED] = false;
}

static bool:Dice_FreeScores(table)
{
	new faces[DICE_COUNT], count = 0, seat = s_DiceGames[table][E_DICE_TURN], free = Dice_FreeMask(table);

	for (new die = 0;die < DICE_COUNT;die++)
	{
		if (free & (1 << die))
		{
			faces[count++] = Dice_ScoringFace(s_DiceKinds[table][seat][die],s_DiceFaces[table][die]);
		}
	}

	return Dice_HasScore(faces,count);
}

static Dice_Bust(table)
{
	new seat = s_DiceGames[table][E_DICE_TURN], name[TABLE_NAME_LEN], line[TABLE_LINE_LEN], lost = s_DiceGames[table][E_DICE_TURN_POINTS];
	Dice_SeatName(table,seat,name);
	s_DiceGames[table][E_DICE_BUSTED] = true;
	s_DiceGames[table][E_DICE_TURN_POINTS] = 0;

	if (lost > 0)
	{
		format(line,sizeof(line),"%s rolls nothing that scores and loses %d points.",name,lost);
	}
	else
	{
		format(line,sizeof(line),"%s rolls nothing that scores.",name);
	}

	Table_Log(table,line);
	SetTimerEx("Dice_PassDeferred",DICE_BUST_PAUSE_MS,false,"ddd",table,s_DiceGames[table][E_DICE_SERIAL],s_DiceGames[table][E_DICE_TURNS]);
}

stock bool:Dice_Roll(table)
{
	if (!Dice_IsRunning(table) || s_DiceGames[table][E_DICE_BUSTED])
	{
		return false;
	}

	new seat = s_DiceGames[table][E_DICE_TURN], name[TABLE_NAME_LEN], line[TABLE_LINE_LEN];
	Dice_SeatName(table,seat,name);

	if (s_DiceGames[table][E_DICE_ROLLED])
	{
		new score = Dice_PickScore(table);

		if (score <= 0)
		{
			return false;
		}

		s_DiceGames[table][E_DICE_TURN_POINTS] += score;
		s_DiceGames[table][E_DICE_ASIDE] |= s_DiceGames[table][E_DICE_PICKED];
		s_DiceGames[table][E_DICE_PICKED] = 0;

		if (s_DiceGames[table][E_DICE_ASIDE] == DICE_ALL)
		{
			s_DiceGames[table][E_DICE_ASIDE] = 0;
			format(line,sizeof(line),"%s set all six dice aside and rolls all six again.",name);
			Table_Log(table,line);
		}
	}

	s_DiceGames[table][E_DICE_ROLLED] = true;
	s_DiceGames[table][E_DICE_ROLLS]++;
	s_DiceGames[table][E_DICE_DEADLINE] = GetTickCount() + DICE_TURN_MS;
	Dice_RollFree(table);

	if (!Dice_FreeScores(table) && !s_DiceLuckyUsed[table][seat] && Dice_SeatHasKind(table,seat,DICE_KIND_LUCKY))
	{
		s_DiceLuckyUsed[table][seat] = true;
		Dice_RollFree(table);
		format(line,sizeof(line),"%s's lucky die saves a bust. The dice are rolled again.",name);
		Table_Log(table,line);
	}

	if (!Dice_FreeScores(table))
	{
		Dice_Bust(table);
	}

	Dice_Changed(table);
	return true;
}

stock bool:Dice_TogglePick(table,die)
{
	if (!Dice_IsRunning(table) || die < 0 || die >= DICE_COUNT || s_DiceGames[table][E_DICE_BUSTED] || !Dice_IsDieFree(table,die))
	{
		return false;
	}

	s_DiceGames[table][E_DICE_PICKED] ^= 1 << die;
	Dice_Changed(table);
	return true;
}

static Dice_Win(table,seat)
{
	new name[TABLE_NAME_LEN], line[TABLE_LINE_LEN], pot = Table_GetPot(table), winner = Table_GetSeatPlayer(table,seat);
	Dice_SeatName(table,seat,name);
	format(line,sizeof(line),"%s reaches %d points and wins the pot of %d pfennig.",name,s_DiceScores[table][seat],pot);
	Table_Log(table,line);
	format(line,sizeof(line),"%s won the game of dice.",name);
	Table_NotifySeats(table,line,seat);

	if (winner != INVALID_PLAYER_ID)
	{
		format(line,sizeof(line),"You won the pot of %d pfennig!",pot);
		Table_Notify(winner,line);
	}

	Table_Finish(table,seat);
}

stock bool:Dice_Bank(table)
{
	if (!Dice_IsRunning(table) || !s_DiceGames[table][E_DICE_ROLLED] || s_DiceGames[table][E_DICE_BUSTED])
	{
		return false;
	}

	new score = Dice_PickScore(table);

	if (score <= 0)
	{
		return false;
	}

	new seat = s_DiceGames[table][E_DICE_TURN], name[TABLE_NAME_LEN], line[TABLE_LINE_LEN];
	s_DiceGames[table][E_DICE_TURN_POINTS] += score;
	s_DiceScores[table][seat] += s_DiceGames[table][E_DICE_TURN_POINTS];
	Dice_SeatName(table,seat,name);
	format(line,sizeof(line),"%s banks %d and has %d.",name,s_DiceGames[table][E_DICE_TURN_POINTS],s_DiceScores[table][seat]);
	Table_Log(table,line);

	if (s_DiceScores[table][seat] >= Dice_GetTarget(table))
	{
		Dice_Win(table,seat);
		return true;
	}

	Dice_NextTurn(table);
	return true;
}

static Dice_AutoMove(table)
{
	new seat = s_DiceGames[table][E_DICE_TURN], playerid = Table_GetSeatPlayer(table,seat);

	if (!s_DiceGames[table][E_DICE_ROLLED])
	{
		Dice_Roll(table);
		Gui_Notify(playerid,"Your time ran out. The game rolled for you.");
		return;
	}

	s_DiceGames[table][E_DICE_PICKED] = Dice_BestPick(table);
	Dice_Bank(table);
	Gui_Notify(playerid,"Your time ran out. The game banked your best dice for you.");
}

forward Dice_OnChanged(table);

public Dice_OnChanged(table)
{
	return 1;
}

forward Dice_OnTurn(table,seat);

public Dice_OnTurn(table,seat)
{
	return 1;
}

forward Dice_OnEnded(table,winner);

public Dice_OnEnded(table,winner)
{
	return 1;
}

forward Dice_PassDeferred(table,serial,turns);

public Dice_PassDeferred(table,serial,turns)
{
	if (Dice_IsRunning(table) && s_DiceGames[table][E_DICE_SERIAL] == serial && s_DiceGames[table][E_DICE_TURNS] == turns && s_DiceGames[table][E_DICE_BUSTED])
	{
		Dice_NextTurn(table);
	}

	return 1;
}

forward Dice_Tick();

public Dice_Tick()
{
	new now = GetTickCount();

	for (new table = 0;table < TABLE_MAX;table++)
	{
		if (!Dice_IsRunning(table))
		{
			continue;
		}

		new seat = s_DiceGames[table][E_DICE_TURN];

		if (!s_DiceGames[table][E_DICE_BUSTED] && !Table_IsSeatRegular(table,seat) && now > s_DiceGames[table][E_DICE_DEADLINE])
		{
			Dice_AutoMove(table);
		}

		for (new other = 0;other < TABLE_SEATS && Dice_IsRunning(table);other++)
		{
			new playerid = Table_GetSeatPlayer(table,other);

			if (Table_IsSeatIn(table,other) && playerid != INVALID_PLAYER_ID)
			{
				Dice_UpdateTimer(playerid,table);
			}
		}
	}

	return 1;
}

#include <pp-hooks>

hook Table_OnStarted(table)
{
	if (Table_GetGame(table) == TABLE_GAME_DICE)
	{
		Dice_Begin(table);
	}
}

hook Table_OnSeatLeft(table,seat,reason)
{
	#pragma unused reason

	if (!Dice_IsRunning(table))
	{
		return;
	}

	if (seat == s_DiceGames[table][E_DICE_TURN])
	{
		Dice_NextTurn(table);
	}
	else
	{
		Dice_Changed(table);
	}
}

hook Table_OnClosing(table,winner)
{
	if (Table_GetGame(table) != TABLE_GAME_DICE || s_DiceGames[table][E_DICE_SERIAL] == 0)
	{
		return;
	}

	pawn_call_public("Dice_OnEnded","dd",table,winner);
	s_DiceGames[table][E_DICE_SERIAL] = 0;
}
