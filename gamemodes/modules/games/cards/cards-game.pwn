enum E_CARDS_GAME
{
	E_CARDS_SERIAL,
	E_CARDS_STEP,
	E_CARDS_DEALER,
	E_CARDS_ACTOR,
	E_CARDS_LEVEL,
	E_CARDS_DECK_POS,
	E_CARDS_MIDDLE,
	E_CARDS_DEADLINE,
	E_CARDS_TURNS,
}

static s_CardsGames[TABLE_MAX][E_CARDS_GAME];
static s_CardsDeck[TABLE_MAX][CARDS_DECK];
static s_CardsHands[TABLE_MAX][TABLE_SEATS];
static s_CardsPaidRound[TABLE_MAX][TABLE_SEATS];
static bool:s_CardsFolded[TABLE_MAX][TABLE_SEATS];
static bool:s_CardsActed[TABLE_MAX][TABLE_SEATS];
static s_CardsBurned[TABLE_MAX][CARDS_BURN];
static s_CardsNextDeck[CARDS_DECK];
static bool:s_CardsNextDeckSet;

stock bool:Cards_IsRunning(table)
{
	return Table_GetGame(table) == TABLE_GAME_CARDS && Table_GetState(table) == TABLE_PLAYING && s_CardsGames[table][E_CARDS_SERIAL] != 0 && s_CardsGames[table][E_CARDS_SERIAL] == Table_GetSerial(table);
}

stock Cards_GetStep(table)
{
	return s_CardsGames[table][E_CARDS_STEP];
}

stock Cards_GetActor(table)
{
	return s_CardsGames[table][E_CARDS_ACTOR];
}

stock Cards_GetTurns(table)
{
	return s_CardsGames[table][E_CARDS_TURNS];
}

stock Cards_GetLevel(table)
{
	return s_CardsGames[table][E_CARDS_LEVEL];
}

stock Cards_GetMiddle(table)
{
	return s_CardsGames[table][E_CARDS_MIDDLE];
}

stock Cards_GetHand(table,seat)
{
	return s_CardsHands[table][seat];
}

stock Cards_GetBurned(table,index)
{
	return s_CardsBurned[table][index];
}

stock Cards_GetLeft(table)
{
	return CARDS_DECK - s_CardsGames[table][E_CARDS_DECK_POS];
}

stock bool:Cards_HasFolded(table,seat)
{
	return s_CardsFolded[table][seat];
}

stock Cards_GetOwed(table,seat)
{
	return max(0,s_CardsGames[table][E_CARDS_LEVEL] - s_CardsPaidRound[table][seat]);
}

stock Cards_GetSecondsLeft(table)
{
	return max(0,(s_CardsGames[table][E_CARDS_DEADLINE] - GetTickCount() + 999) / 1000);
}

stock bool:Cards_IsActive(table,seat)
{
	return Table_IsSeatIn(table,seat) && !s_CardsFolded[table][seat];
}

stock Cards_CountActive(table)
{
	new count = 0;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Cards_IsActive(table,seat))
		{
			count++;
		}
	}

	return count;
}

stock bool:Cards_CanRaise(table,seat)
{
	return Table_GetSeatPaid(table,seat) + Cards_GetOwed(table,seat) + Table_GetStake(table) <= TABLE_STAKE_MAX;
}

stock Cards_RigNextDeck(const deck[CARDS_DECK])
{
	for (new i = 0;i < CARDS_DECK;i++)
	{
		s_CardsNextDeck[i] = deck[i];
	}

	s_CardsNextDeckSet = true;
}

stock bool:Cards_NpcShouldMeet(style,paid,owed)
{
	switch (style)
	{
		case TABLE_STYLE_CAREFUL:
		{
			return false;
		}
		case TABLE_STYLE_EVEN:
		{
			return paid + owed <= TABLE_STAKE_MAX / 2;
		}
	}

	return true;
}

stock bool:Cards_NpcShouldRaise(style,roll)
{
	switch (style)
	{
		case TABLE_STYLE_CAREFUL:
		{
			return false;
		}
		case TABLE_STYLE_EVEN:
		{
			return roll < 15;
		}
	}

	return roll < 40;
}

static Cards_Changed(table)
{
	pawn_call_public("Cards_OnChanged","d",table);
}

static Cards_NextActive(table,seat)
{
	for (new step = 1;step <= TABLE_SEATS;step++)
	{
		new next = (seat + step) % TABLE_SEATS;

		if (Cards_IsActive(table,next))
		{
			return next;
		}
	}

	return -1;
}

static Cards_NeedsToAct(table,seat)
{
	return Cards_IsActive(table,seat) && (!s_CardsActed[table][seat] || s_CardsPaidRound[table][seat] < s_CardsGames[table][E_CARDS_LEVEL]);
}

static Cards_StartActor(table,seat)
{
	s_CardsGames[table][E_CARDS_ACTOR] = seat;
	s_CardsGames[table][E_CARDS_TURNS]++;
	s_CardsGames[table][E_CARDS_DEADLINE] = GetTickCount() + CARDS_TURN_MS;
	Cards_Changed(table);
	pawn_call_public("Cards_OnTurn","dd",table,seat);
}

static Cards_StartBetting(table,step)
{
	s_CardsGames[table][E_CARDS_STEP] = step;
	s_CardsGames[table][E_CARDS_LEVEL] = 0;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		s_CardsPaidRound[table][seat] = 0;
		s_CardsActed[table][seat] = false;
	}

	Cards_StartActor(table,Cards_NextActive(table,s_CardsGames[table][E_CARDS_DEALER]));
}

static Cards_Win(table,winners)
{
	new line[TABLE_LINE_LEN], name[TABLE_NAME_LEN], pot = Table_GetPot(table), count = Table_CountBits(winners);

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if ((winners & (1 << seat)) == 0)
		{
			continue;
		}

		new playerid = Table_GetSeatPlayer(table,seat);
		Table_GetSeatName(table,seat,name);

		if (count > 1)
		{
			format(line,sizeof(line),"%s shares the pot and takes %d pfennig.",name,pot / count);
		}
		else
		{
			format(line,sizeof(line),"%s wins the pot of %d pfennig.",name,pot);
		}

		Table_Log(table,line);

		if (playerid != INVALID_PLAYER_ID)
		{
			format(line,sizeof(line),count > 1 ? ("You share the pot and take %d pfennig.") : ("You won the pot of %d pfennig!"),pot / count);
			Table_Notify(playerid,line);
		}
	}

	Table_FinishSplit(table,winners);
}

static Cards_Showdown(table)
{
	new best = -1, name[TABLE_NAME_LEN], card[CARDS_NAME_LEN], line[TABLE_LINE_LEN];

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Cards_IsActive(table,seat) && (best == -1 || Cards_Compare(s_CardsHands[table][seat],s_CardsHands[table][best]) > 0))
		{
			best = seat;
		}
	}

	if (best == -1)
	{
		Table_Close(table);
		return;
	}

	Table_GetSeatName(table,best,name);
	Cards_Name(s_CardsHands[table][best],card);
	format(line,sizeof(line),"The deck has run out. %s has the highest card, the %s.",name,card);
	Table_Log(table,line);
	Cards_Win(table,1 << best);
}

static Cards_Burn(table)
{
	new names[CARDS_BURN][CARDS_NAME_LEN], line[TABLE_LINE_LEN];

	for (new i = 0;i < CARDS_BURN;i++)
	{
		s_CardsBurned[table][i] = s_CardsDeck[table][s_CardsGames[table][E_CARDS_DECK_POS]++];
		Cards_Name(s_CardsBurned[table][i],names[i]);
	}

	format(line,sizeof(line),"Three cards go to the discard pile: the %s, the %s and the %s.",names[0],names[1],names[2]);
	Table_Log(table,line);
}

static Cards_Turn(table)
{
	new card[CARDS_NAME_LEN], line[TABLE_LINE_LEN], middle = s_CardsDeck[table][s_CardsGames[table][E_CARDS_DECK_POS]++], winners = 0;
	s_CardsGames[table][E_CARDS_MIDDLE] = middle;
	Cards_Name(middle,card);
	format(line,sizeof(line),"The middle card is the %s.",card);
	Table_Log(table,line);

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Cards_IsActive(table,seat) && Cards_Matches(s_CardsHands[table][seat],middle))
		{
			winners |= 1 << seat;
		}
	}

	if (winners != 0)
	{
		Cards_Win(table,winners);
		return;
	}

	Cards_StartBetting(table,CARDS_STEP_BET_LOOP);
}

static Cards_EndBetting(table)
{
	new step = s_CardsGames[table][E_CARDS_STEP], needed = step == CARDS_STEP_BET_BURN ? 1 : (step == CARDS_STEP_BET_DEAL ? CARDS_BURN : CARDS_BURN + 1);

	if (Cards_GetLeft(table) < needed)
	{
		Cards_Showdown(table);
		return;
	}

	switch (step)
	{
		case CARDS_STEP_BET_DEAL:
		{
			Cards_Burn(table);
			Cards_StartBetting(table,CARDS_STEP_BET_BURN);
		}
		case CARDS_STEP_BET_BURN:
		{
			Cards_Turn(table);
		}
		default:
		{
			Cards_Burn(table);
			Cards_Turn(table);
		}
	}
}

static Cards_Advance(table)
{
	new active = Cards_CountActive(table);

	if (active == 1)
	{
		Cards_Win(table,1 << Cards_NextActive(table,TABLE_SEATS - 1));
		return;
	}

	if (active == 0)
	{
		Table_Close(table);
		return;
	}

	new next = s_CardsGames[table][E_CARDS_ACTOR];

	for (new step = 1;step <= TABLE_SEATS;step++)
	{
		next = (s_CardsGames[table][E_CARDS_ACTOR] + step) % TABLE_SEATS;

		if (Cards_NeedsToAct(table,next))
		{
			Cards_StartActor(table,next);
			return;
		}
	}

	Cards_EndBetting(table);
}

stock Cards_Begin(table)
{
	s_CardsGames[table][E_CARDS_SERIAL] = Table_GetSerial(table);
	s_CardsGames[table][E_CARDS_TURNS] = 0;
	s_CardsGames[table][E_CARDS_DECK_POS] = 0;
	s_CardsGames[table][E_CARDS_MIDDLE] = CARDS_NONE;
	s_CardsGames[table][E_CARDS_DEALER] = Table_FirstSeatIn(table,true);

	if (s_CardsNextDeckSet)
	{
		for (new i = 0;i < CARDS_DECK;i++)
		{
			s_CardsDeck[table][i] = s_CardsNextDeck[i];
		}

		s_CardsNextDeckSet = false;
	}
	else
	{
		Cards_Shuffle(s_CardsDeck[table]);
	}

	for (new i = 0;i < CARDS_BURN;i++)
	{
		s_CardsBurned[table][i] = CARDS_NONE;
	}

	new line[TABLE_LINE_LEN], name[TABLE_NAME_LEN], card[CARDS_NAME_LEN], dealer = s_CardsGames[table][E_CARDS_DEALER];
	format(line,sizeof(line),"A hand of Lansquenet starts. The pot is %d pfennig.",Table_GetPot(table));
	Table_Log(table,line);

	for (new step = 0;step < TABLE_SEATS;step++)
	{
		new seat = (dealer + step) % TABLE_SEATS;
		s_CardsFolded[table][seat] = false;
		s_CardsHands[table][seat] = CARDS_NONE;

		if (!Table_IsSeatIn(table,seat))
		{
			continue;
		}

		s_CardsHands[table][seat] = s_CardsDeck[table][s_CardsGames[table][E_CARDS_DECK_POS]++];
		Table_GetSeatName(table,seat,name);
		Cards_Name(s_CardsHands[table][seat],card);
		format(line,sizeof(line),"%s is dealt the %s.",name,card);
		Table_Log(table,line);
	}

	Cards_StartBetting(table,CARDS_STEP_BET_DEAL);
}

stock bool:Cards_Act(table,action)
{
	if (!Cards_IsRunning(table))
	{
		return false;
	}

	new seat = s_CardsGames[table][E_CARDS_ACTOR], owed = Cards_GetOwed(table,seat), stake = Table_GetStake(table), name[TABLE_NAME_LEN], line[TABLE_LINE_LEN];
	Table_GetSeatName(table,seat,name);

	switch (action)
	{
		case CARDS_ACT_STAY:
		{
			if (owed > 0)
			{
				return false;
			}

			format(line,sizeof(line),"%s stays.",name);
		}
		case CARDS_ACT_MEET:
		{
			if (owed <= 0)
			{
				return false;
			}

			if (!Table_AddToPot(table,seat,owed,"table raise"))
			{
				s_CardsFolded[table][seat] = true;
				format(line,sizeof(line),"%s can't meet the raise and folds.",name);
				Table_Log(table,line);
				Cards_Advance(table);
				return true;
			}

			s_CardsPaidRound[table][seat] += owed;
			format(line,sizeof(line),"%s meets the raise.",name);
		}
		case CARDS_ACT_RAISE:
		{
			if (!Cards_CanRaise(table,seat) || !Table_AddToPot(table,seat,owed + stake,"table raise"))
			{
				return false;
			}

			s_CardsGames[table][E_CARDS_LEVEL] += stake;
			s_CardsPaidRound[table][seat] = s_CardsGames[table][E_CARDS_LEVEL];

			for (new other = 0;other < TABLE_SEATS;other++)
			{
				s_CardsActed[table][other] = false;
			}

			format(line,sizeof(line),"%s raises by %d pfennig.",name,stake);
		}
		case CARDS_ACT_FOLD:
		{
			s_CardsFolded[table][seat] = true;
			format(line,sizeof(line),"%s folds.",name);
		}
		default:
		{
			return false;
		}
	}

	s_CardsActed[table][seat] = true;
	Table_Log(table,line);
	Cards_Advance(table);
	return true;
}

forward Cards_OnChanged(table);

public Cards_OnChanged(table)
{
	return 1;
}

forward Cards_OnTurn(table,seat);

public Cards_OnTurn(table,seat)
{
	return 1;
}

forward Cards_OnEnded(table,winner);

public Cards_OnEnded(table,winner)
{
	return 1;
}

forward Cards_Tick();

public Cards_Tick()
{
	new now = GetTickCount();

	for (new table = 0;table < TABLE_MAX;table++)
	{
		if (!Cards_IsRunning(table))
		{
			continue;
		}

		new seat = s_CardsGames[table][E_CARDS_ACTOR], playerid = Table_GetSeatPlayer(table,seat);

		if (Table_IsSeatRegular(table,seat) || now <= s_CardsGames[table][E_CARDS_DEADLINE])
		{
			continue;
		}

		if (Cards_GetOwed(table,seat) > 0)
		{
			Cards_Act(table,CARDS_ACT_FOLD);
			Gui_Notify(playerid,"Your time ran out. The game folded your hand.");
		}
		else
		{
			Cards_Act(table,CARDS_ACT_STAY);
			Gui_Notify(playerid,"Your time ran out. The game stayed for you.");
		}
	}

	for (new table = 0;table < TABLE_MAX;table++)
	{
		for (new seat = 0;seat < TABLE_SEATS && Cards_IsRunning(table);seat++)
		{
			new playerid = Table_GetSeatPlayer(table,seat);

			if (Table_IsSeatIn(table,seat) && playerid != INVALID_PLAYER_ID)
			{
				Cards_UpdateTimer(playerid,table);
			}
		}
	}

	return 1;
}

#include <pp-hooks>

hook Table_OnStarted(table)
{
	if (Table_GetGame(table) == TABLE_GAME_CARDS)
	{
		Cards_Begin(table);
	}
}

hook Table_OnSeatLeft(table,seat,reason)
{
	#pragma unused reason

	if (!Cards_IsRunning(table))
	{
		return;
	}

	s_CardsFolded[table][seat] = true;

	if (seat == s_CardsGames[table][E_CARDS_ACTOR])
	{
		Cards_Advance(table);
	}
	else
	{
		Cards_Changed(table);
	}
}

hook Table_OnClosing(table,winner)
{
	if (Table_GetGame(table) != TABLE_GAME_CARDS || s_CardsGames[table][E_CARDS_SERIAL] == 0)
	{
		return;
	}

	pawn_call_public("Cards_OnEnded","dd",table,winner);
	s_CardsGames[table][E_CARDS_SERIAL] = 0;
}
