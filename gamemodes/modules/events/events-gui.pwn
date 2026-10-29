static const s_DeclareHours[4] = {1, 2, 4, 8};
static const s_DeclarePurses[5] = {0, 120, 240, 480, 960};
static const s_DeclareFees[4] = {0, 6, 12, 24};

stock Events_OpenOrder(playerid)
{
	new lines[16][96], count = 0, now = gettime();

	for (new event = 0;event < EVENTS_MAX && count < sizeof(lines) - 2;event++)
	{
		if (!Events_IsValid(event))
		{
			continue;
		}

		new money[24], fee[24], left = Events_GetStarts(event) - now;
		Economy_Format(Events_GetPurse(event),money);
		Economy_Format(Events_GetFee(event),fee);
		format(lines[count++],96,"The %s: %s. Purse %s, entry %s.",g_EventKindNames[Events_GetKind(event)],left > 0 ? sprintf("in %d minutes",left / 60 + 1) : ("under way"),money,fee);

		for (new contest = 0;contest < CONTEST_COUNT && count < sizeof(lines);contest++)
		{
			if (Events_HasContest(event,contest))
			{
				format(lines[count++],96,"   %s: %d entered, %d bets%s",g_ContestDefs[contest][E_CONTEST_DEF_NAME],Events_GetEntryCount(event,contest),Events_CountBets(event,contest),Events_IsContestDone(event,contest) ? (", done") : (Events_GetRunningContest() == contest && Events_GetRunningEvent() == event ? (", now") : ("")));
			}
		}
	}

	if (count == 0)
	{
		strcopy(lines[count++],"Nothing is proclaimed. The lord declares tournaments at the steward's desk.",96);
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"The order of the day");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH + 80.0,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"The order of the day",x,y,width);

	for (new i = 0;i < count;i++)
	{
		Kit_AddText(playerid,x,y + KIT_ROW * float(i),lines[i],i == 0 ? KIT_COLOUR_ACCENT : KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}
}

static Events_OpenContests(list[],size = sizeof(list))
{
	new count = 0;

	for (new event = 0;event < EVENTS_MAX;event++)
	{
		for (new contest = 0;contest < CONTEST_COUNT && count < size;contest++)
		{
			if (Events_HasContest(event,contest) && !Events_IsContestDone(event,contest) && Events_GetState(event) != EVENT_DONE && !(Events_GetRunningEvent() == event && Events_GetRunningContest() == contest))
			{
				list[count++] = event * CONTEST_COUNT + contest;
			}
		}
	}

	return count;
}

static Events_PickContest(playerid,const title[])
{
	new list[EVENTS_MAX * CONTEST_COUNT], count = Events_OpenContests(list);

	if (count == 0)
	{
		Gui_Notify(playerid,"No contest is taking entries now.");
		return -1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);

	for (new i = 0;i < count;i++)
	{
		new event = list[i] / CONTEST_COUNT, contest = list[i] % CONTEST_COUNT, label[32];
		strcopy(label,g_ContestDefs[contest][E_CONTEST_DEF_NAME]);
		label[0] = toupper(label[0]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,label,i,KIT_COLOUR_TEXT,sprintf("%d entered",Events_GetEntryCount(event,contest)),KIT_COLOUR_MUTED);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return -1;
	}

	return list[pick];
}

static Events_PickProduce(playerid)
{
	new slots[10], count = 0;

	for (new index = 0, total = Inventory_GetCount(playerid);index < total && count < sizeof(slots);index++)
	{
		new E_ITEM_KIND:kind, param, amount;

		if (Inventory_GetSlot(playerid,index,kind,param,amount) && amount > 0 && (kind == ITEM_KIND_FOOD || kind == ITEM_KIND_MATERIAL))
		{
			slots[count++] = index;
		}
	}

	if (count == 0)
	{
		Gui_Notify(playerid,"Bring some produce in your bag to enter it.");
		return -1;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Your best produce");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Your best produce",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new E_ITEM_KIND:kind, param, amount, name[ITEM_NAME_LEN];
		Inventory_GetSlot(playerid,slots[i],kind,param,amount);
		Item_GetName(kind,param,name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT,sprintf("%d stars",Inventory_GetSlotStars(playerid,slots[i])),KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return -1;
	}

	return slots[pick];
}

stock Events_OpenSignUp(playerid)
{
	new chosen = Events_PickContest(playerid,"Sign up");

	if (chosen == -1)
	{
		return;
	}

	new event = chosen / CONTEST_COUNT, contest = chosen % CONTEST_COUNT, index = -1, reason[64];

	if (contest == CONTEST_PRODUCE)
	{
		index = Events_PickProduce(playerid);

		if (index == -1)
		{
			return;
		}
	}

	if (Events_SignUp(playerid,event,contest,reason,sizeof(reason),index))
	{
		Gui_Notify(playerid,sprintf("The herald writes your name down for %s. Be %s when it's called.",g_ContestDefs[contest][E_CONTEST_DEF_NAME],g_ContestDefs[contest][E_CONTEST_DEF_CALL]));
	}
	else
	{
		Gui_Notify(playerid,reason);
	}
}

stock Events_OpenBet(playerid)
{
	new chosen = Events_PickContest(playerid,"Place a bet");

	if (chosen == -1)
	{
		return;
	}

	new event = chosen / CONTEST_COUNT, contest = chosen % CONTEST_COUNT, count = Events_GetEntryCount(event,contest);

	if (count == 0)
	{
		Gui_Notify(playerid,"Nobody's entered to bet on yet.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"On whom?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"On whom?",x,y,width);

	for (new i = 0;i < count;i++)
	{
		new name[MAX_PLAYER_NAME];
		Events_EntryName(event,contest,i,name);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,name,i,KIT_COLOUR_TEXT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= count)
	{
		return;
	}

	new text[8], reason[64];

	if (!Groups_AskText(playerid,"The stake","How many pfennig?",text,sizeof(text)))
	{
		return;
	}

	if (Events_PlaceBet(playerid,event,contest,Events_EntryCharacter(event,contest,pick),strval(text),reason))
	{
		Gui_Notify(playerid,"The bookmaker chalks up your bet.");
	}
	else
	{
		Gui_Notify(playerid,reason);
	}
}

stock Events_OpenDeclare(playerid)
{
	new contests = (1 << CONTEST_JOUST) | (1 << CONTEST_ARCHERY), hours = 1, purse = 1, fee = 1;

	for (;;)
	{
		new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, money[24], feeText[24], rows = CONTEST_PRODUCE + 4;
		Economy_Format(s_DeclarePurses[purse],money);
		Economy_Format(s_DeclareFees[fee],feeText);
		Kit_Begin(playerid,KIT_LAYER_SCREEN,"Declare a tournament");
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,EVENTS_PANEL_WIDTH,float(rows) * KIT_ROW * 0.85 + 6.0 + KIT_ROW + 12.0,"Declare a tournament",x,y,width);

		for (new contest = 0;contest < CONTEST_PRODUCE;contest++)
		{
			new label[32], bool:on = (contests & (1 << contest)) != 0;
			strcopy(label,g_ContestDefs[contest][E_CONTEST_DEF_NAME]);
			label[0] = toupper(label[0]);
			Kit_AddChoice(playerid,x,y + KIT_ROW * 0.85 * float(contest),width,label,contest,KIT_COLOUR_TEXT,on ? ("held") : ("no"),on ? KIT_COLOUR_GOOD : KIT_COLOUR_MUTED);
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.85 * float(CONTEST_PRODUCE),width,"Starts",100,KIT_COLOUR_TEXT,sprintf("in %d hours",s_DeclareHours[hours]),KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.85 * float(CONTEST_PRODUCE + 1),width,"Purse from the treasury",101,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.85 * float(CONTEST_PRODUCE + 2),width,"Entry fee",102,KIT_COLOUR_TEXT,feeText,KIT_COLOUR_ACCENT);
		Kit_AddChoice(playerid,x,y + KIT_ROW * 0.85 * float(CONTEST_PRODUCE + 3),width,"Proclaim it",103,KIT_COLOUR_GOOD);
		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows) * KIT_ROW * 0.85 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
		new pick = await Kit_Present(playerid);
		Kit_Close(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || (!Realm_IsRuler(playerid) && !Realm_IsDuke(playerid)))
		{
			return;
		}

		if (pick >= 0 && pick < CONTEST_PRODUCE)
		{
			contests ^= 1 << pick;
			continue;
		}

		switch (pick)
		{
			case 100: hours = (hours + 1) % sizeof(s_DeclareHours);
			case 101: purse = (purse + 1) % sizeof(s_DeclarePurses);
			case 102: fee = (fee + 1) % sizeof(s_DeclareFees);
			case 103:
			{
				if (contests == 0)
				{
					Gui_Notify(playerid,"Choose at least one contest.");
					continue;
				}

				if (Events_FindKind(EVENT_TOURNAMENT) != -1)
				{
					Gui_Notify(playerid,"A tournament is proclaimed already.");
					return;
				}

				if (!Events_TakeFromCounty(s_DeclarePurses[purse]))
				{
					Gui_Notify(playerid,"The treasury can't put up that purse.");
					continue;
				}

				new now = gettime(), starts = now + s_DeclareHours[hours] * 3600, event = await Events_Declare(EVENT_TOURNAMENT,contests,starts,starts + 4 * 3600,Character_GetId(playerid),s_DeclarePurses[purse],s_DeclareFees[fee]), list[96], text[REALM_DECREE_TEXT];

				if (event == -1)
				{
					Events_PayCounty(s_DeclarePurses[purse]);
					Gui_Notify(playerid,"It can't be proclaimed now.");
					return;
				}

				Events_DescribeContests(event,list);
				format(text,sizeof(text),"A tournament at the lists " EVENTS_LISTS_WHERE ": %s.",list);
				Realm_IssueDecree(REALM_DECREE_FEAST,text,starts,starts + 4 * 3600,Character_GetId(playerid));
				Events_Announce(event);
				Gui_Notify(playerid,"The tournament is proclaimed, and the herald takes the roll at the lists.");
				return;
			}
		}
	}
}

forward Events_MenuOrder(playerid,index,data);

public Events_MenuOrder(playerid,index,data)
{
	Events_OpenOrder(playerid);
	return 1;
}

forward Events_MenuSignUp(playerid,index,data);

public Events_MenuSignUp(playerid,index,data)
{
	Events_OpenSignUp(playerid);
	return 1;
}

forward Events_MenuBet(playerid,index,data);

public Events_MenuBet(playerid,index,data)
{
	Events_OpenBet(playerid);
	return 1;
}

forward Events_MenuDeclare(playerid,index,data);

public Events_MenuDeclare(playerid,index,data)
{
	Events_OpenDeclare(playerid);
	return 1;
}

forward Events_OfferExpired(playerid,epoch);
public Events_OfferExpired(playerid,epoch)
{
    if (Gui_IsFlowCurrent(playerid,epoch) && Kit_IsOpen(playerid))
    {
        Kit_Close(playerid);
        Gui_Notify(playerid,"The offer has expired. Watch for the next contest or ask the host again.");
    }
    return 1;
}

forward Events_HeraldDeferred(playerid);
public Events_HeraldDeferred(playerid)
{
    if (IsPlayerConnected(playerid) && Events_GetPlayerHerald() == playerid && Events_IsAtHeraldStand(playerid))
    {
        Events_OpenHerald(playerid);
    }
    return 1;
}

stock Events_OpenHerald(playerid)
{
    yield 1;
    new epoch = Gui_BeginFlow(playerid);
    Events_SetHeraldFlow(epoch);
    for (;;)
    {
        if (Events_GetPlayerHerald() != playerid || !Events_IsAtHeraldStand(playerid))
        {
            return;
        }
        new Float:positionX, Float:positionY, Float:width;
        Kit_Begin(playerid,KIT_LAYER_SCREEN,"The herald's stand");
        Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,300.0,6.0 * KIT_ROW + 12.0,"The herald's stand",positionX,positionY,width);
        Kit_AddChoice(playerid,positionX,positionY,width,"Call the next pair",0);
        Kit_AddChoice(playerid,positionX,positionY + KIT_ROW,width,"Call time",1);
        Kit_AddChoice(playerid,positionX,positionY + KIT_ROW * 2.0,width,"Accept a requested yield",2);
        Kit_AddChoice(playerid,positionX,positionY + KIT_ROW * 3.0,width,"Stop the bout",3,KIT_COLOUR_BAD);
        Kit_AddChoice(playerid,positionX,positionY + KIT_ROW * 4.0,width,"Hand the stand to Hans",4);
        Kit_AddButton(playerid,positionX + width / 2.0 - 40.0,positionY + KIT_ROW * 5.0 + 8.0,80.0,"Close",KIT_BACK);
        new pick = await Kit_Present(playerid);
        if (!Gui_IsFlowCurrent(playerid,epoch))
        {
            return;
        }
        Kit_Close(playerid);
        if (pick == KIT_BACK || Events_GetPlayerHerald() != playerid || !Events_IsAtHeraldStand(playerid))
        {
            return;
        }
        if (!Events_HeraldAction(playerid,pick))
        {
            Gui_Notify(playerid,"That call isn't available now. A yield must be requested by a fighter, and time needs a running bout.");
        }
        if (pick == 4)
        {
            return;
        }
    }
}

forward Events_AppointDeferred(playerid);
public Events_AppointDeferred(playerid)
{
    if (IsPlayerConnected(playerid) && Events_IsAtHeraldStand(playerid))
    {
        Events_OpenAppointment(playerid);
    }
    return 1;
}

stock Events_OpenAppointment(playerid)
{
    yield 1;
    new event = Events_FindKind(EVENT_TOURNAMENT), epoch = Gui_BeginFlow(playerid);
    if (!Events_CanAppointHerald(playerid,event))
    {
        Gui_Notify(playerid,"Only the tournament host can appoint a herald. Speak to the host on the stand.");
        return;
    }
    new players[8], count = 0, Float:positionX, Float:positionY, Float:width;
    Kit_Begin(playerid,KIT_LAYER_SCREEN,"Appoint a herald");
    foreach (new targetid : Player)
    {
        if (count < sizeof(players) && !IsPlayerNPC(targetid) && Events_IsAtHeraldStand(targetid) && !Mount_IsRiding(targetid) && !Character_IsBusy(targetid))
        {
            players[count++] = targetid;
        }
    }
    Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,300.0,float(count + 1) * KIT_ROW + 12.0,"Appoint a herald",positionX,positionY,width);
    for (new i = 0;i < count;i++)
    {
        new name[MAX_PLAYER_NAME];
        Character_GetName(players[i],name);
        Kit_AddChoice(playerid,positionX,positionY + KIT_ROW * float(i),width,name,i);
    }
    Kit_AddButton(playerid,positionX + width / 2.0 - 40.0,positionY + KIT_ROW * float(count) + 8.0,80.0,"Back",KIT_BACK);
    new pick = await Kit_Present(playerid);
    if (!Gui_IsFlowCurrent(playerid,epoch))
    {
        return;
    }
    Kit_Close(playerid);
    if (pick < 0 || pick >= count || !Events_CanAppointHerald(playerid,event) || !Events_IsAtHeraldStand(playerid) || !Events_IsAtHeraldStand(players[pick]))
    {
        return;
    }
    if (players[pick] == playerid)
    {
        Events_AppointHerald(playerid,playerid,event);
    }
    else if (!Gui_IsBusy(players[pick]))
    {
        SetTimerEx("Events_HeraldOfferDeferred",0,false,"dddd",playerid,players[pick],event,Character_GetId(players[pick]));
        Gui_Notify(playerid,"The herald appointment has been offered. The player must accept on the panel.");
    }
    else
    {
        Gui_Notify(playerid,"That player has a panel open. Ask them to close it and try again.");
    }
}

forward Events_HeraldOfferDeferred(hostid,playerid,event,characterid);
public Events_HeraldOfferDeferred(hostid,playerid,event,characterid)
{
    if (IsPlayerConnected(hostid) && IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid && Events_CanAppointHerald(hostid,event) && !Gui_IsBusy(playerid))
    {
        Events_OpenHeraldOffer(hostid,playerid,event,characterid);
    }
    return 1;
}

stock Events_OpenHeraldOffer(hostid,playerid,event,characterid)
{
    yield 1;
    new epoch = Gui_BeginFlow(playerid), hostCharacter = Character_GetId(hostid), offeredAt = GetTickCount();
    SetTimerEx("Events_OfferExpired",60000,false,"dd",playerid,epoch);
    new Float:positionX, Float:positionY, Float:width;
    Kit_Begin(playerid,KIT_LAYER_SCREEN,"Be the herald");
    Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,300.0,KIT_ROW * 3.0 + 12.0,"Be the herald",positionX,positionY,width);
    Kit_AddText(playerid,positionX,positionY,"The host offers you the herald's stand.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
    Kit_AddChoice(playerid,positionX,positionY + KIT_ROW,width,"Accept the appointment",1,KIT_COLOUR_GOOD);
    Kit_AddButton(playerid,positionX + width / 2.0 - 40.0,positionY + KIT_ROW * 2.0 + 8.0,80.0,"Decline",KIT_BACK);
    new pick = await Kit_Present(playerid);
    if (!Gui_IsFlowCurrent(playerid,epoch))
    {
        return;
    }
    Kit_Close(playerid);
    if (pick == 1 && Character_GetId(playerid) == characterid && IsPlayerConnected(hostid) && Character_GetId(hostid) == hostCharacter && GetTickCount() - offeredAt <= 60000 && Events_AppointHerald(hostid,playerid,event))
    {
        Gui_Notify(hostid,"The player accepted the herald's stand.");
    }
}

forward Events_MenuAppoint(playerid,index,data);
public Events_MenuAppoint(playerid,index,data)
{
    #pragma unused index, data
    SetTimerEx("Events_AppointDeferred",0,false,"d",playerid);
    return 1;
}

forward Events_SparringDeferred(playerid);
public Events_SparringDeferred(playerid)
{
    if (Events_IsSparringOffered(playerid))
    {
        if (Gui_IsBusy(playerid))
        {
            SetTimerEx("Events_SparringDeferred",500,false,"d",playerid);
        }
        else
        {
            Events_OpenSparring(playerid);
        }
    }
    return 1;
}

stock Events_OpenSparring(playerid)
{
    yield 1;
    new epoch = Gui_BeginFlow(playerid), characterid = Character_GetId(playerid);
    SetTimerEx("Events_OfferExpired",60000,false,"dd",playerid,epoch);
    new Float:positionX, Float:positionY, Float:width;
    Kit_Begin(playerid,KIT_LAYER_SCREEN,"The sparring knight");
    Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,320.0,KIT_ROW * 4.0 + 12.0,"The sparring knight",positionX,positionY,width);
    Kit_AddText(playerid,positionX,positionY,"You're the only entrant. Joust against the sparring knight?",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
    Kit_AddText(playerid,positionX,positionY + KIT_ROW,"No prize. Bets are returned. Accept within 60 seconds.",KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
    Kit_AddChoice(playerid,positionX,positionY + KIT_ROW * 2.0,width,"Accept the practice bout",1,KIT_COLOUR_GOOD);
    Kit_AddButton(playerid,positionX + width / 2.0 - 40.0,positionY + KIT_ROW * 3.0 + 8.0,80.0,"Decline",KIT_BACK);
    new pick = await Kit_Present(playerid);
    if (!Gui_IsFlowCurrent(playerid,epoch))
    {
        return;
    }
    Kit_Close(playerid);
    if (Character_GetId(playerid) != characterid)
    {
        return;
    }
    if (pick == 1)
    {
        if (!Events_AcceptSparring(playerid))
        {
            Gui_Notify(playerid,"The sparring offer has ended. Watch for the next contest.");
        }
    }
    else if (Events_GetRunPhase() == RUN_CALLING && Events_GetRunningContest() == CONTEST_JOUST)
    {
        Events_DeclineSparring(playerid);
    }
}

#include <pp-hooks>

hook Actors_OnMenuBuild(playerid,index)
{
	if (index == -1)
	{
		return;
	}

	if (index == Events_GetHerald())
	{
		Actors_MenuAdd(playerid,"The order of the day","Events_MenuOrder");
		Actors_MenuAdd(playerid,"Sign up for a contest","Events_MenuSignUp",0,KIT_COLOUR_GOOD);
		Actors_MenuAdd(playerid,"Place a bet","Events_MenuBet");
        if (Events_CanAppointHerald(playerid,Events_FindKind(EVENT_TOURNAMENT)))
        {
            Actors_MenuAdd(playerid,"Appoint a herald","Events_MenuAppoint");
        }
		return;
	}

	if (index == Realm_GetSteward() && (Realm_IsRuler(playerid) || Realm_IsDuke(playerid)))
	{
		Actors_MenuAdd(playerid,"Declare a tournament","Events_MenuDeclare",0,KIT_COLOUR_ACCENT);
	}
}
