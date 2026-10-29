#define COMBAT_BLOCK_ANIM_MS (350)
#define COMBAT_STAMINA_BLOCK (15.0)
#define COMBAT_BLOCK_CONE_BARE (60.0)
#define COMBAT_BLOCK_CONE_SHIELD (80.0)
#define COMBAT_BLOCK_CONE_WALL (90.0)
#define COMBAT_KNOCKBACK (-0.3)

static bool:s_RangedAiming[MAX_PLAYERS];

static Combat_Knockback(playerid)
{
	new Float:vx, Float:vy, Float:vz, Float:angle;
	GetPlayerVelocity(playerid,vx,vy,vz);
	GetPlayerFacingAngle(playerid,angle);
	SetPlayerVelocity(playerid,COMBAT_KNOCKBACK * floatsin(-angle,degrees),COMBAT_KNOCKBACK * floatcos(-angle,degrees),vz);
}

Combat_ResolveBlock(defenderid,attackerid,Float:damage)
{
	new Float:cone = COMBAT_BLOCK_CONE_BARE;
	if (Combat_IsShieldWall(defenderid))
	{
		cone = COMBAT_BLOCK_CONE_WALL;
	}
	else if (Combat_GetShield(defenderid) != INVALID_SHIELD_INDEX)
	{
		cone = COMBAT_BLOCK_CONE_SHIELD;
	}

	if (!Combat_IsFacing(defenderid,attackerid,cone))
	{
		new source[COMBAT_NAME_LEN];
		Weapon_GetName(Combat_GetWeapon(attackerid),source);
		new bool:wasDown = Combat_IsStruckDown(defenderid);
		Vitals_Damage(defenderid,Combat_CapToStrikeDown(defenderid,damage),source);
		pawn_call_public("Combat_OnHit","dddf",attackerid,defenderid,Combat_GetWeapon(attackerid),damage);

		if (!wasDown && Combat_IsStruckDown(defenderid))
		{
			pawn_call_public("Combat_OnFelled","dd",attackerid,defenderid);
		}

		return;
	}

	PlayerPlaySound(defenderid,Combat_IsShieldUp(defenderid) ? 1135 : 17807,0.0,0.0,0.0);
	PlayerPlaySound(attackerid,Combat_IsShieldUp(defenderid) ? 1135 : 17807,0.0,0.0,0.0);

	Combat_Knockback(attackerid);
	Vitals_Damage(attackerid,Combat_CapToStrikeDown(attackerid,float(2 + random(3))),"parry");
	Vitals_DrainStamina(attackerid,20.0);

	new Float:parry = Traits_Factor(defenderid,TRAIT_EFFECT_PARRY);

	if (!Combat_IsShieldUp(defenderid))
	{
		Combat_Knockback(defenderid);
		Vitals_DrainStamina(defenderid,15.0 * parry);
		Vitals_Damage(defenderid,Combat_CapToStrikeDown(defenderid,float(1 + random(2)) * parry),"parry");
	}
	else
	{
		Vitals_DrainStamina(defenderid,5.0 * parry);
		if (Combat_DamageShield(defenderid,damage * parry))
		{
			new bool:wasWall = Combat_GetFlag(defenderid,E_COMBAT_SHIELD_WALL);
			Combat_SetFlag(defenderid,E_COMBAT_BLOCKING,false);
			Combat_SetFlag(defenderid,E_COMBAT_SHIELD_WALL,false);

			if (wasWall)
			{
				Vitals_SetBusy(defenderid,Combat_IsAttacking(defenderid));
				Combat_ClearAnimation(defenderid);
			}

			Gui_Notify(attackerid,"You broke their shield.");
		}
	}

	pawn_call_public("Combat_OnBlocked","ddf",defenderid,attackerid,damage);
}

stock bool:Combat_IsRangedAiming(playerid)
{
    return Util_IsValidPlayer(playerid) && s_RangedAiming[playerid];
}

stock bool:Combat_SetRangedAim(playerid,bool:enable)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return false;
    }

    if (enable && (!Combat_IsInMode(playerid) || !Weapon_IsRanged(Combat_GetWeapon(playerid)) || Combat_IsAttacking(playerid) || Combat_IsKnockedDown(playerid) || Combat_IsStruckDown(playerid) || Gui_IsBusy(playerid)))
    {
        return false;
    }

    if (s_RangedAiming[playerid] == enable)
    {
        return true;
    }

    s_RangedAiming[playerid] = enable;
    Combat_SetFlag(playerid,E_COMBAT_AIMING,enable);
    Vitals_SetBusy(playerid,enable || Combat_IsAttacking(playerid));
    if (enable)
    {
        ApplyAnimation(playerid,"PED",Combat_IsCrouched(playerid) ? ("WEAPON_crouch") : ("Gun_stand"),4.1,true,false,false,true,0,SYNC_ALL);
    }
    else if (Combat_IsInMode(playerid) && !Combat_IsKnockedDown(playerid) && !Combat_IsStruckDown(playerid))
    {
        Combat_ClearAnimation(playerid);
    }

    return true;
}

Combat_HandleBlockKeys(playerid,KEY:keys)
{
    if (Weapon_IsRanged(Combat_GetWeapon(playerid)))
    {
        if (keys & KEY_HANDBRAKE)
        {
            Combat_SetRangedAim(playerid,true);
        }

        return;
    }

	if (!(keys & KEY_HANDBRAKE) || Combat_GetFlag(playerid,E_COMBAT_BLOCKING) || Combat_GetFlag(playerid,E_COMBAT_BLOCK_COOLDOWN))
	{
		return;
	}

	if (Combat_IsBlockBarred(playerid))
	{
		if (Combat_HintReady(playerid))
		{
			Gui_Notify(playerid,"Your broken arm won't hold a block.");
		}

		return;
	}

	if (!Vitals_DrainStamina(playerid,COMBAT_STAMINA_BLOCK))
	{
		return;
	}

	Combat_SetFlag(playerid,E_COMBAT_BLOCKING,true);
	Combat_SetFlag(playerid,E_COMBAT_BLOCK_COOLDOWN,true);
	Vitals_SetBusy(playerid,true);
	Combat_PlayFightAnimation(playerid,FIGHT_ANIM_BLOCK);
	SetTimerEx("Combat_BlockCooldownEnd",COMBAT_BLOCK_ANIM_MS,false,"dd",playerid,Combat_GetToken(playerid));
}

Combat_HandleBlockRelease(playerid,KEY:keys)
{
    if (s_RangedAiming[playerid])
    {
        if (!(keys & KEY_HANDBRAKE) || !Weapon_IsRanged(Combat_GetWeapon(playerid)) || !Combat_IsInMode(playerid))
        {
            Combat_SetRangedAim(playerid,false);
        }

        return;
    }

	if ((keys & KEY_HANDBRAKE) || !Combat_GetFlag(playerid,E_COMBAT_BLOCKING))
	{
		return;
	}

	Combat_SetFlag(playerid,E_COMBAT_BLOCKING,false);
	Vitals_SetBusy(playerid,Combat_IsAttacking(playerid));
}

forward Combat_BlockCooldownEnd(playerid,token);

public Combat_BlockCooldownEnd(playerid,token)
{
	if (IsPlayerConnected(playerid) && Combat_GetToken(playerid) == token)
	{
		Combat_SetFlag(playerid,E_COMBAT_BLOCK_COOLDOWN,false);
	}

	return 1;
}

stock bool:Combat_SetShieldWall(playerid,bool:enable)
{
	if (!Combat_IsInMode(playerid) || Combat_GetShield(playerid) == INVALID_SHIELD_INDEX || !Combat_IsShieldUp(playerid))
	{
		return false;
	}

	if (Combat_IsAttacking(playerid) || Combat_GetFlag(playerid,E_COMBAT_BLOCK_COOLDOWN))
	{
		return false;
	}

	Combat_SetFlag(playerid,E_COMBAT_SHIELD_WALL,enable);
	Vitals_SetBusy(playerid,enable);
	Combat_AttachShield(playerid,true,enable);
	if (!enable)
	{
		Combat_ClearAnimation(playerid);
	}

	return true;
}

forward Combat_OnBlocked(defenderid,attackerid,Float:damage);

public Combat_OnBlocked(defenderid,attackerid,Float:damage)
{
	return 1;
}

stock Combat_ClearSyncedStance(playerid)
{
    if (!Util_IsValidPlayer(playerid) || GetPlayerState(playerid) == PLAYER_STATE_DRIVER || GetPlayerState(playerid) == PLAYER_STATE_PASSENGER)
    {
        return;
    }

    ApplyAnimation(playerid,"CARRY","crry_prtial",1.0,false,false,false,false,0,SYNC_ALL);
    ClearAnimations(playerid,SYNC_ALL);
    SetPlayerSpecialAction(playerid,SPECIAL_ACTION_NONE);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
    s_RangedAiming[playerid] = false;
}

hook Combat_OnModeChanged(playerid,enabled)
{
    if (!enabled)
    {
        Combat_SetRangedAim(playerid,false);
        Combat_ClearSyncedStance(playerid);
    }
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
    if (to != SESSION_PLAYING)
    {
        Combat_SetRangedAim(playerid,false);
        if (from == SESSION_PLAYING)
        {
            Combat_ClearSyncedStance(playerid);
        }
    }
}

hook Combat_OnKnockedDown(playerid,attackerid)
{
    #pragma unused attackerid

    Combat_SetRangedAim(playerid,false);
}

hook Combat_OnStruckDown(playerid)
{
    Combat_SetRangedAim(playerid,false);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if (!(newkeys & KEY_HANDBRAKE) && (oldkeys & KEY_HANDBRAKE))
    {
        Combat_SetRangedAim(playerid,false);
    }

	if ((newkeys & KEY_CTRL_BACK) && !(oldkeys & KEY_CTRL_BACK) && Combat_IsInMode(playerid))
	{
		if (!Combat_SetShieldWall(playerid,!Combat_IsShieldWall(playerid)) && Combat_HintReady(playerid))
		{
			Gui_Notify(playerid,"Press F to raise your shield first.");
		}
	}
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
    #pragma unused killerid, reason

    Combat_ClearSyncedStance(playerid);
}

hook Mount_OnDismounted(playerid,horseid)
{
    #pragma unused horseid

    if (Combat_IsInMode(playerid))
    {
        Combat_SetMode(playerid,false);
    }
}
