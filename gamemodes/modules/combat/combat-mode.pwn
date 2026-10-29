#define COMBAT_DODGE_KEY (KEY_SPRINT)

enum E_FIGHT_ANIM
{
	FIGHT_ANIM_OVERHEAD,
	FIGHT_ANIM_LOWER,
	FIGHT_ANIM_LEFT,
	FIGHT_ANIM_RIGHT,
	FIGHT_ANIM_BLOCK,
	FIGHT_ANIM_JAB,
}

enum E_COMBAT_STATE
{
	bool:E_COMBAT_MODE,
	bool:E_COMBAT_ATTACKING,
	bool:E_COMBAT_BLOCKING,
	bool:E_COMBAT_AIMING,
	bool:E_COMBAT_BLOCK_COOLDOWN,
	bool:E_COMBAT_SHIELD_WALL,
	bool:E_COMBAT_DODGING,
	bool:E_COMBAT_DODGE_COOLDOWN,
	bool:E_COMBAT_FISTS,
	bool:E_COMBAT_CROUCHED,
	E_COMBAT_DOWN_UNTIL,
	E_COMBAT_TOKEN,
	E_COMBAT_HINT_TICK,
}

#define COMBAT_KNOCKDOWN_MS (4000)

static s_Combat[MAX_PLAYERS][E_COMBAT_STATE];
static Float:s_CombatStrikeFactor[MAX_PLAYERS] = {1.0, ...};
static bool:s_CombatBlockBarred[MAX_PLAYERS];
static bool:s_CombatTeleportCamera[MAX_PLAYERS];

stock Combat_SetStrikeFactor(playerid,Float:factor)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_CombatStrikeFactor[playerid] = factor;
	}
}

stock Float:Combat_GetStrikeFactor(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_CombatStrikeFactor[playerid] : 1.0;
}

stock Combat_SetBlockBarred(playerid,bool:isBarred)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_CombatBlockBarred[playerid] = isBarred;
	}
}

stock bool:Combat_IsBlockBarred(playerid)
{
	return Util_IsValidPlayer(playerid) && s_CombatBlockBarred[playerid];
}

stock bool:Combat_IsFistsUp(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_MODE] && s_Combat[playerid][E_COMBAT_FISTS];
}

stock bool:Combat_IsCrouched(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_MODE] && s_Combat[playerid][E_COMBAT_CROUCHED] && Weapon_IsRanged(Combat_GetWeapon(playerid));
}

stock bool:Combat_IsKnockedDown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_DOWN_UNTIL] != 0 && GetTickCount() - s_Combat[playerid][E_COMBAT_DOWN_UNTIL] < 0;
}

stock Combat_KnockDown(playerid,attackerid = INVALID_PLAYER_ID)
{
	if (!Util_IsValidPlayer(playerid) || Combat_IsKnockedDown(playerid) || Combat_IsStruckDown(playerid))
	{
		return;
	}

	s_Combat[playerid][E_COMBAT_DOWN_UNTIL] = GetTickCount() + COMBAT_KNOCKDOWN_MS;
	ApplyAnimation(playerid,"PED","KO_SKID_BACK",4.1,false,false,false,true,0,SYNC_ALL);
	SetTimerEx("Combat_GetUp",COMBAT_KNOCKDOWN_MS,false,"dd",playerid,s_Combat[playerid][E_COMBAT_TOKEN]);
	pawn_call_public("Combat_OnKnockedDown","dd",playerid,attackerid);
}

stock bool:Combat_IsInMode(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_MODE];
}

stock bool:Combat_IsAttacking(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_ATTACKING];
}

stock bool:Combat_IsBlocking(playerid)
{
	return Util_IsValidPlayer(playerid) && (s_Combat[playerid][E_COMBAT_BLOCKING] || s_Combat[playerid][E_COMBAT_SHIELD_WALL]);
}

stock bool:Combat_IsShieldWall(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Combat[playerid][E_COMBAT_SHIELD_WALL];
}

bool:Combat_IsIdle(playerid)
{
	return !s_Combat[playerid][E_COMBAT_ATTACKING] && !s_Combat[playerid][E_COMBAT_BLOCKING] && !s_Combat[playerid][E_COMBAT_AIMING] && !s_Combat[playerid][E_COMBAT_SHIELD_WALL] && !s_Combat[playerid][E_COMBAT_DODGING];
}

Combat_GetToken(playerid)
{
	return s_Combat[playerid][E_COMBAT_TOKEN];
}

Combat_SetFlag(playerid,E_COMBAT_STATE:flag,bool:value)
{
	s_Combat[playerid][flag] = value;
}

bool:Combat_GetFlag(playerid,E_COMBAT_STATE:flag)
{
	return bool:s_Combat[playerid][flag];
}

bool:Combat_HintReady(playerid)
{
	new tick = GetTickCount();
	if (tick - s_Combat[playerid][E_COMBAT_HINT_TICK] < 2000)
	{
		return false;
	}

	s_Combat[playerid][E_COMBAT_HINT_TICK] = tick;
	return true;
}

Combat_ResetState(playerid)
{
    s_CombatTeleportCamera[playerid] = false;
	s_Combat[playerid][E_COMBAT_MODE] = false;
	s_Combat[playerid][E_COMBAT_ATTACKING] = false;
	s_Combat[playerid][E_COMBAT_BLOCKING] = false;
	s_Combat[playerid][E_COMBAT_AIMING] = false;
	s_Combat[playerid][E_COMBAT_BLOCK_COOLDOWN] = false;
	s_Combat[playerid][E_COMBAT_SHIELD_WALL] = false;
	s_Combat[playerid][E_COMBAT_DODGING] = false;
	s_Combat[playerid][E_COMBAT_DODGE_COOLDOWN] = false;
	s_Combat[playerid][E_COMBAT_FISTS] = false;
	s_Combat[playerid][E_COMBAT_CROUCHED] = false;
	s_Combat[playerid][E_COMBAT_DOWN_UNTIL] = 0;
	s_Combat[playerid][E_COMBAT_TOKEN]++;
	s_Combat[playerid][E_COMBAT_HINT_TICK] = 0;
	Vitals_SetBusy(playerid,false);
}

static Combat_GuardNativeMelee(playerid)
{
	if (Mount_IsRiding(playerid) || GetPlayerWeapon(playerid) != WEAPON_FIST || GetPlayerState(playerid) != PLAYER_STATE_ONFOOT)
	{
		return;
	}

	new library[16], name[24];
	GetAnimationName(GetPlayerAnimationIndex(playerid),library,sizeof(library),name,sizeof(name));

    if (library[0] == EOS || name[0] == EOS)
    {
        return;
    }

	if ((!strcmp(library,"PED",true) && !strcmp(name,"FIGHTA_",true,7)) || !strcmp(library,"FIGHT_",true,6))
	{
		ClearAnimations(playerid,SYNC_ALL);
	}
}

Combat_ClearAnimation(playerid)
{
	ApplyAnimation(playerid,"CARRY","crry_prtial",1.0,false,false,false,false,0,SYNC_NONE);
	SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
}

Combat_PlayFightAnimation(playerid,E_FIGHT_ANIM:anim)
{
	new weapon = Combat_GetWeapon(playerid);
	new bool:shield = Combat_GetShield(playerid) != INVALID_SHIELD_INDEX;

	if (!Weapon_IsValid(weapon))
	{
		switch (anim)
		{
			case FIGHT_ANIM_JAB: ApplyAnimation(playerid,"GANGS","shake_cara",4.1,false,true,true,true,0,SYNC_ALL);
			case FIGHT_ANIM_OVERHEAD: ApplyAnimation(playerid,"PED","FightA_1",4.1,false,true,true,true,0,SYNC_ALL);
			case FIGHT_ANIM_LEFT: ApplyAnimation(playerid,"PED","FightA_2",4.1,false,true,true,true,0,SYNC_ALL);
			case FIGHT_ANIM_RIGHT: ApplyAnimation(playerid,"PED","FightA_3",4.1,false,true,true,true,0,SYNC_ALL);
			case FIGHT_ANIM_LOWER: ApplyAnimation(playerid,"FIGHT_E","FightKick_B",4.1,false,true,true,true,0,SYNC_ALL);
			case FIGHT_ANIM_BLOCK: ApplyAnimation(playerid,"FIGHT_B","FIGHTB_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
		}

		return;
	}

	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_LONGSWORD:
		{
			switch (anim)
			{
				case FIGHT_ANIM_OVERHEAD: ApplyAnimation(playerid,"SWORD","SWORD_3",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LOWER: ApplyAnimation(playerid,"SWORD","SWORD_4",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LEFT: ApplyAnimation(playerid,"SWORD","SWORD_2",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_RIGHT: ApplyAnimation(playerid,"SWORD","SWORD_1",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_BLOCK: ApplyAnimation(playerid,"SWORD","SWORD_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
				default: {}
			}
		}
		case WEAPON_TYPE_SHORTSWORD, WEAPON_TYPE_DAGGER, WEAPON_TYPE_SPEAR:
		{
			switch (anim)
			{
				case FIGHT_ANIM_OVERHEAD: ApplyAnimation(playerid,"KNIFE","KNIFE_3",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LOWER: ApplyAnimation(playerid,"KNIFE","KNIFE_4",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LEFT: ApplyAnimation(playerid,"KNIFE","KNIFE_2",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_RIGHT: ApplyAnimation(playerid,"KNIFE","KNIFE_1",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_BLOCK:
				{
					if (shield)
					{
						ApplyAnimation(playerid,"FIGHT_B","FIGHTB_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
					}
					else
					{
						ApplyAnimation(playerid,"SWORD","SWORD_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
					}
				}
				default: {}
			}
		}
		case WEAPON_TYPE_BLUNT, WEAPON_TYPE_GREATAXE:
		{
			switch (anim)
			{
				case FIGHT_ANIM_OVERHEAD: ApplyAnimation(playerid,"BASEBALL","BAT_1",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LOWER: ApplyAnimation(playerid,"BASEBALL","BAT_4",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LEFT: ApplyAnimation(playerid,"BASEBALL","BAT_2",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_RIGHT: ApplyAnimation(playerid,"BASEBALL","BAT_3",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_BLOCK: ApplyAnimation(playerid,"SWORD","SWORD_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
				default: {}
			}
		}
		case WEAPON_TYPE_AXE:
		{
			switch (anim)
			{
				case FIGHT_ANIM_OVERHEAD: ApplyAnimation(playerid,"DILDO","DILDO_1",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LOWER: ApplyAnimation(playerid,"BASEBALL","BAT_4",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_LEFT: ApplyAnimation(playerid,"DILDO","DILDO_2",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_RIGHT: ApplyAnimation(playerid,"BASEBALL","BAT_3",4.1,false,true,true,true,0,SYNC_ALL);
				case FIGHT_ANIM_BLOCK:
				{
					if (shield)
					{
						ApplyAnimation(playerid,"FIGHT_B","FIGHTB_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
					}
					else
					{
						ApplyAnimation(playerid,"SWORD","SWORD_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
					}
				}
				default: {}
			}
		}
		case WEAPON_TYPE_BOW, WEAPON_TYPE_CROSSBOW, WEAPON_TYPE_SLING:
		{
			if (anim == FIGHT_ANIM_BLOCK)
			{
				ApplyAnimation(playerid,"SWORD","SWORD_BLOCK",4.1,false,true,true,true,0,SYNC_ALL);
			}
		}
	}
}

Combat_PlayIdleAnimation(playerid)
{
	if (!Weapon_IsValid(Combat_GetWeapon(playerid)))
	{
		ApplyAnimation(playerid,"PED","FIGHTIDLE",4.1,true,true,true,true,0,SYNC_ALL);
		return;
	}

	switch (Weapon_GetType(Combat_GetWeapon(playerid)))
	{
		case WEAPON_TYPE_LONGSWORD: ApplyAnimation(playerid,"SWORD","SWORD_IDLE",4.1,true,true,true,true,0,SYNC_ALL);
		case WEAPON_TYPE_SHORTSWORD, WEAPON_TYPE_DAGGER, WEAPON_TYPE_SPEAR: ApplyAnimation(playerid,"KNIFE","KNIFE_IDLE",4.1,true,true,true,true,0,SYNC_ALL);
		case WEAPON_TYPE_BLUNT, WEAPON_TYPE_AXE, WEAPON_TYPE_GREATAXE: ApplyAnimation(playerid,"BASEBALL","BAT_IDLE",4.1,true,true,true,true,0,SYNC_ALL);
		case WEAPON_TYPE_BOW, WEAPON_TYPE_CROSSBOW, WEAPON_TYPE_SLING:
		{
			if (s_Combat[playerid][E_COMBAT_CROUCHED])
			{
				ApplyAnimation(playerid,"PED","WEAPON_crouch",4.1,true,false,false,true,0,SYNC_ALL);
			}
			else
			{
				ApplyAnimation(playerid,"PED","Gun_stand",4.1,true,true,true,true,0,SYNC_ALL);
			}
		}
	}
}

Combat_PlayMoveAnimation(playerid,updown,leftright)
{
	new bool:bow = Weapon_IsRanged(Combat_GetWeapon(playerid));

	if (bow && s_Combat[playerid][E_COMBAT_CROUCHED])
	{
		if (updown == KEY_UP)
		{
			ApplyAnimation(playerid,"PED","Player_Sneak",4.1,false,true,true,true,0,SYNC_ALL);
		}
		else
		{
			ApplyAnimation(playerid,"PED","WEAPON_crouch",4.1,true,false,false,true,0,SYNC_ALL);
		}

		return;
	}

	if (leftright == KEY_LEFT)
	{
		ApplyAnimation(playerid,"PED",bow ? ("GunMove_L") : ("FIGHTSH_LEFT"),4.1,false,true,true,true,0,SYNC_ALL);
	}
	else if (leftright == KEY_RIGHT)
	{
		ApplyAnimation(playerid,"PED",bow ? ("GunMove_R") : ("FIGHTSH_RIGHT"),4.1,false,true,true,true,0,SYNC_ALL);
	}

	if (updown == KEY_UP)
	{
		ApplyAnimation(playerid,"PED",bow ? ("GunMove_FWD") : ("FIGHTSH_FWD"),4.1,false,true,true,true,0,SYNC_ALL);
	}
	else if (updown == KEY_DOWN)
	{
		ApplyAnimation(playerid,"PED",bow ? ("GunMove_BWD") : ("FIGHTSH_BWD"),4.1,false,true,true,true,0,SYNC_ALL);
	}
}

Combat_FaceCamera(playerid)
{
	new Float:x, Float:y, Float:z, Float:vx, Float:vy, Float:vz;
	GetPlayerCameraFrontVector(playerid,vx,vy,vz);
	GetPlayerCameraPos(playerid,x,y,z);
	Util_FacePoint(playerid,vx * 500.0 + x,vy * 500.0 + y);
}

stock Combat_ClearOffhandProp(playerid)
{
	RemovePlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND);
	Combat_AttachShield(playerid,Combat_IsShieldUp(playerid),Combat_IsShieldWall(playerid));
}

stock bool:Combat_SetMode(playerid,bool:enable)
{
	if (!Util_IsValidPlayer(playerid) || !Session_IsPlaying(playerid))
	{
		return false;
	}

	if (enable == s_Combat[playerid][E_COMBAT_MODE])
	{
        if (!enable)
        {
            SetCameraBehindPlayer(playerid);
        }

		return true;
	}

	if (enable)
	{
        if (Combat_IsStruckDown(playerid) || Mount_IsRiding(playerid) || !Util_IsInteriorReady(playerid))
		{
			return false;
		}

		s_Combat[playerid][E_COMBAT_MODE] = true;
		s_Combat[playerid][E_COMBAT_FISTS] = Combat_GetWeapon(playerid) == INVALID_WEAPON_INDEX;
		s_Combat[playerid][E_COMBAT_CROUCHED] = GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_DUCK && Weapon_IsRanged(Combat_GetWeapon(playerid));

		if (!s_Combat[playerid][E_COMBAT_FISTS])
		{
			Combat_AttachDrawn(playerid,Combat_GetWeapon(playerid));
		}

		pawn_call_public("Combat_OnModeChanged","dd",playerid,1);
		return true;
	}

	s_Combat[playerid][E_COMBAT_MODE] = false;
	s_Combat[playerid][E_COMBAT_ATTACKING] = false;
	s_Combat[playerid][E_COMBAT_BLOCKING] = false;
	s_Combat[playerid][E_COMBAT_AIMING] = false;
	s_Combat[playerid][E_COMBAT_BLOCK_COOLDOWN] = false;
	s_Combat[playerid][E_COMBAT_SHIELD_WALL] = false;
	s_Combat[playerid][E_COMBAT_DODGING] = false;
	s_Combat[playerid][E_COMBAT_DODGE_COOLDOWN] = false;
	s_Combat[playerid][E_COMBAT_CROUCHED] = false;
	s_Combat[playerid][E_COMBAT_TOKEN]++;
	Vitals_SetBusy(playerid,false);
	RemovePlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND);
	Combat_AttachSheathed(playerid,Combat_GetWeapon(playerid));
	if (Combat_GetShield(playerid) != INVALID_SHIELD_INDEX)
	{
		Combat_AttachShield(playerid,Combat_IsShieldUp(playerid));
	}
	Combat_ClearAnimation(playerid);
    SetCameraBehindPlayer(playerid);
	pawn_call_public("Combat_OnModeChanged","dd",playerid,0);
	return true;
}

forward Combat_OnKnockedDown(playerid,attackerid);

public Combat_OnKnockedDown(playerid,attackerid)
{
	return 1;
}

forward Combat_GetUp(playerid,token);

public Combat_GetUp(playerid,token)
{
	if (IsPlayerConnected(playerid) && s_Combat[playerid][E_COMBAT_TOKEN] == token && s_Combat[playerid][E_COMBAT_DOWN_UNTIL] != 0 && !Combat_IsStruckDown(playerid))
	{
		s_Combat[playerid][E_COMBAT_DOWN_UNTIL] = 0;
		ApplyAnimation(playerid,"PED","GETUP",4.1,false,false,false,false,0,SYNC_ALL);
	}

	return 1;
}

forward Combat_OnModeChanged(playerid,enabled);

public Combat_OnModeChanged(playerid,enabled)
{
	return 1;
}

forward bool:Combat_KeyContext(playerid);

public bool:Combat_KeyContext(playerid)
{
	return Combat_IsInMode(playerid);
}

forward bool:Combat_BusyCheck(playerid);

public bool:Combat_BusyCheck(playerid)
{
	return Combat_IsInMode(playerid) || Combat_IsStruckDown(playerid) || Combat_IsKnockedDown(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Combat_ResetState(playerid);
	s_CombatStrikeFactor[playerid] = 1.0;
	s_CombatBlockBarred[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!Session_IsPlaying(playerid) || Gui_IsBusy(playerid))
	{
		return;
	}

	if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_ACTION))
	{
		if (Combat_IsInMode(playerid))
		{
			Combat_SetMode(playerid,false);
		}
		else if (!Combat_SetMode(playerid,true))
		{
            if (!Util_IsInteriorReady(playerid))
            {
                Gui_Notify(playerid,"Wait for the interior to finish loading before fighting.");
            }
            else
            {
                Gui_Notify(playerid,"You can't fight while you're struck down or riding.");
            }
		}
	}

	if ((newkeys & KEY_CROUCH) && !(oldkeys & KEY_CROUCH) && Combat_IsInMode(playerid) && Weapon_IsRanged(Combat_GetWeapon(playerid)) && Combat_IsIdle(playerid))
	{
		s_Combat[playerid][E_COMBAT_CROUCHED] = !s_Combat[playerid][E_COMBAT_CROUCHED];
	}

	if ((newkeys & KEY_SECONDARY_ATTACK) && !(oldkeys & KEY_SECONDARY_ATTACK) && !Keys_IsBusy(playerid,KEY_SECONDARY_ATTACK,KEYS_PRIO_MENU) && Combat_GetShield(playerid) != INVALID_SHIELD_INDEX && !Combat_IsShieldWall(playerid))
	{
		Combat_SetShieldUp(playerid,!Combat_IsShieldUp(playerid));
	}
}

hook OnPlayerUpdate(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	if (!s_Combat[playerid][E_COMBAT_MODE])
	{
		Combat_GuardNativeMelee(playerid);
		return;
	}

	if ((Combat_GetWeapon(playerid) == INVALID_WEAPON_INDEX) != s_Combat[playerid][E_COMBAT_FISTS])
	{
		Combat_SetMode(playerid,false);
		return;
	}

	if (Combat_IsKnockedDown(playerid))
	{
		return;
	}

	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);
	Combat_HandleBlockRelease(playerid,keys);

	if (Combat_IsIdle(playerid))
	{
		Combat_HandleAttackKeys(playerid,keys,updown,leftright);
		Combat_HandleBlockKeys(playerid,keys);
	}

	if (!s_Combat[playerid][E_COMBAT_ATTACKING] && !s_Combat[playerid][E_COMBAT_BLOCKING] && !s_Combat[playerid][E_COMBAT_AIMING] && !s_Combat[playerid][E_COMBAT_DODGE_COOLDOWN] && !s_Combat[playerid][E_COMBAT_BLOCK_COOLDOWN])
	{
		if (s_Combat[playerid][E_COMBAT_SHIELD_WALL])
		{
			ApplyAnimation(playerid,"CAMERA","CAMCRCH_IDLELOOP",4.1,true,false,false,true,0,SYNC_ALL);
		}
		else if ((updown != 0 || leftright != 0) && !(keys & KEY_FIRE))
		{
			Combat_HandleDodgeKeys(playerid,keys,updown,leftright);

			if (keys != COMBAT_DODGE_KEY)
			{
				Combat_PlayMoveAnimation(playerid,updown,leftright);
			}
		}
		else
		{
			Combat_PlayIdleAnimation(playerid);
		}
	}

	Combat_FaceCamera(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to != SESSION_PLAYING)
	{
		Combat_ResetState(playerid);
	}
}

hook Mount_OnMounting(playerid,horseid)
{
	#pragma unused horseid

	if (s_Combat[playerid][E_COMBAT_MODE])
	{
		Combat_SetMode(playerid,false);
	}
}

hook Util_OnTeleporting(playerid,bool:keepMounted)
{
    #pragma unused keepMounted

    s_CombatTeleportCamera[playerid] = Combat_IsInMode(playerid);
    if (Combat_IsInMode(playerid))
    {
        Combat_SetMode(playerid,false);
    }
}

forward Combat_RestoreTeleportCamera(playerid);

public Combat_RestoreTeleportCamera(playerid)
{
    if (s_CombatTeleportCamera[playerid] && Session_IsPlaying(playerid) && Util_IsInteriorReady(playerid) && !Combat_IsInMode(playerid))
    {
        s_CombatTeleportCamera[playerid] = false;
        SetCameraBehindPlayer(playerid);
    }

    return 1;
}

hook Util_OnInteriorReady(playerid)
{
    if (s_CombatTeleportCamera[playerid])
    {
        SetTimerEx("Combat_RestoreTeleportCamera",0,false,"d",playerid);
    }
}
