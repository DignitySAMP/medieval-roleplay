static Light_DevPlace(playerid,kind)
{
	yield 1;

	new Float:x, Float:y, Float:z, Float:a, Float:groundZ, world = GetPlayerVirtualWorld(playerid), interior = GetPlayerInterior(playerid);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += 1.5 * floatsin(-a,degrees);
	y += 1.5 * floatcos(-a,degrees);

	if (!Placement_FindSurface(x,y,z + 0.5,LIGHT_PLACE_REACH,groundZ))
	{
		groundZ = z - 1.0;
	}

	new source = await Light_CreateKept(kind,x,y,groundZ,a,world,interior);

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	new name[LIGHT_NAME_LEN];
	Light_GetKindName(kind,name);
	SendClientMessage(playerid,0xFFFFFFFF,source == -1 ? ("It couldn't be saved. The list may be full.") : sprintf("Placed a cold %s. Add fuel with Y, or /light fuel <minutes>.",name));
}

static Light_DevGiveKit(playerid)
{
	Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_TORCH,3);
	Inventory_Give(playerid,ITEM_KIND_MISC,ITEM_LANTERN,1,ITEM_STARS_MIN,ITEM_FRESH_NOW,ITEM_WEAR_MAX);
	Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE,3);
	Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX,2);
	Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_FLINT,1);
	Inventory_Give(playerid,ITEM_KIND_MATERIAL,ITEM_FIREWOOD,3);
}

CMD<ADMIN_LEVEL_TRIAL>:light(cmdid, playerid, params[])
{
	#pragma unused cmdid

	new action[12], value;

	if (sscanf(params,"s[12]D(0)",action,value))
	{
		SendClientMessage(playerid,0xFFFFFFFF,"Use: /light brazier, bonfire, fuel <minutes>, out, remove, list, kit, tune, moon");
		return 1;
	}

	if (!strcmp(action,"brazier",true) || !strcmp(action,"bonfire",true))
	{
		Light_DevPlace(playerid,!strcmp(action,"brazier",true) ? LIGHT_SOURCE_BRAZIER : LIGHT_SOURCE_BONFIRE);
		return 1;
	}

	if (!strcmp(action,"fuel",true) || !strcmp(action,"out",true) || !strcmp(action,"remove",true))
	{
		new source = Light_FindSourceForPlayer(playerid,4.0);

		if (source == -1)
		{
			SendClientMessage(playerid,0xFFFFFFFF,"There's no light source within 4 m of you.");
			return 1;
		}

		if (!strcmp(action,"remove",true))
		{
			Light_RemoveSource(source);
			SendClientMessage(playerid,0xFFFFFFFF,"Removed.");
			return 1;
		}

		Light_SetSourceSeconds(source,!strcmp(action,"out",true) ? 0 : max(value,1) * 60);
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("It now burns for %d minute(s).",Light_GetSourceSeconds(source) / 60));
		return 1;
	}

	if (!strcmp(action,"list",true))
	{
		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%d light source(s), %d of them kept (braziers and bonfires).",Light_CountSources(),Light_CountSources(true)));
		return 1;
	}

	if (!strcmp(action,"kit",true))
	{
		Light_DevGiveKit(playerid);
		SendClientMessage(playerid,0xFFFFFFFF,"You have 3 torches, an empty lantern, 5 candles, flint and firewood.");
		return 1;
	}

	if (!strcmp(action,"tune",true))
	{
		if (!Light_HasTorchLit(playerid) && !Light_HasLanternLit(playerid))
		{
			SendClientMessage(playerid,0xFFFFFFFF,"Light a torch or a lantern first.");
			return 1;
		}

		EditAttachedObject(playerid,Light_HasTorchLit(playerid) ? LIGHT_SLOT_HAND : LIGHT_SLOT_BELT);
		SendClientMessage(playerid,0xFFFFFFFF,"Move it into place and save. The numbers print here to paste into light-data.pwn.");
		return 1;
	}

	if (!strcmp(action,"moon",true))
	{
		new Float:azimuth, Float:altitude, phase[24];
		new bool:isUp = Light_GetMoonSky(azimuth,altitude);
		Calendar_MoonPhaseName(Calendar_GetMoon(),phase);

		if (value == 1)
		{
			Light_SetMoonHidden(playerid,!Light_IsMoonShown(playerid));
		}

		SendClientMessage(playerid,0xFFFFFFFF,sprintf("%s, hour angle %.0f, altitude %.0f, %s, %s for you. /light moon 1 hides or shows it.",phase,azimuth,altitude,isUp ? ("up") : ("down"),Light_IsMoonShown(playerid) ? ("shown") : ("not shown")));
		return 1;
	}

	SendClientMessage(playerid,0xFFFFFFFF,"Use: /light brazier, bonfire, fuel <minutes>, out, remove, list, kit, tune, moon");
	return 1;
}

#include <pp-hooks>

hook OnPlayerEditAttachedObject(playerid,EDIT_RESPONSE:response,index,modelid,boneid,Float:fOffsetX,Float:fOffsetY,Float:fOffsetZ,Float:fRotX,Float:fRotY,Float:fRotZ,Float:fScaleX,Float:fScaleY,Float:fScaleZ)
{
	#pragma unused fScaleX, fScaleY, fScaleZ

	if ((index != LIGHT_SLOT_HAND && index != LIGHT_SLOT_BELT) || Light_FindGrip(modelid) == -1)
	{
		return;
	}

	new grip = Light_FindGrip(modelid);

	if (response != EDIT_RESPONSE_FINAL)
	{
		Light_AttachGrip(playerid,index,modelid);
		return;
	}

	g_LightGrips[grip][E_LIGHT_GRIP_BONE] = boneid;
	g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][0] = fOffsetX;
	g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][1] = fOffsetY;
	g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][2] = fOffsetZ;
	g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][0] = fRotX;
	g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][1] = fRotY;
	g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][2] = fRotZ;
	SendClientMessage(playerid,0xFFFFFFFF,sprintf("{%d, %d, {%.3f, %.3f, %.3f}, {%.1f, %.1f, %.1f}} (kept until restart)",modelid,boneid,fOffsetX,fOffsetY,fOffsetZ,fRotX,fRotY,fRotZ));
}
