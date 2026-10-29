#define COMBAT_SWING_RESOLVE_MS (500)
#define COMBAT_FACING_CONE (27.5)
#define COMBAT_BEHIND_CONE (10.0)
#define COMBAT_STAMINA_OVERHEAD (25.0)
#define COMBAT_STAMINA_LOWER (15.0)
#define COMBAT_STAMINA_SIDE (20.0)
#define COMBAT_STAMINA_DODGE_SIDE (35.0)
#define COMBAT_STAMINA_DODGE_BACK (15.0)
#define COMBAT_FIST_REACH (1.3)
#define COMBAT_KNOCKOUT_SECONDS (30)
#define COMBAT_FIST_FLOOR (10.0)
#define COMBAT_FIST_KNOCKDOWN_STAMINA (15.0)

static const Float:s_CombatFistStamina[] = {15.0, 18.0, 12.0, 12.0, 10.0, 8.0};
static const Float:s_CombatFistDamage[] = {3.0, 3.5, 2.5, 2.5, 0.0, 0.5};

static E_FIGHT_ANIM:s_CombatLastSwing[MAX_PLAYERS];
static bool:s_CombatFistBlow[MAX_PLAYERS];
#define COMBAT_DODGE_MIN_STAMINA (65.0)
#define COMBAT_DODGE_MS (500)
#define COMBAT_DODGE_SIDE_COOLDOWN_MS (800)
#define COMBAT_DODGE_BACK_COOLDOWN_MS (500)
#define COMBAT_FIST_RESOLVE_MS (300)
#define COMBAT_SHOVE_PUSH (0.18)
#define COMBAT_SHOVE_LIFT (0.04)
#define COMBAT_NPC_HEIGHT (2.0)

enum E_COMBAT_SEEK_SHAPE
{
	COMBAT_SEEK_NONE,
	COMBAT_SEEK_ARC,
	COMBAT_SEEK_LINE,
}

static E_COMBAT_SEEK_SHAPE:s_CombatSeekShape = COMBAT_SEEK_NONE;
static Float:s_CombatSeekOrigin[3];
static Float:s_CombatSeekDirection[3];
static Float:s_CombatSeekFacing;
static Float:s_CombatSeekRadius;
static Float:s_CombatSeekHeight;
static Float:s_CombatSeekDistance;
static s_CombatSeekActor = INVALID_ACTOR_ID;
static Float:s_CombatSeekActorPos[4];

static Float:Combat_AngleDiff(Float:a,Float:b)
{
	new Float:diff = Util_NormalizeAngle(a) - Util_NormalizeAngle(b);
	while (diff > 180.0)
	{
		diff -= 360.0;
	}
	while (diff < -180.0)
	{
		diff += 360.0;
	}

	return floatabs(diff);
}

forward bool:Combat_IsTourney(playerid);

stock bool:Combat_IsFacing(playerid,targetid,Float:cone)
{
	new Float:x, Float:y, Float:z, Float:tx, Float:ty, Float:tz, Float:facing;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerPos(targetid,tx,ty,tz);
	GetPlayerFacingAngle(playerid,facing);

	return Combat_AngleDiff(Util_GetAngleToPoint(x,y,tx,ty),facing) <= cone;
}

stock bool:Combat_IsBehind(playerid,targetid)
{
	new Float:a, Float:b;
	GetPlayerFacingAngle(playerid,a);
	GetPlayerFacingAngle(targetid,b);

	return Combat_AngleDiff(a,b) <= COMBAT_BEHIND_CONE && Combat_IsFacing(playerid,targetid,COMBAT_BEHIND_CONE);
}

stock bool:Combat_IsTakingFistBlow(playerid)
{
	return Util_IsValidPlayer(playerid) && s_CombatFistBlow[playerid];
}

static Combat_FindTarget(playerid,weapon,&Float:distance)
{
	new best = INVALID_PLAYER_ID, Float:x, Float:y, Float:z, Float:px, Float:py, Float:pz;
	distance = Weapon_IsValid(weapon) ? Weapon_GetReach(weapon) : COMBAT_FIST_REACH;
	GetPlayerPos(playerid,px,py,pz);

	foreach(new i : Player)
	{
		if (i == playerid || !Session_HasCharacter(i) || Session_IsAway(i) || GetPlayerVirtualWorld(i) != GetPlayerVirtualWorld(playerid) || Combat_GetFlag(i,E_COMBAT_DODGING))
		{
			continue;
		}

		GetPlayerPos(i,x,y,z);
		new Float:gap = VectorSize(x - px,y - py,z - pz);

		if (gap > distance || !Combat_IsFacing(playerid,i,COMBAT_FACING_CONE))
		{
			continue;
		}

		distance = gap;
		best = i;
	}

	return best;
}

stock Combat_OfferNpc(actorid,Float:x,Float:y,Float:z,Float:a = 0.0)
{
	if (s_CombatSeekShape == COMBAT_SEEK_NONE || actorid == INVALID_ACTOR_ID)
	{
		return;
	}

	new Float:distance;

	if (s_CombatSeekShape == COMBAT_SEEK_ARC)
	{
		distance = Util_GetDistance2D(s_CombatSeekOrigin[0],s_CombatSeekOrigin[1],x,y);

		if (distance > s_CombatSeekDistance || floatabs(z - s_CombatSeekOrigin[2]) > COMBAT_NPC_HEIGHT || Combat_AngleDiff(Util_GetAngleToPoint(s_CombatSeekOrigin[0],s_CombatSeekOrigin[1],x,y),s_CombatSeekFacing) > COMBAT_FACING_CONE)
		{
			return;
		}
	}
	else
	{
		distance = (x - s_CombatSeekOrigin[0]) * s_CombatSeekDirection[0] + (y - s_CombatSeekOrigin[1]) * s_CombatSeekDirection[1] + (z - s_CombatSeekOrigin[2]) * s_CombatSeekDirection[2];

		if (distance < 0.5 || distance > s_CombatSeekDistance)
		{
			return;
		}

		new Float:cx = s_CombatSeekOrigin[0] + s_CombatSeekDirection[0] * distance, Float:cy = s_CombatSeekOrigin[1] + s_CombatSeekDirection[1] * distance, Float:cz = s_CombatSeekOrigin[2] + s_CombatSeekDirection[2] * distance;

		if (Util_GetDistance2D(cx,cy,x,y) > s_CombatSeekRadius || floatabs(cz - z) > s_CombatSeekHeight)
		{
			return;
		}
	}

	s_CombatSeekDistance = distance;
	s_CombatSeekActor = actorid;
	s_CombatSeekActorPos[0] = x;
	s_CombatSeekActorPos[1] = y;
	s_CombatSeekActorPos[2] = z;
	s_CombatSeekActorPos[3] = a;
}

static Combat_SeekNpc(playerid,&Float:distance)
{
	s_CombatSeekDistance = distance;
	s_CombatSeekActor = INVALID_ACTOR_ID;
	pawn_call_public("Combat_OnNpcSeek","d",playerid);
	s_CombatSeekShape = COMBAT_SEEK_NONE;

	if (s_CombatSeekActor != INVALID_ACTOR_ID)
	{
		distance = s_CombatSeekDistance;
	}

	return s_CombatSeekActor;
}

stock Combat_FindNpcInArc(playerid,Float:reach,&Float:distance = 0.0)
{
	if (!IsPlayerConnected(playerid))
	{
		return INVALID_ACTOR_ID;
	}

	GetPlayerPos(playerid,s_CombatSeekOrigin[0],s_CombatSeekOrigin[1],s_CombatSeekOrigin[2]);
	GetPlayerFacingAngle(playerid,s_CombatSeekFacing);
	s_CombatSeekShape = COMBAT_SEEK_ARC;
	distance = reach;
	return Combat_SeekNpc(playerid,distance);
}

stock Combat_FindNpcOnLine(playerid,Float:sx,Float:sy,Float:sz,Float:dx,Float:dy,Float:dz,Float:radius,Float:height,&Float:distance)
{
	if (!IsPlayerConnected(playerid))
	{
		return INVALID_ACTOR_ID;
	}

	s_CombatSeekOrigin[0] = sx;
	s_CombatSeekOrigin[1] = sy;
	s_CombatSeekOrigin[2] = sz;
	s_CombatSeekDirection[0] = dx;
	s_CombatSeekDirection[1] = dy;
	s_CombatSeekDirection[2] = dz;
	s_CombatSeekRadius = radius;
	s_CombatSeekHeight = height;
	s_CombatSeekShape = COMBAT_SEEK_LINE;
	return Combat_SeekNpc(playerid,distance);
}

static Combat_StrikeNpc(playerid,actorid,weapon)
{
	new bool:isFists = !Weapon_IsValid(weapon), Float:x, Float:y, Float:z, Float:facing;
	new Float:damage = (isFists ? s_CombatFistDamage[(_:s_CombatLastSwing[playerid])] : Weapon_GetDamage(weapon)) * Combat_GetStrikeFactor(playerid) * Traits_Factor(playerid,TRAIT_EFFECT_DAMAGE_DEALT);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,facing);

	if (Combat_AngleDiff(facing,s_CombatSeekActorPos[3]) <= COMBAT_BEHIND_CONE && Combat_AngleDiff(Util_GetAngleToPoint(x,y,s_CombatSeekActorPos[0],s_CombatSeekActorPos[1]),facing) <= COMBAT_BEHIND_CONE)
	{
		damage *= 2.0;
	}

	if (damage > 0.0)
	{
		pawn_call_public("Combat_OnHitNpc","dddf",playerid,actorid,weapon,damage);
	}
}

stock Combat_ResolveSwing(playerid,weapon)
{
	new Float:distance, targetid = Combat_FindTarget(playerid,weapon,distance), actorid = Combat_FindNpcInArc(playerid,distance);

	if (actorid != INVALID_ACTOR_ID)
	{
		Combat_StrikeNpc(playerid,actorid,weapon);
		return INVALID_PLAYER_ID;
	}

	if (targetid == INVALID_PLAYER_ID)
	{
		return INVALID_PLAYER_ID;
	}

	if (Combat_IsTourney(targetid))
	{
		pawn_call_public("Combat_OnTourneyHit","ddd",playerid,targetid,weapon);
		return targetid;
	}

	new bool:isFists = !Weapon_IsValid(weapon), E_FIGHT_ANIM:swing = s_CombatLastSwing[playerid];
	new Float:damage = (isFists ? s_CombatFistDamage[(_:swing)] : Weapon_GetDamage(weapon)) * Combat_GetStrikeFactor(playerid) * Traits_Factor(playerid,TRAIT_EFFECT_DAMAGE_DEALT) * Traits_Factor(targetid,TRAIT_EFFECT_DAMAGE_TAKEN);

	if (Combat_IsBlocking(targetid))
	{
		Combat_ResolveBlock(targetid,playerid,damage);
		return targetid;
	}

	if (Combat_IsStruckDown(targetid))
	{
		if (!isFists && !Combat_IsTourney(targetid))
		{
			Combat_ExecuteDowned(playerid,targetid);
		}

		return targetid;
	}

	if (Combat_IsTourney(targetid))
	{
		damage *= 0.5;
	}

	if (Combat_IsBehind(playerid,targetid))
	{
		damage *= 2.0;
	}

	if (isFists)
	{
		Combat_LandFistBlow(playerid,targetid,swing,damage);
		return targetid;
	}

	new source[COMBAT_NAME_LEN];
	Weapon_GetName(weapon,source);
	damage = Combat_CapToStrikeDown(targetid,damage);
	new bool:wasDown = Combat_IsStruckDown(targetid);
	Vitals_Damage(targetid,damage,source);
	pawn_call_public("Combat_OnHit","dddf",playerid,targetid,weapon,damage);

	if (!wasDown && Combat_IsStruckDown(targetid))
	{
		pawn_call_public("Combat_OnFelled","dd",playerid,targetid);
	}
	return targetid;
}

static Combat_LandFistBlow(playerid,targetid,E_FIGHT_ANIM:swing,Float:damage)
{
	new Float:health = Vitals_GetHealth(targetid), bool:isKnockout = health - damage <= COMBAT_FIST_FLOOR;

	if (isKnockout)
	{
		damage = health - COMBAT_FIST_FLOOR;
	}

	s_CombatFistBlow[targetid] = true;

	if (damage > 0.0)
	{
		Vitals_Damage(targetid,damage,"fists");
	}

	s_CombatFistBlow[targetid] = false;
	pawn_call_public("Combat_OnHit","dddf",playerid,targetid,INVALID_WEAPON_INDEX,damage);

	if (isKnockout)
	{
		if (Combat_StrikeDown(targetid,COMBAT_KNOCKOUT_SECONDS,true))
		{
			pawn_call_public("Combat_OnFelled","dd",playerid,targetid);
		}

		return;
	}

	if (swing == FIGHT_ANIM_LOWER || Vitals_GetStamina(targetid) < COMBAT_FIST_KNOCKDOWN_STAMINA)
	{
		Combat_KnockDown(targetid,playerid);
		return;
	}

	if (swing == FIGHT_ANIM_JAB)
	{
		new Float:ax, Float:ay, Float:az, Float:tx, Float:ty, Float:tz;
		GetPlayerPos(playerid,ax,ay,az);
		GetPlayerPos(targetid,tx,ty,tz);

		new Float:distance = VectorSize(tx - ax,ty - ay,0.0);

		if (distance > 0.01)
		{
			SetPlayerVelocity(targetid,(tx - ax) / distance * COMBAT_SHOVE_PUSH,(ty - ay) / distance * COMBAT_SHOVE_PUSH,COMBAT_SHOVE_LIFT);
		}
	}

	if (!Combat_IsInMode(targetid))
	{
		ApplyAnimation(targetid,"PED",swing == FIGHT_ANIM_LEFT ? ("HIT_R") : (swing == FIGHT_ANIM_RIGHT ? ("HIT_L") : ("HIT_FRONT")),4.1,false,true,true,false,0,SYNC_ALL);
	}
}

static Combat_Swing(playerid,E_FIGHT_ANIM:anim,Float:stamina)
{
	if (!Weapon_IsValid(Combat_GetWeapon(playerid)))
	{
		stamina = s_CombatFistStamina[_:anim];
	}

	s_CombatLastSwing[playerid] = anim;

	if (!Vitals_DrainStamina(playerid,stamina))
	{
		if (Combat_HintReady(playerid))
		{
			Gui_Notify(playerid,"You're out of stamina. Stop for a few seconds to get your breath back.");
		}
		return;
	}

	Combat_SetFlag(playerid,E_COMBAT_ATTACKING,true);
	Vitals_SetBusy(playerid,true);
	Combat_PlayFightAnimation(playerid,anim);
	pawn_call_public("Combat_OnSwing","dd",playerid,_:anim);
	SetTimerEx("Combat_SwingResolve",Weapon_IsValid(Combat_GetWeapon(playerid)) ? COMBAT_SWING_RESOLVE_MS : COMBAT_FIST_RESOLVE_MS,false,"ddd",playerid,Combat_GetToken(playerid),Combat_GetWeapon(playerid));
}

forward Combat_SwingResolve(playerid,token,weapon);

public Combat_SwingResolve(playerid,token,weapon)
{
	if (!IsPlayerConnected(playerid) || Combat_GetToken(playerid) != token)
	{
		return 1;
	}

	Combat_SetFlag(playerid,E_COMBAT_ATTACKING,false);
	Vitals_SetBusy(playerid,Combat_IsBlocking(playerid) || Combat_GetFlag(playerid,E_COMBAT_AIMING));

	if (Combat_IsInMode(playerid))
	{
		Combat_ResolveSwing(playerid,weapon);
	}

	return 1;
}

Combat_HandleAttackKeys(playerid,KEY:keys,updown,leftright)
{
	if (!(keys & KEY_FIRE))
	{
		return;
	}

	if (Weapon_IsRanged(Combat_GetWeapon(playerid)))
	{
		return;
	}

	if (updown == 0 && leftright == 0)
	{
		if (!Weapon_IsValid(Combat_GetWeapon(playerid)))
		{
			Combat_Swing(playerid,FIGHT_ANIM_JAB,0.0);
		}

		return;
	}

	if (updown == KEY_UP)
	{
		Combat_Swing(playerid,FIGHT_ANIM_OVERHEAD,COMBAT_STAMINA_OVERHEAD);
	}
	else if (updown == KEY_DOWN)
	{
		Combat_Swing(playerid,FIGHT_ANIM_LOWER,COMBAT_STAMINA_LOWER);
	}
	else if (leftright == KEY_LEFT)
	{
		Combat_Swing(playerid,FIGHT_ANIM_LEFT,COMBAT_STAMINA_SIDE);
	}
	else if (leftright == KEY_RIGHT)
	{
		Combat_Swing(playerid,FIGHT_ANIM_RIGHT,COMBAT_STAMINA_SIDE);
	}
}

static Combat_Dodge(playerid,const lib[],const anim[],Float:stamina,bool:isSideways,cooldownMs)
{
	if (!Vitals_DrainStamina(playerid,stamina))
	{
		return;
	}

	Combat_SetFlag(playerid,E_COMBAT_DODGING,true);
	Combat_SetFlag(playerid,E_COMBAT_DODGE_COOLDOWN,true);
	ApplyAnimation(playerid,lib,anim,4.1,false,true,true,true,0,SYNC_ALL);
	SetTimerEx("Combat_DodgeEnd",COMBAT_DODGE_MS,false,"dd",playerid,Combat_GetToken(playerid));
	SetTimerEx("Combat_DodgeCooldownEnd",cooldownMs,false,"dd",playerid,Combat_GetToken(playerid));
	pawn_call_public("Combat_OnDodge","dd",playerid,isSideways);
}

forward Combat_DodgeEnd(playerid,token);

public Combat_DodgeEnd(playerid,token)
{
	if (IsPlayerConnected(playerid) && Combat_GetToken(playerid) == token)
	{
		Combat_SetFlag(playerid,E_COMBAT_DODGING,false);
	}

	return 1;
}

forward Combat_DodgeCooldownEnd(playerid,token);

public Combat_DodgeCooldownEnd(playerid,token)
{
	if (IsPlayerConnected(playerid) && Combat_GetToken(playerid) == token)
	{
		Combat_SetFlag(playerid,E_COMBAT_DODGE_COOLDOWN,false);
	}

	return 1;
}

Combat_HandleDodgeKeys(playerid,KEY:keys,updown,leftright)
{
	if (keys != COMBAT_DODGE_KEY || Combat_GetFlag(playerid,E_COMBAT_DODGING))
	{
		return;
	}

	if ((leftright == KEY_LEFT || leftright == KEY_RIGHT) && (Combat_GetShield(playerid) == INVALID_SHIELD_INDEX || Weapon_GetType(Combat_GetWeapon(playerid)) == WEAPON_TYPE_GREATAXE))
	{
		if (Vitals_GetStamina(playerid) <= COMBAT_DODGE_MIN_STAMINA)
		{
			if (Combat_HintReady(playerid))
			{
				Gui_Notify(playerid,"You're too tired to roll aside. Let your stamina come back first.");
			}

			return;
		}

		Combat_Dodge(playerid,"PED",leftright == KEY_LEFT ? ("CROUCH_ROLL_L") : ("CROUCH_ROLL_R"),COMBAT_STAMINA_DODGE_SIDE,true,COMBAT_DODGE_SIDE_COOLDOWN_MS);
		return;
	}

	if (updown == KEY_DOWN)
	{
		Combat_Dodge(playerid,"PED","FIGHTSHB",COMBAT_STAMINA_DODGE_BACK,false,COMBAT_DODGE_BACK_COOLDOWN_MS);
	}
}

forward Combat_OnDodge(playerid,bool:isSideways);

public Combat_OnDodge(playerid,bool:isSideways)
{
	return 1;
}

forward Combat_OnSwing(playerid,anim);

public Combat_OnSwing(playerid,anim)
{
	return 1;
}

forward Combat_OnNpcSeek(playerid);

public Combat_OnNpcSeek(playerid)
{
	return 1;
}

forward Combat_OnHitNpc(attackerid,actorid,weapon,Float:damage);

public Combat_OnHitNpc(attackerid,actorid,weapon,Float:damage)
{
	return 1;
}

forward Combat_OnTourneyHit(attackerid,targetid,weapon);

public Combat_OnTourneyHit(attackerid,targetid,weapon)
{
	return 1;
}

forward Combat_OnHit(attackerid,targetid,weapon,Float:damage);

public Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	return 1;
}
