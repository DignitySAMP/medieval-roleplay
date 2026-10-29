static bool:s_AttachEditing[MAX_PLAYERS];
static bool:s_AttachPosing[MAX_PLAYERS];
static bool:s_AttachParentShown[MAX_PLAYERS];
static const s_AttachParents[][2][16] = {
	{"torchflame", "torch"}
};

stock bool:Attach_IsEditing(playerid)
{
	return playerid >= 0 && playerid < MAX_PLAYERS && s_AttachEditing[playerid];
}

static Attach_StopPose(playerid)
{
	if (s_AttachParentShown[playerid])
	{
		RemovePlayerAttachedObject(playerid,ATTACH_DEV_PARENT_SLOT);
		s_AttachParentShown[playerid] = false;
	}

	if (s_AttachPosing[playerid])
	{
		s_AttachPosing[playerid] = false;
		ClearAnimations(playerid,SYNC_ALL);
	}
}

static Attach_StartPose(playerid,preset)
{
	new lib[ATTACH_ANIM_LIB_LEN], anim[ATTACH_ANIM_NAME_LEN];

	if (!Attach_GetPresetAnim(preset,lib,anim))
	{
		Attach_StopPose(playerid);
		return;
	}

	s_AttachPosing[playerid] = true;
	ApplyAnimation(playerid,lib,anim,4.1,true,false,false,true,0,SYNC_ALL);
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("Playing %s:%s while you fit it, so it sits right in the pose.",lib,anim));
}

static bool:Attach_Resolve(const what[],boneArg,&model,&bone,Float:pose[9])
{
	new preset = Attach_FindPreset(what);

	if (preset != -1)
	{
		Attach_GetPreset(preset,model,bone,pose);

		if (boneArg != -1)
		{
			bone = boneArg;
		}

		new seenBone = bone;
		Attach_GetSeen(model,seenBone,pose);
		return true;
	}

	model = strval(what);

	if (model == 0)
	{
		return false;
	}

	bone = boneArg;

	if (!Attach_GetSeen(model,bone,pose))
	{
		bone = boneArg == -1 ? ATTACH_BONE_RIGHT_HAND : boneArg;
		for (new i = 0;i < 9;i++)
		{
			pose[i] = i >= 6 ? 1.0 : 0.0;
		}
	}

	return true;
}

CMD<ADMIN_LEVEL_MANAGER>:attach(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new what[ATTACH_PRESET_NAME_LEN], extra[ATTACH_PRESET_NAME_LEN], boneArg = -1, list[512];

	if (sscanf(params,"s[16]S()[16]D(-1)",what,extra,boneArg))
	{
		Attach_FormatPresets(list);
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /attach <name or model id> [bone 1-18] to fit it, /attach seen, /attach reset <name or model id> [bone]. Click the disk to save it for everyone.");
		SendClientMessage(playerid,0xFFFFFFFF,list);
		return 1;
	}

	if (!strcmp(what,"seen",true))
	{
		Attach_FormatSeen(list);
		SendClientMessage(playerid,0xFFFFFFFF,list[0] == EOS ? ("Nothing has been attached since the server started.") : ("Model/bone pairs worn since the server started:"));

		for (new at = 0, len = strlen(list);at < len;at += 120)
		{
			new part[121];
			strmid(part,list,at,at + 120);
			SendClientMessage(playerid,0xFFFFFFFF,part);
		}

		return 1;
	}

	new model, bone, Float:pose[9];

	if (!strcmp(what,"reset",true))
	{
		if (extra[0] == EOS || !Attach_Resolve(extra,boneArg,model,bone,pose))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Use: /attach reset <name or model id> [bone].");
			return 1;
		}

		if (!Attach_ClearFit(model,bone))
		{
			SendClientMessage(playerid,0xFFFFFFFF,sprintf("Model %d on bone %d already uses the code's own fit.",model,bone));
			return 1;
		}

		Attach_SaveFit(model,bone);
		Attach_RefreshAll(model,bone);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("Model %d on bone %d is back to the code's own fit.",model,bone));
		return 1;
	}

	if (extra[0] != EOS)
	{
		boneArg = strval(extra);
	}

	if (boneArg != -1 && (boneArg < 1 || boneArg > 18))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"The bone is 1-18.");
		return 1;
	}

	if (!Attach_Resolve(what,boneArg,model,bone,pose))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"There's no such name. /attach lists them; a model id works too.");
		return 1;
	}

	new preset = Attach_FindPreset(what);
	s_AttachEditing[playerid] = true;
	SetPlayerAttachedObject(playerid,ATTACH_DEV_SLOT,model,bone,pose[0],pose[1],pose[2],pose[3],pose[4],pose[5],pose[6],pose[7],pose[8]);
	Attach_StartPose(playerid,preset != -1 ? preset : Attach_FindPresetByModel(model));
	Attach_ShowParent(playerid,what);
	EditAttachedObject(playerid,ATTACH_DEV_SLOT);
	return 1;
}

static Attach_ShowParent(playerid,const what[])
{
	for (new i = 0;i < sizeof(s_AttachParents);i++)
	{
		new model, bone, Float:pose[9];

		if (!strcmp(what,s_AttachParents[i][0],true) && Attach_Resolve(s_AttachParents[i][1],-1,model,bone,pose))
		{
			SetPlayerAttachedObject(playerid,ATTACH_DEV_PARENT_SLOT,model,bone,pose[0],pose[1],pose[2],pose[3],pose[4],pose[5],pose[6],pose[7],pose[8]);
			s_AttachParentShown[playerid] = true;
			return;
		}
	}
}

CMD<ADMIN_LEVEL_MANAGER>:attachoff(cmdid, playerid, params[])
{
	#pragma unused cmdid, params

	s_AttachEditing[playerid] = false;
	Attach_StopPose(playerid);

	if (IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_DEV_SLOT))
	{
		RemovePlayerAttachedObject(playerid,ATTACH_DEV_SLOT);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_AttachEditing[playerid] = false;
	s_AttachPosing[playerid] = false;
}

hook OnPlayerEditAttachedObject(playerid,EDIT_RESPONSE:response,index,modelid,boneid,Float:fOffsetX,Float:fOffsetY,Float:fOffsetZ,Float:fRotX,Float:fRotY,Float:fRotZ,Float:fScaleX,Float:fScaleY,Float:fScaleZ)
{
	if (index != ATTACH_DEV_SLOT || !s_AttachEditing[playerid] || response == EDIT_RESPONSE_UPDATE)
	{
		return;
	}

	Attach_StopPose(playerid);

	if (response != EDIT_RESPONSE_FINAL)
	{
		return;
	}

	new Float:pose[9];
	pose[0] = fOffsetX;
	pose[1] = fOffsetY;
	pose[2] = fOffsetZ;
	pose[3] = fRotX;
	pose[4] = fRotY;
	pose[5] = fRotZ;
	pose[6] = fScaleX;
	pose[7] = fScaleY;
	pose[8] = fScaleZ;

	if (!Attach_SetFit(modelid,boneid,pose))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"It couldn't be saved: the fit list is full.");
		return;
	}

	new line[192];
	format(line,sizeof(line),"SetPlayerAttachedObject(playerid, slot, %d, %d, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f);",modelid,boneid,fOffsetX,fOffsetY,fOffsetZ,fRotX,fRotY,fRotZ,fScaleX,fScaleY,fScaleZ);
	SendClientMessage(playerid,0xFFFFFFFF,line);
	SendClientMessage(playerid,0xFFFFFFFF,"Saved for everyone: every attachment of this model on this bone now sits like this. /attach reset undoes it.");
	Log_Info("attach","fit saved: %s",line);
	Attach_SaveFit(modelid,boneid);
	Attach_RefreshAll(modelid,boneid);
}
