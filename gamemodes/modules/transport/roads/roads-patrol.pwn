#define ROADS_PATROLS (2)
#define ROADS_PATROL_WATCH (200.0)
#define ROADS_PATROL_PACE_MS (5000)

static s_RoadsPatrolActor[ROADS_PATROLS] = {-1, ...};
static s_RoadsPatrolNext[ROADS_PATROLS];
static s_RoadsPatrolToken[ROADS_PATROLS];
static s_RoadsPatrolLegMs[ROADS_PATROLS];
static s_RoadsPatrolArrivalPoint[ROADS_PATROLS] = {-1, ...};
static Float:s_RoadsPatrolArrivalPos[ROADS_PATROLS][3];
static s_RoadsPatrolPoints = ROADS_PATROL_POINTS;
static const s_RoadsPatrolNames[ROADS_PATROLS][24] = {"Hanus Strazny", "Vojta Pochuzka"};

stock Roads_GetPatrolActor(patrol)
{
	return patrol >= 0 && patrol < ROADS_PATROLS ? s_RoadsPatrolActor[patrol] : -1;
}

stock Roads_GetPatrolNext(patrol)
{
	return patrol >= 0 && patrol < ROADS_PATROLS ? s_RoadsPatrolNext[patrol] : -1;
}

stock Roads_GetPatrolArrival(patrol,&Float:x,&Float:y,&Float:z)
{
    if (patrol < 0 || patrol >= ROADS_PATROLS)
    {
        return -1;
    }

    x = s_RoadsPatrolArrivalPos[patrol][0];
    y = s_RoadsPatrolArrivalPos[patrol][1];
    z = s_RoadsPatrolArrivalPos[patrol][2];
    return s_RoadsPatrolArrivalPoint[patrol];
}

stock bool:Roads_PatrolNear(Float:x,Float:y,Float:range)
{
	for (new patrol = 0;patrol < ROADS_PATROLS;patrol++)
	{
		new actor = s_RoadsPatrolActor[patrol], Float:ax, Float:ay, Float:az, Float:aa;

		if (actor == -1 || !Actors_IsPlaced(actor) || Actors_IsDead(actor))
		{
			continue;
		}

		Actors_GetPos(actor,ax,ay,az,aa);

		if (VectorSize(ax - x,ay - y,0.0) <= range)
		{
			return true;
		}
	}

	return false;
}

static bool:Roads_PatrolWatched(actor)
{
	new Float:x, Float:y, Float:z, Float:a;
	Actors_GetPos(actor,x,y,z,a);

	foreach (new playerid : Player)
	{
		new Float:px, Float:py, Float:pz;

		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0)
		{
			continue;
		}

		GetPlayerPos(playerid,px,py,pz);

		if (IsActorStreamedIn(Actors_GetBody(actor),playerid) || VectorSize(px - x,py - y,0.0) <= ROADS_PATROL_WATCH)
		{
			return true;
		}
	}

	return false;
}

static Roads_PatrolStep(patrol)
{
	new actor = s_RoadsPatrolActor[patrol];

	if (actor == -1 || s_RoadsPatrolPoints < 2 || Actors_IsDead(actor))
	{
		return;
	}

	new next = s_RoadsPatrolNext[patrol], token = ++s_RoadsPatrolToken[patrol];

	if (Roads_PatrolWatched(actor))
	{
		Actors_WalkTo(actor,g_RoadsPatrol[next][0],g_RoadsPatrol[next][1],g_RoadsPatrol[next][2],0.0);
		return;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Actors_GetPos(actor,x,y,z,a);
	s_RoadsPatrolLegMs[patrol] = floatround(VectorSize(g_RoadsPatrol[next][0] - x,g_RoadsPatrol[next][1] - y,0.0) / ACTORS_WALK_SPEED * 1000.0);
	SetTimerEx("Roads_PatrolPace",ROADS_PATROL_PACE_MS,false,"ddd",patrol,token,next);
}

stock Roads_PlacePatrols()
{
	if (s_RoadsPatrolPoints < 2)
	{
		return 0;
	}

	new placed = 0;

	for (new patrol = 0;patrol < ROADS_PATROLS;patrol++)
	{
		new key[16], start = (patrol * ROADS_PATROL_POINTS / ROADS_PATROLS) % ROADS_PATROL_POINTS;
		format(key,sizeof(key),"patrol:%d",patrol);
		new actor = Actors_Register(key,ACTOR_ROLE_GUARD,ACTOR_KIND_WALKER,0,Skins_GetGuard(),s_RoadsPatrolNames[patrol],"Road warden");

		if (actor == -1)
		{
			continue;
		}

		s_RoadsPatrolActor[patrol] = actor;
		s_RoadsPatrolNext[patrol] = (start + 1) % ROADS_PATROL_POINTS;
		Actors_SetPlace(actor,g_RoadsPatrol[start][0],g_RoadsPatrol[start][1],g_RoadsPatrol[start][2],0.0,0,0);
		Actors_Place(actor);
		Roads_PatrolStep(patrol);
		placed++;
	}

	return placed;
}

forward Roads_PatrolPace(patrol,token,point);

public Roads_PatrolPace(patrol,token,point)
{
	new actor = s_RoadsPatrolActor[patrol];

	if (token != s_RoadsPatrolToken[patrol] || actor == -1 || Actors_IsDead(actor))
	{
		return 1;
	}

	s_RoadsPatrolLegMs[patrol] -= ROADS_PATROL_PACE_MS;

	if (Roads_PatrolWatched(actor))
	{
		Actors_WalkTo(actor,g_RoadsPatrol[point][0],g_RoadsPatrol[point][1],g_RoadsPatrol[point][2],0.0);
		return 1;
	}

	if (s_RoadsPatrolLegMs[patrol] > 0)
	{
		SetTimerEx("Roads_PatrolPace",ROADS_PATROL_PACE_MS,false,"ddd",patrol,token,point);
		return 1;
	}

	Actors_MoveTo(actor,g_RoadsPatrol[point][0],g_RoadsPatrol[point][1],g_RoadsPatrol[point][2],0.0,0,0);
	s_RoadsPatrolNext[patrol] = (point + 1) % ROADS_PATROL_POINTS;
	Roads_PatrolStep(patrol);
	return 1;
}

#include <pp-hooks>

hook Actors_OnArrived(index)
{
	for (new patrol = 0;patrol < ROADS_PATROLS;patrol++)
	{
		if (s_RoadsPatrolActor[patrol] == index)
		{
			new Float:angle;
			s_RoadsPatrolArrivalPoint[patrol] = s_RoadsPatrolNext[patrol];
			Actors_GetPos(index,s_RoadsPatrolArrivalPos[patrol][0],s_RoadsPatrolArrivalPos[patrol][1],s_RoadsPatrolArrivalPos[patrol][2],angle);
			Actors_SetPlace(index,s_RoadsPatrolArrivalPos[patrol][0],s_RoadsPatrolArrivalPos[patrol][1],s_RoadsPatrolArrivalPos[patrol][2],angle,0,0);
			s_RoadsPatrolNext[patrol] = (s_RoadsPatrolNext[patrol] + 1) % ROADS_PATROL_POINTS;
			Roads_PatrolStep(patrol);
			return;
		}
	}
}

hook Actors_OnRespawn(index)
{
	for (new patrol = 0;patrol < ROADS_PATROLS;patrol++)
	{
		if (s_RoadsPatrolActor[patrol] == index)
		{
			Roads_PatrolStep(patrol);
			return;
		}
	}
}
