CMD<ADMIN_LEVEL_ADMIN>:event(cmdid, playerid, params[])
{
	#pragma unused cmdid
	yield 1;

	new action[12], rest[64];

	if (sscanf(params,"s[12]S()[64]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/event list | tourney <minutes> <contest keys...> | sign <contest> | time | stop | end <slot> | fair | harvest | bonfires | market open/close/auto");
		return 1;
	}

    if (!strcmp(action,"market",true))
    {
        if (!strcmp(rest,"open",true) && rest[0] != EOS)
        {
            Market_SetOverride(1);
        }
        else if (!strcmp(rest,"close",true) && rest[0] != EOS)
        {
            Market_SetOverride(0);
        }
        else if (!strcmp(rest,"auto",true) && rest[0] != EOS)
        {
            Market_SetOverride(-1);
        }
        else
        {
            SendClientMessage(playerid,-1,"/event market open | close | auto");
            return 1;
        }
        SendClientMessage(playerid,-1,sprintf("Market: %s, %d objects, %d market/fair actors (households travel separately).",Market_IsOpen() ? ("open") : ("closed"),Market_CountPlaced(),Events_CountMarketActors()));
        return 1;
    }

	if (!strcmp(action,"tourney",true))
	{
		new minutes, keys[48], contests = 0;

		if (sscanf(rest,"is[48]",minutes,keys))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"/event tourney <minutes> joust archery melee wrestling logtoss drinking");
			return 1;
		}

		for (new contest = 0;contest < CONTEST_PRODUCE;contest++)
		{
			if (strfind(keys,g_ContestDefs[contest][E_CONTEST_DEF_KEY],true) != -1)
			{
				contests |= 1 << contest;
			}
		}

		new now = gettime(), event = await Events_Declare(EVENT_TOURNAMENT,contests,now + max(minutes,0) * 60,now + max(minutes,0) * 60 + 4 * 3600,0,0,0);
		SendClientMessage(playerid,0xFFFFFFFF,event != -1 ? ("Declared (no purse, no fee): the herald is at the lists.") : ("Couldn't declare it."));

		if (event != -1)
		{
			Events_Announce(event);
		}

		return 1;
	}

	if (!strcmp(action,"sign",true))
	{
		new contest = -1, reason[64];

		for (new i = 0;i < CONTEST_COUNT;i++)
		{
			if (!strcmp(rest,g_ContestDefs[i][E_CONTEST_DEF_KEY],true))
			{
				contest = i;
			}
		}

		new event = contest == -1 ? -1 : Events_FindOpen(contest);
		SendClientMessage(playerid,0xFFFFFFFF,event != -1 && Events_SignUp(playerid,event,contest,reason) ? ("Signed up.") : (reason[0] != EOS ? reason : ("No such contest open.")));
		return 1;
	}

	if (!strcmp(action,"time",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Events_CallTime() ? ("Time is called on the bout.") : ("No bout is being fought."));
		return 1;
	}

	if (!strcmp(action,"stop",true))
	{
		Events_StopContest();
		SendClientMessage(playerid,0xFFFFFFFF,"The running contest is stopped.");
		return 1;
	}

	if (!strcmp(action,"end",true))
	{
		Events_StopContest();
		Events_End(strval(rest));
		SendClientMessage(playerid,0xFFFFFFFF,"Ended: fees to the host, unrun purses back, bets returned.");
		return 1;
	}

	if (!strcmp(action,"fair",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Events_StartFair(0) != -1 ? ("The fair opens in Talmberg.") : ("A fair is on already."));
		return 1;
	}

	if (!strcmp(action,"harvest",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,Events_StartHarvest() != -1 ? ("The harvest festival is declared.") : ("A festival is on already."));
		return 1;
	}

	if (!strcmp(action,"bonfires",true))
	{
		Events_LightBonfires("Bonfires","The fires are lit on the village squares tonight.");
		SendClientMessage(playerid,0xFFFFFFFF,"Bonfires lit.");
		return 1;
	}

	for (new event = 0;event < EVENTS_MAX;event++)
	{
		if (Events_IsValid(event))
		{
			new list[96];
			Events_DescribeContests(event,list);
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d: %s, state %d, starts in %d s, purse %d, fees %d: %s",event,g_EventKindNames[Events_GetKind(event)],Events_GetState(event),Events_GetStarts(event) - gettime(),Events_GetPurse(event),Events_GetFees(event),list));
		}
	}

	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Running: event %d, contest %d, phase %d. Fair season %d, crowd %d.",Events_GetRunningEvent(),Events_GetRunningContest(),Events_GetRunPhase(),Events_GetFairSeason(),Events_CountCrowd()));
    SendClientMessage(playerid,-1,sprintf("Spectators: %d/%d. Market: %d objects, %d visitors, %d traders.",Events_CountSpectators(),EVENTS_SPECTATORS,Market_CountPlaced(),MarketVisitors_Count(),Trader_CountMarketPresent()));
	return 1;
}
