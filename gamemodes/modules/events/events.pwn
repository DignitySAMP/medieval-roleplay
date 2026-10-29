forward bool:Events_HasPlayerHerald();

enum E_EVENT
{
	bool:E_EVENT_USED,
	E_EVENT_ROW,
	E_EVENT_KIND,
	E_EVENT_STATE,
	E_EVENT_HOST,
	E_EVENT_STARTS,
	E_EVENT_ENDS,
	E_EVENT_PURSE,
	E_EVENT_FEE,
	E_EVENT_FEES,
	E_EVENT_CONTESTS,
	E_EVENT_DONE_CONTESTS,
	bool:E_EVENT_WARNED_HOUR,
	bool:E_EVENT_WARNED_SOON,
}

enum E_EVENT_ENTRY
{
	E_ENTRY_CHARACTER,
	E_ENTRY_SCORE,
	bool:E_ENTRY_OUT,
	E_ENTRY_PLACED,
	E_ENTRY_ITEM,
	E_ENTRY_STARS,
}

enum E_EVENT_BET
{
	bool:E_BET_USED,
	E_BET_EVENT,
	E_BET_CONTEST,
	E_BET_BETTOR,
	E_BET_ON,
	E_BET_STAKE,
}

static s_Events[EVENTS_MAX][E_EVENT];
static s_Entries[EVENTS_MAX][CONTEST_COUNT][EVENTS_ENTRIES][E_EVENT_ENTRY];
static s_EntryCount[EVENTS_MAX][CONTEST_COUNT];
static s_Bets[EVENTS_BETS][E_EVENT_BET];
static s_Herald = -1;

forward Task:Events_Declare(kind,contests,startsAt,endsAt,host,purse,fee);
forward Task:Events_Load();

stock bool:Events_IsValid(event)
{
	return event >= 0 && event < EVENTS_MAX && s_Events[event][E_EVENT_USED];
}

stock Events_GetKind(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_KIND] : -1;
}

stock Events_GetState(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_STATE] : EVENT_DONE;
}

stock Events_GetHost(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_HOST] : 0;
}

stock Events_GetStarts(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_STARTS] : 0;
}

stock Events_GetEnds(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_ENDS] : 0;
}

stock Events_GetPurse(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_PURSE] : 0;
}

stock Events_GetFee(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_FEE] : 0;
}

stock Events_GetFees(event)
{
	return Events_IsValid(event) ? s_Events[event][E_EVENT_FEES] : 0;
}

stock bool:Events_HasContest(event,contest)
{
	return Events_IsValid(event) && contest >= 0 && contest < CONTEST_COUNT && (s_Events[event][E_EVENT_CONTESTS] & (1 << contest)) != 0;
}

stock bool:Events_IsContestDone(event,contest)
{
	return Events_IsValid(event) && (s_Events[event][E_EVENT_DONE_CONTESTS] & (1 << contest)) != 0;
}

stock Events_FindKind(kind,bool:isLive = true)
{
	for (new event = 0;event < EVENTS_MAX;event++)
	{
		if (s_Events[event][E_EVENT_USED] && s_Events[event][E_EVENT_KIND] == kind && (!isLive || s_Events[event][E_EVENT_STATE] != EVENT_DONE))
		{
			return event;
		}
	}

	return -1;
}

stock Events_FindOpen(contest)
{
	for (new event = 0;event < EVENTS_MAX;event++)
	{
		if (Events_HasContest(event,contest) && s_Events[event][E_EVENT_STATE] != EVENT_DONE && !Events_IsContestDone(event,contest))
		{
			return event;
		}
	}

	return -1;
}

stock Events_GetEntryCount(event,contest)
{
	return Events_IsValid(event) && contest >= 0 && contest < CONTEST_COUNT ? s_EntryCount[event][contest] : 0;
}

stock Events_GetEntry(event,contest,index,&characterid,&score,&bool:isOut,&placed)
{
	characterid = s_Entries[event][contest][index][E_ENTRY_CHARACTER];
	score = s_Entries[event][contest][index][E_ENTRY_SCORE];
	isOut = s_Entries[event][contest][index][E_ENTRY_OUT];
	placed = s_Entries[event][contest][index][E_ENTRY_PLACED];
}

stock Events_GetEntryItem(event,contest,index,&param,&stars)
{
	param = s_Entries[event][contest][index][E_ENTRY_ITEM];
	stars = s_Entries[event][contest][index][E_ENTRY_STARS];
}

stock Events_SetScore(event,contest,index,score)
{
	s_Entries[event][contest][index][E_ENTRY_SCORE] = score;
	mysql_tquery_s(g_Mysql,str_format("UPDATE event_entries SET score = %d WHERE event_id = %d AND contest = %d AND character_id = %d",score,s_Events[event][E_EVENT_ROW],contest,s_Entries[event][contest][index][E_ENTRY_CHARACTER]));
}

stock Events_SetOut(event,contest,index,bool:isOut)
{
	s_Entries[event][contest][index][E_ENTRY_OUT] = isOut;
}

stock Events_SetPlaced(event,contest,index,placed)
{
	s_Entries[event][contest][index][E_ENTRY_PLACED] = placed;
	mysql_tquery_s(g_Mysql,str_format("UPDATE event_entries SET placed = %d WHERE event_id = %d AND contest = %d AND character_id = %d",placed,s_Events[event][E_EVENT_ROW],contest,s_Entries[event][contest][index][E_ENTRY_CHARACTER]));
}

stock Events_FindEntry(event,contest,characterid)
{
	for (new index = 0;Events_IsValid(event) && index < s_EntryCount[event][contest];index++)
	{
		if (s_Entries[event][contest][index][E_ENTRY_CHARACTER] == characterid)
		{
			return index;
		}
	}

	return -1;
}

stock Events_PlayerOf(event,contest,index)
{
    if (!Events_IsValid(event) || contest < 0 || contest >= CONTEST_COUNT || index < 0 || index >= s_EntryCount[event][contest])
    {
        return INVALID_PLAYER_ID;
    }
	return Groups_PlayerByCharacter(s_Entries[event][contest][index][E_ENTRY_CHARACTER]);
}

stock Events_CountContests(event)
{
	new count = 0;

	for (new contest = 0;contest < CONTEST_COUNT;contest++)
	{
		if (Events_HasContest(event,contest))
		{
			count++;
		}
	}

	return count;
}

stock Events_DescribeContests(event,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	for (new contest = 0;contest < CONTEST_COUNT;contest++)
	{
		if (Events_HasContest(event,contest))
		{
			format(dest,size,"%s%s%s",dest,dest[0] != EOS ? (", ") : (""),g_ContestDefs[contest][E_CONTEST_DEF_NAME]);
		}
	}
}

stock Events_PayCounty(amount)
{
	new counts[COIN_TIER_COUNT], treasury = Realm_GetTreasury();

	if (amount <= 0 || treasury == INVALID_CONTAINER_ID)
	{
		return;
	}

	Economy_Split(amount,counts);

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Container_Add(treasury,ITEM_KIND_COIN,tier,counts[tier]);
		}
	}
}

stock bool:Events_TakeFromCounty(amount)
{
	new treasury = Realm_GetTreasury(), take[COIN_TIER_COUNT], left = amount;

	if (amount <= 0)
	{
		return true;
	}

	if (treasury == INVALID_CONTAINER_ID || Realm_TreasuryCoin() < amount)
	{
		return false;
	}

	for (new tier = COIN_TIER_COUNT - 1;tier >= COIN_PFENNIG;tier--)
	{
		take[tier] = min(left / Item_CoinWorth(tier),Container_Count(treasury,ITEM_KIND_COIN,tier));
		left -= take[tier] * Item_CoinWorth(tier);
	}

	if (left != 0)
	{
		return false;
	}

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (take[tier] > 0)
		{
			Container_TakeStars(treasury,ITEM_KIND_COIN,tier,take[tier],ITEM_STARS_MIN);
		}
	}

	return true;
}

stock Events_PayCharacter(characterid,amount,const source[])
{
	if (amount <= 0)
	{
		return;
	}

	if (characterid <= 0)
	{
		Events_PayCounty(amount);
		return;
	}

	Economy_GiveOrClaim(Groups_PlayerByCharacter(characterid),characterid,amount,source);
}

stock Events_PlaceHerald()
{
	if (s_Herald != -1 || g_EventsHerald[0] == 0.0)
	{
		return s_Herald;
	}

	new skins = Skins_CountStarter(0);
	s_Herald = Actors_Register("events:herald",ACTOR_ROLE_VILLAGER,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,6 % skins) : 1,"Hans Herold","Herald of the lists");

	if (s_Herald != -1)
	{
		new Float:x = g_EventsHerald[0], Float:y = g_EventsHerald[1], Float:z = g_EventsHerald[2];
		Events_GetHeraldDeck(x,y,z);
		Actors_SetPlace(s_Herald,x,y,z + 1.0,g_EventsHerald[3],0,0);
		Actors_Place(s_Herald);
	}

	return s_Herald;
}

stock Events_RemoveHerald()
{
	if (s_Herald != -1)
	{
		Actors_Remove(s_Herald);
	}
}

stock Events_GetHerald()
{
	return s_Herald;
}

stock Events_RefreshHerald()
{
    if (Events_HasPlayerHerald())
    {
        Events_RemoveHerald();
        return;
    }

	if (Events_FindKind(EVENT_TOURNAMENT) != -1 || Events_FindKind(EVENT_FESTIVAL) != -1)
	{
		if (s_Herald == -1)
		{
			Events_PlaceHerald();
		}
		else
		{
			Actors_Place(s_Herald);
		}
	}
	else
	{
		Events_RemoveHerald();
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Events_Declare(kind,contests,startsAt,endsAt,host,purse,fee)
{
	new event = -1;

	for (new i = 0;i < EVENTS_MAX;i++)
	{
		if (!s_Events[i][E_EVENT_USED])
		{
			event = i;
			break;
		}
	}

	if (event == -1 || kind < 0 || kind >= EVENT_KIND_COUNT)
	{
		wait_ticks(1);
		return async -1;
	}

	s_Events[event][E_EVENT_USED] = true;
	s_Events[event][E_EVENT_ROW] = 0;
	s_Events[event][E_EVENT_KIND] = kind;
	s_Events[event][E_EVENT_STATE] = EVENT_OPEN;
	s_Events[event][E_EVENT_HOST] = host;
	s_Events[event][E_EVENT_STARTS] = startsAt;
	s_Events[event][E_EVENT_ENDS] = endsAt;
	s_Events[event][E_EVENT_PURSE] = purse;
	s_Events[event][E_EVENT_FEE] = fee;
	s_Events[event][E_EVENT_FEES] = 0;
	s_Events[event][E_EVENT_CONTESTS] = contests;
	s_Events[event][E_EVENT_DONE_CONTESTS] = 0;
	s_Events[event][E_EVENT_WARNED_HOUR] = startsAt - gettime() < 3600;
	s_Events[event][E_EVENT_WARNED_SOON] = startsAt - gettime() < 600;

	for (new contest = 0;contest < CONTEST_COUNT;contest++)
	{
		s_EntryCount[event][contest] = 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO events (kind, host_character_id, county_id, place_key, starts_at, ends_at, purse, entry_fee, contests, fees, state, decree_id) VALUES (%d, %d, %d, 'lists', %d, %d, %d, %d, %d, 0, %d, NULL)",kind,host,REALM_COUNTY,startsAt,endsAt,purse,fee,contests,EVENT_OPEN));

	if (!s_Events[event][E_EVENT_USED] || s_Events[event][E_EVENT_STARTS] != startsAt)
	{
		return async -1;
	}

	s_Events[event][E_EVENT_ROW] = cache_insert_id();
	Events_RefreshHerald();
	pawn_call_public("Events_OnDeclared","dd",event,kind);
	return async event;
}
#pragma warning pop

stock Events_FormatStart(seconds,dest[],size = sizeof(dest))
{
	new count = max((seconds + 59) / 60,0);

	if (count == 0)
	{
		strcopy(dest,"now",size);
	}
	else if (count >= 1440)
	{
		count = (count + 1439) / 1440;
		format(dest,size,"in %d day%s",count,count == 1 ? ("") : ("s"));
	}
	else if (count >= 60)
	{
		count = (count + 59) / 60;
		format(dest,size,"in %d hour%s",count,count == 1 ? ("") : ("s"));
	}
	else
	{
		format(dest,size,"in %d minute%s",count,count == 1 ? ("") : ("s"));
	}
}

stock Events_Announce(event)
{
	new text[144], title[48], when[48], money[48], amount[24], list[96], now = gettime();
	Events_DescribeContests(event,list);
	if (s_Events[event][E_EVENT_PURSE] > 0)
	{
		Economy_Format(s_Events[event][E_EVENT_PURSE],amount);
		format(money,sizeof(money),"Purse %s.",amount);
	}
	else
	{
		strcopy(money,"No prize money.");
	}

	Events_FormatStart(s_Events[event][E_EVENT_STARTS] - now,when);

	switch (s_Events[event][E_EVENT_KIND])
	{
		case EVENT_TOURNAMENT:
		{
			strcopy(title,"A tournament");
			format(text,sizeof(text),"A tournament at the lists " EVENTS_LISTS_WHERE " %s: %s. %s Sign up with the herald.",when,list,money);
		}
		case EVENT_FAIR:
		{
			strcopy(title,"The fair");
			format(text,sizeof(text),"The fair opens in Talmberg's square: merchants from afar with spices, dyes and fine cloth, buying our surplus.");
		}
		default:
		{
			strcopy(title,"A festival");
			format(text,sizeof(text),"A festival %s: %s. The herald at the lists takes entries.",when,list);
		}
	}

	Crier_Announce("event",title,text);
	Notices_Post(NOTICE_TAB_EVENTS,s_Events[event][E_EVENT_HOST],title,text,now,max(s_Events[event][E_EVENT_ENDS],now + EVENTS_NOTICE_DAYS * 86400));
}

stock bool:Events_SignUp(playerid,event,contest,reason[],size = sizeof(reason),itemIndex = -1)
{
	reason[0] = EOS;

	if (!Events_HasContest(event,contest) || Events_IsContestDone(event,contest) || s_Events[event][E_EVENT_STATE] == EVENT_DONE)
	{
		strcopy(reason,"That contest isn't open.",size);
		return false;
	}

	new characterid = Character_GetId(playerid);

	if (Events_FindEntry(event,contest,characterid) != -1)
	{
		strcopy(reason,"You're already entered.",size);
		return false;
	}

	if (s_EntryCount[event][contest] >= EVENTS_ENTRIES)
	{
		strcopy(reason,"The roll is full.",size);
		return false;
	}

	new item = -1, stars = 0;

	if (contest == CONTEST_PRODUCE)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (itemIndex == -1 || !Inventory_GetSlot(playerid,itemIndex,kind,param,amount) || (kind != ITEM_KIND_FOOD && kind != ITEM_KIND_MATERIAL))
		{
			strcopy(reason,"Bring a piece of produce from your bag.",size);
			return false;
		}

		item = param;
		stars = Inventory_GetSlotStars(playerid,itemIndex);
	}

	new fee = s_Events[event][E_EVENT_FEE];

	if (fee > 0 && Economy_Pay(playerid,fee,INVALID_CONTAINER_ID,"entry fee") != PAY_OK)
	{
		strcopy(reason,"You can't pay the entry fee.",size);
		return false;
	}

	if (contest == CONTEST_PRODUCE)
	{
		Inventory_TakeSlot(playerid,itemIndex,1);
	}

	new index = s_EntryCount[event][contest]++;
	s_Entries[event][contest][index][E_ENTRY_CHARACTER] = characterid;
	s_Entries[event][contest][index][E_ENTRY_SCORE] = 0;
	s_Entries[event][contest][index][E_ENTRY_OUT] = false;
	s_Entries[event][contest][index][E_ENTRY_PLACED] = 0;
	s_Entries[event][contest][index][E_ENTRY_ITEM] = item;
	s_Entries[event][contest][index][E_ENTRY_STARS] = stars;
	s_Events[event][E_EVENT_FEES] += fee;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO event_entries (event_id, contest, character_id, score, placed, item_param, item_stars) VALUES (%d, %d, %d, 0, 0, %d, %d)",s_Events[event][E_EVENT_ROW],contest,characterid,item,stars));
	mysql_tquery_s(g_Mysql,str_format("UPDATE events SET fees = %d WHERE id = %d",s_Events[event][E_EVENT_FEES],s_Events[event][E_EVENT_ROW]));
	return true;
}

stock bool:Events_PlaceBet(playerid,event,contest,onCharacter,stake,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (!Events_HasContest(event,contest) || Events_IsContestDone(event,contest) || Events_FindEntry(event,contest,onCharacter) == -1)
	{
		strcopy(reason,"That bet can't be taken.",size);
		return false;
	}

	if (Events_GetRunningContest() == contest && Events_GetRunningEvent() == event)
	{
		strcopy(reason,"No bets once the contest has begun.",size);
		return false;
	}

	if (stake < 1 || stake > 960)
	{
		strcopy(reason,"Stake between a pfennig and four gulden.",size);
		return false;
	}

	new slot = -1;

	for (new i = 0;i < EVENTS_BETS;i++)
	{
		if (!s_Bets[i][E_BET_USED])
		{
			slot = i;
			break;
		}
	}

	if (slot == -1)
	{
		strcopy(reason,"The bookmaker's slate is full.",size);
		return false;
	}

	if (Economy_Pay(playerid,stake,INVALID_CONTAINER_ID,"bet") != PAY_OK)
	{
		strcopy(reason,"You can't cover that stake.",size);
		return false;
	}

	s_Bets[slot][E_BET_USED] = true;
	s_Bets[slot][E_BET_EVENT] = event;
	s_Bets[slot][E_BET_CONTEST] = contest;
	s_Bets[slot][E_BET_BETTOR] = Character_GetId(playerid);
	s_Bets[slot][E_BET_ON] = onCharacter;
	s_Bets[slot][E_BET_STAKE] = stake;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO event_bets (event_id, contest, bettor_character_id, on_character_id, stake, paid) VALUES (%d, %d, %d, %d, %d, 0)",s_Events[event][E_EVENT_ROW],contest,s_Bets[slot][E_BET_BETTOR],onCharacter,stake));
	return true;
}

stock Events_CountBets(event,contest)
{
	new count = 0;

	for (new i = 0;i < EVENTS_BETS;i++)
	{
		if (s_Bets[i][E_BET_USED] && s_Bets[i][E_BET_EVENT] == event && s_Bets[i][E_BET_CONTEST] == contest)
		{
			count++;
		}
	}

	return count;
}

stock Events_SettleBets(event,contest,winner)
{
	new pool = 0, backed = 0;

	for (new i = 0;i < EVENTS_BETS;i++)
	{
		if (s_Bets[i][E_BET_USED] && s_Bets[i][E_BET_EVENT] == event && s_Bets[i][E_BET_CONTEST] == contest)
		{
			pool += s_Bets[i][E_BET_STAKE];

			if (s_Bets[i][E_BET_ON] == winner)
			{
				backed += s_Bets[i][E_BET_STAKE];
			}
		}
	}

	if (pool <= 0)
	{
		return 0;
	}

    if (winner == 0)
    {
        for (new i = 0;i < EVENTS_BETS;i++)
        {
            if (s_Bets[i][E_BET_USED] && s_Bets[i][E_BET_EVENT] == event && s_Bets[i][E_BET_CONTEST] == contest)
            {
                Events_PayCharacter(s_Bets[i][E_BET_BETTOR],s_Bets[i][E_BET_STAKE],"bet returned");
                s_Bets[i][E_BET_USED] = false;
            }
        }
        mysql_tquery_s(g_Mysql,str_format("UPDATE event_bets SET paid = 1 WHERE event_id = %d AND contest = %d",s_Events[event][E_EVENT_ROW],contest));
        return pool;
    }

	new cut = pool * EVENTS_HOUSE_CUT / 100, paid = 0;

	for (new i = 0;i < EVENTS_BETS;i++)
	{
		if (!s_Bets[i][E_BET_USED] || s_Bets[i][E_BET_EVENT] != event || s_Bets[i][E_BET_CONTEST] != contest)
		{
			continue;
		}

		if (backed > 0 && s_Bets[i][E_BET_ON] == winner)
		{
			new share = (pool - cut) * s_Bets[i][E_BET_STAKE] / backed;
			Events_PayCharacter(s_Bets[i][E_BET_BETTOR],share,"winning bet");
			paid += share;
		}

		s_Bets[i][E_BET_USED] = false;
	}

	Events_PayCharacter(s_Events[event][E_EVENT_HOST],pool - paid,"the bookmaker's cut");
	mysql_tquery_s(g_Mysql,str_format("UPDATE event_bets SET paid = 1 WHERE event_id = %d AND contest = %d",s_Events[event][E_EVENT_ROW],contest));
	return paid;
}

stock Events_AwardContest(event,contest,first,second,third)
{
	new share = s_Events[event][E_EVENT_PURSE] / max(Events_CountContests(event),1), places[3], paid = 0;
	places[0] = first;
	places[1] = second;
	places[2] = third;
	new const percents[3] = {60, 30, 10};

	for (new place = 0;place < 3;place++)
	{
		if (places[place] <= 0)
		{
			continue;
		}

		new amount = share * percents[place] / 100;

		if (place == 0 && third <= 0)
		{
			amount += share * percents[2] / 100;
		}

		Events_PayCharacter(places[place],amount,"prize");
		paid += amount;
	}

	if (share - paid > 0)
	{
		Events_PayCharacter(s_Events[event][E_EVENT_HOST],share - paid,"unclaimed prize");
	}

	new trophy = g_ContestDefs[contest][E_CONTEST_DEF_TROPHY], playerid = Groups_PlayerByCharacter(first);

	if (trophy != -1 && playerid != INVALID_PLAYER_ID)
	{
		Inventory_Give(playerid,Item_GetDefKind(trophy),trophy,1,ITEM_STARS_MAX);
	}

	s_Events[event][E_EVENT_DONE_CONTESTS] |= 1 << contest;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO event_results (event_id, contest, first_character_id, second_character_id, third_character_id, at) VALUES (%d, %d, %d, %d, %d, %d)",s_Events[event][E_EVENT_ROW],contest,first,second,third,gettime()));
	Events_SettleBets(event,contest,first);
	pawn_call_public("Events_OnContestDone","ddd",event,contest,first);
}

stock Events_End(event)
{
	if (!Events_IsValid(event) || s_Events[event][E_EVENT_STATE] == EVENT_DONE)
	{
		return;
	}

    if (Events_GetRunningEvent() == event)
    {
        Events_StopContest();
    }
	for (new contest = 0;contest < CONTEST_COUNT;contest++)
	{
		if (Events_HasContest(event,contest) && !Events_IsContestDone(event,contest))
		{
			Events_PayCharacter(s_Events[event][E_EVENT_HOST],s_Events[event][E_EVENT_PURSE] / max(Events_CountContests(event),1),"unrun contest");

			for (new i = 0;i < EVENTS_BETS;i++)
			{
				if (s_Bets[i][E_BET_USED] && s_Bets[i][E_BET_EVENT] == event && s_Bets[i][E_BET_CONTEST] == contest)
				{
					Events_PayCharacter(s_Bets[i][E_BET_BETTOR],s_Bets[i][E_BET_STAKE],"bet returned");
					s_Bets[i][E_BET_USED] = false;
				}
			}
		}
	}

	Events_PayCharacter(s_Events[event][E_EVENT_HOST],s_Events[event][E_EVENT_FEES],"entry fees");
	s_Events[event][E_EVENT_STATE] = EVENT_DONE;
	mysql_tquery_s(g_Mysql,str_format("UPDATE events SET state = %d, ends_at = %d WHERE id = %d",EVENT_DONE,gettime(),s_Events[event][E_EVENT_ROW]));
	pawn_call_public("Events_OnEnded","dd",event,s_Events[event][E_EVENT_KIND]);
	s_Events[event][E_EVENT_USED] = false;
	Events_RefreshHerald();
}

stock Events_SetRunning(event)
{
	if (Events_IsValid(event) && s_Events[event][E_EVENT_STATE] == EVENT_OPEN)
	{
		s_Events[event][E_EVENT_STATE] = EVENT_RUNNING;
		mysql_tquery_s(g_Mysql,str_format("UPDATE events SET state = %d WHERE id = %d",EVENT_RUNNING,s_Events[event][E_EVENT_ROW]));
	}
}

stock Events_Reminders(event)
{
	new left = s_Events[event][E_EVENT_STARTS] - gettime(), list[96], text[144];

	if (s_Events[event][E_EVENT_STATE] != EVENT_OPEN || s_Events[event][E_EVENT_KIND] == EVENT_FAIR)
	{
		return;
	}

	if (!s_Events[event][E_EVENT_WARNED_HOUR] && left <= 3600)
	{
		s_Events[event][E_EVENT_WARNED_HOUR] = true;
		Events_DescribeContests(event,list);
		format(text,sizeof(text),"Within the hour, at the lists " EVENTS_LISTS_WHERE ": %s. The herald still takes entries.",list);
		Crier_Announce("event","The lists",text);
	}

	if (!s_Events[event][E_EVENT_WARNED_SOON] && left <= 600)
	{
		s_Events[event][E_EVENT_WARNED_SOON] = true;
		Crier_Announce("event","The lists","The heralds are calling the contestants to the lists " EVENTS_LISTS_WHERE "!");
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Events_Load()
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, host_character_id, starts_at, ends_at, purse, entry_fee, contests, fees FROM events WHERE state < %d ORDER BY id LIMIT %d",EVENT_DONE,EVENTS_MAX));
	new rows = cache_num_rows(), ids[EVENTS_MAX], loaded = 0;

	for (new r = 0;r < rows && r < EVENTS_MAX;r++)
	{
		new event = r;
		cache_get_value_name_int(r,"id",ids[r]);
		s_Events[event][E_EVENT_USED] = true;
		s_Events[event][E_EVENT_ROW] = ids[r];
		cache_get_value_name_int(r,"kind",s_Events[event][E_EVENT_KIND]);
		cache_get_value_name_int(r,"host_character_id",s_Events[event][E_EVENT_HOST]);
		cache_get_value_name_int(r,"starts_at",s_Events[event][E_EVENT_STARTS]);
		cache_get_value_name_int(r,"ends_at",s_Events[event][E_EVENT_ENDS]);
		cache_get_value_name_int(r,"purse",s_Events[event][E_EVENT_PURSE]);
		cache_get_value_name_int(r,"entry_fee",s_Events[event][E_EVENT_FEE]);
		cache_get_value_name_int(r,"contests",s_Events[event][E_EVENT_CONTESTS]);
		cache_get_value_name_int(r,"fees",s_Events[event][E_EVENT_FEES]);
		s_Events[event][E_EVENT_STATE] = EVENT_OPEN;
		s_Events[event][E_EVENT_DONE_CONTESTS] = 0;
		s_Events[event][E_EVENT_WARNED_HOUR] = true;
		s_Events[event][E_EVENT_WARNED_SOON] = true;
		loaded++;
	}

	for (new event = 0;event < loaded;event++)
	{
		await mysql_aquery_s(g_Mysql,str_format("SELECT contest, character_id, score, item_param, item_stars FROM event_entries WHERE event_id = %d",ids[event]));

		for (new r = 0, entries = cache_num_rows();r < entries;r++)
		{
			new contest, characterid, score, item, stars;
			cache_get_value_name_int(r,"contest",contest);
			cache_get_value_name_int(r,"character_id",characterid);
			cache_get_value_name_int(r,"score",score);
			cache_get_value_name_int(r,"item_param",item);
			cache_get_value_name_int(r,"item_stars",stars);

			if (contest < 0 || contest >= CONTEST_COUNT || s_EntryCount[event][contest] >= EVENTS_ENTRIES)
			{
				continue;
			}

			new index = s_EntryCount[event][contest]++;
			s_Entries[event][contest][index][E_ENTRY_CHARACTER] = characterid;
			s_Entries[event][contest][index][E_ENTRY_SCORE] = 0;
			s_Entries[event][contest][index][E_ENTRY_OUT] = false;
			s_Entries[event][contest][index][E_ENTRY_PLACED] = 0;
			s_Entries[event][contest][index][E_ENTRY_ITEM] = item;
			s_Entries[event][contest][index][E_ENTRY_STARS] = stars;
		}

		await mysql_aquery_s(g_Mysql,str_format("SELECT contest, bettor_character_id, on_character_id, stake FROM event_bets WHERE event_id = %d AND paid = 0",ids[event]));

		for (new r = 0, bets = cache_num_rows();r < bets;r++)
		{
			for (new slot = 0;slot < EVENTS_BETS;slot++)
			{
				if (!s_Bets[slot][E_BET_USED])
				{
					s_Bets[slot][E_BET_USED] = true;
					s_Bets[slot][E_BET_EVENT] = event;
					cache_get_value_name_int(r,"contest",s_Bets[slot][E_BET_CONTEST]);
					cache_get_value_name_int(r,"bettor_character_id",s_Bets[slot][E_BET_BETTOR]);
					cache_get_value_name_int(r,"on_character_id",s_Bets[slot][E_BET_ON]);
					cache_get_value_name_int(r,"stake",s_Bets[slot][E_BET_STAKE]);
					break;
				}
			}
		}
	}

	Events_RefreshHerald();
	return async loaded;
}
#pragma warning pop

forward Events_OnDeclared(event,kind);

public Events_OnDeclared(event,kind)
{
	return 1;
}

forward Events_OnContestDone(event,contest,winner);

public Events_OnContestDone(event,contest,winner)
{
	return 1;
}

forward Events_OnEnded(event,kind);

public Events_OnEnded(event,kind)
{
	return 1;
}
