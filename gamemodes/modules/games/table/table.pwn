enum E_TABLE
{
	E_TABLE_STATE,
	E_TABLE_GAME,
	E_TABLE_STAKE,
	E_TABLE_POT,
	E_TABLE_OPTION,
	E_TABLE_ROW,
	E_TABLE_SERIAL,
	bool:E_TABLE_WITH_REGULAR,
	Float:E_TABLE_X,
	Float:E_TABLE_Y,
	Float:E_TABLE_Z,
	Float:E_TABLE_ANGLE,
	E_TABLE_WORLD,
	E_TABLE_INTERIOR,
}

enum E_TABLE_SEAT
{
	E_TABLE_SEAT_PLAYER,
	E_TABLE_SEAT_TOKEN,
	E_TABLE_SEAT_REGULAR,
	E_TABLE_SEAT_CHARACTER,
	E_TABLE_SEAT_PAID,
	bool:E_TABLE_SEAT_IN,
	bool:E_TABLE_SEAT_LEFT,
	E_TABLE_SEAT_ASKED_UNTIL,
}

enum E_TABLE_GAME_DEF
{
	E_TABLE_GAME_DEF_NAME[TABLE_TITLE_LEN],
	E_ITEM_KIND:E_TABLE_GAME_DEF_KIND,
	E_TABLE_GAME_DEF_ITEM,
	E_TABLE_GAME_DEF_OPTION_LABEL[TABLE_OPTION_LEN],
	E_TABLE_GAME_DEF_OPTIONS[TABLE_OPTIONS_LEN],
	E_TABLE_GAME_DEF_OFFER[TABLE_OFFER_LEN],
	bool:E_TABLE_GAME_DEF_USED,
}

static s_Tables[TABLE_MAX][E_TABLE];
static s_TableSeats[TABLE_MAX][TABLE_SEATS][E_TABLE_SEAT];
static s_TableSeatNames[TABLE_MAX][TABLE_SEATS][TABLE_NAME_LEN];
static s_TableOffers[TABLE_MAX][TABLE_LINE_LEN];
static s_TablePlayer[MAX_PLAYERS] = {TABLE_EMPTY, ...};
static s_TableGames[TABLE_GAME_COUNT][E_TABLE_GAME_DEF];
static s_TableSerial;

stock bool:Table_RegisterGame(game,const name[],E_ITEM_KIND:kind,item,const offer[],const optionLabel[] = "",const options[] = "")
{
	if (game <= TABLE_GAME_NONE || game >= TABLE_GAME_COUNT)
	{
		return false;
	}

	strcopy(s_TableGames[game][E_TABLE_GAME_DEF_NAME],name,TABLE_TITLE_LEN);
	s_TableGames[game][E_TABLE_GAME_DEF_KIND] = kind;
	s_TableGames[game][E_TABLE_GAME_DEF_ITEM] = item;
	strcopy(s_TableGames[game][E_TABLE_GAME_DEF_OFFER],offer,TABLE_OFFER_LEN);
	strcopy(s_TableGames[game][E_TABLE_GAME_DEF_OPTION_LABEL],optionLabel,TABLE_OPTION_LEN);
	strcopy(s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS],options,TABLE_OPTIONS_LEN);
	s_TableGames[game][E_TABLE_GAME_DEF_USED] = true;
	return true;
}

stock bool:Table_IsGameRegistered(game)
{
	return game > TABLE_GAME_NONE && game < TABLE_GAME_COUNT && s_TableGames[game][E_TABLE_GAME_DEF_USED];
}

stock Table_CountGameOptions(game)
{
	if (!Table_IsGameRegistered(game) || s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS][0] == EOS)
	{
		return 0;
	}

	new count = 1;

	for (new i = 0;s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS][i] != EOS;i++)
	{
		if (s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS][i] == '|')
		{
			count++;
		}
	}

	return count;
}

stock Table_GetGameOption(game,index,dest[],size = sizeof(dest))
{
	new current = 0, length = 0;
	dest[0] = EOS;

	if (!Table_IsGameRegistered(game))
	{
		return;
	}

	for (new i = 0;s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS][i] != EOS;i++)
	{
		new c = s_TableGames[game][E_TABLE_GAME_DEF_OPTIONS][i];

		if (c == '|')
		{
			current++;
			continue;
		}

		if (current == index && length < size - 1)
		{
			dest[length++] = c;
		}
	}

	dest[length] = EOS;
}

stock Table_GetGameOptionLabel(game,dest[],size = sizeof(dest))
{
	if (!Table_IsGameRegistered(game))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_TableGames[game][E_TABLE_GAME_DEF_OPTION_LABEL],size);
}

stock Table_FormatOffer(game,option,dest[],size = sizeof(dest))
{
	if (strfind(s_TableGames[game][E_TABLE_GAME_DEF_OFFER],"%") == -1)
	{
		strcopy(dest,s_TableGames[game][E_TABLE_GAME_DEF_OFFER],size);
		return;
	}

	new value[TABLE_OPTION_LEN];
	Table_GetGameOption(game,option,value);
	format(dest,size,s_TableGames[game][E_TABLE_GAME_DEF_OFFER],value);
}

stock Table_GetGameName(game,dest[],size = sizeof(dest))
{
	if (game <= TABLE_GAME_NONE || game >= TABLE_GAME_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_TableGames[game][E_TABLE_GAME_DEF_NAME],size);
}

stock bool:Table_HasGameItem(playerid,game)
{
	if (!Table_IsGameRegistered(game))
	{
		return false;
	}

	return Inventory_Count(playerid,s_TableGames[game][E_TABLE_GAME_DEF_KIND],s_TableGames[game][E_TABLE_GAME_DEF_ITEM]) > 0;
}

stock bool:Table_IsValid(table)
{
	return table >= 0 && table < TABLE_MAX && s_Tables[table][E_TABLE_STATE] != TABLE_FREE;
}

stock bool:Table_IsCurrent(table,serial)
{
	return Table_IsValid(table) && s_Tables[table][E_TABLE_SERIAL] == serial;
}

stock Table_GetState(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_STATE] : TABLE_FREE;
}

stock Table_GetGame(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_GAME] : TABLE_GAME_NONE;
}

stock Table_GetStake(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_STAKE] : 0;
}

stock Table_GetPot(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_POT] : 0;
}

stock Table_GetOption(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_OPTION] : 0;
}

stock Table_GetSerial(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_SERIAL] : 0;
}

stock Table_GetRow(table)
{
	return Table_IsValid(table) ? s_Tables[table][E_TABLE_ROW] : 0;
}

stock Table_GetPos(table,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	x = s_Tables[table][E_TABLE_X];
	y = s_Tables[table][E_TABLE_Y];
	z = s_Tables[table][E_TABLE_Z];
	angle = s_Tables[table][E_TABLE_ANGLE];
}

stock Table_LocalToWorld(table,Float:right,Float:ahead,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	Table_GetPos(table,x,y,z,angle);
	x += right * floatcos(-angle,degrees) + ahead * floatsin(-angle,degrees);
	y += -right * floatsin(-angle,degrees) + ahead * floatcos(-angle,degrees);
}

stock Table_GetWorld(table)
{
	return s_Tables[table][E_TABLE_WORLD];
}

stock Table_GetInterior(table)
{
	return s_Tables[table][E_TABLE_INTERIOR];
}

stock Table_SetOffer(table,const text[])
{
	if (Table_IsValid(table))
	{
		strcopy(s_TableOffers[table],text,TABLE_LINE_LEN);
	}
}

stock Table_GetOffer(table,dest[],size = sizeof(dest))
{
	if (!Table_IsValid(table))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_TableOffers[table],size);
}

stock Table_GetPlayerTable(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_TablePlayer[playerid] : TABLE_EMPTY;
}

stock Table_GetPlayerSeat(playerid)
{
	if (playerid < 0 || playerid >= MAX_PLAYERS)
	{
		return -1;
	}

	new table = s_TablePlayer[playerid];

	if (table == TABLE_EMPTY)
	{
		return -1;
	}

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] == playerid)
		{
			return seat;
		}
	}

	return -1;
}

stock Table_GetSeatPlayer(table,seat)
{
	return s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER];
}

stock Table_GetSeatRegular(table,seat)
{
	return s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];
}

stock Table_GetSeatCharacter(table,seat)
{
	return s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER];
}

stock bool:Table_IsSeatIn(table,seat)
{
	return Table_IsValid(table) && seat >= 0 && seat < TABLE_SEATS && s_TableSeats[table][seat][E_TABLE_SEAT_IN];
}

stock bool:Table_IsSeatAsked(table,seat)
{
	return Table_IsValid(table) && seat >= 0 && seat < TABLE_SEATS && !s_TableSeats[table][seat][E_TABLE_SEAT_IN] && s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] != 0;
}

stock bool:Table_HasSeatLeft(table,seat)
{
	return s_TableSeats[table][seat][E_TABLE_SEAT_LEFT];
}

stock bool:Table_IsSeatRegular(table,seat)
{
	return Table_IsSeatIn(table,seat) && s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR] != TABLE_EMPTY;
}

stock Table_GetSeatAskedLeft(table,seat)
{
	return Table_IsSeatAsked(table,seat) ? max(0,s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] - gettime()) : 0;
}

stock Table_GetSeatName(table,seat,dest[],size = sizeof(dest))
{
	strcopy(dest,s_TableSeatNames[table][seat],size);
}

stock Table_GetSeatNameFor(table,seat,viewerid,dest[],size = sizeof(dest))
{
	Nametag_Expand(viewerid,s_TableSeatNames[table][seat],dest,size);
}

stock Table_Notify(playerid,const text[])
{
	new line[256];
	Nametag_Expand(playerid,text,line);
	Gui_Notify(playerid,line);
}

stock Table_CountIn(table)
{
	new count = 0;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Table_IsSeatIn(table,seat))
		{
			count++;
		}
	}

	return count;
}

stock Table_CountHumansIn(table)
{
	new count = 0;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Table_IsSeatIn(table,seat) && s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] != INVALID_PLAYER_ID)
		{
			count++;
		}
	}

	return count;
}

stock Table_CountAsked(table)
{
	new count = 0;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Table_IsSeatAsked(table,seat))
		{
			count++;
		}
	}

	return count;
}

stock Table_CountBits(mask)
{
	new count = 0;

	for (new i = 0;i < 32;i++)
	{
		if (mask & (1 << i))
		{
			count++;
		}
	}

	return count;
}

stock Table_NextSeatIn(table,seat)
{
	for (new step = 1;step <= TABLE_SEATS;step++)
	{
		new next = (seat + step) % TABLE_SEATS;

		if (Table_IsSeatIn(table,next))
		{
			return next;
		}
	}

	return -1;
}

stock Table_FirstSeatIn(table,bool:humansFirst = false)
{
	if (humansFirst)
	{
		for (new seat = 0;seat < TABLE_SEATS;seat++)
		{
			if (Table_IsSeatIn(table,seat) && s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] != INVALID_PLAYER_ID)
			{
				return seat;
			}
		}
	}

	return Table_NextSeatIn(table,TABLE_SEATS - 1);
}

stock Table_Log(table,const line[])
{
	Chat_FromPoint(s_Tables[table][E_TABLE_X],s_Tables[table][E_TABLE_Y],s_Tables[table][E_TABLE_Z] + 1.0,s_Tables[table][E_TABLE_WORLD],s_Tables[table][E_TABLE_INTERIOR],TABLE_LOG_RANGE,CHAT_COLOUR_ACTION,line);
}

stock Table_NotifySeats(table,const text[],exceptSeat = -1)
{
	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (seat != exceptSeat && Table_IsSeatIn(table,seat) && s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] != INVALID_PLAYER_ID)
		{
			Table_Notify(s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER],text);
		}
	}
}

stock Table_PayOut(playerid,characterid,amount,const source[])
{
	Economy_GiveOrClaim(playerid,characterid,amount,source);
}

static Table_ResetSeat(table,seat)
{
	s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] = INVALID_PLAYER_ID;
	s_TableSeats[table][seat][E_TABLE_SEAT_TOKEN] = 0;
	s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR] = TABLE_EMPTY;
	s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER] = 0;
	s_TableSeats[table][seat][E_TABLE_SEAT_PAID] = 0;
	s_TableSeats[table][seat][E_TABLE_SEAT_IN] = false;
	s_TableSeats[table][seat][E_TABLE_SEAT_LEFT] = false;
	s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] = 0;
	s_TableSeatNames[table][seat][0] = EOS;
}

static Table_Free(table)
{
	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER], regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];

		if (Util_IsValidPlayer(playerid) && s_TablePlayer[playerid] == table)
		{
			s_TablePlayer[playerid] = TABLE_EMPTY;
		}

		if (regular != TABLE_EMPTY && Table_GetRegularTable(regular) == table)
		{
			Table_SetRegularTable(regular,TABLE_EMPTY);
		}

		Table_ResetSeat(table,seat);
	}

	s_Tables[table][E_TABLE_STATE] = TABLE_FREE;
	s_Tables[table][E_TABLE_GAME] = TABLE_GAME_NONE;
	s_Tables[table][E_TABLE_STAKE] = 0;
	s_Tables[table][E_TABLE_POT] = 0;
	s_Tables[table][E_TABLE_OPTION] = 0;
	s_Tables[table][E_TABLE_ROW] = 0;
	s_Tables[table][E_TABLE_SERIAL] = 0;
	s_Tables[table][E_TABLE_WITH_REGULAR] = false;
	s_TableOffers[table][0] = EOS;
}

static Table_FindFree()
{
	for (new table = 0;table < TABLE_MAX;table++)
	{
		if (s_Tables[table][E_TABLE_STATE] == TABLE_FREE)
		{
			return table;
		}
	}

	return TABLE_EMPTY;
}

static Table_FindEmptySeat(table)
{
	for (new seat = 1;seat < TABLE_SEATS;seat++)
	{
		if (!s_TableSeats[table][seat][E_TABLE_SEAT_IN] && !s_TableSeats[table][seat][E_TABLE_SEAT_LEFT] && s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] == 0 && s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] == INVALID_PLAYER_ID && s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR] == TABLE_EMPTY)
		{
			return seat;
		}
	}

	return -1;
}

static bool:Table_PaySeat(table,seat)
{
	new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER], regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR], stake = s_Tables[table][E_TABLE_STAKE];

	if (playerid != INVALID_PLAYER_ID)
	{
		if (Economy_Pay(playerid,stake,INVALID_CONTAINER_ID,"table stake") != PAY_OK)
		{
			return false;
		}
	}
	else if (!Table_TakeRegularPurse(regular,stake))
	{
		return false;
	}

	s_TableSeats[table][seat][E_TABLE_SEAT_PAID] = stake;
	s_TableSeats[table][seat][E_TABLE_SEAT_IN] = true;
	s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] = 0;
	s_Tables[table][E_TABLE_POT] += stake;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO games_seats (game_id, seat, character_id, regular_id, stake) VALUES (%d, %d, NULLIF(%d, 0), NULLIF(%d, 0), %d) ON DUPLICATE KEY UPDATE character_id = VALUES(character_id), regular_id = VALUES(regular_id), stake = VALUES(stake), result = 0, left_reason = NULL",s_Tables[table][E_TABLE_ROW],seat,s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER],Table_GetRegularRow(regular),stake));
	return true;
}

static Table_PayBack(table,seat)
{
	new paid = s_TableSeats[table][seat][E_TABLE_SEAT_PAID];

	if (paid <= 0)
	{
		return;
	}

	if (s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR] != TABLE_EMPTY)
	{
		Table_GiveRegularPurse(s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR],paid);
	}
	else
	{
		Table_PayOut(s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER],s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER],paid,"table refund");
	}

	s_Tables[table][E_TABLE_POT] -= paid;
	s_TableSeats[table][seat][E_TABLE_SEAT_PAID] = 0;
}

static Table_ReleaseSeat(table,seat)
{
	new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER], regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];

	if (Util_IsValidPlayer(playerid) && s_TablePlayer[playerid] == table)
	{
		s_TablePlayer[playerid] = TABLE_EMPTY;
	}

	if (regular != TABLE_EMPTY && Table_GetRegularTable(regular) == table)
	{
		Table_SetRegularTable(regular,TABLE_EMPTY);
	}

	Table_ResetSeat(table,seat);
	pawn_call_public("Table_OnChanged","d",table);
}

static Table_TakeSeat(table,seat,playerid,regular)
{
	s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] = playerid;
	s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR] = regular;

	if (playerid != INVALID_PLAYER_ID)
	{
		s_TableSeats[table][seat][E_TABLE_SEAT_TOKEN] = Account_GetToken(playerid);
		s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER] = Character_GetId(playerid);
		Nametag_Token(playerid,s_TableSeatNames[table][seat],TABLE_NAME_LEN);
		s_TablePlayer[playerid] = table;
	}
	else
	{
		Table_GetRegularName(regular,s_TableSeatNames[table][seat],TABLE_NAME_LEN);
		Table_SetRegularTable(regular,table);
	}
}

#pragma warning push
#pragma warning disable 204
forward Task:Table_Open(game,hostid,stake,option);

async Task:Table_Open(game,hostid,stake,option)
{
	new table = Table_FindFree();

	if (table == TABLE_EMPTY || game <= TABLE_GAME_NONE || game >= TABLE_GAME_COUNT || !Session_IsPlaying(hostid) || s_TablePlayer[hostid] != TABLE_EMPTY || stake <= 0 || stake > TABLE_STAKE_MAX || Economy_Worth(hostid) < stake)
	{
		wait_ticks(1);
		return async TABLE_EMPTY;
	}

	new serial = ++s_TableSerial, Float:x, Float:y, Float:z, Float:angle;
	GetPlayerPos(hostid,x,y,z);
	GetPlayerFacingAngle(hostid,angle);
	s_Tables[table][E_TABLE_STATE] = TABLE_GATHERING;
	s_Tables[table][E_TABLE_GAME] = game;
	s_Tables[table][E_TABLE_STAKE] = stake;
	s_Tables[table][E_TABLE_POT] = 0;
	s_Tables[table][E_TABLE_OPTION] = option;
	s_Tables[table][E_TABLE_ROW] = 0;
	s_Tables[table][E_TABLE_SERIAL] = serial;
	s_Tables[table][E_TABLE_WITH_REGULAR] = false;
	s_Tables[table][E_TABLE_X] = x;
	s_Tables[table][E_TABLE_Y] = y;
	s_Tables[table][E_TABLE_Z] = z - TABLE_GROUND_DROP;
	s_Tables[table][E_TABLE_ANGLE] = angle;
	s_Tables[table][E_TABLE_WORLD] = GetPlayerVirtualWorld(hostid);
	s_Tables[table][E_TABLE_INTERIOR] = GetPlayerInterior(hostid);
	s_TableOffers[table][0] = EOS;
	Table_TakeSeat(table,0,hostid,TABLE_EMPTY);

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO games_played (kind, stake, opened_at) VALUES (%d, %d, %d)",game,stake,gettime()));

	new row = cache_insert_id();

	if (!Table_IsCurrent(table,serial))
	{
		return async TABLE_EMPTY;
	}

	s_Tables[table][E_TABLE_ROW] = row;

	if (row <= 0 || !Table_PaySeat(table,0))
	{
		Table_Close(table);
		return async TABLE_EMPTY;
	}

	return async table;
}
#pragma warning pop

stock Table_GetSeatPaid(table,seat)
{
	return s_TableSeats[table][seat][E_TABLE_SEAT_PAID];
}

stock bool:Table_AddToPot(table,seat,amount,const source[])
{
	if (!Table_IsSeatIn(table,seat) || amount <= 0 || s_TableSeats[table][seat][E_TABLE_SEAT_PAID] + amount > TABLE_STAKE_MAX)
	{
		return false;
	}

	new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER], regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];

	if (playerid != INVALID_PLAYER_ID)
	{
		if (Economy_Pay(playerid,amount,INVALID_CONTAINER_ID,source) != PAY_OK)
		{
			return false;
		}
	}
	else if (!Table_TakeRegularPurse(regular,amount))
	{
		return false;
	}

	s_TableSeats[table][seat][E_TABLE_SEAT_PAID] += amount;
	s_Tables[table][E_TABLE_POT] += amount;
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_seats SET stake = %d WHERE game_id = %d AND seat = %d",s_TableSeats[table][seat][E_TABLE_SEAT_PAID],s_Tables[table][E_TABLE_ROW],seat));
	return true;
}

stock bool:Table_SeatRegular(table,regular)
{
	if (Table_GetState(table) != TABLE_GATHERING || !Table_IsValidRegular(regular) || Table_GetRegularTable(regular) != TABLE_EMPTY)
	{
		return false;
	}

	new seat = Table_FindEmptySeat(table);

	if (seat == -1)
	{
		return false;
	}

	Table_TakeSeat(table,seat,INVALID_PLAYER_ID,regular);

	if (!Table_PaySeat(table,seat))
	{
		Table_ReleaseSeat(table,seat);
		return false;
	}

	s_Tables[table][E_TABLE_WITH_REGULAR] = true;
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_played SET with_regular = 1 WHERE id = %d",s_Tables[table][E_TABLE_ROW]));
	pawn_call_public("Table_OnChanged","d",table);
	return true;
}

stock Table_Ask(table,playerid)
{
	if (Table_GetState(table) != TABLE_GATHERING || !Session_IsPlaying(playerid) || s_TablePlayer[playerid] != TABLE_EMPTY)
	{
		return -1;
	}

	new seat = Table_FindEmptySeat(table);

	if (seat == -1)
	{
		return -1;
	}

	Table_TakeSeat(table,seat,playerid,TABLE_EMPTY);
	s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] = gettime() + TABLE_INVITE_SECONDS;
	pawn_call_public("Table_OnChanged","d",table);
	return seat;
}

stock bool:Table_Accept(table,seat)
{
	if (!Table_IsSeatAsked(table,seat))
	{
		return false;
	}

	if (!Table_PaySeat(table,seat))
	{
		Table_ReleaseSeat(table,seat);
		return false;
	}

	pawn_call_public("Table_OnChanged","d",table);
	return true;
}

stock Table_Decline(table,seat)
{
	if (Table_IsSeatAsked(table,seat))
	{
		Table_ReleaseSeat(table,seat);
	}
}

static Table_PlaceLayout(table)
{
	new Float:sumX = 0.0, Float:sumY = 0.0, Float:sumZ = 0.0, count = 0, Float:x, Float:y, Float:z, Float:angle;

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (!Table_IsSeatIn(table,seat))
		{
			continue;
		}

		new regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];

		if (regular != TABLE_EMPTY)
		{
			Table_GetRegularSpot(regular,x,y,z,angle);
			s_Tables[table][E_TABLE_X] = x;
			s_Tables[table][E_TABLE_Y] = y;
			s_Tables[table][E_TABLE_Z] = z;
			s_Tables[table][E_TABLE_ANGLE] = angle;
			s_Tables[table][E_TABLE_WORLD] = Table_GetRegularWorld(regular);
			s_Tables[table][E_TABLE_INTERIOR] = Table_GetRegularInterior(regular);
			return;
		}

		GetPlayerPos(s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER],x,y,z);
		sumX += x;
		sumY += y;
		sumZ += z;
		count++;
	}

	if (count == 0)
	{
		return;
	}

	x = sumX / float(count);
	y = sumY / float(count);
	z = sumZ / float(count);

	new Float:hitX, Float:hitY, Float:hitZ;

	new hit = CA_RayCastLine(x,y,z + 0.5,x,y,z - TABLE_GROUND_PROBE,hitX,hitY,hitZ);

	if (hit)
	{
		s_Tables[table][E_TABLE_Z] = hitZ + (Map_IsMapModel(hit) ? TABLE_GROUND_LIFT : 0.0);
	}
	else
	{
		s_Tables[table][E_TABLE_Z] = z - TABLE_GROUND_DROP;
	}

	s_Tables[table][E_TABLE_X] = x;
	s_Tables[table][E_TABLE_Y] = y;
}

stock bool:Table_Start(table)
{
	if (Table_GetState(table) != TABLE_GATHERING || Table_CountIn(table) < 2)
	{
		return false;
	}

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		if (Table_IsSeatAsked(table,seat))
		{
			new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER];
			Table_ReleaseSeat(table,seat);
			Table_CloseInvite(playerid);
			Gui_Notify(playerid,"That game started without you.");
		}
	}

	Table_PlaceLayout(table);
	s_Tables[table][E_TABLE_STATE] = TABLE_PLAYING;
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_played SET started_at = %d, pot = %d WHERE id = %d",gettime(),s_Tables[table][E_TABLE_POT],s_Tables[table][E_TABLE_ROW]));
	pawn_call_public("Table_OnStarted","d",table);
	return true;
}

stock Table_Finish(table,winner)
{
	Table_FinishSplit(table,winner >= 0 && winner < TABLE_SEATS ? (1 << winner) : 0);
}

stock Table_FinishSplit(table,winners)
{
	if (!Table_IsValid(table))
	{
		return;
	}

	new pot = s_Tables[table][E_TABLE_POT], count = Table_CountBits(winners), first = -1, winnerCharacter = 0, winnerRegular = 0;

	for (new seat = 0;seat < TABLE_SEATS && count > 0;seat++)
	{
		if ((winners & (1 << seat)) == 0)
		{
			continue;
		}

		new share = pot / count, regular = s_TableSeats[table][seat][E_TABLE_SEAT_REGULAR];

		if (first == -1)
		{
			first = seat;
			share += pot % count;
		}

		if (regular != TABLE_EMPTY)
		{
			Table_GiveRegularPurse(regular,share);

			if (winnerRegular == 0 && winnerCharacter == 0)
			{
				winnerRegular = Table_GetRegularRow(regular);
			}
		}
		else
		{
			Table_PayOut(s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER],s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER],share,"table winnings");

			if (winnerRegular == 0 && winnerCharacter == 0)
			{
				winnerCharacter = s_TableSeats[table][seat][E_TABLE_SEAT_CHARACTER];
			}
		}

		mysql_tquery_s(g_Mysql,str_format("UPDATE games_seats SET result = %d - stake WHERE game_id = %d AND seat = %d",share,s_Tables[table][E_TABLE_ROW],seat));
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE games_seats SET result = -stake WHERE game_id = %d AND (%d >> seat) & 1 = 0",s_Tables[table][E_TABLE_ROW],winners));
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_played SET ended_at = %d, pot = %d, winner_character_id = NULLIF(%d, 0), winner_regular_id = NULLIF(%d, 0) WHERE id = %d",gettime(),pot,winnerCharacter,winnerRegular,s_Tables[table][E_TABLE_ROW]));
	pawn_call_public("Table_OnClosing","dd",table,first);
	Table_Free(table);
}

stock Table_Close(table)
{
	if (!Table_IsValid(table))
	{
		return;
	}

	for (new seat = 0;seat < TABLE_SEATS;seat++)
	{
		new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER];

		if (s_TableSeats[table][seat][E_TABLE_SEAT_IN])
		{
			Table_PayBack(table,seat);
		}
		else if (Table_IsSeatAsked(table,seat))
		{
			Table_CloseInvite(playerid);
		}
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE games_played SET ended_at = %d, refunded = 1 WHERE id = %d",gettime(),s_Tables[table][E_TABLE_ROW]));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM games_seats WHERE game_id = %d",s_Tables[table][E_TABLE_ROW]));
	pawn_call_public("Table_OnClosing","dd",table,-1);
	Table_Free(table);
}

stock Table_Leave(playerid,reason)
{
	if (playerid < 0 || playerid >= MAX_PLAYERS)
	{
		return;
	}

	new table = s_TablePlayer[playerid];

	if (table == TABLE_EMPTY)
	{
		return;
	}

	new seat = Table_GetPlayerSeat(playerid);

	if (seat == -1)
	{
		s_TablePlayer[playerid] = TABLE_EMPTY;
		return;
	}

	if (s_Tables[table][E_TABLE_STATE] == TABLE_GATHERING)
	{
		if (seat == 0)
		{
			Table_NotifySeats(table,"The game was called off. You got your stake back.",0);
			Table_Close(table);
			return;
		}

		if (s_TableSeats[table][seat][E_TABLE_SEAT_IN])
		{
			Table_PayBack(table,seat);
			mysql_tquery_s(g_Mysql,str_format("DELETE FROM games_seats WHERE game_id = %d AND seat = %d",s_Tables[table][E_TABLE_ROW],seat));
		}

		Table_ReleaseSeat(table,seat);
		return;
	}

	new name[TABLE_NAME_LEN], line[TABLE_LINE_LEN];
	strcopy(name,s_TableSeatNames[table][seat]);
	pawn_call_public("Table_OnPlayerLeft","ddd",table,playerid,reason);
	s_TableSeats[table][seat][E_TABLE_SEAT_IN] = false;
	s_TableSeats[table][seat][E_TABLE_SEAT_LEFT] = true;
	s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER] = INVALID_PLAYER_ID;
	s_TablePlayer[playerid] = TABLE_EMPTY;
	mysql_tquery_s(g_Mysql,str_format("UPDATE games_seats SET left_reason = %d, result = -stake WHERE game_id = %d AND seat = %d",reason,s_Tables[table][E_TABLE_ROW],seat));
	format(line,sizeof(line),"%s leaves the game and loses their stake.",name);
	Table_Log(table,line);

	if (Table_CountIn(table) <= 1 || Table_CountHumansIn(table) == 0)
	{
		Table_Finish(table,Table_FirstSeatIn(table));
		return;
	}

	pawn_call_public("Table_OnSeatLeft","ddd",table,seat,reason);
}

forward Task:Table_RefundOpenGames();

async Task:Table_RefundOpenGames()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT IFNULL(s.character_id, 0) AS character_id, IFNULL(s.regular_id, 0) AS regular_id, s.stake FROM games_seats s JOIN games_played p ON p.id = s.game_id WHERE p.ended_at IS NULL"));

	new refunded = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new characterid, regularRow, stake;
		cache_get_value_name_int(r,"character_id",characterid);
		cache_get_value_name_int(r,"regular_id",regularRow);
		cache_get_value_name_int(r,"stake",stake);

		if (characterid > 0)
		{
			Table_PayOut(INVALID_PLAYER_ID,characterid,stake,"table refund");
			refunded++;
		}
		else if (regularRow > 0)
		{
			mysql_tquery_s(g_Mysql,str_format("UPDATE games_regulars SET purse = purse + %d WHERE id = %d",stake,regularRow));
			refunded++;
		}
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE games_played SET ended_at = %d, refunded = 1 WHERE ended_at IS NULL",gettime()));
	return async refunded;
}

forward Table_OnChanged(table);

public Table_OnChanged(table)
{
	return 1;
}

forward Table_OnStarted(table);

public Table_OnStarted(table)
{
	return 1;
}

forward Table_OnSeatLeft(table,seat,reason);

public Table_OnSeatLeft(table,seat,reason)
{
	return 1;
}

forward Table_OnPlayerLeft(table,playerid,reason);

public Table_OnPlayerLeft(table,playerid,reason)
{
	return 1;
}

forward Table_OnClosing(table,winner);

public Table_OnClosing(table,winner)
{
	return 1;
}

forward Table_Tick();

public Table_Tick()
{
	new now = gettime();

	for (new table = 0;table < TABLE_MAX;table++)
	{
		if (s_Tables[table][E_TABLE_STATE] == TABLE_GATHERING)
		{
			for (new seat = 1;seat < TABLE_SEATS && Table_IsValid(table);seat++)
			{
				if (Table_IsSeatAsked(table,seat) && s_TableSeats[table][seat][E_TABLE_SEAT_ASKED_UNTIL] < now)
				{
					new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER], host = s_TableSeats[table][0][E_TABLE_SEAT_PLAYER], line[TABLE_LINE_LEN];
					format(line,sizeof(line),"%s didn't answer your challenge in time.",s_TableSeatNames[table][seat]);
					Table_ReleaseSeat(table,seat);
					Table_CloseInvite(playerid);
					Gui_Notify(playerid,"You didn't answer the challenge in time.");
					Table_Notify(host,line);
					Table_CheckGathering(table);
				}
			}

			continue;
		}

		if (s_Tables[table][E_TABLE_STATE] != TABLE_PLAYING)
		{
			continue;
		}

		for (new seat = 0;seat < TABLE_SEATS && Table_GetState(table) == TABLE_PLAYING;seat++)
		{
			new playerid = s_TableSeats[table][seat][E_TABLE_SEAT_PLAYER];

			if (!Table_IsSeatIn(table,seat) || playerid == INVALID_PLAYER_ID)
			{
				continue;
			}

			if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != s_TableSeats[table][seat][E_TABLE_SEAT_TOKEN])
			{
				Table_Leave(playerid,TABLE_LEFT_GONE);
			}
			else if (Wounds_IsDown(playerid))
			{
				Table_Leave(playerid,TABLE_LEFT_DOWN);
				Gui_Notify(playerid,"You went down and lost your place in the game. Your stake stays in the pot.");
			}
			else if (GetPlayerVirtualWorld(playerid) != s_Tables[table][E_TABLE_WORLD] || GetPlayerDistanceFromPoint(playerid,s_Tables[table][E_TABLE_X],s_Tables[table][E_TABLE_Y],s_Tables[table][E_TABLE_Z]) > TABLE_LEAVE_RANGE)
			{
				Table_Leave(playerid,TABLE_LEFT_WALKED);
				Gui_Notify(playerid,"You walked away from the game and lost your stake.");
			}
		}
	}

	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new table = 0;table < TABLE_MAX;table++)
	{
		for (new seat = 0;seat < TABLE_SEATS;seat++)
		{
			Table_ResetSeat(table,seat);
		}
	}
}

hook OnPlayerConnect(playerid)
{
	s_TablePlayer[playerid] = TABLE_EMPTY;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Table_Leave(playerid,TABLE_LEFT_GONE);
}

hook Character_OnUnloaded(playerid)
{
	Table_Leave(playerid,TABLE_LEFT_GONE);
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid,reason

	Table_Leave(playerid,TABLE_LEFT_DOWN);
}
