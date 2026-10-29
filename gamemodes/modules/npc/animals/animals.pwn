#define ANIMALS_ARROW_FACTOR (5.0)
#define ANIMALS_BODY_LIFT (1.0)
#define ANIMALS_PLACES (ANIMALS_SEED_FOREST + ANIMALS_SEED_MEADOW + ANIMALS_SEED_WATER + ANIMALS_SEED_DENS)

enum E_ANIMAL
{
	bool:E_ANIMAL_USED,
	E_ANIMAL_ACTOR,
	E_ANIMAL_SPECIES,
	E_ANIMAL_STATE,
	Float:E_ANIMAL_HOME[3],
	Float:E_ANIMAL_CHASE_FROM[3],
	E_ANIMAL_CHASE_TICK,
	E_ANIMAL_CHASE_REST_UNTIL,
	E_ANIMAL_PLACE,
	E_ANIMAL_TARGET,
	E_ANIMAL_HIT_BY,
	E_ANIMAL_HIT_TICK,
	E_ANIMAL_HITS,
	E_ANIMAL_NEXT_TICK,
	E_ANIMAL_BITE_TICK,
	E_ANIMAL_STATE_UNTIL,
	E_ANIMAL_HELD_BY,
	STREAMER_TAG_3D_TEXT_LABEL:E_ANIMAL_LABEL,
	E_ANIMAL_GAIT,
	bool:E_ANIMAL_FEMALE,
	bool:E_ANIMAL_WET,
	Float:E_ANIMAL_WATER_LEVEL,
	STREAMER_TAG_OBJECT:E_ANIMAL_SWIM_OBJECT,
	Float:E_ANIMAL_SWIM_Z,
	E_ANIMAL_WORLD,
	E_ANIMAL_MODE,
	E_ANIMAL_HERD_ID,
	Float:E_ANIMAL_CAUSE[3],
	Float:E_ANIMAL_LEFT,
	Float:E_ANIMAL_GOAL[3],
	Float:E_ANIMAL_LEG_FROM[3],
	Float:E_ANIMAL_LEG_LENGTH,
	bool:E_ANIMAL_LEG_ON,
	E_ANIMAL_LEG_FAILS,
	E_ANIMAL_STILL,
	Float:E_ANIMAL_LAST[2],
	E_ANIMAL_ALERT_TICK,
	E_ANIMAL_WARY_UNTIL,
	bool:E_ANIMAL_EASING,
	E_ANIMAL_CORNER_UNTIL,
	E_ANIMAL_PATH_FAILS,
}

static s_Animals[ANIMALS_MAX][E_ANIMAL];
static s_AnimalsHerdSeq = 0;
static bool:s_AnimalsAlarming = false;
static Float:s_AnimalsPlayerPos[MAX_PLAYERS][3];
static Float:s_AnimalsPlayerSpeed[MAX_PLAYERS];
static s_AnimalsPlayerTick = 0;
static s_AnimalsHerdBack[sizeof(g_AnimalsHerd)];
static bool:s_AnimalsWild = true;
static s_AnimalsRouteFails = 0;
static s_AnimalsRouteRefused = 0;

stock bool:Animals_IsValid(animal)
{
	return animal >= 0 && animal < ANIMALS_MAX && s_Animals[animal][E_ANIMAL_USED];
}

stock Animals_GetActor(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_ACTOR] : -1;
}

stock Animals_GetSpecies(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_SPECIES] : -1;
}

stock Animals_GetState(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_STATE] : ANIMAL_STATE_DEAD;
}

stock Animals_GetTarget(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_TARGET] : INVALID_PLAYER_ID;
}

stock Animals_GetHits(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_HITS] : 0;
}

stock Animals_GetMode(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_MODE] : ANIMAL_MODE_GRAZE;
}

stock Animals_GetHerd(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_HERD_ID] : -1;
}

stock Animals_RouteFails()
{
	return s_AnimalsRouteFails;
}

stock Animals_RouteRefused()
{
	return s_AnimalsRouteRefused;
}

stock Animals_NewHerd()
{
	return ++s_AnimalsHerdSeq;
}

stock Animals_HerdLeader(animal)
{
	if (!Animals_IsValid(animal))
	{
		return -1;
	}

	new herd = s_Animals[animal][E_ANIMAL_HERD_ID];

	if (herd < 0)
	{
		return animal;
	}

	for (new i = 0;i < ANIMALS_MAX;i++)
	{
		if (s_Animals[i][E_ANIMAL_USED] && s_Animals[i][E_ANIMAL_HERD_ID] == herd && s_Animals[i][E_ANIMAL_STATE] != ANIMAL_STATE_DEAD && s_Animals[i][E_ANIMAL_STATE] != ANIMAL_STATE_HELD)
		{
			return i;
		}
	}

	return animal;
}

stock Animals_HerdSize(animal)
{
	if (!Animals_IsValid(animal))
	{
		return 0;
	}

	new herd = s_Animals[animal][E_ANIMAL_HERD_ID], count = 0;

	if (herd < 0)
	{
		return 1;
	}

	for (new i = 0;i < ANIMALS_MAX;i++)
	{
		if (s_Animals[i][E_ANIMAL_USED] && s_Animals[i][E_ANIMAL_HERD_ID] == herd && s_Animals[i][E_ANIMAL_STATE] != ANIMAL_STATE_DEAD)
		{
			count++;
		}
	}

	return count;
}

stock bool:Animals_IsFemale(animal)
{
	return animal >= 0 && animal < ANIMALS_MAX && s_Animals[animal][E_ANIMAL_FEMALE];
}

stock Animals_FindByActor(actorid)
{
    if (!IsValidPedestrian(actorid))
    {
        return -1;
    }

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (s_Animals[animal][E_ANIMAL_USED] && s_Animals[animal][E_ANIMAL_ACTOR] == actorid && GetPedestrianKind(actorid) == ANIMALS_KIND_BASE + s_Animals[animal][E_ANIMAL_SPECIES])
		{
			return animal;
		}
	}

	return -1;
}

stock Animals_Count(species = -1)
{
	new count = 0;

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (s_Animals[animal][E_ANIMAL_USED] && (species == -1 || s_Animals[animal][E_ANIMAL_SPECIES] == species))
		{
			count++;
		}
	}

	return count;
}

stock Animals_SpeciesFromKey(const key[])
{
	for (new species = 0;species < ANIMAL_SPECIES_COUNT;species++)
	{
		if (!strcmp(g_AnimalDefs[species][E_ANIMAL_DEF_KEY],key,true))
		{
			return species;
		}
	}

	return -1;
}

stock bool:Animals_HerdKeeps(species = -1)
{
	for (new slot = 0;slot < sizeof(g_AnimalsHerd);slot++)
	{
		if (species == -1 || g_AnimalsHerd[slot][E_ANIMAL_HERD_SPECIES] == species)
		{
			return true;
		}
	}

	return false;
}

stock bool:Animals_IsWild()
{
	return s_AnimalsWild;
}

stock Animals_SetWild(bool:isOn)
{
	s_AnimalsWild = isOn;

	if (!isOn)
	{
		for (new animal = 0;animal < ANIMALS_MAX;animal++)
		{
			if (s_Animals[animal][E_ANIMAL_USED] && s_Animals[animal][E_ANIMAL_PLACE] != -1 && s_Animals[animal][E_ANIMAL_PLACE] < ANIMALS_HERD_PLACE && s_Animals[animal][E_ANIMAL_HELD_BY] == -1)
			{
				Animals_Despawn(animal);
			}
		}
	}
}

stock bool:Animals_IsAbroad(species)
{
	new active = g_AnimalDefs[species][E_ANIMAL_DEF_ACTIVE], bool:night = Calendar_IsNight();

	if (species == ANIMAL_WOLF && Calendar_GetSeason() == SEASON_WINTER)
	{
		return true;
	}

	return (night && (active & ANIMAL_ACTIVE_NIGHT)) || (!night && (active & ANIMAL_ACTIVE_DAY));
}

stock bool:Animals_GetPos(animal,&Float:x,&Float:y,&Float:z)
{
	if (!Animals_IsValid(animal))
	{
		return false;
	}

	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);

	if (IsValidDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]))
	{
		z = s_Animals[animal][E_ANIMAL_SWIM_Z];
	}

	return true;
}

stock bool:Animals_IsSwimming(animal)
{
	return Animals_IsValid(animal) && IsValidDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]);
}

static Animals_Swim(animal,Float:x,Float:y,Float:z)
{
	new Float:level, actorid = s_Animals[animal][E_ANIMAL_ACTOR], bool:swim = s_Animals[animal][E_ANIMAL_SPECIES] == ANIMAL_DUCK && s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_DEAD && s_Animals[animal][E_ANIMAL_WET] && Fishing_WaterAt(x,y,level) != FISHING_WATER_NONE && level - z > ANIMALS_SWIM_DEPTH;

	if (!swim)
	{
		if (IsValidDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]))
		{
			DestroyDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]);
			s_Animals[animal][E_ANIMAL_SWIM_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
			SetActorVirtualWorld(actorid,s_Animals[animal][E_ANIMAL_WORLD]);
		}

		return;
	}

	new Float:angle = GetPedestrianFacingAngle(actorid);
	s_Animals[animal][E_ANIMAL_SWIM_Z] = level;

	if (!IsValidDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]))
	{
		s_Animals[animal][E_ANIMAL_WORLD] = GetActorVirtualWorld(actorid);
		s_Animals[animal][E_ANIMAL_SWIM_OBJECT] = CreateDynamicObject(MODEL_DUCK_SWIM,x,y,level,0.0,0.0,angle,s_Animals[animal][E_ANIMAL_WORLD],0,-1,ANIMALS_SWIM_RANGE,ANIMALS_SWIM_RANGE);
		SetActorVirtualWorld(actorid,ANIMALS_HIDDEN_WORLD);
		Nearby_StreamObjectsAt(x,y,level,s_Animals[animal][E_ANIMAL_WORLD],0,ANIMALS_SWIM_RANGE);
		return;
	}

	new Float:ox, Float:oy, Float:oz;
	GetDynamicObjectPos(s_Animals[animal][E_ANIMAL_SWIM_OBJECT],ox,oy,oz);
	new Float:distance = VectorSize(x - ox,y - oy,level - oz);

	if (distance > ANIMALS_SWIM_JUMP)
	{
		SetDynamicObjectPos(s_Animals[animal][E_ANIMAL_SWIM_OBJECT],x,y,level);
		SetDynamicObjectRot(s_Animals[animal][E_ANIMAL_SWIM_OBJECT],0.0,0.0,angle);
	}
	else if (distance > 0.02)
	{
		MoveDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT],x,y,level,distance * 1000.0 / float(ANIMALS_THINK_MS),0.0,0.0,angle);
	}
	else
	{
		SetDynamicObjectRot(s_Animals[animal][E_ANIMAL_SWIM_OBJECT],0.0,0.0,angle);
	}
}

stock bool:Animals_WaterLevelNear(Float:x,Float:y,&Float:level)
{
	if (Fishing_WaterAt(x,y,level) != FISHING_WATER_NONE)
	{
		return true;
	}

	for (new Float:reach = 2.0;reach <= ANIMALS_WATER_REACH;reach += 2.0)
	{
		for (new ang = 0;ang < 360;ang += 45)
		{
			if (Fishing_WaterAt(x + floatsin(-float(ang),degrees) * reach,y + floatcos(-float(ang),degrees) * reach,level) != FISHING_WATER_NONE)
			{
				return true;
			}
		}
	}

	return false;
}

stock bool:Animals_TooDeep(Float:x,Float:y,Float:groundZ)
{
	new Float:level;
	return Animals_WaterLevelNear(x,y,level) && level - groundZ > ANIMALS_WADE_DEPTH;
}

static bool:Animals_PathDry(animal,Float:x,Float:y)
{
	if (!s_Animals[animal][E_ANIMAL_WET] || s_Animals[animal][E_ANIMAL_SPECIES] == ANIMAL_DUCK)
	{
		return true;
	}

	new Float:fromX, Float:fromY, Float:fromZ, Float:hx, Float:hy, Float:hz;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],fromX,fromY,fromZ);
	new steps = floatround(VectorSize(x - fromX,y - fromY,0.0) / ANIMALS_PATH_STEP,floatround_ceil), bool:leaving = true;

	for (new i = 0;i <= steps;i++)
	{
		new Float:px = fromX + (x - fromX) * float(i) / float(max(steps,1)), Float:py = fromY + (y - fromY) * float(i) / float(max(steps,1)), bool:deep = CA_RayCastLine(px,py,fromZ + 15.0,px,py,fromZ - 15.0,hx,hy,hz) != 0 && s_Animals[animal][E_ANIMAL_WATER_LEVEL] - hz > ANIMALS_WADE_DEPTH;

		if (deep && (!leaving || i == steps))
		{
			return false;
		}

		leaving = leaving && deep;
	}

	return true;
}

stock Animals_GetHome(animal,&Float:x,&Float:y,&Float:z)
{
	x = s_Animals[animal][E_ANIMAL_HOME][0];
	y = s_Animals[animal][E_ANIMAL_HOME][1];
	z = s_Animals[animal][E_ANIMAL_HOME][2];
}

stock Animals_SetHome(animal,Float:x,Float:y,Float:z)
{
	if (Animals_IsValid(animal))
	{
		s_Animals[animal][E_ANIMAL_HOME][0] = x;
		s_Animals[animal][E_ANIMAL_HOME][1] = y;
		s_Animals[animal][E_ANIMAL_HOME][2] = z;
		s_Animals[animal][E_ANIMAL_WET] = Animals_WaterLevelNear(x,y,s_Animals[animal][E_ANIMAL_WATER_LEVEL]);
	}
}

stock Animals_Spawn(species,Float:x,Float:y,Float:z,place = -1,herd = -1)
{
	if (species < 0 || species >= ANIMAL_SPECIES_COUNT)
	{
		return -1;
	}

	new animal = -1;

	for (new i = 0;i < ANIMALS_MAX;i++)
	{
		if (!s_Animals[i][E_ANIMAL_USED])
		{
			animal = i;
			break;
		}
	}

	if (animal == -1)
	{
		return -1;
	}

	new skin = g_AnimalDefs[species][E_ANIMAL_DEF_SKIN], bool:female = g_AnimalDefs[species][E_ANIMAL_DEF_SKIN_FEMALE] != 0 && random(ANIMALS_MALE_ODDS) != 0;

	if (female)
	{
		skin = g_AnimalDefs[species][E_ANIMAL_DEF_SKIN_FEMALE];
	}

	new actorid = SpawnPedestrianAt(skin != 0 ? skin : ANIMALS_PLACEHOLDER_SKIN,x,y,z + 1.0,float(random(360)),ANIMALS_KIND_BASE + species);

	if (actorid < 0 || actorid >= MAX_ACTORS)
	{
		return -1;
	}

	SetPedestrianBody(actorid,Animals_NavBody(species));

	SetPedestrianHealth(actorid,g_AnimalDefs[species][E_ANIMAL_DEF_HEALTH]);
	s_Animals[animal][E_ANIMAL_USED] = true;
	s_Animals[animal][E_ANIMAL_ACTOR] = actorid;
	s_Animals[animal][E_ANIMAL_SPECIES] = species;
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_WANDER;
	s_Animals[animal][E_ANIMAL_HOME][0] = x;
	s_Animals[animal][E_ANIMAL_HOME][1] = y;
	s_Animals[animal][E_ANIMAL_HOME][2] = z;
	s_Animals[animal][E_ANIMAL_PLACE] = place;
	s_Animals[animal][E_ANIMAL_TARGET] = INVALID_PLAYER_ID;
	s_Animals[animal][E_ANIMAL_HIT_BY] = INVALID_PLAYER_ID;
	s_Animals[animal][E_ANIMAL_HIT_TICK] = 0;
	s_Animals[animal][E_ANIMAL_HITS] = 0;
	s_Animals[animal][E_ANIMAL_NEXT_TICK] = GetTickCount() + random(4000);
	s_Animals[animal][E_ANIMAL_BITE_TICK] = 0;
	s_Animals[animal][E_ANIMAL_STATE_UNTIL] = 0;
	s_Animals[animal][E_ANIMAL_CHASE_REST_UNTIL] = 0;
	s_Animals[animal][E_ANIMAL_HELD_BY] = -1;
	s_Animals[animal][E_ANIMAL_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	s_Animals[animal][E_ANIMAL_GAIT] = ANIMAL_GAIT_NONE;
	s_Animals[animal][E_ANIMAL_FEMALE] = female;
	s_Animals[animal][E_ANIMAL_WET] = Animals_WaterLevelNear(x,y,s_Animals[animal][E_ANIMAL_WATER_LEVEL]);
	s_Animals[animal][E_ANIMAL_SWIM_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_Animals[animal][E_ANIMAL_WORLD] = 0;
	s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_GRAZE;
	s_Animals[animal][E_ANIMAL_HERD_ID] = herd;
	s_Animals[animal][E_ANIMAL_LEFT] = 0.0;
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	s_Animals[animal][E_ANIMAL_LEG_FAILS] = 0;
	s_Animals[animal][E_ANIMAL_STILL] = 0;
	s_Animals[animal][E_ANIMAL_ALERT_TICK] = 0;
	s_Animals[animal][E_ANIMAL_WARY_UNTIL] = 0;
	s_Animals[animal][E_ANIMAL_EASING] = false;
	s_Animals[animal][E_ANIMAL_CORNER_UNTIL] = 0;
	s_Animals[animal][E_ANIMAL_PATH_FAILS] = 0;

	if (skin == 0)
	{
		new text[32];
		format(text,sizeof(text),"(%s)",g_AnimalDefs[species][E_ANIMAL_DEF_NAME]);
		s_Animals[animal][E_ANIMAL_LABEL] = CreateDynamic3DTextLabel(text,ANIMALS_LABEL_COLOUR,x,y,z + 2.0,30.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
	}

	pawn_call_public("Animals_OnSpawned","dd",animal,species);
	return animal;
}

stock Animals_Despawn(animal)
{
	if (!Animals_IsValid(animal))
	{
		return;
	}

	if (IsValidPedestrian(s_Animals[animal][E_ANIMAL_ACTOR]))
	{
		DespawnPedestrian(s_Animals[animal][E_ANIMAL_ACTOR]);
	}

	if (IsValidDynamic3DTextLabel(s_Animals[animal][E_ANIMAL_LABEL]))
	{
		DestroyDynamic3DTextLabel(s_Animals[animal][E_ANIMAL_LABEL]);
	}

	if (IsValidDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]))
	{
		DestroyDynamicObject(s_Animals[animal][E_ANIMAL_SWIM_OBJECT]);
		s_Animals[animal][E_ANIMAL_SWIM_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	s_Animals[animal][E_ANIMAL_USED] = false;
	s_Animals[animal][E_ANIMAL_ACTOR] = -1;
}

stock Animals_Kill(animal,killerid)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	new Float:x, Float:y, Float:z, species = s_Animals[animal][E_ANIMAL_SPECIES], hits = s_Animals[animal][E_ANIMAL_HITS], held = s_Animals[animal][E_ANIMAL_HELD_BY];
	Animals_GetPos(animal,x,y,z);
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_DEAD;

	if (killerid == INVALID_PLAYER_ID)
	{
		killerid = s_Animals[animal][E_ANIMAL_HIT_BY];
	}

	if (s_Animals[animal][E_ANIMAL_PLACE] >= ANIMALS_HERD_PLACE)
	{
		s_AnimalsHerdBack[s_Animals[animal][E_ANIMAL_PLACE] - ANIMALS_HERD_PLACE] = GetTickCount() + ANIMALS_HERD_RESPAWN_MS;
	}

	Animals_Despawn(animal);
	pawn_call_public("Animals_OnKilled","dddfffdd",animal,species,killerid,x,y,z,hits,held);
}

stock Animals_Bleed(animal)
{
	new Float:x, Float:y, Float:z;

	if (Animals_GetPos(animal,x,y,z))
	{
		Wounds_SpillBlood(x,y,z,0);
	}
}

stock Animals_Struck(animal,playerid)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	s_Animals[animal][E_ANIMAL_HIT_BY] = playerid;
	s_Animals[animal][E_ANIMAL_HIT_TICK] = GetTickCount();
	s_Animals[animal][E_ANIMAL_HITS]++;
	Animals_Bleed(animal);
	pawn_call_public("Animals_OnStruck","dd",animal,playerid);

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_HELD)
	{
		return;
	}

	new species = s_Animals[animal][E_ANIMAL_SPECIES];

	if (g_AnimalDefs[species][E_ANIMAL_DEF_AGGRESSION] >= 1 && IsPlayerConnected(playerid))
	{
		Animals_Chase(animal,playerid);
		return;
	}

	new Float:px, Float:py, Float:pz;

	if (IsPlayerConnected(playerid))
	{
		GetPlayerPos(playerid,px,py,pz);
		Animals_Flee(animal,px,py,pz);
	}
}

stock Animals_Damage(animal,playerid,Float:amount)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	new actorid = s_Animals[animal][E_ANIMAL_ACTOR], Float:health = GetPedestrianHealth(actorid) - amount;

	if (health <= 0.0)
	{
		s_Animals[animal][E_ANIMAL_HIT_BY] = playerid;
		s_Animals[animal][E_ANIMAL_HITS]++;
		Animals_Bleed(animal);
		Animals_Kill(animal,playerid);
		return;
	}

	SetPedestrianHealth(actorid,health);
	Animals_Struck(animal,playerid);
}

static Float:Animals_AngleTo(Float:fromX,Float:fromY,Float:toX,Float:toY)
{
	return atan2(toY - fromY,toX - fromX) - 90.0;
}

static Animals_Face(animal,Float:x,Float:y)
{
	new Float:ax, Float:ay, Float:az;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],ax,ay,az);
	SetPedestrianFacingAngle(s_Animals[animal][E_ANIMAL_ACTOR],Animals_AngleTo(ax,ay,x,y));
}

static Animals_SetCause(animal,Float:x,Float:y,Float:z)
{
	s_Animals[animal][E_ANIMAL_CAUSE][0] = x;
	s_Animals[animal][E_ANIMAL_CAUSE][1] = y;
	s_Animals[animal][E_ANIMAL_CAUSE][2] = z;
}

static bool:Animals_Go(animal,Float:x,Float:y,Float:z,Float:speed,Float:reach = 0.0)
{
	new actorid = s_Animals[animal][E_ANIMAL_ACTOR], body = Animals_NavBody(s_Animals[animal][E_ANIMAL_SPECIES]), Float:ax, Float:ay, Float:az, Float:length;
	GetPedestrianPos(actorid,ax,ay,az);
	new route = PedestrianPathProbe(body,ax,ay,az,x,y,z,length);

	if (route == -1 || (route > 0 && reach > 0.0 && length > reach))
	{
		s_AnimalsRouteRefused++;
		StopPedestrian(actorid);
		return false;
	}

	if (SetPedestrianTarget(actorid,x,y,z,speed) != 1)
	{
		s_AnimalsRouteFails++;
		return false;
	}

	if (IsPedestrianOnNav(actorid) == 1)
	{
		return true;
	}

	if (PedestrianPathProbe(body,ax,ay,az,ax,ay,az,length) == -2)
	{
		return true;
	}

	StopPedestrian(actorid);
	return false;
}

static bool:Animals_Disturbs(animal,playerid,Float:distance,&bool:bolt)
{
	new Float:radius = g_AnimalDefs[s_Animals[animal][E_ANIMAL_SPECIES]][E_ANIMAL_DEF_FLEE];
	bolt = false;

	if (radius <= 0.0 || playerid == INVALID_PLAYER_ID)
	{
		return false;
	}

	if (GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_DUCK || Combat_IsCrouched(playerid))
	{
		radius = radius * float(ANIMALS_CROUCH_FACTOR) / 100.0;
	}

	if (distance > radius)
	{
		return false;
	}

	bolt = distance <= radius * float(ANIMALS_BOLT_PERCENT) / 100.0 || (s_AnimalsPlayerSpeed[playerid] >= ANIMALS_RUN_SPEED && distance <= radius * float(ANIMALS_RUN_PERCENT) / 100.0);
	return true;
}

static Animals_TrackPlayers()
{
	new tick = GetTickCount(), dt = tick - s_AnimalsPlayerTick;

	if (dt < 400)
	{
		return;
	}

	s_AnimalsPlayerTick = tick;

	foreach (new playerid : Player)
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);
		new Float:speed = dt < 3000 ? VectorSize(x - s_AnimalsPlayerPos[playerid][0],y - s_AnimalsPlayerPos[playerid][1],0.0) * 1000.0 / float(dt) : 0.0;
		s_AnimalsPlayerSpeed[playerid] = speed > ANIMALS_TELEPORT_SPEED ? 0.0 : speed;
		s_AnimalsPlayerPos[playerid][0] = x;
		s_AnimalsPlayerPos[playerid][1] = y;
		s_AnimalsPlayerPos[playerid][2] = z;
	}
}

stock Float:Animals_PlayerSpeed(playerid)
{
	return playerid >= 0 && playerid < MAX_PLAYERS ? s_AnimalsPlayerSpeed[playerid] : 0.0;
}

static bool:Animals_PickLeg(animal,Float:causeX,Float:causeY,Float:maxDist,&Float:gx,&Float:gy,&Float:gz,&Float:length)
{
	new actorid = s_Animals[animal][E_ANIMAL_ACTOR], body = Animals_NavBody(s_Animals[animal][E_ANIMAL_SPECIES]), Float:x, Float:y, Float:z;
	GetPedestrianPos(actorid,x,y,z);
	new Float:ax = x - causeX, Float:ay = y - causeY, Float:len = VectorSize(ax,ay,0.0), Float:best = -999999.0, bool:found = false;

	if (len < 0.01)
	{
		ax = 1.0;
		ay = 0.0;
		len = 1.0;
	}

	ax /= len;
	ay /= len;

	new const Float:scale[3] = {1.0, 0.6, 0.3};

	for (new d = 0;d < 3 && !found;d++)
	{
		new Float:dist = maxDist * scale[d];

		for (new k = 0;k < 7;k++)
		{
			new Float:ang = float(k - 3) * 25.0, Float:c = floatcos(ang,degrees), Float:sn = floatsin(ang,degrees), Float:tx = x + (ax * c - ay * sn) * dist, Float:ty = y + (ax * sn + ay * c) * dist, Float:hx, Float:hy, Float:hz, Float:plen;

			if (CA_RayCastLine(tx,ty,z + 8.0,tx,ty,z - 10.0,hx,hy,hz) == 0 || PedestrianPathProbe(body,x,y,z,tx,ty,hz + 1.0,plen) < 1)
			{
				continue;
			}

			new Float:away = VectorSize(tx - causeX,ty - causeY,0.0);

			if (plen > dist * 1.6 || plen < dist * 0.6 || away < len + dist * 0.35)
			{
				continue;
			}

			new Float:score = away - plen * 0.25 + float(random(30)) / 10.0;

			if (score > best)
			{
				best = score;
				gx = tx;
				gy = ty;
				gz = hz + 1.0;
				length = plen;
				found = true;
			}
		}
	}

	return found;
}

static bool:Animals_StartLeg(animal,Float:gx,Float:gy,Float:gz,Float:length,Float:speed,gait,Float:reach = 0.0)
{
	new Float:z;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],s_Animals[animal][E_ANIMAL_LEG_FROM][0],s_Animals[animal][E_ANIMAL_LEG_FROM][1],z);
	s_Animals[animal][E_ANIMAL_LEG_FROM][2] = z;

	if (!Animals_Go(animal,gx,gy,gz,speed,reach))
	{
		s_Animals[animal][E_ANIMAL_LEG_ON] = false;
		return false;
	}

	s_Animals[animal][E_ANIMAL_GOAL][0] = gx;
	s_Animals[animal][E_ANIMAL_GOAL][1] = gy;
	s_Animals[animal][E_ANIMAL_GOAL][2] = gz;
	s_Animals[animal][E_ANIMAL_LEG_LENGTH] = length;
	s_Animals[animal][E_ANIMAL_LEG_ON] = true;
	s_Animals[animal][E_ANIMAL_STILL] = 0;
	Animals_SetGait(animal,gait,true);
	return true;
}

static bool:Animals_HerdSpot(animal,Float:tx,Float:ty,Float:tz,Float:speed,gait)
{
	for (new attempt = 0;attempt < 3;attempt++)
	{
		new Float:ang = float(random(360)), Float:dist = ANIMALS_HERD_SPREAD_MIN + float(random(floatround((ANIMALS_HERD_SPREAD_MAX - ANIMALS_HERD_SPREAD_MIN) * 10.0))) / 10.0, Float:x = tx + floatsin(-ang,degrees) * dist, Float:y = ty + floatcos(-ang,degrees) * dist, Float:hx, Float:hy, Float:hz;

		if (CA_RayCastLine(x,y,tz + 6.0,x,y,tz - 8.0,hx,hy,hz) != 0 && Animals_StartLeg(animal,x,y,hz + 1.0,dist,speed,gait))
		{
			return true;
		}
	}

	return Animals_StartLeg(animal,tx,ty,tz,0.0,speed,gait);
}

static Animals_Stand(animal,gait)
{
	StopPedestrian(s_Animals[animal][E_ANIMAL_ACTOR]);
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	Animals_SetGait(animal,gait,true);
}

static Animals_Graze(animal,ms)
{
	s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_GRAZE;
	s_Animals[animal][E_ANIMAL_NEXT_TICK] = GetTickCount() + ms;
	Animals_SetGait(animal,g_AnimalNature[s_Animals[animal][E_ANIMAL_SPECIES]][E_ANIMAL_NATURE_GRAZES] ? ANIMAL_GAIT_GRAZE : ANIMAL_GAIT_STAND,true);
}

static Animals_Rest(animal,ms)
{
	StopPedestrian(s_Animals[animal][E_ANIMAL_ACTOR]);
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_REST;
	s_Animals[animal][E_ANIMAL_NEXT_TICK] = GetTickCount() + ms;
	Animals_SetGait(animal,ANIMAL_GAIT_REST,true);
}

static Animals_Calm(animal)
{
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_WANDER;
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	Animals_Graze(animal,2000 + random(3000));
}

static Animals_Look(animal)
{
	Animals_Stand(animal,ANIMAL_GAIT_STAND);
	s_Animals[animal][E_ANIMAL_EASING] = false;
	Animals_Face(animal,s_Animals[animal][E_ANIMAL_CAUSE][0],s_Animals[animal][E_ANIMAL_CAUSE][1]);
}

static Animals_EnterWary(animal)
{
	new Float:gx, Float:gy, Float:gz, Float:length, species = s_Animals[animal][E_ANIMAL_SPECIES];
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_WARY;
	s_Animals[animal][E_ANIMAL_WARY_UNTIL] = GetTickCount() + ANIMALS_WARY_MIN_MS + random(ANIMALS_WARY_VARY_MS);
	s_Animals[animal][E_ANIMAL_EASING] = false;

	if (g_AnimalNature[species][E_ANIMAL_NATURE_FLIGHT] > 0.0 && Animals_PickLeg(animal,s_Animals[animal][E_ANIMAL_CAUSE][0],s_Animals[animal][E_ANIMAL_CAUSE][1],ANIMALS_EASE_LENGTH,gx,gy,gz,length) && Animals_StartLeg(animal,gx,gy,gz,length,g_AnimalDefs[species][E_ANIMAL_DEF_WALK] * ANIMALS_EASE_FACTOR,ANIMAL_GAIT_WALK))
	{
		s_Animals[animal][E_ANIMAL_EASING] = true;
		return;
	}

	Animals_Look(animal);
}

static bool:Animals_Near(animal,other,Float:range)
{
	new Float:ax, Float:ay, Float:az, Float:bx, Float:by, Float:bz;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],ax,ay,az);
	GetPedestrianPos(s_Animals[other][E_ANIMAL_ACTOR],bx,by,bz);
	return VectorSize(ax - bx,ay - by,0.0) <= range;
}

static bool:Animals_Calling(animal)
{
	return s_Animals[animal][E_ANIMAL_USED] && s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_DEAD && s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_HELD;
}

static Animals_Alert(animal,Float:x,Float:y,Float:z)
{
	if (!Animals_Calling(animal))
	{
		return;
	}

	new current = s_Animals[animal][E_ANIMAL_STATE];

	if (current == ANIMAL_STATE_FLEE || current == ANIMAL_STATE_CHASE || current == ANIMAL_STATE_RETURN)
	{
		return;
	}

	Animals_SetCause(animal,x,y,z);
	s_Animals[animal][E_ANIMAL_ALERT_TICK] = GetTickCount();

	if (current != ANIMAL_STATE_ALERT && current != ANIMAL_STATE_WARY)
	{
		s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_ALERT;
		Animals_Stand(animal,ANIMAL_GAIT_STAND);
	}

	Animals_Face(animal,x,y);

	if (s_AnimalsAlarming || s_Animals[animal][E_ANIMAL_HERD_ID] < 0)
	{
		return;
	}

	s_AnimalsAlarming = true;

	for (new mate = 0;mate < ANIMALS_MAX;mate++)
	{
		if (mate != animal && s_Animals[mate][E_ANIMAL_USED] && s_Animals[mate][E_ANIMAL_HERD_ID] == s_Animals[animal][E_ANIMAL_HERD_ID] && s_Animals[mate][E_ANIMAL_STATE] == ANIMAL_STATE_WANDER && Animals_Near(animal,mate,ANIMALS_HERD_ALARM))
		{
			Animals_Alert(mate,x,y,z);
		}
	}

	s_AnimalsAlarming = false;
}

static Animals_NextLeg(animal,bool:first = false)
{
	new species = s_Animals[animal][E_ANIMAL_SPECIES], Float:x, Float:y, Float:z, Float:distance, others;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;

	if (s_Animals[animal][E_ANIMAL_LEFT] < 6.0)
	{
		Animals_EnterWary(animal);
		return;
	}

	new playerid = Animals_NearestPlayer(x,y,z,distance,others);

	if (playerid != INVALID_PLAYER_ID && distance <= 60.0)
	{
		new Float:px, Float:py, Float:pz;
		GetPlayerPos(playerid,px,py,pz);
		Animals_SetCause(animal,px,py,pz);
	}

	new Float:gx, Float:gy, Float:gz, Float:length, bool:started = false, leader = Animals_HerdLeader(animal);

	if (leader != animal && s_Animals[leader][E_ANIMAL_STATE] == ANIMAL_STATE_FLEE && s_Animals[leader][E_ANIMAL_LEG_ON])
	{
		started = Animals_HerdSpot(animal,s_Animals[leader][E_ANIMAL_GOAL][0],s_Animals[leader][E_ANIMAL_GOAL][1],s_Animals[leader][E_ANIMAL_GOAL][2],g_AnimalDefs[species][E_ANIMAL_DEF_RUN],ANIMAL_GAIT_RUN);
	}

	if (!started && Animals_PickLeg(animal,s_Animals[animal][E_ANIMAL_CAUSE][0],s_Animals[animal][E_ANIMAL_CAUSE][1],(s_Animals[animal][E_ANIMAL_LEFT] < ANIMALS_LEG_LENGTH ? s_Animals[animal][E_ANIMAL_LEFT] : ANIMALS_LEG_LENGTH),gx,gy,gz,length))
	{
		started = Animals_StartLeg(animal,gx,gy,gz,length,g_AnimalDefs[species][E_ANIMAL_DEF_RUN],ANIMAL_GAIT_RUN);
	}

	if (started)
	{
		return;
	}

	s_Animals[animal][E_ANIMAL_LEG_FAILS]++;

	if (!first)
	{
		s_Animals[animal][E_ANIMAL_CORNER_UNTIL] = GetTickCount() + 4000;
		Animals_EnterWary(animal);
	}
}

static Animals_LegDone(animal)
{
	new Float:x, Float:y, Float:z;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);
	s_Animals[animal][E_ANIMAL_LEFT] -= VectorSize(x - s_Animals[animal][E_ANIMAL_LEG_FROM][0],y - s_Animals[animal][E_ANIMAL_LEG_FROM][1],0.0);
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
}

stock Animals_Flee(animal,Float:fromX,Float:fromY,Float:fromZ)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_HELD || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	new species = s_Animals[animal][E_ANIMAL_SPECIES];
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_FLEE;
	s_Animals[animal][E_ANIMAL_STATE_UNTIL] = GetTickCount() + ANIMALS_FLEE_MAX_MS;
	s_Animals[animal][E_ANIMAL_GAIT] = ANIMAL_GAIT_NONE;
	s_Animals[animal][E_ANIMAL_LEFT] = g_AnimalNature[species][E_ANIMAL_NATURE_FLIGHT] * float(80 + random(40)) / 100.0;
	s_Animals[animal][E_ANIMAL_LEG_FAILS] = 0;
	s_Animals[animal][E_ANIMAL_EASING] = false;
	Animals_SetCause(animal,fromX,fromY,fromZ);
	Animals_NextLeg(animal,true);

	if (s_AnimalsAlarming || s_Animals[animal][E_ANIMAL_HERD_ID] < 0)
	{
		return;
	}

	s_AnimalsAlarming = true;

	for (new mate = 0;mate < ANIMALS_MAX;mate++)
	{
		new mood = s_Animals[mate][E_ANIMAL_STATE];

		if (mate != animal && s_Animals[mate][E_ANIMAL_USED] && s_Animals[mate][E_ANIMAL_HERD_ID] == s_Animals[animal][E_ANIMAL_HERD_ID] && mood != ANIMAL_STATE_FLEE && mood != ANIMAL_STATE_CHASE && mood != ANIMAL_STATE_HELD && mood != ANIMAL_STATE_DEAD && Animals_Near(animal,mate,ANIMALS_HERD_ALARM))
		{
			Animals_Flee(mate,fromX,fromY,fromZ);
		}
	}

	s_AnimalsAlarming = false;
}

stock Animals_Noise(Float:x,Float:y,Float:z)
{
	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (!Animals_Calling(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_CHASE || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_RETURN || g_AnimalDefs[s_Animals[animal][E_ANIMAL_SPECIES]][E_ANIMAL_DEF_FLEE] <= 0.0)
		{
			continue;
		}

		new Float:ax, Float:ay, Float:az;
		GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],ax,ay,az);
		new Float:d = VectorSize(ax - x,ay - y,az - z);

		if (d <= ANIMALS_NOISE_RANGE && s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_FLEE)
		{
			if (g_AnimalDefs[s_Animals[animal][E_ANIMAL_SPECIES]][E_ANIMAL_DEF_GROUP] == ANIMAL_GROUP_GAME && d <= ANIMALS_NOISE_RANGE * 0.45)
			{
				Animals_Flee(animal,x,y,z);
			}
			else
			{
				Animals_Alert(animal,x,y,z);
			}
		}
	}
}

stock bool:Animals_CanPursue(animal,Float:targetX,Float:targetY,tick)
{
    if (!Animals_IsValid(animal))
    {
        return false;
    }

    if (s_Animals[animal][E_ANIMAL_SPECIES] != ANIMAL_WOLF)
    {
        return true;
    }

    new Float:x, Float:y, Float:z;
    GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);

    if (tick - s_Animals[animal][E_ANIMAL_CHASE_TICK] >= ANIMALS_CHASE_MS || VectorSize(targetX - s_Animals[animal][E_ANIMAL_CHASE_FROM][0],targetY - s_Animals[animal][E_ANIMAL_CHASE_FROM][1],0.0) > ANIMALS_CHASE_LEASH || VectorSize(x - s_Animals[animal][E_ANIMAL_CHASE_FROM][0],y - s_Animals[animal][E_ANIMAL_CHASE_FROM][1],0.0) > ANIMALS_CHASE_LEASH)
    {
        return false;
    }

    return !Realm_PathEntersTown(x,y,targetX,targetY);
}

stock Animals_Chase(animal,playerid)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_HELD || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	if (s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_CHASE || s_Animals[animal][E_ANIMAL_TARGET] != playerid)
	{
		if (s_Animals[animal][E_ANIMAL_SPECIES] == ANIMAL_WOLF)
		{
			if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_RETURN || GetTickCount() < s_Animals[animal][E_ANIMAL_CHASE_REST_UNTIL])
			{
				return;
			}

			new Float:x, Float:y, Float:z, Float:tx, Float:ty, Float:tz;
			GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);

			if (Realm_InTown(x,y))
			{
				return;
			}

			if (IsPlayerConnected(playerid))
			{
				GetPlayerPos(playerid,tx,ty,tz);

				if (Realm_PathEntersTown(x,y,tx,ty))
				{
					return;
				}
			}

			if (s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_CHASE)
			{
				s_Animals[animal][E_ANIMAL_CHASE_FROM][0] = x;
				s_Animals[animal][E_ANIMAL_CHASE_FROM][1] = y;
				s_Animals[animal][E_ANIMAL_CHASE_FROM][2] = z;
				s_Animals[animal][E_ANIMAL_CHASE_TICK] = GetTickCount();
			}
		}

		pawn_call_public("Animals_OnChase","dd",animal,playerid);
	}

	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_CHASE;
	s_Animals[animal][E_ANIMAL_TARGET] = playerid;
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	Animals_SetGait(animal,ANIMAL_GAIT_RUN);

	if (s_Animals[animal][E_ANIMAL_SPECIES] == ANIMAL_WOLF && s_Animals[animal][E_ANIMAL_HERD_ID] >= 0)
	{
		for (new mate = 0;mate < ANIMALS_MAX;mate++)
		{
			if (mate != animal && s_Animals[mate][E_ANIMAL_USED] && s_Animals[mate][E_ANIMAL_HERD_ID] == s_Animals[animal][E_ANIMAL_HERD_ID] && s_Animals[mate][E_ANIMAL_STATE] != ANIMAL_STATE_CHASE && Animals_Near(animal,mate,ANIMALS_PACK_JOIN))
			{
				Animals_Chase(mate,playerid);
			}
		}
	}
}

stock bool:Animals_Hold(animal,trap)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return false;
	}

	s_Animals[animal][E_ANIMAL_GAIT] = ANIMAL_GAIT_NONE;

	if (trap == -1)
	{
		s_Animals[animal][E_ANIMAL_HELD_BY] = -1;
		s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_WANDER;
		s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_GRAZE;
		s_Animals[animal][E_ANIMAL_NEXT_TICK] = 0;
		ResumePedestrian(s_Animals[animal][E_ANIMAL_ACTOR]);
		return true;
	}

	s_Animals[animal][E_ANIMAL_HELD_BY] = trap;
	s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_HELD;
	s_Animals[animal][E_ANIMAL_LEG_ON] = false;
	StopPedestrian(s_Animals[animal][E_ANIMAL_ACTOR]);
	return true;
}

stock Animals_GetGait(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_GAIT] : ANIMAL_GAIT_NONE;
}

static Animals_SetGait(animal,gait,bool:force = false)
{
	if (s_Animals[animal][E_ANIMAL_GAIT] == gait && !force)
	{
		return;
	}

	s_Animals[animal][E_ANIMAL_GAIT] = gait;

	switch (gait)
	{
		case ANIMAL_GAIT_STAND:
		{
			ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","IDLE_stance",4.1,1,0,0,0,0);
		}
		case ANIMAL_GAIT_WALK:
		{
			ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","WALK_civi",4.1,1,1,1,0,0);
		}
		case ANIMAL_GAIT_RUN:
		{
			ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","run_civi",4.1,1,1,1,0,0);
		}
		case ANIMAL_GAIT_GRAZE:
		{
			ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","IDLE_tired",4.1,1,0,0,0,0);
		}
		case ANIMAL_GAIT_REST:
		{
			ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","SEAT_idle",4.1,1,0,0,0,0);
		}
	}
}

stock Animals_GetHeldBy(animal)
{
	return Animals_IsValid(animal) ? s_Animals[animal][E_ANIMAL_HELD_BY] : -1;
}

stock Animals_Lure(animal,Float:x,Float:y,Float:z)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] != ANIMAL_STATE_WANDER)
	{
		return;
	}

	Animals_SetHome(animal,x,y,z);
	s_Animals[animal][E_ANIMAL_HERD_ID] = -1;
	s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_GRAZE;
	s_Animals[animal][E_ANIMAL_NEXT_TICK] = 0;
}

stock Animals_FindNear(Float:x,Float:y,Float:z,Float:range,mask = -1,&Float:distance = 0.0)
{
	new best = -1;
	distance = range;

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (!s_Animals[animal][E_ANIMAL_USED] || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD || !(mask & (1 << s_Animals[animal][E_ANIMAL_SPECIES])))
		{
			continue;
		}

		new Float:ax, Float:ay, Float:az;
		GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],ax,ay,az);
		new Float:d = VectorSize(ax - x,ay - y,az - z);

		if (d <= distance)
		{
			distance = d;
			best = animal;
		}
	}

	return best;
}

static Animals_NearestPlayer(Float:x,Float:y,Float:z,&Float:distance,&others)
{
	new best = INVALID_PLAYER_ID;
	distance = 9999.0;
	others = 0;

	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
		{
			continue;
		}

		new Float:d = GetPlayerDistanceFromPoint(playerid,x,y,z);

		if (d < distance)
		{
			distance = d;
			best = playerid;
		}
	}

	if (best == INVALID_PLAYER_ID)
	{
		return best;
	}

	new Float:bx, Float:by, Float:bz;
	GetPlayerPos(best,bx,by,bz);

	foreach (new playerid : Player)
	{
		if (playerid != best && !IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerDistanceFromPoint(playerid,bx,by,bz) <= ANIMALS_LONE_RANGE)
		{
			others++;
		}
	}

	return best;
}

static Animals_HerdFollow(animal,Float:tx,Float:ty,Float:tz)
{
	if (s_Animals[animal][E_ANIMAL_HERD_ID] < 0)
	{
		return;
	}

	for (new mate = 0;mate < ANIMALS_MAX;mate++)
	{
		if (mate == animal || !s_Animals[mate][E_ANIMAL_USED] || s_Animals[mate][E_ANIMAL_HERD_ID] != s_Animals[animal][E_ANIMAL_HERD_ID] || s_Animals[mate][E_ANIMAL_STATE] != ANIMAL_STATE_WANDER)
		{
			continue;
		}

		new Float:speed = g_AnimalDefs[s_Animals[mate][E_ANIMAL_SPECIES]][E_ANIMAL_DEF_WALK] * float(90 + random(21)) / 100.0;

		if (Animals_HerdSpot(mate,tx,ty,tz,speed,ANIMAL_GAIT_WALK))
		{
			s_Animals[mate][E_ANIMAL_MODE] = ANIMAL_MODE_WALK;
			s_Animals[mate][E_ANIMAL_NEXT_TICK] = GetTickCount() + 20000;
		}
	}
}

static Animals_Wander(animal)
{
	new species = s_Animals[animal][E_ANIMAL_SPECIES], bool:yard = s_Animals[animal][E_ANIMAL_PLACE] >= ANIMALS_HERD_PLACE, Float:ax, Float:ay, Float:az, Float:x, Float:y, Float:hx, Float:hy, Float:hz, bool:found = false, bool:local = false;
	GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],ax,ay,az);

	for (new round = 0;round < 2 && !found;round++)
	{
		new Float:cx = round == 0 ? s_Animals[animal][E_ANIMAL_HOME][0] : ax, Float:cy = round == 0 ? s_Animals[animal][E_ANIMAL_HOME][1] : ay, Float:cz = round == 0 && !yard ? s_Animals[animal][E_ANIMAL_HOME][2] : az, Float:up = yard ? ANIMALS_YARD_RAY_UP : 15.0, Float:down = yard ? ANIMALS_YARD_RAY_DOWN : 15.0;

		for (new attempt = 0;attempt < ANIMALS_WANDER_TRIES && !found;attempt++)
		{
			new Float:ang = float(random(360)), Float:dist = yard ? float(1 + random(ANIMALS_HERD_WANDER)) : float(4 + random(floatround(ANIMALS_WANDER)));
			x = cx + floatsin(-ang,degrees) * dist;
			y = cy + floatcos(-ang,degrees) * dist;
			found = CA_RayCastLine(x,y,cz + up,x,y,cz - down,hx,hy,hz) != 0 && Animals_PathDry(animal,x,y) && Animals_StartLeg(animal,x,y,hz + 1.0,dist,g_AnimalDefs[species][E_ANIMAL_DEF_WALK],ANIMAL_GAIT_WALK,yard ? dist * 2.0 + 2.0 : 0.0);
		}

		local = found && round == 1;
	}

	if (!found)
	{
		s_Animals[animal][E_ANIMAL_PATH_FAILS]++;
		Animals_Graze(animal,3000);
		return;
	}

	if (local && !yard && g_AnimalDefs[species][E_ANIMAL_DEF_GROUP] != ANIMAL_GROUP_PREDATOR)
	{
		Animals_SetHome(animal,ax,ay,az);
	}

	s_Animals[animal][E_ANIMAL_PATH_FAILS] = 0;
	s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_WALK;
	s_Animals[animal][E_ANIMAL_NEXT_TICK] = GetTickCount() + 20000;
	Animals_HerdFollow(animal,x,y,hz + 1.0);
}

static Animals_CalmNext(animal,tick)
{
	new species = s_Animals[animal][E_ANIMAL_SPECIES];

	if (s_Animals[animal][E_ANIMAL_PATH_FAILS] >= ANIMALS_PATH_FAILS_MAX && s_Animals[animal][E_ANIMAL_HERD_ID] >= 0)
	{
		s_Animals[animal][E_ANIMAL_HERD_ID] = -1;
		s_Animals[animal][E_ANIMAL_PATH_FAILS] = 0;
	}

	new leader = Animals_HerdLeader(animal);

	if (s_Animals[animal][E_ANIMAL_PATH_FAILS] >= ANIMALS_PATH_FAILS_MAX && s_Animals[animal][E_ANIMAL_PLACE] != -1 && s_Animals[animal][E_ANIMAL_PLACE] < ANIMALS_HERD_PLACE)
	{
		Animals_Despawn(animal);
		return;
	}

	if (leader != animal)
	{
		if (s_Animals[leader][E_ANIMAL_MODE] == ANIMAL_MODE_REST && s_Animals[leader][E_ANIMAL_STATE] == ANIMAL_STATE_WANDER)
		{
			Animals_Rest(animal,max(s_Animals[leader][E_ANIMAL_NEXT_TICK] - tick,3000));
			return;
		}

		new Float:lx, Float:ly, Float:lz;
		GetPedestrianPos(s_Animals[leader][E_ANIMAL_ACTOR],lx,ly,lz);

		if (!Animals_Near(animal,leader,ANIMALS_HERD_CATCHUP))
		{
			if (Animals_HerdSpot(animal,lx,ly,lz,g_AnimalDefs[species][E_ANIMAL_DEF_RUN] * 0.5,ANIMAL_GAIT_WALK))
			{
				s_Animals[animal][E_ANIMAL_PATH_FAILS] = 0;
				s_Animals[animal][E_ANIMAL_MODE] = ANIMAL_MODE_WALK;
				s_Animals[animal][E_ANIMAL_NEXT_TICK] = tick + 15000;
				return;
			}

			s_Animals[animal][E_ANIMAL_PATH_FAILS]++;
		}

		Animals_Graze(animal,3000 + random(5000));
		return;
	}

	if (s_Animals[animal][E_ANIMAL_MODE] != ANIMAL_MODE_GRAZE)
	{
		Animals_Graze(animal,ANIMALS_GRAZE_MIN_MS + random(ANIMALS_GRAZE_VARY_MS));
		return;
	}

	if (Calendar_IsNight() && g_AnimalNature[species][E_ANIMAL_NATURE_RESTS] && random(3) == 0)
	{
		new Float:x, Float:y, Float:z, Float:distance, others;
		GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);
		Animals_NearestPlayer(x,y,z,distance,others);

		if (distance > ANIMALS_REST_QUIET)
		{
			new ms = ANIMALS_REST_MIN_MS + random(ANIMALS_REST_VARY_MS);
			Animals_Rest(animal,ms);
			return;
		}
	}

	Animals_Wander(animal);
}

static Animals_Bite(animal,playerid)
{
	new species = s_Animals[animal][E_ANIMAL_SPECIES], name[16];
	strcopy(name,g_AnimalDefs[species][E_ANIMAL_DEF_NAME]);
	ApplyPedestrianAnim(s_Animals[animal][E_ANIMAL_ACTOR],"PED","FIGHTA_1",4.1,0,1,1,0,0);
	s_Animals[animal][E_ANIMAL_GAIT] = ANIMAL_GAIT_NONE;
	Vitals_Damage(playerid,g_AnimalDefs[species][E_ANIMAL_DEF_DAMAGE],name);
	Gui_Notify(playerid,sprintf("The %s %s you!",name,species == ANIMAL_BEAR ? ("mauls") : (species == ANIMAL_BOAR ? ("gores") : ("bites"))));
	pawn_call_public("Animals_OnBite","dd",animal,playerid);
}

stock Animals_Think(animal)
{
	if (!Animals_IsValid(animal) || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
	{
		return;
	}

	new actorid = s_Animals[animal][E_ANIMAL_ACTOR];

	if (!IsValidPedestrian(actorid))
	{
		Animals_Despawn(animal);
		return;
	}

	new species = s_Animals[animal][E_ANIMAL_SPECIES], group = g_AnimalDefs[species][E_ANIMAL_DEF_GROUP], tick = GetTickCount(), Float:x, Float:y, Float:z;
	GetPedestrianPos(actorid,x,y,z);
	Animals_Swim(animal,x,y,z);

	if (IsValidDynamic3DTextLabel(s_Animals[animal][E_ANIMAL_LABEL]))
	{
		Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL,s_Animals[animal][E_ANIMAL_LABEL],E_STREAMER_X,x);
		Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL,s_Animals[animal][E_ANIMAL_LABEL],E_STREAMER_Y,y);
		Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL,s_Animals[animal][E_ANIMAL_LABEL],E_STREAMER_Z,z + 1.2);
	}

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_HELD)
	{
		return;
	}

	new Float:distance, others, playerid = Animals_NearestPlayer(x,y,z,distance,others);

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_RETURN)
	{
		if (VectorSize(x - s_Animals[animal][E_ANIMAL_HOME][0],y - s_Animals[animal][E_ANIMAL_HOME][1],0.0) <= 3.0)
		{
			s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_WANDER;
			s_Animals[animal][E_ANIMAL_CHASE_REST_UNTIL] = tick + ANIMALS_CHASE_REST_MS;
			s_Animals[animal][E_ANIMAL_NEXT_TICK] = tick;
			Animals_SetGait(animal,ANIMAL_GAIT_STAND);
		}
		else
		{
			SetPedestrianTarget(actorid,s_Animals[animal][E_ANIMAL_HOME][0],s_Animals[animal][E_ANIMAL_HOME][1],s_Animals[animal][E_ANIMAL_HOME][2] + 1.0,g_AnimalDefs[species][E_ANIMAL_DEF_WALK]);
			Animals_SetGait(animal,ANIMAL_GAIT_WALK);
		}

		return;
	}

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_CHASE)
	{
		new target = s_Animals[animal][E_ANIMAL_TARGET], bool:wounded = tick - s_Animals[animal][E_ANIMAL_HIT_TICK] < ANIMALS_WOUNDED_MS;

		if (!IsPlayerConnected(target) || !Session_IsPlaying(target) || GetPlayerVirtualWorld(target) != 0 || GetPlayerDistanceFromPoint(target,x,y,z) > ANIMALS_CHASE_GIVE_UP || (group == ANIMAL_GROUP_PREDATOR && !wounded && !Animals_IsAbroad(species)) || (group == ANIMAL_GROUP_GAME && !wounded))
		{
			s_Animals[animal][E_ANIMAL_STATE] = species == ANIMAL_WOLF ? ANIMAL_STATE_RETURN : ANIMAL_STATE_WANDER;
			s_Animals[animal][E_ANIMAL_TARGET] = INVALID_PLAYER_ID;
			s_Animals[animal][E_ANIMAL_NEXT_TICK] = 0;
			if (species == ANIMAL_WOLF)
			{
				SetPedestrianTarget(actorid,s_Animals[animal][E_ANIMAL_HOME][0],s_Animals[animal][E_ANIMAL_HOME][1],s_Animals[animal][E_ANIMAL_HOME][2] + 1.0,g_AnimalDefs[species][E_ANIMAL_DEF_WALK]);
				Animals_SetGait(animal,ANIMAL_GAIT_WALK);
			}
			return;
		}

		new Float:tx, Float:ty, Float:tz;
		GetPlayerPos(target,tx,ty,tz);

		if (!Animals_CanPursue(animal,tx,ty,tick))
		{
			s_Animals[animal][E_ANIMAL_STATE] = ANIMAL_STATE_RETURN;
			s_Animals[animal][E_ANIMAL_TARGET] = INVALID_PLAYER_ID;
			SetPedestrianTarget(actorid,s_Animals[animal][E_ANIMAL_HOME][0],s_Animals[animal][E_ANIMAL_HOME][1],s_Animals[animal][E_ANIMAL_HOME][2] + 1.0,g_AnimalDefs[species][E_ANIMAL_DEF_WALK]);
			Animals_SetGait(animal,ANIMAL_GAIT_WALK);
			return;
		}

		if (GetPlayerDistanceFromPoint(target,x,y,z) <= ANIMALS_BITE_RANGE)
		{
			if (tick >= s_Animals[animal][E_ANIMAL_BITE_TICK])
			{
				s_Animals[animal][E_ANIMAL_BITE_TICK] = tick + ANIMALS_BITE_MS;
				Animals_Bite(animal,target);
			}

			return;
		}

		SetPedestrianTarget(actorid,tx,ty,tz,g_AnimalDefs[species][E_ANIMAL_DEF_RUN]);
		Animals_SetGait(animal,ANIMAL_GAIT_RUN);
		return;
	}

	new Float:px, Float:py, Float:pz, bool:bolt = false, bool:disturbed = false;

	if (playerid != INVALID_PLAYER_ID && group != ANIMAL_GROUP_PREDATOR)
	{
		GetPlayerPos(playerid,px,py,pz);
		disturbed = Animals_Disturbs(animal,playerid,distance,bolt);
	}

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_FLEE)
	{
		Animals_ThinkFlee(animal,tick,x,y);
		return;
	}

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_ALERT)
	{
		if (disturbed && bolt)
		{
			Animals_Flee(animal,px,py,pz);
		}
		else if (disturbed)
		{
			Animals_Alert(animal,px,py,pz);
		}
		else if (tick - s_Animals[animal][E_ANIMAL_ALERT_TICK] >= ANIMALS_ALERT_CALM_MS)
		{
			Animals_Calm(animal);
		}

		return;
	}

	if (s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_WARY)
	{
		if (disturbed && bolt && tick >= s_Animals[animal][E_ANIMAL_CORNER_UNTIL])
		{
			Animals_Flee(animal,px,py,pz);
			return;
		}

		if (disturbed)
		{
			Animals_SetCause(animal,px,py,pz);
			s_Animals[animal][E_ANIMAL_WARY_UNTIL] = max(s_Animals[animal][E_ANIMAL_WARY_UNTIL],tick + 2000);

			if (!s_Animals[animal][E_ANIMAL_EASING])
			{
				Animals_Face(animal,px,py);
			}
		}

		if (s_Animals[animal][E_ANIMAL_EASING] && tick >= s_Animals[animal][E_ANIMAL_WARY_UNTIL] + 4000)
		{
			Animals_Look(animal);
		}
		else if (!s_Animals[animal][E_ANIMAL_EASING] && tick >= s_Animals[animal][E_ANIMAL_WARY_UNTIL])
		{
			Animals_Calm(animal);
		}

		return;
	}

	if (group == ANIMAL_GROUP_PREDATOR)
	{
		if (playerid != INVALID_PLAYER_ID)
		{
			new Float:hx = s_Animals[animal][E_ANIMAL_HOME][0], Float:hy = s_Animals[animal][E_ANIMAL_HOME][1];

			if ((species == ANIMAL_WOLF && Animals_IsAbroad(species) && others == 0 && distance <= ANIMALS_CHASE_RANGE) || (species == ANIMAL_BEAR && distance <= 12.0 && VectorSize(x - hx,y - hy,0.0) <= ANIMALS_TERRITORY))
			{
				Animals_Chase(animal,playerid);
				return;
			}
		}
	}
	else if (disturbed)
	{
		if (bolt)
		{
			Animals_Flee(animal,px,py,pz);
		}
		else
		{
			Animals_Alert(animal,px,py,pz);
		}

		return;
	}

	if (tick >= s_Animals[animal][E_ANIMAL_NEXT_TICK])
	{
		Animals_CalmNext(animal,tick);
	}
}

static Animals_ThinkFlee(animal,tick,Float:x,Float:y)
{
	if (tick >= s_Animals[animal][E_ANIMAL_STATE_UNTIL])
	{
		s_Animals[animal][E_ANIMAL_LEG_ON] = false;
		Animals_EnterWary(animal);
		return;
	}

	if (!s_Animals[animal][E_ANIMAL_LEG_ON])
	{
		Animals_NextLeg(animal);
		return;
	}

	if (VectorSize(x - s_Animals[animal][E_ANIMAL_LAST][0],y - s_Animals[animal][E_ANIMAL_LAST][1],0.0) < 0.5)
	{
		if (++s_Animals[animal][E_ANIMAL_STILL] >= ANIMALS_LEG_STILL)
		{
			Animals_LegDone(animal);
			Animals_NextLeg(animal);
		}
	}
	else
	{
		s_Animals[animal][E_ANIMAL_STILL] = 0;
	}

	s_Animals[animal][E_ANIMAL_LAST][0] = x;
	s_Animals[animal][E_ANIMAL_LAST][1] = y;
}

static Animals_PlacePos(place,&Float:x,&Float:y,&Float:z,&habitat)
{
	new index = place;

	if (index < ANIMALS_SEED_FOREST)
	{
		x = g_AnimalsForest[index][0];
		y = g_AnimalsForest[index][1];
		z = g_AnimalsForest[index][2];
		habitat = ANIMAL_HABITAT_FOREST;
		return;
	}

	index -= ANIMALS_SEED_FOREST;

	if (index < ANIMALS_SEED_MEADOW)
	{
		x = g_AnimalsMeadow[index][0];
		y = g_AnimalsMeadow[index][1];
		z = g_AnimalsMeadow[index][2];
		habitat = ANIMAL_HABITAT_MEADOW;
		return;
	}

	index -= ANIMALS_SEED_MEADOW;

	if (index < ANIMALS_SEED_WATER)
	{
		x = g_AnimalsWater[index][0];
		y = g_AnimalsWater[index][1];
		z = g_AnimalsWater[index][2];
		habitat = ANIMAL_HABITAT_WATER;
		return;
	}

	index -= ANIMALS_SEED_WATER;
	x = g_AnimalsDens[index][0];
	y = g_AnimalsDens[index][1];
	z = g_AnimalsDens[index][2];
	habitat = ANIMAL_HABITAT_DEN;
}

stock Animals_PickSpecies(habitat)
{
	new total = 0, weights[ANIMAL_SPECIES_COUNT];

	for (new species = 0;species < ANIMAL_SPECIES_COUNT;species++)
	{
		if (g_AnimalDefs[species][E_ANIMAL_DEF_GROUP] == ANIMAL_GROUP_HERD || !(g_AnimalDefs[species][E_ANIMAL_DEF_HABITAT] & habitat) || !Animals_IsAbroad(species))
		{
			continue;
		}

		weights[species] = g_AnimalDefs[species][E_ANIMAL_DEF_WEIGHT] * (species == ANIMAL_WOLF && Calendar_GetSeason() == SEASON_WINTER ? 3 : 1);
		total += weights[species];
	}

	if (total <= 0)
	{
		return -1;
	}

	new roll = random(total);

	for (new species = 0;species < ANIMAL_SPECIES_COUNT;species++)
	{
		if (roll < weights[species])
		{
			return species;
		}

		roll -= weights[species];
	}

	return -1;
}

stock Animals_SpawnGroup(place)
{
	new Float:x, Float:y, Float:z, habitat, spawned = 0;
	Animals_PlacePos(place,x,y,z,habitat);
	new species = Animals_PickSpecies(habitat);

	if (species == -1)
	{
		return 0;
	}

	new pack = 1 + random(g_AnimalDefs[species][E_ANIMAL_DEF_PACK]), herd = pack > 1 ? Animals_NewHerd() : -1;

	for (new i = 0;i < pack;i++)
	{
		new Float:ang = float(random(360)), Float:dist = float(random(8)), Float:sx = x + floatsin(-ang,degrees) * dist, Float:sy = y + floatcos(-ang,degrees) * dist, Float:hx, Float:hy, Float:hz;

		if (CA_RayCastLine(sx,sy,z + 15.0,sx,sy,z - 15.0,hx,hy,hz) != 0 && (species == ANIMAL_DUCK || !Animals_TooDeep(sx,sy,hz)) && Animals_Spawn(species,sx,sy,hz,place,herd) != -1)
		{
			spawned++;
		}
	}

	return spawned;
}

static Animals_CountAt(place)
{
	new count = 0;

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (s_Animals[animal][E_ANIMAL_USED] && s_Animals[animal][E_ANIMAL_PLACE] == place)
		{
			count++;
		}
	}

	return count;
}

static bool:Animals_PlayerWithin(Float:x,Float:y,Float:z,Float:range)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid) && GetPlayerVirtualWorld(playerid) == 0 && GetPlayerDistanceFromPoint(playerid,x,y,z) <= range)
		{
			return true;
		}
	}

	return false;
}

stock Animals_YardHerd(slot)
{
	new cluster = slot, species = g_AnimalsHerd[slot][E_ANIMAL_HERD_SPECIES];

	for (new other = 0;other < slot;other++)
	{
		if (g_AnimalsHerd[other][E_ANIMAL_HERD_SPECIES] == species && VectorSize(g_AnimalsHerd[other][E_ANIMAL_HERD_POS][0] - g_AnimalsHerd[slot][E_ANIMAL_HERD_POS][0],g_AnimalsHerd[other][E_ANIMAL_HERD_POS][1] - g_AnimalsHerd[slot][E_ANIMAL_HERD_POS][1],0.0) <= ANIMALS_HERD_YARD)
		{
			cluster = other;
			break;
		}
	}

	return ANIMALS_HERD_YARD_BASE + cluster;
}

stock Animals_KeepHerd()
{
	for (new slot = 0;slot < sizeof(g_AnimalsHerd);slot++)
	{
		new species = g_AnimalsHerd[slot][E_ANIMAL_HERD_SPECIES], Float:x = g_AnimalsHerd[slot][E_ANIMAL_HERD_POS][0], Float:y = g_AnimalsHerd[slot][E_ANIMAL_HERD_POS][1], Float:z = g_AnimalsHerd[slot][E_ANIMAL_HERD_POS][2], Float:hx, Float:hy, Float:hz;

		if (Animals_CountAt(ANIMALS_HERD_PLACE + slot) > 0 || GetTickCount() < s_AnimalsHerdBack[slot] || !Animals_IsAbroad(species) || !Animals_PlayerWithin(x,y,z,ANIMALS_STREAM_NEAR) || Animals_Count() >= ANIMALS_MAX)
		{
			continue;
		}

		if (CA_RayCastLine(x,y,z + 15.0,x,y,z - 15.0,hx,hy,hz) == 0)
		{
			hz = z;
		}

		Animals_Spawn(species,x,y,hz,ANIMALS_HERD_PLACE + slot,Animals_YardHerd(slot));
	}
}

stock Animals_GetHerdAnimal(slot)
{
	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (s_Animals[animal][E_ANIMAL_USED] && s_Animals[animal][E_ANIMAL_PLACE] == ANIMALS_HERD_PLACE + slot)
		{
			return animal;
		}
	}

	return -1;
}

stock Animals_ResetHerd()
{
	for (new slot = 0;slot < sizeof(g_AnimalsHerd);slot++)
	{
		s_AnimalsHerdBack[slot] = 0;
	}
}

stock Animals_Stream()
{
	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (!s_Animals[animal][E_ANIMAL_USED] || s_Animals[animal][E_ANIMAL_PLACE] == -1 || s_Animals[animal][E_ANIMAL_HELD_BY] != -1)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPedestrianPos(s_Animals[animal][E_ANIMAL_ACTOR],x,y,z);

		if (!Animals_PlayerWithin(x,y,z,ANIMALS_STREAM_FAR) || !Animals_IsAbroad(s_Animals[animal][E_ANIMAL_SPECIES]))
		{
			Animals_Despawn(animal);
		}
	}

	Animals_KeepHerd();

	if (!s_AnimalsWild)
	{
		return;
	}

	for (new place = 0;place < ANIMALS_PLACES && Animals_Count() < ANIMALS_MAX - 4;place++)
	{
		new Float:x, Float:y, Float:z, habitat;
		Animals_PlacePos(place,x,y,z,habitat);

		if (Animals_CountAt(place) == 0 && Animals_PlayerWithin(x,y,z,ANIMALS_STREAM_NEAR) && !Animals_PlayerWithin(x,y,z,50.0) && random(3) == 0)
		{
			Animals_SpawnGroup(place);
		}
	}
}

stock Animals_Clear()
{
	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (s_Animals[animal][E_ANIMAL_USED])
		{
			Animals_Despawn(animal);
		}
	}
}

Timer_Declare(Animals_ThinkTick)
{
	Animals_TrackPlayers();

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		Animals_Think(animal);
	}

	return 1;
}

Timer_Declare(Animals_StreamTick)
{
	Animals_Stream();
	return 1;
}

forward Animals_OnSpawned(animal,species);

public Animals_OnSpawned(animal,species)
{
	return 1;
}

forward Animals_OnStruck(animal,playerid);

public Animals_OnStruck(animal,playerid)
{
	return 1;
}

forward Animals_OnChase(animal,playerid);

public Animals_OnChase(animal,playerid)
{
	return 1;
}

forward Animals_OnBite(animal,playerid);

public Animals_OnBite(animal,playerid)
{
	return 1;
}

forward Animals_OnKilled(animal,species,killerid,Float:x,Float:y,Float:z,hits,heldBy);

public Animals_OnKilled(animal,species,killerid,Float:x,Float:y,Float:z,hits,heldBy)
{
	return 1;
}

#include <pp-hooks>

hook OnPedestrianReachTarget(actorid)
{
	new animal = Animals_FindByActor(actorid);

	if (animal == -1)
	{
		return;
	}

	switch (s_Animals[animal][E_ANIMAL_STATE])
	{
		case ANIMAL_STATE_WANDER:
		{
			s_Animals[animal][E_ANIMAL_LEG_ON] = false;
			Animals_Graze(animal,ANIMALS_GRAZE_MIN_MS + random(ANIMALS_GRAZE_VARY_MS));
		}
		case ANIMAL_STATE_FLEE:
		{
			Animals_LegDone(animal);
			Animals_NextLeg(animal);
		}
		case ANIMAL_STATE_WARY:
		{
			if (s_Animals[animal][E_ANIMAL_EASING])
			{
				Animals_Look(animal);
			}
		}
	}
}

hook OnPedestrianPathFailed(actorid)
{
	new animal = Animals_FindByActor(actorid);

	if (animal == -1)
	{
		return;
	}

	switch (s_Animals[animal][E_ANIMAL_STATE])
	{
		case ANIMAL_STATE_WANDER:
		{
			s_Animals[animal][E_ANIMAL_LEG_ON] = false;
			s_Animals[animal][E_ANIMAL_PATH_FAILS]++;
			Animals_Graze(animal,2000 + random(3000));
		}
		case ANIMAL_STATE_FLEE:
		{
			Animals_LegDone(animal);
			s_Animals[animal][E_ANIMAL_LEG_FAILS]++;

			if (s_Animals[animal][E_ANIMAL_LEG_FAILS] >= 2)
			{
				s_Animals[animal][E_ANIMAL_CORNER_UNTIL] = GetTickCount() + 4000;
				Animals_EnterWary(animal);
			}
			else
			{
				Animals_NextLeg(animal);
			}
		}
		case ANIMAL_STATE_WARY:
		{
			if (s_Animals[animal][E_ANIMAL_EASING])
			{
				Animals_Look(animal);
			}
		}
	}
}

hook Projectile_OnShot(shooterid,kind,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz)
{
	#pragma unused shooterid, kind, dx, dy, dz
	Animals_Noise(sx,sy,sz);
}

hook OnPedestrianGetDamage(pedestrianid,playerid,weaponid,Float:amount)
{
	#pragma unused weaponid, amount
	new animal = Animals_FindByActor(pedestrianid);

	if (animal != -1)
	{
		Animals_Struck(animal,playerid);
	}
}

hook OnPedestrianDeath(actorid,killerid,reason)
{
	#pragma unused reason
	new animal = Animals_FindByActor(actorid);

	if (animal != -1)
	{
		Animals_Kill(animal,killerid);
	}
}

hook Projectile_OnHitActor(shooterid,actorid,weapon,Float:damage)
{
	#pragma unused weapon

    if (Actors_DamageByBody(actorid,shooterid,damage))
    {
        return;
    }

	new animal = Animals_FindByActor(actorid);

	if (animal != -1)
	{
		Animals_Damage(animal,shooterid,damage * ANIMALS_ARROW_FACTOR);
	}
}

hook Combat_OnNpcSeek(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != 0)
	{
		return;
	}

	for (new animal = 0;animal < ANIMALS_MAX;animal++)
	{
		if (!s_Animals[animal][E_ANIMAL_USED] || s_Animals[animal][E_ANIMAL_STATE] == ANIMAL_STATE_DEAD)
		{
			continue;
		}

		new actorid = s_Animals[animal][E_ANIMAL_ACTOR], Float:x, Float:y, Float:z;
		Animals_GetPos(animal,x,y,z);
		Combat_OfferNpc(actorid,x,y,z + (Animals_IsSwimming(animal) ? ANIMALS_SWIM_LIFT : ANIMALS_BODY_LIFT),GetPedestrianFacingAngle(actorid));
	}
}

hook Combat_OnHitNpc(attackerid,actorid,weapon,Float:damage)
{
	#pragma unused weapon
	new animal = Animals_FindByActor(actorid);

	if (animal != -1)
	{
		Animals_Damage(animal,attackerid,damage * ANIMALS_ARROW_FACTOR);
	}
}
