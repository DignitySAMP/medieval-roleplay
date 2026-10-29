#define DAYS_STEP (30)
#define DAYS_JITTER (9)
#define DAYS_LEAD_MAX (50)
#define DAYS_SPEED (1.1)
#define DAYS_DETOUR (1.35)
#define DAYS_SICK_PER_MILLE (22)
#define DAYS_SICK_MAX (3)
#define DAYS_SALT (8)
#define DAYS_HARVEST_FROM (221)
#define DAYS_HARVEST_TO (260)
#define DAYS_MASS_LEAD_SECONDS (420)
#define DAYS_MARKET_SETUP (30)
#define DAYS_MARKET_OPEN_HOUR (9)
#define DAYS_MARKET_CLOSE_HOUR (16)
#define DAYS_BEDSIDE (0.95)

enum E_DAYS_KIND
{
	DAYS_KIND_WORK,
	DAYS_KIND_SUNDAY,
	DAYS_KIND_MARKET,
	DAYS_KIND_FEAST,
	DAYS_KIND_RAIN,
	DAYS_KIND_SNOW,
	DAYS_KIND_HARVEST,
	DAYS_KIND_COUNT,
}

enum E_DAYS_STATE
{
	E_DAYS_SPOT:E_DAYS_STATE_SPOT,
	E_FAMILY_ACT:E_DAYS_STATE_ACT,
	E_DAYS_STATE_TARGET,
	E_DAYS_STATE_START,
	E_DAYS_STATE_ROW,
	E_DAYS_STATE_HABIT,
	bool:E_DAYS_STATE_SICK,
	bool:E_DAYS_STATE_HARD,
	bool:E_DAYS_STATE_EVENT,
	E_DAYS_STATE_BEGIN,
	E_DAYS_STATE_ARRIVE,
}

enum E_DAYS_CONTEXT
{
	E_DAYS_CONTEXT_DAY,
	E_DAYS_CONTEXT_WEEKDAY,
	E_SEASON:E_DAYS_CONTEXT_SEASON,
	E_DAYS_CONTEXT_MONTH,
	E_DAYS_CONTEXT_MONTH_DAY,
	E_DAYS_KIND:E_DAYS_CONTEXT_KIND,
	E_DAYS_CONTEXT_MINUTE,
	bool:E_DAYS_CONTEXT_MARKET,
	bool:E_DAYS_CONTEXT_FOUL,
	bool:E_DAYS_CONTEXT_STORM,
}

enum E_DAYS_NOW
{
	E_DAYS_SPOT:E_DAYS_NOW_SPOT,
	E_FAMILY_ACT:E_DAYS_NOW_ACT,
	E_FAMILY_PLACE:E_DAYS_NOW_PLACE,
	E_DAYS_NOW_TARGET,
	E_DAYS_NOW_KEY,
	E_DAYS_NOW_RANK,
	E_DAYS_NOW_COUNT,
	E_DAYS_NOW_HABIT,
	bool:E_DAYS_NOW_EXPLICIT,
	bool:E_DAYS_NOW_SICK,
	bool:E_DAYS_NOW_EVENT,
	bool:E_DAYS_NOW_TRANSIT,
	Float:E_DAYS_NOW_POS[4],
	E_DAYS_NOW_ANIM,
}

new const g_DaysKindNames[_:DAYS_KIND_COUNT][14] = {"workday", "Sunday", "market day", "feast day", "rainy day", "snowy day", "harvest"};
new const g_DaysTagNames[5][8] = {"devout", "forage", "help", "tavern", "wash"};
new const g_DaysSpotWhere[_:DAYS_SPOT_COUNT][28] = {
	"in bed", "at home", "at the family table", "in the yard", "by the door", "in the fields", "in the woods", "by the water",
	"in the square", "at the market", "at the church", "at work", "at the well", "at the wash", "in the garden", "at the tavern",
	"visiting kin", "helping a neighbour", "at the spinning circle", "playing on the green", "at the church lesson", "at the pond",
	"gathering in the woods", "at the sickbed"
};

static s_DaysNow[FAMILY_SEED_MEMBERS][E_DAYS_NOW];
static s_DaysCtx[E_DAYS_CONTEXT];
static s_DaysHabitFirst[FAMILY_SEED_MEMBERS];
static s_DaysHabitCount[FAMILY_SEED_MEMBERS];
static bool:s_DaysIndexed;
static s_DaysSickOverride[FAMILY_SEED_MEMBERS];
static s_DaysWorkshopMode[DAYS_WORKSHOPS] = {-1, ...};
static s_DaysForageDay[FAMILY_SEED_MEMBERS] = {-1, ...};
static s_DaysForageNode[FAMILY_SEED_MEMBERS][2];
static bool:s_DaysMassAssigned;
static s_DaysVersion;
static s_DaysStamp[3];
static bool:s_DaysValid;
static bool:s_DaysIllness = true;

forward Days_Lead(member,E_DAYS_SPOT:fromSpot,fromTarget,E_DAYS_SPOT:spot,target,day);
forward bool:Days_SpotPos(member,E_DAYS_SPOT:spot,target,day,&Float:x,&Float:y,&Float:z);
forward Families_AssignMass(church);
forward bool:Funeral_IsRiteRunning();
forward bool:Days_IsWorkshopPlaced(workshop);
forward bool:Workshops_IsPlaced(site);
forward bool:Workshops_GetSpotPose(spot,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior);
forward bool:Days_ForagePos(hostMember,&Float:x,&Float:y,&Float:z);

stock Days_AnchorMinute(anchor,bool:winter)
{
	if (winter)
	{
		switch (anchor)
		{
			case 0: return 480;
			case 1: return 600;
			case 2: return 720;
			case 3: return 840;
			case 4: return 960;
		}
		return 1200;
	}

	switch (anchor)
	{
		case 0: return 360;
		case 1: return 540;
		case 2: return 660;
		case 3: return 780;
		case 4: return 1080;
	}

	return 1200;
}

stock Days_RowMinute(anchor,offset,bool:winter)
{
	return Days_AnchorMinute(anchor,winter) + offset * DAYS_STEP;
}

stock Days_NameAnchor(E_HOUR_NAME:name)
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

stock bool:Days_IsHarvestDate(month,monthDay)
{
	new ordinal = (month - 1) * CALENDAR_DAYS_PER_MONTH + monthDay;
	return ordinal >= DAYS_HARVEST_FROM && ordinal <= DAYS_HARVEST_TO;
}

stock E_DAYS_KIND:Days_PickKind(weekday,bool:feast,bool:snowing,bool:raining,bool:harvest)
{
	if (feast)
	{
		return DAYS_KIND_FEAST;
	}

	if (weekday == FAMILY_WEEK_SUNDAY)
	{
		return DAYS_KIND_SUNDAY;
	}

	if (snowing)
	{
		return DAYS_KIND_SNOW;
	}

	if (raining)
	{
		return DAYS_KIND_RAIN;
	}

	if (weekday == FAMILY_WEEK_MARKET)
	{
		return DAYS_KIND_MARKET;
	}

	return harvest ? DAYS_KIND_HARVEST : DAYS_KIND_WORK;
}

stock bool:Days_IsIndoorSpot(E_DAYS_SPOT:spot)
{
	switch (spot)
	{
		case DAYS_SPOT_BED, DAYS_SPOT_HOME, DAYS_SPOT_TABLE, DAYS_SPOT_BEDSIDE: return true;
	}

	return false;
}

stock bool:Days_IsHardSpot(E_DAYS_SPOT:spot)
{
	switch (spot)
	{
		case DAYS_SPOT_CHURCH, DAYS_SPOT_MARKET, DAYS_SPOT_LESSON: return true;
	}

	return false;
}

static Days_BuildIndex()
{
	for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
	{
		s_DaysHabitFirst[member] = -1;
		s_DaysHabitCount[member] = 0;
	}

	for (new habit = 0; habit < DAYS_HABITS; habit++)
	{
		new member = g_DaysHabits[habit][E_DAYS_HABIT_MEMBER];

		if (s_DaysHabitFirst[member] == -1)
		{
			s_DaysHabitFirst[member] = habit;
		}

		s_DaysHabitCount[member]++;
	}

	s_DaysIndexed = true;
}

stock Days_GetHabitFirst(member)
{
	if (!s_DaysIndexed)
	{
		Days_BuildIndex();
	}

	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_DaysHabitFirst[member] : -1;
}

stock Days_GetHabitCount(member)
{
	if (!s_DaysIndexed)
	{
		Days_BuildIndex();
	}

	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_DaysHabitCount[member] : 0;
}

stock Days_GetTemplate(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? g_DaysPeople[member][E_DAYS_PERSON_TEMPLATE] : -1;
}

stock Days_GetTemplateName(member,dest[],size = sizeof(dest))
{
	new template = Days_GetTemplate(member);
	if (template >= 0)
	{
		strcopy(dest,g_DaysTemplates[template][E_DAYS_TEMPLATE_NAME],size);
	}
	else
	{
		dest[0] = EOS;
	}
}

stock Days_GetTemplateDescription(member,dest[],size = sizeof(dest))
{
	new template = Days_GetTemplate(member);
	if (template >= 0)
	{
		strcopy(dest,g_DaysTemplates[template][E_DAYS_TEMPLATE_DESC],size);
	}
	else
	{
		dest[0] = EOS;
	}
}

stock Days_GetTemplatePhrase(member,dest[],size = sizeof(dest))
{
	new template = Days_GetTemplate(member);
	if (template >= 0)
	{
		strcopy(dest,g_DaysTemplates[template][E_DAYS_TEMPLATE_PHRASE],size);
	}
	else
	{
		dest[0] = EOS;
	}
}

stock Days_GetTrait(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? g_DaysPeople[member][E_DAYS_PERSON_TRAIT] : 0;
}

stock Days_Hash(member,day,salt)
{
	return Families_PlanHash(member + 1,day,salt);
}

stock bool:Days_IsSickOn(member,day)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		return false;
	}

	if (s_DaysSickOverride[member] == 1)
	{
		return true;
	}

	if (s_DaysSickOverride[member] == 2 || !s_DaysIllness)
	{
		return false;
	}

	for (new back = 0; back < DAYS_SICK_MAX; back++)
	{
		new start = day - back;

		if (Days_Hash(member,start,77) % 1000 < DAYS_SICK_PER_MILLE && Days_Hash(member,start,78) % DAYS_SICK_MAX >= back)
		{
			return true;
		}
	}

	return false;
}

stock Days_SetIllness(bool:on)
{
	s_DaysIllness = on;
	s_DaysVersion++;
}

stock bool:Days_GetIllness()
{
	return s_DaysIllness;
}

stock Days_SetSick(member,value)
{
	if (member >= 0 && member < FAMILY_SEED_MEMBERS)
	{
		s_DaysSickOverride[member] = value;
		s_DaysVersion++;
	}
}

stock Days_GetSickOverride(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_DaysSickOverride[member] : 0;
}

stock Days_FindTender(family,day)
{
	new best = -1;

	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS]; member < last; member++)
	{
		if (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_AGE] < FAMILY_AGE_ADULT || Days_IsSickOn(member,day))
		{
			continue;
		}

		if (best == -1 || (g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX] == 1 && g_FamilyMemberDefs[best][E_FAMILY_MEMBER_DEF_SEX] != 1))
		{
			best = member;
		}
	}

	return best;
}

stock Days_FindSick(family,day)
{
	for (new member = g_FamilyDefs[family][E_FAMILY_DEF_FIRST_MEMBER], last = member + g_FamilyDefs[family][E_FAMILY_DEF_MEMBERS]; member < last; member++)
	{
		if (Days_IsSickOn(member,day))
		{
			return member;
		}
	}

	return -1;
}

stock Days_RowJitter(member,day,row)
{
	return Days_Hash(member,day,row + DAYS_SALT) % (DAYS_JITTER + 1);
}

static Days_SetBed(dstate[E_DAYS_STATE])
{
	dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_BED;
	dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_SLEEP;
	dstate[E_DAYS_STATE_TARGET] = -1;
	dstate[E_DAYS_STATE_START] = 0;
	dstate[E_DAYS_STATE_ROW] = -1;
	dstate[E_DAYS_STATE_HABIT] = -1;
	dstate[E_DAYS_STATE_HARD] = false;
	dstate[E_DAYS_STATE_BEGIN] = 0;
	dstate[E_DAYS_STATE_ARRIVE] = 0;
}

stock Days_SetBase(member,E_DAYS_KIND:kind,minute,bool:winter,day,dstate[E_DAYS_STATE])
{
	new template = Days_GetTemplate(member), set = g_DaysTemplates[template][E_DAYS_TEMPLATE_SETS][_:kind];
	new first = g_DaysSets[set][0], count = g_DaysSets[set][1], found = -1, foundBegin = 0, foundArrive = 0;
	new E_DAYS_SPOT:prevSpot = DAYS_SPOT_BED;

	for (new i = 0; i < count; i++)
	{
		new row = first + i, E_DAYS_SPOT:spot = E_DAYS_SPOT:g_DaysRows[row][E_DAYS_ROW_SPOT];
		new start = Days_RowMinute(g_DaysRows[row][E_DAYS_ROW_ANCHOR],g_DaysRows[row][E_DAYS_ROW_OFFSET],winter), begin, arrive;

		if (Days_IsHardSpot(spot))
		{
			new lead = Days_Lead(member,prevSpot,-1,spot,-1,day);
			begin = start - lead - Days_RowJitter(member,day,row);
			arrive = start;
		}
		else if (spot == DAYS_SPOT_TABLE)
		{
			begin = start;
			arrive = start + Days_Lead(member,prevSpot,-1,spot,-1,day);
		}
		else
		{
			begin = start + Days_RowJitter(member,day,row);
			arrive = begin + Days_Lead(member,prevSpot,-1,spot,-1,day);
		}

		if (begin <= minute)
		{
			found = i;
			foundBegin = begin;
			foundArrive = arrive;
		}

		prevSpot = spot;
	}

	if (found == -1)
	{
		Days_SetBed(dstate);
		return -1;
	}

	new row = first + found, E_DAYS_SPOT:spot = E_DAYS_SPOT:g_DaysRows[row][E_DAYS_ROW_SPOT], E_FAMILY_ACT:act = E_FAMILY_ACT:g_DaysRows[row][E_DAYS_ROW_ACT];

	if (g_DaysRows[row][E_DAYS_ROW_ALT_SPOT] >= 0 && (day + member) % 2 == 1)
	{
		spot = E_DAYS_SPOT:g_DaysRows[row][E_DAYS_ROW_ALT_SPOT];
		act = E_FAMILY_ACT:g_DaysRows[row][E_DAYS_ROW_ALT_ACT];
	}

	dstate[E_DAYS_STATE_SPOT] = spot;
	dstate[E_DAYS_STATE_ACT] = act;
	dstate[E_DAYS_STATE_TARGET] = -1;
	dstate[E_DAYS_STATE_START] = Days_RowMinute(g_DaysRows[row][E_DAYS_ROW_ANCHOR],g_DaysRows[row][E_DAYS_ROW_OFFSET],winter);
	dstate[E_DAYS_STATE_ROW] = row;
	dstate[E_DAYS_STATE_HABIT] = -1;
	dstate[E_DAYS_STATE_HARD] = Days_IsHardSpot(spot);
	dstate[E_DAYS_STATE_BEGIN] = foundBegin;
	dstate[E_DAYS_STATE_ARRIVE] = foundArrive;
	return row;
}

stock bool:Days_HabitApplies(habit,member,E_DAYS_KIND:kind,weekday,E_SEASON:season,day)
{
	if (!(g_DaysHabits[habit][E_DAYS_HABIT_KINDS] & (1 << _:kind)) || !(g_DaysHabits[habit][E_DAYS_HABIT_WEEKDAYS] & (1 << weekday)) || !(g_DaysHabits[habit][E_DAYS_HABIT_SEASONS] & (1 << _:season)))
	{
		return false;
	}

	new parity = g_DaysHabits[habit][E_DAYS_HABIT_PARITY];

	if (parity >= 0 && ((day / g_DaysHabits[habit][E_DAYS_HABIT_PERIOD]) + parity) % 2 != 0)
	{
		return false;
	}

	return Days_Hash(member,day,habit + 500) % 100 < g_DaysHabits[habit][E_DAYS_HABIT_CHANCE];
}

stock Days_Resolve(member,const ctx[E_DAYS_CONTEXT],dstate[E_DAYS_STATE])
{
	new day = ctx[E_DAYS_CONTEXT_DAY], minute = ctx[E_DAYS_CONTEXT_MINUTE], bool:winter = ctx[E_DAYS_CONTEXT_SEASON] == SEASON_WINTER;
	dstate[E_DAYS_STATE_HABIT] = -1;
	dstate[E_DAYS_STATE_SICK] = false;
	dstate[E_DAYS_STATE_HARD] = false;
	dstate[E_DAYS_STATE_EVENT] = false;

	if (Days_IsSickOn(member,day))
	{
		Days_SetBed(dstate);
		dstate[E_DAYS_STATE_SICK] = true;
		return;
	}

	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], sick = Days_FindSick(family,day);

	if (sick != -1 && Days_FindTender(family,day) == member)
	{
		new const tend[3][2] = {{1, 0}, {3, 1}, {4, -1}};

		for (new i = 0; i < 3; i++)
		{
			new from = Days_RowMinute(tend[i][0],tend[i][1],winter);

			if (minute >= from && minute < from + DAYS_STEP)
			{
				dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_BEDSIDE;
				dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_STAND;
				dstate[E_DAYS_STATE_TARGET] = sick;
				dstate[E_DAYS_STATE_START] = from;
				dstate[E_DAYS_STATE_ROW] = -1;
				return;
			}
		}
	}

	Days_SetBase(member,ctx[E_DAYS_CONTEXT_KIND],minute,winter,day,dstate);
	new first = Days_GetHabitFirst(member);

	if (first == -1)
	{
		return;
	}

	for (new habit = first, last = first + s_DaysHabitCount[member]; habit < last; habit++)
	{
		if (!Days_HabitApplies(habit,member,ctx[E_DAYS_CONTEXT_KIND],ctx[E_DAYS_CONTEXT_WEEKDAY],ctx[E_DAYS_CONTEXT_SEASON],day))
		{
			continue;
		}

		new E_DAYS_SPOT:spot = E_DAYS_SPOT:g_DaysHabits[habit][E_DAYS_HABIT_SPOT];
		new from = Days_RowMinute(g_DaysHabits[habit][E_DAYS_HABIT_FROM_ANCHOR],g_DaysHabits[habit][E_DAYS_HABIT_FROM_OFFSET],winter);
		new to = Days_RowMinute(g_DaysHabits[habit][E_DAYS_HABIT_TO_ANCHOR],g_DaysHabits[habit][E_DAYS_HABIT_TO_OFFSET],winter);
		new begin = from;

		if (Days_IsHardSpot(spot))
		{
			begin = from - Days_Lead(member,DAYS_SPOT_HOME,-1,spot,g_DaysHabits[habit][E_DAYS_HABIT_TARGET],day);
		}

		if (minute >= begin && minute < to)
		{
			dstate[E_DAYS_STATE_SPOT] = spot;
			dstate[E_DAYS_STATE_ACT] = E_FAMILY_ACT:g_DaysHabits[habit][E_DAYS_HABIT_ACT];
			dstate[E_DAYS_STATE_TARGET] = g_DaysHabits[habit][E_DAYS_HABIT_TARGET];
			dstate[E_DAYS_STATE_START] = from;
			dstate[E_DAYS_STATE_HABIT] = habit;
			dstate[E_DAYS_STATE_HARD] = Days_IsHardSpot(spot);
			dstate[E_DAYS_STATE_BEGIN] = begin;
			dstate[E_DAYS_STATE_ARRIVE] = Days_IsHardSpot(spot) ? from : begin + Days_Lead(member,DAYS_SPOT_HOME,-1,spot,g_DaysHabits[habit][E_DAYS_HABIT_TARGET],day);
			return;
		}
	}
}

stock Days_FillContext(ctx[E_DAYS_CONTEXT])
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	ctx[E_DAYS_CONTEXT_DAY] = Calendar_DaysSinceEpoch(day,month,year);
	ctx[E_DAYS_CONTEXT_WEEKDAY] = Families_Weekday();
	ctx[E_DAYS_CONTEXT_SEASON] = Calendar_GetSeason();
	ctx[E_DAYS_CONTEXT_MONTH] = month;
	ctx[E_DAYS_CONTEXT_MONTH_DAY] = day;
	ctx[E_DAYS_CONTEXT_MINUTE] = Calendar_GetMinuteOfDay();
	ctx[E_DAYS_CONTEXT_FOUL] = Families_IsFoul();
	ctx[E_DAYS_CONTEXT_STORM] = ctx[E_DAYS_CONTEXT_FOUL] && Calendar_GetWeather() == 8;
	new bool:snowing = ctx[E_DAYS_CONTEXT_FOUL] && Weather_IsSnowing();
	ctx[E_DAYS_CONTEXT_KIND] = Days_PickKind(ctx[E_DAYS_CONTEXT_WEEKDAY],Faith_GetLiturgicalSeason() == FAITH_SEASON_FEAST,snowing,ctx[E_DAYS_CONTEXT_FOUL] && !snowing,Days_IsHarvestDate(month,day));
	new minute = ctx[E_DAYS_CONTEXT_MINUTE];
	ctx[E_DAYS_CONTEXT_MARKET] = Market_IsOpen() || (ctx[E_DAYS_CONTEXT_WEEKDAY] == FAMILY_WEEK_MARKET && minute >= DAYS_MARKET_OPEN_HOUR * 60 - DAYS_MARKET_SETUP && minute < DAYS_MARKET_CLOSE_HOUR * 60 + DAYS_MARKET_SETUP);
}

stock Days_AtAnchor(const ctx[E_DAYS_CONTEXT],E_HOUR_NAME:name,newCtx[E_DAYS_CONTEXT])
{
	newCtx = ctx;

	new anchor = Days_NameAnchor(name);
	newCtx[E_DAYS_CONTEXT_MINUTE] = anchor == -1 ? 120 : Days_AnchorMinute(anchor,ctx[E_DAYS_CONTEXT_SEASON] == SEASON_WINTER) + 1;
}

static Days_ApplyEvents(member,const ctx[E_DAYS_CONTEXT],dstate[E_DAYS_STATE])
{
	if (dstate[E_DAYS_STATE_SICK])
	{
		return;
	}

	new E_DAYS_SPOT:spot = dstate[E_DAYS_STATE_SPOT];

	if (Families_IsTableOpen(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY]) && Families_IsEating(member))
	{
		dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_TABLE;
		dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_EAT;
		dstate[E_DAYS_STATE_TARGET] = -1;
		dstate[E_DAYS_STATE_EVENT] = true;
		dstate[E_DAYS_STATE_ARRIVE] = 0;
		return;
	}

	if (Families_GetMassSlot(member) != -1)
	{
		dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_CHURCH;
		dstate[E_DAYS_STATE_ACT] = Faith_IsServiceRunning() ? FAMILY_ACT_SIT : FAMILY_ACT_STAND;
		dstate[E_DAYS_STATE_TARGET] = -1;
		dstate[E_DAYS_STATE_EVENT] = true;
		return;
	}

	if (Funeral_IsRiteRunning() && !Days_IsIndoorSpot(spot) && spot != DAYS_SPOT_CHURCH && Days_AnchorMinute(5,ctx[E_DAYS_CONTEXT_SEASON] == SEASON_WINTER) > ctx[E_DAYS_CONTEXT_MINUTE])
	{
		dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_CHURCH;
		dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_STAND;
		dstate[E_DAYS_STATE_TARGET] = -1;
		dstate[E_DAYS_STATE_EVENT] = true;
		return;
	}

	if (ctx[E_DAYS_CONTEXT_FOUL] && !Days_IsIndoorSpot(spot) && spot != DAYS_SPOT_CHURCH && spot != DAYS_SPOT_LESSON && (ctx[E_DAYS_CONTEXT_STORM] || ctx[E_DAYS_CONTEXT_KIND] == DAYS_KIND_SUNDAY || ctx[E_DAYS_CONTEXT_KIND] == DAYS_KIND_FEAST))
	{
		dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_HOME;
		dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_CHORE;
		dstate[E_DAYS_STATE_TARGET] = -1;
		dstate[E_DAYS_STATE_EVENT] = true;
	}

	if (dstate[E_DAYS_STATE_SPOT] == DAYS_SPOT_MARKET && !ctx[E_DAYS_CONTEXT_MARKET])
	{
		dstate[E_DAYS_STATE_SPOT] = DAYS_SPOT_SQUARE;
		dstate[E_DAYS_STATE_ACT] = FAMILY_ACT_STAND;
		dstate[E_DAYS_STATE_EVENT] = true;
	}
}

static const g_DaysPlaceIndex[8] = {0, 1, 2, 3, 4, 5, 6, 7};

stock bool:Days_FamilyPlace(family,placeIndex,&Float:x,&Float:y,&Float:z)
{
	if (family < 0 || family >= FAMILY_SEED_HOUSEHOLDS || placeIndex < 0 || placeIndex > 7)
	{
		return false;
	}

	x = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][placeIndex * 3];
	y = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][placeIndex * 3 + 1];
	z = g_FamilyDefs[family][E_FAMILY_DEF_PLACES][placeIndex * 3 + 2];
	return x != 0.0 || y != 0.0;
}

stock Days_SlotColumn(placeIndex)
{
	switch (placeIndex)
	{
		case 0: return 0;
		case 1: return 1;
		case 5: return 2;
		case 7: return 3;
	}

	return -1;
}

stock Days_WorkSpotOf(member,day)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS || g_DaysWorkAssign[member][0] < 0)
	{
		return -1;
	}

	new spot = (day + member) % 2 == 0 ? g_DaysWorkAssign[member][0] : g_DaysWorkAssign[member][1];
	return Days_IsWorkshopPlaced(g_DaysWorkSpots[spot][E_DAYS_WORKSPOT_SITE]) ? spot : -1;
}

stock Days_SetWorkshopPlaced(workshop,bool:placed)
{
	if (workshop >= 0 && workshop < DAYS_WORKSHOPS)
	{
		s_DaysWorkshopMode[workshop] = placed ? 1 : 0;
		s_DaysVersion++;
	}
}

stock Days_SetWorkshopAuto(workshop)
{
	if (workshop >= 0 && workshop < DAYS_WORKSHOPS)
	{
		s_DaysWorkshopMode[workshop] = -1;
		s_DaysVersion++;
	}
}

stock bool:Days_IsWorkshopPlaced(workshop)
{
	if (workshop < 0 || workshop >= DAYS_WORKSHOPS)
	{
		return false;
	}

	return s_DaysWorkshopMode[workshop] == -1 ? Workshops_IsPlaced(workshop) : s_DaysWorkshopMode[workshop] == 1;
}

stock bool:Days_WorkSpotPose(member,day,&Float:x,&Float:y,&Float:z,&Float:a,&bool:indoor)
{
	new workSpot = Days_WorkSpotOf(member,day), world, interior;

	if (workSpot == -1 || !Workshops_GetSpotPose(workSpot,x,y,z,a,world,interior))
	{
		return false;
	}

	indoor = g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_INDOOR];
	return true;
}

stock bool:Days_GetIndoorWorkPose(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
	new bool:indoor;

	if (member < 0 || member >= FAMILY_SEED_MEMBERS || s_DaysNow[member][E_DAYS_NOW_SPOT] != DAYS_SPOT_WORK || !Days_WorkSpotPose(member,s_DaysCtx[E_DAYS_CONTEXT_DAY],x,y,z,a,indoor))
	{
		return false;
	}

	return indoor;
}

stock Days_WorkFallbackPlace(family,&E_DAYS_SPOT:spot)
{
	new workplace = g_DaysFamilyWork[family];
	spot = workplace == -1 ? DAYS_SPOT_YARD : E_DAYS_SPOT:g_DaysWorkplaces[workplace][E_DAYS_WORKPLACE_FALLBACK];
}

stock bool:Days_SpotPos(member,E_DAYS_SPOT:spot,target,day,&Float:x,&Float:y,&Float:z)
{
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], village = g_DaysPeople[member][E_DAYS_PERSON_VILLAGE], Float:a;
	new place = -1, host = family;

	switch (spot)
	{
		case DAYS_SPOT_BED, DAYS_SPOT_HOME, DAYS_SPOT_TABLE, DAYS_SPOT_BEDSIDE:
		{
			Families_DoorPos(member,x,y,z,a);
			return true;
		}
		case DAYS_SPOT_YARD, DAYS_SPOT_GARDEN: place = 0;
		case DAYS_SPOT_DOORSTEP: place = 1;
		case DAYS_SPOT_FIELD: place = 2;
		case DAYS_SPOT_SQUARE: place = 3;
		case DAYS_SPOT_MARKET: place = 4;
		case DAYS_SPOT_CHURCH, DAYS_SPOT_LESSON:
		{
			place = 5;
			host = target >= 0 && spot == DAYS_SPOT_CHURCH ? target : family;
		}
		case DAYS_SPOT_FOREST, DAYS_SPOT_FORAGE:
		{
			place = 6;
			host = target >= 0 && spot == DAYS_SPOT_FORAGE ? g_FamilyMemberDefs[target][E_FAMILY_MEMBER_DEF_FAMILY] : family;
		}
		case DAYS_SPOT_WATER, DAYS_SPOT_POND: place = 7;
		case DAYS_SPOT_WASH:
		{
			place = 7;
			host = target >= 0 ? target : family;
		}
		case DAYS_SPOT_WORK:
		{
			new bool:indoor;

			if (Days_WorkSpotPose(member,day,x,y,z,a,indoor))
			{
				if (indoor)
				{
					Families_DoorPos(member,x,y,z,a);
				}

				return true;
			}

			new E_DAYS_SPOT:fallback;
			Days_WorkFallbackPlace(family,fallback);
			return fallback != DAYS_SPOT_WORK && Days_SpotPos(member,fallback,-1,day,x,y,z);
		}
		case DAYS_SPOT_WELL, DAYS_SPOT_PLAY:
		{
			new kind = spot == DAYS_SPOT_WELL ? 0 : 1;
			x = g_DaysCommons[village][kind][0];
			y = g_DaysCommons[village][kind][1];
			z = g_DaysCommons[village][kind][2];
			return x != 0.0 || y != 0.0;
		}
		case DAYS_SPOT_TAVERN, DAYS_SPOT_KIN:
		{
			place = 1;
			host = target >= 0 ? target : (spot == DAYS_SPOT_KIN ? g_DaysPeople[member][E_DAYS_PERSON_KIN] : family);
		}
		case DAYS_SPOT_HELP:
		{
			place = 0;
			host = target >= 0 ? target : family;
		}
		case DAYS_SPOT_CIRCLE:
		{
			place = 1;
			host = Days_CircleHost(member,day);
		}
		default: return false;
	}

	return place != -1 && host >= 0 && Days_FamilyPlace(host,place,x,y,z);
}

stock Days_CircleHost(member,day)
{
	new group = g_DaysPeople[member][E_DAYS_PERSON_CIRCLE];

	if (group < 0)
	{
		return -1;
	}

	new count = g_DaysCircles[group][6];
	return count > 0 ? g_DaysCircles[group][day % count] : -1;
}

stock Days_Lead(member,E_DAYS_SPOT:fromSpot,fromTarget,E_DAYS_SPOT:spot,target,day)
{
	new Float:fx, Float:fy, Float:fz, Float:tx, Float:ty, Float:tz;

	if (!Days_SpotPos(member,fromSpot,fromTarget,day,fx,fy,fz) || !Days_SpotPos(member,spot,target,day,tx,ty,tz))
	{
		return 0;
	}

	new Float:seconds = VectorSize(tx - fx,ty - fy,0.0) * DAYS_DETOUR / DAYS_SPEED, Float:perMinute = float(Calendar_MsPerMinute()) / 1000.0;
	return clamp(floatround(seconds / perMinute,floatround_ceil) + 1,0,DAYS_LEAD_MAX);
}

stock Days_TravelMinutes(member,E_DAYS_SPOT:fromSpot,E_DAYS_SPOT:spot,day)
{
	return Days_Lead(member,fromSpot,-1,spot,-1,day);
}

static Days_Normalise(E_FAMILY_PLACE:place,&E_FAMILY_ACT:act)
{
	if (place == FAMILY_PLACE_HOME)
	{
		switch (act)
		{
			case FAMILY_ACT_SPIN: act = FAMILY_ACT_REST;
			case FAMILY_ACT_WASH, FAMILY_ACT_DRAW: act = FAMILY_ACT_CHORE;
			case FAMILY_ACT_CHAT, FAMILY_ACT_DRINK: act = FAMILY_ACT_STAND;
			case FAMILY_ACT_TEND, FAMILY_ACT_FISH, FAMILY_ACT_PLAY: act = FAMILY_ACT_CHORE;
		}
	}
}

stock Days_Map(member,const ctx[E_DAYS_CONTEXT],const dstate[E_DAYS_STATE],&E_FAMILY_PLACE:place,&E_FAMILY_ACT:act,&bool:explicit,&key)
{
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], E_DAYS_SPOT:spot = dstate[E_DAYS_STATE_SPOT], target = dstate[E_DAYS_STATE_TARGET], host = -1;
	act = dstate[E_DAYS_STATE_ACT];
	explicit = false;
	key = -1;

	switch (spot)
	{
		case DAYS_SPOT_BED:
		{
			place = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_BED] != -1 ? FAMILY_PLACE_BED : FAMILY_PLACE_NONE;
			act = FAMILY_ACT_SLEEP;
		}
		case DAYS_SPOT_BEDSIDE:
		{
			place = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_BED] != -1 ? FAMILY_PLACE_BED : FAMILY_PLACE_HOME;
			act = FAMILY_ACT_STAND;
		}
		case DAYS_SPOT_HOME:
		{
			place = FAMILY_PLACE_HOME;
		}
		case DAYS_SPOT_TABLE:
		{
			if (Families_IsTableOpen(family) && Families_IsEating(member))
			{
				place = FAMILY_PLACE_TABLE;
				act = FAMILY_ACT_EAT;
			}
			else
			{
				place = FAMILY_PLACE_HOME;
				act = FAMILY_ACT_HEARTH;
			}
		}
		case DAYS_SPOT_YARD, DAYS_SPOT_GARDEN: place = FAMILY_PLACE_YARD;
		case DAYS_SPOT_DOORSTEP: place = FAMILY_PLACE_DOORSTEP;
		case DAYS_SPOT_FIELD: place = FAMILY_PLACE_FIELD;
		case DAYS_SPOT_FOREST: place = FAMILY_PLACE_FOREST;
		case DAYS_SPOT_WATER, DAYS_SPOT_POND: place = FAMILY_PLACE_WATER;
		case DAYS_SPOT_SQUARE: place = FAMILY_PLACE_SQUARE;
		case DAYS_SPOT_MARKET: place = FAMILY_PLACE_MARKET;
		case DAYS_SPOT_CHURCH:
		{
			place = FAMILY_PLACE_CHURCH;
			explicit = target >= 0;
			host = target;
		}
		case DAYS_SPOT_LESSON:
		{
			place = FAMILY_PLACE_CHURCH;
		}
		case DAYS_SPOT_WORK:
		{
			new workSpot = Days_WorkSpotOf(member,ctx[E_DAYS_CONTEXT_DAY]);

			if (workSpot != -1)
			{
				place = g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_INDOOR] ? FAMILY_PLACE_HOME : FAMILY_PLACE_YARD;
				explicit = !g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_INDOOR];
				host = -2 - workSpot;
				if (g_DaysWorkAssign[member][2] >= 0)
				{
					act = E_FAMILY_ACT:g_DaysWorkAssign[member][2];
				}
			}
			else
			{
				new E_DAYS_SPOT:fallback;
				Days_WorkFallbackPlace(family,fallback);
				new role = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_ROLE];

				if (ctx[E_DAYS_CONTEXT_FOUL] && fallback != DAYS_SPOT_HOME && role != _:ACTOR_ROLE_FORESTER && role != _:ACTOR_ROLE_FISHER)
				{
					fallback = DAYS_SPOT_HOME;
				}

				switch (fallback)
				{
					case DAYS_SPOT_HOME: place = FAMILY_PLACE_HOME;
					case DAYS_SPOT_FIELD: place = FAMILY_PLACE_FIELD;
					case DAYS_SPOT_FOREST: place = FAMILY_PLACE_FOREST;
					case DAYS_SPOT_WATER: place = FAMILY_PLACE_WATER;
					case DAYS_SPOT_MARKET: place = FAMILY_PLACE_MARKET;
					case DAYS_SPOT_CHURCH: place = FAMILY_PLACE_CHURCH;
					default: place = FAMILY_PLACE_YARD;
				}
			}
		}
		case DAYS_SPOT_WELL, DAYS_SPOT_PLAY:
		{
			place = FAMILY_PLACE_SQUARE;
			explicit = true;
			host = g_DaysPeople[member][E_DAYS_PERSON_VILLAGE];
		}
		case DAYS_SPOT_TAVERN:
		{
			place = FAMILY_PLACE_DOORSTEP;
			explicit = target >= 0;
			host = target;
		}
		case DAYS_SPOT_KIN:
		{
			place = FAMILY_PLACE_DOORSTEP;
			host = target >= 0 ? target : g_DaysPeople[member][E_DAYS_PERSON_KIN];

			if (target < 0 && (host < 0 || ((ctx[E_DAYS_CONTEXT_DAY] / 7) + g_DaysPeople[member][E_DAYS_PERSON_KIN_PARITY]) % 2 != 0))
			{
				host = -1;
				act = FAMILY_ACT_REST;
			}
			else
			{
				explicit = true;
			}
		}
		case DAYS_SPOT_HELP:
		{
			place = FAMILY_PLACE_YARD;
			explicit = target >= 0;
			host = target;
		}
		case DAYS_SPOT_CIRCLE:
		{
			place = FAMILY_PLACE_DOORSTEP;
			host = Days_CircleHost(member,ctx[E_DAYS_CONTEXT_DAY]);

			if (host >= 0)
			{
				explicit = true;
			}
			else
			{
				place = FAMILY_PLACE_HOME;
				act = FAMILY_ACT_REST;
			}
		}
		case DAYS_SPOT_WASH:
		{
			place = FAMILY_PLACE_WATER;
			explicit = target >= 0;
			host = target;
		}
		case DAYS_SPOT_FORAGE:
		{
			place = FAMILY_PLACE_FOREST;
			explicit = true;
			host = target;
		}
		default: place = FAMILY_PLACE_HOME;
	}

	if (explicit)
	{
		new Float:x, Float:y, Float:z;

		if (!Days_SpotPos(member,spot,target,ctx[E_DAYS_CONTEXT_DAY],x,y,z) && host != -1 && host > -2)
		{
			explicit = false;
		}
	}

	if (explicit && spot == DAYS_SPOT_FORAGE)
	{
		new Float:fx, Float:fy, Float:fz;

		if (!Days_ForagePos(host,fx,fy,fz))
		{
			explicit = false;
			act = FAMILY_ACT_STAND;
		}
	}

	if (!explicit && spot == DAYS_SPOT_TAVERN)
	{
		place = FAMILY_PLACE_SQUARE;
	}

	if (explicit)
	{
		key = _:spot * 1000 + (host < -1 ? 900 + (-2 - host) : host);
	}

	Days_Normalise(place,act);
}

stock bool:Days_ForagePos(hostMember,&Float:x,&Float:y,&Float:z)
{
	if (hostMember < 0 || hostMember >= FAMILY_SEED_MEMBERS)
	{
		return false;
	}

	new slot = s_DaysCtx[E_DAYS_CONTEXT_MINUTE] < 12 * 60 ? 0 : 1;

	if (s_DaysForageDay[hostMember] != s_DaysCtx[E_DAYS_CONTEXT_DAY])
	{
		s_DaysForageDay[hostMember] = s_DaysCtx[E_DAYS_CONTEXT_DAY];
		s_DaysForageNode[hostMember][0] = Families_FindPlanNode(hostMember,s_DaysCtx[E_DAYS_CONTEXT_DAY],0,false);
		s_DaysForageNode[hostMember][1] = Families_FindPlanNode(hostMember,s_DaysCtx[E_DAYS_CONTEXT_DAY],1,true);
	}

	new node = s_DaysForageNode[hostMember][slot];
	return node != -1 && Families_IsPlanNode(node,slot == 1) && Work_GetNodePos(node,x,y,z);
}

stock Days_Compute(member,const ctx[E_DAYS_CONTEXT],bool:events,dstate[E_DAYS_STATE],&E_FAMILY_PLACE:place,&E_FAMILY_ACT:act,&bool:explicit,&key)
{
	Days_Resolve(member,ctx,dstate);

	if (events)
	{
		Days_ApplyEvents(member,ctx,dstate);
	}

	Days_Map(member,ctx,dstate,place,act,explicit,key);

	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY];

	if (_:place < FAMILY_OUTDOOR_PLACES && (!Families_GoesOut(family) || (!explicit && !Families_HasPlace(family,place))))
	{
		act = place == FAMILY_PLACE_CHURCH ? FAMILY_ACT_PRAY : FAMILY_ACT_CHORE;
		place = FAMILY_PLACE_HOME;
		explicit = false;
		key = -1;
	}
}

stock Days_Invalidate()
{
	s_DaysVersion++;
}

stock Days_Want(member,E_HOUR_NAME:name,&E_FAMILY_PLACE:place,&E_FAMILY_ACT:act,&bool:explicit)
{
	act = FAMILY_ACT_STAND;
	explicit = false;

	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		place = FAMILY_PLACE_NONE;
		return;
	}

	new actor = Families_GetMemberActor(member);

	if (actor == -1 || Actors_IsDead(actor))
	{
		place = FAMILY_PLACE_NONE;
		return;
	}

	if (name == HOUR_NONE)
	{
		Days_EnsureFresh();
		place = s_DaysNow[member][E_DAYS_NOW_PLACE];
		act = s_DaysNow[member][E_DAYS_NOW_ACT];
		explicit = s_DaysNow[member][E_DAYS_NOW_EXPLICIT];
		return;
	}

	new ctx[E_DAYS_CONTEXT], anchored[E_DAYS_CONTEXT], dstate[E_DAYS_STATE], key;
	Days_FillContext(ctx);
	Days_AtAnchor(ctx,name,anchored);
	Days_Compute(member,anchored,false,dstate,place,act,explicit,key);
}

static Days_CountRanks()
{
	for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
	{
		s_DaysNow[member][E_DAYS_NOW_RANK] = 0;
		s_DaysNow[member][E_DAYS_NOW_COUNT] = 1;

		if (s_DaysNow[member][E_DAYS_NOW_KEY] == -1)
		{
			continue;
		}

		new rank = 0, count = 0;

		for (new other = 0; other < FAMILY_SEED_MEMBERS; other++)
		{
			if (s_DaysNow[other][E_DAYS_NOW_KEY] == s_DaysNow[member][E_DAYS_NOW_KEY])
			{
				count++;

				if (other < member)
				{
					rank++;
				}
			}
		}

		s_DaysNow[member][E_DAYS_NOW_RANK] = rank;
		s_DaysNow[member][E_DAYS_NOW_COUNT] = count;
	}
}

stock Days_Refresh()
{
	Days_FillContext(s_DaysCtx);

	for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
	{
		new dstate[E_DAYS_STATE], E_FAMILY_PLACE:place, E_FAMILY_ACT:act, bool:explicit, key, actor = Families_GetMemberActor(member);

		if (actor == -1 || Actors_IsDead(actor))
		{
			s_DaysNow[member][E_DAYS_NOW_PLACE] = FAMILY_PLACE_NONE;
			s_DaysNow[member][E_DAYS_NOW_KEY] = -1;
			s_DaysNow[member][E_DAYS_NOW_EXPLICIT] = false;
			s_DaysNow[member][E_DAYS_NOW_SPOT] = DAYS_SPOT_BED;
			continue;
		}

		Days_Compute(member,s_DaysCtx,true,dstate,place,act,explicit,key);
		s_DaysNow[member][E_DAYS_NOW_SPOT] = dstate[E_DAYS_STATE_SPOT];
		s_DaysNow[member][E_DAYS_NOW_ACT] = act;
		s_DaysNow[member][E_DAYS_NOW_PLACE] = place;
		s_DaysNow[member][E_DAYS_NOW_TARGET] = dstate[E_DAYS_STATE_TARGET];
		s_DaysNow[member][E_DAYS_NOW_KEY] = key;
		s_DaysNow[member][E_DAYS_NOW_HABIT] = dstate[E_DAYS_STATE_HABIT];
		s_DaysNow[member][E_DAYS_NOW_EXPLICIT] = explicit;
		s_DaysNow[member][E_DAYS_NOW_SICK] = dstate[E_DAYS_STATE_SICK];
		s_DaysNow[member][E_DAYS_NOW_EVENT] = dstate[E_DAYS_STATE_EVENT];
		s_DaysNow[member][E_DAYS_NOW_TRANSIT] = !dstate[E_DAYS_STATE_EVENT] && !dstate[E_DAYS_STATE_SICK] && s_DaysCtx[E_DAYS_CONTEXT_MINUTE] < dstate[E_DAYS_STATE_ARRIVE] && s_DaysCtx[E_DAYS_CONTEXT_MINUTE] >= dstate[E_DAYS_STATE_BEGIN];
	}

	Days_CountRanks();
}

static Days_Signature(signature[3])
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	signature[0] = Calendar_DaysSinceEpoch(day,month,year) * 1440 + Calendar_GetMinuteOfDay();
	signature[1] = (Families_IsFoul() ? 1 : 0) | (Weather_IsSnowing() ? 2 : 0) | (Calendar_GetWeather() == 8 ? 4 : 0) | (Market_IsOpen() ? 8 : 0) | (Faith_IsServiceRunning() ? 16 : 0) | (Funeral_IsRiteRunning() ? 32 : 0) | (Faith_GetLiturgicalSeason() == FAITH_SEASON_FEAST ? 64 : 0) | (Families_GetMassVersion() << 8);
	signature[2] = s_DaysVersion;
}

stock Days_EnsureFresh()
{
	new signature[3];
	Days_Signature(signature);

	if (s_DaysValid && signature[0] == s_DaysStamp[0] && signature[1] == s_DaysStamp[1] && signature[2] == s_DaysStamp[2])
	{
		return;
	}

	Days_Refresh();
	s_DaysStamp = signature;
	s_DaysValid = true;
}

stock bool:Days_IsExplicit(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS && s_DaysNow[member][E_DAYS_NOW_EXPLICIT];
}

stock bool:Days_InTransit(member)
{
	Days_EnsureFresh();
	return member >= 0 && member < FAMILY_SEED_MEMBERS && s_DaysNow[member][E_DAYS_NOW_TRANSIT];
}

stock bool:Days_IsSickNow(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS && Days_IsSickOn(member,s_DaysCtx[E_DAYS_CONTEXT_DAY]);
}

stock Days_GetKind()
{
	return _:s_DaysCtx[E_DAYS_CONTEXT_KIND];
}

stock Days_GetNowSpot(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? (_:s_DaysNow[member][E_DAYS_NOW_SPOT]) : (-1);
}

stock Days_GetNowTarget(member)
{
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? (s_DaysNow[member][E_DAYS_NOW_TARGET]) : (-1);
}

stock Days_GetNowRank(member,&count = 0)
{
	count = member >= 0 && member < FAMILY_SEED_MEMBERS ? s_DaysNow[member][E_DAYS_NOW_COUNT] : 0;
	return member >= 0 && member < FAMILY_SEED_MEMBERS ? s_DaysNow[member][E_DAYS_NOW_RANK] : 0;
}

stock Days_NeedsStandingRoom(member)
{
	return Days_IsExplicit(member);
}

static Days_SlotOffset(const offsets[][2],count,index,&Float:dx,&Float:dy)
{
	dx = offsets[index % count][0];
	dy = offsets[index % count][1];
}

stock bool:Days_GetDestination(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS || !s_DaysNow[member][E_DAYS_NOW_EXPLICIT])
	{
		return false;
	}

	new E_DAYS_SPOT:spot = s_DaysNow[member][E_DAYS_NOW_SPOT], target = s_DaysNow[member][E_DAYS_NOW_TARGET], rank = s_DaysNow[member][E_DAYS_NOW_RANK];
	new family = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY], village = g_DaysPeople[member][E_DAYS_PERSON_VILLAGE];

	if (spot == DAYS_SPOT_WORK)
	{
		new bool:indoor;
		return Days_WorkSpotPose(member,s_DaysCtx[E_DAYS_CONTEXT_DAY],x,y,z,a,indoor) && !indoor;
	}

	if (spot == DAYS_SPOT_FORAGE)
	{
		new Float:angle = float((member * 137) % 360);

		if (!Days_ForagePos(target,x,y,z))
		{
			return false;
		}

		x += floatcos(angle,degrees) * 0.8;
		y += floatsin(angle,degrees) * 0.8;
		a = angle + 90.0;
		return true;
	}

	new Float:ax, Float:ay, Float:az, Float:dx, Float:dy;

	if (!Days_SpotPos(member,spot,target,s_DaysCtx[E_DAYS_CONTEXT_DAY],ax,ay,az))
	{
		return false;
	}

	if (spot == DAYS_SPOT_WELL || spot == DAYS_SPOT_PLAY)
	{
		new kind = spot == DAYS_SPOT_WELL ? 0 : 1;

		new count = g_DaysCommonSlotCount[village][kind];

		if (count == 0)
		{
			return false;
		}

		dx = g_DaysCommonSlots[village][kind][rank % count][0];
		dy = g_DaysCommonSlots[village][kind][rank % count][1];

		x = ax + dx;
		y = ay + dy;
		z = az;
		a = Util_NormalizeAngle(atan2(ay - y,ax - x) - 90.0);
		return true;
	}

	new host = family, placeIndex = 1;

	switch (spot)
	{
		case DAYS_SPOT_TAVERN, DAYS_SPOT_KIN:
		{
			host = target >= 0 ? target : (spot == DAYS_SPOT_KIN ? g_DaysPeople[member][E_DAYS_PERSON_KIN] : family);
		}
		case DAYS_SPOT_CIRCLE:
		{
			host = Days_CircleHost(member,s_DaysCtx[E_DAYS_CONTEXT_DAY]);
		}
		case DAYS_SPOT_CHURCH:
		{
			placeIndex = 5;
			host = target >= 0 ? target : family;
		}
		case DAYS_SPOT_HELP:
		{
			placeIndex = 0;
			host = target;
		}
		case DAYS_SPOT_WASH:
		{
			placeIndex = 7;
			host = target;
		}
	}

	new column = Days_SlotColumn(placeIndex);

	if (host < 0 || host >= FAMILY_SEED_HOUSEHOLDS || column == -1)
	{
		return false;
	}

	new count = g_DaysSlotCount[host][column], index;

	if (count == 0)
	{
		return false;
	}

	index = rank % count;
	dx = g_DaysFamilySlots[host][column][index][0];
	dy = g_DaysFamilySlots[host][column][index][1];
	x = ax + dx;
	y = ay + dy;
	z = az;

	if (index == 0)
	{
		a = g_FamilyDefs[host][E_FAMILY_DEF_FACING][placeIndex];
	}
	else
	{
		a = Util_NormalizeAngle(atan2(ay + g_DaysFamilySlots[host][column][0][1] - y,ax + g_DaysFamilySlots[host][column][0][0] - x) - 90.0);
	}

	return true;
}

stock bool:Days_GetWorkAnim(member,lib[],libSize,name[],nameSize,&bool:loop)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS || s_DaysNow[member][E_DAYS_NOW_SPOT] != DAYS_SPOT_WORK)
	{
		return false;
	}

	new workSpot = Days_WorkSpotOf(member,s_DaysCtx[E_DAYS_CONTEXT_DAY]);

	if (workSpot == -1)
	{
		return false;
	}

	strcopy(lib,g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_LIB],libSize);
	strcopy(name,g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_ANIM],nameSize);
	loop = g_DaysWorkSpots[workSpot][E_DAYS_WORKSPOT_LOOP];
	return true;
}

stock bool:Days_BedsidePos(member,&Float:x,&Float:y,&Float:z,&Float:a)
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS || s_DaysNow[member][E_DAYS_NOW_SPOT] != DAYS_SPOT_BEDSIDE)
	{
		return false;
	}

	new sick = s_DaysNow[member][E_DAYS_NOW_TARGET];

	if (sick < 0 || !Families_BedPos(sick,x,y,z,a))
	{
		return false;
	}

	x += floatcos(a,degrees) * DAYS_BEDSIDE;
	y += floatsin(a,degrees) * DAYS_BEDSIDE;
	a = Util_NormalizeAngle(a + 90.0);
	return true;
}

stock bool:Days_AtTable(member,E_FAMILY_MEAL:meal)
{
	new ctx[E_DAYS_CONTEXT], anchored[E_DAYS_CONTEXT], dstate[E_DAYS_STATE];
	Days_FillContext(ctx);
	Days_AtAnchor(ctx,meal == FAMILY_MEAL_DINNER ? HOUR_SEXT : HOUR_VESPERS,anchored);
	Days_Resolve(member,anchored,dstate);
	return dstate[E_DAYS_STATE_SPOT] == DAYS_SPOT_TABLE;
}

stock Days_ClockPhrase(minute,bool:winter,dest[],size = sizeof(dest))
{
	new const names[6][9] = {"Prime", "Terce", "Sext", "Nones", "Vespers", "Compline"};
	new best = -1, bestGap = 100000;

	for (new anchor = 0; anchor < 6; anchor++)
	{
		new gap = Days_AnchorMinute(anchor,winter) - minute;

		if (gap < 0)
		{
			gap = -gap;
		}

		if (gap < bestGap)
		{
			bestGap = gap;
			best = anchor;
		}
	}

	if (bestGap <= 60)
	{
		format(dest,size,"%s%s",bestGap <= 15 ? ("") : (Days_AnchorMinute(best,winter) > minute ? ("before ") : ("after ")),names[best]);
		return;
	}

	strcopy(dest,minute < Days_AnchorMinute(0,winter) ? "dawn" : "dusk",size);
}

stock Days_DescribeSpot(member,E_DAYS_SPOT:spot,target,dest[],size = sizeof(dest))
{
	#pragma unused target
	switch (spot)
	{
		case DAYS_SPOT_WORK:
		{
			new phrase[40];
			Days_GetTemplatePhrase(member,phrase);
			strcopy(dest,phrase[0] == EOS ? "at work" : phrase,size);
		}
		case DAYS_SPOT_KIN: strcopy(dest,"visiting kin",size);
		default: strcopy(dest,g_DaysSpotWhere[_:spot],size);
	}
}

stock Days_FormatWhere(member,dest[],size = sizeof(dest))
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		dest[0] = EOS;
		return;
	}

	new ctx[E_DAYS_CONTEXT], dstate[E_DAYS_STATE];
	Days_FillContext(ctx);
	Days_Resolve(member,ctx,dstate);
	Days_ApplyEvents(member,ctx,dstate);
	new now[48], later[48], E_DAYS_SPOT:spot = dstate[E_DAYS_STATE_SPOT], bool:winter = ctx[E_DAYS_CONTEXT_SEASON] == SEASON_WINTER;
	new bool:female = g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_SEX] == 1, he[4], his[4];
	strcopy(he,female ? "She" : "He");
	strcopy(his,female ? "her" : "his");

	if (dstate[E_DAYS_STATE_SICK])
	{
		format(dest,size,"%s's ill in bed at home.",he);

		if (Days_FindTender(g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_FAMILY],ctx[E_DAYS_CONTEXT_DAY]) != -1)
		{
			strcat(dest,female ? (" Her family is looking after her.") : (" His family is looking after him."),size);
		}

		return;
	}

	if (spot == DAYS_SPOT_BED)
	{
		format(dest,size,"%s's asleep in bed at home.",he);
		return;
	}

	new sick = dstate[E_DAYS_STATE_TARGET];

	if (spot == DAYS_SPOT_BEDSIDE && sick >= 0 && sick < FAMILY_SEED_MEMBERS)
	{
		format(dest,size,"%s's at home looking after %s, who's ill.",he,g_FamilyMemberDefs[sick][E_FAMILY_MEMBER_DEF_NAME]);
		return;
	}

	Days_DescribeSpot(member,spot,dstate[E_DAYS_STATE_TARGET],now);

	new probe[E_DAYS_CONTEXT], next[E_DAYS_STATE], when = -1;

	probe = ctx;

	for (new minute = ctx[E_DAYS_CONTEXT_MINUTE] + 15; minute < 1440 && when == -1; minute += 15)
	{
		probe[E_DAYS_CONTEXT_MINUTE] = minute;
		Days_Resolve(member,probe,next);

		if (next[E_DAYS_STATE_SPOT] != spot && next[E_DAYS_STATE_SPOT] != DAYS_SPOT_TABLE && next[E_DAYS_STATE_SPOT] != DAYS_SPOT_BED)
		{
			when = minute;
			Days_DescribeSpot(member,next[E_DAYS_STATE_SPOT],next[E_DAYS_STATE_TARGET],later);
		}
	}

	new at = strfind(now,"the mother");

	if (at != -1)
	{
		strdel(now,at,at + 3);
		strins(now,his,at);
	}

	if ((at = strfind(later,"the mother")) != -1)
	{
		strdel(later,at,at + 3);
		strins(later,his,at);
	}

	if (when == -1)
	{
		format(dest,size,"%s's %s for the rest of the day.",he,now);
		return;
	}

	new until[24];
	Days_ClockPhrase(when,winter,until);

	if (strfind(until,"before ") == 0)
	{
		strins(until,"just ",0);
	}

	format(dest,size,"%s's %s until %s, then usually %s.",he,now,until,later);
}

stock Days_FormatPlanAnswer(member,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		return;
	}

	if (Days_IsSickNow(member))
	{
		strcopy(dest,"I'm ill. They've put me to bed until I'm better.",size);
		return;
	}

	new ctx[E_DAYS_CONTEXT], dstate[E_DAYS_STATE], E_DAYS_SPOT:spot, phrase[48], target;
	Days_FillContext(ctx);
	Days_Resolve(member,ctx,dstate);
	Days_ApplyEvents(member,ctx,dstate);
	spot = dstate[E_DAYS_STATE_SPOT];
	target = dstate[E_DAYS_STATE_TARGET];

	if ((spot == DAYS_SPOT_HOME || spot == DAYS_SPOT_FIELD || spot == DAYS_SPOT_WORK) && dstate[E_DAYS_STATE_ACT] != FAMILY_ACT_PRAY && Families_FormatVoice(member,_:FAMILY_VOICE_PLAN,dest,size))
	{
		return;
	}

	new const dayName[_:DAYS_KIND_COUNT][24] = {"", " It's Sunday.", " It's market day.", " It's a feast day.", "", "", " It's harvest time."};

	switch (spot)
	{
		case DAYS_SPOT_BED: strcopy(phrase,"off to bed");
		case DAYS_SPOT_TABLE: strcopy(phrase,"eating with my family");
		case DAYS_SPOT_MARKET: strcopy(phrase,"at Talmberg market");
		case DAYS_SPOT_FORAGE: strcopy(phrase,"looking for herbs and mushrooms in the woods");
		case DAYS_SPOT_BEDSIDE:
		{
			if (target >= 0 && target < FAMILY_SEED_MEMBERS)
			{
				format(dest,size,"I'm looking after %s. %s's ill.",g_FamilyMemberDefs[target][E_FAMILY_MEMBER_DEF_NAME],g_FamilyMemberDefs[target][E_FAMILY_MEMBER_DEF_SEX] == 1 ? ("She") : ("He"));
				return;
			}

			strcopy(phrase,"looking after someone who's ill");
		}
		default:
		{
			if (spot == DAYS_SPOT_HOME && dstate[E_DAYS_STATE_ACT] == FAMILY_ACT_PRAY)
			{
				strcopy(phrase,"saying my prayers at home");
			}
			else
			{
				Days_DescribeSpot(member,spot,target,phrase);
			}
		}
	}

	new at = strfind(phrase,"the mother");

	if (at != -1)
	{
		strdel(phrase,at,at + 3);
		strins(phrase,"my",at);
	}

	format(dest,size,"I'm %s.%s",phrase,dayName[spot == DAYS_SPOT_BED ? 0 : _:ctx[E_DAYS_CONTEXT_KIND]]);
}

stock Days_WhereTargets(member,out[],max = sizeof(out))
{
	if (member < 0 || member >= FAMILY_SEED_MEMBERS || max <= 0)
	{
		return 0;
	}

	new village = g_DaysPeople[member][E_DAYS_PERSON_VILLAGE], found[FAMILY_SEED_MEMBERS], services = 0, total = 0;

	for (new pass = 0; pass < 2; pass++)
	{
		for (new other = 0; other < FAMILY_SEED_MEMBERS; other++)
		{
			new role = g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_ROLE], actor = Families_GetMemberActor(other);

			if (other == member || g_DaysPeople[other][E_DAYS_PERSON_VILLAGE] != village || g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_AGE] < FAMILY_AGE_ADULT || !strcmp(g_FamilyMemberDefs[other][E_FAMILY_MEMBER_DEF_WHO],"wife") || actor == -1 || Actors_IsDead(actor))
			{
				continue;
			}

			if (pass == 0 ? (role != _:ACTOR_ROLE_BAKER && role != _:ACTOR_ROLE_MERCHANT && role != _:ACTOR_ROLE_MILLER && role != _:ACTOR_ROLE_CLERK && role != _:ACTOR_ROLE_HEALER) : (role != _:ACTOR_ROLE_CRAFT))
			{
				continue;
			}

			new template = Days_GetTemplate(other), bool:seen = template < 0 || strfind(g_DaysTemplates[template][E_DAYS_TEMPLATE_NAME],"(") != -1;

			for (new i = 0; i < total && !seen; i++)
			{
				seen = !strcmp(g_DaysTemplates[Days_GetTemplate(found[i])][E_DAYS_TEMPLATE_NAME],g_DaysTemplates[template][E_DAYS_TEMPLATE_NAME]);
			}

			if (!seen)
			{
				found[total++] = other;
			}
		}

		if (pass == 0)
		{
			services = total;
		}
	}

	new count = 0, crafts = total - services;

	for (new i = 0; i < services && count < max; i++)
	{
		out[count++] = found[i];
	}

	for (new i = 0; i < crafts && count < max; i++)
	{
		out[count++] = found[services + (member + i) % crafts];
	}

	return count;
}

CMD<ADMIN_LEVEL_TRIAL>:days(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], rest[32];

	if (sscanf(params,"s[12]S()[32]",action,rest))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"/days kind | who [name] | where [member] | sick [member] [on|off|auto] | workshops [on|off] | dump | list");
		return 1;
	}

	if (!strcmp(action,"kind",true))
	{
		new ctx[E_DAYS_CONTEXT];
		Days_FillContext(ctx);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Villager Days: %s, minute %d, weekday %d, season %d, market %s, foul %s.",g_DaysKindNames[_:ctx[E_DAYS_CONTEXT_KIND]],ctx[E_DAYS_CONTEXT_MINUTE],ctx[E_DAYS_CONTEXT_WEEKDAY],_:ctx[E_DAYS_CONTEXT_SEASON],ctx[E_DAYS_CONTEXT_MARKET] ? ("open") : ("closed"),ctx[E_DAYS_CONTEXT_FOUL] ? ("yes") : ("no")));
		return 1;
	}

	if (!strcmp(action,"workshops",true))
	{
		new mode = !strcmp(rest,"off",true) ? 0 : (!strcmp(rest,"auto",true) ? -1 : 1);

		for (new shop = 0; shop < DAYS_WORKSHOPS; shop++)
		{
			if (mode == -1)
			{
				Days_SetWorkshopAuto(shop);
			}
			else
			{
				Days_SetWorkshopPlaced(shop,mode == 1);
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,mode == -1 ? "Workshop work spots follow the placed workshops again." : (mode == 1 ? "Workshop work spots are on: the craftsmen work at the workshop spots." : "Workshop work spots are off: the craftsmen work at home and in their yards."));
		Families_Refresh();
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		new count[_:DAYS_SPOT_COUNT];

		for (new member = 0; member < FAMILY_SEED_MEMBERS; member++)
		{
			if (Days_GetNowSpot(member) >= 0)
			{
				count[Days_GetNowSpot(member)]++;
			}
		}

		new line[160];

		for (new spot = 0; spot < _:DAYS_SPOT_COUNT; spot++)
		{
			if (count[spot] > 0)
			{
				format(line,sizeof(line),"%s%s%d %s",line,line[0] == EOS ? ("") : (", "),count[spot],g_DaysSpotWhere[spot]);
			}
		}

		SendClientMessage(playerid,0xFFFFFFFF,line);
		return 1;
	}

	new member = -1;

	if (rest[0] >= '0' && rest[0] <= '9')
	{
		member = strval(rest);
	}
	else
	{
		new actor = Actors_FindNear(playerid,6.0,false);
		member = Families_GetMemberOfActor(actor);

		if (member == -1 && rest[0] != EOS)
		{
			for (new i = 0; i < FAMILY_SEED_MEMBERS; i++)
			{
				if (!strcmp(g_FamilyMemberDefs[i][E_FAMILY_MEMBER_DEF_NAME],rest,true))
				{
					member = i;
					break;
				}
			}
		}
	}

	if (!strcmp(action,"dump",true))
	{
		new clock[E_DAYS_CONTEXT];
		Days_FillContext(clock);
		printf("DAYSNOW minute=%d weekday=%d kind=%d season=%d market=%d foul=%d day=%d",clock[E_DAYS_CONTEXT_MINUTE],clock[E_DAYS_CONTEXT_WEEKDAY],_:clock[E_DAYS_CONTEXT_KIND],_:clock[E_DAYS_CONTEXT_SEASON],clock[E_DAYS_CONTEXT_MARKET] ? 1 : 0,clock[E_DAYS_CONTEXT_FOUL] ? 1 : 0,clock[E_DAYS_CONTEXT_DAY]);

		for (new i = 0; i < FAMILY_SEED_MEMBERS; i++)
		{
			new Float:x, Float:y, Float:z, actor = Families_GetMemberActor(i);
			Actors_GetPos(actor,x,y,z);
			printf("DAYS %d %s %.2f %.2f %.2f place=%d spot=%d act=%d placed=%d walking=%d",i,g_FamilyMemberDefs[i][E_FAMILY_MEMBER_DEF_NAME],x,y,z,_:s_DaysNow[i][E_DAYS_NOW_PLACE],_:s_DaysNow[i][E_DAYS_NOW_SPOT],_:s_DaysNow[i][E_DAYS_NOW_ACT],Actors_IsPlaced(actor),Actors_IsWalking(actor));
		}

		SendClientMessage(playerid,0xFFFFFFFF,"Positions written to the server log.");
		return 1;
	}

	if (member < 0 || member >= FAMILY_SEED_MEMBERS)
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Stand within 6 m of a villager, or give a member number or first name.");
		return 1;
	}

	if (!strcmp(action,"sick",true))
	{
		new value[8], extra[16];
		sscanf(rest,"s[16]S(auto)[8]",extra,value);
		Days_SetSick(member,!strcmp(value,"on",true) ? 1 : (!strcmp(value,"off",true) ? 2 : 0));
		Families_Refresh();
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s is %s today.",g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_NAME],Days_IsSickNow(member) ? ("ill in bed") : ("well")));
		return 1;
	}

	new name[32], desc[168], answer[160];
	Days_GetTemplateName(member,name);
	Days_GetTemplateDescription(member,desc);
	Days_FormatWhere(member,answer);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s %s (%d): %s - %s",g_FamilyMemberDefs[member][E_FAMILY_MEMBER_DEF_NAME],name,member,desc,answer));
	return 1;
}

#include <pp-hooks>

hook Actors_OnKilled(index,killerid)
{
	#pragma unused index, killerid
	Days_Invalidate();
}

hook Actors_OnRespawn(index)
{
	#pragma unused index
	Days_Invalidate();
}
