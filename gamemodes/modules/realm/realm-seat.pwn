#define REALM_PANEL_WIDTH (340.0)
#define REALM_COLLECT_MS (5000)
#define REALM_POINT_REACH (3.0)
#define REALM_TOLL_REACH (6.0)
#define REALM_TOLL_OPEN_MS (10000)
#define REALM_TOLL_HOLD_RANGE (12.0)
#define REALM_TOLL_HOLD_MS (3000)
#define REALM_TOLL_WALKER_RANGE (4.0)
#define REALM_TOLL_CLEAR_RANGE (1.2)
#define REALM_TOLL_BAR_FROM (-0.75)
#define REALM_TOLL_BAR_TO (3.8)
#define REALM_TOLL_CLEAR_MS (1000)
#define REALM_TOLL_PASS_MS (60000)
#define REALM_TOLL_CLEAR_SPOTS (12.0)
#define REALM_TOLL_LINE_REACH (34.0)
#define REALM_TOLL_LINE_DEPTH (15.0)
#define REALM_TOLL_LINE_Z (12.0)
#define REALM_TOLL_LINE_DEADBAND (0.3)
#define REALM_TOLL_LINE_GAP_MS (2000)
#define REALM_TOLL_LINE_JUMP (12.0)
#define REALM_WATCH_MS (20000)

enum
{
	REALM_PICK_BOOKS = 1,
	REALM_PICK_POLICY,
	REALM_PICK_BOUNDS,
	REALM_PICK_DECREES,
	REALM_PICK_LEVY,
	REALM_PICK_APPOINT,
	REALM_PICK_DELIVER,
}

static s_RealmSteward = -1;
static s_RealmCarried[MAX_PLAYERS];
static s_RealmCollecting[MAX_PLAYERS] = {-1, ...};
static s_RealmPrompt[MAX_PLAYERS] = {-1, ...};
static s_RealmInfobox[MAX_PLAYERS];
static STREAMER_TAG_OBJECT:s_RealmTollBar[REALM_SEED_TOLLS + 1];
static s_RealmTollOpenUntil[REALM_SEED_TOLLS + 1];
static s_RealmTollHeld[REALM_SEED_TOLLS + 1] = {INVALID_PLAYER_ID, ...};
static s_RealmTollHeldUntil[REALM_SEED_TOLLS + 1];
static s_RealmTollKeeper[REALM_SEED_TOLLS + 1] = {-1, ...};
static bool:s_RealmTollCoachPaid[REALM_SEED_TOLLS + 1];
static STREAMER_TAG_OBJECT:s_RealmTollBooth[REALM_SEED_TOLLS + 1];
static bool:s_RealmTollHirePaid[REALM_SEED_TOLLS + 1][COACH_HIRES];
static const s_RealmTollKeeperNames[][24] = {"Vavrinec Mytny", "Bohus Celny", "Jakub Branny"};
static s_RealmTollPassUntil[MAX_PLAYERS];
static s_RealmTollSideOf[MAX_PLAYERS] = {-1, ...};
static s_RealmTollSideSign[MAX_PLAYERS];
static s_RealmTollSideAt[MAX_PLAYERS];
static Float:s_RealmTollSidePos[MAX_PLAYERS][2];
static s_RealmDarkNight[MAX_PLAYERS];
static s_RealmLevySeason = -1;

forward Task:Realm_LoadCarried(playerid,characterid);
forward bool:Realm_AskText(playerid,const title[],const prompt[],dest[],size);

stock Realm_GetSteward()
{
	return s_RealmSteward;
}

stock Realm_SetCarried(playerid,coin)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_RealmCarried[playerid] = max(coin,0);
	}
}

stock Realm_GetCarried(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_RealmCarried[playerid] : 0;
}

stock Realm_PolicyText(policy,value,dest[],size = sizeof(dest))
{
	if (!strcmp(g_RealmPolicyDefs[policy][E_RP_UNIT],"pfennig"))
	{
		Economy_Format(value,dest,size);
	}
	else if (!strcmp(g_RealmPolicyDefs[policy][E_RP_UNIT],"off/on"))
	{
		strcopy(dest,value != 0 ? ("on") : ("off"),size);
	}
	else if (policy == REALM_POLICY_WEAPONS)
	{
		switch (value)
		{
			case 1: strcopy(dest,"sheathed only",size);
			case 2: strcopy(dest,"none in town",size);
			default: strcopy(dest,"carried openly",size);
		}
	}
	else if (policy == REALM_POLICY_MULTURE)
	{
		format(dest,size,"one part in %d",value > 0 ? 1000 / value : 0);
	}
	else
	{
		format(dest,size,"%d %s",value,g_RealmPolicyDefs[policy][E_RP_UNIT]);
	}
}

static Realm_Post(const title[],const body[])
{
	Notices_Post(NOTICE_TAB_REALM,0,title,body,gettime(),gettime() + 7 * 86400);
}

stock Realm_PlaceSteward()
{
	if (g_RealmSeat[0] == 0.0 && g_RealmSeat[1] == 0.0)
	{
		return -1;
	}

	new skins = Skins_CountStarter(0);
	s_RealmSteward = Actors_Register("realm:steward",ACTOR_ROLE_VILLAGER,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,4 % skins) : 1,"Ondrej Spravce","Steward of the county");

	if (s_RealmSteward != -1)
	{
		Actors_SetPlace(s_RealmSteward,g_RealmSeat[0],g_RealmSeat[1],g_RealmSeat[2] + 1.0,g_RealmSeat[3],0,0);
		Actors_Place(s_RealmSteward);
	}

	return s_RealmSteward;
}

stock Realm_TollFrame(toll,Float:x,Float:y,&Float:along,&Float:across)
{
	new Float:dx = floatcos(g_RealmTollDefs[toll][3],degrees), Float:dy = floatsin(g_RealmTollDefs[toll][3],degrees);
	along = (x - g_RealmTollDefs[toll][0]) * dx + (y - g_RealmTollDefs[toll][1]) * dy;
	across = (x - g_RealmTollDefs[toll][0]) * dy - (y - g_RealmTollDefs[toll][1]) * dx;
}

stock Realm_TollPoint(toll,Float:along,Float:across,&Float:x,&Float:y)
{
	new Float:dx = floatcos(g_RealmTollDefs[toll][3],degrees), Float:dy = floatsin(g_RealmTollDefs[toll][3],degrees);
	x = g_RealmTollDefs[toll][0] + dx * along + dy * across;
	y = g_RealmTollDefs[toll][1] + dy * along - dx * across;
}

static Float:Realm_TollRoadAlong(toll)
{
	new Float:along, Float:across;
	Realm_TollFrame(toll,g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5],along,across);
	return along;
}

static Realm_PlaceTollBooth(toll)
{
	s_RealmTollBooth[toll] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

	if (g_RealmTollBoothKinds[toll] == 0)
	{
		return;
	}

	s_RealmTollBooth[toll] = Nearby_CreateDynamicObject(g_RealmTollBoothKinds[toll] == 2 ? MODEL_YARD_TOLL_BOOTH_PLAIN : MODEL_YARD_TOLL_BOOTH,g_RealmTollBooths[toll][0],g_RealmTollBooths[toll][1],g_RealmTollBooths[toll][2],0.0,0.0,g_RealmTollBooths[toll][3],0,0,-1,200.0);
}

stock STREAMER_TAG_OBJECT:Realm_GetTollBooth(toll)
{
	return toll >= 0 && toll < REALM_SEED_TOLLS ? s_RealmTollBooth[toll] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Realm_PlaceTollKeeper(toll)
{
	new skins = Skins_CountStarter(0), name = toll % sizeof(s_RealmTollKeeperNames);
	s_RealmTollKeeper[toll] = Actors_Register(sprintf("realm:tollkeeper%d",toll),ACTOR_ROLE_VILLAGER,ACTOR_KIND_STATIC,0,skins > 0 ? Skins_GetStarter(0,(5 + toll * 4) % skins) : 1,s_RealmTollKeeperNames[name],"Toll keeper");

	if (s_RealmTollKeeper[toll] == -1)
	{
		return;
	}

	Actors_SetPlace(s_RealmTollKeeper[toll],g_RealmTollKeepers[toll][0],g_RealmTollKeepers[toll][1],g_RealmTollKeepers[toll][2] + 1.0,g_RealmTollKeepers[toll][3],0,0);
	Actors_Place(s_RealmTollKeeper[toll]);
}

static Realm_MarkCoachToll(toll)
{
	for (new i = 0;i + 1 < ROADS_COACH_POINTS;i++)
	{
		new Float:along, Float:across, Float:nextAlong, Float:nextAcross;
		Realm_TollFrame(toll,g_RoadsCoachRoute[i][0],g_RoadsCoachRoute[i][1],along,across);
		Realm_TollFrame(toll,g_RoadsCoachRoute[i + 1][0],g_RoadsCoachRoute[i + 1][1],nextAlong,nextAcross);

		if ((across >= 0.0) != (nextAcross >= 0.0) && floatabs((along + nextAlong) / 2.0 - Realm_TollRoadAlong(toll)) < REALM_TOLL_HOLD_RANGE)
		{
			Coach_AddTollPoint(i + 1);
		}
	}
}

stock Realm_PlaceTolls()
{
	for (new toll = 0;toll < REALM_SEED_TOLLS;toll++)
	{
		s_RealmTollBar[toll] = Nearby_CreateDynamicObject(MODEL_VILLAGE_TOLL_BAR_DOWN,g_RealmTollDefs[toll][0],g_RealmTollDefs[toll][1],g_RealmTollDefs[toll][2],0.0,0.0,g_RealmTollDefs[toll][3],0,0,-1,150.0);
		s_RealmTollOpenUntil[toll] = 0;
		Realm_PlaceTollBooth(toll);
		Realm_PlaceTollKeeper(toll);
		Realm_MarkCoachToll(toll);
	}

	return REALM_SEED_TOLLS;
}

stock Realm_GetTollKeeper(toll)
{
	return toll >= 0 && toll < REALM_SEED_TOLLS ? s_RealmTollKeeper[toll] : -1;
}

static bool:Realm_KeeperWatching(toll)
{
	new keeper = s_RealmTollKeeper[toll];
	return Actors_IsPlaced(keeper) && !Actors_IsDead(keeper);
}

static Realm_KeeperSays(toll,const text[])
{
	if (Realm_KeeperWatching(toll))
	{
		Actors_Say(s_RealmTollKeeper[toll],text);
	}
}

stock bool:Realm_IsTollExempt(playerid)
{
	return Law_IsGuard(playerid) || Realm_IsRuler(playerid);
}

stock bool:Realm_HasTollPass(playerid)
{
	return Util_IsValidPlayer(playerid) && GetTickCount() < s_RealmTollPassUntil[playerid];
}

stock bool:Realm_OwesToll(playerid)
{
	return Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL) > 0 && !Realm_IsTollExempt(playerid) && !Realm_HasTollPass(playerid) && Carts_GetSeat(playerid) == -1;
}

stock Realm_DepositTreasury(coin)
{
	new treasury = Realm_GetTreasury(), counts[COIN_TIER_COUNT];

	if (coin <= 0 || treasury == INVALID_CONTAINER_ID)
	{
		return 0;
	}

	Economy_Split(coin,counts);

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Container_Add(treasury,ITEM_KIND_COIN,tier,counts[tier]);
		}
	}

	return coin;
}

stock Realm_CoachPaysToll(toll)
{
	if (toll < 0 || toll >= REALM_SEED_TOLLS)
	{
		return 0;
	}

	new coin = Realm_DepositTreasury(Coach_PayTolls(Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL)));

	if (coin > 0)
	{
		Realm_KeeperSays(toll,"Thank you, coachman. Safe road to you.");
	}

	return coin;
}

stock bool:Realm_HirerPaysToll(playerid,toll)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid) || toll < 0 || toll >= REALM_SEED_TOLLS)
	{
		return false;
	}

	new fee = Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL), money[24];
	s_RealmTollPassUntil[playerid] = GetTickCount() + REALM_TOLL_PASS_MS;

	if (fee <= 0 || Realm_IsTollExempt(playerid))
	{
		Gui_Notify(playerid,"The toll keeper waves your coach through without a toll.");
		return true;
	}

	Economy_Format(fee,money);

	if (Economy_Pay(playerid,fee,INVALID_CONTAINER_ID,"toll") != PAY_OK)
	{
		Gui_Notify(playerid,sprintf("You can't pay the toll keeper %s for your coach. Your coachman drives on, and that's toll evasion.",money));
		Realm_KeeperSays(toll,"Hey! That coach didn't pay the toll. The guards will hear of this!");
		Law_Commit(playerid,LAW_CRIME_TOLL,INVALID_PLAYER_ID,Realm_KeeperWatching(toll) ? 1 : 0);
		return false;
	}

	Realm_AddDues(REALM_COUNTY,Realm_VillageAt(g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5]),fee);
	Gui_Notify(playerid,sprintf("You pay the toll keeper %s for your coach, and the bar goes up.",money));
	Realm_KeeperSays(toll,"Thank you. Pass, and God keep you on the road.");
	return true;
}

stock Realm_TollDodged(playerid,toll)
{
	new Float:x, Float:y, Float:z, keeper = s_RealmTollKeeper[toll], seen = Realm_KeeperWatching(toll) ? 1 : 0;
	GetPlayerPos(playerid,x,y,z);
	Realm_KeeperSays(toll,"Hey, you there! You didn't pay the toll. The guards will hear of this!");
	Gui_Notify(playerid,"You crossed the toll line without paying the toll keeper. That's toll evasion, a crime in this county.");
	new witnesses = Law_Commit(playerid,LAW_CRIME_TOLL,INVALID_PLAYER_ID,seen + Actors_CountWitnesses(x,y,z,0,ACTORS_WITNESS_RANGE,keeper));
	Log_Info("realm","toll evasion by player %d at %s, %d witnesses",playerid,g_RealmTollNames[toll],witnesses);
	return witnesses;
}

static Realm_TollWatch(playerid,tick)
{
	new Float:x, Float:y, Float:z;

	if (!Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || !GetPlayerPos(playerid,x,y,z))
	{
		s_RealmTollSideOf[playerid] = -1;
		return;
	}

	for (new toll = 0;toll < REALM_SEED_TOLLS;toll++)
	{
		new Float:along, Float:across;
		Realm_TollFrame(toll,x,y,along,across);

		if (floatabs(along - Realm_TollRoadAlong(toll)) > REALM_TOLL_LINE_REACH || floatabs(across) > REALM_TOLL_LINE_DEPTH || floatabs(z - g_RealmTollDefs[toll][6]) > REALM_TOLL_LINE_Z)
		{
			continue;
		}

		new side = across > REALM_TOLL_LINE_DEADBAND ? 1 : (across < -REALM_TOLL_LINE_DEADBAND ? -1 : 0);

		if (s_RealmTollSideOf[playerid] == toll && tick - s_RealmTollSideAt[playerid] <= REALM_TOLL_LINE_GAP_MS && VectorSize(x - s_RealmTollSidePos[playerid][0],y - s_RealmTollSidePos[playerid][1],0.0) < REALM_TOLL_LINE_JUMP)
		{
			if (side != 0 && s_RealmTollSideSign[playerid] != 0 && side != s_RealmTollSideSign[playerid] && Realm_OwesToll(playerid))
			{
				Realm_TollDodged(playerid,toll);
			}
		}
		else
		{
			s_RealmTollSideSign[playerid] = 0;
		}

		s_RealmTollSideOf[playerid] = toll;
		s_RealmTollSideAt[playerid] = tick;
		s_RealmTollSidePos[playerid][0] = x;
		s_RealmTollSidePos[playerid][1] = y;

		if (side != 0)
		{
			s_RealmTollSideSign[playerid] = side;
		}

		return;
	}

	s_RealmTollSideOf[playerid] = -1;
}

stock bool:Realm_IsTollOpen(toll)
{
	return toll >= 0 && toll < REALM_SEED_TOLLS && GetTickCount() < s_RealmTollOpenUntil[toll];
}

static Realm_SetTollBar(toll,bool:up)
{
	new STREAMER_TAG_OBJECT:old = s_RealmTollBar[toll];
	s_RealmTollBar[toll] = CreateDynamicObject(up ? MODEL_VILLAGE_TOLL_BAR_UP : MODEL_VILLAGE_TOLL_BAR_DOWN,g_RealmTollDefs[toll][0],g_RealmTollDefs[toll][1],g_RealmTollDefs[toll][2],0.0,0.0,g_RealmTollDefs[toll][3],0,0,-1,150.0);

	if (IsValidDynamicObject(old))
	{
		DestroyDynamicObject(old);
	}

	Nearby_StreamObjectsAt(g_RealmTollDefs[toll][0],g_RealmTollDefs[toll][1],g_RealmTollDefs[toll][2],0,0,150.0);
}

static Realm_OpenToll(toll)
{
	new bool:wasOpen = Realm_IsTollOpen(toll);
	s_RealmTollOpenUntil[toll] = GetTickCount() + REALM_TOLL_OPEN_MS;

	if (!wasOpen)
	{
		Realm_SetTollBar(toll,true);
	}
}

static Float:Realm_BarDistance(toll,Float:x,Float:y)
{
	new Float:dx = floatcos(g_RealmTollDefs[toll][3],degrees), Float:dy = floatsin(g_RealmTollDefs[toll][3],degrees);
	new Float:along = (x - g_RealmTollDefs[toll][0]) * dx + (y - g_RealmTollDefs[toll][1]) * dy;

	if (along < REALM_TOLL_BAR_FROM)
	{
		along = REALM_TOLL_BAR_FROM;
	}
	else if (along > REALM_TOLL_BAR_TO)
	{
		along = REALM_TOLL_BAR_TO;
	}

	return VectorSize(x - (g_RealmTollDefs[toll][0] + dx * along),y - (g_RealmTollDefs[toll][1] + dy * along),0.0);
}

static bool:Realm_RiderNearToll(riderid,toll,Float:range)
{
	new Float:x, Float:y, Float:z, Float:a;
	return riderid != INVALID_PLAYER_ID && Rider_GetPos(riderid,x,y,z,a) && Realm_BarDistance(toll,x,y) < range;
}

static bool:Realm_WalkerNearToll(toll,Float:range)
{
	new peds[16], count = GetPedestriansInRange(g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5],g_RealmTollDefs[toll][6],REALM_TOLL_BAR_TO + range,peds);

	for (new i = 0;i < count;i++)
	{
		new kind = GetPedestrianKind(peds[i]), Float:x, Float:y, Float:z;

		if (kind == WALKERS_KIND_ACTOR && GetPedestrianPos(peds[i],x,y,z) && Realm_BarDistance(toll,x,y) < range)
		{
			return true;
		}
	}

	return false;
}

static bool:Realm_TollIsClear(toll)
{
	foreach (new playerid : Player)
	{
		new Float:x, Float:y, Float:z;

		if (!IsPlayerNPC(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerPos(playerid,x,y,z) && floatabs(z - g_RealmTollDefs[toll][6]) < 4.0 && Realm_BarDistance(toll,x,y) < REALM_TOLL_CLEAR_RANGE)
		{
			return false;
		}
	}

	for (new h = -1;h < COACH_HIRES;h++)
	{
		if (Realm_RiderNearToll(h == -1 ? Coach_GetRider() : Coach_GetHireRider(h),toll,REALM_TOLL_CLEAR_RANGE * 3.0))
		{
			return false;
		}
	}

	return !Realm_WalkerNearToll(toll,REALM_TOLL_CLEAR_RANGE);
}

static Realm_TollTraffic(toll,tick)
{
	new coach = Coach_GetRider();

	if (Realm_RiderNearToll(coach,toll,REALM_TOLL_HOLD_RANGE))
	{
		if (!s_RealmTollCoachPaid[toll])
		{
			s_RealmTollCoachPaid[toll] = true;
			Realm_CoachPaysToll(toll);
		}
	}
	else if (!Realm_RiderNearToll(coach,toll,REALM_TOLL_HOLD_RANGE * 2.0))
	{
		s_RealmTollCoachPaid[toll] = false;
	}

	for (new h = 0;h < COACH_HIRES;h++)
	{
		new hired = Coach_GetHireRider(h);

		if (Realm_RiderNearToll(hired,toll,REALM_TOLL_HOLD_RANGE))
		{
			if (!s_RealmTollHirePaid[toll][h])
			{
				s_RealmTollHirePaid[toll][h] = true;

				if (!Coach_IsHireReturning(h))
				{
					Realm_HirerPaysToll(Coach_GetHireOwner(h),toll);
				}
			}
		}
		else if (!Realm_RiderNearToll(hired,toll,REALM_TOLL_HOLD_RANGE * 2.0))
		{
			s_RealmTollHirePaid[toll][h] = false;
		}
	}

	if (s_RealmTollHeld[toll] != INVALID_PLAYER_ID)
	{
		if (tick >= s_RealmTollHeldUntil[toll])
		{
			Realm_OpenToll(toll);
			Coach_Release(s_RealmTollHeld[toll]);
			s_RealmTollHeld[toll] = INVALID_PLAYER_ID;
		}

		return;
	}

	if (Realm_IsTollOpen(toll))
	{
		return;
	}

	for (new h = -1;h < COACH_HIRES;h++)
	{
		new rider = h == -1 ? Coach_GetRider() : Coach_GetHireRider(h);

		if (Realm_RiderNearToll(rider,toll,REALM_TOLL_HOLD_RANGE) && Coach_Hold(rider))
		{
			s_RealmTollHeld[toll] = rider;
			s_RealmTollHeldUntil[toll] = tick + REALM_TOLL_HOLD_MS;
			return;
		}
	}

	if (Realm_WalkerNearToll(toll,REALM_TOLL_WALKER_RANGE))
	{
		Realm_OpenToll(toll);
	}
}

stock bool:Realm_PayToll(playerid,toll)
{
	if (toll < 0 || toll >= REALM_SEED_TOLLS)
	{
		return false;
	}

	new fee = Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL);

	if (fee > 0 && !Realm_IsTollExempt(playerid))
	{
		new money[24];
		Economy_Format(fee,money);

		if (Economy_Pay(playerid,fee,INVALID_CONTAINER_ID,"toll") != PAY_OK)
		{
			Gui_Notify(playerid,sprintf("You can't pay the toll. The toll keeper wants %s before he raises the bar.",money));
			return false;
		}

		Realm_AddDues(REALM_COUNTY,Realm_VillageAt(g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5]),fee);
		Gui_Notify(playerid,sprintf("You pay the toll keeper %s. The bar goes up, and you have a minute to pass.",money));
		Realm_KeeperSays(toll,"Thank you. Pass, and God keep you on the road.");
	}
	else
	{
		Gui_Notify(playerid,"The toll keeper raises the bar for you.");
	}

	s_RealmTollPassUntil[playerid] = GetTickCount() + REALM_TOLL_PASS_MS;
	Realm_OpenToll(toll);
	Log_Info("realm","toll paid by player %d at %s",playerid,g_RealmTollNames[toll]);
	return true;
}

stock bool:Realm_Collect(playerid,village)
{
	if (!Law_IsGuard(playerid) || village < 0 || village >= REALM_VILLAGES)
	{
		return false;
	}

	new coin = Realm_TakeDues(village);

	if (coin <= 0)
	{
		Gui_Notify(playerid,"Nothing is owed here.");
		return false;
	}

	Economy_GiveOrClaim(playerid,Character_GetId(playerid),coin,"collected dues");
	s_RealmCarried[playerid] += coin;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO dues_carried (character_id, coin, since) VALUES (%d, %d, %d) ON DUPLICATE KEY UPDATE coin = coin + %d",Character_GetId(playerid),coin,gettime(),coin));
	new money[24];
	Economy_Format(coin,money);
	Gui_Notify(playerid,sprintf("You collect %s for the county. Carry it to the steward; the road isn't safe.",money));
	return true;
}

stock bool:Realm_Deliver(playerid)
{
	new coin = s_RealmCarried[playerid];

	if (coin <= 0)
	{
		return false;
	}

	coin = min(coin,Economy_Worth(playerid));

	if (coin <= 0 || Economy_Pay(playerid,coin,INVALID_CONTAINER_ID,"dues delivered") != PAY_OK)
	{
		Gui_Notify(playerid,"You haven't the coin you collected.");
		return false;
	}

	new counts[COIN_TIER_COUNT];
	Economy_Split(coin,counts);

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Container_Add(Realm_GetTreasury(),ITEM_KIND_COIN,tier,counts[tier]);
		}
	}

	s_RealmCarried[playerid] -= coin;
	mysql_tquery_s(g_Mysql,str_format("UPDATE dues_carried SET coin = GREATEST(coin - %d, 0) WHERE character_id = %d",coin,Character_GetId(playerid)));
	new money[24];
	Economy_Format(coin,money);
	Gui_Notify(playerid,sprintf("The steward counts %s into the treasury.",money));
	return true;
}

stock Realm_TreasuryCoin()
{
	new treasury = Realm_GetTreasury(), coin = 0;

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		coin += Container_Count(treasury,ITEM_KIND_COIN,tier) * Item_CoinWorth(tier);
	}

	return coin;
}

stock bool:Realm_PayFromTreasury(playerid,amount,const source[],bool:orClaim = false)
{
	new treasury = Realm_GetTreasury(), take[COIN_TIER_COUNT], left = amount, change = 0;

	if (amount <= 0 || treasury == INVALID_CONTAINER_ID || Realm_TreasuryCoin() < amount)
	{
		return false;
	}

	for (new tier = COIN_TIER_COUNT - 1;tier >= COIN_PFENNIG;tier--)
	{
		take[tier] = min(left / Item_CoinWorth(tier),Container_Count(treasury,ITEM_KIND_COIN,tier));
		left -= take[tier] * Item_CoinWorth(tier);
	}

	for (new tier = COIN_PFENNIG;left > 0 && tier < COIN_TIER_COUNT;tier++)
	{
		if (Item_CoinWorth(tier) >= left && Container_Count(treasury,ITEM_KIND_COIN,tier) > take[tier])
		{
			take[tier]++;
			change = Item_CoinWorth(tier) - left;
			left = 0;
		}
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

	if (change > 0)
	{
		new counts[COIN_TIER_COUNT];
		Economy_Split(change,counts);

		for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
		{
			if (counts[tier] > 0)
			{
				Container_Add(treasury,ITEM_KIND_COIN,tier,counts[tier]);
			}
		}
	}

	if (Economy_Give(playerid,amount,source))
	{
		return true;
	}

	if (orClaim && Character_GetId(playerid) > 0)
	{
		Economy_GiveOrClaim(INVALID_PLAYER_ID,Character_GetId(playerid),amount,source);
		return true;
	}

	Realm_RefundTreasury(amount);
	return false;
}

stock Realm_RefundTreasury(amount)
{
	new counts[COIN_TIER_COUNT], treasury = Realm_GetTreasury();
	Economy_Split(amount,counts);

	for (new tier = COIN_PFENNIG;treasury != INVALID_CONTAINER_ID && tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Container_Add(treasury,ITEM_KIND_COIN,tier,counts[tier]);
		}
	}
}

stock bool:Realm_StoreInTreasury(E_ITEM_KIND:kind,param,amount,stars)
{
	new treasury = Realm_GetTreasury();
	return treasury != INVALID_CONTAINER_ID && Container_Add(treasury,kind,param,amount,stars);
}

stock Realm_TreasuryGrain()
{
	new treasury = Realm_GetTreasury(), grain = 0, sacks[] = {ITEM_WHEAT, ITEM_BARLEY, ITEM_RYE, ITEM_OATS, ITEM_FLOUR, ITEM_FLOUR_RYE};

	for (new i = 0;i < sizeof(sacks);i++)
	{
		grain += Container_Count(treasury,Item_GetDefKind(sacks[i]),sacks[i]);
	}

	return grain;
}

stock Realm_Levy(byCharacter,coinPercent,grainPercent)
{
	new season = Horses_SeasonIndex();

	if (s_RealmLevySeason == season)
	{
		return -1;
	}

	coinPercent = Util_ClampInt(coinPercent,0,REALM_LEVY_COIN_PERCENT);
	grainPercent = Util_ClampInt(grainPercent,0,REALM_LEVY_GRAIN_PERCENT);
	new coin = Realm_TreasuryCoin() * coinPercent / 100, taken = 0, county = Realm_GetTreasury(), duchy = Realm_GetDuchyTreasury();

	for (new tier = COIN_GULDEN;tier >= COIN_PFENNIG && taken < coin;tier--)
	{
		new worth = Item_CoinWorth(tier), want = (coin - taken) / worth, have = Container_Count(county,ITEM_KIND_COIN,tier), n = min(want,have);

		if (n > 0 && Container_Move(county,duchy,ITEM_KIND_COIN,tier,n,ITEM_STARS_MIN))
		{
			taken += n * worth;
		}
	}

	new grainTaken = 0, sacks[] = {ITEM_WHEAT, ITEM_BARLEY, ITEM_RYE, ITEM_OATS, ITEM_FLOUR, ITEM_FLOUR_RYE};

	for (new i = 0;i < sizeof(sacks);i++)
	{
		new have = Container_Count(county,Item_GetDefKind(sacks[i]),sacks[i]), n = have * grainPercent / 100;

		if (n > 0 && Container_Move(county,duchy,Item_GetDefKind(sacks[i]),sacks[i],n,ITEM_STARS_MIN))
		{
			grainTaken += n;
		}
	}

	s_RealmLevySeason = season;
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO levies (county_id, due_turn, coin, grain, paid) VALUES (%d, %d, %d, %d, 1)",REALM_COUNTY,season,taken,grainTaken));
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO realm_log (at, actor_character_id, what) VALUES (%d, %d, 'levy %d coin %d grain')",gettime(),byCharacter,taken,grainTaken));
	new money[24];
	Economy_Format(taken,money);
	Realm_Post("The duke's levy",sprintf("By the duke's order the county pays %s and %d sacks of grain this season.",money,grainTaken));
	return taken;
}

static Realm_ClearPrompt(playerid)
{
	if (s_RealmInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_RealmInfobox[playerid]);
	}

	s_RealmPrompt[playerid] = -1;
	s_RealmInfobox[playerid] = 0;
}

static Realm_PromptAt(playerid)
{
	for (new point = 0;point < REALM_SEED_POINTS;point++)
	{
		if (Law_IsGuard(playerid) && IsPlayerInRangeOfPoint(playerid,REALM_POINT_REACH,g_RealmPointDefs[point][E_REALM_POINT_DEF_POS][0],g_RealmPointDefs[point][E_REALM_POINT_DEF_POS][1],g_RealmPointDefs[point][E_REALM_POINT_DEF_POS][2] + 1.0))
		{
			for (new village = 0;village < REALM_VILLAGES;village++)
			{
				if (!strcmp(g_RealmPointDefs[point][E_REALM_POINT_DEF_KEY],g_RealmVillageKeys[village]))
				{
					return village;
				}
			}
		}
	}

	for (new toll = 0;toll < REALM_SEED_TOLLS;toll++)
	{
		if ((!Realm_IsTollOpen(toll) || Realm_OwesToll(playerid)) && Carts_GetSeat(playerid) == -1 && IsPlayerInRangeOfPoint(playerid,REALM_TOLL_REACH,g_RealmTollDefs[toll][4],g_RealmTollDefs[toll][5],g_RealmTollDefs[toll][6] + 1.0))
		{
			return 100 + toll;
		}
	}

	return -1;
}

Timer_Declare(Realm_Tick)
{
	new tick = GetTickCount();

	for (new toll = 0;toll < REALM_SEED_TOLLS;toll++)
	{
		if (s_RealmTollOpenUntil[toll] != 0 && tick >= s_RealmTollOpenUntil[toll])
		{
			if (Realm_TollIsClear(toll))
			{
				s_RealmTollOpenUntil[toll] = 0;
				Realm_SetTollBar(toll,false);
			}
			else
			{
				s_RealmTollOpenUntil[toll] = tick + REALM_TOLL_CLEAR_MS;
			}
		}

		Realm_TollTraffic(toll,tick);
	}

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		Realm_TollWatch(playerid,tick);
		new prompt = Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && s_RealmCollecting[playerid] == -1 ? Realm_PromptAt(playerid) : -1;

		if (prompt == -1)
		{
			Realm_ClearPrompt(playerid);
			continue;
		}

		if (prompt == s_RealmPrompt[playerid] && Infobox_IsShown(playerid,s_RealmInfobox[playerid]))
		{
			continue;
		}

		new text[96], money[24];
		s_RealmPrompt[playerid] = prompt;

		if (prompt >= 100)
		{
			if (Realm_OwesToll(playerid))
			{
				Economy_Format(Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL),money);
				format(text,sizeof(text),"Press ~y~Y~w~ to pay the toll keeper %s and pass.",money);
			}
			else
			{
				strcopy(text,"Press ~y~Y~w~ and the toll keeper raises the bar.");
			}

			s_RealmInfobox[playerid] = Infobox_Show(playerid,"The toll",text,3,0,true);
		}
		else
		{
			Economy_Format(Realm_GetDues(prompt),money);
			format(text,sizeof(text),"Press ~y~Y~w~ to collect the dues (%s owed).",money);
			s_RealmInfobox[playerid] = Infobox_Show(playerid,g_RealmVillageNames[prompt],text,3,0,true);
		}
	}

	return 1;
}

Timer_Declare(Realm_WatchTick)
{
	if (!Calendar_IsNight() || Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_LIGHT_LAW) == 0)
	{
		return 1;
	}

	new night = Horses_Today();

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || s_RealmDarkNight[playerid] == night)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);

		if (!Realm_InTown(x,y) || Light_HasLight(playerid) || Light_IsLitNear(x,y,z,0))
		{
			continue;
		}

		s_RealmDarkNight[playerid] = night;
		Gui_Notify(playerid,"The county's light law: carry a light in town after dark.");
		Law_Commit(playerid,LAW_CRIME_DARKNESS);
	}

	return 1;
}

forward Realm_CollectDone(playerid,village,token);

public Realm_CollectDone(playerid,village,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || s_RealmCollecting[playerid] != village)
	{
		return 1;
	}

	s_RealmCollecting[playerid] = -1;
	ClearAnimations(playerid,SYNC_ALL);
	Realm_Collect(playerid,village);
	return 1;
}

forward bool:Realm_PromptContext(playerid);

public bool:Realm_PromptContext(playerid)
{
	return s_RealmPrompt[playerid] != -1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_RealmCarried[playerid] = 0;
	s_RealmCollecting[playerid] = -1;
	s_RealmPrompt[playerid] = -1;
	s_RealmInfobox[playerid] = 0;
	s_RealmDarkNight[playerid] = -1;
	s_RealmTollPassUntil[playerid] = 0;
	s_RealmTollSideOf[playerid] = -1;
	s_RealmTollSideSign[playerid] = 0;
}

hook Character_OnLoaded(playerid,characterid)
{
	Realm_LoadCarried(playerid,characterid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || (newkeys & KEY_WALK) || s_RealmPrompt[playerid] == -1 || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		return;
	}

	new prompt = s_RealmPrompt[playerid];
	Realm_ClearPrompt(playerid);

	if (prompt >= 100)
	{
		Realm_PayToll(playerid,prompt - 100);
		return;
	}

	s_RealmCollecting[playerid] = prompt;
	ApplyAnimation(playerid,"CASINO","cards_win",4.1,true,false,false,false,0,SYNC_ALL);
	Gui_Notify(playerid,"You call the households out and count their dues.");
	SetTimerEx("Realm_CollectDone",REALM_COLLECT_MS,false,"ddd",playerid,prompt,Account_GetToken(playerid));
}

hook Houses_OnRentPaid(playerid,room,rent)
{
	#pragma unused room
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	Realm_AddDues(REALM_COUNTY,Realm_VillageAt(x,y),rent);
}

hook Realm_OnPolicyChanged(county,policy,oldValue,newValue)
{
	#pragma unused county, oldValue
	new value[32];
	Realm_PolicyText(policy,newValue,value);
	Realm_Post("The county's policy",sprintf("%s is now %s.",g_RealmPolicyDefs[policy][E_RP_NAME],value));
}

hook Realm_OnDecree(row,kind,const text[])
{
	#pragma unused row
	Realm_Post(g_RealmDecreeNames[kind],text);
	Crier_Announce("law",g_RealmDecreeNames[kind],text);
}
