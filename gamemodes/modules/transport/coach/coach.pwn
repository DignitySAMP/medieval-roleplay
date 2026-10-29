#define COACH_TAG_LINE (1001)
#define COACH_TAG_HIRE (1002)
#define COACH_TICK_MS (50)
#define COACH_STOP_SECONDS (90)
#define COACH_FARE (2)
#define COACH_HIRE_FEE (6)
#define COACH_HORSE_TYPE (3)
#define COACH_PULL (0.8)
#define COACH_BOARD_RANGE (3.0)
#define COACH_HIRES (2)
#define COACH_HIRE_WAIT_MS (9000)
#define COACH_HIRE_STUCK_MS (20000)
#define COACH_HIRE_NEAR (4.0)
#define COACH_HIRE_LINE_REACH (45.0)
#define COACH_TOLLS_MAX (4)

enum
{
	COACH_STATE_IDLE,
	COACH_STATE_AT_STOP,
	COACH_STATE_RUNNING,
}

enum
{
	COACH_HIRE_APPROACH,
	COACH_HIRE_LINE,
	COACH_HIRE_FINAL,
	COACH_HIRE_WAIT,
}

enum E_COACH_HIRE
{
	bool:E_CH_USED,
	E_CH_CART,
	E_CH_RIDER,
	E_CH_OWNER,
	E_CH_ARRIVED_AT,
	E_CH_DEST,
	bool:E_CH_HELD,
	E_CH_PHASE,
	bool:E_CH_RETURNING,
	E_CH_LINE_FROM,
	E_CH_LINE_TO,
	E_CH_MOVED_AT,
	Float:E_CH_GOAL[3],
	Float:E_CH_HOME[4],
}

static s_CoachRider = INVALID_PLAYER_ID;
static s_CoachCart = -1;
static s_CoachState = COACH_STATE_IDLE;
static s_CoachStop = 0;
static s_CoachDirection = 1;
static s_CoachDepartAt = 0;
static s_CoachDest[MAX_PLAYERS] = {-1, ...};
static Float:s_CoachLeg[ROADS_COACH_POINTS * 3];
static s_CoachLegCount = 0;
static bool:s_CoachHeld = false;
static s_CoachHeldAt = 0;
static s_CoachHires[COACH_HIRES][E_COACH_HIRE];
static s_CoachHireWait = COACH_HIRE_WAIT_MS;
static s_CoachPrompt[MAX_PLAYERS];
static s_CoachInfobox[MAX_PLAYERS];
static s_CoachTollOwed[MAX_PLAYERS];
static s_CoachTollPoints[COACH_TOLLS_MAX];
static s_CoachTollCount = 0;

static const s_CoachDestNames[][24] = {"Talmberg", "the church village", "the guardhouse", "the monastery", "the castle"};
static const s_CoachDestLine[] = {0, 79, 291, 187, -1};
static const Float:s_CoachDestPos[][3] = {
	{1007.0, -3403.5, 65.67}, {1005.0, -3155.0, 34.0}, {716.8, -3189.0, 22.7}, {707.0, -3603.0, 17.5}, {724.0, -2887.0, 27.0}
};

stock Coach_GetRider()
{
	return s_CoachRider;
}

stock Coach_GetCart()
{
	return s_CoachCart;
}

stock Coach_GetState()
{
	return s_CoachState;
}

stock Coach_GetStop()
{
	return s_CoachStop;
}

stock Coach_GetHireRider(hire)
{
	return hire >= 0 && hire < COACH_HIRES && s_CoachHires[hire][E_CH_USED] ? s_CoachHires[hire][E_CH_RIDER] : INVALID_PLAYER_ID;
}

stock Coach_GetHireOwner(hire)
{
	return hire >= 0 && hire < COACH_HIRES && s_CoachHires[hire][E_CH_USED] ? s_CoachHires[hire][E_CH_OWNER] : INVALID_PLAYER_ID;
}

forward Coach_HireIssue(h);

stock Coach_SetHireWait(ms)
{
	s_CoachHireWait = ms;
}

stock Coach_FindHire(cart)
{
	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_CART] == cart)
		{
			return h;
		}
	}

	return -1;
}

stock Coach_GetHirePhase(hire)
{
	return hire >= 0 && hire < COACH_HIRES && s_CoachHires[hire][E_CH_USED] ? s_CoachHires[hire][E_CH_PHASE] : -1;
}

stock bool:Coach_IsHireReturning(hire)
{
	return hire >= 0 && hire < COACH_HIRES && s_CoachHires[hire][E_CH_USED] && s_CoachHires[hire][E_CH_RETURNING];
}

stock bool:Coach_IsHeld(riderid)
{
	if (riderid != INVALID_PLAYER_ID && riderid == s_CoachRider)
	{
		return s_CoachHeld;
	}

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_RIDER] == riderid)
		{
			return s_CoachHires[h][E_CH_HELD];
		}
	}

	return false;
}

stock bool:Coach_Hold(riderid)
{
	if (riderid == INVALID_PLAYER_ID)
	{
		return false;
	}

	if (riderid == s_CoachRider)
	{
		new at = Rider_GetRoutePoint(riderid);

		if (s_CoachState != COACH_STATE_RUNNING || s_CoachHeld || at < 0)
		{
			return false;
		}

		Rider_Stop(riderid);
		s_CoachHeld = true;
		s_CoachHeldAt = at;
		return true;
	}

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_RIDER] == riderid && !s_CoachHires[h][E_CH_HELD] && s_CoachHires[h][E_CH_PHASE] != COACH_HIRE_WAIT && Rider_IsMoving(riderid))
		{
			Rider_Stop(riderid);
			s_CoachHires[h][E_CH_HELD] = true;
			return true;
		}
	}

	return false;
}

stock Coach_Release(riderid)
{
	if (riderid == INVALID_PLAYER_ID)
	{
		return;
	}

	if (riderid == s_CoachRider)
	{
		if (!s_CoachHeld)
		{
			return;
		}

		new Float:rest[ROADS_COACH_POINTS * 3], count = 0;
		s_CoachHeld = false;

		for (new i = s_CoachHeldAt;i < s_CoachLegCount;i++)
		{
			rest[count * 3] = s_CoachLeg[i * 3];
			rest[count * 3 + 1] = s_CoachLeg[i * 3 + 1];
			rest[count * 3 + 2] = s_CoachLeg[i * 3 + 2];
			count++;
		}

		if (count == 0)
		{
			Coach_Arrive();
			return;
		}

		NpcRiders_RideRoute(riderid,rest,count,MOUNT_GAIT_SPRINT,COACH_PULL);
		return;
	}

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_RIDER] == riderid && s_CoachHires[h][E_CH_HELD])
		{
			s_CoachHires[h][E_CH_HELD] = false;
			Coach_HireIssue(h);
		}
	}
}

stock Coach_GetDest(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CoachDest[playerid] : -1;
}

stock Coach_AddTollPoint(point)
{
	if (point <= 0 || point >= ROADS_COACH_POINTS || s_CoachTollCount >= COACH_TOLLS_MAX)
	{
		return 0;
	}

	s_CoachTollPoints[s_CoachTollCount++] = point;
	return 1;
}

stock Coach_CountTolls(fromStop,toStop)
{
	if (fromStop < 0 || fromStop >= ROADS_COACH_STOPS || toStop < 0 || toStop >= ROADS_COACH_STOPS)
	{
		return 0;
	}

	new from = g_RoadsCoachStops[fromStop][E_ROADS_STOP_DEF_POINT], to = g_RoadsCoachStops[toStop][E_ROADS_STOP_DEF_POINT], low = min(from,to), high = max(from,to), count = 0;

	for (new i = 0;i < s_CoachTollCount;i++)
	{
		if (s_CoachTollPoints[i] > low && s_CoachTollPoints[i] <= high)
		{
			count++;
		}
	}

	return count;
}

stock Coach_TollPart(fromStop,toStop)
{
	return Coach_CountTolls(fromStop,toStop) * Realm_GetPolicy(REALM_COUNTY,REALM_POLICY_TOLL);
}

stock Coach_Fare(fromStop,toStop)
{
	return COACH_FARE * max(fromStop > toStop ? fromStop - toStop : toStop - fromStop,1) + Coach_TollPart(fromStop,toStop);
}

stock Coach_GetTollOwed(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CoachTollOwed[playerid] : 0;
}

stock bool:Coach_ChargeSeat(playerid,fromStop,toStop)
{
	new fare = Coach_Fare(fromStop,toStop);

	if (Economy_Pay(playerid,fare,INVALID_CONTAINER_ID,"coach fare") != PAY_OK)
	{
		return false;
	}

	s_CoachTollOwed[playerid] = Coach_TollPart(fromStop,toStop);
	return true;
}

stock Coach_RefundSeat(playerid,fromStop,toStop)
{
	Economy_Give(playerid,Coach_Fare(fromStop,toStop),"coach fare back");
	s_CoachTollOwed[playerid] = 0;
}

stock Coach_PayTolls(fee)
{
	new paid = 0;

	if (fee <= 0 || !Carts_IsValid(s_CoachCart))
	{
		return 0;
	}

	for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
	{
		new playerid = Carts_GetSeated(s_CoachCart,seat);

		if (playerid == INVALID_PLAYER_ID || s_CoachTollOwed[playerid] <= 0)
		{
			continue;
		}

		new coin = min(fee,s_CoachTollOwed[playerid]), money[24];
		s_CoachTollOwed[playerid] -= coin;
		paid += coin;
		Economy_Format(coin,money);
		Gui_Notify(playerid,sprintf("The coachman pays the toll keeper %s for your seat. The toll was part of your fare.",money));
	}

	return paid;
}

stock Coach_NextStop()
{
	new next = s_CoachStop + s_CoachDirection;
	return next < 0 || next >= ROADS_COACH_STOPS ? s_CoachStop - s_CoachDirection : next;
}

stock bool:Coach_CanRideTo(fromStop,toStop,direction)
{
	return fromStop >= 0 && fromStop < ROADS_COACH_STOPS && toStop >= 0 && toStop < ROADS_COACH_STOPS && (direction == 1 ? toStop > fromStop : direction == -1 && toStop < fromStop);
}

stock bool:Coach_RunsNow()
{
	return !Calendar_IsNight();
}

stock Coach_BuildRun(from,to,Float:out[],size = sizeof(out))
{
	new step = to >= from ? 1 : -1, count = 0;

	for (new i = from;count * 3 + 2 < size;i += step)
	{
		out[count * 3] = g_RoadsCoachRoute[i][0];
		out[count * 3 + 1] = g_RoadsCoachRoute[i][1];
		out[count * 3 + 2] = g_RoadsCoachRoute[i][2];
		count++;

		if (i == to)
		{
			break;
		}
	}

	return count;
}

stock Coach_BuildLeg(fromStop,toStop,Float:out[],size = sizeof(out))
{
	return Coach_BuildRun(g_RoadsCoachStops[fromStop][E_ROADS_STOP_DEF_POINT],g_RoadsCoachStops[toStop][E_ROADS_STOP_DEF_POINT],out,size);
}

stock Coach_NearestPoint(Float:x,Float:y,&Float:distance)
{
	new best = 0;
	distance = 100000.0;

	for (new i = 0;i < ROADS_COACH_POINTS;i++)
	{
		new Float:d = VectorSize(g_RoadsCoachRoute[i][0] - x,g_RoadsCoachRoute[i][1] - y,0.0);

		if (d < distance)
		{
			distance = d;
			best = i;
		}
	}

	return best;
}

stock Coach_GetHireDestPoint(dest)
{
	return dest >= 0 && dest < sizeof(s_CoachDestLine) ? s_CoachDestLine[dest] : -1;
}

stock bool:Coach_GetHireDestGoal(dest,&Float:x,&Float:y,&Float:z)
{
	if (dest < 0 || dest >= sizeof(s_CoachDestLine))
	{
		return false;
	}

	if (s_CoachDestLine[dest] != -1)
	{
		x = g_RoadsCoachRoute[s_CoachDestLine[dest]][0];
		y = g_RoadsCoachRoute[s_CoachDestLine[dest]][1];
		z = g_RoadsCoachRoute[s_CoachDestLine[dest]][2];
		return true;
	}

	x = s_CoachDestPos[dest][0];
	y = s_CoachDestPos[dest][1];
	z = s_CoachDestPos[dest][2];
	return true;
}

stock Coach_Start()
{
	if (ROADS_COACH_STOPS < 2 || s_CoachRider != INVALID_PLAYER_ID)
	{
		return 0;
	}

	new start = g_RoadsCoachStops[0][E_ROADS_STOP_DEF_POINT], next = min(start + 1,ROADS_COACH_POINTS - 1);
	new Float:x = g_RoadsCoachRoute[start][0], Float:y = g_RoadsCoachRoute[start][1], Float:z = g_RoadsCoachRoute[start][2] - 1.0;
	new Float:a = atan2(g_RoadsCoachRoute[next][1] - y,g_RoadsCoachRoute[next][0] - x) - 90.0, skins = Skins_CountStarter(0);
	s_CoachRider = NpcRiders_Create("Coachman_Jan",skins > 0 ? Skins_GetStarter(0,1 % skins) : 1,COACH_HORSE_TYPE,x,y,z,a,0,COACH_TAG_LINE);

	if (s_CoachRider == INVALID_PLAYER_ID)
	{
		return 0;
	}

	s_CoachCart = Carts_CreateTransient(CART_KIND_PUBLIC_COACH,0,x + floatsin(a,degrees) * CARTS_HITCH,y - floatcos(a,degrees) * CARTS_HITCH,z,a + 180.0);
    if (!Carts_IsValid(s_CoachCart))
    {
        NpcRiders_Destroy(s_CoachRider);
        s_CoachRider = INVALID_PLAYER_ID;
        return 0;
    }

    Infobox_SetTargetActor("Coach_TargetDistance",Actors_FindByKey(sprintf("rider:%d",s_CoachRider)));
	s_CoachState = COACH_STATE_AT_STOP;
	s_CoachStop = 0;
	s_CoachDirection = 1;
	s_CoachDepartAt = gettime() + COACH_STOP_SECONDS;
    Coach_Park();
	return 1;
}

static Coach_Announce(const text[])
{
	new Float:x, Float:y, Float:z, Float:a;

	if (!Rider_GetPos(s_CoachRider,x,y,z,a))
	{
		return;
	}

	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && IsPlayerInRangeOfPoint(playerid,30.0,x,y,z))
		{
			SendClientMessage(playerid,0xC9A66BFF,sprintf("The coachman calls: %s",text));
		}
	}
}

stock Coach_Depart()
{
	if (s_CoachRider == INVALID_PLAYER_ID)
	{
		return;
	}

	new next = Coach_NextStop();

	if (next == s_CoachStop)
	{
		return;
	}

	if (next < s_CoachStop)
	{
		s_CoachDirection = -1;
	}
	else
	{
		s_CoachDirection = 1;
	}

	new count = Coach_BuildLeg(s_CoachStop,next,s_CoachLeg);
	s_CoachLegCount = count;
	s_CoachHeld = false;
	Coach_Announce(sprintf("All aboard for %s!",g_RoadsCoachStops[next][E_ROADS_STOP_DEF_NAME]));
	NpcRiders_RideRoute(s_CoachRider,s_CoachLeg,count,MOUNT_GAIT_SPRINT,COACH_PULL);
	s_CoachState = COACH_STATE_RUNNING;
}

stock bool:Coach_Park()
{
    new Float:x, Float:y, Float:z, Float:angle;

    if (s_CoachState != COACH_STATE_AT_STOP || !Carts_IsValid(s_CoachCart) || !Rider_GetPos(s_CoachRider,x,y,z,angle))
    {
        return false;
    }

    Carts_Follow(s_CoachCart,x,y,z,angle);
    Carts_GetPos(s_CoachCart,x,y,z,angle);
    Nearby_StreamObjectsAt(x,y,z,0,0,CARTS_STREAM);
    return true;
}

stock Coach_Arrive()
{
	s_CoachStop = Coach_NextStop();
	s_CoachState = COACH_STATE_AT_STOP;
	s_CoachDepartAt = gettime() + COACH_STOP_SECONDS;

	if (s_CoachStop == 0 || s_CoachStop == ROADS_COACH_STOPS - 1)
	{
		s_CoachDirection = -s_CoachDirection;
	}

    Coach_Park();
	Coach_Announce(sprintf("%s! The coach stops here a while.",g_RoadsCoachStops[s_CoachStop][E_ROADS_STOP_DEF_NAME]));

	for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
	{
		new playerid = Carts_GetSeated(s_CoachCart,seat);

		if (playerid != INVALID_PLAYER_ID && s_CoachDest[playerid] == s_CoachStop)
		{
			s_CoachDest[playerid] = -1;
			Carts_Stand(playerid);
			Gui_Notify(playerid,sprintf("You climb down at %s.",g_RoadsCoachStops[s_CoachStop][E_ROADS_STOP_DEF_NAME]));
		}
	}
}

stock bool:Coach_Board(playerid,toStop)
{
	if (s_CoachState != COACH_STATE_AT_STOP || !Coach_CanRideTo(s_CoachStop,toStop,Coach_NextStop() - s_CoachStop) || Carts_GetSeat(playerid) != -1)
	{
		return false;
	}

	new seat = Carts_FreeSeat(s_CoachCart);

	if (seat == -1)
	{
		Gui_Notify(playerid,"The coach is full. Wait for the next one.");
		return false;
	}

	if (!Coach_ChargeSeat(playerid,s_CoachStop,toStop))
	{
		Gui_Notify(playerid,"You can't pay the fare.");
		return false;
	}

	if (!Carts_Sit(playerid,s_CoachCart,seat))
	{
		Coach_RefundSeat(playerid,s_CoachStop,toStop);
		return false;
	}

	s_CoachDest[playerid] = toStop;
	Gui_Notify(playerid,sprintf("You take a seat for %s. The coach leaves when the coachman calls.",g_RoadsCoachStops[toStop][E_ROADS_STOP_DEF_NAME]));
	return true;
}

stock bool:Coach_GetPromptDistance(playerid,&Float:distance,bool:selectTarget = true,bool:arbitrate = true)
{
    distance = COACH_BOARD_RANGE + 1.0;
    if (!Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT || s_CoachState != COACH_STATE_AT_STOP || Carts_GetSeat(playerid) != -1 || Mount_IsRiding(playerid) || Gui_IsBusy(playerid))
    {
        return false;
    }

    new Float:playerX, Float:playerY, Float:playerZ, Float:playerAngle, Float:targetX, Float:targetY, Float:targetZ, Float:targetAngle;
    GetPlayerPos(playerid,playerX,playerY,playerZ);
    GetPlayerFacingAngle(playerid,playerAngle);
    for (new target = 0; target < 2; target++)
    {
        new bool:found = target == 0 ? Carts_GetPos(s_CoachCart,targetX,targetY,targetZ,targetAngle) : Rider_GetPos(s_CoachRider,targetX,targetY,targetZ,targetAngle);
        if (found && (!selectTarget || Actors_IsFacing(playerX,playerY,playerAngle,targetX,targetY)))
        {
            new Float:targetDistance = VectorSize(targetX - playerX,targetY - playerY,targetZ + 1.0 - playerZ);
            if (targetDistance <= COACH_BOARD_RANGE && targetDistance < distance)
            {
                distance = targetDistance;
            }
        }
    }
    if (distance > COACH_BOARD_RANGE)
    {
        return false;
    }

    if (!selectTarget)
    {
        return true;
    }

    return !arbitrate || Infobox_IsTargetWinner(playerid,"Coach_TargetDistance");
}

stock bool:Coach_CanPrompt(playerid)
{
    new Float:distance;
    return Coach_GetPromptDistance(playerid,distance);
}

stock Coach_OpenBoard(playerid)
{
	if (!Coach_CanPrompt(playerid))
	{
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, rows = 0, fromStop = s_CoachStop;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"The coach");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(ROADS_COACH_STOPS) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"The coach",x,y,width);

	for (new stop = 0;stop < ROADS_COACH_STOPS;stop++)
	{
		if (!Coach_CanRideTo(s_CoachStop,stop,Coach_NextStop() - s_CoachStop))
		{
			continue;
		}

		new label[48], money[24];
		Economy_Format(Coach_Fare(s_CoachStop,stop),money);
		format(label,sizeof(label),"Ride to %s",g_RoadsCoachStops[stop][E_ROADS_STOP_DEF_NAME]);
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(rows++),width,label,stop,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(ROADS_COACH_STOPS) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= ROADS_COACH_STOPS)
	{
		return;
	}

    new Float:distance;

    if (s_CoachState != COACH_STATE_AT_STOP || s_CoachStop != fromStop || !Coach_GetPromptDistance(playerid,distance,false))
	{
		Gui_Notify(playerid,"The coach has already left. Wait at the stop for the next one.");
		return;
	}

	Coach_Board(playerid,pick);
}

static Coach_HireTrip(h,Float:goalX,Float:goalY,Float:goalZ,lineTo)
{
	new rider = s_CoachHires[h][E_CH_RIDER], Float:x, Float:y, Float:z, Float:a, Float:gap;
	Rider_GetPos(rider,x,y,z,a);
	s_CoachHires[h][E_CH_GOAL][0] = goalX;
	s_CoachHires[h][E_CH_GOAL][1] = goalY;
	s_CoachHires[h][E_CH_GOAL][2] = goalZ;
	s_CoachHires[h][E_CH_LINE_TO] = lineTo;
	s_CoachHires[h][E_CH_LINE_FROM] = lineTo != -1 ? Coach_NearestPoint(x,y,gap) : -1;
	s_CoachHires[h][E_CH_PHASE] = lineTo != -1 ? COACH_HIRE_APPROACH : COACH_HIRE_FINAL;
	s_CoachHires[h][E_CH_MOVED_AT] = GetTickCount();
	Coach_HireIssue(h);
}

static Coach_HireFinish(h)
{
	new cart = s_CoachHires[h][E_CH_CART], rider = s_CoachHires[h][E_CH_RIDER], owner = s_CoachHires[h][E_CH_OWNER];

	if (Carts_IsValid(cart))
	{
		Carts_Follow(cart,s_CoachHires[h][E_CH_HOME][0],s_CoachHires[h][E_CH_HOME][1],s_CoachHires[h][E_CH_HOME][2],s_CoachHires[h][E_CH_HOME][3]);
		Carts_SetDriven(cart,false);
		Carts_Save(cart);
	}

	NpcRiders_Destroy(rider);
	s_CoachHires[h][E_CH_USED] = false;

	if (IsPlayerConnected(owner))
	{
		Gui_Notify(owner,"The coachman has taken your cart home.");
	}
}

static Coach_HireSendHome(h)
{
	new cart = s_CoachHires[h][E_CH_CART], owner = s_CoachHires[h][E_CH_OWNER];

	if (Carts_IsValid(cart))
	{
		for (new seat = 0;seat < CARTS_SEATS_MAX;seat++)
		{
			new passenger = Carts_GetSeated(cart,seat);

			if (passenger != INVALID_PLAYER_ID && IsPlayerConnected(passenger))
			{
				Carts_Stand(passenger);
				Gui_Notify(passenger,"The coachman needs the cart back, and you climb down.");
			}
		}
	}

	new Float:gap, home = Coach_NearestPoint(s_CoachHires[h][E_CH_HOME][0],s_CoachHires[h][E_CH_HOME][1],gap);
	s_CoachHires[h][E_CH_RETURNING] = true;
	Coach_HireTrip(h,s_CoachHires[h][E_CH_HOME][0],s_CoachHires[h][E_CH_HOME][1],s_CoachHires[h][E_CH_HOME][2],gap <= COACH_HIRE_LINE_REACH ? home : -1);

	if (IsPlayerConnected(owner) && Carts_GetSeat(owner) == -1)
	{
		Gui_Notify(owner,"The coachman takes the cart back to where it stood.");
	}
}

static Coach_HireArrived(h)
{
	if (s_CoachHires[h][E_CH_PHASE] < COACH_HIRE_FINAL)
	{
		s_CoachHires[h][E_CH_PHASE]++;
		Coach_HireIssue(h);
		return;
	}

	if (s_CoachHires[h][E_CH_RETURNING])
	{
		Coach_HireFinish(h);
		return;
	}

	new owner = s_CoachHires[h][E_CH_OWNER];
	s_CoachHires[h][E_CH_PHASE] = COACH_HIRE_WAIT;
	s_CoachHires[h][E_CH_ARRIVED_AT] = GetTickCount();

	if (IsPlayerConnected(owner))
	{
		Gui_Notify(owner,"\"Here we are,\" says the coachman. \"Climb down; I'll take the cart back to where it stood.\"");
	}
}

Coach_HireIssue(h)
{
	new rider = s_CoachHires[h][E_CH_RIDER], Float:x, Float:y, Float:z, Float:a;

	if (!Rider_GetPos(rider,x,y,z,a))
	{
		return 0;
	}

	s_CoachHires[h][E_CH_MOVED_AT] = GetTickCount();

	switch (s_CoachHires[h][E_CH_PHASE])
	{
		case COACH_HIRE_APPROACH:
		{
			new point = s_CoachHires[h][E_CH_LINE_FROM];

			if (VectorSize(g_RoadsCoachRoute[point][0] - x,g_RoadsCoachRoute[point][1] - y,0.0) < COACH_HIRE_NEAR)
			{
				Coach_HireArrived(h);
				return 1;
			}

			NpcRiders_Ride(rider,g_RoadsCoachRoute[point][0],g_RoadsCoachRoute[point][1],g_RoadsCoachRoute[point][2],MOUNT_GAIT_SPRINT);
		}
		case COACH_HIRE_LINE:
		{
			new Float:gap, from = Coach_NearestPoint(x,y,gap), to = s_CoachHires[h][E_CH_LINE_TO];

			if (from == to)
			{
				Coach_HireArrived(h);
				return 1;
			}

			new Float:run[ROADS_COACH_POINTS * 3], count = Coach_BuildRun(from,to,run);
			NpcRiders_RideRoute(rider,run,count,MOUNT_GAIT_SPRINT,COACH_PULL);
		}
		case COACH_HIRE_FINAL:
		{
			if (VectorSize(s_CoachHires[h][E_CH_GOAL][0] - x,s_CoachHires[h][E_CH_GOAL][1] - y,0.0) < COACH_HIRE_NEAR)
			{
				Coach_HireArrived(h);
				return 1;
			}

			NpcRiders_Ride(rider,s_CoachHires[h][E_CH_GOAL][0],s_CoachHires[h][E_CH_GOAL][1],s_CoachHires[h][E_CH_GOAL][2],MOUNT_GAIT_SPRINT);
		}
	}

	return 1;
}

stock Coach_Hire(playerid,cart)
{
	if (!Carts_IsValid(cart) || Carts_GetMover(cart) != INVALID_PLAYER_ID)
	{
		return;
	}

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_CART] == cart)
		{
			Gui_Notify(playerid,"A coachman is already on the box.");
			return;
		}
	}

	new slot = -1;

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (!s_CoachHires[h][E_CH_USED])
		{
			slot = h;
			break;
		}
	}

	if (slot == -1)
	{
		Gui_Notify(playerid,"There's no coachman free to hire. Try again later.");
		return;
	}

	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width, money[24];
	Economy_Format(COACH_HIRE_FEE,money);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Where to?");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,260.0,float(sizeof(s_CoachDestNames)) * KIT_ROW + 6.0 + KIT_ROW + 12.0,"Where to?",x,y,width);

	for (new d = 0;d < sizeof(s_CoachDestNames);d++)
	{
		Kit_AddChoice(playerid,x,y + KIT_ROW * float(d),width,s_CoachDestNames[d],d,KIT_COLOUR_TEXT,money,KIT_COLOUR_ACCENT);
	}

	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(sizeof(s_CoachDestNames)) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch) || pick < 0 || pick >= sizeof(s_CoachDestNames) || !Carts_IsValid(cart) || Carts_GetMover(cart) != INVALID_PLAYER_ID || Carts_IsDriven(cart) || s_CoachHires[slot][E_CH_USED])
	{
		return;
	}

	if (Economy_Pay(playerid,COACH_HIRE_FEE,INVALID_CONTAINER_ID,"coachman") != PAY_OK)
	{
		Gui_Notify(playerid,"You can't pay the coachman.");
		return;
	}

	new Float:cx, Float:cy, Float:cz, Float:ca, Float:hx, Float:hy, Float:goalX, Float:goalY, Float:goalZ, skins = Skins_CountStarter(0);
	Carts_GetPos(cart,cx,cy,cz,ca);
	Carts_ShaftPoint(cart,hx,hy);
	new rider = NpcRiders_Create(sprintf("Coachman_%d",slot),skins > 0 ? Skins_GetStarter(0,(slot + 2) % skins) : 1,COACH_HORSE_TYPE,hx,hy,cz,ca + 180.0,0,COACH_TAG_HIRE);

	if (rider == INVALID_PLAYER_ID)
	{
		Economy_Give(playerid,COACH_HIRE_FEE,"coachman back");
		Gui_Notify(playerid,"No coachman could be found. Your coin is back.");
		return;
	}

    Carts_SetDriven(cart,true);
	s_CoachHires[slot][E_CH_USED] = true;
	s_CoachHires[slot][E_CH_CART] = cart;
	s_CoachHires[slot][E_CH_RIDER] = rider;
	s_CoachHires[slot][E_CH_OWNER] = playerid;
	s_CoachHires[slot][E_CH_ARRIVED_AT] = 0;
	s_CoachHires[slot][E_CH_DEST] = pick;
	s_CoachHires[slot][E_CH_HELD] = false;
	s_CoachHires[slot][E_CH_RETURNING] = false;
	s_CoachHires[slot][E_CH_HOME][0] = hx;
	s_CoachHires[slot][E_CH_HOME][1] = hy;
	s_CoachHires[slot][E_CH_HOME][2] = cz;
	s_CoachHires[slot][E_CH_HOME][3] = ca + 180.0;

	if (Carts_GetSeat(playerid) == -1)
	{
		Carts_Sit(playerid,cart,Carts_FreeSeat(cart));
	}

	Coach_GetHireDestGoal(pick,goalX,goalY,goalZ);
	Coach_HireTrip(slot,goalX,goalY,goalZ,s_CoachDestLine[pick]);
	Gui_Notify(playerid,sprintf("The coachman climbs on the box and drives for %s.",s_CoachDestNames[pick]));
}

static Coach_Follow(rider,cart)
{
	new Float:x, Float:y, Float:z, Float:a;

	if (Carts_IsValid(cart) && Rider_GetPos(rider,x,y,z,a))
	{
		Carts_Follow(cart,x,y,z,a);
	}
}

static Coach_ClearPrompt(playerid)
{
	if (s_CoachInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_CoachInfobox[playerid]);
	}

	s_CoachPrompt[playerid] = 0;
	s_CoachInfobox[playerid] = 0;
}

Timer_Declare(Coach_Tick)
{
	if (s_CoachRider != INVALID_PLAYER_ID)
	{
		Coach_Follow(s_CoachRider,s_CoachCart);

		if (s_CoachState == COACH_STATE_AT_STOP && gettime() >= s_CoachDepartAt && Coach_RunsNow())
		{
			Coach_Depart();
		}
	}

	new now = GetTickCount();

	for (new h = 0;h < COACH_HIRES;h++)
	{
		if (!s_CoachHires[h][E_CH_USED])
		{
			continue;
		}

		new cart = s_CoachHires[h][E_CH_CART], rider = s_CoachHires[h][E_CH_RIDER];

		if (!Carts_IsValid(cart) || !Rider_IsValid(rider))
		{
            Carts_SetDriven(cart,false);
			NpcRiders_Destroy(rider);
			s_CoachHires[h][E_CH_USED] = false;
			continue;
		}

		Coach_Follow(rider,cart);

		if (Rider_IsMoving(rider))
		{
			s_CoachHires[h][E_CH_MOVED_AT] = now;
		}
		else if (!s_CoachHires[h][E_CH_HELD] && s_CoachHires[h][E_CH_PHASE] != COACH_HIRE_WAIT && now - s_CoachHires[h][E_CH_MOVED_AT] > COACH_HIRE_STUCK_MS)
		{
			s_CoachHires[h][E_CH_MOVED_AT] = now;
			Coach_HireArrived(h);
		}
		else if (s_CoachHires[h][E_CH_PHASE] == COACH_HIRE_WAIT && now - s_CoachHires[h][E_CH_ARRIVED_AT] > s_CoachHireWait)
		{
			Coach_HireSendHome(h);
		}
	}

	return 1;
}

Timer_Declare(Coach_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

        new bool:near = Coach_CanPrompt(playerid);

		if (!near)
		{
			Coach_ClearPrompt(playerid);
			continue;
		}

        if (Actors_GetPromptTarget(playerid) != -1)
        {
            Actors_ClearPrompt(playerid);
        }

		if (s_CoachPrompt[playerid] == 1 && Infobox_IsShown(playerid,s_CoachInfobox[playerid]))
		{
			continue;
		}

		s_CoachPrompt[playerid] = 1;
		s_CoachInfobox[playerid] = Infobox_ShowPrompt(playerid,s_CoachInfobox[playerid],"The coach","Press ~y~Y~w~ to buy a seat.",3);
	}

	return 1;
}

forward bool:Coach_PromptContext(playerid);

public bool:Coach_PromptContext(playerid)
{
	return s_CoachPrompt[playerid] == 1 && Coach_CanPrompt(playerid);
}

forward Coach_BoardDeferred(playerid);

public Coach_BoardDeferred(playerid)
{
	if (IsPlayerConnected(playerid))
	{
		Coach_OpenBoard(playerid);
	}

	return 1;
}

forward Coach_HireDeferred(playerid,cart);

public Coach_HireDeferred(playerid,cart)
{
	if (IsPlayerConnected(playerid))
	{
		Coach_Hire(playerid,cart);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_CoachDest[playerid] = -1;
	s_CoachPrompt[playerid] = 0;
	s_CoachInfobox[playerid] = 0;
	s_CoachTollOwed[playerid] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && s_CoachPrompt[playerid] == 1 && Coach_CanPrompt(playerid) && !Infobox_IsPromptBlocked(playerid,s_CoachInfobox[playerid]) && !Keys_IsBusy(playerid,KEY_YES,INFOBOX_TARGET_PRIORITY))
	{
		Coach_ClearPrompt(playerid);
		SetTimerEx("Coach_BoardDeferred",0,false,"d",playerid);
	}
}

hook NpcRiders_OnArrive(riderid,tag)
{
	if (tag == COACH_TAG_LINE && riderid == s_CoachRider)
	{
		Coach_Arrive();
		return;
	}

	if (tag == COACH_TAG_HIRE)
	{
		for (new h = 0;h < COACH_HIRES;h++)
		{
			if (s_CoachHires[h][E_CH_USED] && s_CoachHires[h][E_CH_RIDER] == riderid)
			{
				Coach_HireArrived(h);
				return;
			}
		}
	}
}

hook Carts_OnHireCoachman(playerid,cart)
{
	SetTimerEx("Coach_HireDeferred",0,false,"dd",playerid,cart);
}

forward Float:Coach_TargetDistance(playerid);
public Float:Coach_TargetDistance(playerid)
{
    new Float:distance;
    return Coach_GetPromptDistance(playerid,distance,true,false) ? distance : -1.0;
}

forward Coach_TargetRefresh(playerid);
public Coach_TargetRefresh(playerid)
{
    if (Coach_CanPrompt(playerid))
    {
        s_CoachPrompt[playerid] = 1;
        if (!Infobox_IsShown(playerid,s_CoachInfobox[playerid]))
        {
            s_CoachInfobox[playerid] = Infobox_ShowPrompt(playerid,s_CoachInfobox[playerid],"The coach","Press ~y~Y~w~ to buy a seat.",3);
        }
    }
    return 1;
}

forward Coach_TargetClear(playerid);
public Coach_TargetClear(playerid)
{
    Coach_ClearPrompt(playerid);
    return 1;
}
