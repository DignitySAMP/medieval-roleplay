#define MAX_PROJECTILES (128)
#define PROJECTILE_RANGE (45.0)
#define PROJECTILE_SPEED (20.0)
#define PROJECTILE_HIT_RADIUS (0.7)
#define PROJECTILE_HIT_HEIGHT (1.2)
#define PROJECTILE_COOLDOWN_MS (2000)
#define PROJECTILE_MUZZLE (0.6)
#define PROJECTILE_STAMINA_THROW (20.0)
#define PROJECTILE_STAMINA_SHOT (10.0)
#define PROJECTILE_BOLT_RANGE (60.0)
#define PROJECTILE_BOLT_SPEED (32.0)
#define PROJECTILE_BOLT_STAMINA_SHOT (4.0)
#define PROJECTILE_STONE_RANGE (32.0)
#define PROJECTILE_STONE_SPEED (26.0)
#define PROJECTILE_STONE_STAMINA_SHOT (6.0)
#define PROJECTILE_BOLT_SETBACK (0.4)
#define PROJECTILE_CRANK_MS (4000)
#define PROJECTILE_CRANK_STAMINA (15.0)
#define PROJECTILE_LAY_MS (800)
#define PROJECTILE_SLING_LOAD_MS (800)

enum E_PROJECTILE_KIND
{
	PROJECTILE_ARROW,
	PROJECTILE_THROWN,
	PROJECTILE_BOLT,
	PROJECTILE_STONE,
}

enum E_RANGED_STAGE
{
	RANGED_EMPTY,
	RANGED_CRANKING,
	RANGED_SPANNED,
	RANGED_LOADING,
	RANGED_LOADED,
}

enum E_PROJECTILE
{
	bool:E_PROJ_USED,
	E_PROJECTILE_KIND:E_PROJ_KIND,
	E_PROJ_SHOOTER,
	E_PROJ_WEAPON,
	E_PROJ_TARGET,
	E_PROJ_ACTOR,
	E_PROJ_TOKEN,
	STREAMER_TAG_OBJECT:E_PROJ_OBJECT,
	Float:E_PROJ_END_X,
	Float:E_PROJ_END_Y,
	Float:E_PROJ_END_Z,
	Float:E_PROJ_DIR_X,
	Float:E_PROJ_DIR_Y,
	E_PROJ_WORLD,
	E_PROJ_INTERIOR,
}

static s_Projectiles[MAX_PROJECTILES][E_PROJECTILE];
static s_ProjectileCooldown[MAX_PLAYERS];
static E_RANGED_STAGE:s_RangedStage[MAX_PLAYERS];
static s_RangedWeapon[MAX_PLAYERS] = {INVALID_WEAPON_INDEX, ...};
static s_RangedToken[MAX_PLAYERS];
static Text:s_Crosshair = Text:INVALID_TEXT_DRAW;

static const Float:s_BodypartDamage[5] = {25.0, 15.0, 15.0, 10.0, 10.0};

static Projectile_Free()
{
	for (new i = 0; i < MAX_PROJECTILES; i++)
	{
		if (!s_Projectiles[i][E_PROJ_USED])
		{
			return i;
		}
	}

	return -1;
}

static Projectile_FindByObject(STREAMER_TAG_OBJECT:objectid)
{
	for (new i = 0; i < MAX_PROJECTILES; i++)
	{
		if (s_Projectiles[i][E_PROJ_USED] && s_Projectiles[i][E_PROJ_OBJECT] == objectid)
		{
			return i;
		}
	}

	return -1;
}

stock Projectile_CountLive()
{
	new count = 0;
	for (new i = 0; i < MAX_PROJECTILES; i++)
	{
		if (s_Projectiles[i][E_PROJ_USED])
		{
			count++;
		}
	}

	return count;
}

static Float:Projectile_GetRange(E_PROJECTILE_KIND:kind)
{
	if (kind == PROJECTILE_BOLT)
	{
		return PROJECTILE_BOLT_RANGE;
	}

	if (kind == PROJECTILE_STONE)
	{
		return PROJECTILE_STONE_RANGE;
	}

	return PROJECTILE_RANGE;
}

static Float:Projectile_GetSpeed(E_PROJECTILE_KIND:kind)
{
	if (kind == PROJECTILE_BOLT)
	{
		return PROJECTILE_BOLT_SPEED;
	}

	if (kind == PROJECTILE_STONE)
	{
		return PROJECTILE_STONE_SPEED;
	}

	return PROJECTILE_SPEED;
}

stock Float:Projectile_GetMaxDamage(weapon)
{
	return s_BodypartDamage[0] * Weapon_GetRangedScale(weapon);
}

static Projectile_FindTarget(shooterid,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz,Float:range,&Float:distance)
{
	new best = INVALID_PLAYER_ID;
	distance = range;

	foreach(new i : Player)
	{
		if (i == shooterid || !Session_HasCharacter(i) || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(shooterid))
		{
			continue;
		}

		new Float:px, Float:py, Float:pz;
		GetPlayerPos(i,px,py,pz);

		new Float:t = (px - sx) * dx + (py - sy) * dy + (pz - sz) * dz;
		if (t < 0.5 || t > distance)
		{
			continue;
		}

		new Float:cx = sx + dx * t, Float:cy = sy + dy * t, Float:cz = sz + dz * t;
		if (Util_GetDistance2D(cx,cy,px,py) > PROJECTILE_HIT_RADIUS || floatabs(cz - pz) > PROJECTILE_HIT_HEIGHT)
		{
			continue;
		}

		distance = t;
		best = i;
	}

	return best;
}

static Projectile_FindActor(shooterid,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz,&Float:distance)
{
	new actorid = Combat_FindNpcOnLine(shooterid,sx,sy,sz,dx,dy,dz,PROJECTILE_HIT_RADIUS,PROJECTILE_HIT_HEIGHT,distance);
	return actorid == INVALID_ACTOR_ID ? -1 : actorid;
}

static Projectile_Launch(shooterid,E_PROJECTILE_KIND:kind,weapon,modelid)
{
	new slot = Projectile_Free();
	if (slot == -1)
	{
		return -1;
	}

	new Float:vx, Float:vy, Float:vz, Float:px, Float:py, Float:pz;
	GetPlayerCameraFrontVector(shooterid,vx,vy,vz);
	GetPlayerPos(shooterid,px,py,pz);

	new Float:length = floatsqroot(vx * vx + vy * vy + vz * vz);
	if (length < 0.01)
	{
		return -1;
	}

	vx /= length;
	vy /= length;
	vz /= length;

	new Float:sx = px + vx * PROJECTILE_MUZZLE, Float:sy = py + vy * PROJECTILE_MUZZLE, Float:sz = pz + (Combat_IsCrouched(shooterid) ? 0.1 : 0.6) + vz * PROJECTILE_MUZZLE;
	new Float:range = Projectile_GetRange(kind), Float:speed = Projectile_GetSpeed(kind);
	new Float:hx, Float:hy, Float:hz;
	if (CA_RayCastLine(sx,sy,sz,sx + vx * range,sy + vy * range,sz + vz * range,hx,hy,hz) != 0)
	{
		range = VectorSize(hx - sx,hy - sy,hz - sz);
	}

	new Float:flight, targetid = Projectile_FindTarget(shooterid,sx,sy,sz,vx,vy,vz,range,flight);
	if (targetid == INVALID_PLAYER_ID)
	{
		flight = range;
	}

	new Float:actorFlight = flight, actorid = Projectile_FindActor(shooterid,sx,sy,sz,vx,vy,vz,actorFlight);

	if (actorid != -1)
	{
		targetid = INVALID_PLAYER_ID;
		flight = actorFlight;
	}

	new Float:ex = sx + vx * flight, Float:ey = sy + vy * flight, Float:ez = sz + vz * flight;
	if (kind != PROJECTILE_BOLT && targetid == INVALID_PLAYER_ID && actorid == -1 && ez > pz - 1.0)
	{
		ez = pz - 0.9;
	}

	Util_FacePoint(shooterid,ex,ey);

	s_Projectiles[slot][E_PROJ_USED] = true;
	s_Projectiles[slot][E_PROJ_KIND] = kind;
	s_Projectiles[slot][E_PROJ_SHOOTER] = shooterid;
	s_Projectiles[slot][E_PROJ_WEAPON] = weapon;
	s_Projectiles[slot][E_PROJ_TARGET] = targetid;
	s_Projectiles[slot][E_PROJ_ACTOR] = actorid;
	s_Projectiles[slot][E_PROJ_TOKEN]++;
	s_Projectiles[slot][E_PROJ_END_X] = ex;
	s_Projectiles[slot][E_PROJ_END_Y] = ey;
	s_Projectiles[slot][E_PROJ_END_Z] = ez;
	s_Projectiles[slot][E_PROJ_DIR_X] = vx;
	s_Projectiles[slot][E_PROJ_DIR_Y] = vy;
	s_Projectiles[slot][E_PROJ_WORLD] = GetPlayerVirtualWorld(shooterid);
	s_Projectiles[slot][E_PROJ_INTERIOR] = GetPlayerInterior(shooterid);

	new Float:heading = Util_GetAngleToPoint(sx,sy,ex,ey);
	s_Projectiles[slot][E_PROJ_OBJECT] = CreateDynamicObject(modelid,sx,sy,sz,kind == PROJECTILE_THROWN ? 90.0 : 0.0,kind == PROJECTILE_THROWN ? 90.0 : 0.0,heading + 90.0,GetPlayerVirtualWorld(shooterid));
	MoveDynamicObject(s_Projectiles[slot][E_PROJ_OBJECT],ex,ey,ez,speed);

    SetTimerEx("Projectile_Strike",floatround(VectorSize(ex - sx,ey - sy,ez - sz) / speed * 1000.0) + 100,false,"dd",slot,s_Projectiles[slot][E_PROJ_TOKEN]);

	pawn_call_public("Projectile_OnFired","dddd",shooterid,_:kind,weapon,targetid);
	pawn_call_public("Projectile_OnShot","ddffffff",shooterid,_:kind,sx,sy,sz,vx,vy,vz);
	return slot;
}

static Projectile_Land(slot)
{
	if (!s_Projectiles[slot][E_PROJ_USED])
	{
		return;
	}

	if (s_Projectiles[slot][E_PROJ_KIND] == PROJECTILE_BOLT)
	{
		new Float:hitX, Float:hitY, Float:groundZ;
		s_Projectiles[slot][E_PROJ_END_X] -= s_Projectiles[slot][E_PROJ_DIR_X] * PROJECTILE_BOLT_SETBACK;
		s_Projectiles[slot][E_PROJ_END_Y] -= s_Projectiles[slot][E_PROJ_DIR_Y] * PROJECTILE_BOLT_SETBACK;
		if (CA_RayCastLine(s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z] + 0.1,s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],-1000.0,hitX,hitY,groundZ) != 0)
		{
			s_Projectiles[slot][E_PROJ_END_Z] = groundZ + 0.03;
		}
	}

	if (IsValidDynamicObject(s_Projectiles[slot][E_PROJ_OBJECT]))
	{
		DestroyDynamicObject(s_Projectiles[slot][E_PROJ_OBJECT]);
	}

	switch (s_Projectiles[slot][E_PROJ_KIND])
	{
		case PROJECTILE_ARROW:
		{
			Drop_Create(ITEM_KIND_MISC,ITEM_ARROW,1,s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z] + 0.9,s_Projectiles[slot][E_PROJ_WORLD],.interior = s_Projectiles[slot][E_PROJ_INTERIOR]);
		}
		case PROJECTILE_BOLT:
		{
			Drop_Create(ITEM_KIND_TOOL,ITEM_BOLT,1,s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z] + 0.9,s_Projectiles[slot][E_PROJ_WORLD],.interior = s_Projectiles[slot][E_PROJ_INTERIOR]);
		}
		case PROJECTILE_STONE:
		{
			Drop_Create(ITEM_KIND_MISC,ITEM_SLING_STONE,1,s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z] + 0.9,s_Projectiles[slot][E_PROJ_WORLD],.interior = s_Projectiles[slot][E_PROJ_INTERIOR]);
		}
		default:
		{
			Drop_Create(ITEM_KIND_WEAPON,s_Projectiles[slot][E_PROJ_WEAPON],1,s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z] + 0.9,s_Projectiles[slot][E_PROJ_WORLD],.interior = s_Projectiles[slot][E_PROJ_INTERIOR]);
		}
	}

	s_Projectiles[slot][E_PROJ_USED] = false;
	pawn_call_public("Projectile_OnImpact","ddfff",s_Projectiles[slot][E_PROJ_SHOOTER],_:s_Projectiles[slot][E_PROJ_KIND],s_Projectiles[slot][E_PROJ_END_X],s_Projectiles[slot][E_PROJ_END_Y],s_Projectiles[slot][E_PROJ_END_Z]);
	pawn_call_public("Projectile_OnLanded","dd",s_Projectiles[slot][E_PROJ_SHOOTER],_:s_Projectiles[slot][E_PROJ_KIND]);
}

forward Projectile_Strike(slot,token);

public Projectile_Strike(slot,token)
{
	if (slot < 0 || slot >= MAX_PROJECTILES || !s_Projectiles[slot][E_PROJ_USED] || s_Projectiles[slot][E_PROJ_TOKEN] != token)
	{
		return 1;
	}

	new targetid = s_Projectiles[slot][E_PROJ_TARGET], shooterid = s_Projectiles[slot][E_PROJ_SHOOTER], actorid = s_Projectiles[slot][E_PROJ_ACTOR];

	if (actorid != -1)
	{
		new Float:hit = s_Projectiles[slot][E_PROJ_KIND] == PROJECTILE_THROWN ? Weapon_GetDamage(s_Projectiles[slot][E_PROJ_WEAPON]) : s_BodypartDamage[random(5)] * Weapon_GetRangedScale(s_Projectiles[slot][E_PROJ_WEAPON]);
		Projectile_Land(slot);

		if (IsValidPedestrian(actorid) == 1 || IsValidActor(actorid))
		{
			pawn_call_public("Projectile_OnHitActor","dddf",shooterid,actorid,s_Projectiles[slot][E_PROJ_WEAPON],hit);
		}

		return 1;
	}

	if (!IsPlayerConnected(targetid) || !Session_HasCharacter(targetid) || Session_IsAway(targetid))
	{
		Projectile_Land(slot);
		return 1;
	}

	if (Combat_IsTourney(targetid))
	{
		Projectile_Land(slot);
		return 1;
	}

	new Float:damage = s_Projectiles[slot][E_PROJ_KIND] == PROJECTILE_THROWN ? Weapon_GetDamage(s_Projectiles[slot][E_PROJ_WEAPON]) : s_BodypartDamage[random(5)] * Weapon_GetRangedScale(s_Projectiles[slot][E_PROJ_WEAPON]);

	if (IsValidDynamicObject(s_Projectiles[slot][E_PROJ_OBJECT]))
	{
		DestroyDynamicObject(s_Projectiles[slot][E_PROJ_OBJECT]);
	}

	if (Combat_IsShieldUp(targetid) && Combat_IsBlocking(targetid) && IsPlayerConnected(shooterid) && Combat_IsFacing(targetid,shooterid,80.0))
	{
		PlayerPlaySound(targetid,1135,0.0,0.0,0.0);
		Combat_DamageShield(targetid,damage);
		pawn_call_public("Combat_OnBlocked","ddf",targetid,shooterid,damage);
	}
	else if (!Combat_IsStruckDown(targetid))
	{
		new source[COMBAT_NAME_LEN];
		switch (s_Projectiles[slot][E_PROJ_KIND])
		{
			case PROJECTILE_ARROW:
			{
				strcopy(source,"arrow",sizeof(source));
			}
			case PROJECTILE_BOLT:
			{
				strcopy(source,"bolt",sizeof(source));
			}
			case PROJECTILE_STONE:
			{
				strcopy(source,"sling stone",sizeof(source));
			}
			default:
			{
				Weapon_GetName(s_Projectiles[slot][E_PROJ_WEAPON],source);
			}
		}

		damage = Combat_CapToStrikeDown(targetid,damage);
		new bool:wasDown = Combat_IsStruckDown(targetid);
		Vitals_Damage(targetid,damage,source);

		if (!wasDown && Combat_IsStruckDown(targetid))
		{
			pawn_call_public("Combat_OnFelled","dd",shooterid,targetid);
		}

		pawn_call_public("Combat_OnHit","dddf",shooterid,targetid,s_Projectiles[slot][E_PROJ_WEAPON],damage);
	}

	if (s_Projectiles[slot][E_PROJ_KIND] == PROJECTILE_THROWN)
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(targetid,x,y,z);
		Drop_Create(ITEM_KIND_WEAPON,s_Projectiles[slot][E_PROJ_WEAPON],1,x + 0.5,y,z,s_Projectiles[slot][E_PROJ_WORLD],.interior = s_Projectiles[slot][E_PROJ_INTERIOR]);
	}

	s_Projectiles[slot][E_PROJ_USED] = false;
	return 1;
}

static bool:Projectile_Ready(playerid)
{
	new tick = GetTickCount();
	if (tick - s_ProjectileCooldown[playerid] < PROJECTILE_COOLDOWN_MS)
	{
		return false;
	}

	s_ProjectileCooldown[playerid] = tick;
	return true;
}

static Projectile_AmmoCount(playerid,weapon)
{
	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_BOW:
		{
			return Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_ARROW);
		}
		case WEAPON_TYPE_CROSSBOW:
		{
			return Inventory_Count(playerid,ITEM_KIND_TOOL,ITEM_BOLT);
		}
		case WEAPON_TYPE_SLING:
		{
			return Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_SLING_STONE);
		}
	}

	return 0;
}

static Projectile_TakeAmmo(playerid,weapon)
{
	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_BOW:
		{
			Inventory_Take(playerid,ITEM_KIND_MISC,ITEM_ARROW,1);
		}
		case WEAPON_TYPE_CROSSBOW:
		{
			Inventory_Take(playerid,ITEM_KIND_TOOL,ITEM_BOLT,1);
		}
		case WEAPON_TYPE_SLING:
		{
			Inventory_Take(playerid,ITEM_KIND_MISC,ITEM_SLING_STONE,1);
		}
	}
}

static Projectile_Sync(playerid)
{
	new weapon = Combat_GetWeapon(playerid);
	if (s_RangedWeapon[playerid] == weapon)
	{
		return;
	}

	s_RangedToken[playerid]++;
	s_RangedWeapon[playerid] = weapon;
	s_RangedStage[playerid] = RANGED_EMPTY;
}

static Projectile_ShowStage(playerid)
{
	new weapon = Combat_GetWeapon(playerid), E_RANGED_STAGE:stage = s_RangedStage[playerid];
	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_CROSSBOW:
		{
			switch (stage)
			{
				case RANGED_SPANNED, RANGED_LOADING:
				{
					Combat_SwapHeld(playerid,MODEL_WEAPON_CROSSBOW_SPANNED);
				}
				case RANGED_LOADED:
				{
					Combat_SwapHeld(playerid,MODEL_WEAPON_CROSSBOW_LOADED);
				}
				default:
				{
					Combat_SwapHeld(playerid,MODEL_WEAPON_CROSSBOW_SLACK);
				}
			}

			if (stage == RANGED_CRANKING && Combat_IsInMode(playerid))
			{
				Combat_SetOffhandProp(playerid,MODEL_WEAPON_CROSSBOW_CRANK);
			}
			else
			{
				Combat_ClearOffhandProp(playerid);
			}
		}
		case WEAPON_TYPE_SLING:
		{
			Combat_SwapHeld(playerid,stage == RANGED_LOADED ? MODEL_WEAPON_SLING_LOADED : MODEL_WEAPON_SLING_EMPTY);
		}
	}
}

static Projectile_Interrupt(playerid,bool:notify)
{
	new weapon = Combat_GetWeapon(playerid), E_RANGED_STAGE:stage = s_RangedStage[playerid];
	if (s_RangedWeapon[playerid] != weapon || (stage != RANGED_CRANKING && stage != RANGED_LOADING))
	{
		return;
	}

	s_RangedToken[playerid]++;
	s_RangedStage[playerid] = stage == RANGED_LOADING && Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW ? RANGED_SPANNED : RANGED_EMPTY;
	Projectile_ShowStage(playerid);

	if (notify)
	{
		if (stage == RANGED_CRANKING)
		{
			Gui_Notify(playerid,"You lost your grip on the cranequin. The crossbow is still slack, so left click to start cranking again.");
		}
		else
		{
			Gui_Notify(playerid,"You fumbled the reload. Left click to try again.");
		}
	}
}

static Projectile_ResetRanged(playerid)
{
	s_RangedToken[playerid]++;
	s_RangedWeapon[playerid] = INVALID_WEAPON_INDEX;
	s_RangedStage[playerid] = RANGED_EMPTY;
}

static bool:Projectile_BeginReload(playerid,weapon,E_RANGED_STAGE:next,ms,Float:stamina)
{
	if (next == RANGED_LOADING && Projectile_AmmoCount(playerid,weapon) == 0)
	{
		if (Combat_HintReady(playerid))
		{
			if (Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW)
			{
				Gui_Notify(playerid,"You have no bolts left. The crossbow stays spanned until you get some.");
			}
			else
			{
				Gui_Notify(playerid,"You have no sling stones. Gather some at a rock outcrop.");
			}
		}
		return false;
	}

	if (!Vitals_DrainStamina(playerid,stamina))
	{
		if (Combat_HintReady(playerid))
		{
			Gui_Notify(playerid,"You're too winded for that. Catch your breath first.");
		}
		return false;
	}

	s_RangedToken[playerid]++;
	s_RangedStage[playerid] = next;
	Projectile_ShowStage(playerid);
	SetTimerEx("Projectile_ReloadStep",ms,false,"dd",playerid,s_RangedToken[playerid]);
	return true;
}

stock bool:Projectile_Reload(playerid)
{
	new weapon = Combat_GetWeapon(playerid);
	if (!Combat_IsInMode(playerid) || Combat_IsAttacking(playerid) || !Weapon_IsRanged(weapon))
	{
		return false;
	}

	Projectile_Sync(playerid);

	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_CROSSBOW:
		{
			switch (s_RangedStage[playerid])
			{
				case RANGED_EMPTY:
				{
					return Projectile_BeginReload(playerid,weapon,RANGED_CRANKING,PROJECTILE_CRANK_MS,PROJECTILE_CRANK_STAMINA);
				}
				case RANGED_SPANNED:
				{
					return Projectile_BeginReload(playerid,weapon,RANGED_LOADING,PROJECTILE_LAY_MS,0.0);
				}
			}
		}
		case WEAPON_TYPE_SLING:
		{
			if (s_RangedStage[playerid] == RANGED_EMPTY)
			{
				return Projectile_BeginReload(playerid,weapon,RANGED_LOADING,PROJECTILE_SLING_LOAD_MS,0.0);
			}
		}
	}

	return false;
}

stock E_RANGED_STAGE:Projectile_GetStage(playerid)
{
	if (!Util_IsValidPlayer(playerid) || s_RangedWeapon[playerid] != Combat_GetWeapon(playerid))
	{
		return RANGED_EMPTY;
	}

	return s_RangedStage[playerid];
}

forward Projectile_ReloadStep(playerid,token);

public Projectile_ReloadStep(playerid,token)
{
	if (!IsPlayerConnected(playerid) || s_RangedToken[playerid] != token || s_RangedWeapon[playerid] != Combat_GetWeapon(playerid))
	{
		return 1;
	}

	new weapon = Combat_GetWeapon(playerid);
	if (s_RangedStage[playerid] == RANGED_CRANKING)
	{
		s_RangedStage[playerid] = RANGED_SPANNED;
	}
	else if (s_RangedStage[playerid] == RANGED_LOADING)
	{
		if (Projectile_AmmoCount(playerid,weapon) == 0)
		{
			s_RangedStage[playerid] = Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW ? RANGED_SPANNED : RANGED_EMPTY;
			Gui_Notify(playerid,"You ran out of ammunition before you could load it.");
		}
		else
		{
			s_RangedStage[playerid] = RANGED_LOADED;
		}
	}

	Projectile_ShowStage(playerid);
	return 1;
}

static bool:Projectile_ShootBow(playerid,weapon)
{
	if (Projectile_AmmoCount(playerid,weapon) == 0)
	{
		if (Combat_HintReady(playerid))
		{
			Gui_Notify(playerid,"Your quiver is empty.");
		}
		return false;
	}

	if (!Projectile_Ready(playerid) || !Vitals_DrainStamina(playerid,PROJECTILE_STAMINA_SHOT))
	{
		return false;
	}

	Projectile_TakeAmmo(playerid,weapon);
    if (!Combat_IsRangedAiming(playerid))
    {
        ApplyAnimation(playerid,"PED",Combat_IsCrouched(playerid) ? ("WEAPON_crouch") : ("Gun_stand"),4.1,false,true,true,true,300,SYNC_ALL);
    }
	return Projectile_Launch(playerid,PROJECTILE_ARROW,weapon,WEAPON_ARROW_MODEL) != -1;
}

static bool:Projectile_ShootLoaded(playerid,weapon)
{
	Projectile_Sync(playerid);
	if (s_RangedStage[playerid] != RANGED_LOADED)
	{
		return false;
	}

	if (Projectile_AmmoCount(playerid,weapon) == 0)
	{
		s_RangedStage[playerid] = Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW ? RANGED_SPANNED : RANGED_EMPTY;
		Projectile_ShowStage(playerid);
		return false;
	}

	new bool:crossbow = Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW;
	if (!Vitals_DrainStamina(playerid,crossbow ? PROJECTILE_BOLT_STAMINA_SHOT : PROJECTILE_STONE_STAMINA_SHOT))
	{
		return false;
	}

    if (!Combat_IsRangedAiming(playerid))
    {
        ApplyAnimation(playerid,"PED",Combat_IsCrouched(playerid) ? ("WEAPON_crouch") : ("Gun_stand"),4.1,false,true,true,true,300,SYNC_ALL);
    }
	if (Projectile_Launch(playerid,crossbow ? PROJECTILE_BOLT : PROJECTILE_STONE,weapon,crossbow ? MODEL_WEAPON_CROSSBOW_BOLT : MODEL_WEAPON_SLING_STONE) == -1)
	{
		return false;
	}

	Projectile_TakeAmmo(playerid,weapon);
	s_RangedStage[playerid] = RANGED_EMPTY;
	Projectile_ShowStage(playerid);
	return true;
}

stock bool:Projectile_Shoot(playerid)
{
	new weapon = Combat_GetWeapon(playerid);
	if (!Combat_IsInMode(playerid) || !Weapon_IsRanged(weapon) || Combat_IsAttacking(playerid))
	{
		return false;
	}

	if (Weapon_GetType(weapon) == WEAPON_TYPE_BOW)
	{
		return Projectile_ShootBow(playerid,weapon);
	}

	return Projectile_ShootLoaded(playerid,weapon);
}

stock bool:Projectile_Use(playerid)
{
	new weapon = Combat_GetWeapon(playerid);
	if (!Combat_IsInMode(playerid) || !Weapon_IsRanged(weapon))
	{
		return false;
	}

	if (Weapon_GetType(weapon) == WEAPON_TYPE_BOW)
	{
		return Projectile_Shoot(playerid);
	}

	Projectile_Sync(playerid);
	if (s_RangedStage[playerid] == RANGED_LOADED)
	{
		return Projectile_Shoot(playerid);
	}

	return Projectile_Reload(playerid);
}

stock bool:Projectile_Throw(playerid)
{
	new weapon = Combat_GetWeapon(playerid);
	if (!Combat_IsInMode(playerid) || !Weapon_IsThrowable(weapon) || Combat_IsAttacking(playerid))
	{
		return false;
	}

	if (!Projectile_Ready(playerid) || !Vitals_DrainStamina(playerid,PROJECTILE_STAMINA_THROW))
	{
		return false;
	}

	new model = Weapon_GetModel(weapon);
	ApplyAnimation(playerid,"GRENADE","WEAPON_throw",4.1,false,true,true,true,0,SYNC_ALL);
	if (Projectile_Launch(playerid,PROJECTILE_THROWN,weapon,model) == -1)
	{
		return false;
	}

	Inventory_Take(playerid,ITEM_KIND_WEAPON,weapon,1);
	if (Combat_GetWeapon(playerid) == weapon)
	{
		Combat_Unequip(playerid);
	}

	return true;
}

forward Projectile_OnFired(shooterid,kind,weapon,targetid);

public Projectile_OnFired(shooterid,kind,weapon,targetid)
{
	return 1;
}

forward Projectile_OnHitActor(shooterid,actorid,weapon,Float:damage);

public Projectile_OnHitActor(shooterid,actorid,weapon,Float:damage)
{
	return 1;
}

forward Projectile_OnShot(shooterid,kind,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz);

public Projectile_OnShot(shooterid,kind,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz)
{
	return 1;
}

forward Projectile_OnImpact(shooterid,kind,Float:x,Float:y,Float:z);

public Projectile_OnImpact(shooterid,kind,Float:x,Float:y,Float:z)
{
	return 1;
}

forward Projectile_OnLanded(shooterid,kind);

public Projectile_OnLanded(shooterid,kind)
{
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0; i < MAX_PROJECTILES; i++)
	{
		s_Projectiles[i][E_PROJ_USED] = false;
	}

	s_Crosshair = TextDrawCreate(320.0,215.0,"+");
	TextDrawFont(s_Crosshair,TEXT_DRAW_FONT_2);
	TextDrawLetterSize(s_Crosshair,0.4,1.6);
	TextDrawAlignment(s_Crosshair,TEXT_DRAW_ALIGN_CENTRE);
	TextDrawColour(s_Crosshair,0xE8DCC0AA);
	TextDrawSetOutline(s_Crosshair,1);
	TextDrawBackgroundColour(s_Crosshair,0x000000AA);
}

hook OnPlayerConnect(playerid)
{
	s_ProjectileCooldown[playerid] = 0;
	Projectile_ResetRanged(playerid);
}

hook Character_OnUnloaded(playerid)
{
	Projectile_ResetRanged(playerid);
}

hook Combat_OnEquipped(playerid,weapon)
{
	#pragma unused weapon

	Projectile_Sync(playerid);
}

hook Combat_OnModeChanged(playerid,enabled)
{
	if (enabled && Weapon_IsRanged(Combat_GetWeapon(playerid)))
	{
		Projectile_Sync(playerid);
		Projectile_ShowStage(playerid);
		TextDrawShowForPlayer(playerid,s_Crosshair);
	}
	else
	{
		Projectile_Interrupt(playerid,false);
		TextDrawHideForPlayer(playerid,s_Crosshair);
	}
}

hook Combat_OnKnockedDown(playerid,attackerid)
{
	#pragma unused attackerid

	Projectile_Interrupt(playerid,true);
}

hook Combat_OnStruckDown(playerid)
{
	Projectile_Interrupt(playerid,true);
}

hook Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	#pragma unused attackerid, weapon, damage

	if (Util_IsValidPlayer(targetid))
	{
		Projectile_Interrupt(targetid,true);
	}
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!Combat_IsInMode(playerid))
	{
		return;
	}

	if ((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE) && Weapon_IsRanged(Combat_GetWeapon(playerid)))
	{
		Projectile_Use(playerid);
	}
	else if ((newkeys & KEY_JUMP) && !(oldkeys & KEY_JUMP) && Weapon_IsThrowable(Combat_GetWeapon(playerid)))
	{
		Projectile_Throw(playerid);
	}
}

hook OnDynamicObjectMoved(STREAMER_TAG_OBJECT:objectid)
{
	new slot = Projectile_FindByObject(objectid);
	if (slot != -1 && s_Projectiles[slot][E_PROJ_TARGET] == INVALID_PLAYER_ID && s_Projectiles[slot][E_PROJ_ACTOR] == -1)
	{
		Projectile_Land(slot);
	}
}
