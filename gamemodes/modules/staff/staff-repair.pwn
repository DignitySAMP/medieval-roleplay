#define STAFF_REPAIR_NEED (80)
#define STAFF_UNSTICK_RAY_TOP (1000.0)
#define STAFF_UNSTICK_RAY_BOTTOM (-30.0)
#define STAFF_UNSTICK_LIFT (1.0)
#define STAFF_UNSTICK_SEARCH_RADIUS (32)

stock bool:Staff_ResolveRepairTarget(staffid,const params[],&targetid)
{
	targetid = staffid;
	if (!isnull(params) && sscanf(params,"r",targetid))
	{
		return false;
	}

	return Util_IsValidPlayer(targetid) && !IsPlayerNPC(targetid) && Session_HasCharacter(targetid);
}

stock Staff_LogRepair(staffid,targetid,const action[],const detail[] = "")
{
	new who[96], whom[96];
	Staff_TargetName(staffid,who);
	Staff_TargetName(targetid,whom);
	Staff_Log(staffid,action,whom,detail);
	Log_Info("staff","%s: %s on %s %s",action,who,whom,detail);
}

stock bool:Staff_Heal(staffid,targetid)
{
	if (!Staff_HasLevel(staffid,ADMIN_LEVEL_ADMIN) || !Util_IsValidPlayer(targetid) || IsPlayerNPC(targetid) || !Character_IsAlive(targetid))
	{
		return false;
	}

	if (Session_GetState(targetid) == SESSION_DEAD && Lineage_GetLifeClock(targetid) > 0)
	{
		Character_Respawn(targetid,Account_GetToken(targetid));
	}
	else if (!Session_IsPlaying(targetid))
	{
		return false;
	}

	Wounds_Clear(targetid,false);
	Injury_StopBleeding(targetid);
	Combat_Revive(targetid,staffid);
	Vitals_SetHealth(targetid,VITALS_MAX,"staff heal");
	Needs_Set(targetid,NEED_HUNGER,STAFF_REPAIR_NEED);
	Needs_Set(targetid,NEED_THIRST,STAFF_REPAIR_NEED);
	Warmth_Set(targetid,0);
	Staff_LogRepair(staffid,targetid,"heal");
	SendClientMessage(staffid,STAFF_NOTE_COLOUR,"Health, wounds, bleeding and survival needs restored.");
	return true;
}

stock bool:Staff_Revive(staffid,targetid)
{
	if (!Staff_HasLevel(staffid,ADMIN_LEVEL_ADMIN) || !Util_IsValidPlayer(targetid) || IsPlayerNPC(targetid) || !Session_IsPlaying(targetid) || !Combat_Revive(targetid,staffid))
	{
		return false;
	}

	Staff_LogRepair(staffid,targetid,"revive");
	SendClientMessage(staffid,STAFF_NOTE_COLOUR,"Helped the player back to their feet.");
	return true;
}

stock bool:Staff_FindRepairSurface(Float:x,Float:y,Float:z,&Float:surface)
{
	new Float:hitX[MAX_MULTICAST_SIZE], Float:hitY[MAX_MULTICAST_SIZE], Float:hitZ[MAX_MULTICAST_SIZE], Float:hitDist[MAX_MULTICAST_SIZE], hitModel[MAX_MULTICAST_SIZE];
	new Float:top = z + STAFF_UNSTICK_LIFT > STAFF_UNSTICK_RAY_TOP ? z + STAFF_UNSTICK_LIFT : STAFF_UNSTICK_RAY_TOP;
	new hits = CA_RayCastMultiLine(x,y,top,x,y,STAFF_UNSTICK_RAY_BOTTOM,hitX,hitY,hitZ,hitDist,hitModel);
	new bool:found = false, bool:below = false;

	for (new i = 0;i < hits;i++)
	{
		if (hitModel[i] == WATER_OBJECT)
		{
			continue;
		}

		new bool:isBelow = hitZ[i] <= z + STAFF_UNSTICK_LIFT;
		if (!found || (isBelow && (!below || hitZ[i] > surface)) || (!isBelow && !below && hitZ[i] < surface))
		{
			found = true;
			below = isBelow;
			surface = hitZ[i];
		}
	}

	return found;
}

stock bool:Staff_FindRepairGround(&Float:x,&Float:y,&Float:z)
{
	new Float:surface;
	if (Staff_FindRepairSurface(x,y,z,surface))
	{
		z = surface + STAFF_UNSTICK_LIFT;
		return true;
	}

	for (new radius = 2;radius <= STAFF_UNSTICK_SEARCH_RADIUS;radius += 2)
	{
		for (new step = 0;step < 8;step++)
		{
			new Float:sx = x + float(radius) * floatsin(float(step * 45),degrees), Float:sy = y + float(radius) * floatcos(float(step * 45),degrees);
			if (Staff_FindRepairSurface(sx,sy,z,surface))
			{
				x = sx;
				y = sy;
				z = surface + STAFF_UNSTICK_LIFT;
				return true;
			}
		}
	}

	return false;
}

stock bool:Staff_Unstick(staffid,targetid)
{
	if (!Staff_HasLevel(staffid,ADMIN_LEVEL_TRIAL) || !Util_IsValidPlayer(targetid) || IsPlayerNPC(targetid) || !Session_IsPlaying(targetid))
	{
		return false;
	}

	Gui_BeginFlow(targetid);
	Kit_Pick(targetid,KIT_BACK);
	Kit_Close(targetid);
	if (Gui_IsDialogOpen(targetid))
	{
		HidePlayerDialog(targetid);
	}
	Work_Abort(targetid);
	Horses_AbortScene(targetid);
	Emotes_EndPair(targetid);
	Emotes_Stop(targetid);
	Perform_Stop(targetid);
	Faith_StopPrayer(targetid,true);
	Families_StandUp(targetid);
	Mount_Dismount(targetid);
	Combat_SetMode(targetid,false);
	Staff_SetFrozen(targetid,false);
	ClearAnimations(targetid,SYNC_ALL);
	SetCameraBehindPlayer(targetid);
	TogglePlayerControllable(targetid,true);

	new Float:x, Float:y, Float:z, Float:angle;
	GetPlayerPos(targetid,x,y,z);
	GetPlayerFacingAngle(targetid,angle);
	new bool:grounded = Staff_FindRepairGround(x,y,z);
	if (grounded)
	{
		Util_SafeTeleport(targetid,x,y,z,angle,GetPlayerVirtualWorld(targetid),GetPlayerInterior(targetid));
	}
	Staff_LogRepair(staffid,targetid,"unstick",grounded ? ("placed on ground") : ("no ground found within 32 metres"));
	SendClientMessage(staffid,STAFF_NOTE_COLOUR,grounded ? ("Actions cleared and player placed on the ground.") : ("Actions cleared. No ground found within 32 metres. Ask the player to use /tp if they are staff, or bring them with /gethere."));
	return true;
}

stock bool:Staff_ParseTeleport(const params[],&Float:x,&Float:y,&Float:z,&interior,&world)
{
	return !sscanf(params,"fffI(-1)I(-1)",x,y,z,interior,world) && x == x && y == y && z == z && floatabs(x) <= 20000.0 && floatabs(y) <= 20000.0 && floatabs(z) <= 20000.0 && interior >= -1 && interior <= 255 && world >= -1;
}

stock bool:Staff_Teleport(staffid,Float:x,Float:y,Float:z,interior = -1,world = -1)
{
	if (!Staff_HasLevel(staffid,ADMIN_LEVEL_TRIAL) || !Session_IsPlaying(staffid) || x != x || y != y || z != z || floatabs(x) > 20000.0 || floatabs(y) > 20000.0 || floatabs(z) > 20000.0 || interior < -1 || interior > 255 || world < -1)
	{
		return false;
	}

	if (interior == -1)
	{
		interior = GetPlayerInterior(staffid);
	}
	if (world == -1)
	{
		world = GetPlayerVirtualWorld(staffid);
	}
	new Float:angle, detail[128];
	GetPlayerFacingAngle(staffid,angle);
	Util_SafeTeleport(staffid,x,y,z,angle,world,interior);
	format(detail,sizeof(detail),"%.3f %.3f %.3f interior %d world %d",x,y,z,interior,world);
	Staff_LogRepair(staffid,staffid,"tp",detail);
	return true;
}

CMD<ADMIN_LEVEL_ADMIN>:heal(cmdid, playerid, params[])
{
	new targetid;
	if (!Staff_ResolveRepairTarget(playerid,params,targetid))
	{
		Command_Usage(playerid,cmdid,"[player id or name]");
		return 1;
	}
	if (!Staff_Heal(playerid,targetid))
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,"That player can't be healed in their current state.");
	}
	return 1;
}

CMD<ADMIN_LEVEL_ADMIN>:revive(cmdid, playerid, params[])
{
	new targetid;
	if (!Staff_ResolveRepairTarget(playerid,params,targetid))
	{
		Command_Usage(playerid,cmdid,"[player id or name]");
		return 1;
	}
	if (!Staff_Revive(playerid,targetid))
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,"That player isn't struck down. Use /heal to restore health.");
	}
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:unstick(cmdid, playerid, params[])
{
	new targetid;
	if (!Staff_ResolveRepairTarget(playerid,params,targetid))
	{
		Command_Usage(playerid,cmdid,"[player id or name]");
		return 1;
	}
	if (!Staff_Unstick(playerid,targetid))
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,"That player must be playing to clear their stuck actions.");
	}
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:tp(cmdid, playerid, params[])
{
	new Float:x, Float:y, Float:z, interior, world;
	if (!Staff_ParseTeleport(params,x,y,z,interior,world))
	{
		Command_Usage(playerid,cmdid,"<x> <y> <z> [interior 0-255] [world]");
		return 1;
	}
	if (!Staff_Teleport(playerid,x,y,z,interior,world))
	{
		SendClientMessage(playerid,STAFF_NOTE_COLOUR,"You must be playing to teleport.");
	}
	return 1;
}
