#define ATTACH_SLOT_HEAD (0)
#define ATTACH_SLOT_BODY (1)
#define ATTACH_SLOT_HAND (2)
#define ATTACH_SLOT_HAND_LEFT (3)
#define ATTACH_SLOT_WOUND (4)
#define ATTACH_SLOT_MEAL (5)
#define ATTACH_SLOT_BACK (6)
#define ATTACH_SLOT_INSECTS (8)
#define ATTACH_SLOT_CUFFS (7)
#define ATTACH_SLOT_BREATH (9)

#define ATTACH_BONE_SPINE (1)
#define ATTACH_BONE_HEAD (2)
#define ATTACH_BONE_LEFT_UPPER_ARM (3)
#define ATTACH_BONE_RIGHT_UPPER_ARM (4)
#define ATTACH_BONE_LEFT_HAND (5)
#define ATTACH_BONE_RIGHT_HAND (6)
#define ATTACH_BONE_LEFT_THIGH (7)
#define ATTACH_BONE_RIGHT_THIGH (8)
#define ATTACH_BONE_LEFT_FOOT (9)
#define ATTACH_BONE_RIGHT_FOOT (10)
#define ATTACH_BONE_RIGHT_CALF (11)
#define ATTACH_BONE_LEFT_CALF (12)
#define ATTACH_BONE_LEFT_FOREARM (13)
#define ATTACH_BONE_RIGHT_FOREARM (14)
#define ATTACH_BONE_LEFT_SHOULDER (15)
#define ATTACH_BONE_RIGHT_SHOULDER (16)
#define ATTACH_BONE_NECK (17)
#define ATTACH_BONE_JAW (18)

#define ATTACH_MAX_SLOTS (MAX_PLAYER_ATTACHED_OBJECTS)

enum e_ATTACH_SLOT
{
	bool:E_ATTACH_USED,
	E_ATTACH_MODEL,
	E_ATTACH_BONE,
	Float:E_ATTACH_OFFSET_X,
	Float:E_ATTACH_OFFSET_Y,
	Float:E_ATTACH_OFFSET_Z,
	Float:E_ATTACH_ROTATION_X,
	Float:E_ATTACH_ROTATION_Y,
	Float:E_ATTACH_ROTATION_Z,
	Float:E_ATTACH_SCALE_X,
	Float:E_ATTACH_SCALE_Y,
	Float:E_ATTACH_SCALE_Z,
	E_ATTACH_COLOUR_ONE,
	E_ATTACH_COLOUR_TWO,
}

static s_Attachments[MAX_PLAYERS][ATTACH_MAX_SLOTS][e_ATTACH_SLOT];
static bool:s_AttachRestoring[MAX_PLAYERS];

stock Attach_SlotDefaultBone(slot)
{
	switch (slot)
	{
		case ATTACH_SLOT_HEAD:
		{
			return ATTACH_BONE_HEAD;
		}
		case ATTACH_SLOT_BODY:
		{
			return ATTACH_BONE_SPINE;
		}
		case ATTACH_SLOT_HAND:
		{
			return ATTACH_BONE_RIGHT_HAND;
		}
		case ATTACH_SLOT_HAND_LEFT:
		{
			return ATTACH_BONE_LEFT_HAND;
		}
	}

	return ATTACH_BONE_SPINE;
}

static bool:Attach_IsScopedWeapon(WEAPON:weaponid)
{
	switch (weaponid)
	{
		case WEAPON_SNIPER, WEAPON_ROCKETLAUNCHER, WEAPON_HEATSEEKER, WEAPON_CAMERA:
		{
			return true;
		}
	}

	return false;
}

static Attach_HandleKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(oldkeys & KEY_AIM) || (newkeys & KEY_AIM))
	{
		return;
	}

	if (!Attach_IsScopedWeapon(GetPlayerWeapon(playerid)))
	{
		return;
	}

	Attach_Restore(playerid);
}

stock Attach_Restore(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	s_AttachRestoring[playerid] = true;

	for (new slot = 0;slot < ATTACH_MAX_SLOTS;slot++)
	{
		if (!s_Attachments[playerid][slot][E_ATTACH_USED])
		{
			continue;
		}

		if (!IsPlayerAttachedObjectSlotUsed(playerid,slot))
		{
			s_Attachments[playerid][slot][E_ATTACH_USED] = false;
			continue;
		}

		SetPlayerAttachedObject(playerid,slot,s_Attachments[playerid][slot][E_ATTACH_MODEL],s_Attachments[playerid][slot][E_ATTACH_BONE],s_Attachments[playerid][slot][E_ATTACH_OFFSET_X],s_Attachments[playerid][slot][E_ATTACH_OFFSET_Y],s_Attachments[playerid][slot][E_ATTACH_OFFSET_Z],s_Attachments[playerid][slot][E_ATTACH_ROTATION_X],s_Attachments[playerid][slot][E_ATTACH_ROTATION_Y],s_Attachments[playerid][slot][E_ATTACH_ROTATION_Z],s_Attachments[playerid][slot][E_ATTACH_SCALE_X],s_Attachments[playerid][slot][E_ATTACH_SCALE_Y],s_Attachments[playerid][slot][E_ATTACH_SCALE_Z],s_Attachments[playerid][slot][E_ATTACH_COLOUR_ONE],s_Attachments[playerid][slot][E_ATTACH_COLOUR_TWO]);
	}

	s_AttachRestoring[playerid] = false;
}

static Attach_ClearCache(playerid)
{
	for (new slot = 0;slot < ATTACH_MAX_SLOTS;slot++)
	{
		s_Attachments[playerid][slot][E_ATTACH_USED] = false;
	}

	s_AttachRestoring[playerid] = false;
}

forward Attach_FilterSet(&result,&playerid,&index,&modelid,&bone,&Float:offsetX,&Float:offsetY,&Float:offsetZ,&Float:rotationX,&Float:rotationY,&Float:rotationZ,&Float:scaleX,&Float:scaleY,&Float:scaleZ,&colourOne,&colourTwo);

public Attach_FilterSet(&result,&playerid,&index,&modelid,&bone,&Float:offsetX,&Float:offsetY,&Float:offsetZ,&Float:rotationX,&Float:rotationY,&Float:rotationZ,&Float:scaleX,&Float:scaleY,&Float:scaleZ,&colourOne,&colourTwo)
{
	if (!result || s_AttachRestoring[playerid] || playerid < 0 || playerid >= MAX_PLAYERS || index < 0 || index >= ATTACH_MAX_SLOTS)
	{
		return 1;
	}

	s_Attachments[playerid][index][E_ATTACH_USED] = true;
	s_Attachments[playerid][index][E_ATTACH_MODEL] = modelid;
	s_Attachments[playerid][index][E_ATTACH_BONE] = bone;
	s_Attachments[playerid][index][E_ATTACH_OFFSET_X] = offsetX;
	s_Attachments[playerid][index][E_ATTACH_OFFSET_Y] = offsetY;
	s_Attachments[playerid][index][E_ATTACH_OFFSET_Z] = offsetZ;
	s_Attachments[playerid][index][E_ATTACH_ROTATION_X] = rotationX;
	s_Attachments[playerid][index][E_ATTACH_ROTATION_Y] = rotationY;
	s_Attachments[playerid][index][E_ATTACH_ROTATION_Z] = rotationZ;
	s_Attachments[playerid][index][E_ATTACH_SCALE_X] = scaleX;
	s_Attachments[playerid][index][E_ATTACH_SCALE_Y] = scaleY;
	s_Attachments[playerid][index][E_ATTACH_SCALE_Z] = scaleZ;
	s_Attachments[playerid][index][E_ATTACH_COLOUR_ONE] = colourOne;
	s_Attachments[playerid][index][E_ATTACH_COLOUR_TWO] = colourTwo;

	return 1;
}

forward Attach_FilterRemove(&result,&playerid,&index);

public Attach_FilterRemove(&result,&playerid,&index)
{
#pragma unused result

	if (playerid < 0 || playerid >= MAX_PLAYERS || index < 0 || index >= ATTACH_MAX_SLOTS)
	{
		return 1;
	}

	if (IsPlayerConnected(playerid) && IsPlayerAttachedObjectSlotUsed(playerid,index))
	{
		return 1;
	}

	s_Attachments[playerid][index][E_ATTACH_USED] = false;
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	pawn_add_filter("SetPlayerAttachedObject","iiiifffffffffii","Attach_FilterSet",filter_out);
	pawn_add_filter("RemovePlayerAttachedObject","ii","Attach_FilterRemove",filter_out);

}

hook OnPlayerConnect(playerid)
{
	Attach_ClearCache(playerid);
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	Attach_HandleKeyStateChange(playerid,newkeys,oldkeys);
}
