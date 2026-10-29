#define MOUNT_SLOT (ATTACH_SLOT_BODY)
#define MOUNT_DELAY_MS (800)
#define MOUNT_COOLDOWN_MS (5000)
#define MOUNT_FRAME_IDLE_MS (75)
#define MOUNT_FRAME_MOVE_MS (50)
#define MOUNT_VELOCITY_TROT (0.12)
#define MOUNT_VELOCITY_WALK_FACTOR (0.4)
#define MOUNT_VELOCITY_GALLOP_FACTOR (1.5)
#define MOUNT_VELOCITY_BACK (-0.05)
#define MOUNT_TURN_STEP (6.0)
#define MOUNT_STAMINA_RESUME (65)
#define MOUNT_TURN_STEP_LAG (15.0)
#define MOUNT_LAG_PING (50)
#define MOUNT_MAX_PING (105)
#define MOUNT_SLOPE_LIFT (0.01)
#define MOUNT_RIDE_HEIGHT (1.25)
#define MOUNT_GROUND_REACH (0.5)
#define MOUNT_GROUND_PROBE (2000.0)
#define MOUNT_GROUND_SUPPORT_PROBE (4.0)
#define MOUNT_FALL_SPEED_MAX (0.6)
#define MOUNT_HEIGHT_BAND (0.15)
#define MOUNT_HEIGHT_BAND_LAG (0.085)
#define MOUNT_HEIGHT_BAND_HIGH_LAG (0.05)
#define MOUNT_CLIMB (0.05)
#define MOUNT_CLIMB_STEEP (0.24)
#define MOUNT_CLIMB_GALLOP_SCALE (0.75)
#define MOUNT_CLIMB_STEEP_SCALE (0.5)
#define MOUNT_CLIMB_SCALE (0.25)
#define MOUNT_PULL_SCALE (0.25)
#define MOUNT_WATER_DEPTH (-1.5)
#define MOUNT_WATER_MAX_DEPTH (100)
#define MOUNT_WATER_WARNINGS (2)
#define MOUNT_WATER_WARN_SECONDS (1)
#define MOUNT_WATER_FORGIVE_SECONDS (10)

enum E_RIDE
{
	bool:E_RIDE_ACTIVE,
	E_RIDE_HORSE,
	E_RIDE_FRAME,
	E_MOUNT_GAIT:E_RIDE_GAIT,
	E_RIDE_TOKEN,
	E_RIDE_STAMINA,
	bool:E_RIDE_CAN_GALLOP,
	E_RIDE_MOUNT_TICK,
	bool:E_RIDE_EDITING,
	E_MOUNT_GAIT:E_RIDE_EDIT_GAIT,
	E_RIDE_WATER_WARNINGS,
	E_RIDE_WATER_NEXT,
	E_RIDE_WATER_LAST,
	E_RIDE_STAMINA_MAX,
	Float:E_RIDE_SPEED_SCALE,
	bool:E_RIDE_GALLOPING,
	E_RIDE_REFUSED_TICK,
	E_RIDE_VETO[HORSE_HOLD_LEN],
	bool:E_RIDE_VETOED,
}

static s_Ride[MAX_PLAYERS][E_RIDE];

stock bool:Mount_IsRiding(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Ride[playerid][E_RIDE_ACTIVE];
}

stock Mount_GetHorse(playerid)
{
	return Mount_IsRiding(playerid) ? s_Ride[playerid][E_RIDE_HORSE] : INVALID_HORSE_ID;
}

stock E_MOUNT_GAIT:Mount_GetGait(playerid)
{
	return Mount_IsRiding(playerid) ? s_Ride[playerid][E_RIDE_GAIT] : MOUNT_GAIT_IDLE;
}

stock Mount_GetStamina(playerid)
{
	return Mount_IsRiding(playerid) ? s_Ride[playerid][E_RIDE_STAMINA] : 0;
}

stock Mount_GetStaminaMax(playerid)
{
	return Mount_IsRiding(playerid) ? s_Ride[playerid][E_RIDE_STAMINA_MAX] : MOUNT_STAMINA_MAX;
}

stock bool:Mount_IsGalloping(playerid)
{
	return Mount_IsRiding(playerid) && s_Ride[playerid][E_RIDE_GALLOPING];
}

stock Mount_SetSpeedScale(playerid,Float:scale)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_Ride[playerid][E_RIDE_SPEED_SCALE] = scale;
	}
}

stock Float:Mount_GetSpeedScale(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Ride[playerid][E_RIDE_SPEED_SCALE] : 1.0;
}

stock Mount_Veto(playerid,const message[])
{
	if (Util_IsValidPlayer(playerid))
	{
		s_Ride[playerid][E_RIDE_VETOED] = true;
		strcopy(s_Ride[playerid][E_RIDE_VETO],message,HORSE_HOLD_LEN);
	}
}

stock Mount_SetStamina(playerid,stamina)
{
	if (Mount_IsRiding(playerid))
	{
		s_Ride[playerid][E_RIDE_STAMINA] = Util_ClampInt(stamina,0,s_Ride[playerid][E_RIDE_STAMINA_MAX]);
	}
}

static Mount_AttachFrameAt(playerid,E_MOUNT_GAIT:gait,frame)
{
	new type = Horse_GetType(s_Ride[playerid][E_RIDE_HORSE]), Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz;
	Mount_GetAttach(type,gait,x,y,z,rx,ry,rz);
	SetPlayerAttachedObject(playerid,MOUNT_SLOT,Mount_FrameModel(type,gait,frame),ATTACH_BONE_SPINE,x,y,z,rx,ry,rz);
}

static Mount_AttachFrame(playerid)
{
	Mount_AttachFrameAt(playerid,s_Ride[playerid][E_RIDE_GAIT],s_Ride[playerid][E_RIDE_FRAME]);
}

stock bool:Mount_BeginSeatEdit(playerid,E_MOUNT_GAIT:gait)
{
	if (!Mount_IsRiding(playerid))
	{
		return false;
	}

	s_Ride[playerid][E_RIDE_EDITING] = true;
	s_Ride[playerid][E_RIDE_EDIT_GAIT] = gait;
	Mount_AttachFrameAt(playerid,gait,0);
	EditAttachedObject(playerid,MOUNT_SLOT);
	return true;
}

static E_MOUNT_GAIT:Mount_GaitFromKeys(playerid,KEY:keys,updown,leftright)
{
	if (updown == 0 && leftright == 0)
	{
		return MOUNT_GAIT_IDLE;
	}

	if ((keys & KEY_JUMP) && s_Ride[playerid][E_RIDE_CAN_GALLOP] && !(keys & KEY_WALK) && Mount_TypeCanGallop(Horse_GetType(s_Ride[playerid][E_RIDE_HORSE])))
	{
		return MOUNT_GAIT_GALLOP;
	}

	if (keys & KEY_WALK)
	{
		return MOUNT_GAIT_WALK;
	}

	return MOUNT_GAIT_SPRINT;
}

forward Mount_FrameTick(playerid,token);

public Mount_FrameTick(playerid,token)
{
	if (!IsPlayerConnected(playerid) || !s_Ride[playerid][E_RIDE_ACTIVE] || s_Ride[playerid][E_RIDE_TOKEN] != token)
	{
		return 1;
	}

	if (s_Ride[playerid][E_RIDE_EDITING])
	{
		SetTimerEx("Mount_FrameTick",MOUNT_FRAME_IDLE_MS,false,"dd",playerid,token);
		return 1;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);

	if (Mount_HasLane(playerid))
	{
		leftright = 0;
	}

	new E_MOUNT_GAIT:gait = Mount_GaitFromKeys(playerid,keys,updown,leftright);
	if (gait != s_Ride[playerid][E_RIDE_GAIT])
	{
		s_Ride[playerid][E_RIDE_GAIT] = gait;
		s_Ride[playerid][E_RIDE_FRAME] = 0;
	}

	Mount_AttachFrame(playerid);
	s_Ride[playerid][E_RIDE_FRAME] = (s_Ride[playerid][E_RIDE_FRAME] + 1) % Mount_TypeGaitFrames(Horse_GetType(s_Ride[playerid][E_RIDE_HORSE]),gait);
	SetTimerEx("Mount_FrameTick",gait == MOUNT_GAIT_IDLE ? MOUNT_FRAME_IDLE_MS : MOUNT_FRAME_MOVE_MS,false,"dd",playerid,token);
	return 1;
}

stock bool:Mount_Mount(playerid,horseid)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid) || !Horse_IsStanding(horseid) || s_Ride[playerid][E_RIDE_ACTIVE])
	{
		return false;
	}

	if (Vitals_GetHealth(playerid) < 15.0 || Combat_IsStruckDown(playerid))
	{
		Gui_Notify(playerid,"You're too badly hurt to ride. Recover some health first.");
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a;
	Horse_GetPos(horseid,x,y,z,a);
	pawn_call_public("Mount_OnMounting","dd",playerid,horseid);
	Horse_TakeRider(horseid,playerid);

	s_Ride[playerid][E_RIDE_ACTIVE] = true;
	s_Ride[playerid][E_RIDE_HORSE] = horseid;
	s_Ride[playerid][E_RIDE_FRAME] = 0;
	s_Ride[playerid][E_RIDE_GAIT] = MOUNT_GAIT_IDLE;
	s_Ride[playerid][E_RIDE_TOKEN]++;
	s_Ride[playerid][E_RIDE_STAMINA_MAX] = Horse_GetStaminaMax(horseid);
	s_Ride[playerid][E_RIDE_STAMINA] = s_Ride[playerid][E_RIDE_STAMINA_MAX];
	s_Ride[playerid][E_RIDE_CAN_GALLOP] = true;
	s_Ride[playerid][E_RIDE_GALLOPING] = false;
	s_Ride[playerid][E_RIDE_WATER_WARNINGS] = 0;
	s_Ride[playerid][E_RIDE_WATER_NEXT] = 0;

	SetPlayerPos(playerid,x,y,z + 0.5);
	SetPlayerFacingAngle(playerid,a);
	ApplyAnimation(playerid,"BIKED","BIKEd_Ride",4.0,true,true,true,true,0,SYNC_ALL);
	Mount_AttachFrame(playerid);
	SetTimerEx("Mount_FrameTick",MOUNT_FRAME_IDLE_MS,false,"dd",playerid,s_Ride[playerid][E_RIDE_TOKEN]);
	pawn_call_public("Mount_OnMounted","dd",playerid,horseid);
	return true;
}

stock bool:Mount_Dismount(playerid,bool:placeHorse = true)
{
	if (!Mount_IsRiding(playerid))
	{
		return false;
	}

	new horseid = s_Ride[playerid][E_RIDE_HORSE];
	s_Ride[playerid][E_RIDE_ACTIVE] = false;
	s_Ride[playerid][E_RIDE_EDITING] = false;
	s_Ride[playerid][E_RIDE_TOKEN]++;
	s_Ride[playerid][E_RIDE_HORSE] = INVALID_HORSE_ID;

	Mount_ClearLane(playerid);
	Mount_SetLance(playerid,E_LANCE_NONE);
	RemovePlayerAttachedObject(playerid,MOUNT_SLOT);
	ClearAnimations(playerid,SYNC_ALL);

	if (placeHorse && Horse_IsValid(horseid))
	{
		new Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		Horse_DropRider(horseid,x,y,z - 0.5,a,GetPlayerVirtualWorld(playerid));
		Util_GetLeftOfPoint(x,y,a,1.0,x,y);
		SetPlayerPos(playerid,x,y,z);
		ApplyAnimation(playerid,"BIKED","BIKEd_getoffLHS",4.1,false,false,false,false,0,SYNC_ALL);
	}

	pawn_call_public("Mount_OnDismounted","dd",playerid,horseid);
	return true;
}

stock Mount_Throw(playerid,const message[],Float:damage = 0.0)
{
	if (!Mount_IsRiding(playerid))
	{
		return;
	}

	Mount_Dismount(playerid);
	ApplyAnimation(playerid,"PED","KO_skid_front",4.1,false,true,true,false,0,SYNC_ALL);

	if (damage > 0.0)
	{
		Vitals_Damage(playerid,damage,"thrown from a horse");
	}

	if (message[0] != EOS)
	{
		Gui_Notify(playerid,message);
	}
}

static Mount_TryMountNearby(playerid)
{
	new horseid = Horse_Nearest(playerid);
	if (horseid == INVALID_HORSE_ID)
	{
		return false;
	}

	new tick = GetTickCount();
	if (tick - s_Ride[playerid][E_RIDE_MOUNT_TICK] < MOUNT_COOLDOWN_MS)
	{
		return true;
	}

	new hold[HORSE_HOLD_LEN];
    if (Vitals_GetHealth(playerid) < 15.0)
    {
        s_Ride[playerid][E_RIDE_MOUNT_TICK] = tick;
        Gui_Notify(playerid,"You're too badly hurt to ride. Recover some health first.");
        return true;
    }

	if (Horse_GetHold(horseid,hold))
	{
		s_Ride[playerid][E_RIDE_MOUNT_TICK] = tick;
		Gui_Notify(playerid,hold);
		return true;
	}

	s_Ride[playerid][E_RIDE_VETOED] = false;
	s_Ride[playerid][E_RIDE_VETO][0] = EOS;
	pawn_call_public("Mount_OnTryMount","dd",playerid,horseid);

	if (s_Ride[playerid][E_RIDE_VETOED])
	{
		s_Ride[playerid][E_RIDE_MOUNT_TICK] = tick;

		if (s_Ride[playerid][E_RIDE_VETO][0] != EOS)
		{
			Gui_Notify(playerid,s_Ride[playerid][E_RIDE_VETO]);
		}

		return true;
	}

	new Float:x, Float:y, Float:z, Float:a, Float:sx, Float:sy;
	Horse_GetPos(horseid,x,y,z,a);
	Horse_GetSide(horseid,true,sx,sy);
	new bool:left = IsPlayerInRangeOfPoint(playerid,HORSE_MOUNT_RANGE,sx,sy,z);
	if (!left)
	{
		Horse_GetSide(horseid,false,sx,sy);
		if (!IsPlayerInRangeOfPoint(playerid,HORSE_MOUNT_RANGE,sx,sy,z))
		{
			Gui_Notify(playerid,"Stand at its side to get on.");
			return true;
		}
	}

	pawn_call_public("Mount_OnMounting","dd",playerid,horseid);
	s_Ride[playerid][E_RIDE_MOUNT_TICK] = tick;
	SetPlayerPos(playerid,sx,sy,z);
	SetPlayerFacingAngle(playerid,a);
	ApplyAnimation(playerid,"BIKED",left ? ("BIKEd_jumponR") : ("BIKEd_jumponL"),4.1,false,false,false,true,0,SYNC_ALL);
	SetTimerEx("Mount_MountDelayed",MOUNT_DELAY_MS,false,"ddd",playerid,horseid,Account_GetToken(playerid));
	return true;
}

forward Mount_MountDelayed(playerid,horseid,token);

public Mount_MountDelayed(playerid,horseid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Mount_Mount(playerid,horseid);
	}

	return 1;
}

static bool:Mount_CheckWater(playerid)
{
	new Float:depth, Float:playerDepth, now = gettime();
	CA_IsPlayerInWater(playerid,depth,playerDepth);

	if (playerDepth < MOUNT_WATER_DEPTH || floatround(depth,floatround_round) >= MOUNT_WATER_MAX_DEPTH || (playerDepth == 0.0 && depth == 0.0))
	{
		if (s_Ride[playerid][E_RIDE_WATER_WARNINGS] > 0 && now - s_Ride[playerid][E_RIDE_WATER_LAST] > MOUNT_WATER_FORGIVE_SECONDS)
		{
			s_Ride[playerid][E_RIDE_WATER_WARNINGS] = 0;
		}

		return true;
	}

	s_Ride[playerid][E_RIDE_WATER_LAST] = now;

	if (s_Ride[playerid][E_RIDE_WATER_NEXT] >= now)
	{
		return true;
	}

	if (++s_Ride[playerid][E_RIDE_WATER_WARNINGS] > MOUNT_WATER_WARNINGS)
	{
		s_Ride[playerid][E_RIDE_WATER_WARNINGS] = 0;
		Mount_Dismount(playerid);
		Gui_Notify(playerid,"You've been thrown off your mount for riding on the water.");
		return false;
	}

	s_Ride[playerid][E_RIDE_WATER_NEXT] = now + MOUNT_WATER_WARN_SECONDS;
	Gui_Notify(playerid,sprintf("Mounts don't belong on the water. Ride back to land or you'll be thrown off. Warning %d of %d.",s_Ride[playerid][E_RIDE_WATER_WARNINGS],MOUNT_WATER_WARNINGS));
	return true;
}

static Mount_Drive(playerid)
{
	if (!Mount_CheckWater(playerid))
	{
		return;
	}

	new KEY:keys, updown, leftright, Float:angle, Float:speed = 0.0, type = Horse_GetType(s_Ride[playerid][E_RIDE_HORSE]), ping = GetPlayerPing(playerid), bool:isGalloping = false;
	GetPlayerKeys(playerid,keys,updown,leftright);
	GetPlayerFacingAngle(playerid,angle);
	if (Mount_HasLane(playerid))
	{
		leftright = 0;
	}

	if (updown == KEY_UP)
	{
		speed = MOUNT_VELOCITY_TROT;
	}
	else if (updown == KEY_DOWN)
	{
		speed = MOUNT_VELOCITY_BACK;
	}

	if (leftright == KEY_LEFT)
	{
		angle += ping > MOUNT_MAX_PING ? MOUNT_TURN_STEP_LAG : MOUNT_TURN_STEP;
	}
	else if (leftright == KEY_RIGHT)
	{
		angle -= ping > MOUNT_MAX_PING ? MOUNT_TURN_STEP_LAG : MOUNT_TURN_STEP;
	}

	if (updown != 0 || leftright != 0)
	{
		new horseid = s_Ride[playerid][E_RIDE_HORSE];

		if ((keys & KEY_JUMP) && !(keys & KEY_WALK) && (!s_Ride[playerid][E_RIDE_CAN_GALLOP] || Horse_IsNoGallop(horseid)) && Mount_TypeCanGallop(type) && GetTickCount() - s_Ride[playerid][E_RIDE_REFUSED_TICK] > 3000)
		{
			s_Ride[playerid][E_RIDE_REFUSED_TICK] = GetTickCount();
			pawn_call_public("Mount_OnGallopRefused","dd",playerid,horseid);
		}

		if ((keys & KEY_JUMP) && !(keys & KEY_WALK) && ping < MOUNT_MAX_PING && s_Ride[playerid][E_RIDE_CAN_GALLOP] && s_Ride[playerid][E_RIDE_STAMINA] > 0 && Mount_TypeCanGallop(type) && !Horse_IsNoGallop(horseid))
		{
			speed *= MOUNT_VELOCITY_GALLOP_FACTOR;
			isGalloping = true;

			if (!s_Ride[playerid][E_RIDE_GALLOPING])
			{
				s_Ride[playerid][E_RIDE_GALLOPING] = true;
				pawn_call_public("Mount_OnGallopStart","dd",playerid,horseid);

				if (!s_Ride[playerid][E_RIDE_ACTIVE])
				{
					return;
				}
			}

			if (--s_Ride[playerid][E_RIDE_STAMINA] < MOUNT_STAMINA_GALLOP_MIN)
			{
				s_Ride[playerid][E_RIDE_CAN_GALLOP] = false;
			}
		}
		else
		{
			s_Ride[playerid][E_RIDE_GALLOPING] = false;

			if (keys & KEY_WALK)
			{
				speed *= MOUNT_VELOCITY_WALK_FACTOR;
			}

			if (s_Ride[playerid][E_RIDE_STAMINA] < s_Ride[playerid][E_RIDE_STAMINA_MAX])
			{
				s_Ride[playerid][E_RIDE_STAMINA]++;
			}
		}
	}
	else
	{
		s_Ride[playerid][E_RIDE_GALLOPING] = false;

		if (s_Ride[playerid][E_RIDE_STAMINA] < s_Ride[playerid][E_RIDE_STAMINA_MAX])
		{
			s_Ride[playerid][E_RIDE_STAMINA]++;
		}
	}

	if (s_Ride[playerid][E_RIDE_STAMINA] >= MOUNT_STAMINA_RESUME)
	{
		s_Ride[playerid][E_RIDE_CAN_GALLOP] = true;
	}

	speed *= Mount_TypeSpeedFactor(type) * Horse_GetSpeed(s_Ride[playerid][E_RIDE_HORSE]) * s_Ride[playerid][E_RIDE_SPEED_SCALE];
	new Float:velocityX = speed * floatsin(-angle,degrees), Float:velocityY = speed * floatcos(-angle,degrees);
	Mount_HoldLane(playerid,speed,angle,velocityX,velocityY);
	SetPlayerFacingAngle(playerid,angle);
	SetPlayerVelocity(playerid,velocityX,velocityY,Mount_SlopeLift(playerid,updown != 0,isGalloping));
}

static Float:Mount_HeightBand(playerid)
{
	new ping = GetPlayerPing(playerid);

	if (ping >= MOUNT_MAX_PING)
	{
		return MOUNT_HEIGHT_BAND_HIGH_LAG;
	}

	return ping > MOUNT_LAG_PING ? MOUNT_HEIGHT_BAND_LAG : MOUNT_HEIGHT_BAND;
}

stock Float:Mount_SlopeLift(playerid,bool:isMoving,bool:isGalloping = false)
{
	new Float:x, Float:y, Float:fz, Float:hx, Float:hy, Float:ground;
	GetPlayerPos(playerid,x,y,fz);

    new Float:vx, Float:vy, Float:vz;
    GetPlayerVelocity(playerid,vx,vy,vz);
    new Float:fall = Util_Clamp(vz, -MOUNT_FALL_SPEED_MAX, 0.0) - GetPlayerGravity(playerid);
    fall = Util_Clamp(fall, -MOUNT_FALL_SPEED_MAX, 0.0);

	if (!CA_RayCastLine(x,y,fz + MOUNT_GROUND_REACH,x,y,fz - MOUNT_GROUND_SUPPORT_PROBE,hx,hy,ground) && !CA_RayCastLine(x,y,fz + MOUNT_GROUND_REACH,x,y,fz - MOUNT_GROUND_PROBE,hx,hy,ground))
	{
		return fall;
	}

	new Float:z = ground + MOUNT_RIDE_HEIGHT, Float:band = Mount_HeightBand(playerid), Float:ratio = fz > 0.0 && z > 0.0 ? fz / z : 1.0;

	if (fz > z + band)
	{
        return Util_Clamp(fall, -(fz - z) * MOUNT_PULL_SCALE, 0.0);
	}

	if (!isMoving)
	{
		return MOUNT_SLOPE_LIFT;
	}

	if (fz < z)
	{
		if (z - fz >= MOUNT_CLIMB_STEEP)
		{
			return isGalloping ? (MOUNT_CLIMB + band / ratio) * MOUNT_CLIMB_GALLOP_SCALE : (MOUNT_CLIMB + band * ratio) * MOUNT_CLIMB_STEEP_SCALE;
		}

		return (MOUNT_CLIMB + band * ratio) * MOUNT_CLIMB_SCALE;
	}

	return MOUNT_SLOPE_LIFT;
}

forward Mount_OnMounted(playerid,horseid);

public Mount_OnMounted(playerid,horseid)
{
	return 1;
}

forward Mount_OnDismounted(playerid,horseid);

public Mount_OnDismounted(playerid,horseid)
{
	return 1;
}

forward Mount_OnMounting(playerid,horseid);

public Mount_OnMounting(playerid,horseid)
{
    return 1;
}

forward Mount_OnTryMount(playerid,horseid);

public Mount_OnTryMount(playerid,horseid)
{
	return 1;
}

forward Mount_OnGallopStart(playerid,horseid);

public Mount_OnGallopStart(playerid,horseid)
{
	return 1;
}

forward Mount_OnGallopRefused(playerid,horseid);

public Mount_OnGallopRefused(playerid,horseid)
{
	return 1;
}

forward bool:Mount_KeyContext(playerid);

public bool:Mount_KeyContext(playerid)
{
	return Mount_IsRiding(playerid) || Horse_Nearest(playerid) != INVALID_HORSE_ID;
}

forward bool:Mount_BusyCheck(playerid);

public bool:Mount_BusyCheck(playerid)
{
	return Mount_IsRiding(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Ride[playerid][E_RIDE_ACTIVE] = false;
	s_Ride[playerid][E_RIDE_HORSE] = INVALID_HORSE_ID;
	s_Ride[playerid][E_RIDE_TOKEN]++;
	s_Ride[playerid][E_RIDE_MOUNT_TICK] = 0;
	s_Ride[playerid][E_RIDE_EDITING] = false;
	s_Ride[playerid][E_RIDE_SPEED_SCALE] = 1.0;
	s_Ride[playerid][E_RIDE_STAMINA_MAX] = MOUNT_STAMINA_MAX;
	s_Ride[playerid][E_RIDE_GALLOPING] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_SECONDARY_ATTACK) || (oldkeys & KEY_SECONDARY_ATTACK) || !Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		return;
	}

	if (s_Ride[playerid][E_RIDE_ACTIVE])
	{
        if (!Mount_CanDismount(playerid))
        {
            return;
        }
		Mount_Dismount(playerid);
		return;
	}

	Mount_TryMountNearby(playerid);
}

hook OnPlayerUpdate(playerid)
{
	if (s_Ride[playerid][E_RIDE_ACTIVE] && !s_Ride[playerid][E_RIDE_EDITING])
	{
		Mount_Drive(playerid);
	}
}

hook OnPlayerEditAttachedObject(playerid,EDIT_RESPONSE:response,index,modelid,boneid,Float:fOffsetX,Float:fOffsetY,Float:fOffsetZ,Float:fRotX,Float:fRotY,Float:fRotZ,Float:fScaleX,Float:fScaleY,Float:fScaleZ)
{
	#pragma unused modelid, boneid, fScaleX, fScaleY, fScaleZ

	if (index != MOUNT_SLOT || !s_Ride[playerid][E_RIDE_EDITING])
	{
		return;
	}

	s_Ride[playerid][E_RIDE_EDITING] = false;

	if (response == EDIT_RESPONSE_FINAL && Mount_IsRiding(playerid))
	{
		new type = Horse_GetType(s_Ride[playerid][E_RIDE_HORSE]), name[MOUNT_NAME_LEN];
		Mount_TypeName(type,name);
		Mount_SetAttach(type,s_Ride[playerid][E_RIDE_EDIT_GAIT],fOffsetX,fOffsetY,fOffsetZ,fRotX,fRotY,fRotZ);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Seat saved for every %s at gait %d: %.3f, %.3f, %.3f, %.1f, %.1f, %.1f",name,_:s_Ride[playerid][E_RIDE_EDIT_GAIT],fOffsetX,fOffsetY,fOffsetZ,fRotX,fRotY,fRotZ));
	}

	if (Mount_IsRiding(playerid))
	{
		Mount_AttachFrame(playerid);
	}
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to != SESSION_PLAYING && s_Ride[playerid][E_RIDE_ACTIVE])
	{
		Mount_Dismount(playerid,true);
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	if (s_Ride[playerid][E_RIDE_ACTIVE])
	{
		new horseid = s_Ride[playerid][E_RIDE_HORSE], Float:x, Float:y, Float:z, Float:a;
		GetPlayerPos(playerid,x,y,z);
		GetPlayerFacingAngle(playerid,a);
		s_Ride[playerid][E_RIDE_ACTIVE] = false;
		s_Ride[playerid][E_RIDE_TOKEN]++;
		if (Horse_IsValid(horseid))
		{
			Horse_DropRider(horseid,x,y,z - 0.5,a,GetPlayerVirtualWorld(playerid));
		}
	}
}
