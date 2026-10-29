#define MOUNT_DEV_RANGE (5.0)

static s_MountStandEdit[MAX_PLAYERS] = {INVALID_HORSE_ID, ...};

static const s_MountGaitNames[MOUNT_GAIT_COUNT][8] = {"idle", "walk", "gallop", "sprint"};

CMD<ADMIN_LEVEL_ADMIN>:mountseat(cmdid, playerid, params[])
{
	if (!Mount_IsRiding(playerid))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Get on a mount first, then /mountseat [idle|walk|gallop|sprint].");
		return 1;
	}

	new E_MOUNT_GAIT:gait = Mount_GetGait(playerid);

	if (params[0] != EOS)
	{
		gait = E_MOUNT_GAIT:-1;

		for (new i = 0;i < MOUNT_GAIT_COUNT;i++)
		{
			if (!strcmp(params,s_MountGaitNames[i],true))
			{
				gait = E_MOUNT_GAIT:i;
			}
		}

		if (_:gait == -1)
		{
			Command_Usage(playerid,cmdid,"[idle|walk|gallop|sprint]");
			return 1;
		}
	}

	Mount_BeginSeatEdit(playerid,gait);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Move the %s seat with the gizmo and save. Press ESC to cancel. The frame holds still while you edit.",s_MountGaitNames[_:gait]));
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:mountstand(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	new horseid = Horse_Nearest(playerid,MOUNT_DEV_RANGE);

	if (horseid == INVALID_HORSE_ID || !IsValidDynamicObject(Horse_GetObject(horseid)))
	{
		SendClientMessage(playerid,COMMAND_COLOUR_ERROR,"Stand near a mount that nobody rides, then /mountstand.");
		return 1;
	}

	s_MountStandEdit[playerid] = horseid;
	EditDynamicObject(playerid,Horse_GetObject(horseid));
	SendClientMessage(playerid,0xFFFFFFFF,"Move the standing model with the gizmo and save. Press ESC to cancel.");
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_MountStandEdit[playerid] = INVALID_HORSE_ID;
}

hook OnPlayerEditDynamicObject(playerid,STREAMER_TAG_OBJECT:objectid,response,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz)
{
	new horseid = s_MountStandEdit[playerid];

	if (horseid == INVALID_HORSE_ID || !Horse_IsValid(horseid) || objectid != Horse_GetObject(horseid) || response == _:EDIT_RESPONSE_UPDATE)
	{
		return;
	}

	new type = Horse_GetType(horseid);
	s_MountStandEdit[playerid] = INVALID_HORSE_ID;

	if (response == _:EDIT_RESPONSE_FINAL)
	{
		new Float:hx, Float:hy, Float:hz, Float:ha, name[MOUNT_NAME_LEN];
		Horse_GetPos(horseid,hx,hy,hz,ha);
		Mount_SetStandFromPose(type,hx,hy,hz,ha,x,y,z,rx,ry,rz);
		Mount_TypeName(type,name);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Stand saved for every %s: offset %.3f, %.3f, %.3f, rotation %.1f, %.1f, %.1f (relative to its facing).",name,x - hx,y - hy,z - hz,rx,ry,rz - ha));
	}

	Horse_ReplaceType(type);
}
