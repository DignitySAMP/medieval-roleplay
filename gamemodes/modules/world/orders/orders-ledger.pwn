#define LEDGER_ROWS (ORDERS_LEDGER_MAX + ORDERS_SUGGEST_MAX)
#define LEDGER_GOAL (0)
#define LEDGER_SUGGESTION (1)

enum E_LEDGER_ROW
{
	E_LEDGER_ROW_ID,
	E_LEDGER_ROW_KIND,
	E_LEDGER_ROW_TEXT[ORDERS_LEDGER_LEN],
	E_LEDGER_ROW_DUE,
	bool:E_LEDGER_ROW_DONE,
	bool:E_LEDGER_ROW_USED,
}

static s_Ledger[MAX_PLAYERS][LEDGER_ROWS][E_LEDGER_ROW];

forward bool:Ledger_Remove(playerid,row);

stock Ledger_Reset(playerid)
{
	for (new row = 0;row < LEDGER_ROWS;row++)
	{
		s_Ledger[playerid][row][E_LEDGER_ROW_USED] = false;
		s_Ledger[playerid][row][E_LEDGER_ROW_ID] = 0;
	}
}

stock bool:Ledger_IsValid(playerid,row)
{
	return Util_IsValidPlayer(playerid) && row >= 0 && row < LEDGER_ROWS && s_Ledger[playerid][row][E_LEDGER_ROW_USED];
}

stock Ledger_GetKind(playerid,row)
{
	return Ledger_IsValid(playerid,row) ? s_Ledger[playerid][row][E_LEDGER_ROW_KIND] : -1;
}

stock Ledger_GetText(playerid,row,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Ledger_IsValid(playerid,row))
	{
		strcopy(dest,s_Ledger[playerid][row][E_LEDGER_ROW_TEXT],size);
	}
}

stock Ledger_GetDue(playerid,row)
{
	return Ledger_IsValid(playerid,row) ? s_Ledger[playerid][row][E_LEDGER_ROW_DUE] : -1;
}

stock bool:Ledger_IsDone(playerid,row)
{
	return Ledger_IsValid(playerid,row) && s_Ledger[playerid][row][E_LEDGER_ROW_DONE];
}

stock Ledger_Count(playerid,kind)
{
	new count = 0;

	for (new row = 0;Util_IsValidPlayer(playerid) && row < LEDGER_ROWS;row++)
	{
		if (s_Ledger[playerid][row][E_LEDGER_ROW_USED] && s_Ledger[playerid][row][E_LEDGER_ROW_KIND] == kind)
		{
			count++;
		}
	}

	return count;
}

stock Ledger_Clean(text[])
{
	for (new i = 0;text[i] != EOS;i++)
	{
		if (text[i] == '~' || text[i] == '{' || text[i] == '}' || text[i] == '|' || text[i] == '%' || text[i] < ' ')
		{
			text[i] = ' ';
		}
	}
}

static Ledger_FindFree(playerid)
{
	for (new row = 0;row < LEDGER_ROWS;row++)
	{
		if (!s_Ledger[playerid][row][E_LEDGER_ROW_USED])
		{
			return row;
		}
	}

	return -1;
}

stock Ledger_Put(playerid,id,kind,const text[],due,bool:isDone)
{
	new row = Ledger_FindFree(playerid);

	if (row == -1)
	{
		return -1;
	}

	s_Ledger[playerid][row][E_LEDGER_ROW_ID] = id;
	s_Ledger[playerid][row][E_LEDGER_ROW_KIND] = kind;
	strcopy(s_Ledger[playerid][row][E_LEDGER_ROW_TEXT],text,ORDERS_LEDGER_LEN);
	Ledger_Clean(s_Ledger[playerid][row][E_LEDGER_ROW_TEXT]);
	s_Ledger[playerid][row][E_LEDGER_ROW_DUE] = due;
	s_Ledger[playerid][row][E_LEDGER_ROW_DONE] = isDone;
	s_Ledger[playerid][row][E_LEDGER_ROW_USED] = true;
	return row;
}

forward Task:Ledger_Insert(playerid,row);

public Task:Ledger_Insert(playerid,row)
{
	new Task:done = task_new(), token = Account_GetToken(playerid), characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO ledger_goals (character_id, kind, text, due_day, done) VALUES (%d, %d, '%e', NULLIF(%d, -1), %d)",characterid,s_Ledger[playerid][row][E_LEDGER_ROW_KIND],s_Ledger[playerid][row][E_LEDGER_ROW_TEXT],s_Ledger[playerid][row][E_LEDGER_ROW_DUE],s_Ledger[playerid][row][E_LEDGER_ROW_DONE]));
	new id = cache_insert_id();

	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && s_Ledger[playerid][row][E_LEDGER_ROW_USED] && s_Ledger[playerid][row][E_LEDGER_ROW_ID] == 0)
	{
		s_Ledger[playerid][row][E_LEDGER_ROW_ID] = id;
	}
	else if (id > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM ledger_goals WHERE id = %d",id));
	}

	task_set_result(done,id);
	return done;
}

stock Ledger_Add(playerid,const text[],due = -1)
{
	if (!Util_IsValidPlayer(playerid) || Character_GetId(playerid) <= 0 || text[0] == EOS || Ledger_Count(playerid,LEDGER_GOAL) >= ORDERS_LEDGER_MAX)
	{
		return -1;
	}

	new row = Ledger_Put(playerid,0,LEDGER_GOAL,text,due,false);

	if (row != -1)
	{
		Ledger_Insert(playerid,row);
	}

	return row;
}

stock Ledger_Suggest(playerid,const text[])
{
	if (!Util_IsValidPlayer(playerid) || Character_GetId(playerid) <= 0 || text[0] == EOS)
	{
		return -1;
	}

	new clean[ORDERS_LEDGER_LEN];
	strcopy(clean,text);
	Ledger_Clean(clean);

	for (new row = 0;row < LEDGER_ROWS;row++)
	{
		if (s_Ledger[playerid][row][E_LEDGER_ROW_USED] && !strcmp(s_Ledger[playerid][row][E_LEDGER_ROW_TEXT],clean))
		{
			return row;
		}
	}

	if (Ledger_Count(playerid,LEDGER_SUGGESTION) >= ORDERS_SUGGEST_MAX)
	{
		for (new row = 0;row < LEDGER_ROWS;row++)
		{
			if (s_Ledger[playerid][row][E_LEDGER_ROW_USED] && s_Ledger[playerid][row][E_LEDGER_ROW_KIND] == LEDGER_SUGGESTION)
			{
				Ledger_Remove(playerid,row);
				break;
			}
		}
	}

	new row = Ledger_Put(playerid,0,LEDGER_SUGGESTION,clean,-1,false);

	if (row != -1)
	{
		Ledger_Insert(playerid,row);
	}

	return row;
}

stock bool:Ledger_Tick(playerid,row)
{
	if (!Ledger_IsValid(playerid,row) || s_Ledger[playerid][row][E_LEDGER_ROW_KIND] != LEDGER_GOAL)
	{
		return false;
	}

	s_Ledger[playerid][row][E_LEDGER_ROW_DONE] = !s_Ledger[playerid][row][E_LEDGER_ROW_DONE];

	if (s_Ledger[playerid][row][E_LEDGER_ROW_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE ledger_goals SET done = %d WHERE id = %d",s_Ledger[playerid][row][E_LEDGER_ROW_DONE],s_Ledger[playerid][row][E_LEDGER_ROW_ID]));
	}

	return true;
}

stock bool:Ledger_Remove(playerid,row)
{
	if (!Ledger_IsValid(playerid,row))
	{
		return false;
	}

	if (s_Ledger[playerid][row][E_LEDGER_ROW_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM ledger_goals WHERE id = %d",s_Ledger[playerid][row][E_LEDGER_ROW_ID]));
	}

	s_Ledger[playerid][row][E_LEDGER_ROW_USED] = false;
	s_Ledger[playerid][row][E_LEDGER_ROW_ID] = 0;
	return true;
}

stock bool:Ledger_Keep(playerid,row)
{
	if (!Ledger_IsValid(playerid,row) || s_Ledger[playerid][row][E_LEDGER_ROW_KIND] != LEDGER_SUGGESTION || Ledger_Count(playerid,LEDGER_GOAL) >= ORDERS_LEDGER_MAX)
	{
		return false;
	}

	s_Ledger[playerid][row][E_LEDGER_ROW_KIND] = LEDGER_GOAL;

	if (s_Ledger[playerid][row][E_LEDGER_ROW_ID] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE ledger_goals SET kind = %d WHERE id = %d",LEDGER_GOAL,s_Ledger[playerid][row][E_LEDGER_ROW_ID]));
	}

	return true;
}

stock Ledger_DayDate(dayNumber,&day,&month,&year)
{
	new perYear = CALENDAR_MONTHS * CALENDAR_DAYS_PER_MONTH, value = max(dayNumber,0), into = value % perYear;
	year = CALENDAR_EPOCH_YEAR + value / perYear;
	month = into / CALENDAR_DAYS_PER_MONTH + 1;
	day = into % CALENDAR_DAYS_PER_MONTH + 1;
}

stock Ledger_NextMoonDay(E_MOON:phase,from)
{
	for (new offset = 0;offset <= 31;offset++)
	{
		new day, month, year;
		Ledger_DayDate(from + offset,day,month,year);

		if (Calendar_MoonOf(day,month,year) == phase)
		{
			return from + offset;
		}
	}

	return -1;
}

stock Ledger_FormatMoon(dest[],size = sizeof(dest))
{
	new today = Orders_Today(), full = Ledger_NextMoonDay(MOON_FULL,today), dark = Ledger_NextMoonDay(MOON_NEW,today), fullText[24], darkText[24];
	Calendar_FormatDay(full,fullText);
	Calendar_FormatDay(dark,darkText);
	format(dest,size,"Full moon %s, new moon %s.",full == today ? ("tonight") : fullText,dark == today ? ("tonight") : darkText);
}

stock Ledger_Compass(Float:fromX,Float:fromY,Float:toX,Float:toY,dest[],size = sizeof(dest))
{
	static const names[8][12] = {"north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"};
	new Float:angle = atan2(toX - fromX,toY - fromY);

	if (angle < 0.0)
	{
		angle += 360.0;
	}

	strcopy(dest,names[floatround(angle / 45.0,floatround_round) % 8],size);
}

stock Ledger_InGameHours(realSeconds)
{
	return realSeconds * 24 / ((CALENDAR_DAY_REAL_MS + CALENDAR_NIGHT_REAL_MS) / 1000);
}

stock Ledger_FormatChores(playerid,dest[],size = sizeof(dest))
{
	new hunger = Ledger_InGameHours(Needs_GetSecondsUntilLow(playerid,NEED_HUNGER)), thirst = Ledger_InGameHours(Needs_GetSecondsUntilLow(playerid,NEED_THIRST)), hungerText[40], thirstText[40];

	if (hunger <= 0)
	{
		strcopy(hungerText,"You're hungry now");
	}
	else
	{
		format(hungerText,sizeof(hungerText),hunger == 1 ? ("Hungry in about an hour") : ("Hungry in about %d hours"),hunger);
	}

	if (thirst <= 0)
	{
		strcopy(thirstText,"thirsty now");
	}
	else
	{
		format(thirstText,sizeof(thirstText),thirst == 1 ? ("thirsty in about an hour") : ("thirsty in about %d hours"),thirst);
	}

	format(dest,size,"%s; %s.",hungerText,thirstText);

	new Float:px, Float:py, Float:pz, best = -1, Float:bestDistance = 99999.0;
	GetPlayerPos(playerid,px,py,pz);

	for (new index = 0;index < ACTORS_MAX;index++)
	{
		new Float:x, Float:y, Float:z;

		if (Orders_GiverKindOf(index) != ORDER_GIVER_INNKEEPER || Actors_IsDead(index) || !Actors_GetPos(index,x,y,z))
		{
			continue;
		}

		new Float:distance = VectorSize(x - px,y - py,0.0);

		if (distance < bestDistance)
		{
			bestDistance = distance;
			best = index;
		}
	}

	if (best != -1 && bestDistance > 20.0)
	{
		new Float:x, Float:y, Float:z, way[12];
		Actors_GetPos(best,x,y,z);
		Ledger_Compass(px,py,x,y,way);
		new line[40];
		format(line,sizeof(line)," The nearest inn is %s.",way);
		strcat(dest,line,size);
	}
}

forward Task:Ledger_Load(playerid,characterid);

#pragma warning push
#pragma warning disable 204
async Task:Ledger_Load(playerid,characterid)
{
	new token = Account_GetToken(playerid);
	Ledger_Reset(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, text, IFNULL(due_day, -1) AS due, done FROM ledger_goals WHERE character_id = %d ORDER BY id LIMIT %d",characterid,LEDGER_ROWS));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, kind, text[ORDERS_LEDGER_LEN], due, isDone;
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name_int(row,"kind",kind);
		cache_get_value_name(row,"text",text);
		cache_get_value_name_int(row,"due",due);
		cache_get_value_name_int(row,"done",isDone);
		Ledger_Put(playerid,id,kind,text,due,isDone != 0);
	}

	return async 1;
}
#pragma warning pop
