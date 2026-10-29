enum E_FAMILY_TABLE
{
	bool:E_FAMILY_TABLE_ON,
    bool:E_FAMILY_TABLE_WAITING,
	E_FAMILY_MEAL:E_FAMILY_TABLE_KIND,
	E_FAMILY_TABLE_START,
	E_FAMILY_TABLE_PLATE,
	E_FAMILY_TABLE_CENTRES[2],
	bool:E_FAMILY_TABLE_GRACE_DONE,
	E_FAMILY_TABLE_GRACE_AT,
	E_FAMILY_TABLE_TALK_AT,
	E_FAMILY_TABLE_TALK_NEXT,
	bool:E_FAMILY_TABLE_RENDERED,
	STREAMER_TAG_OBJECT:E_FAMILY_TABLE_CENTRE_OBJECTS[2],
	E_FAMILY_TABLE_CENTRE_STAGE,
	E_FAMILY_TABLE_INVITES[FAMILY_INVITES_MAX],
	E_FAMILY_TABLE_CONVO,
	E_FAMILY_TABLE_CONVO_LINE,
	bool:E_FAMILY_TABLE_TOPIC_TURN,
}

enum E_FAMILY_GUEST
{
	E_FAMILY_GUEST_FAMILY,
	E_FAMILY_GUEST_SEAT,
    bool:E_FAMILY_GUEST_SETTLED,
	bool:E_FAMILY_GUEST_INVITED,
	E_FAMILY_GUEST_PICKS,
	E_FAMILY_GUEST_STATE:E_FAMILY_GUEST_PHASE,
	E_FAMILY_GUEST_SPEAKER,
	E_FAMILY_GUEST_QUESTIONS,
	Float:E_FAMILY_GUEST_CAMERA[6],
    Float:E_FAMILY_GUEST_STANDING[4],
	STREAMER_TAG_OBJECT:E_FAMILY_GUEST_PLATE,
	Float:E_FAMILY_GUEST_PLATE_POS[4],
	E_FAMILY_GUEST_CONVO,
	E_FAMILY_GUEST_LINE,
}

static s_FamilyTables[FAMILY_SEED_HOUSEHOLDS][E_FAMILY_TABLE];
static bool:s_FamilyEating[FAMILY_SEED_MEMBERS];
static STREAMER_TAG_OBJECT:s_FamilyPlates[FAMILY_SEED_MEMBERS] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static s_FamilyPlateStage[FAMILY_SEED_MEMBERS];
static s_FamilyGuests[MAX_PLAYERS][E_FAMILY_GUEST];
static s_FamilyWellFedUntil[MAX_PLAYERS];
static s_FamilyWellFedNext[MAX_PLAYERS];
static s_FamilySeatPrompt[MAX_PLAYERS] = {-1, ...};
static bool:s_FamilySeatAllowed[MAX_PLAYERS];
static s_FamilySeatAskedAt[MAX_PLAYERS];
static s_FamilyMealStamp[FAMILY_SEED_HOUSEHOLDS];
static s_FamilySeatInfobox[MAX_PLAYERS];
static s_FamilySeatGenerations[MAX_PLAYERS];
static s_FamilyFoulOverride = -1;
static bool:s_FamilyConvoUsed[sizeof(g_FamilyConvoDefs)];

forward E_FAMILY_MEAL:Families_NextMeal(&bool:soon);

stock bool:Families_IsTableOpen(family)
{
    return family >= 0 && family < FAMILY_SEED_HOUSEHOLDS && s_FamilyTables[family][E_FAMILY_TABLE_ON];
}

stock bool:Families_IsMealOn(family)
{
    return Families_IsTableOpen(family) && !s_FamilyTables[family][E_FAMILY_TABLE_WAITING];
}

stock bool:Families_IsEating(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS && s_FamilyEating[member];
}

stock E_FAMILY_MEAL:Families_GetMealKind(family)
{
	return s_FamilyTables[family][E_FAMILY_TABLE_KIND];
}

stock bool:Families_IsGraceSaid(family)
{
	return s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE];
}

stock Families_GetMenu(family,dishes[3])
{
	dishes[0] = s_FamilyTables[family][E_FAMILY_TABLE_PLATE];
	dishes[1] = s_FamilyTables[family][E_FAMILY_TABLE_CENTRES][0];
	dishes[2] = s_FamilyTables[family][E_FAMILY_TABLE_CENTRES][1];
}

stock Families_SetFoulOverride(value)
{
	s_FamilyFoulOverride = value;
}

stock Families_GetFoulOverride()
{
	return s_FamilyFoulOverride;
}

stock Families_GameMinute()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return ((((year - CALENDAR_EPOCH_YEAR) * CALENDAR_MONTHS + (month - 1)) * CALENDAR_DAYS_PER_MONTH + (day - 1)) * 1440) + Calendar_GetMinuteOfDay();
}

stock Families_MealId(E_FAMILY_MEAL:meal)
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Calendar_DaysSinceEpoch(day,month,year) * 2 + (meal == FAMILY_MEAL_SUPPER ? 1 : 0) + 1;
}

stock Families_CurrentMealId(family)
{
	if (Families_IsTableOpen(family))
	{
		return Families_MealId(s_FamilyTables[family][E_FAMILY_TABLE_KIND]);
	}

	new bool:soon, E_FAMILY_MEAL:meal = Families_NextMeal(soon);
	return soon ? Families_MealId(meal) : 0;
}

stock Families_MealElapsed(family)
{
	return Families_IsMealOn(family) ? Families_GameMinute() - s_FamilyTables[family][E_FAMILY_TABLE_START] : 0;
}

stock Families_SetMealStart(family,start)
{
	s_FamilyTables[family][E_FAMILY_TABLE_START] = start;
}

stock Families_DishModel(group,stage)
{
	stage = clamp(stage,0,2);

	if (group < FAMILY_PLATE_GROUPS)
	{
		return -7601 - group * 3 - stage;
	}

	new centre = group - FAMILY_PLATE_GROUPS;

	if (centre < 12)
	{
		return -7643 - centre * 3 - stage;
	}

	return (centre == 12 ? -7679 : -7681) - (stage > 0 ? 1 : 0);
}

static Families_FastPlate(group)
{
	switch (group)
	{
		case FAMILY_DISH_TRENCHER_MEAT, FAMILY_DISH_PEWTER_ROAST: return FAMILY_DISH_TRENCHER_FISH;
		case FAMILY_DISH_STEW_BOWL, FAMILY_DISH_PLATE_FOWL: return FAMILY_DISH_FISH_STEW;
		case FAMILY_DISH_PLATE_SAUSAGE: return FAMILY_DISH_POTTAGE_BOWL;
		case FAMILY_DISH_PLATE_PIE: return FAMILY_DISH_POTTAGE_BREAD;
	}

	return group;
}

static Families_FastCentre(group)
{
	switch (group)
	{
		case FAMILY_DISH_ROAST_JOINT, FAMILY_DISH_ROAST_FOWL, FAMILY_DISH_MEAT_PIE: return FAMILY_DISH_FISH_PLATTER;
		case FAMILY_DISH_SAUSAGE_BOARD: return FAMILY_DISH_RYE_LOAF;
	}

	return group;
}

stock Families_ResolveMenu(family,E_FAMILY_MEAL:meal,dishes[3])
{
	#pragma unused meal

	new wealth = g_FamilyDefs[family][E_FAMILY_DEF_WEALTH], day, month, year;
	Calendar_GetDate(day,month,year);
	dishes[0] = g_FamilyDefs[family][E_FAMILY_DEF_PLATE];
	dishes[1] = g_FamilyDefs[family][E_FAMILY_DEF_CENTRES][0];
	dishes[2] = g_FamilyDefs[family][E_FAMILY_DEF_CENTRES][1];

	if (Families_GetStores(family) < FAMILY_STORES_MEAGRE)
	{
		dishes[0] = FAMILY_DISH_POTTAGE_BOWL;
		dishes[1] = FAMILY_DISH_RYE_LOAF;
		dishes[2] = -1;
		return;
	}

	if (Families_IsFastDay())
	{
		dishes[0] = Families_FastPlate(dishes[0]);
		dishes[1] = Families_FastCentre(dishes[1]);
		dishes[2] = Families_FastCentre(dishes[2]);
		return;
	}

	if (Families_IsFeastDay())
	{
		dishes[1] = wealth >= 2 ? FAMILY_DISH_ROAST_FOWL : FAMILY_DISH_WHEAT_LOAF;
		dishes[2] = FAMILY_DISH_HONEY_CAKES;
		return;
	}

	if (month >= 8 && month <= 10 && dishes[2] != FAMILY_DISH_GROUPS - 1)
	{
		dishes[2] = wealth >= 2 ? FAMILY_DISH_FRUIT_TART : FAMILY_DISH_NUTS_APPLES;
	}
	else if (month >= 3 && month <= 5 && wealth <= 1 && day % 2 == 1)
	{
		dishes[0] = FAMILY_DISH_PLATE_EGG;
	}
}

static bool:Families_LocalPos(const Float:pos[],&Float:x,&Float:y,&Float:z)
{
	if (pos[0] == 0.0 && pos[1] == 0.0 && pos[2] == 0.0)
	{
		return false;
	}

	Houses_LocalToWorld(pos[0],pos[1],pos[2],x,y,z);
	return true;
}

stock Families_SeatPlatePos(family,seat,&Float:x,&Float:y,&Float:z,&Float:a)
{
	new Float:sx, Float:sy, Float:sz, Float:cx, Float:cy, Float:cz;
	Families_SeatPos(seat,sx,sy,sz,a);

	if (!Families_LocalPos(g_FamilyDefs[family][E_FAMILY_DEF_CENTRE],cx,cy,cz))
	{
		cz = sz + FAMILY_SEAT_TABLE_TOP;
	}

	new Float:reach = strcmp(g_HouseSeatDefs[seat][E_HOUSE_POSE_DEF_STYLE],"bench") == 0 ? FAMILY_PLATE_REACH : FAMILY_PLATE_REACH_SEATED;
	x = sx - floatsin(a,degrees) * reach;
	y = sy + floatcos(a,degrees) * reach;
	z = cz;
}

static Families_MemberPlatePos(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (Families_LocalPos(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SETTING],x,y,z))
	{
		a = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SETTING][3];
		return;
	}

	Families_SeatPlatePos(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY],g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT],x,y,z,a);
}

stock Families_PlateStageAt(family,member,elapsed)
{
	new seat = member - g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], jitter = (family * 7 + seat * 13) % (FAMILY_MEAL_JITTER * 2 + 1) - FAMILY_MEAL_JITTER;
	return clamp((elapsed + jitter) / FAMILY_STAGE_MINUTES,0,2);
}

static STREAMER_TAG_OBJECT:Families_DishObject(group,stage,Float:x,Float:y,Float:z,Float:a,world)
{
	return CreateDynamicObject(Families_DishModel(group,stage),x,y,z,0.0,0.0,a,world,HOUSE_INTERIOR,-1,HOUSE_STREAM_RANGE);
}

static Families_DropObject(&STREAMER_TAG_OBJECT:object)
{
	if (object != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		DestroyDynamicObject(object);
		object = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

static Families_CentrePos(family,slot,&Float:x,&Float:y,&Float:z)
{
	Families_LocalPos(g_FamilyDefs[family][E_FAMILY_DEF_CENTRE],x,y,z);
	x += slot == 0 ? -FAMILY_CENTRE_SPREAD / 2.0 : FAMILY_CENTRE_SPREAD / 2.0;
}

static Families_ClearTable(family)
{
	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		Families_DropObject(s_FamilyPlates[member]);
	}

	Families_DropObject(s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][0]);
	Families_DropObject(s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][1]);

	foreach (new playerid : Player)
	{
		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] == family)
		{
			Families_DropObject(s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE]);
		}
	}

	s_FamilyTables[family][E_FAMILY_TABLE_RENDERED] = false;
}

static Families_RenderTable(family)
{
	new world = Houses_GetWorld(Families_GetHouse(family)), elapsed = Families_MealElapsed(family), Float:x, Float:y, Float:z, Float:a;

	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (!s_FamilyEating[member])
		{
			Families_DropObject(s_FamilyPlates[member]);
			continue;
		}

		new stage = Families_PlateStageAt(family,member,elapsed);

		if (s_FamilyPlates[member] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID && stage == s_FamilyPlateStage[member])
		{
			continue;
		}

		Families_DropObject(s_FamilyPlates[member]);
		Families_MemberPlatePos(member,x,y,z,a);
		s_FamilyPlates[member] = Families_DishObject(s_FamilyTables[family][E_FAMILY_TABLE_PLATE],stage,x,y,z,a,world);
		s_FamilyPlateStage[member] = stage;
	}

	new centreStage = clamp(elapsed / 60,0,2);

	for (new slot = 0;slot < 2;slot++)
	{
		new group = s_FamilyTables[family][E_FAMILY_TABLE_CENTRES][slot];

		if (group == -1)
		{
			continue;
		}

		if (s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][slot] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID && centreStage == s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_STAGE])
		{
			continue;
		}

		Families_DropObject(s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][slot]);
		Families_CentrePos(family,slot,x,y,z);
		s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][slot] = Families_DishObject(group,centreStage,x,y,z,0.0,world);
	}

	s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_STAGE] = centreStage;
	s_FamilyTables[family][E_FAMILY_TABLE_RENDERED] = true;
}

stock bool:Families_StartMeal(family,E_FAMILY_MEAL:meal,bool:waiting = false)
{
	if (family < 0 || family >= FAMILY_SEED_HOUSEHOLDS)
	{
		return false;
	}

	if (s_FamilyTables[family][E_FAMILY_TABLE_ON])
	{
		Families_EndMeal(family);
	}

	new dishes[3], eaters = 0;
	Families_ResolveMenu(family,meal,dishes);
	s_FamilyTables[family][E_FAMILY_TABLE_KIND] = meal;
    s_FamilyTables[family][E_FAMILY_TABLE_WAITING] = waiting;
	s_FamilyTables[family][E_FAMILY_TABLE_START] = Families_GameMinute() + (waiting ? FAMILY_MEAL_WINDOW : 0);
	s_FamilyTables[family][E_FAMILY_TABLE_PLATE] = dishes[0];
	s_FamilyTables[family][E_FAMILY_TABLE_CENTRES][0] = dishes[1];
	s_FamilyTables[family][E_FAMILY_TABLE_CENTRES][1] = dishes[2];
	s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE] = false;
	s_FamilyTables[family][E_FAMILY_TABLE_GRACE_AT] = 0;
	s_FamilyTables[family][E_FAMILY_TABLE_TALK_AT] = 0;
	s_FamilyTables[family][E_FAMILY_TABLE_TALK_NEXT] = random(g_FamilyDefs[family][E_FAMILY_DEF_TOPICS] > 0 ? g_FamilyDefs[family][E_FAMILY_DEF_TOPICS] : 1);
	s_FamilyTables[family][E_FAMILY_TABLE_RENDERED] = false;
	s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][0] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_FamilyTables[family][E_FAMILY_TABLE_CENTRE_OBJECTS][1] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_FamilyTables[family][E_FAMILY_TABLE_CONVO] = -1;
	s_FamilyTables[family][E_FAMILY_TABLE_CONVO_LINE] = 0;
	s_FamilyTables[family][E_FAMILY_TABLE_TOPIC_TURN] = false;

	for (new convo = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_CONVO], last = convo + g_FamilyDefs[family][E_FAMILY_DEF_CONVOS];convo < last;convo++)
	{
		s_FamilyConvoUsed[convo] = false;
	}

	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		s_FamilyEating[member] = Families_EatsAtTable(member,meal);

		if (s_FamilyEating[member])
		{
			eaters++;
		}
	}

	s_FamilyTables[family][E_FAMILY_TABLE_ON] = eaters > 0;
	Days_Invalidate();

	if (eaters > 0)
	{
        if (!waiting)
        {
            pawn_call_public("Household_OnMealStart","dd",family,_:meal);
        }
		Families_RefreshFamily(family);
	}

	return eaters > 0;
}

stock Families_CountEaters(family)
{
	new count = 0;

	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (s_FamilyEating[member])
		{
			count++;
		}
	}

	return count;
}

stock Families_EndMeal(family)
{
	if (!Families_IsTableOpen(family))
	{
		return;
	}

	new head = Families_FirstEater(family);

	foreach (new playerid : Player)
	{
		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] != family)
		{
			continue;
		}

		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] > 0)
		{
			Families_SetWellFed(playerid);
		}

		Families_StandUp(playerid);
	}

	if (head != -1 && Families_GetViewers(family) > 0)
	{
		Actors_Say(Families_GetMemberActor(head),"That's the meal. Back to work, all of you.");
	}

	Families_ClearTable(family);
	s_FamilyTables[family][E_FAMILY_TABLE_ON] = false;

	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		s_FamilyEating[member] = false;
	}

	for (new i = 0;i < FAMILY_INVITES_MAX;i++)
	{
		s_FamilyTables[family][E_FAMILY_TABLE_INVITES][i] = 0;
	}

	pawn_call_public("Household_OnMealEnd","d",family);
	Days_Invalidate();
	Families_RefreshFamily(family);
}

stock Families_FirstEater(family)
{
	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (s_FamilyEating[member])
		{
			return member;
		}
	}

	return -1;
}

stock bool:Families_Invite(family,characterid)
{
	if (Families_IsInvited(family,characterid))
	{
		return true;
	}

	for (new i = 0;i < FAMILY_INVITES_MAX;i++)
	{
		if (s_FamilyTables[family][E_FAMILY_TABLE_INVITES][i] == 0)
		{
			s_FamilyTables[family][E_FAMILY_TABLE_INVITES][i] = characterid;
			return true;
		}
	}

	return false;
}

stock bool:Families_IsInvited(family,characterid)
{
	for (new i = 0;i < FAMILY_INVITES_MAX;i++)
	{
		if (characterid > 0 && s_FamilyTables[family][E_FAMILY_TABLE_INVITES][i] == characterid)
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_CanInvite(family,characterid)
{
	if (Families_IsInvited(family,characterid))
	{
		return true;
	}

	for (new i = 0;i < FAMILY_INVITES_MAX;i++)
	{
		if (s_FamilyTables[family][E_FAMILY_TABLE_INVITES][i] == 0)
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_MaySit(playerid,family)
{
	return !Hygiene_IsReeking(playerid) && Families_IsInvited(family,Character_GetId(playerid)) || Houses_HoldsRoomIn(playerid,Families_GetHouse(family));
}

stock Families_FindFreeSeat(playerid,family,Float:reach = FAMILY_SEAT_REACH)
{
	new house = Families_GetHouse(family), first = g_HouseDefs[house][E_HOUSE_DEF_FIRST][2], count = g_HouseDefs[house][E_HOUSE_DEF_COUNT][2];
	new best = -1, Float:bestDistance = reach, Float:x, Float:y, Float:z, Float:a;

	for (new seat = first;seat < first + count;seat++)
	{
		if (Families_IsSeatTaken(family,seat))
		{
			continue;
		}

		Families_SeatPos(seat,x,y,z,a);

		if (playerid == INVALID_PLAYER_ID)
		{
			return seat;
		}

		new Float:distance = GetPlayerDistanceFromPoint(playerid,x,y,z);

		if (distance < bestDistance)
		{
			best = seat;
			bestDistance = distance;
		}
	}

	return best;
}

stock bool:Families_HasGuestSeat(family)
{
	new house = Families_GetHouse(family), first = g_HouseDefs[house][E_HOUSE_DEF_FIRST][2], count = g_HouseDefs[house][E_HOUSE_DEF_COUNT][2];

	for (new seat = first;seat < first + count;seat++)
	{
		new bool:own = false;

		for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
		{
			if (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] == seat)
			{
				own = true;
				break;
			}
		}

		if (!own)
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_IsSeatTaken(family,seat)
{
	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] == seat && (s_FamilyEating[member] || !Actors_IsDead(Families_GetMemberActor(member))))
		{
			return true;
		}
	}

	foreach (new playerid : Player)
	{
		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] == family && s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT] == seat)
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_IsGuest(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] != -1;
}

stock Families_GetGuestFamily(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] : -1;
}

stock bool:Families_IsGuestSettled(playerid)
{
	return Families_IsGuest(playerid) && s_FamilyGuests[playerid][E_FAMILY_GUEST_SETTLED];
}

stock Families_GetGuestPicks(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] : 0;
}

stock bool:Families_SeatGuest(playerid,family,seat)
{
	if (!Families_IsTableOpen(family) || Families_IsGuest(playerid) || seat == -1 || Families_IsSeatTaken(family,seat))
	{
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	GetPlayerPos(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][0],s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][1],s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][2]);
    GetPlayerFacingAngle(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][3]);
    Families_SeatPos(seat,x,y,z,a);
	SetPlayerPos(playerid,x,y,z + FAMILY_SEAT_PED_Z);
	SetPlayerFacingAngle(playerid,a);
    s_FamilyGuests[playerid][E_FAMILY_GUEST_SETTLED] = false;
    SetTimerEx("Families_SitGuestDeferred",FAMILY_SEAT_SETTLE_MS,false,"dd",playerid,++s_FamilySeatGenerations[playerid]);
	GetPlayerCameraPos(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][0],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][1],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][2]);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][3] = x;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][4] = y;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][5] = z;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] = family;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT] = seat;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_INVITED] = !Houses_HoldsRoomIn(playerid,Families_GetHouse(family));
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] = 0;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] = Families_IsGraceSaid(family) ? FAMILY_GUEST_READY : FAMILY_GUEST_WAITING;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER] = -1;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS] = 0;
	Families_SeatPlatePos(family,seat,x,y,z,a);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][0] = x;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][1] = y;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][2] = z;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][3] = a;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE] = Families_DishObject(s_FamilyTables[family][E_FAMILY_TABLE_PLATE],0,x,y,z,a,Houses_GetWorld(Families_GetHouse(family)));
	Nearby_StreamObjectsAt(x,y,z,Houses_GetWorld(Families_GetHouse(family)),HOUSE_INTERIOR,HOUSE_STREAM_RANGE);
	Families_CameraWide(playerid);
	Gui_Notify(playerid,"You sit down at the table. Wait for the grace, then press ~y~Y~w~ to take a bite.");

	if (s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] == FAMILY_GUEST_READY)
	{
		SetTimerEx("Families_EatDeferred",FAMILY_BEAT_GAP_MS,false,"d",playerid);
	}

	pawn_call_public("Household_OnGuestSeated","dd",family,playerid);
	return true;
}

stock Families_StandUp(playerid)
{
    s_FamilySeatGenerations[playerid]++;
	if (!Families_IsGuest(playerid))
	{
		return;
	}

    new house = Families_GetHouse(s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY]);
	Families_DropObject(s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE]);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] = -1;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT] = -1;

	if (IsPlayerConnected(playerid))
	{
		ClearAnimations(playerid,SYNC_ALL);
        if (Houses_GetInside(playerid) == house && GetPlayerInterior(playerid) == HOUSE_INTERIOR)
        {
            SetPlayerPos(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][0],s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][1],s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][2]);
            SetPlayerFacingAngle(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_STANDING][3]);
            SetPlayerVelocity(playerid,0.0,0.0,0.0);
        }
		SetCameraBehindPlayer(playerid);
	}
}

stock Families_LeaveTable(playerid)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1)
	{
		return;
	}

	if (s_FamilyGuests[playerid][E_FAMILY_GUEST_INVITED] && s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] < FAMILY_BITES && Families_IsMealOn(family))
	{
		Families_AddFavour(playerid,family,-FAMILY_FAVOUR_RUDE);
		Gui_Notify(playerid,"Getting up before the meal is done is rude. The family noticed.");
	}

	if (s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] > 0)
	{
		Families_SetWellFed(playerid);
	}

	Families_StandUp(playerid);
}

stock Families_SitRefusal(playerid,family,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (!Families_IsTableOpen(family))
	{
		strcopy(dest,"There is no meal laid at the table right now.",size);
	}
	else if (!Families_HasGuestSeat(family))
	{
		strcopy(dest,"This table is kept for the household. They have no place at it for a guest. Try the inn or a bigger house.",size);
	}
	else if (Hygiene_IsReeking(playerid))
	{
		strcopy(dest,"They won't have you at the table smelling like that. Wash first.",size);
	}
	else if (!Families_MaySit(playerid,family))
	{
		strcopy(dest,"You haven't been asked to eat with them. Ask one of the family first.",size);
	}
	else if (Families_FindFreeSeat(playerid,family,FAMILY_SEAT_ANYWHERE) == -1)
	{
		strcopy(dest,"Every seat at the table is taken. Come back another day.",size);
	}
}

stock bool:Families_SeatInvited(playerid,family)
{
	if (!Families_IsTableOpen(family) || Families_IsGuest(playerid))
	{
		return false;
	}

	if (Families_FindByHouse(GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE) != family || GetPlayerInterior(playerid) != HOUSE_INTERIOR)
	{
		Gui_Notify(playerid,"The table is laid. Come inside and they will seat you.");
		return false;
	}

	new reason[96];
	Families_SitRefusal(playerid,family,reason);

	if (reason[0] != EOS)
	{
		Gui_Notify(playerid,reason);
		return false;
	}

	return Families_SeatGuest(playerid,family,Families_FindFreeSeat(playerid,family,FAMILY_SEAT_ANYWHERE));
}

stock Families_AskAtTable(playerid,family)
{
	if (!Util_IsValidPlayer(playerid) || Families_IsGuest(playerid) || !Families_IsTableOpen(family) || Gui_IsBusy(playerid))
	{
		return;
	}

	if (Families_FindByHouse(GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE) != family || GetPlayerInterior(playerid) != HOUSE_INTERIOR)
	{
		return;
	}

	if (Families_MaySit(playerid,family))
	{
		Families_SeatInvited(playerid,family);
		return;
	}

	new member = Families_FirstEater(family);

	if (member != -1)
	{
		Families_OpenMealOffer(playerid,member);
	}
}

stock bool:Families_GuestEat(playerid,slot)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1 || !s_FamilyGuests[playerid][E_FAMILY_GUEST_SETTLED] || slot < 0 || slot > 2 || s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] != FAMILY_GUEST_READY)
	{
		return false;
	}

	new dishes[3];
	Families_GetMenu(family,dishes);

	if (dishes[slot] == -1)
	{
		return false;
	}

	new hunger = g_FamilyDishes[dishes[slot]][E_FAMILY_DISH_HUNGER] / 2, thirst = g_FamilyDishes[dishes[slot]][E_FAMILY_DISH_THIRST] / 2;
	Needs_Feed(playerid,NEED_HUNGER,hunger > 0 || thirst == 0 ? (hunger > 0 ? hunger : 1) : 0);
	Needs_Feed(playerid,NEED_THIRST,thirst);
	new bites = ++s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS];

	new name[28], text[96];
	strcopy(name,g_FamilyDishes[dishes[slot]][E_FAMILY_DISH_NAME]);
	name[0] = tolower(name[0]);
	format(text,sizeof(text),g_FamilyDishes[dishes[slot]][E_FAMILY_DISH_THIRST] > g_FamilyDishes[dishes[slot]][E_FAMILY_DISH_HUNGER] ? ("You drink some %s.") : ("You take a bite of %s."),name);
	Gui_Notify(playerid,text);

	Families_DropObject(s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE]);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE] = Families_DishObject(dishes[0],bites >= FAMILY_BITES ? 2 : (bites >= FAMILY_BITES / 2 ? 1 : 0),s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][0],s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][1],s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][2],s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][3],Houses_GetWorld(Families_GetHouse(family)));
	ApplyAnimation(playerid,FAMILY_SIT_LIB,FAMILY_BITE_ANIM,4.1,false,false,false,true,0,SYNC_ALL);
	SetTimerEx("Families_BackToSitting",2500,false,"d",playerid);
	Families_CameraPlate(playerid);

	if (bites >= FAMILY_BITES)
	{
		s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] = FAMILY_GUEST_DONE;
		Families_AddFavour(playerid,family,FAMILY_FAVOUR_EAT_ALL);
		Gui_Notify(playerid,"You've cleaned your plate. The family is pleased. Stay for the talk or get up when you like.");
		SetTimerEx("Families_CameraWideDeferred",FAMILY_BEAT_GAP_MS,false,"d",playerid);
		return true;
	}

	s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] = FAMILY_GUEST_TALKING;
	SetTimerEx("Families_GuestBeat",FAMILY_BEAT_GAP_MS,false,"dd",playerid,0);
	return true;
}

stock bool:Families_IsGuestTalking(playerid)
{
	return Families_IsGuest(playerid) && s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] == FAMILY_GUEST_TALKING;
}

stock E_FAMILY_GUEST_STATE:Families_GetGuestPhase(playerid)
{
	return Families_IsGuest(playerid) ? s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] : FAMILY_GUEST_WAITING;
}

stock Families_FinishTalk(playerid)
{
	if (!Families_IsGuestTalking(playerid))
	{
		return;
	}

	s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] = FAMILY_GUEST_READY;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER] = -1;
	Families_CameraWide(playerid);
	SetTimerEx("Families_EatDeferred",FAMILY_BEAT_GAP_MS,false,"d",playerid);
}

stock Families_NextTopic(family)
{
	new topics = g_FamilyDefs[family][E_FAMILY_DEF_TOPICS], first = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_TOPIC];

	for (new tries = 0;tries < topics;tries++)
	{
		new topic = first + s_FamilyTables[family][E_FAMILY_TABLE_TALK_NEXT] % topics;
		s_FamilyTables[family][E_FAMILY_TABLE_TALK_NEXT]++;

		if (s_FamilyEating[g_FamilyTopicDefs[topic][E_FAMILY_TOPIC_DEF_MEMBER]])
		{
			return topic;
		}
	}

	return -1;
}

stock Families_GuestReact(playerid,reaction)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1 || reaction < 0 || reaction >= sizeof(g_FamilyReactions))
	{
		return;
	}

	Families_AddFavour(playerid,family,g_FamilyReactions[reaction][E_FAMILY_REACTION_FAVOUR]);
	new speaker = s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER];

	if (speaker != -1 && g_FamilyReactions[reaction][E_FAMILY_REACTION_REPLY][0] != EOS)
	{
		Actors_Say(Families_GetMemberActor(speaker),g_FamilyReactions[reaction][E_FAMILY_REACTION_REPLY]);
	}
}

static Families_CameraTo(playerid,Float:x,Float:y,Float:z,Float:lx,Float:ly,Float:lz,time = FAMILY_CAMERA_MS)
{
	InterpolateCameraPos(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][0],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][1],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][2],x,y,z,time,CAMERA_MOVE);
	InterpolateCameraLookAt(playerid,s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][3],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][4],s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][5],lx,ly,lz,time,CAMERA_MOVE);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][0] = x;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][1] = y;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][2] = z;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][3] = lx;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][4] = ly;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_CAMERA][5] = lz;
}

stock Families_CameraWide(playerid)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1)
	{
		return;
	}

	new Float:sx, Float:sy, Float:sz, Float:sa, Float:px, Float:py, Float:pz, Float:pa;
	new seat = s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT];
	Families_SeatPos(seat,sx,sy,sz,sa);
	Families_SeatPlatePos(family,seat,px,py,pz,pa);
	new Float:dx = -floatsin(sa,degrees), Float:dy = floatcos(sa,degrees);
	Families_CameraTo(playerid,sx - dx * 0.55 - dy * 0.35,sy - dy * 0.55 + dx * 0.35,pz + 0.95,px + dx * 0.6,py + dy * 0.6,pz + 0.15);
}

stock Families_CameraPlate(playerid)
{
	if (!Families_IsGuest(playerid))
	{
		return;
	}

	new Float:px = s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][0], Float:py = s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][1], Float:pz = s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE_POS][2];
	new Float:sx, Float:sy, Float:sz, Float:sa;
	Families_SeatPos(s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT],sx,sy,sz,sa);
	new Float:dx = px - sx, Float:dy = py - sy, Float:length = VectorSize(dx,dy,0.0);

	if (length < 0.05)
	{
		length = 1.0;
	}

	Families_CameraTo(playerid,px - dx / length * 0.35 + dy / length * 0.25,py - dy / length * 0.35 - dx / length * 0.25,pz + 0.55,px,py,pz + 0.05,FAMILY_CAMERA_MS / 2);
}

stock Families_CameraOn(playerid,member)
{
	new actor = Families_GetMemberActor(member), Float:ax, Float:ay, Float:az, Float:sx, Float:sy, Float:sz, Float:sa;

	if (!Families_IsGuest(playerid) || !Actors_GetPos(actor,ax,ay,az))
	{
		return;
	}

	Families_SeatPos(s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT],sx,sy,sz,sa);
	new Float:dx = ax - sx, Float:dy = ay - sy, Float:length = VectorSize(dx,dy,0.0);

	if (length < 0.05)
	{
		length = 1.0;
	}

	dx /= length;
	dy /= length;
	Families_CameraTo(playerid,sx + dx * 0.4 + dy * 0.3,sy + dy * 0.4 - dx * 0.3,sz + 0.70,ax,ay,az + 0.40);
}

stock Families_GuestAnswer(playerid,question,answer)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1 || question < 0 || question >= FAMILY_SEED_QUESTIONS || answer < 0 || answer > 2)
	{
		return;
	}

	Families_AddFavour(playerid,family,g_FamilyAnswerDefs[question * 3 + answer][E_FAMILY_ANSWER_DEF_FAVOUR]);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS]++;
	new head = Families_FirstEater(family);

	if (head != -1)
	{
		Actors_Say(Families_GetMemberActor(head),g_FamilyAnswerDefs[question * 3 + answer][E_FAMILY_ANSWER_DEF_REPLY]);
	}
}

stock Families_SetWellFed(playerid)
{
	Buff_Set(playerid,"well_fed","Well fed","A good meal keeps hunger and thirst at bay.",FAMILY_WELL_FED_SECONDS,FAMILY_WELL_FED_SECONDS);
	s_FamilyWellFedUntil[playerid] = gettime() + FAMILY_WELL_FED_SECONDS;
	s_FamilyWellFedNext[playerid] = gettime() + FAMILY_WELL_FED_EVERY;
}

stock bool:Families_IsWellFed(playerid)
{
	return Util_IsValidPlayer(playerid) && s_FamilyWellFedUntil[playerid] > gettime();
}

static Families_ReplaceToken(text[],const token[],const value[],size = sizeof(text))
{
	new at = strfind(text,token);

	if (at == -1)
	{
		return;
	}

	strdel(text,at,at + strlen(token));
	strins(text,value,at,size);
}

stock Families_FormatTopic(family,topic,dest[],size = sizeof(dest))
{
	Families_FormatText(family,g_FamilyTopicDefs[topic][E_FAMILY_TOPIC_DEF_TEXT],dest,size);
}

stock Families_FormatLine(family,line,dest[],size = sizeof(dest))
{
	Families_FormatText(family,g_FamilyLineDefs[line][E_FAMILY_LINE_DEF_TEXT],dest,size);
}

stock Families_FormatText(family,const source[],dest[],size = sizeof(dest))
{
	strcopy(dest,source,size);

	if (strfind(dest,"{") == -1)
	{
		return;
	}

	new season[CALENDAR_NAME_LEN], neighbour[24], other = (family + 1) % FAMILY_SEED_HOUSEHOLDS;
	Calendar_SeasonName(Calendar_GetSeason(),season);

	for (new i = 0;season[i] != EOS;i++)
	{
		season[i] = tolower(season[i]);
	}

	for (new step = 1;step < FAMILY_SEED_HOUSEHOLDS;step++)
	{
		new candidate = (family + step) % FAMILY_SEED_HOUSEHOLDS;

		if (g_HouseDefs[Families_GetHouse(candidate)][E_HOUSE_DEF_VILLAGE] == g_HouseDefs[Families_GetHouse(family)][E_HOUSE_DEF_VILLAGE])
		{
			other = candidate;
			break;
		}
	}

	format(neighbour,sizeof(neighbour),"%ss",g_FamilyDefs[other][E_FAMILY_DEF_SURNAME]);
	Families_ReplaceToken(dest,"{season}",season,size);
	Families_ReplaceToken(dest,"{neighbour}",neighbour,size);
}

static Families_SayGrace(family)
{
	new head = Families_FirstEater(family);
	s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE] = true;
	s_FamilyTables[family][E_FAMILY_TABLE_TALK_AT] = gettime() + 8;

	if (head == -1)
	{
		return;
	}

	new actor = Families_GetMemberActor(head);
	Actors_Say(actor,g_FamilyGraces[family % FAMILY_SEED_GRACES]);

	if (g_FamilyDefs[family][E_FAMILY_DEF_PIETY] >= 2)
	{
		Actors_Do(actor,Actors_GetSex(actor) ? ("crosses herself.") : ("crosses himself."));
	}

	for (new member = head + 1, last = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER] + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (s_FamilyEating[member])
		{
			Actors_Say(Families_GetMemberActor(member),"Amen.");
			break;
		}
	}

	foreach (new playerid : Player)
	{
		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] == family && s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] == FAMILY_GUEST_WAITING)
		{
			s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] = FAMILY_GUEST_READY;
			SetTimerEx("Families_EatDeferred",FAMILY_LINE_GAP_MS,false,"d",playerid);
		}
	}
}

stock Families_SayGraceNow(family)
{
	if (Families_IsMealOn(family) && !s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE])
	{
		Families_SayGrace(family);
	}
}

static bool:Families_HasGuestTalking(family)
{
	foreach (new playerid : Player)
	{
		if (s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] == family && s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE] == FAMILY_GUEST_TALKING)
		{
			return true;
		}
	}

	return false;
}

stock bool:Families_ConvoFits(family,convo)
{
	if (FAMILY_SEED_CONVOS == 0 || g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_FAMILY] != family)
	{
		return false;
	}

	new season = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_SEASON], meal = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_MEAL];

	if ((season != -1 && season != _:Calendar_GetSeason()) || (meal != -1 && meal != _:s_FamilyTables[family][E_FAMILY_TABLE_KIND]))
	{
		return false;
	}

	if (!s_FamilyEating[g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_ASKER]])
	{
		return false;
	}

	for (new line = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_FIRST_LINE], last = line + g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_LINES];line < last;line++)
	{
		if (!s_FamilyEating[g_FamilyLineDefs[line][E_FAMILY_LINE_DEF_MEMBER]])
		{
			return false;
		}
	}

	return true;
}

stock Families_PickConvo(family)
{
	new picks[32], count = 0;

	for (new convo = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_CONVO], last = convo + g_FamilyDefs[family][E_FAMILY_DEF_CONVOS];convo < last && count < sizeof(picks);convo++)
	{
		if (!s_FamilyConvoUsed[convo] && Families_ConvoFits(family,convo))
		{
			picks[count++] = convo;
		}
	}

	if (count == 0)
	{
		return -1;
	}

	new convo = picks[random(count)];
	s_FamilyConvoUsed[convo] = true;
	return convo;
}

static Families_TableTalk(family)
{
	new convo = s_FamilyTables[family][E_FAMILY_TABLE_CONVO];

	if (convo == -1 && !s_FamilyTables[family][E_FAMILY_TABLE_TOPIC_TURN])
	{
		convo = Families_PickConvo(family);
		s_FamilyTables[family][E_FAMILY_TABLE_CONVO] = convo;
		s_FamilyTables[family][E_FAMILY_TABLE_CONVO_LINE] = 0;
	}

	if (convo == -1)
	{
		s_FamilyTables[family][E_FAMILY_TABLE_TOPIC_TURN] = false;
		Families_TableTalkTopic(family);
		return 0;
	}

	new line = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_FIRST_LINE] + s_FamilyTables[family][E_FAMILY_TABLE_CONVO_LINE]++, text[144];
	Families_FormatLine(family,line,text);
	Actors_Say(Families_GetMemberActor(g_FamilyLineDefs[line][E_FAMILY_LINE_DEF_MEMBER]),text);

	if (s_FamilyTables[family][E_FAMILY_TABLE_CONVO_LINE] < g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_LINES])
	{
		return 1;
	}

	s_FamilyTables[family][E_FAMILY_TABLE_CONVO] = -1;
	s_FamilyTables[family][E_FAMILY_TABLE_TOPIC_TURN] = true;
	return 0;
}

static Families_TableTalkTopic(family)
{
	new topic = Families_NextTopic(family);

	if (topic == -1)
	{
		return;
	}

	new line[144];
	Families_FormatTopic(family,topic,line);
	Actors_Say(Families_GetMemberActor(g_FamilyTopicDefs[topic][E_FAMILY_TOPIC_DEF_MEMBER]),line);
	s_FamilyTables[family][E_FAMILY_TABLE_TOPIC_TURN] = false;
}

static Families_CatchUpMeals()
{
	new E_HOUR_NAME:name = Routine_GetHour();

	if (!Families_IsReady() || (name != HOUR_SEXT && name != HOUR_VESPERS))
	{
		return;
	}

	new hour = -1;

	for (new h = Calendar_GetHour();h >= 0;h--)
	{
		if (Routine_HourAt(h) == name)
		{
			hour = h;
			break;
		}
	}

	new since = Calendar_GetMinuteOfDay() - hour * 60;

	if (hour == -1 || since < 0 || since - FAMILY_MEAL_WINDOW >= FAMILY_MEAL_MINUTES)
	{
		return;
	}

	new stamp = Families_GameMinute() - since;

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		if (s_FamilyMealStamp[family] == stamp)
		{
			continue;
		}

		s_FamilyMealStamp[family] = stamp;

		if (!s_FamilyTables[family][E_FAMILY_TABLE_ON] && Families_StartMeal(family,name == HOUR_SEXT ? FAMILY_MEAL_DINNER : FAMILY_MEAL_SUPPER,since < FAMILY_MEAL_WINDOW))
		{
			s_FamilyTables[family][E_FAMILY_TABLE_START] = stamp + FAMILY_MEAL_WINDOW;
		}
	}
}

stock Families_MealTick()
{
	new now = gettime();
	Families_CatchUpMeals();

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		if (!s_FamilyTables[family][E_FAMILY_TABLE_ON])
		{
			continue;
		}

        if (s_FamilyTables[family][E_FAMILY_TABLE_WAITING])
        {
            if (Families_GameMinute() < s_FamilyTables[family][E_FAMILY_TABLE_START])
            {
                if (Families_GetViewers(family) > 0)
                {
                    Families_RenderTable(family);
                }
                continue;
            }

            s_FamilyTables[family][E_FAMILY_TABLE_WAITING] = false;
            pawn_call_public("Household_OnMealStart","dd",family,_:s_FamilyTables[family][E_FAMILY_TABLE_KIND]);
        }

		new elapsed = Families_MealElapsed(family);

		if (elapsed >= FAMILY_MEAL_MINUTES || elapsed < 0)
		{
			Families_EndMeal(family);
			continue;
		}

		if (Families_GetViewers(family) == 0)
		{
			if (s_FamilyTables[family][E_FAMILY_TABLE_RENDERED])
			{
				Families_ClearTable(family);
			}

			continue;
		}

		Families_RenderTable(family);

		if (!s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE])
		{
			if (elapsed > FAMILY_GRACE_LATE)
			{
				s_FamilyTables[family][E_FAMILY_TABLE_GRACE_DONE] = true;
				s_FamilyTables[family][E_FAMILY_TABLE_TALK_AT] = now + 5;
			}
			else if (s_FamilyTables[family][E_FAMILY_TABLE_GRACE_AT] == 0)
			{
				s_FamilyTables[family][E_FAMILY_TABLE_GRACE_AT] = now + FAMILY_GRACE_DELAY;
			}
			else if (now >= s_FamilyTables[family][E_FAMILY_TABLE_GRACE_AT])
			{
				Families_SayGrace(family);
			}

			continue;
		}

		if (now >= s_FamilyTables[family][E_FAMILY_TABLE_TALK_AT] && !Families_HasGuestTalking(family))
		{
			s_FamilyTables[family][E_FAMILY_TABLE_TALK_AT] = now + (Families_TableTalk(family) ? 6 + random(3) : FAMILY_TALK_MIN + random(FAMILY_TALK_MAX - FAMILY_TALK_MIN + 1));
		}
	}

	foreach (new playerid : Player)
	{
		if (s_FamilyWellFedUntil[playerid] > 0)
		{
			if (now >= s_FamilyWellFedUntil[playerid] || !Buff_Has(playerid,"well_fed"))
			{
				s_FamilyWellFedUntil[playerid] = 0;
			}
			else if (now >= s_FamilyWellFedNext[playerid])
			{
				s_FamilyWellFedNext[playerid] = now + FAMILY_WELL_FED_EVERY;
				Needs_Feed(playerid,NEED_HUNGER,FAMILY_WELL_FED_TOPUP);
				Needs_Feed(playerid,NEED_THIRST,FAMILY_WELL_FED_TOPUP);
			}
		}

		new family = s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY];

		if (family == -1)
		{
			continue;
		}

		if (GetPlayerVirtualWorld(playerid) != Houses_GetWorld(Families_GetHouse(family)))
		{
			Families_LeaveTable(playerid);
		}
	}
}

stock Families_OpenEat(playerid)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1)
	{
		return;
	}

	new E_FAMILY_GUEST_STATE:phase = s_FamilyGuests[playerid][E_FAMILY_GUEST_PHASE];

	if (phase == FAMILY_GUEST_WAITING)
	{
		Gui_Notify(playerid,"Wait for the grace before you eat.");
		return;
	}

	if (phase == FAMILY_GUEST_TALKING)
	{
		Gui_Notify(playerid,"They're talking to you. Answer them before you take another bite.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), dishes[3], title[48], Float:x, Float:y, Float:width, rows = 0;
	Families_GetMenu(family,dishes);

	if (phase == FAMILY_GUEST_DONE)
	{
		dishes[0] = -1;
		dishes[1] = -1;
		dishes[2] = -1;
	}
	format(title,sizeof(title),"%s, bite %d of %d",s_FamilyTables[family][E_FAMILY_TABLE_KIND] == FAMILY_MEAL_DINNER ? ("Dinner") : ("Supper"),s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] + 1,FAMILY_BITES);

	if (phase == FAMILY_GUEST_DONE)
	{
		strcopy(title,"Your plate is clean");
	}

	for (new i = 0;i < 3;i++)
	{
		if (dishes[i] != -1)
		{
			rows++;
		}
	}

	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,FAMILY_PANEL_WIDTH,float(rows + 2) * KIT_ROW + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,phase == FAMILY_GUEST_DONE ? ("Stay and listen, or get up.") : ("Take a bite. They'll talk to you before the next one."),KIT_COLOUR_MUTED);

	for (new i = 0, row = 1;i < 3;i++)
	{
		if (dishes[i] == -1)
		{
			continue;
		}

		Kit_AddChoice(playerid,x,y + KIT_ROW * float(row++),width,g_FamilyDishes[dishes[i]][E_FAMILY_DISH_NAME],i,KIT_COLOUR_TEXT,g_FamilyDishes[dishes[i]][E_FAMILY_DISH_THIRST] > g_FamilyDishes[dishes[i]][E_FAMILY_DISH_HUNGER] ? ("drink") : ("food"));
	}

	Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows + 1),width,"Get up from the table",3,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(rows + 2) * KIT_ROW + 8.0,80.0,"Wait",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
	{
		return;
	}

	if (pick == 3)
	{
		Families_LeaveTable(playerid);
		return;
	}

	Families_GuestEat(playerid,pick);
}

stock Families_OpenQuestion(playerid)
{
	new family = Families_GetGuestFamily(playerid);

	if (family == -1 || s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS] >= 3)
	{
		Families_FinishTalk(playerid);
		return;
	}

	new question = g_FamilyDefs[family][E_FAMILY_DEF_QUESTIONS][s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS]], head = Families_FirstEater(family);

	if (question < 0 || question >= FAMILY_SEED_QUESTIONS || head == -1)
	{
		s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS]++;
		Families_FinishTalk(playerid);
		return;
	}

	Families_CameraOn(playerid,head);

	new actor = Families_GetMemberActor(head), name[ACTORS_NAME_LEN], Float:x, Float:y, Float:width;
	Actors_Say(actor,g_FamilyQuestionDefs[question][E_FAMILY_QUESTION_DEF_TEXT]);
	Actors_GetName(actor,name);

	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,FAMILY_PANEL_WIDTH + 40.0,4.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddText(playerid,x,y,g_FamilyQuestionDefs[question][E_FAMILY_QUESTION_DEF_TEXT],KIT_COLOUR_ACCENT);

	for (new i = 0;i < 3;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1),width,g_FamilyAnswerDefs[question * 3 + i][E_FAMILY_ANSWER_DEF_TEXT],i);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 4.0 * KIT_ROW + 8.0,80.0,"Say nothing",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK || pick < 0 || pick > 2)
	{
		s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS]++;
		SetTimerEx("Families_GuestBeat",FAMILY_LINE_GAP_MS,false,"dd",playerid,2);
		return;
	}

	Families_GuestAnswer(playerid,question,pick);
	SetTimerEx("Families_GuestBeat",FAMILY_LINE_GAP_MS,false,"dd",playerid,2);
}

stock Families_OpenConvoQuestion(playerid)
{
	new convo = s_FamilyGuests[playerid][E_FAMILY_GUEST_CONVO];

	if (!Families_IsGuestTalking(playerid) || convo == -1)
	{
		Families_FinishTalk(playerid);
		return;
	}

	new asker = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_ASKER], actor = Families_GetMemberActor(asker), first = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_FIRST_ANSWER];
	new name[ACTORS_NAME_LEN], question[144], Float:x, Float:y, Float:width;
	Families_FormatText(Families_GetGuestFamily(playerid),g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_QUESTION],question);
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER] = asker;
	Families_CameraOn(playerid,asker);
	Actors_Say(actor,question);
	Actors_GetName(actor,name);

	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,FAMILY_PANEL_WIDTH + 60.0,5.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddText(playerid,x,y,question,KIT_COLOUR_ACCENT,KIT_TEXT_BODY,TEXT_DRAW_FONT_1,false,width);

	for (new i = 0;i < 3;i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 2),width,g_FamilyAnswerDefs[first + i][E_FAMILY_ANSWER_DEF_TEXT],i);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 5.0 * KIT_ROW + 8.0,80.0,"Say nothing",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick >= 0 && pick <= 2 && Families_IsGuest(playerid))
	{
		Families_AddFavour(playerid,Families_GetGuestFamily(playerid),g_FamilyAnswerDefs[first + pick][E_FAMILY_ANSWER_DEF_FAVOUR]);
		Actors_Say(actor,g_FamilyAnswerDefs[first + pick][E_FAMILY_ANSWER_DEF_REPLY]);
	}

	SetTimerEx("Families_GuestBeat",FAMILY_LINE_GAP_MS,false,"dd",playerid,2);
}

stock Families_OpenReaction(playerid)
{
	new speaker = s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER];

	if (!Families_IsGuestTalking(playerid) || speaker == -1)
	{
		Families_FinishTalk(playerid);
		return;
	}

	new actor = Families_GetMemberActor(speaker), name[ACTORS_NAME_LEN], Float:x, Float:y, Float:width;
	Actors_GetName(actor,name);
	new epoch = Gui_BeginFlow(playerid);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,name);
	Kit_OpenPanel(playerid,KIT_ANCHOR_BOTTOM,FAMILY_PANEL_WIDTH,4.0 * KIT_ROW + 6.0 + KIT_ROW + 12.0,name,x,y,width);
	Kit_AddText(playerid,x,y,"They look at you.",KIT_COLOUR_MUTED);

	for (new i = 0;i < sizeof(g_FamilyReactions);i++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(i + 1),width,g_FamilyReactions[i][E_FAMILY_REACTION_TEXT],i);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + 4.0 * KIT_ROW + 8.0,80.0,"Say nothing",KIT_BACK);

	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch) && pick >= 0 && pick < sizeof(g_FamilyReactions))
	{
		Families_GuestReact(playerid,pick);
	}

	SetTimerEx("Families_GuestBeat",pick > 0 ? FAMILY_LINE_GAP_MS : FAMILY_BEAT_GAP_MS,false,"dd",playerid,2);
}

static Families_ClearSeatPrompt(playerid)
{
	if (s_FamilySeatInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_FamilySeatInfobox[playerid]);
	}

	s_FamilySeatPrompt[playerid] = -1;
	s_FamilySeatInfobox[playerid] = 0;
	s_FamilySeatAllowed[playerid] = false;
}

static Families_UpdateSeatPrompt(playerid)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid) || Families_IsGuest(playerid) || Keys_IsBusy(playerid,KEY_YES,FAMILY_SEAT_KEY_PRIO))
	{
		Families_ClearSeatPrompt(playerid);
		return;
	}

	new family = Families_FindByHouse(GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE);

	if (family == -1 || !Families_IsTableOpen(family) || GetPlayerInterior(playerid) != HOUSE_INTERIOR)
	{
		Families_ClearSeatPrompt(playerid);
		return;
	}

	new seat = Families_FindFreeSeat(playerid,family);

	if (seat == -1)
	{
		Families_ClearSeatPrompt(playerid);
		return;
	}

	new bool:allowed = Families_MaySit(playerid,family);

	if (seat == s_FamilySeatPrompt[playerid] && allowed == s_FamilySeatAllowed[playerid] && Infobox_IsShown(playerid,s_FamilySeatInfobox[playerid]))
	{
		return;
	}

	new text[96];

	if (allowed)
	{
		strcopy(text,"Press ~y~Y~w~ to sit down and eat with the family.");
	}
	else if (Hygiene_IsReeking(playerid))
	{
		strcopy(text,"The family is at the table. They won't have you there smelling like that.");
	}
	else
	{
		format(text,sizeof(text),"The family is at the table.~n~Press ~y~Y~w~ to ask if you can eat here for %s.",s_FamilyTables[family][E_FAMILY_TABLE_KIND] == FAMILY_MEAL_DINNER ? ("Sext") : ("Vespers"));
	}

	Families_ClearSeatPrompt(playerid);
	s_FamilySeatPrompt[playerid] = seat;
	s_FamilySeatAllowed[playerid] = allowed;
	s_FamilySeatInfobox[playerid] = Infobox_Show(playerid,"The table",text,3,0,true);
}

Timer_Declare(Families_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid))
		{
			Families_UpdateSeatPrompt(playerid);
		}
	}

	return 1;
}

Timer_Declare(Families_MealTimer)
{
	Families_MealTick();
	return 1;
}

forward Families_GuestBeat(playerid,step);

public Families_GuestBeat(playerid,step)
{
	if (!IsPlayerConnected(playerid) || !Families_IsGuestTalking(playerid))
	{
		return 1;
	}

	new family = Families_GetGuestFamily(playerid);

	switch (step)
	{
		case 0:
		{
			new convo = Families_PickConvo(family);

			if (convo != -1)
			{
				s_FamilyGuests[playerid][E_FAMILY_GUEST_CONVO] = convo;
				s_FamilyGuests[playerid][E_FAMILY_GUEST_LINE] = 0;
				Families_GuestBeat(playerid,10);
				return 1;
			}

			s_FamilyGuests[playerid][E_FAMILY_GUEST_CONVO] = -1;
			new topic = Families_NextTopic(family);

			if (topic == -1)
			{
				Families_FinishTalk(playerid);
				return 1;
			}

			new line[144], member = g_FamilyTopicDefs[topic][E_FAMILY_TOPIC_DEF_MEMBER];
			Families_FormatTopic(family,topic,line);
			s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER] = member;
			Families_CameraOn(playerid,member);
			Actors_Say(Families_GetMemberActor(member),line);
			SetTimerEx("Families_GuestBeat",FAMILY_LINE_GAP_MS,false,"dd",playerid,1);
		}
		case 1:
		{
			if (s_FamilyGuests[playerid][E_FAMILY_GUEST_PICKS] % 2 == 0 && s_FamilyGuests[playerid][E_FAMILY_GUEST_QUESTIONS] < 3)
			{
				Families_OpenQuestion(playerid);
			}
			else
			{
				Families_OpenReaction(playerid);
			}
		}
		case 10:
		{
			new convo = s_FamilyGuests[playerid][E_FAMILY_GUEST_CONVO];

			if (convo == -1 || s_FamilyGuests[playerid][E_FAMILY_GUEST_LINE] >= g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_LINES])
			{
				Families_GuestBeat(playerid,11);
				return 1;
			}

			new line = g_FamilyConvoDefs[convo][E_FAMILY_CONVO_DEF_FIRST_LINE] + s_FamilyGuests[playerid][E_FAMILY_GUEST_LINE]++, member = g_FamilyLineDefs[line][E_FAMILY_LINE_DEF_MEMBER], text[144];
			Families_FormatLine(family,line,text);
			s_FamilyGuests[playerid][E_FAMILY_GUEST_SPEAKER] = member;
			Families_CameraOn(playerid,member);
			Actors_Say(Families_GetMemberActor(member),text);
			SetTimerEx("Families_GuestBeat",FAMILY_LINE_GAP_MS,false,"dd",playerid,10);
		}
		case 11: Families_OpenConvoQuestion(playerid);
		default: Families_FinishTalk(playerid);
	}

	return 1;
}

forward Families_CameraWideDeferred(playerid);

public Families_CameraWideDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Families_IsGuest(playerid))
	{
		Families_CameraWide(playerid);
	}

	return 1;
}

forward Families_AskDeferred(playerid,family);

public Families_AskDeferred(playerid,family)
{
	if (IsPlayerConnected(playerid))
	{
		Families_AskAtTable(playerid,family);
	}

	return 1;
}

forward Families_EatDeferred(playerid);

public Families_EatDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Families_IsGuest(playerid))
	{
		Families_OpenEat(playerid);
	}

	return 1;
}

forward Families_SitGuestDeferred(playerid,generation);

public Families_SitGuestDeferred(playerid,generation)
{
    if (IsPlayerConnected(playerid) && Families_IsGuest(playerid) && generation == s_FamilySeatGenerations[playerid])
    {
        if (!Util_IsInteriorReady(playerid))
        {
            SetTimerEx("Families_SitGuestDeferred",FAMILY_SEAT_READY_POLL_MS,false,"dd",playerid,generation);
            return 1;
        }

        ApplyAnimation(playerid,FAMILY_SIT_LIB,FAMILY_SIT_ANIM,4.1,true,false,false,true,0,SYNC_ALL);
        s_FamilyGuests[playerid][E_FAMILY_GUEST_SETTLED] = true;
        SetTimerEx("Families_SeatNudge",FAMILY_SEAT_NUDGE_MS,false,"dd",playerid,generation);
    }

	return 1;
}

forward Families_SeatNudge(playerid,generation);

public Families_SeatNudge(playerid,generation)
{
    if (IsPlayerConnected(playerid) && Families_IsGuest(playerid) && generation == s_FamilySeatGenerations[playerid])
    {
        SetPlayerVelocity(playerid,0.0,0.0,FAMILY_SEAT_NUDGE);
    }

	return 1;
}

forward Families_BackToSitting(playerid);

public Families_BackToSitting(playerid)
{
	if (IsPlayerConnected(playerid) && Families_IsGuest(playerid))
	{
		ApplyAnimation(playerid,FAMILY_SIT_LIB,FAMILY_SIT_ANIM,4.1,true,false,false,true,0,SYNC_ALL);
	}

	return 1;
}

forward bool:Families_PromptContext(playerid);

public bool:Families_PromptContext(playerid)
{
	return s_FamilySeatPrompt[playerid] != -1 || Families_IsGuest(playerid);
}

forward Household_OnMealStart(family,meal);

public Household_OnMealStart(family,meal)
{
	return 1;
}

forward Household_OnMealEnd(family);

public Household_OnMealEnd(family)
{
	return 1;
}

forward Household_OnGuestSeated(family,playerid);

public Household_OnGuestSeated(family,playerid)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_FamilyGuests[playerid][E_FAMILY_GUEST_FAMILY] = -1;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_SEAT] = -1;
	s_FamilyGuests[playerid][E_FAMILY_GUEST_PLATE] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_FamilyWellFedUntil[playerid] = 0;
	s_FamilySeatPrompt[playerid] = -1;
	s_FamilySeatInfobox[playerid] = 0;
	s_FamilySeatAllowed[playerid] = false;
	s_FamilySeatAskedAt[playerid] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	Families_StandUp(playerid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || Keys_IsBusy(playerid,KEY_YES,FAMILY_SEAT_KEY_PRIO))
	{
		return;
	}

	if (Families_IsGuest(playerid))
	{
		SetTimerEx("Families_EatDeferred",0,false,"d",playerid);
		return;
	}

	if (s_FamilySeatPrompt[playerid] == -1)
	{
		return;
	}

	new seat = s_FamilySeatPrompt[playerid], family = Families_FindByHouse(GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE), bool:allowed = s_FamilySeatAllowed[playerid];
	Families_ClearSeatPrompt(playerid);

	if (!allowed)
	{
		if (gettime() >= s_FamilySeatAskedAt[playerid] + FAMILY_ASK_COOLDOWN)
		{
			s_FamilySeatAskedAt[playerid] = gettime();
			SetTimerEx("Families_AskDeferred",0,false,"dd",playerid,family);
		}

		return;
	}

	if (!Families_SeatGuest(playerid,family,seat))
	{
		new reason[96];
		Families_SitRefusal(playerid,family,reason);
		Gui_Notify(playerid,reason[0] != EOS ? reason : ("Somebody else took that seat. Find another one."));
	}
}

hook Routine_OnKeyframe(hour,E_HOUR_NAME:name)
{
	if (name != HOUR_SEXT && name != HOUR_VESPERS)
	{
		return;
	}

	new stamp = Families_GameMinute() - Calendar_GetMinuteOfDay() + hour * 60;

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		s_FamilyMealStamp[family] = stamp;
		Families_StartMeal(family,name == HOUR_SEXT ? FAMILY_MEAL_DINNER : FAMILY_MEAL_SUPPER,true);
	}
}
