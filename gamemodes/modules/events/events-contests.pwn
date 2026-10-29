forward bool:Events_IsAtJoustGate(playerid,side,course);
forward bool:Events_StartRiddenJoust(playerA,playerB,course);
forward Events_GetSparringKnight();
forward bool:Events_PrepareSparring(playerid);

enum _:E_RUN_PHASES
{
	RUN_IDLE,
	RUN_CALLING,
	RUN_BOUT,
	RUN_GAP,
	RUN_SINGLE,
	RUN_DRINKING,
}

enum E_EVENT_RUN
{
	E_RUN_EVENT,
	E_RUN_CONTEST,
	E_RUN_PHASE,
	E_RUN_A,
	E_RUN_B,
	E_RUN_PASS,
	E_RUN_POINTS[2],
	E_RUN_OUT_SINCE[2],
	E_RUN_UNTIL,
	E_RUN_TURN,
	E_RUN_SHOTS,
	E_RUN_ROUND,
	E_RUN_RUNNER_UP,
	E_RUN_THIRD,
}

enum E_EVENT_BAR
{
	bool:E_BAR_ACTIVE,
	E_BAR_ID,
	E_BAR_STARTED,
	E_BAR_RESULT,
}

enum _:E_BOUT_RESULTS
{
	BOUT_KNOCKDOWN,
	BOUT_POINTS,
	BOUT_DRAW,
	BOUT_RING_OUT,
	BOUT_ARMED,
	BOUT_LEFT,
	BOUT_YIELD,
}

enum E_EVENT_FIGHTER
{
	bool:E_FIGHTER_IN,
	E_FIGHTER_SWING,
	E_FIGHTER_WEAPON,
	E_FIGHTER_SHIELD,
	E_FIGHTER_TOKEN,
	E_FIGHTER_YIELD_AT,
}

static const s_EventsBlowPoints[] = {3, 3, 2, 2, 0, 1};

static s_Run[E_EVENT_RUN] = {-1, -1, RUN_IDLE, -1, -1, 0, {0, 0}, {0, 0}, 0, 0, 0, 0, 0, 0};
static s_Bar[MAX_PLAYERS][E_EVENT_BAR];
static s_Fighter[MAX_PLAYERS][E_EVENT_FIGHTER];
static s_RunIdleSince;
static s_LastCall[144];
static s_BoutSerial;
static bool:s_BoutFought;
static s_RingWarned[MAX_PLAYERS];

stock Events_WorldToLists(Float:x,Float:y,&Float:frameX,&Float:frameY)
{
	new Float:rzf = Events_ListsFrameAngle(), Float:dx = x - g_EventsLists[0], Float:dy = y - g_EventsLists[1];
	frameX = dx * floatcos(rzf,degrees) + dy * floatsin(rzf,degrees);
	frameY = -dx * floatsin(rzf,degrees) + dy * floatcos(rzf,degrees);
}

stock bool:Events_IsInsideLists(Float:x,Float:y,Float:z)
{
	new Float:frameX, Float:frameY;
	Events_WorldToLists(x,y,frameX,frameY);
	return floatabs(frameX) <= EVENTS_LISTS_HALF_LENGTH && floatabs(frameY) <= EVENTS_LISTS_HALF_WIDTH && floatabs(z - g_EventsLists[2]) < 6.0;
}

stock Events_GetRunningEvent()
{
	return s_Run[E_RUN_PHASE] == RUN_IDLE ? -1 : s_Run[E_RUN_EVENT];
}

stock Events_GetRunningContest()
{
	return s_Run[E_RUN_PHASE] == RUN_IDLE ? -1 : s_Run[E_RUN_CONTEST];
}

stock Events_GetRunPhase()
{
	return s_Run[E_RUN_PHASE];
}

stock Events_GetCourse()
{
    return s_Run[E_RUN_PASS];
}

stock Events_GetBout(&a,&b)
{
	a = s_Run[E_RUN_A];
	b = s_Run[E_RUN_B];
}

stock Float:Events_BarValue(started,period = EVENTS_BAR_PERIOD)
{
	new phase = (GetTickCount() - started) % period;
	return phase < period / 2 ? float(phase) * 200.0 / float(period) : 200.0 - float(phase) * 200.0 / float(period);
}

stock Events_BarQuality(Float:value)
{
	return value >= EVENTS_BAR_CLEAN ? 2 : (value >= EVENTS_BAR_GOOD ? 1 : 0);
}

stock Events_StartBar(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	Events_StopBar(playerid);
	s_Bar[playerid][E_BAR_ACTIVE] = true;
	s_Bar[playerid][E_BAR_STARTED] = GetTickCount() + random(EVENTS_BAR_PERIOD);
	s_Bar[playerid][E_BAR_RESULT] = -1;
	s_Bar[playerid][E_BAR_ID] = PBar_Create(playerid,260.0,360.0,120.0,4.0,0xC9B27CFF);
	PBar_Show(playerid,s_Bar[playerid][E_BAR_ID]);
	Infobox_Show(playerid,"The lists","Press ~y~Y~w~ when the bar tops out.",1,3);
}

stock Events_StopBar(playerid)
{
	if (!s_Bar[playerid][E_BAR_ACTIVE])
	{
		return;
	}

	s_Bar[playerid][E_BAR_ACTIVE] = false;

	if (s_Bar[playerid][E_BAR_ID] != INVALID_PLAYER_BAR)
	{
		PBar_Destroy(playerid,s_Bar[playerid][E_BAR_ID]);
	}

	s_Bar[playerid][E_BAR_ID] = INVALID_PLAYER_BAR;
}

stock Events_BarPress(playerid)
{
	if (!s_Bar[playerid][E_BAR_ACTIVE])
	{
		return -1;
	}

	new quality = Events_BarQuality(Events_BarValue(s_Bar[playerid][E_BAR_STARTED]));

	if (s_Bar[playerid][E_BAR_RESULT] == -1)
	{
		s_Bar[playerid][E_BAR_RESULT] = quality;
		PlayerPlaySound(playerid,quality == 2 ? 1058 : (quality == 1 ? 1056 : 1055),0.0,0.0,0.0);
	}

	return quality;
}

stock Events_BarResult(playerid)
{
	return max(s_Bar[playerid][E_BAR_RESULT],0);
}

stock bool:Events_IsBarActive(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Bar[playerid][E_BAR_ACTIVE];
}

stock Events_Say(const text[])
{
	strcopy(s_LastCall,text);

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,120.0,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2]))
		{
			SendClientMessage(playerid,0xE8D8A8FF,text);
		}
	}
}

stock Events_EntryName(event,contest,index,dest[],size = sizeof(dest))
{
	new playerid = Events_PlayerOf(event,contest,index);

	if (playerid == INVALID_PLAYER_ID)
	{
		strcopy(dest,"someone away",size);
		return;
	}

	Character_GetName(playerid,dest,size);
}

static bool:Events_IsAtLists(playerid,contest)
{
	if (!IsPlayerConnected(playerid) || GetPlayerVirtualWorld(playerid) != 0)
	{
		return false;
	}

	if (contest == CONTEST_ARCHERY || contest == CONTEST_LOG_TOSS)
	{
		return IsPlayerInRangeOfPoint(playerid,EVENTS_LINE_RANGE,g_EventsLine[0],g_EventsLine[1],g_EventsLine[2] + 1.0);
	}

	if (contest == CONTEST_MELEE || contest == CONTEST_WRESTLING)
	{
		return Events_IsPlayerInRing(playerid);
	}

	if (contest == CONTEST_JOUST)
	{
		return Mount_IsRiding(playerid) && (IsPlayerInRangeOfPoint(playerid,15.0,g_EventsTilt[0][0],g_EventsTilt[0][1],g_EventsTilt[0][2] + 1.0) || IsPlayerInRangeOfPoint(playerid,15.0,g_EventsTilt[1][0],g_EventsTilt[1][1],g_EventsTilt[1][2] + 1.0));
	}

	return IsPlayerInRangeOfPoint(playerid,EVENTS_LISTS_RANGE,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2] + 1.0);
}

static Events_NextPair(event,contest,&a,&b)
{
	for (;;)
	{
		new left = 0, last = -1;
		a = -1;
		b = -1;

		for (new index = 0;index < Events_GetEntryCount(event,contest);index++)
		{
			new characterid, score, bool:isOut, placed;
			Events_GetEntry(event,contest,index,characterid,score,isOut,placed);

			if (isOut)
			{
				continue;
			}

			left++;
			last = index;

			if (score <= s_Run[E_RUN_ROUND])
			{
				if (a == -1)
				{
					a = index;
				}
				else if (b == -1)
				{
					b = index;
				}
			}
		}

		if (left <= 1)
		{
			a = last;
			return 0;
		}

		if (b != -1)
		{
			return 1;
		}

		if (a != -1)
		{
			Events_SetScore(event,contest,a,s_Run[E_RUN_ROUND] + 1);
		}

		s_Run[E_RUN_ROUND]++;
	}
}

stock Events_BeginContest(event,contest)
{
	if (!Events_HasContest(event,contest) || Events_IsContestDone(event,contest) || s_Run[E_RUN_PHASE] != RUN_IDLE)
	{
		return false;
	}

	new name[24];
	strcopy(name,g_ContestDefs[contest][E_CONTEST_DEF_NAME]);

	if (contest == CONTEST_JOUST && Events_GetEntryCount(event,contest) == 1)
	{
        Events_SetRunning(event);
        s_Run[E_RUN_EVENT] = event;
        s_Run[E_RUN_CONTEST] = contest;
        s_Run[E_RUN_A] = 0;
        s_Run[E_RUN_B] = -1;
        s_Run[E_RUN_PASS] = 0;
        s_Run[E_RUN_POINTS][0] = 0;
        s_Run[E_RUN_POINTS][1] = 0;
        s_Run[E_RUN_PHASE] = RUN_CALLING;
        s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_CALL_MS;
        Events_OfferSparring(event,Events_PlayerOf(event,contest,0));
        return true;
	}

	if (Events_GetEntryCount(event,contest) < 2)
	{
		Events_Say(sprintf("Too few came forward for %s; the herald calls it off.",name));
		Events_AwardContest(event,contest,Events_GetEntryCount(event,contest) == 1 ? Events_EntryCharacter(event,contest,0) : 0,0,0);
		return false;
	}

	Events_SetRunning(event);
	s_Run[E_RUN_EVENT] = event;
	s_Run[E_RUN_CONTEST] = contest;
	s_Run[E_RUN_ROUND] = 0;
	s_Run[E_RUN_TURN] = 0;
	s_Run[E_RUN_RUNNER_UP] = 0;
	s_Run[E_RUN_THIRD] = 0;
	name[0] = toupper(name[0]);
	Events_Say(sprintf("Hear ye! %s begins. Contestants, %s.",name,g_ContestDefs[contest][E_CONTEST_DEF_CALL]));

	if (contest == CONTEST_PRODUCE)
	{
		Events_JudgeProduce(event);
		return true;
	}

	if (contest == CONTEST_DRINKING)
	{
		s_Run[E_RUN_PHASE] = RUN_DRINKING;
		s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_DRINK_MS;
		return true;
	}

	if (g_ContestDefs[contest][E_CONTEST_DEF_BOUTS])
	{
		Events_CallBout();
	}
	else
	{
		Events_CallSingle();
	}

	return true;
}

stock Events_EntryCharacter(event,contest,index)
{
	new characterid, score, bool:isOut, placed;
	Events_GetEntry(event,contest,index,characterid,score,isOut,placed);
	return characterid;
}

static Events_CallBout()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], a, b;

	if (!Events_NextPair(event,contest,a,b))
	{
		Events_FinishContest(a != -1 ? Events_EntryCharacter(event,contest,a) : 0,s_Run[E_RUN_RUNNER_UP],s_Run[E_RUN_THIRD]);
		return;
	}

	new nameA[MAX_PLAYER_NAME], nameB[MAX_PLAYER_NAME];
	Events_EntryName(event,contest,a,nameA);
	Events_EntryName(event,contest,b,nameB);
	s_Run[E_RUN_A] = a;
	s_Run[E_RUN_B] = b;
	s_Run[E_RUN_PASS] = 0;
	s_Run[E_RUN_POINTS][0] = 0;
	s_Run[E_RUN_POINTS][1] = 0;
	s_Run[E_RUN_PHASE] = RUN_CALLING;
	s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_CALL_MS;
	s_BoutFought = false;

	if (contest != CONTEST_MELEE && contest != CONTEST_WRESTLING)
	{
		Events_Say(sprintf("%s against %s! To the %s.",nameA,nameB,contest == CONTEST_JOUST ? ("gates") : ("lists")));
        if (contest == CONTEST_JOUST)
        {
            for (new side = 0;side < 2;side++)
            {
                new playerid = Events_PlayerOf(event,contest,side == 0 ? a : b);
                if (playerid == INVALID_PLAYER_ID)
                {
                    continue;
                }
                if (!Mount_IsRiding(playerid) || Horse_IsNoGallop(Mount_GetHorse(playerid)) || !Mount_TypeCanGallop(Horse_GetType(Mount_GetHorse(playerid))))
                {
                    Gui_Notify(playerid,"Bring a horse that can gallop to your gate within 60 seconds or you forfeit.");
                }
                else if (GetPlayerPing(playerid) > MOUNT_MAX_PING)
                {
                    Gui_Notify(playerid,"Your ping is above 105 ms. Your horse can only trot; shield hits still score but helm hits will miss.");
                }
                if (IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_SLOT_HAND))
                {
                    Gui_Notify(playerid,"Put away what you're holding before taking your joust lance.");
                }
                Gui_Notify(playerid,side == 0 ? ("Take the west gate, south of the tilt. Ride in within 60 seconds.") : ("Take the east gate, north of the tilt. Ride in within 60 seconds."));
            }
        }
		return;
	}

	Events_Say(sprintf("%s against %s! To the ring.",nameA,nameB));

	for (new side = 0;side < 2;side++)
	{
		new playerid = Events_PlayerOf(event,contest,side == 0 ? a : b);

		if (playerid != INVALID_PLAYER_ID)
		{
			Gui_Notify(playerid,sprintf("The herald calls you to %s. Step into the ring beside the lists within %d seconds.",g_ContestDefs[contest][E_CONTEST_DEF_NAME],EVENTS_CALL_MS / 1000));
		}
	}
}

static Events_CallSingle()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST];

	while (s_Run[E_RUN_TURN] < Events_GetEntryCount(event,contest) && Events_PlayerOf(event,contest,s_Run[E_RUN_TURN]) == INVALID_PLAYER_ID)
	{
		s_Run[E_RUN_TURN]++;
	}

	if (s_Run[E_RUN_TURN] >= Events_GetEntryCount(event,contest))
	{
		Events_FinishScored();
		return;
	}

	new name[MAX_PLAYER_NAME];
	Events_EntryName(event,contest,s_Run[E_RUN_TURN],name);
	s_Run[E_RUN_A] = s_Run[E_RUN_TURN];
	s_Run[E_RUN_SHOTS] = 0;
	s_Run[E_RUN_PHASE] = RUN_SINGLE;
	s_Run[E_RUN_UNTIL] = GetTickCount() + (contest == CONTEST_ARCHERY ? EVENTS_ARCHERY_MS : EVENTS_TOSS_MS);
	Events_Say(sprintf("%s steps up to the line.",name));
	new playerid = Events_PlayerOf(event,contest,s_Run[E_RUN_A]);

	if (contest == CONTEST_LOG_TOSS && playerid != INVALID_PLAYER_ID)
	{
		Events_StartBar(playerid);
	}
	else if (playerid != INVALID_PLAYER_ID)
	{
		Gui_Notify(playerid,sprintf("Shoot %d arrows at the butts from the line. Farther butts score more.",EVENTS_ARROWS));
	}
}

stock Events_FormatBout(const nameW[],const nameL[],const how[],dest[],size = sizeof(dest))
{
	format(dest,size,"%s beats %s %s.",nameW,nameL,how);
}

stock Events_FormatFight(contest,result,const nameW[],const nameL[],pointsW,pointsL,dest[],size = sizeof(dest))
{
	switch (result)
	{
		case BOUT_KNOCKDOWN:
		{
			format(dest,size,"%s %s %s to the ground and wins the bout!",nameW,contest == CONTEST_WRESTLING ? ("throws") : ("knocks"),nameL);
		}
		case BOUT_POINTS:
		{
			format(dest,size,"Time! %s wins on points against %s, %d to %d.",nameW,nameL,pointsW,pointsL);
		}
		case BOUT_DRAW:
		{
			format(dest,size,"Time! %s and %s are level at %d points each: a draw. A coin toss sends %s through.",nameW,nameL,pointsW,nameW);
		}
		case BOUT_RING_OUT:
		{
			format(dest,size,"%s stepped out of the ring and loses the bout. %s goes through.",nameL,nameW);
		}
		case BOUT_YIELD:
		{
			format(dest,size,"%s yields to %s. %s wins the bout.",nameL,nameW,nameW);
		}
		case BOUT_ARMED:
		{
			format(dest,size,"%s struck with a weapon in the wrestling and is put out. %s goes through.",nameL,nameW);
		}
		default:
		{
			format(dest,size,"%s has left the field and loses the bout. %s goes through.",nameL,nameW);
		}
	}
}

stock Events_FightLeader(pointsA,pointsB)
{
	return pointsA == pointsB ? -1 : (pointsA > pointsB ? 0 : 1);
}

stock Events_BlowPoints(swing,bool:isArmed,bool:isBehind)
{
	new points = isArmed ? EVENTS_ARMED_BLOW : (swing >= 0 && swing < sizeof(s_EventsBlowPoints) ? s_EventsBlowPoints[swing] : 1);
	return isBehind ? points * 2 : points;
}

stock bool:Events_IsFightContest(contest)
{
	return contest == CONTEST_MELEE || contest == CONTEST_WRESTLING;
}

stock Events_GetFightPoints(&pointsA,&pointsB)
{
	pointsA = s_Run[E_RUN_POINTS][0];
	pointsB = s_Run[E_RUN_POINTS][1];
}

stock bool:Events_IsFighter(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Fighter[playerid][E_FIGHTER_IN];
}

stock Events_GetLastCall(dest[],size = sizeof(dest))
{
	strcopy(dest,s_LastCall,size);
}

stock bool:Events_CallTime()
{
	if (s_Run[E_RUN_PHASE] != RUN_BOUT)
	{
		return false;
	}

	s_Run[E_RUN_UNTIL] = GetTickCount();
	return true;
}

static Events_FighterSide(playerid)
{
	if (s_Run[E_RUN_PHASE] != RUN_BOUT || !Events_IsFightContest(s_Run[E_RUN_CONTEST]) || !Events_IsFighter(playerid))
	{
		return -1;
	}

	if (Events_PlayerOf(s_Run[E_RUN_EVENT],s_Run[E_RUN_CONTEST],s_Run[E_RUN_A]) == playerid)
	{
		return 0;
	}

	return Events_PlayerOf(s_Run[E_RUN_EVENT],s_Run[E_RUN_CONTEST],s_Run[E_RUN_B]) == playerid ? 1 : -1;
}

static Events_ReadyFighter(playerid,side,contest)
{
	s_Fighter[playerid][E_FIGHTER_IN] = true;
	s_Fighter[playerid][E_FIGHTER_TOKEN]++;
	s_Fighter[playerid][E_FIGHTER_WEAPON] = INVALID_WEAPON_INDEX;
	s_Fighter[playerid][E_FIGHTER_SHIELD] = INVALID_SHIELD_INDEX;
	s_Fighter[playerid][E_FIGHTER_YIELD_AT] = 0;

	if (Mount_IsRiding(playerid))
	{
		Mount_Dismount(playerid);
	}

	if (contest == CONTEST_WRESTLING)
	{
		s_Fighter[playerid][E_FIGHTER_WEAPON] = Combat_GetWeapon(playerid);
		s_Fighter[playerid][E_FIGHTER_SHIELD] = Combat_GetShield(playerid);

		if (s_Fighter[playerid][E_FIGHTER_WEAPON] != INVALID_WEAPON_INDEX)
		{
			Combat_Unequip(playerid);
		}

		if (s_Fighter[playerid][E_FIGHTER_SHIELD] != INVALID_SHIELD_INDEX)
		{
			Combat_UnequipShield(playerid);
		}
	}

	Combat_SetTourney(playerid,true);
	new Float:x, Float:y, Float:z, Float:angle;
	Events_RingMark(side,x,y,z,angle);
	Util_SafeTeleport(playerid,x,y,z,angle,0,0);

	if (contest == CONTEST_WRESTLING)
	{
		Gui_Notify(playerid,sprintf("Wrestle! Press ~y~Y~w~ to raise your fists. Landed blows score, blocked ones don't. First to %d points throws the other. Stay in the ring.",EVENTS_FIGHT_POINTS));
	}
	else
	{
		Gui_Notify(playerid,sprintf("Fight! The weapons are blunted: blows score points and hurt nobody. First to %d points knocks the other down. Stay in the ring.",EVENTS_FIGHT_POINTS));
	}
}

static Events_ReleaseFighter(playerid)
{
	if (!Util_IsValidPlayer(playerid) || !s_Fighter[playerid][E_FIGHTER_IN])
	{
		return;
	}

	s_Fighter[playerid][E_FIGHTER_IN] = false;
	s_Fighter[playerid][E_FIGHTER_TOKEN]++;
	Combat_SetTourney(playerid,false);

	if (!IsPlayerConnected(playerid) || !Session_HasCharacter(playerid))
	{
		return;
	}

	new weapon = s_Fighter[playerid][E_FIGHTER_WEAPON], shield = s_Fighter[playerid][E_FIGHTER_SHIELD];

	if (weapon != INVALID_WEAPON_INDEX && Combat_GetWeapon(playerid) == INVALID_WEAPON_INDEX && Inventory_Find(playerid,ITEM_KIND_WEAPON,weapon) != -1)
	{
		Combat_Equip(playerid,weapon);
	}

	if (shield != INVALID_SHIELD_INDEX && Combat_GetShield(playerid) == INVALID_SHIELD_INDEX && Inventory_Find(playerid,ITEM_KIND_SHIELD,shield) != -1)
	{
		Combat_EquipShield(playerid,shield);
	}
}

static Events_ShowFightPoints()
{
	for (new side = 0;side < 2;side++)
	{
		new playerid = Events_PlayerOf(s_Run[E_RUN_EVENT],s_Run[E_RUN_CONTEST],side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B]);

		if (playerid != INVALID_PLAYER_ID)
		{
			Infobox_Show(playerid,"The bout",sprintf("Points: you ~y~%d~w~, your opponent ~y~%d~w~.~n~Press ~y~N~w~ twice to yield.",s_Run[E_RUN_POINTS][side],s_Run[E_RUN_POINTS][1 - side]),2,4);
		}
	}
}

static Events_StartFight()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], names[2][MAX_PLAYER_NAME], line[144], seconds = (contest == CONTEST_WRESTLING ? EVENTS_WRESTLE_MS : EVENTS_MELEE_MS) / 1000;
	s_Run[E_RUN_PHASE] = RUN_BOUT;
	s_Run[E_RUN_UNTIL] = GetTickCount() + seconds * 1000;
	s_BoutSerial++;
	s_BoutFought = true;

	for (new side = 0;side < 2;side++)
	{
		new entry = side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B], playerid = Events_PlayerOf(event,contest,entry);
		s_Run[E_RUN_POINTS][side] = 0;
		s_Run[E_RUN_OUT_SINCE][side] = 0;
		Events_EntryName(event,contest,entry,names[side]);

		if (playerid != INVALID_PLAYER_ID)
		{
			Events_ReadyFighter(playerid,side,contest);
		}
	}

	if (contest == CONTEST_WRESTLING)
	{
		format(line,sizeof(line),"%s and %s square up. Wrestle! First to %d points, or the most in %d seconds.",names[0],names[1],EVENTS_FIGHT_POINTS,seconds);
	}
	else
	{
		format(line,sizeof(line),"%s and %s face off. Fight! First to %d points, or the most in %d seconds.",names[0],names[1],EVENTS_FIGHT_POINTS,seconds);
	}

	Events_Say(line);
	Events_ShowFightPoints();
}

static Events_EndBoutWith(winner,loser,const line[],result = BOUT_POINTS)
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST];
	Events_StopRiddenJoust(true);
	Events_SetOut(event,contest,loser,true);
	Events_SetScore(event,contest,winner,s_Run[E_RUN_ROUND] + 1);
	s_Run[E_RUN_THIRD] = s_Run[E_RUN_RUNNER_UP];
	s_Run[E_RUN_RUNNER_UP] = Events_EntryCharacter(event,contest,loser);
	Events_Say(line);
    pawn_call_public("Events_OnBoutEnded","ddddd",event,contest,Events_EntryCharacter(event,contest,winner),Events_EntryCharacter(event,contest,loser),result);

	for (new side = 0;side < 2;side++)
	{
		new playerid = Events_PlayerOf(event,contest,side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B]);

		if (playerid == INVALID_PLAYER_ID)
		{
			continue;
		}

		Events_StopBar(playerid);

		if (s_Fighter[playerid][E_FIGHTER_IN])
		{
			SetTimerEx("Events_FighterStandsDown",EVENTS_STAND_DOWN_MS,false,"dd",playerid,s_Fighter[playerid][E_FIGHTER_TOKEN]);
		}
		else
		{
			Combat_SetTourney(playerid,false);
		}
	}

	s_Run[E_RUN_PHASE] = RUN_GAP;
	s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_PASS_GAP_MS;
	s_Run[E_RUN_PASS] = -1;
}

static Events_EndBout(winner,loser,const how[])
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], nameW[MAX_PLAYER_NAME], nameL[MAX_PLAYER_NAME], line[144];
	Events_EntryName(event,contest,winner,nameW);
	Events_EntryName(event,contest,loser,nameL);
	Events_FormatBout(nameW,nameL,how,line);
	Events_EndBoutWith(winner,loser,line,BOUT_LEFT);
}

static Events_EndFight(winnerSide,result)
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], winner = winnerSide == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B], loser = winnerSide == 0 ? s_Run[E_RUN_B] : s_Run[E_RUN_A], nameW[MAX_PLAYER_NAME], nameL[MAX_PLAYER_NAME], line[144];
	Events_EntryName(event,contest,winner,nameW);
	Events_EntryName(event,contest,loser,nameL);
	Events_FormatFight(contest,result,nameW,nameL,s_Run[E_RUN_POINTS][winnerSide],s_Run[E_RUN_POINTS][1 - winnerSide],line);
	Events_EndBoutWith(winner,loser,line,result);
}

static Events_CallFightTime()
{
	new leader = Events_FightLeader(s_Run[E_RUN_POINTS][0],s_Run[E_RUN_POINTS][1]);

	if (leader == -1)
	{
		Events_EndFight(random(2),BOUT_DRAW);
		return;
	}

	Events_EndFight(leader,BOUT_POINTS);
}

static bool:Events_WatchFight(tick)
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], players[2];

	for (new side = 0;side < 2;side++)
	{
		players[side] = Events_PlayerOf(event,contest,side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B]);

		if (players[side] != INVALID_PLAYER_ID && !s_Fighter[players[side]][E_FIGHTER_IN])
		{
			players[side] = INVALID_PLAYER_ID;
		}
	}

	if (players[0] == INVALID_PLAYER_ID || players[1] == INVALID_PLAYER_ID)
	{
		Events_EndFight(players[0] == INVALID_PLAYER_ID ? 1 : 0,BOUT_LEFT);
		return true;
	}

	for (new side = 0;side < 2;side++)
	{
		new playerid = players[side], Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);

		if (Combat_IsKnockedDown(playerid) || Events_IsInsideRing(x,y,z))
		{
			s_Run[E_RUN_OUT_SINCE][side] = 0;
			continue;
		}

		if (s_Run[E_RUN_OUT_SINCE][side] == 0)
		{
			s_Run[E_RUN_OUT_SINCE][side] = tick;
			Gui_Notify(playerid,sprintf("You're outside the ring. Step back in within %d seconds or you lose the bout.",EVENTS_RING_GRACE_MS / 1000));
			continue;
		}

		if (tick - s_Run[E_RUN_OUT_SINCE][side] >= EVENTS_RING_GRACE_MS)
		{
			Events_EndFight(1 - side,BOUT_RING_OUT);
			return true;
		}
	}

	Events_WarnIntruders(players[0],players[1]);
	return false;
}

static Events_WarnIntruders(fighterA,fighterB)
{
	foreach (new playerid : Player)
	{
		if (playerid == fighterA || playerid == fighterB || s_RingWarned[playerid] == s_BoutSerial || IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || !Events_IsPlayerInRing(playerid))
		{
			continue;
		}

		s_RingWarned[playerid] = s_BoutSerial;
		Gui_Notify(playerid,"A bout is on. Step out of the ring.");
	}
}

stock bool:Events_IsRingWarned(playerid)
{
	return Util_IsValidPlayer(playerid) && s_BoutSerial != 0 && s_RingWarned[playerid] == s_BoutSerial;
}

stock Events_FormatRingLabel(const nameA[],const nameB[],pointsA,pointsB,msLeft,dest[],size = sizeof(dest))
{
	if (msLeft < 0)
	{
		format(dest,size,"%s %d - %d %s",nameA,pointsA,pointsB,nameB);
		return;
	}

	new seconds = (msLeft + 999) / 1000;
	format(dest,size,"%s %d - %d %s   %d:%02d left",nameA,pointsA,pointsB,nameB,seconds / 60,seconds % 60);
}

static Events_ShowRingScore(tick)
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], phase = s_Run[E_RUN_PHASE];

	if (phase == RUN_IDLE || !Events_IsFightContest(contest) || (phase == RUN_GAP && !s_BoutFought))
	{
		Events_SetRingLabel(EVENTS_RING_LABEL_IDLE);
		return;
	}

	new names[2][MAX_PLAYER_NAME], text[EVENTS_RING_LABEL_LEN];
	Events_EntryName(event,contest,s_Run[E_RUN_A],names[0]);
	Events_EntryName(event,contest,s_Run[E_RUN_B],names[1]);

	if (phase == RUN_CALLING)
	{
		format(text,sizeof(text),"%s against %s",names[0],names[1]);
	}
	else
	{
		Events_FormatRingLabel(names[0],names[1],s_Run[E_RUN_POINTS][0],s_Run[E_RUN_POINTS][1],phase == RUN_BOUT ? max(s_Run[E_RUN_UNTIL] - tick,0) : -1,text);
	}

	Events_SetRingLabel(text);
}

stock bool:Events_YieldPress(playerid)
{
	new side = Events_FighterSide(playerid);

	if (side == -1 || Combat_IsKnockedDown(playerid))
	{
		return false;
	}

	new tick = GetTickCount(), name[MAX_PLAYER_NAME];
	Events_EntryName(s_Run[E_RUN_EVENT],s_Run[E_RUN_CONTEST],side == 0 ? s_Run[E_RUN_B] : s_Run[E_RUN_A],name);

	if (s_Fighter[playerid][E_FIGHTER_YIELD_AT] != 0 && tick - s_Fighter[playerid][E_FIGHTER_YIELD_AT] <= EVENTS_YIELD_MS)
	{
		s_Fighter[playerid][E_FIGHTER_YIELD_AT] = 0;
		Gui_Notify(playerid,sprintf("You yield the bout to %s.",name));
		Events_EndFight(1 - side,BOUT_YIELD);
		return true;
	}

	s_Fighter[playerid][E_FIGHTER_YIELD_AT] = tick;
	Gui_Notify(playerid,sprintf("Press ~y~N~w~ again within %d seconds to yield the bout to %s.",EVENTS_YIELD_MS / 1000,name));
	return true;
}

static Events_FinishContest(first,second,third)
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], name[MAX_PLAYER_NAME] = "nobody", playerid = Groups_PlayerByCharacter(first);

	if (playerid != INVALID_PLAYER_ID)
	{
		Character_GetName(playerid,name);
	}

	Events_Say(sprintf("The winner of %s: %s!",g_ContestDefs[contest][E_CONTEST_DEF_NAME],name));
	s_Run[E_RUN_PHASE] = RUN_IDLE;
	s_RunIdleSince = GetTickCount();
	Events_AwardContest(event,contest,first,second,third);

	if (Events_NextContest(event) == -1 && Events_GetKind(event) != EVENT_FAIR)
	{
		Events_End(event);
	}
}

stock Events_NextContest(event)
{
	for (new contest = 0;contest < CONTEST_COUNT;contest++)
	{
		if (Events_HasContest(event,contest) && !Events_IsContestDone(event,contest))
		{
			return contest;
		}
	}

	return -1;
}

static Events_FinishScored()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], best[3] = {-1, -1, -1};

	for (new index = 0;index < Events_GetEntryCount(event,contest);index++)
	{
		new characterid, score, bool:isOut, placed;
		Events_GetEntry(event,contest,index,characterid,score,isOut,placed);

		for (new slot = 0;slot < 3;slot++)
		{
			new other = best[slot];

			if (other == -1 || score > Events_EntryScore(event,contest,other))
			{
				for (new move = 2;move > slot;move--)
				{
					best[move] = best[move - 1];
				}

				best[slot] = index;
				break;
			}
		}
	}

	for (new slot = 0;slot < 3;slot++)
	{
		if (best[slot] != -1)
		{
			Events_SetPlaced(event,contest,best[slot],slot + 1);
		}
	}

	Events_FinishContest(best[0] != -1 ? Events_EntryCharacter(event,contest,best[0]) : 0,best[1] != -1 ? Events_EntryCharacter(event,contest,best[1]) : 0,best[2] != -1 ? Events_EntryCharacter(event,contest,best[2]) : 0);
}

stock Events_EntryScore(event,contest,index)
{
	new characterid, score, bool:isOut, placed;
	Events_GetEntry(event,contest,index,characterid,score,isOut,placed);
	return score;
}

stock Events_JudgeProduce(event)
{
	new contest = CONTEST_PRODUCE;
	s_Run[E_RUN_EVENT] = event;
	s_Run[E_RUN_CONTEST] = contest;

	for (new index = 0;index < Events_GetEntryCount(event,contest);index++)
	{
		new param, stars;
		Events_GetEntryItem(event,contest,index,param,stars);
		Events_SetScore(event,contest,index,param == -1 ? 0 : stars * 1000 + Item_GetPrice(g_ItemDefs[param][E_ITEM_DEF_KIND],param,stars));
	}

	Events_FinishScored();
}

stock Events_ScoreArrow(Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz)
{
	new best = 0, Float:wind = Calendar_GetWeatherOverride() != -1 ? 0.8 : 0.25;

	for (new butt = 0;butt < 3;butt++)
	{
		new Float:bx = g_EventsButts[butt][0], Float:by = g_EventsButts[butt][1], Float:bz = g_EventsButts[butt][2] + 1.0, Float:t = (bx - sx) * dx + (by - sy) * dy + (bz - sz) * dz;

		if (t <= 0.0)
		{
			continue;
		}

		new Float:off = VectorSize(sx + dx * t - bx,sy + dy * t - by,sz + dz * t - bz) + wind * float(random(100)) / 100.0, ring = off < 0.35 ? 10 : (off < 0.7 ? 7 : (off < 1.1 ? 4 : (off < 1.6 ? 1 : 0)));
		best = max(best,ring * (butt + 1));
	}

	return best;
}

static Events_DrinkRound()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], standing = 0, last = -1;
	s_Run[E_RUN_ROUND]++;

	for (new index = 0;index < Events_GetEntryCount(event,contest);index++)
	{
		new characterid, score, bool:isOut, placed, playerid = Events_PlayerOf(event,contest,index);
		Events_GetEntry(event,contest,index,characterid,score,isOut,placed);

		if (isOut)
		{
			continue;
		}

		if (playerid == INVALID_PLAYER_ID || !IsPlayerInRangeOfPoint(playerid,EVENTS_LISTS_RANGE,g_EventsLists[0],g_EventsLists[1],g_EventsLists[2] + 1.0))
		{
			Events_SetOut(event,contest,index,true);
			continue;
		}

		new chance = max(s_Run[E_RUN_ROUND] * 7 - Character_GetAttribute(playerid,_:ATTR_WILLPOWER) * 3,2);
		SetPlayerDrunkLevel(playerid,min(GetPlayerDrunkLevel(playerid) + 1800,49000));
		Chat_Annotate(playerid,"drains another tankard.");

		if (random(100) < chance)
		{
			Events_SetOut(event,contest,index,true);
			Events_SetScore(event,contest,index,s_Run[E_RUN_ROUND]);
			ApplyAnimation(playerid,"PED","KO_skid_front",4.1,false,false,false,true,0,SYNC_ALL);
			Chat_Annotate(playerid,"sways, and goes down under the table.");
			continue;
		}

		Events_SetScore(event,contest,index,s_Run[E_RUN_ROUND] + 1);
		standing++;
		last = index;
	}

	if (standing <= 1 || s_Run[E_RUN_ROUND] >= EVENTS_DRINK_ROUNDS)
	{
		if (last != -1)
		{
			Events_SetScore(event,contest,last,s_Run[E_RUN_ROUND] + 10);
		}

		Events_FinishScored();
		return;
	}

	s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_DRINK_MS;
}

static Events_StartPass()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST];

	if (Events_IsFightContest(contest))
	{
		Events_StartFight();
		return;
	}

	if (contest == CONTEST_JOUST)
	{
		s_Run[E_RUN_PHASE] = RUN_BOUT;
		s_Run[E_RUN_UNTIL] = GetTickCount() + 15000;
		Events_StartRiddenJoust(Events_PlayerOf(event,contest,s_Run[E_RUN_A]),s_Run[E_RUN_B] == -1 ? Events_GetSparringKnight() : Events_PlayerOf(event,contest,s_Run[E_RUN_B]),s_Run[E_RUN_PASS]);
		return;
	}

	s_Run[E_RUN_PHASE] = RUN_BOUT;
	s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_PASS_MS;

	for (new side = 0;side < 2;side++)
	{
		new playerid = Events_PlayerOf(event,contest,side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B]);

		if (playerid != INVALID_PLAYER_ID)
		{
			Events_StartBar(playerid);
		}
	}

	if (contest == CONTEST_JOUST)
	{
		Events_Say(sprintf("Pass %d: lower your lances!",s_Run[E_RUN_PASS] + 1));
	}
}

static Events_EndPass()
{
	new event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST], a = s_Run[E_RUN_A], b = s_Run[E_RUN_B], pa = Events_PlayerOf(event,contest,a), pb = Events_PlayerOf(event,contest,b), qa = pa != INVALID_PLAYER_ID ? Events_BarResult(pa) : 0, qb = pb != INVALID_PLAYER_ID ? Events_BarResult(pb) : 0;

	if (pa != INVALID_PLAYER_ID)
	{
		Events_StopBar(pa);
	}

	if (pb != INVALID_PLAYER_ID)
	{
		Events_StopBar(pb);
	}

	s_Run[E_RUN_POINTS][0] += qa;
	s_Run[E_RUN_POINTS][1] += qb;

	if (qa == 2 && qb == 0 && pb != INVALID_PLAYER_ID)
	{
		Mount_Throw(pb,"The lance takes you square and you're thrown from the saddle!");
		Events_EndBout(a,b,"and unhorses them");
		return;
	}

	if (qb == 2 && qa == 0 && pa != INVALID_PLAYER_ID)
	{
		Mount_Throw(pa,"The lance takes you square and you're thrown from the saddle!");
		Events_EndBout(b,a,"and unhorses them");
		return;
	}

	Events_Say(sprintf("%s! Points: %d to %d.",qa + qb == 0 ? ("Both miss") : (qa > qb ? ("A hit on the right") : (qb > qa ? ("A hit on the left") : ("Lances shatter on both shields"))),s_Run[E_RUN_POINTS][0],s_Run[E_RUN_POINTS][1]));
	s_Run[E_RUN_PASS]++;

	if (s_Run[E_RUN_PASS] >= EVENTS_PASSES && s_Run[E_RUN_POINTS][0] != s_Run[E_RUN_POINTS][1])
	{
		new bool:aWins = s_Run[E_RUN_POINTS][0] > s_Run[E_RUN_POINTS][1];
		Events_EndBout(aWins ? a : b,aWins ? b : a,"on points");
		return;
	}

	s_Run[E_RUN_PHASE] = RUN_GAP;
	s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_PASS_GAP_MS;
}

stock Events_StartDue(tick)
{
    if (Events_HasPlayerHerald())
    {
        return;
    }

	if (s_RunIdleSince == 0)
	{
		s_RunIdleSince = tick;
	}

	if (tick - s_RunIdleSince < 30000)
	{
		return;
	}

	new now = gettime();

	for (new event = 0;event < EVENTS_MAX;event++)
	{
		if (!Events_IsValid(event) || Events_GetState(event) == EVENT_DONE || Events_GetKind(event) == EVENT_FAIR || Events_GetStarts(event) > now)
		{
			continue;
		}

		new contest = Events_NextContest(event);

		if (contest == -1)
		{
			Events_End(event);
			continue;
		}

		s_RunIdleSince = 0;
		Events_BeginContest(event,contest);
		return;
	}
}

stock Events_StopContest()
{
	if (s_Run[E_RUN_PHASE] == RUN_IDLE)
	{
		return;
	}

    Events_EndSparring();
	foreach (new playerid : Player)
	{
		Events_StopBar(playerid);
		Events_ReleaseFighter(playerid);
		Combat_SetTourney(playerid,false);
	}

	s_Run[E_RUN_PHASE] = RUN_IDLE;
}

stock Events_ResolveCourse(pointsA,pointsB,unhorsedSide = -1)
{
    if (s_Run[E_RUN_PHASE] != RUN_BOUT || s_Run[E_RUN_CONTEST] != CONTEST_JOUST)
    {
        return false;
    }
    s_Run[E_RUN_POINTS][0] += pointsA;
    s_Run[E_RUN_POINTS][1] += pointsB;
    s_Run[E_RUN_PASS]++;
    Events_StopRiddenJoust(true);
    if (s_Run[E_RUN_B] == -1)
    {
        if (unhorsedSide >= 0 || s_Run[E_RUN_PASS] >= EVENTS_PASSES)
        {
            Events_Say(sprintf("The practice bout ends, %d points to %d. No prize is awarded.",s_Run[E_RUN_POINTS][0],s_Run[E_RUN_POINTS][1]));
            Events_FinishSparring();
        }
        else
        {
            s_Run[E_RUN_PHASE] = RUN_GAP;
            s_Run[E_RUN_UNTIL] = GetTickCount() + 6000;
        }
        return true;
    }
    new leader = Events_FightLeader(s_Run[E_RUN_POINTS][0],s_Run[E_RUN_POINTS][1]);
    if (unhorsedSide >= 0 || (s_Run[E_RUN_PASS] >= EVENTS_PASSES && leader != -1) || s_Run[E_RUN_PASS] >= EVENTS_PASSES + 2)
    {
        new winner = unhorsedSide == 2 ? random(2) : (unhorsedSide >= 0 ? 1 - unhorsedSide : (leader == -1 ? random(2) : leader));
        new nameW[MAX_PLAYER_NAME], nameL[MAX_PLAYER_NAME], line[144];
        Events_EntryName(s_Run[E_RUN_EVENT],CONTEST_JOUST,winner == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B],nameW);
        Events_EntryName(s_Run[E_RUN_EVENT],CONTEST_JOUST,winner == 0 ? s_Run[E_RUN_B] : s_Run[E_RUN_A],nameL);
        if (unhorsedSide == 2)
        {
            format(line,sizeof(line),"Both riders are unhorsed! A draw. A coin toss sends %s through.",nameW);
        }
        else if (unhorsedSide >= 0)
        {
            format(line,sizeof(line),"%s is unhorsed! %s wins the joust.",nameL,nameW);
        }
        else if (leader == -1)
        {
            format(line,sizeof(line),"Five courses run, level at %d points. A draw! A coin toss sends %s through.",s_Run[E_RUN_POINTS][0],nameW);
        }
        else
        {
            format(line,sizeof(line),"%s wins the joust against %s, %d points to %d.",nameW,nameL,s_Run[E_RUN_POINTS][winner],s_Run[E_RUN_POINTS][1 - winner]);
        }
        Events_EndBoutWith(winner == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B],winner == 0 ? s_Run[E_RUN_B] : s_Run[E_RUN_A],line,unhorsedSide == 2 || (unhorsedSide < 0 && leader == -1) ? BOUT_DRAW : (unhorsedSide >= 0 ? BOUT_KNOCKDOWN : BOUT_POINTS));
        return true;
    }
    if (s_Run[E_RUN_PASS] >= EVENTS_PASSES)
    {
        Events_Say(sprintf("%d courses run, %d points each. Another course!",s_Run[E_RUN_PASS],s_Run[E_RUN_POINTS][0]));
    }
    s_Run[E_RUN_PHASE] = RUN_GAP;
    s_Run[E_RUN_UNTIL] = GetTickCount() + 6000;
    return true;
}

stock Events_ForfeitJoust(playerid)
{
    if (s_Run[E_RUN_CONTEST] != CONTEST_JOUST || (s_Run[E_RUN_PHASE] != RUN_BOUT && s_Run[E_RUN_PHASE] != RUN_GAP) || s_Run[E_RUN_PASS] == -1)
    {
        return false;
    }
    new side = Events_PlayerOf(s_Run[E_RUN_EVENT],CONTEST_JOUST,s_Run[E_RUN_A]) == playerid ? 0 : (Events_PlayerOf(s_Run[E_RUN_EVENT],CONTEST_JOUST,s_Run[E_RUN_B]) == playerid ? 1 : -1);
    if (side == -1)
    {
        return false;
    }
    if (s_Run[E_RUN_B] == -1)
    {
        Events_Say("The practice bout ends. No prize is awarded.");
        Events_FinishSparring();
        return true;
    }
    Events_EndBout(side == 0 ? s_Run[E_RUN_B] : s_Run[E_RUN_A],side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B],"when the other forfeits");
    return true;
}

stock bool:Events_HeraldAdvance(event = -1)
{
    if (s_Run[E_RUN_PHASE] == RUN_GAP && s_Run[E_RUN_PASS] == -1)
    {
        Events_CallBout();
        return true;
    }
    if (s_Run[E_RUN_PHASE] != RUN_IDLE)
    {
        return false;
    }
    if (event == -1)
    {
        event = Events_FindKind(EVENT_TOURNAMENT);
    }
    new contest = event == -1 ? -1 : Events_NextContest(event);
    return contest != -1 && Events_GetStarts(event) <= gettime() && Events_BeginContest(event,contest);
}

stock bool:Events_HeraldYield()
{
    if (s_Run[E_RUN_PHASE] != RUN_BOUT || !Events_IsFightContest(s_Run[E_RUN_CONTEST]))
    {
        return false;
    }
    for (new side = 0;side < 2;side++)
    {
        new playerid = Events_PlayerOf(s_Run[E_RUN_EVENT],s_Run[E_RUN_CONTEST],side == 0 ? s_Run[E_RUN_A] : s_Run[E_RUN_B]);
        if (playerid != INVALID_PLAYER_ID && s_Fighter[playerid][E_FIGHTER_YIELD_AT] != 0 && GetTickCount() - s_Fighter[playerid][E_FIGHTER_YIELD_AT] <= EVENTS_YIELD_MS)
        {
            Events_EndFight(1 - side,BOUT_YIELD);
            return true;
        }
    }
    return false;
}

stock Events_FinishSparring()
{
    new event = s_Run[E_RUN_EVENT];
    Events_EndSparring();
    s_Run[E_RUN_PHASE] = RUN_IDLE;
    s_RunIdleSince = GetTickCount();
    Events_AwardContest(event,CONTEST_JOUST,0,0,0);
    if (Events_NextContest(event) == -1)
    {
        Events_End(event);
    }
}

stock bool:Events_AcceptSparring(playerid)
{
    if (s_Run[E_RUN_PHASE] != RUN_CALLING || s_Run[E_RUN_CONTEST] != CONTEST_JOUST || s_Run[E_RUN_B] != -1 || Events_PlayerOf(s_Run[E_RUN_EVENT],CONTEST_JOUST,0) != playerid || GetTickCount() >= s_Run[E_RUN_UNTIL])
    {
        return false;
    }
    s_Run[E_RUN_UNTIL] = GetTickCount() + EVENTS_CALL_MS;
    return Events_PrepareSparring(playerid);
}

stock Events_DeclineSparring(playerid)
{
    if (s_Run[E_RUN_PHASE] == RUN_CALLING && s_Run[E_RUN_CONTEST] == CONTEST_JOUST && s_Run[E_RUN_B] == -1 && Events_PlayerOf(s_Run[E_RUN_EVENT],CONTEST_JOUST,0) == playerid)
    {
        Events_FinishSparring();
    }
}

stock Events_BeginSparringCourse()
{
    Events_StartPass();
}

stock Events_Step()
{
	new tick = GetTickCount(), event = s_Run[E_RUN_EVENT], contest = s_Run[E_RUN_CONTEST];

	foreach (new playerid : Player)
	{
		if (s_Bar[playerid][E_BAR_ACTIVE])
		{
			PBar_SetValue(playerid,s_Bar[playerid][E_BAR_ID],Events_BarValue(s_Bar[playerid][E_BAR_STARTED]),Events_BarValue(s_Bar[playerid][E_BAR_STARTED]) >= EVENTS_BAR_GOOD ? 0x7FC97CFF : 0xC9B27CFF);
		}
	}

	if (s_Run[E_RUN_PHASE] == RUN_IDLE || !Events_IsValid(event))
	{
		if (s_Run[E_RUN_PHASE] != RUN_IDLE)
		{
            Events_EndSparring();
			s_Run[E_RUN_PHASE] = RUN_IDLE;
		}

		Events_ShowRingScore(tick);
		Events_StartDue(tick);
		return;
	}

	Events_ShowRingScore(tick);

	switch (s_Run[E_RUN_PHASE])
	{
		case RUN_CALLING:
		{
            if (contest == CONTEST_JOUST && s_Run[E_RUN_B] == -1)
            {
                Events_WatchSparringOffer(tick >= s_Run[E_RUN_UNTIL]);
                return;
            }
			new pa = Events_PlayerOf(event,contest,s_Run[E_RUN_A]), pb = Events_PlayerOf(event,contest,s_Run[E_RUN_B]), bool:aHere = contest == CONTEST_JOUST ? Events_IsAtJoustGate(pa,0,s_Run[E_RUN_PASS]) : Events_IsAtLists(pa,contest), bool:bHere = contest == CONTEST_JOUST ? Events_IsAtJoustGate(pb,1,s_Run[E_RUN_PASS]) : Events_IsAtLists(pb,contest);

			if (aHere && bHere)
			{
				Events_StartPass();
			}
			else if (tick >= s_Run[E_RUN_UNTIL])
			{
				if (!aHere && !bHere)
				{
					Events_SetOut(event,contest,s_Run[E_RUN_B],true);
					Events_EndBout(s_Run[E_RUN_A],s_Run[E_RUN_B],"as neither came: the first named goes through");
				}
				else
				{
					Events_EndBout(aHere ? s_Run[E_RUN_A] : s_Run[E_RUN_B],aHere ? s_Run[E_RUN_B] : s_Run[E_RUN_A],"when the other doesn't come");
				}
			}
		}
		case RUN_BOUT:
		{
			if (contest == CONTEST_JOUST)
			{
				Events_WatchRiddenJoust(tick >= s_Run[E_RUN_UNTIL]);
				return;
			}

			if (Events_IsFightContest(contest))
			{
				if (!Events_WatchFight(tick) && tick >= s_Run[E_RUN_UNTIL])
				{
					Events_CallFightTime();
				}

				return;
			}

			if (tick >= s_Run[E_RUN_UNTIL])
			{
				Events_EndPass();
			}
		}
		case RUN_GAP:
		{
			if (tick < s_Run[E_RUN_UNTIL])
			{
				return;
			}

			if (s_Run[E_RUN_PASS] == -1)
			{
                if (Events_HasPlayerHerald())
                {
                    return;
                }
				Events_CallBout();
			}
			else
			{
                if (contest == CONTEST_JOUST)
                {
                    s_Run[E_RUN_PHASE] = RUN_CALLING;
                    s_Run[E_RUN_UNTIL] = tick + EVENTS_CALL_MS;
                    Events_Say("Riders, turn at the far gates and take the other lane. You have 60 seconds for the next course.");
                }
                else
                {
				    Events_StartPass();
                }
			}
		}
		case RUN_SINGLE:
		{
			new playerid = Events_PlayerOf(event,contest,s_Run[E_RUN_A]);

			if (contest == CONTEST_LOG_TOSS && playerid != INVALID_PLAYER_ID && s_Bar[playerid][E_BAR_ACTIVE] && s_Bar[playerid][E_BAR_RESULT] != -1)
			{
				new quality = s_Bar[playerid][E_BAR_RESULT], Float:value = Events_BarValue(s_Bar[playerid][E_BAR_STARTED]), metres = 30 + quality * 25 + floatround(value / 10.0) + Character_GetAttribute(playerid,_:ATTR_WILLPOWER) * 4;
				Events_StopBar(playerid);
				Events_SetScore(event,contest,s_Run[E_RUN_A],metres);
				ApplyAnimation(playerid,"GRENADE","WEAPON_throw",4.1,false,false,false,false,0,SYNC_ALL);
				Events_Say(sprintf("The log tumbles %d.%d m.",metres / 10,metres % 10));
				s_Run[E_RUN_TURN]++;
				Events_CallSingle();
				return;
			}

			if (tick >= s_Run[E_RUN_UNTIL] || playerid == INVALID_PLAYER_ID || (contest == CONTEST_ARCHERY && s_Run[E_RUN_SHOTS] >= EVENTS_ARROWS))
			{
				if (playerid != INVALID_PLAYER_ID)
				{
					Events_StopBar(playerid);
				}

				s_Run[E_RUN_TURN]++;
				Events_CallSingle();
			}
		}
		case RUN_DRINKING:
		{
			if (tick >= s_Run[E_RUN_UNTIL])
			{
				Events_DrinkRound();
			}
		}
	}
}

Timer_Declare(Events_Tick)
{
	Events_Step();
	return 1;
}

forward Events_OnBoutEnded(event,contest,winnerCharacter,loserCharacter,result);
public Events_OnBoutEnded(event,contest,winnerCharacter,loserCharacter,result)
{
    return 1;
}

forward Events_FighterStandsDown(playerid,token);

public Events_FighterStandsDown(playerid,token)
{
	if (IsPlayerConnected(playerid) && s_Fighter[playerid][E_FIGHTER_TOKEN] == token)
	{
		Events_ReleaseFighter(playerid);
	}

	return 1;
}

forward bool:Events_BarContext(playerid);

public bool:Events_BarContext(playerid)
{
	return Events_IsBarActive(playerid);
}

forward bool:Events_YieldContext(playerid);

public bool:Events_YieldContext(playerid)
{
	return Events_FighterSide(playerid) != -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Bar[playerid][E_BAR_ACTIVE] = false;
	s_Bar[playerid][E_BAR_ID] = INVALID_PLAYER_BAR;
	s_Fighter[playerid][E_FIGHTER_IN] = false;
	s_Fighter[playerid][E_FIGHTER_TOKEN]++;
	s_Fighter[playerid][E_FIGHTER_YIELD_AT] = 0;
	s_RingWarned[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_Fighter[playerid][E_FIGHTER_IN])
	{
		s_Fighter[playerid][E_FIGHTER_IN] = false;
		s_Fighter[playerid][E_FIGHTER_TOKEN]++;
		Combat_SetTourney(playerid,false);
	}
}

hook Combat_OnSwing(playerid,anim)
{
	s_Fighter[playerid][E_FIGHTER_SWING] = anim;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_Bar[playerid][E_BAR_ACTIVE])
	{
		Events_BarPress(playerid);
	}

	if ((newkeys & KEY_NO) && !(oldkeys & KEY_NO) && !(newkeys & KEY_WALK))
	{
		Events_YieldPress(playerid);
	}
}

hook Combat_OnTourneyHit(attackerid,targetid,weapon)
{
	new side = Events_FighterSide(attackerid);

	if (side == -1 || Events_FighterSide(targetid) != 1 - side || Combat_IsKnockedDown(targetid))
	{
		return;
	}

	if (s_Run[E_RUN_CONTEST] == CONTEST_WRESTLING && Weapon_IsValid(weapon))
	{
		Events_EndFight(1 - side,BOUT_ARMED);
		return;
	}

	if (Combat_IsBlocking(targetid) && Combat_IsFacing(targetid,attackerid,Combat_GetShield(targetid) != INVALID_SHIELD_INDEX ? EVENTS_BLOCK_CONE_SHIELD : EVENTS_BLOCK_CONE_BARE))
	{
		new sound = Combat_IsShieldUp(targetid) ? 1135 : 17807;
		PlayerPlaySound(targetid,sound,0.0,0.0,0.0);
		PlayerPlaySound(attackerid,sound,0.0,0.0,0.0);
		return;
	}

    Events_CheerSpectators();

	s_Run[E_RUN_POINTS][side] += Events_BlowPoints(s_Fighter[attackerid][E_FIGHTER_SWING],Weapon_IsValid(weapon),Combat_IsBehind(attackerid,targetid));
	Events_ShowFightPoints();

	if (s_Run[E_RUN_POINTS][side] >= EVENTS_FIGHT_POINTS)
	{
		Combat_KnockDown(targetid,attackerid);
		Events_EndFight(side,BOUT_KNOCKDOWN);
	}
}

hook Projectile_OnShot(shooterid,kind,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz)
{
	#pragma unused kind

	if (s_Run[E_RUN_PHASE] != RUN_SINGLE || s_Run[E_RUN_CONTEST] != CONTEST_ARCHERY || Events_PlayerOf(s_Run[E_RUN_EVENT],CONTEST_ARCHERY,s_Run[E_RUN_A]) != shooterid || s_Run[E_RUN_SHOTS] >= EVENTS_ARROWS)
	{
		return;
	}

	if (!IsPlayerInRangeOfPoint(shooterid,EVENTS_LINE_RANGE,g_EventsLine[0],g_EventsLine[1],g_EventsLine[2] + 1.0))
	{
		Gui_Notify(shooterid,"Shoot from the line, or it doesn't count.");
		return;
	}

	new points = Events_ScoreArrow(sx,sy,sz,dx,dy,dz), total = Events_EntryScore(s_Run[E_RUN_EVENT],CONTEST_ARCHERY,s_Run[E_RUN_A]) + points;
	s_Run[E_RUN_SHOTS]++;
	Events_SetScore(s_Run[E_RUN_EVENT],CONTEST_ARCHERY,s_Run[E_RUN_A],total);
	Events_Say(sprintf("%s! %d points, %d in all.",points == 0 ? ("A miss") : (points >= 20 ? ("A fine shot") : ("A hit")),points,total));
}
