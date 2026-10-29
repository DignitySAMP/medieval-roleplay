#define BANDITS_PED_KIND (40)
#define BANDITS_MAX (3)
#define BANDITS_AMBUSHES (2)
#define BANDITS_TICK_MS (1000)
#define BANDITS_TRIGGER_RANGE (60.0)
#define BANDITS_TALK_RANGE (6.0)
#define BANDITS_HIT_RANGE (1.9)
#define BANDITS_GIVE_UP (70.0)
#define BANDITS_PATROL_SAFE (150.0)
#define BANDITS_CHANCE (35)
#define BANDITS_CHANCE_WINTER (55)
#define BANDITS_POINT_COOLDOWN (1200)
#define BANDITS_PLAYER_COOLDOWN (1800)
#define BANDITS_ANSWER_SECONDS (20)
#define BANDITS_HIT_MS (1500)
#define BANDITS_DAMAGE (7.0)
#define BANDITS_STRUCK_DOWN (20.0)
#define BANDITS_HEALTH (60.0)
#define BANDITS_RUN_SPEED (5.0)
#define BANDITS_WALK_SPEED (1.2)

enum
{
	BANDITS_STATE_NONE,
	BANDITS_STATE_CLOSING,
	BANDITS_STATE_DEMANDING,
	BANDITS_STATE_FIGHTING,
	BANDITS_STATE_LEAVING,
}

enum E_BANDITS_AMBUSH
{
	bool:E_BA_USED,
	E_BA_STATE,
	E_BA_POINT,
	E_BA_VICTIM,
	E_BA_ACTORS[BANDITS_MAX],
	E_BA_COUNT,
	E_BA_DEMAND,
	E_BA_STATE_AT,
	E_BA_HIT_AT,
	E_BA_PURSE,
	E_BA_STARTED,
}

static s_BanditAmbush[BANDITS_AMBUSHES][E_BANDITS_AMBUSH];
static s_BanditPointUntil[ROADS_SEED_AMBUSHES + 1];
static s_BanditPlayerUntil[MAX_PLAYERS];
static bool:s_BanditInRange[MAX_PLAYERS][ROADS_SEED_AMBUSHES + 1];
static s_BanditForce = -1;
static const s_BanditLoot[] = {ITEM_CRUDE_AXE, ITEM_FLINT_KNIFE, ITEM_KNIFE};

static const s_BanditDemands[][96] = {
	"Halt! Your purse or your hide, traveller.",
	"Easy now. Hand over the coin and you ride on whole.",
	"This road has a toll tonight. Pay it."
};

stock Bandits_SetForce(value)
{
	s_BanditForce = value;
}

stock Bandits_Demand(worth)
{
	return Util_ClampInt(worth / 4,10,240);
}

stock bool:Bandits_IsWinter()
{
	return Calendar_GetSeason() == SEASON_WINTER;
}

stock Bandits_CountFor(bool:winter)
{
	return winter ? 3 : 2;
}

stock Bandits_GetAmbushOf(playerid)
{
	for (new a = 0;a < BANDITS_AMBUSHES;a++)
	{
		if (s_BanditAmbush[a][E_BA_USED] && s_BanditAmbush[a][E_BA_VICTIM] == playerid)
		{
			return a;
		}
	}

	return -1;
}

stock Bandits_GetState(ambush)
{
	return ambush >= 0 && ambush < BANDITS_AMBUSHES && s_BanditAmbush[ambush][E_BA_USED] ? s_BanditAmbush[ambush][E_BA_STATE] : BANDITS_STATE_NONE;
}

stock Bandits_FindOfActor(actorid)
{
	for (new a = 0;a < BANDITS_AMBUSHES;a++)
	{
		if (!s_BanditAmbush[a][E_BA_USED])
		{
			continue;
		}

		for (new i = 0;i < s_BanditAmbush[a][E_BA_COUNT];i++)
		{
			if (s_BanditAmbush[a][E_BA_ACTORS][i] == actorid)
			{
				return a;
			}
		}
	}

	return -1;
}

static Bandits_Say(ambush,const text[])
{
	new actorid = s_BanditAmbush[ambush][E_BA_ACTORS][0], Float:x, Float:y, Float:z;

	if (IsValidPedestrian(actorid) != 1)
	{
		return;
	}

	GetPedestrianPos(actorid,x,y,z);

	foreach (new playerid : Player)
	{
		if (IsPlayerInRangeOfPoint(playerid,25.0,x,y,z))
		{
			SendClientMessage(playerid,0xC9A66BFF,sprintf("Bandit says: %s",text));
		}
	}
}

stock Bandits_End(ambush)
{
	if (ambush < 0 || ambush >= BANDITS_AMBUSHES || !s_BanditAmbush[ambush][E_BA_USED])
	{
		return;
	}

	for (new i = 0;i < s_BanditAmbush[ambush][E_BA_COUNT];i++)
	{
		new actorid = s_BanditAmbush[ambush][E_BA_ACTORS][i];

		if (IsValidPedestrian(actorid) != 0)
		{
			DespawnPedestrian(actorid);
		}
	}

	new victim = s_BanditAmbush[ambush][E_BA_VICTIM];

	if (victim != INVALID_PLAYER_ID && IsPlayerConnected(victim))
	{
		pawn_call_public("Bandits_OnEnded","dd",victim,s_BanditAmbush[ambush][E_BA_STATE]);
	}

	s_BanditAmbush[ambush][E_BA_USED] = false;
}

static Bandits_Leave(ambush)
{
	s_BanditAmbush[ambush][E_BA_STATE] = BANDITS_STATE_LEAVING;
	s_BanditAmbush[ambush][E_BA_STATE_AT] = gettime();
	new point = s_BanditAmbush[ambush][E_BA_POINT];

	for (new i = 0;i < s_BanditAmbush[ambush][E_BA_COUNT];i++)
	{
		new actorid = s_BanditAmbush[ambush][E_BA_ACTORS][i];

		if (IsValidPedestrian(actorid) == 1)
		{
			PedestrianFleeFrom(actorid,g_RoadsAmbushes[point][0],g_RoadsAmbushes[point][1],g_RoadsAmbushes[point][2],20000);
		}
	}
}

stock Bandits_Start(playerid,point)
{
	new ambush = -1;

	for (new a = 0;a < BANDITS_AMBUSHES;a++)
	{
		if (!s_BanditAmbush[a][E_BA_USED])
		{
			ambush = a;
			break;
		}
	}

	if (ambush == -1)
	{
		return -1;
	}

	new Float:px, Float:py, Float:pz, Float:pa, count = Bandits_CountFor(Bandits_IsWinter()), spawned = 0, skins = Skins_CountStarter(0);
	GetPlayerPos(playerid,px,py,pz);
	GetPlayerFacingAngle(playerid,pa);

	for (new i = 0;i < count;i++)
	{
		new Float:ang = pa + float(i - 1) * 35.0, Float:dist = 18.0 + float(i) * 3.0, Float:x = px + floatsin(-ang,degrees) * dist, Float:y = py + floatcos(-ang,degrees) * dist, Float:hx, Float:hy, Float:hz;

		if (CA_RayCastLine(x,y,pz + 10.0,x,y,pz - 15.0,hx,hy,hz) == 0)
		{
			continue;
		}

		new actorid = SpawnPedestrianAt(skins > 0 ? Skins_GetStarter(0,random(skins)) : 1,x,y,hz + 1.0,ang + 180.0,BANDITS_PED_KIND);

		if (actorid < 0)
		{
			continue;
		}

		SetPedestrianBody(actorid,PED_BODY_PEOPLE);
		SetPedestrianHealth(actorid,BANDITS_HEALTH);
		s_BanditAmbush[ambush][E_BA_ACTORS][spawned++] = actorid;
	}

	if (spawned == 0)
	{
		return -1;
	}

	s_BanditAmbush[ambush][E_BA_USED] = true;
	s_BanditAmbush[ambush][E_BA_STATE] = BANDITS_STATE_CLOSING;
	s_BanditAmbush[ambush][E_BA_POINT] = point;
	s_BanditAmbush[ambush][E_BA_VICTIM] = playerid;
	s_BanditAmbush[ambush][E_BA_COUNT] = spawned;
	s_BanditAmbush[ambush][E_BA_DEMAND] = Bandits_Demand(Economy_Worth(playerid));
	s_BanditAmbush[ambush][E_BA_STATE_AT] = gettime();
	s_BanditAmbush[ambush][E_BA_STARTED] = gettime();
	s_BanditAmbush[ambush][E_BA_HIT_AT] = 0;
	s_BanditAmbush[ambush][E_BA_PURSE] = 5 + random(26);
	s_BanditPointUntil[point] = gettime() + BANDITS_POINT_COOLDOWN;
	s_BanditPlayerUntil[playerid] = gettime() + BANDITS_PLAYER_COOLDOWN;
	pawn_call_public("Bandits_OnAmbush","dd",playerid,ambush);
	return ambush;
}

stock bool:Bandits_Pay(playerid)
{
	new ambush = Bandits_GetAmbushOf(playerid);

	if (ambush == -1 || s_BanditAmbush[ambush][E_BA_STATE] != BANDITS_STATE_DEMANDING)
	{
		return false;
	}

	new demand = s_BanditAmbush[ambush][E_BA_DEMAND];

	if (Economy_Pay(playerid,demand,INVALID_CONTAINER_ID,"bandits") != PAY_OK)
	{
		return false;
	}

	s_BanditAmbush[ambush][E_BA_PURSE] += demand;
	Bandits_Say(ambush,"Wise. Ride on, and don't look back.");
	Bandits_Leave(ambush);
	return true;
}

stock Bandits_Refuse(playerid)
{
	new ambush = Bandits_GetAmbushOf(playerid);

	if (ambush == -1 || s_BanditAmbush[ambush][E_BA_STATE] > BANDITS_STATE_DEMANDING)
	{
		return;
	}

	s_BanditAmbush[ambush][E_BA_STATE] = BANDITS_STATE_FIGHTING;
	s_BanditAmbush[ambush][E_BA_STATE_AT] = gettime();
	Bandits_Say(ambush,"The hard way, then. Take him!");
}

stock Bandits_StrikeDown(ambush)
{
	new playerid = s_BanditAmbush[ambush][E_BA_VICTIM], take = Economy_Worth(playerid) / 3;

	if (take > 0 && Economy_Pay(playerid,take,INVALID_CONTAINER_ID,"robbed by bandits") == PAY_OK)
	{
		s_BanditAmbush[ambush][E_BA_PURSE] += take;
	}

	ApplyAnimation(playerid,"PED","KO_shot_stom",4.1,false,true,true,true,0,SYNC_ALL);
	new money[24];
	Economy_Format(take,money);
	Gui_Notify(playerid,take > 0 ? sprintf("You're beaten to the ground. They cut your purse: %s gone.",money) : sprintf("You're beaten to the ground. They find nothing worth taking.%s",""));
	Bandits_Say(ambush,"That'll teach him. Off, before the guard comes!");
	Bandits_Leave(ambush);
}

static Bandits_Loot(ambush,actorid)
{
	new Float:x, Float:y, Float:z, counts[COIN_TIER_COUNT], share = s_BanditAmbush[ambush][E_BA_PURSE] / max(s_BanditAmbush[ambush][E_BA_COUNT],1);
	GetPedestrianPos(actorid,x,y,z);
	Economy_Split(share,counts);

	for (new tier = COIN_PFENNIG;tier < COIN_TIER_COUNT;tier++)
	{
		if (counts[tier] > 0)
		{
			Drop_Create(ITEM_KIND_COIN,tier,counts[tier],x + 0.3 * float(tier),y,z - 0.95,0);
		}
	}

	new item = s_BanditLoot[random(sizeof(s_BanditLoot))];
	Drop_Create(Item_GetDefKind(item),item,1,x,y + 0.4,z - 0.95,0);
}

Timer_Declare(Bandits_Tick)
{
	new now = gettime();

	for (new a = 0;a < BANDITS_AMBUSHES;a++)
	{
		if (!s_BanditAmbush[a][E_BA_USED])
		{
			continue;
		}

		new playerid = s_BanditAmbush[a][E_BA_VICTIM], alive = 0;

		for (new i = 0;i < s_BanditAmbush[a][E_BA_COUNT];i++)
		{
			if (IsValidPedestrian(s_BanditAmbush[a][E_BA_ACTORS][i]) == 1)
			{
				alive++;
			}
		}

		if (alive == 0 || !IsPlayerConnected(playerid) || now - s_BanditAmbush[a][E_BA_STARTED] > 300 || (s_BanditAmbush[a][E_BA_STATE] == BANDITS_STATE_LEAVING && now - s_BanditAmbush[a][E_BA_STATE_AT] > 25))
		{
			Bandits_End(a);
			continue;
		}

		if (s_BanditAmbush[a][E_BA_STATE] == BANDITS_STATE_LEAVING)
		{
			continue;
		}

		new Float:px, Float:py, Float:pz, Float:nearest = 1000.0, closest = -1;
		GetPlayerPos(playerid,px,py,pz);

		for (new i = 0;i < s_BanditAmbush[a][E_BA_COUNT];i++)
		{
			new actorid = s_BanditAmbush[a][E_BA_ACTORS][i], Float:x, Float:y, Float:z;

			if (IsValidPedestrian(actorid) != 1)
			{
				continue;
			}

			GetPedestrianPos(actorid,x,y,z);
			new Float:d = VectorSize(px - x,py - y,pz - z);

			if (d < nearest)
			{
				nearest = d;
				closest = actorid;
			}

			if (d > BANDITS_HIT_RANGE)
			{
				SetPedestrianTarget(actorid,px,py,pz,s_BanditAmbush[a][E_BA_STATE] == BANDITS_STATE_FIGHTING ? BANDITS_RUN_SPEED : BANDITS_WALK_SPEED);
			}
			else
			{
				StopPedestrian(actorid);
				SetPedestrianFacingAngle(actorid,atan2(py - y,px - x) - 90.0);
			}
		}

		if (Roads_PatrolNear(px,py,60.0))
		{
			Bandits_Say(a,"The road wardens! Scatter!");
			Gui_Notify(playerid,"The road wardens are coming. The bandits run.");
			Bandits_Leave(a);
			continue;
		}

		if (nearest > BANDITS_GIVE_UP)
		{
			Gui_Notify(playerid,"You leave the bandits behind in the dark.");
			Bandits_Leave(a);
			continue;
		}

		switch (s_BanditAmbush[a][E_BA_STATE])
		{
			case BANDITS_STATE_CLOSING:
			{
				if (nearest <= BANDITS_TALK_RANGE)
				{
					new money[24];
					Economy_Format(s_BanditAmbush[a][E_BA_DEMAND],money);
					s_BanditAmbush[a][E_BA_STATE] = BANDITS_STATE_DEMANDING;
					s_BanditAmbush[a][E_BA_STATE_AT] = now;
					Bandits_Say(a,s_BanditDemands[random(sizeof(s_BanditDemands))]);
					Gui_Notify(playerid,sprintf("Bandits bar the road. They want %s. Press Y to answer, or %s for it.",money,Mount_IsRiding(playerid) ? ("ride") : ("run")));
					pawn_call_public("Bandits_OnDemand","dd",playerid,s_BanditAmbush[a][E_BA_DEMAND]);
				}
			}
			case BANDITS_STATE_DEMANDING:
			{
				if (now - s_BanditAmbush[a][E_BA_STATE_AT] > BANDITS_ANSWER_SECONDS)
				{
					Bandits_Refuse(playerid);
				}
			}
			case BANDITS_STATE_FIGHTING:
			{
				if (closest == -1 || nearest > BANDITS_HIT_RANGE || GetTickCount() - s_BanditAmbush[a][E_BA_HIT_AT] < BANDITS_HIT_MS)
				{
					continue;
				}

				s_BanditAmbush[a][E_BA_HIT_AT] = GetTickCount();
				ApplyPedestrianAnim(closest,"FIGHT_B","FightB_1",4.1,0,1,1,0,0);

				if (Mount_IsRiding(playerid))
				{
					Mount_Throw(playerid,"A bandit drags you out of the saddle.",3.0);
					continue;
				}

				if (Vitals_GetHealth(playerid) - BANDITS_DAMAGE <= BANDITS_STRUCK_DOWN)
				{
					Bandits_StrikeDown(a);
					continue;
				}

				Vitals_Damage(playerid,BANDITS_DAMAGE,"a bandit's club");
			}
		}
	}

	if (!Calendar_IsNight() && s_BanditForce != 1)
	{
		return 1;
	}

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
		{
			continue;
		}

		for (new point = 0;point < ROADS_SEED_AMBUSHES;point++)
		{
			new bool:inside = IsPlayerInRangeOfPoint(playerid,BANDITS_TRIGGER_RANGE,g_RoadsAmbushes[point][0],g_RoadsAmbushes[point][1],g_RoadsAmbushes[point][2] + 1.0);

			if (inside && !s_BanditInRange[playerid][point] && now >= s_BanditPointUntil[point] && now >= s_BanditPlayerUntil[playerid] && Bandits_GetAmbushOf(playerid) == -1 && !Roads_PatrolNear(g_RoadsAmbushes[point][0],g_RoadsAmbushes[point][1],BANDITS_PATROL_SAFE))
			{
				if (s_BanditForce == 1 || random(100) < (Bandits_IsWinter() ? BANDITS_CHANCE_WINTER : BANDITS_CHANCE))
				{
					Bandits_Start(playerid,point);
				}
				else
				{
					s_BanditPlayerUntil[playerid] = now + 120;
				}
			}

			s_BanditInRange[playerid][point] = inside;
		}
	}

	return 1;
}

forward Bandits_OnAmbush(playerid,ambush);

public Bandits_OnAmbush(playerid,ambush)
{
	return 1;
}

forward Bandits_OnDemand(playerid,amount);

public Bandits_OnDemand(playerid,amount)
{
	return 1;
}

forward Bandits_OnEnded(playerid,lastState);

public Bandits_OnEnded(playerid,lastState)
{
	return 1;
}

forward bool:Bandits_KeyContext(playerid);

public bool:Bandits_KeyContext(playerid)
{
	new ambush = Bandits_GetAmbushOf(playerid);
	return ambush != -1 && s_BanditAmbush[ambush][E_BA_STATE] == BANDITS_STATE_DEMANDING;
}

forward Bandits_AnswerDeferred(playerid);

public Bandits_AnswerDeferred(playerid)
{
	if (!IsPlayerConnected(playerid) || !Bandits_KeyContext(playerid))
	{
		return 1;
	}

	new ambush = Bandits_GetAmbushOf(playerid), money[24], label[48], epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Economy_Format(s_BanditAmbush[ambush][E_BA_DEMAND],money);
	format(label,sizeof(label),"Pay them (%s)",money);
	Kit_Begin(playerid,KIT_LAYER_SCREEN,"Bandits");
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,240.0,KIT_ROW * 2.0 + 6.0 + KIT_ROW + 12.0,"Bandits",x,y,width);
	Kit_AddChoice(playerid,x,y,width,label,1,KIT_COLOUR_TEXT);
	Kit_AddChoice(playerid,x,y + KIT_ROW,width,"Refuse and fight",2,KIT_COLOUR_BAD);
	Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + KIT_ROW * 2.0 + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);
	new pick = await Kit_Present(playerid);
	Kit_Close(playerid);

	if (!Gui_IsFlowCurrent(playerid,epoch))
	{
		return 1;
	}

	if (pick == 1)
	{
		if (!Bandits_Pay(playerid))
		{
			Gui_Notify(playerid,"You haven't the coin. They don't like that.");
			Bandits_Refuse(playerid);
		}
	}
	else if (pick == 2)
	{
		Bandits_Refuse(playerid);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_BanditPlayerUntil[playerid] = 0;

	for (new point = 0;point <= ROADS_SEED_AMBUSHES;point++)
	{
		s_BanditInRange[playerid][point] = false;
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	new ambush = Bandits_GetAmbushOf(playerid);

	if (ambush != -1)
	{
		Bandits_End(ambush);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && Bandits_KeyContext(playerid) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU))
	{
		SetTimerEx("Bandits_AnswerDeferred",0,false,"d",playerid);
	}
}

hook OnPedestrianGetDamage(pedestrianid,playerid,weaponid,Float:amount)
{
	#pragma unused weaponid, amount

	new ambush = Bandits_FindOfActor(pedestrianid);

	if (ambush != -1 && s_BanditAmbush[ambush][E_BA_STATE] < BANDITS_STATE_FIGHTING && s_BanditAmbush[ambush][E_BA_VICTIM] == playerid)
	{
		Bandits_Refuse(playerid);
	}
}

hook OnPedestrianDeath(actorid,killerid,reason)
{
	#pragma unused killerid, reason

	new ambush = Bandits_FindOfActor(actorid);

	if (ambush != -1)
	{
		Bandits_Loot(ambush,actorid);
	}
}
