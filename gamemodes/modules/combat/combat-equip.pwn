#define COMBAT_SLOT_MAINHAND (ATTACH_SLOT_HAND)
#define COMBAT_SLOT_OFFHAND (ATTACH_SLOT_HAND_LEFT)
#define COMBAT_SLOT_SCABBARD (ATTACH_SLOT_BACK)
#define COMBAT_SHIELD_RESISTANCE (100.0)

enum E_COMBAT_GEAR
{
	E_GEAR_WEAPON,
	E_GEAR_SHIELD,
	bool:E_GEAR_SHIELD_UP,
	Float:E_GEAR_SHIELD_RESISTANCE,
}

static s_Gear[MAX_PLAYERS][E_COMBAT_GEAR];

stock Combat_GetWeapon(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return INVALID_WEAPON_INDEX;
	}

	return s_Gear[playerid][E_GEAR_WEAPON];
}

stock Combat_GetShield(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return INVALID_SHIELD_INDEX;
	}

	return s_Gear[playerid][E_GEAR_SHIELD];
}

stock bool:Combat_IsShieldUp(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Gear[playerid][E_GEAR_SHIELD] != INVALID_SHIELD_INDEX && s_Gear[playerid][E_GEAR_SHIELD_UP];
}

stock Float:Combat_GetShieldResistance(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0.0;
	}

	return s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE];
}

static Combat_AttachScabbard(playerid,weapon,model)
{
	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_LONGSWORD:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_SPINE,0.459,-0.094,-0.225,-81.9,0.0,-68.7);
		}
		case WEAPON_TYPE_SHORTSWORD:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_RIGHT_THIGH,-0.056,0.243,0.05,-172.7,9.6,114.8);
		}
		case WEAPON_TYPE_DAGGER:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_RIGHT_THIGH,-0.118,0.027,0.096,0.0,0.0,84.8);
		}
		case WEAPON_TYPE_BOW:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_SPINE,0.029,-0.137,-0.053,-81.9,0.0,111.9);
		}
		case WEAPON_TYPE_CROSSBOW:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_RIGHT_THIGH,0.1,0.09,0.11,0.0,-90.0,0.0);
		}
		case WEAPON_TYPE_SLING:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,model,ATTACH_BONE_LEFT_THIGH,0.1,0.09,-0.11,0.0,-90.0,0.0);
		}
	}
}

Combat_AttachSheathed(playerid,weapon)
{
	new model = Weapon_GetScabbardModel(weapon,true);
	Combat_AttachScabbard(playerid,weapon,model);

	if (model != 0)
	{
		return;
	}

	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_SHORTSWORD:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,Weapon_GetModel(weapon),ATTACH_BONE_RIGHT_THIGH,-0.056,0.243,0.05,-172.7,9.6,114.8);
		}
		case WEAPON_TYPE_AXE, WEAPON_TYPE_DAGGER, WEAPON_TYPE_BOW:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,Weapon_GetModel(weapon),ATTACH_BONE_RIGHT_THIGH,0.361,-0.078,0.081,0.0,0.0,-98.6);
		}
		default:
		{
			SetPlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD,Weapon_GetModel(weapon),ATTACH_BONE_SPINE,-0.148,-0.095,-0.206,-80.7,0.0,52.5);
		}
	}
}

Combat_AttachDrawn(playerid,weapon)
{
	new empty = Weapon_GetScabbardModel(weapon,false);
	if (empty != 0)
	{
		Combat_AttachScabbard(playerid,weapon,empty);
	}
	else
	{
		RemovePlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD);
	}

	if (Weapon_GetType(weapon) == WEAPON_TYPE_BOW)
	{
		SetPlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND,Weapon_GetModel(weapon),ATTACH_BONE_RIGHT_HAND,0.108,0.012,0.014,92.9,3.4,0.0);
		return;
	}

	if (Weapon_GetType(weapon) == WEAPON_TYPE_CROSSBOW || Weapon_GetType(weapon) == WEAPON_TYPE_SLING)
	{
		Combat_SwapHeld(playerid,Weapon_GetModel(weapon));
		return;
	}

	SetPlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND,Weapon_GetModel(weapon),ATTACH_BONE_RIGHT_HAND,0.096,0.038,0.0,87.0,-4.2,-174.1);
}

Combat_AttachShield(playerid,bool:up,bool:wall = false)
{
	new shield = s_Gear[playerid][E_GEAR_SHIELD];
	if (shield == INVALID_SHIELD_INDEX)
	{
		return;
	}

	new model = Shield_GetModel(shield);
	if (wall)
	{
		SetPlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND,model,ATTACH_BONE_RIGHT_HAND,0.049,0.0,0.084,-89.9,142.7,-0.8);
		return;
	}

	if (up)
	{
		SetPlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND,model,ATTACH_BONE_LEFT_HAND,0.0,-0.052,0.0,50.5,-1.0,94.7);
		return;
	}

	SetPlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND,model,ATTACH_BONE_SPINE,0.061,-0.118,-0.032,85.5,1.6,0.0);
}

stock Combat_SwapHeld(playerid,modelid)
{
	if (!Combat_IsInMode(playerid) || !Weapon_IsValid(Combat_GetWeapon(playerid)))
	{
		return;
	}

	if (Weapon_GetType(Combat_GetWeapon(playerid)) == WEAPON_TYPE_SLING)
	{
		SetPlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND,modelid,ATTACH_BONE_RIGHT_HAND,0.0,0.0,0.0,90.0,0.0,0.0);
		return;
	}

	SetPlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND,modelid,ATTACH_BONE_RIGHT_HAND,0.0,0.0,0.0,0.0,0.0,90.0);
}

stock Combat_SetOffhandProp(playerid,modelid)
{
	SetPlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND,modelid,ATTACH_BONE_LEFT_HAND,0.0,0.0,0.0,0.0,0.0,90.0);
}

stock bool:Combat_Equip(playerid,weapon)
{
	if (!Util_IsValidPlayer(playerid) || !Weapon_IsValid(weapon) || !Session_HasCharacter(playerid))
	{
		return false;
	}

	if (Combat_IsInMode(playerid))
	{
		Combat_SetMode(playerid,false);
	}

	s_Gear[playerid][E_GEAR_WEAPON] = weapon;
	Character_SetStoredHand(playerid,false,weapon);
	Combat_AttachSheathed(playerid,weapon);
	pawn_call_public("Combat_OnEquipped","dd",playerid,weapon);
	return true;
}

stock Combat_Unequip(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	if (Combat_IsInMode(playerid))
	{
		Combat_SetMode(playerid,false);
	}

	s_Gear[playerid][E_GEAR_WEAPON] = INVALID_WEAPON_INDEX;
	Character_SetStoredHand(playerid,false,INVALID_WEAPON_INDEX);
	RemovePlayerAttachedObject(playerid,COMBAT_SLOT_MAINHAND);
	RemovePlayerAttachedObject(playerid,COMBAT_SLOT_SCABBARD);
}

stock bool:Combat_EquipShield(playerid,shield)
{
	if (!Util_IsValidPlayer(playerid) || !Shield_IsValid(shield) || !Session_HasCharacter(playerid))
	{
		return false;
	}

	s_Gear[playerid][E_GEAR_SHIELD] = shield;
	s_Gear[playerid][E_GEAR_SHIELD_UP] = false;
	s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE] = COMBAT_SHIELD_RESISTANCE;
	Character_SetStoredHand(playerid,true,shield);
	Combat_AttachShield(playerid,false);
	return true;
}

stock Combat_UnequipShield(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Gear[playerid][E_GEAR_SHIELD] = INVALID_SHIELD_INDEX;
	s_Gear[playerid][E_GEAR_SHIELD_UP] = false;
	Character_SetStoredHand(playerid,true,INVALID_SHIELD_INDEX);
	RemovePlayerAttachedObject(playerid,COMBAT_SLOT_OFFHAND);
}

stock bool:Combat_SetShieldUp(playerid,bool:up)
{
	if (!Util_IsValidPlayer(playerid) || s_Gear[playerid][E_GEAR_SHIELD] == INVALID_SHIELD_INDEX)
	{
		return false;
	}

	s_Gear[playerid][E_GEAR_SHIELD_UP] = up;
	Combat_AttachShield(playerid,up);
	return true;
}

Combat_DamageShield(playerid,Float:amount)
{
	s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE] -= amount;
	if (s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE] > 0.0)
	{
		return false;
	}

	s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE] = 0.0;
	Combat_UnequipShield(playerid);
	Gui_Notify(playerid,"Your shield has broken.");
	return true;
}

Combat_ResetGear(playerid)
{
	s_Gear[playerid][E_GEAR_WEAPON] = INVALID_WEAPON_INDEX;
	s_Gear[playerid][E_GEAR_SHIELD] = INVALID_SHIELD_INDEX;
	s_Gear[playerid][E_GEAR_SHIELD_UP] = false;
	s_Gear[playerid][E_GEAR_SHIELD_RESISTANCE] = COMBAT_SHIELD_RESISTANCE;
}

forward Combat_OnEquipped(playerid,weapon);

public Combat_OnEquipped(playerid,weapon)
{
	return 1;
}

CMD:equip(cmdid, playerid, params[])
{
	new weapon;
	if (sscanf(params,"i",weapon))
	{
		Command_Usage(playerid,cmdid,"<weapon index 0..49>");
		return 1;
	}

	if (!Combat_Equip(playerid,weapon))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"No such weapon.");
	}

	return 1;
}

CMD:equipshield(cmdid, playerid, params[])
{
	new shield;
	if (sscanf(params,"i",shield))
	{
		Command_Usage(playerid,cmdid,"<shield index 0..23>");
		return 1;
	}

	if (!Combat_EquipShield(playerid,shield))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"No such shield.");
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Combat_ResetGear(playerid);
}

hook Character_OnUnloaded(playerid)
{
	Combat_ResetGear(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to != SESSION_PLAYING)
	{
		return;
	}

	if (s_Gear[playerid][E_GEAR_WEAPON] != INVALID_WEAPON_INDEX)
	{
		Combat_AttachSheathed(playerid,s_Gear[playerid][E_GEAR_WEAPON]);
	}

	Combat_AttachShield(playerid,s_Gear[playerid][E_GEAR_SHIELD_UP]);
}
