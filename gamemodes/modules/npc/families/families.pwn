static s_FamilySeatEpochs[FAMILY_SEED_MEMBERS];

forward Days_EnsureFresh();
forward Days_Invalidate();
forward Families_GetMassVersion();
forward Families_MassPoll();
forward Days_Want(member,E_HOUR_NAME:name,&E_FAMILY_PLACE:place,&E_FAMILY_ACT:act,&bool:explicit);
forward bool:Days_GetDestination(member,&Float:x,&Float:y,&Float:z,&Float:a);
forward bool:Days_IsExplicit(member);
forward bool:Days_InTransit(member);
forward bool:Days_AtTable(member,E_FAMILY_MEAL:meal);
forward bool:Days_IsSickNow(member);
forward bool:Days_GetWorkAnim(member,lib[],libSize,name[],nameSize,&bool:loop);
forward bool:Days_GetIndoorWorkPose(member,&Float:x,&Float:y,&Float:z,&Float:a);
forward bool:Days_BedsidePos(member,&Float:x,&Float:y,&Float:z,&Float:a);
forward Days_GetNowSpot(member);

enum E_FAMILY_MEMBER
{
	E_FAMILY_MEMBER_ACTOR,
	E_FAMILY_PLACE:E_FAMILY_MEMBER_PLACE,
	E_FAMILY_ACT:E_FAMILY_MEMBER_ACT,
	Float:E_FAMILY_MEMBER_POS[4],
	E_FAMILY_MEMBER_WORLD,
    E_FAMILY_MEMBER_SPOT,
    E_FAMILY_MEMBER_PLACEMENTS,
	bool:E_FAMILY_MEMBER_GOING_IN,
    bool:E_FAMILY_MEMBER_PERSONAL,
}

static s_FamilyMembers[FAMILY_SEED_MEMBERS][E_FAMILY_MEMBER];
static s_FamilyStores[FAMILY_SEED_HOUSEHOLDS];
static s_FamilyOfHouse[HOUSE_SEED_COUNT] = {-1, ...};
static s_FamilyMemberOfActor[ACTORS_MAX] = {-1, ...};
static s_FamilyViewers[HOUSE_SEED_COUNT];
static bool:s_FamiliesReady;
static bool:s_FamiliesFrozen;
static bool:s_FamilyWaitSpotsReady;
static bool:s_FamilyWaitSpotValid[FAMILY_SEED_MEMBERS];
static Float:s_FamilyWaitSpots[FAMILY_SEED_MEMBERS][4];
#define FAMILY_WAIT_GAP (1.75)
#define FAMILY_MASS_MAX (8)
#define FAMILY_MASS_RANGE (250.0)
static s_FamilyMassSlots[FAMILY_SEED_MEMBERS] = {-1, ...};
static bool:s_FamilyMassPending;
static s_FamilyMassVersion;
#define FAMILY_MASS_LEAD_SECONDS (420)

stock bool:Families_IsReady()
{
	return s_FamiliesReady;
}

stock Families_SetFrozen(bool:frozen)
{
	s_FamiliesFrozen = frozen;
}

stock Families_GetHouse(family)
{
	return g_FamilyDefs[family][E_FAMILY_DEF_HOUSE];
}

stock Families_FindByHouse(house)
{
	return house >= 0 && house < HOUSE_SEED_COUNT ? s_FamilyOfHouse[house] : -1;
}

stock Families_FindByKey(const key[])
{
	return Families_FindByHouse(Houses_FindByKey(key));
}

stock Families_GetMemberActor(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_FamilyMembers[member][E_FAMILY_MEMBER_ACTOR] : -1;
}

stock Families_GetPlacementCount(member)
{
    return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_FamilyMembers[member][E_FAMILY_MEMBER_PLACEMENTS] : 0;
}

stock Families_GetMemberOfActor(actor)
{
	return actor >= 0 && actor < ACTORS_MAX ? s_FamilyMemberOfActor[actor] : -1;
}

stock Families_GetMemberFamily(member)
{
	return g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY];
}

stock Families_GetMemberTopic(member, choice)
{
    if (member < 0 || member >= FAMILY_SEED_MEMBERS || choice < 0)
    {
        return -1;
    }

    new family = Families_GetMemberFamily(member);
    new first = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_TOPIC];
    new last = first + g_FamilyDefs[family][E_FAMILY_DEF_TOPICS];

    for (new topic = first; topic < last; topic++)
    {
        if (g_FamilyTopicDefs[topic][E_FAMILY_TOPIC_DEF_MEMBER] == member && choice-- == 0)
        {
            return topic;
        }
    }

    return -1;
}

stock Families_GetMemberTopicCount(member)
{
    new count = 0;

    while (Families_GetMemberTopic(member, count) != -1)
    {
        count++;
    }

    return count;
}

stock E_FAMILY_PLACE:Families_GetPlace(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] : FAMILY_PLACE_NONE;
}

stock Families_GetViewers(family)
{
	return s_FamilyViewers[Families_GetHouse(family)];
}

stock Families_GetStores(family)
{
	return s_FamilyStores[family];
}

stock Families_SetStores(family,stores)
{
	s_FamilyStores[family] = clamp(stores,0,FAMILY_STORES_FULL);
	mysql_tquery_s(g_Mysql,str_format("UPDATE households SET stores = %d WHERE id = %d",s_FamilyStores[family],family + 1));
}

stock Families_GetHead(family)
{
	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];member < last;member++)
	{
		if (!Actors_IsDead(s_FamilyMembers[member][E_FAMILY_MEMBER_ACTOR]))
		{
			return member;
		}
	}

	return -1;
}

stock Families_GetSurname(family,dest[],size = sizeof(dest))
{
	strcopy(dest,g_FamilyDefs[family][E_FAMILY_DEF_SURNAME],size);
}

stock Families_FormatTitle(member,dest[],size = sizeof(dest))
{
	strcopy(dest,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_WHO],size);
	new length = strlen(dest);

	while (length > 0 && ((dest[length - 1] >= '0' && dest[length - 1] <= '9') || dest[length - 1] == ' '))
	{
		dest[--length] = EOS;
	}
}

stock Families_Weekday()
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return (((year - CALENDAR_EPOCH_YEAR) * CALENDAR_MONTHS + (month - 1)) * CALENDAR_DAYS_PER_MONTH + (day - 1)) % 7;
}

stock bool:Families_IsFastDay()
{
	new season = Faith_GetLiturgicalSeason();
	return Families_Weekday() == FAMILY_WEEK_FRIDAY || season == FAITH_SEASON_LENT || season == FAITH_SEASON_PASSIONTIDE || season == FAITH_SEASON_ADVENT;
}

stock bool:Families_IsFeastDay()
{
	return Families_Weekday() == FAMILY_WEEK_SUNDAY || Faith_GetLiturgicalSeason() == FAITH_SEASON_FEAST;
}

stock bool:Families_IsMarketDay()
{
	return Families_Weekday() == FAMILY_WEEK_MARKET;
}

stock bool:Families_IsFoul()
{
	if (Families_GetFoulOverride() != -1)
	{
		return Families_GetFoulOverride() == 1;
	}

	new weather = Calendar_GetWeather();
	return Weather_IsSnowing() || weather == 8 || weather == 16;
}

stock bool:Families_HasPlace(family,E_FAMILY_PLACE:place)
{
	if (_:place >= FAMILY_OUTDOOR_PLACES)
	{
		return true;
	}

	return g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3] != 0.0 || g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 1] != 0.0;
}

stock bool:Families_GoesOut(family)
{
	return Families_HasPlace(family,FAMILY_PLACE_DOORSTEP);
}

stock Families_KeyframeOf(E_HOUR_NAME:name)
{
	switch (name)
	{
		case HOUR_PRIME: return 0;
		case HOUR_TERCE: return 1;
		case HOUR_SEXT: return 2;
		case HOUR_NONES: return 3;
		case HOUR_VESPERS: return 4;
		case HOUR_COMPLINE: return 5;
	}

	return -1;
}

stock bool:Families_EatsAtTable(member,E_FAMILY_MEAL:meal)
{
	return g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] != -1 && !Actors_IsDead(s_FamilyMembers[member][E_FAMILY_MEMBER_ACTOR]) && Days_AtTable(member,meal);
}

stock Float:Families_SpotRange(E_FAMILY_PLACE:place,E_FAMILY_ACT:act)
{
	return place == FAMILY_PLACE_CHURCH || act == FAMILY_ACT_SIT || act == FAMILY_ACT_REST || act == FAMILY_ACT_EAT ? FAMILY_SPOT_RANGE_SEATED : FAMILY_SPOT_RANGE;
}

stock bool:Families_IsPlayerAtSpot(Float:x,Float:y,Float:z,world,interior,Float:range = FAMILY_SPOT_RANGE)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == world && GetPlayerInterior(playerid) == interior)
		{
			new Float:px, Float:py, Float:pz;
			GetPlayerPos(playerid,px,py,pz);
			if (VectorSize(px - x,py - y,0.0) < range && floatabs(pz - z) < 1.5)
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:Families_IsChurchCandidate(member)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		return false;
	}

	new family = Families_GetMemberFamily(member), role = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE], actor = Families_GetMemberActor(member);
	return actor != -1 && !Actors_IsDead(actor) && Families_GoesOut(family) && Families_HasPlace(family,FAMILY_PLACE_CHURCH) && role != _:ACTOR_ROLE_INNKEEPER && role != _:ACTOR_ROLE_SERVANT && role < FAMILY_ROLES && !Days_IsSickNow(member);
}

stock Families_GetChurchSlot(member)
{
	if (!Families_IsChurchCandidate(member))
	{
		return -1;
	}

	new slot = 0;
	for (new piety = 3;piety >= 0;piety--)
	{
		for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
		{
			if (g_FamilyDefs[family][E_FAMILY_DEF_PIETY] != piety)
			{
				continue;
			}
			new selected = 0;
			for (new candidate = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = candidate + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];candidate < last && selected < 2;candidate++)
			{
				if (!Families_IsChurchCandidate(candidate))
				{
					continue;
				}
				if (slot >= Faith_CountCongregationSpots())
				{
					return -1;
				}
				if (candidate == member)
				{
					return slot;
				}
				selected++;
				slot++;
			}
		}
	}
	return -1;
}

stock Families_GetMassSlot(member)
{
    return member >= 0 && member < FAMILY_SEED_MEMBERS && (Faith_IsServiceRunning() || s_FamilyMassPending) ? s_FamilyMassSlots[member] : -1;
}

stock E_FAMILY_PLACE:Families_WantedPlace(member,&E_FAMILY_ACT:act,E_HOUR_NAME:name = HOUR_NONE)
{
	new E_FAMILY_PLACE:place, bool:explicit;
	Days_Want(member,name,place,act,explicit);

	return place;
}

forward bool:Families_SharesSpot(family,E_FAMILY_PLACE:place,E_FAMILY_PLACE:other);

stock bool:Families_IsHouseWaitPlace(family,E_FAMILY_PLACE:place)
{
    return place == FAMILY_PLACE_DOORSTEP || place == FAMILY_PLACE_YARD || Families_SharesSpot(family,place,FAMILY_PLACE_YARD);
}

stock Families_DoorPos(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
    new house = Families_GetHouse(Families_GetMemberFamily(member));
    a = g_HouseDefs[house][E_HOUSE_DEF_DOOR][3];
    x = g_HouseDefs[house][E_HOUSE_DEF_DOOR][0] - floatsin(a,degrees) * 0.6;
    y = g_HouseDefs[house][E_HOUSE_DEF_DOOR][1] + floatcos(a,degrees) * 0.6;
    z = g_HouseDefs[house][E_HOUSE_DEF_DOOR][2];
}

static Families_BuildWaitSpots()
{
    s_FamilyWaitSpotsReady = true;
    for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
    {
        new Float:doorX, Float:doorY, Float:doorZ, Float:a;
        Families_DoorPos(member,doorX,doorY,doorZ,a);
        new Float:outX = -floatsin(a,degrees), Float:outY = floatcos(a,degrees);
        for (new row = 0; row < 4 && !s_FamilyWaitSpotValid[member]; row++)
        {
            for (new index = 0; index < 12; index++)
            {
                new Float:along = (float(index / 2) + 0.5) * FAMILY_WAIT_GAP * (index % 2 == 0 ? -1.0 : 1.0);
                new Float:x = doorX + outX * float(row) * 0.4 + outY * along;
                new Float:y = doorY + outY * float(row) * 0.4 - outX * along, Float:z;
                if (!Placement_FindSurface(x,y,doorZ + 0.8,2.3,z) || floatabs(z - doorZ) > 1.5 || !Walkers_CanWaitOffRoad(x,y,z))
                {
                    continue;
                }
                new bool:free = true;
                for (new other = 0; other < member; other++)
                {
                    if (s_FamilyWaitSpotValid[other] && floatabs(z - s_FamilyWaitSpots[other][2]) < 2.0 && VectorSize(x - s_FamilyWaitSpots[other][0],y - s_FamilyWaitSpots[other][1],0.0) < FAMILY_WAIT_GAP)
                    {
                        free = false;
                        break;
                    }
                }
                if (free)
                {
                    s_FamilyWaitSpots[member][0] = x;
                    s_FamilyWaitSpots[member][1] = y;
                    s_FamilyWaitSpots[member][2] = z;
                    s_FamilyWaitSpots[member][3] = a;
                    s_FamilyWaitSpotValid[member] = true;
                    break;
                }
            }
        }
    }
}

stock bool:Families_GetWaitSpot(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
    if (member < 0 || member >= FAMILY_SEED_MEMBERS)
    {
        return false;
    }
    if (!s_FamilyWaitSpotsReady)
    {
        Families_BuildWaitSpots();
    }
    if (!s_FamilyWaitSpotValid[member])
    {
        return false;
    }
    x = s_FamilyWaitSpots[member][0];
    y = s_FamilyWaitSpots[member][1];
    z = s_FamilyWaitSpots[member][2];
    a = s_FamilyWaitSpots[member][3];
    return true;
}

stock E_FAMILY_PLACE:Families_DeparturePlace(member,&E_FAMILY_ACT:act)
{
    new E_FAMILY_PLACE:place = Families_WantedPlace(member,act);
    if (_:place >= FAMILY_OUTDOOR_PLACES || Families_GetMassSlot(member) != -1)
    {
        return place;
    }
    if (Families_IsHouseWaitPlace(Families_GetMemberFamily(member),place) && !Days_IsExplicit(member))
    {
        new Float:x, Float:y, Float:z, Float:a;
        if (!Families_GetWaitSpot(member,x,y,z,a))
        {
            act = FAMILY_ACT_CHORE;
            return FAMILY_PLACE_HOME;
        }
    }
    return place;
}

stock bool:Families_IsGathering(E_FAMILY_PLACE:place)
{
	return place == FAMILY_PLACE_YARD || place == FAMILY_PLACE_SQUARE || place == FAMILY_PLACE_MARKET;
}

stock bool:Families_SharesSpot(family,E_FAMILY_PLACE:place,E_FAMILY_PLACE:other)
{
	if (place == other)
	{
		return true;
	}

	if (_:place >= FAMILY_OUTDOOR_PLACES || _:other >= FAMILY_OUTDOOR_PLACES || place == FAMILY_PLACE_DOORSTEP || other == FAMILY_PLACE_DOORSTEP)
	{
		return false;
	}

	return g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3] == g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:other * 3] && g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 1] == g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:other * 3 + 1];
}

stock Float:Families_RingRadius(count)
{
	if (count < 2)
	{
		return 0.0;
	}

	new Float:r = FAMILY_GATHER_GAP / (2.0 * floatsin(180.0 / float(count),degrees));
	return r < FAMILY_GATHER_GAP / 2.0 ? FAMILY_GATHER_GAP / 2.0 : r;
}

stock Families_PlaceSpot(family,E_FAMILY_PLACE:place,slot,rank,count,&Float:x,&Float:y,&Float:z,&Float:a)
{
	x = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 0];
	y = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 1];
	z = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 2];
	a = g_FamilyDefs[family][E_FAMILY_DEF_FACING][_:place];

	new Float:lift = 0.0;

	if (_:place < FAMILY_OUTDOOR_PLACES)
	{
		x += g_DaysPlaceFix[family][_:place][0];
		y += g_DaysPlaceFix[family][_:place][1];
		lift = 0.15 * VectorSize(g_DaysPlaceFix[family][_:place][0],g_DaysPlaceFix[family][_:place][1],0.0);

		if (lift > 2.5)
		{
			lift = 2.5;
		}
	}

	if (Families_IsGathering(place) || Families_SharesSpot(family,place,FAMILY_PLACE_YARD))
	{
		if (count > 1)
		{
			new Float:r = Families_RingRadius(count), Float:t = g_DaysPlaceFix[family][_:place][2] + 360.0 * float(rank) / float(count);
			x += floatcos(t,degrees) * r;
			y += floatsin(t,degrees) * r;
			a = t + 90.0;
		}
	}
	else if (place != FAMILY_PLACE_DOORSTEP && _:place < FAMILY_OUTDOOR_PLACES)
	{
		new Float:ox = float(slot % 3 - 1) * FAMILY_SPREAD, Float:oy = float(slot / 3) * FAMILY_SPREAD, Float:turn = g_DaysPlaceFix[family][_:place][3];
		x += ox * floatcos(turn,degrees) - oy * floatsin(turn,degrees);
		y += ox * floatsin(turn,degrees) + oy * floatcos(turn,degrees);
	}

	new Float:ground;

	if ((x != g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 0] || y != g_FamilyDefs[family][E_FAMILY_DEF_PLACES][_:place * 3 + 1]) && Placement_FindSurface(x,y,z + FAMILY_SPOT_GROUND_UP + lift,FAMILY_SPOT_GROUND_UP + FAMILY_SPOT_GROUND_DOWN + lift,ground))
	{
		z = ground;
	}

	while (a >= 360.0)
	{
		a -= 360.0;
	}
}

static Families_OutdoorPos(member,E_FAMILY_PLACE:place,&Float:x,&Float:y,&Float:z,&Float:a,rank = 0,count = 1)
{
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY];
    if (Days_GetDestination(member,x,y,z,a))
    {
        new Float:ground;
        if (Placement_FindSurface(x,y,z + FAMILY_SPOT_GROUND_UP,FAMILY_SPOT_GROUND_UP + FAMILY_SPOT_GROUND_DOWN,ground))
        {
            z = ground;
        }
        return;
    }
	Families_PlaceSpot(family,place,member - g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER],rank,count,x,y,z,a);
}

static Families_PoseOf(const pose[E_HOUSE_POSE_DEF],&Float:x,&Float:y,&Float:z,&Float:a)
{
	Houses_LocalToWorld(pose[E_HOUSE_POSE_DEF_POS][0],pose[E_HOUSE_POSE_DEF_POS][1],pose[E_HOUSE_POSE_DEF_POS][2],x,y,z);
	a = pose[E_HOUSE_POSE_DEF_POS][3];
}

stock Families_SeatPos(seat,&Float:x,&Float:y,&Float:z,&Float:a)
{
	Families_PoseOf(g_HouseSeatDefs[seat],x,y,z,a);
}

stock Families_SeatedPedPos(seat,&Float:x,&Float:y,&Float:z,&Float:a)
{
	Families_SeatPos(seat,x,y,z,a);
	x -= FAMILY_SEAT_BACK * floatsin(-a,degrees);
	y -= FAMILY_SEAT_BACK * floatcos(-a,degrees);
	z += FAMILY_SEAT_PED_Z;
}

stock bool:Families_BedPose(bed,&Float:x,&Float:y,&Float:z,&Float:a)
{
    if (bed < 0 || bed >= HOUSE_SEED_BEDS || !Houses_GetBedPose(bed,x,y,z,a))
    {
        return false;
    }

    Houses_LocalToWorld(x,y,z,x,y,z);
    z += FAMILY_BED_PED_Z;
    a += 180.0;
    return true;
}

stock bool:Families_BedPos(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
    if (member < 0 || member >= FAMILY_SEED_MEMBERS)
    {
        return false;
    }

    new bed = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_BED];

    if (!Families_BedPose(bed,x,y,z,a))
    {
        return false;
    }

    new rank = 0, count = 0;

    for (new other = 0; other < FAMILY_SEED_MEMBERS; other++)
    {
        if (g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_BED] == bed)
        {
            count++;

            if (other < member)
            {
                rank++;
            }
        }
    }

    new Float:offset = (float(rank) - float(count - 1) / 2.0) * 0.7;
    x -= offset * floatsin(-a,degrees);
    y += offset * floatcos(-a,degrees);
    return true;
}

new const g_FamilyIdlePoses[][2][20] = {
	{"PED", "IDLE_stance"},
	{"PED", "IDLE_chat"},
	{"COP_AMBIENT", "Coplook_loop"},
	{"GANGS", "prtial_gngtlkA"},
	{"GANGS", "prtial_gngtlkE"},
	{"GANGS", "prtial_gngtlkG"}
};

stock Families_GetIdlePose(member,E_FAMILY_ACT:act)
{
	if (act != FAMILY_ACT_STAND && act != FAMILY_ACT_CHAT && act != FAMILY_ACT_PLAY)
	{
		return -1;
	}

	return (member * 7 + _:act * 3 + member / sizeof(g_FamilyIdlePoses)) % sizeof(g_FamilyIdlePoses);
}

static Families_ApplyAnim(actor,E_FAMILY_ACT:act,member)
{
    if (act == FAMILY_ACT_EAT)
    {
        SetTimerEx("Families_SeatMember",FAMILY_SEAT_SETTLE_MS,false,"dd",member,++s_FamilySeatEpochs[member]);
        return;
    }

    s_FamilySeatEpochs[member]++;
    if (act == FAMILY_ACT_TEND && Families_GetPlace(member) == FAMILY_PLACE_FOREST && Days_IsExplicit(member))
    {
        Actors_SetAnim(actor,"BOMBER","BOM_Plant_Loop",true);
        return;
    }

    new workLib[20], workName[28], bool:workLoop;
    if (Days_GetWorkAnim(member,workLib,sizeof(workLib),workName,sizeof(workName),workLoop))
    {
        Actors_SetAnim(actor,workLib,workName,workLoop);
        return;
    }

    if (act == FAMILY_ACT_DRINK && Actors_GetSex(actor) == 1)
    {
        Actors_SetAnim(actor,"BAR","dnk_stndF_loop",true);
        return;
    }

	if (act == FAMILY_ACT_SLEEP)
	{
		Actors_SetAnim(actor,HOUSE_SLEEP_LIB,HOUSE_SLEEP_ANIM,false);

		return;
	}

	if (act == FAMILY_ACT_SIT && Families_GetPlace(member) == FAMILY_PLACE_CHURCH)
	{
		Actors_SetAnim(actor,FAMILY_SIT_LIB,FAMILY_SIT_ANIM,true);
		return;
	}

	if ((act == FAMILY_ACT_REST || act == FAMILY_ACT_SIT) && Families_GetPlace(member) == FAMILY_PLACE_HOME)
	{
		Actors_SetAnim(actor,FAMILY_SIT_LIB,FAMILY_SIT_ANIM,true);
		return;
	}

	if (act == FAMILY_ACT_SIT && Actors_GetSex(actor) == 1)
	{
		Actors_SetAnim(actor,"BEACH","ParkSit_W_loop",true);
		return;
	}

	new pose = Families_GetIdlePose(member,act);

	if (pose != -1)
	{
		Actors_SetAnim(actor,g_FamilyIdlePoses[pose][0],g_FamilyIdlePoses[pose][1],true);
		return;
	}

	Actors_SetAnim(actor,g_FamilyActAnims[act][0],g_FamilyActAnims[act][1],true);
}

static bool:Families_IsWatchedOutdoors(Float:x,Float:y,Float:z,Float:range)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,range,x,y,z))
		{
			return true;
		}
	}

	return false;
}

static Families_CountViewers()
{
	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		s_FamilyViewers[house] = 0;
	}

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid))
		{
			continue;
		}

		new house = GetPlayerVirtualWorld(playerid) - HOUSE_WORLD_BASE;

		if (house >= 0 && house < HOUSE_SEED_COUNT)
		{
			s_FamilyViewers[house]++;
		}
	}
}

static Families_UpdateFamily(family)
{
	new house = Families_GetHouse(family), first = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], count = g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS];
	new E_FAMILY_PLACE:places[12], E_FAMILY_ACT:acts[12], spots[12], ranks[12], together[12], bool:taken[64];

	for (new i = 0;i < count && i < sizeof(places);i++)
	{
		places[i] = Families_DeparturePlace(first + i,acts[i]);
		spots[i] = -1;
		ranks[i] = 0;
		together[i] = 0;

		for (new j = 0;j < i;j++)
		{
			if (Families_SharesSpot(family,places[j],places[i]))
			{
				ranks[i]++;
			}
		}
	}

	for (new i = 0;i < count && i < sizeof(places);i++)
	{
		for (new j = 0;j < count && j < sizeof(places);j++)
		{
			if (Families_SharesSpot(family,places[j],places[i]))
			{
				together[i]++;
			}
		}
	}

	new spotFirst = g_HouseDefs[house][E_HOUSE_DEF_FIRST][3], spotCount = g_HouseDefs[house][E_HOUSE_DEF_COUNT][3];

    for (new i = 0;i < count && i < sizeof(places);i++)
    {
        new member = first + i, spot = s_FamilyMembers[member][E_FAMILY_MEMBER_SPOT];
        if (places[i] == FAMILY_PLACE_HOME && Families_GetPlace(member) == places[i] && s_FamilyMembers[member][E_FAMILY_MEMBER_ACT] == acts[i] && spot >= spotFirst && spot < spotFirst + min(spotCount,sizeof(taken)) && !taken[spot - spotFirst])
        {
            spots[i] = spot;
            taken[spot - spotFirst] = true;
        }
    }

	for (new pass = 0;pass < 2;pass++)
	{
		for (new i = 0;i < count && i < sizeof(places);i++)
		{
			if (places[i] != FAMILY_PLACE_HOME || spots[i] != -1 || ((acts[i] == FAMILY_ACT_REST || acts[i] == FAMILY_ACT_SIT) && g_FamilyMemberDefs[first + i][E_FAMILY_MEMBER_DEF_SEAT] != -1))
			{
				continue;
			}

			for (new s = 0;s < spotCount && s < sizeof(taken);s++)
			{
				if (taken[s] || (pass == 0 && strcmp(g_HouseSpotDefs[spotFirst + s][E_HOUSE_POSE_DEF_WHO],g_FamilyActSpots[acts[i]]) != 0))
				{
					continue;
				}

				new Float:sx, Float:sy, Float:sz, Float:sa;
				Families_PoseOf(g_HouseSpotDefs[spotFirst + s],sx,sy,sz,sa);
				new actor = Families_GetMemberActor(first + i);
                new bool:holdsSpot = Actors_IsPlaced(actor) && Families_GetPlace(first + i) == FAMILY_PLACE_HOME && VectorSize(sx - s_FamilyMembers[first + i][E_FAMILY_MEMBER_POS][0],sy - s_FamilyMembers[first + i][E_FAMILY_MEMBER_POS][1],sz + FAMILY_PED_Z - s_FamilyMembers[first + i][E_FAMILY_MEMBER_POS][2]) < 0.2;
                if (!holdsSpot && Families_IsPlayerAtSpot(sx,sy,sz + FAMILY_PED_Z,Houses_GetWorld(house),HOUSE_INTERIOR))
				{
					continue;
				}

				taken[s] = true;
				spots[i] = spotFirst + s;
				break;
			}
		}
	}

	for (new i = 0;i < count && i < sizeof(places);i++)
	{
		Families_UpdateMember(first + i,house,places[i],acts[i],spots[i],ranks[i],together[i]);
	}
}

forward Float:Families_SeatLift(skin);

stock bool:Families_CanTravel(actor,Float:x,Float:y,Float:z)
{
    new total = 0;
    for (new other = 0; other < ACTORS_MAX; other++)
    {
        if (other != actor && Actors_IsWalking(other))
        {
            total++;
        }
    }
    if (!Families_HasTravelBudget(total,0))
    {
        return false;
    }
    foreach (new playerid : Player)
    {
        if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || !IsPlayerInRangeOfPoint(playerid,FAMILY_OUTDOOR_RANGE,x,y,z))
        {
            continue;
        }
        new nearby = 0;
        for (new other = 0; other < ACTORS_MAX; other++)
        {
            new Float:ox, Float:oy, Float:oz;
            if (other != actor && Actors_IsWalking(other) && Actors_GetPos(other,ox,oy,oz) && IsPlayerInRangeOfPoint(playerid,FAMILY_OUTDOOR_RANGE,ox,oy,oz))
            {
                nearby++;
            }
        }
        if (!Families_HasTravelBudget(total,nearby,IsPlayerInRangeOfPoint(playerid,FAMILY_CLOSE_RANGE,x,y,z)))
        {
            return false;
        }
    }
    return true;
}

static Families_UpdateMember(member,house,E_FAMILY_PLACE:place,E_FAMILY_ACT:act,spot,rank,together)
{
	new actor = s_FamilyMembers[member][E_FAMILY_MEMBER_ACTOR];

	if (actor == -1)
	{
		return;
	}

	if (Actors_IsPlaced(actor) && Actors_IsTalkingTo(actor))
	{
		return;
	}

	if (place == FAMILY_PLACE_NONE)
	{
		if (Actors_IsPlaced(actor) && !Actors_IsWalking(actor) && !Actors_IsDead(actor))
		{
			Actors_Remove(actor);
		}

		s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = FAMILY_PLACE_NONE;
		return;
	}

	new Float:x, Float:y, Float:z, Float:a, world = 0, interior = 0, bool:indoor = _:place >= FAMILY_OUTDOOR_PLACES;

	if (place == FAMILY_PLACE_HOME && (act == FAMILY_ACT_REST || act == FAMILY_ACT_SIT) && g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] == -1)
	{
		act = FAMILY_ACT_STAND;
	}

	switch (place)
	{
		case FAMILY_PLACE_TABLE:
		{
			Families_SeatedPedPos(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT],x,y,z,a);
		}
		case FAMILY_PLACE_BED:
		{
            if (act != FAMILY_ACT_SLEEP && Days_BedsidePos(member,x,y,z,a))
            {
                z -= FAMILY_BED_PED_Z - 0.4;
            }
            else
            {
                Families_BedPos(member,x,y,z,a);
            }
		}
		case FAMILY_PLACE_HOME:
		{
			if (Days_GetIndoorWorkPose(member,x,y,z,a))
			{
				z += FAMILY_PED_Z;
			}
			else if ((act == FAMILY_ACT_REST || act == FAMILY_ACT_SIT) && g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] != -1)
			{
				Families_SeatedPedPos(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT],x,y,z,a);
			}
			else if (spot != -1)
			{
				Families_PoseOf(g_HouseSpotDefs[spot],x,y,z,a);
				z += FAMILY_PED_Z;
			}
			else if (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT] != -1)
			{
				Families_SeatPos(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT],x,y,z,a);
				z += FAMILY_SEAT_PED_Z;
				act = FAMILY_ACT_STAND;
			}
			else
			{
				Actors_Remove(actor);
				return;
			}
		}
		case FAMILY_PLACE_CHURCH:
		{
			new slot = Families_GetMassSlot(member);
            if (slot == -1 && Routine_GetHour() == HOUR_TERCE && Families_IsFeastDay())
            {
                slot = Families_GetChurchSlot(member);
            }
			if (slot != -1)
			{
				Faith_GetCongregationSpot(slot,x,y,z,a);
			}
			else
			{
				Families_OutdoorPos(member,place,x,y,z,a,rank,together);
				z += FAMILY_PED_Z;
			}
		}
		default:
		{
			Families_OutdoorPos(member,place,x,y,z,a,rank,together);
			z += FAMILY_PED_Z;
		}
	}

    if (!indoor && Families_IsHouseWaitPlace(Families_GetMemberFamily(member),place) && !Days_IsExplicit(member))
    {
        if (!Families_GetWaitSpot(member,x,y,z,a))
        {
            return;
        }
        z += FAMILY_PED_Z;
        if (act == FAMILY_ACT_SIT || act == FAMILY_ACT_REST)
        {
            act = FAMILY_ACT_STAND;
        }
    }

	if (act == FAMILY_ACT_EAT || act == FAMILY_ACT_SIT || act == FAMILY_ACT_REST)
	{
		z += Families_SeatLift(Actors_GetSkin(actor));
	}

	if (indoor)
	{
		world = Houses_GetWorld(house);
		interior = HOUSE_INTERIOR;
	}

    if (Families_IsPlayerAtSpot(x,y,z,world,interior,Families_SpotRange(place,act)))
    {
        if (!indoor && Actors_IsPlaced(actor) && !Actors_IsWalking(actor))
        {
            Actors_Remove(actor);
        }
        if (!indoor || !Actors_IsPlaced(actor) || VectorSize(x - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0],y - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][1],z - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][2]) > 0.2)
        {
            return;
        }
    }

    new bool:transit = !indoor && Days_InTransit(member) && s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] != FAMILY_PLACE_NONE;

    if (transit && !Actors_IsPlaced(actor) && !Actors_IsWalking(actor))
    {
        new Float:px, Float:py, Float:pz, Float:pa, bool:startsIndoors = Actors_GetWorld(actor) != 0;
        Actors_GetPos(actor,px,py,pz,pa);
        if (startsIndoors)
        {
            Families_DoorPos(member,px,py,pz,pa);
            pz += FAMILY_PED_Z;
            pa = g_HouseDefs[house][E_HOUSE_DEF_DOOR][3];
        }
        if (!(startsIndoors ? Families_IsWatchedOutdoors(g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2],FAMILY_DOOR_RANGE) : Families_IsWatchedOutdoors(px,py,pz,FAMILY_OUTDOOR_RANGE)))
        {
            return;
        }
        if (!Families_CanTravel(actor,px,py,pz))
        {
            return;
        }
        new bool:trip = Days_IsExplicit(member);
        s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = place;
        s_FamilyMembers[member][E_FAMILY_MEMBER_ACT] = act;
        s_FamilyMembers[member][E_FAMILY_MEMBER_SPOT] = spot;
        s_FamilyMembers[member][E_FAMILY_MEMBER_PERSONAL] = trip;
        s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0] = x;
        s_FamilyMembers[member][E_FAMILY_MEMBER_POS][1] = y;
        s_FamilyMembers[member][E_FAMILY_MEMBER_POS][2] = z;
        s_FamilyMembers[member][E_FAMILY_MEMBER_POS][3] = a;
        s_FamilyMembers[member][E_FAMILY_MEMBER_WORLD] = world;
        s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = false;
        Actors_SetPlace(actor,px,py,pz,pa,0,0);
        if (Actors_Place(actor))
        {
            s_FamilyMembers[member][E_FAMILY_MEMBER_PLACEMENTS]++;
        }
        Actors_WalkTo(actor,x,y,z,a,ACTORS_WALK_SPEED,false);
        return;
    }

    if (Actors_IsPlaced(actor) && Actors_GetWorld(actor) == 0)
    {
        new Float:cx, Float:cy, Float:cz;
        Actors_GetPos(actor,cx,cy,cz);
        if (!Families_ShouldTravel(true,Families_IsWatchedOutdoors(cx,cy,cz,FAMILY_OUTDOOR_RANGE)))
        {
            Actors_Remove(actor);

            if (transit)
            {
                Actors_SetPlace(actor,cx,cy,cz,a,0,0);
            }
            else
            {
                Actors_SetPlace(actor,x,y,z,a,world,interior);
            }
        }
    }

    if (transit && !Actors_IsPlaced(actor))
    {
        return;
    }

	new E_FAMILY_PLACE:was = s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE], bool:wasIndoor = _:was >= FAMILY_OUTDOOR_PLACES;
	new bool:changed = was != place || s_FamilyMembers[member][E_FAMILY_MEMBER_ACT] != act || VectorSize(x - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0],y - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][1],z - s_FamilyMembers[member][E_FAMILY_MEMBER_POS][2]) > 0.2;

    new bool:personalTrip = !indoor && Days_IsExplicit(member);
    new bool:wasPersonal = s_FamilyMembers[member][E_FAMILY_MEMBER_PERSONAL];
    if (changed && ((Actors_IsPlaced(actor) && Actors_GetWorld(actor) == 0) || (!indoor && wasIndoor && was != FAMILY_PLACE_NONE && Families_IsWatchedOutdoors(g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2],FAMILY_DOOR_RANGE))))
    {
        new Float:cx, Float:cy, Float:cz, Float:ca;
        if (wasIndoor)
        {
            Families_DoorPos(member,cx,cy,cz,ca);
        }
        else
        {
            Actors_GetPos(actor,cx,cy,cz,ca);
        }
        if (!Families_CanTravel(actor,cx,cy,cz))
        {
            return;
        }
    }

	if (changed)
	{
		s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = place;
		s_FamilyMembers[member][E_FAMILY_MEMBER_ACT] = act;
        s_FamilyMembers[member][E_FAMILY_MEMBER_SPOT] = spot;
        s_FamilyMembers[member][E_FAMILY_MEMBER_PERSONAL] = personalTrip;
		s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0] = x;
		s_FamilyMembers[member][E_FAMILY_MEMBER_POS][1] = y;
		s_FamilyMembers[member][E_FAMILY_MEMBER_POS][2] = z;
		s_FamilyMembers[member][E_FAMILY_MEMBER_POS][3] = a;
		s_FamilyMembers[member][E_FAMILY_MEMBER_WORLD] = world;

		if (!wasIndoor && Actors_IsPlaced(actor) && Actors_GetWorld(actor) == 0)
		{
			if (!indoor)
			{
				s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = false;
                Actors_WalkTo(actor,x,y,z,a,ACTORS_WALK_SPEED,!personalTrip && !wasPersonal && (was == FAMILY_PLACE_YARD || was == FAMILY_PLACE_DOORSTEP) && (place == FAMILY_PLACE_YARD || place == FAMILY_PLACE_DOORSTEP));
				return;
			}

			new Float:sx, Float:sy, Float:sz, Float:sa;
			Families_DoorPos(member,sx,sy,sz,sa);
			s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = true;
            Actors_WalkTo(actor,sx,sy,sz + FAMILY_PED_Z,g_HouseDefs[house][E_HOUSE_DEF_DOOR][3] + 180.0,ACTORS_WALK_SPEED,!wasPersonal && (was == FAMILY_PLACE_YARD || was == FAMILY_PLACE_DOORSTEP));
			return;
		}

		if (wasIndoor && !indoor && was != FAMILY_PLACE_NONE && Families_IsWatchedOutdoors(g_HouseDefs[house][E_HOUSE_DEF_DOOR][0],g_HouseDefs[house][E_HOUSE_DEF_DOOR][1],g_HouseDefs[house][E_HOUSE_DEF_DOOR][2],FAMILY_DOOR_RANGE))
		{
			new Float:sx, Float:sy, Float:sz, Float:sa;
			Families_DoorPos(member,sx,sy,sz,sa);
			Actors_Remove(actor);
			Actors_SetPlace(actor,sx,sy,sz + FAMILY_PED_Z,sa,0,0);
            if (Actors_Place(actor))
            {
                s_FamilyMembers[member][E_FAMILY_MEMBER_PLACEMENTS]++;
            }
			s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = false;
            Actors_WalkTo(actor,x,y,z,a,ACTORS_WALK_SPEED,!personalTrip && (place == FAMILY_PLACE_YARD || place == FAMILY_PLACE_DOORSTEP));
			return;
		}

		if (Actors_IsPlaced(actor))
		{
			Actors_Remove(actor);
		}

		Actors_SetPlace(actor,x,y,z,a,world,interior);
	}

    if (!Actors_IsPlaced(actor))
    {
        Actors_SetPlace(actor,x,y,z,a,world,interior);
    }

	if (Actors_IsWalking(actor))
	{
		return;
	}

	if (changed)
	{
		Families_ApplyAnim(actor,act,member);
	}

	new bool:visible = indoor ? s_FamilyViewers[house] > 0 : Families_IsWatchedOutdoors(x,y,z,FAMILY_OUTDOOR_RANGE);

	if (visible && !Actors_IsPlaced(actor) && !Actors_IsDead(actor))
	{
		Actors_SetPlace(actor,x,y,z,a,world,interior);
		Families_ApplyAnim(actor,act,member);
        if (act != FAMILY_ACT_EAT && Actors_Place(actor))
        {
            s_FamilyMembers[member][E_FAMILY_MEMBER_PLACEMENTS]++;
        }
	}
	else if (!visible && Actors_IsPlaced(actor))
	{
		Actors_Remove(actor);
	}
}

stock Families_Refresh()
{
	if (!s_FamiliesReady || s_FamiliesFrozen)
	{
		return;
	}

	Families_CountViewers();
	Families_MassPoll();
	Days_EnsureFresh();

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		Families_UpdateFamily(family);
	}
}

stock Families_RefreshFamily(family)
{
	if (!s_FamiliesReady)
	{
		return;
	}

	Families_CountViewers();
	Days_EnsureFresh();
	Families_UpdateFamily(family);
}

static bool:Families_IsTwinOfPrevious(member)
{
	return member > 0 && strfind(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_WHO],"twin") != -1 && strfind(g_FamilyMemberDefs[member - 1][E_FAMILY_MEMBER_DEF_WHO],"twin") != -1 && g_FamilyMemberDefs[member - 1][E_FAMILY_MEMBER_DEF_FAMILY] == g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY];
}

static Families_RankInBand(member)
{
	new rank = 0, age = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE], sex = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX];

	for (new other = 0;other < member;other++)
	{
		if (g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_AGE] == age && g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_SEX] == sex && !Families_IsTwinOfPrevious(other))
		{
			rank++;
		}
	}

	return rank;
}

static bool:Families_IsSmallChild(member,rank)
{
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], older = 0, children = 0;

	for (new other = 0;other < FAMILY_SEED_MEMBERS;other++)
	{
		if (g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_FAMILY] != family || g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_AGE] != FAMILY_AGE_CHILD || Families_IsTwinOfPrevious(other))
		{
			continue;
		}

		children++;

		if (other < member)
		{
			older++;
		}
	}

	return children > 1 ? older > 0 : rank % 2 == 1;
}

stock Families_SkinFor(member)
{
	new sex = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX], age = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE];

	if (age == FAMILY_AGE_CHILD)
	{
		new first = Families_IsTwinOfPrevious(member) ? member - 1 : member, bool:small = Families_IsSmallChild(first,Families_RankInBand(first)), turn = 0;

		for (new other = 0;other < first;other++)
		{
			if (g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_AGE] == FAMILY_AGE_CHILD && g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_SEX] == sex && !Families_IsTwinOfPrevious(other) && Families_IsSmallChild(other,Families_RankInBand(other)) == small)
			{
				turn++;
			}
		}

		if (small)
		{
			return sex ? g_FamilySmallGirlSkins[turn % sizeof(g_FamilySmallGirlSkins)] : g_FamilySmallBoySkins[turn % sizeof(g_FamilySmallBoySkins)];
		}

		return sex ? g_FamilyGirlSkins[turn % sizeof(g_FamilyGirlSkins)] : g_FamilyBoySkins[turn % sizeof(g_FamilyBoySkins)];
	}

	if (age == FAMILY_AGE_ELDER)
	{
		new rank = Families_RankInBand(member);
		return sex ? g_FamilyOldWomanSkins[rank % sizeof(g_FamilyOldWomanSkins)] : g_FamilyOldManSkins[rank % sizeof(g_FamilyOldManSkins)];
	}

	if (age == FAMILY_AGE_YOUTH)
	{
		return Families_YouthSkin(member);
	}

	new count = Skins_CountStarter(sex);
	return count > 0 ? Skins_GetStarter(sex,(member * 7 + g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY] * 3) % count) : (sex ? 12 : 1);
}

static Families_YouthSkin(member)
{
	new sex = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX], family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], rank = Families_RankInBand(member), size = sex ? sizeof(g_FamilyYouthWomanSkins) : sizeof(g_FamilyYouthManSkins);

	for (new step = 0;step < size;step++)
	{
		new skin = sex ? g_FamilyYouthWomanSkins[(rank + step) % size] : g_FamilyYouthManSkins[(rank + step) % size], bool:taken = false;

		for (new other = 0;other < FAMILY_SEED_MEMBERS && !taken;other++)
		{
			new otherAge = g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_AGE];

			if (other != member && g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_FAMILY] == family && (otherAge == FAMILY_AGE_ADULT || (otherAge == FAMILY_AGE_YOUTH && other < member)))
			{
				taken = Families_SkinFor(other) == skin;
			}
		}

		if (!taken)
		{
			return skin;
		}
	}

	return sex ? g_FamilyYouthWomanSkins[rank % size] : g_FamilyYouthManSkins[rank % size];
}

stock Families_AddSkinMigration()
{
	new String:sql = str_new("UPDATE household_members SET skin = CASE id"), String:ids = str_new("");

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		new age = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE];

		if (age == FAMILY_AGE_CHILD || age == FAMILY_AGE_ELDER)
		{
			str_append_format(sql," WHEN %d THEN %d",member + 1,Families_SkinFor(member));
			str_append_format(ids,"%s%d",str_len(ids) == 0 ? ("") : (","),member + 1);
		}
	}

	str_append_format(sql," END WHERE id IN (%S)",ids);
	new text[2048];
	str_get(sql,text);
	Migration_Add("npc-household-members-2-age-skins",text);
	Migration_Add("npc-actors-2-age-skins","UPDATE actors a JOIN household_members m ON m.actor_id = a.id SET a.skin = m.skin WHERE m.age_band IN (0, 3)");
	Migration_Add("npc-household-members-5-child-turns",text);
	Migration_Add("npc-actors-5-child-turns","UPDATE actors a JOIN household_members m ON m.actor_id = a.id SET a.skin = m.skin WHERE m.age_band IN (0, 3)");
	str_delete(sql);
	str_delete(ids);

	sql = str_new("UPDATE household_members SET skin = CASE id");
	ids = str_new("");

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		if (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE] == FAMILY_AGE_YOUTH)
		{
			str_append_format(sql," WHEN %d THEN %d",member + 1,Families_SkinFor(member));
			str_append_format(ids,"%s%d",str_len(ids) == 0 ? ("") : (","),member + 1);
		}
	}

	str_append_format(sql," END WHERE id IN (%S)",ids);
	str_get(sql,text);
	Migration_Add("npc-household-members-3-youth-skins",text);
	Migration_Add("npc-actors-3-youth-skins","UPDATE actors a JOIN household_members m ON m.actor_id = a.id SET a.skin = m.skin WHERE m.age_band = 1");
	str_delete(sql);
	str_delete(ids);
}

stock Float:Families_SeatLift(skin)
{
	for (new i = 0;i < sizeof(g_FamilyChildSeatLift);i++)
	{
		if (g_FamilyChildSeatLift[i][0] == skin)
		{
			return float(g_FamilyChildSeatLift[i][1]) / 100.0;
		}
	}

	return 0.0;
}

stock Families_FormatKey(member,dest[],size = sizeof(dest))
{
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY];
	format(dest,size,"%s%s:%d",FAMILY_KEY_PREFIX,g_HouseDefs[Families_GetHouse(family)][E_HOUSE_DEF_KEY],member - g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER]);
}

stock Families_FormatName(member,dest[],size = sizeof(dest))
{
	format(dest,size,"%s %s",g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_NAME],g_FamilyDefs[g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY]][E_FAMILY_DEF_SURNAME]);
}

forward Task:Families_Seed();
#pragma warning push
#pragma warning disable 204
async Task:Families_Seed()
{
	new String:households = str_new("INSERT IGNORE INTO households (id, house_key, name, wealth, trade, piety, stores) VALUES ");

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		new head = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER];
		str_append_format(households,"%s(%d, '%e', '%e', %d, %d, %d, %d)",family == 0 ? ("") : (", "),family + 1,g_HouseDefs[Families_GetHouse(family)][E_HOUSE_DEF_KEY],g_FamilyDefs[family][E_FAMILY_DEF_SURNAME],g_FamilyDefs[family][E_FAMILY_DEF_WEALTH],g_FamilyMemberDefs[head][E_FAMILY_MEMBER_DEF_ROLE],g_FamilyDefs[family][E_FAMILY_DEF_PIETY],FAMILY_STORES_FULL);
	}

	await mysql_aquery_s(g_Mysql,households);

	new String:actors = str_new("INSERT IGNORE INTO actors (actor_key, role, kind, skin, name, home_place_key, schedule, persona, can_act) VALUES "), key[ACTORS_KEY_LEN], name[ACTORS_NAME_LEN];

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		Families_FormatKey(member,key);
		Families_FormatName(member,name);
		str_append_format(actors,"%s('%e', %d, %d, %d, '%e', '%e', %d, 0, 1)",member == 0 ? ("") : (", "),key,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE],_:ACTOR_KIND_STATIC,Families_SkinFor(member),name,g_HouseDefs[Families_GetHouse(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY])][E_HOUSE_DEF_KEY],g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE]);
	}

	await mysql_aquery_s(g_Mysql,actors);

	new String:members = str_new("INSERT IGNORE INTO household_members (id, household_id, name, role, age_band, skin, persona, seat, bed, actor_id) VALUES ");

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		Families_FormatKey(member,key);
		str_append_format(members,"%s(%d, %d, '%e', %d, %d, %d, 0, %d, %d, (SELECT id FROM actors WHERE actor_key = '%e'))",member == 0 ? ("") : (", "),member + 1,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY] + 1,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_NAME],g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE],g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE],Families_SkinFor(member),g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEAT],g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_BED],key);
	}

	await mysql_aquery_s(g_Mysql,members);
	await mysql_aquery_s(g_Mysql,str_new("INSERT IGNORE INTO seeders (seeder_key) VALUES ('npc-households-1')"));
	return async FAMILY_SEED_MEMBERS;
}
#pragma warning pop

stock Families_RegisterAll()
{
	for (new house = 0;house < HOUSE_SEED_COUNT;house++)
	{
		s_FamilyOfHouse[house] = -1;
	}

	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		s_FamilyOfHouse[Families_GetHouse(family)] = family;
	}

	new key[ACTORS_KEY_LEN], name[ACTORS_NAME_LEN], title[ACTORS_TITLE_LEN];

	for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
	{
		Families_FormatKey(member,key);
		Families_FormatName(member,name);
		Families_FormatTitle(member,title);
		new actor = Actors_Register(key,E_ACTOR_ROLE:g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE],ACTOR_KIND_STATIC,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX],Families_SkinFor(member),name,title,g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE],member);
		s_FamilyMembers[member][E_FAMILY_MEMBER_ACTOR] = actor;
		s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = FAMILY_PLACE_NONE;
        s_FamilyMembers[member][E_FAMILY_MEMBER_SPOT] = -1;
		s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = false;

		if (actor != -1)
		{
			s_FamilyMemberOfActor[actor] = member;
		}
	}

	s_FamiliesReady = true;
}

forward Task:Families_LoadStores();
#pragma warning push
#pragma warning disable 204
async Task:Families_LoadStores()
{
	for (new family = 0;family < FAMILY_SEED_HOUSEHOLDS;family++)
	{
		s_FamilyStores[family] = FAMILY_STORES_FULL;
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, stores FROM households"));

	for (new row = 0, rows = cache_num_rows();row < rows;row++)
	{
		new id, stores;
		cache_get_value_name_int(row,"id",id);
		cache_get_value_name_int(row,"stores",stores);

		if (id >= 1 && id <= FAMILY_SEED_HOUSEHOLDS)
		{
			s_FamilyStores[id - 1] = stores;
		}
	}

	return async FAMILY_SEED_HOUSEHOLDS;
}
#pragma warning pop

Timer_Declare(Families_Tick)
{
	Families_Refresh();
	return 1;
}

forward Families_LoadOnBoot();

public Families_LoadOnBoot()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT 1 FROM seeders WHERE seeder_key = 'npc-households-1'"));

	if (cache_num_rows() == 0)
	{
		await Families_Seed();
	}

	await Families_LoadStores();
	await Actors_LoadRows();
	Families_RegisterAll();
	Log_Info("families","%d households, %d people",FAMILY_SEED_HOUSEHOLDS,FAMILY_SEED_MEMBERS);
	Boot_LoaderDone();
	return 1;
}

#include <pp-hooks>

stock Families_GetMassVersion()
{
    return s_FamilyMassVersion;
}

stock Families_AssignMass(church)
{
    s_FamilyMassVersion++;
    new Float:x, Float:y, Float:z, Float:a, attending = 0;
    Faith_GetPriestSpot(church,x,y,z,a);
    for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
    {
        s_FamilyMassSlots[member] = -1;
        new slot = Families_GetChurchSlot(member);
        if (attending >= FAMILY_MASS_MAX || slot < 0 || slot >= Faith_CountCongregationSeats())
        {
            continue;
        }

        new house = Families_GetHouse(Families_GetMemberFamily(member));
        if (VectorSize(g_HouseDefs[house][E_HOUSE_DEF_DOOR][0] - x,g_HouseDefs[house][E_HOUSE_DEF_DOOR][1] - y,0.0) > FAMILY_MASS_RANGE)
        {
            continue;
        }

        new Float:seatX, Float:seatY, Float:seatZ, Float:seatAngle;
        Faith_GetCongregationSpot(slot,seatX,seatY,seatZ,seatAngle);
        if (Families_IsPlayerAtSpot(seatX,seatY,seatZ,0,0))
        {
            continue;
        }

        s_FamilyMassSlots[member] = slot;
        attending++;
    }
}

stock Families_MassPoll()
{
    if (Faith_IsServiceRunning())
    {
        return;
    }
    new wait = Faith_SecondsToNextService();
    if (!s_FamilyMassPending && wait <= FAMILY_MASS_LEAD_SECONDS)
    {
        Families_AssignMass(0);
        s_FamilyMassPending = true;
    }
    else if (s_FamilyMassPending && wait > FAMILY_MASS_LEAD_SECONDS + 120)
    {
        for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
        {
            s_FamilyMassSlots[member] = -1;
        }
        s_FamilyMassPending = false;
        s_FamilyMassVersion++;
    }
}

hook Faith_OnServiceStarted(church)
{
    if (!s_FamilyMassPending)
    {
        Families_AssignMass(church);
    }
    s_FamilyMassPending = false;
    Families_Refresh();
}

hook Faith_OnServiceEnded(church)
{
    #pragma unused church
    for (new member = 0;member < FAMILY_SEED_MEMBERS;member++)
    {
        s_FamilyMassSlots[member] = -1;
    }
    s_FamilyMassPending = false;
    s_FamilyMassVersion++;
    Families_Refresh();
}

forward Families_SeatMember(member,epoch);

public Families_SeatMember(member,epoch)
{
    new actor = Families_GetMemberActor(member);
    if (epoch == s_FamilySeatEpochs[member] && Families_IsEating(member) && Families_GetPlace(member) == FAMILY_PLACE_TABLE && !Actors_IsWalking(actor) && Families_GetViewers(Families_GetMemberFamily(member)) > 0)
    {
        Actors_SetAnim(actor,FAMILY_SIT_LIB,FAMILY_SIT_ANIM,true);
        if (!Actors_IsPlaced(actor) && Actors_Place(actor))
        {
            s_FamilyMembers[member][E_FAMILY_MEMBER_PLACEMENTS]++;
        }
    }
    return 1;
}

hook Actors_OnArrived(index)
{
	new member = Families_GetMemberOfActor(index);

	if (member != -1 && !s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN])
	{
		if (Families_IsPlayerAtSpot(s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0],s_FamilyMembers[member][E_FAMILY_MEMBER_POS][1],s_FamilyMembers[member][E_FAMILY_MEMBER_POS][2],0,0,Families_SpotRange(s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE],s_FamilyMembers[member][E_FAMILY_MEMBER_ACT])))
		{
			Actors_Remove(index);
		}
		else
		{
			Families_ApplyAnim(index,s_FamilyMembers[member][E_FAMILY_MEMBER_ACT],member);
		}
	}

	if (member != -1 && s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN])
	{
		s_FamilyMembers[member][E_FAMILY_MEMBER_GOING_IN] = false;
		Actors_Remove(index);
		s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = FAMILY_PLACE_HOME;
		s_FamilyMembers[member][E_FAMILY_MEMBER_POS][0] = 0.0;
	}
}

hook Actors_OnRespawn(index)
{
	new member = Families_GetMemberOfActor(index);

	if (member != -1)
	{
		s_FamilyMembers[member][E_FAMILY_MEMBER_PLACE] = FAMILY_PLACE_NONE;
	}
}

hook Routine_OnKeyframe(hour,E_HOUR_NAME:name)
{
	#pragma unused hour, name

	Families_Refresh();
}

hook Houses_OnEntered(playerid,house)
{
	#pragma unused playerid

	new family = Families_FindByHouse(house);

	if (family != -1)
	{
		Families_RefreshFamily(family);
	}
}
