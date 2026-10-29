enum E_FISHING_CATCH
{
	E_FISHING_CATCH_BREED,
	E_FISHING_CATCH_GRAMS,
	bool:E_FISHING_CATCH_NOTHING,
	STREAMER_TAG_OBJECT:E_FISHING_CATCH_BOBBER,
	STREAMER_TAG_OBJECT:E_FISHING_CATCH_LINE,
	E_FISHING_CATCH_SWAP_TIMER,
	bool:E_FISHING_CATCH_REELING,
	E_FISHING_CATCH_HOLD_TOKEN,
}

static s_FishingCatch[MAX_PLAYERS][E_FISHING_CATCH];
static s_FishingRecipe = -1;

stock Fishing_GetRecipe()
{
	return s_FishingRecipe;
}

stock Fishing_GetPendingBreed(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_FishingCatch[playerid][E_FISHING_CATCH_BREED] : -1;
}

stock Fishing_SetPendingCatch(playerid,breed,grams)
{
	s_FishingCatch[playerid][E_FISHING_CATCH_BREED] = breed;
	s_FishingCatch[playerid][E_FISHING_CATCH_GRAMS] = grams;
	s_FishingCatch[playerid][E_FISHING_CATCH_NOTHING] = breed == -1;
}

static Fishing_ClearLine(playerid)
{
	if (IsValidDynamicObject(s_FishingCatch[playerid][E_FISHING_CATCH_LINE]))
	{
		DestroyDynamicObject(s_FishingCatch[playerid][E_FISHING_CATCH_LINE]);
	}

	s_FishingCatch[playerid][E_FISHING_CATCH_LINE] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Fishing_StopReelSwap(playerid)
{
	if (s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER] != 0)
	{
		KillTimer(s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER]);
	}

	s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER] = 0;
}

static Fishing_StartReelSwap(playerid)
{
	if (s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER] == 0)
	{
		s_FishingCatch[playerid][E_FISHING_CATCH_REELING] = true;
		s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER] = SetTimerEx("Fishing_ReelSwap",FISHING_REEL_SWAP_MS,true,"d",playerid);
	}
}

static Fishing_HoldCatch(playerid,item)
{
	new model = Item_GetModel(ITEM_KIND_MATERIAL,item);

	if (model == 0)
	{
		return;
	}

	SetPlayerAttachedObject(playerid,FISHING_ROD_SLOT,model,ATTACH_BONE_RIGHT_HAND,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0);
	ApplyAnimation(playerid,FISHING_HOLD_LIB,FISHING_HOLD_ANIM,4.1,false,true,true,true,0,SYNC_ALL);
	SetTimerEx("Fishing_HoldDone",FISHING_HOLD_MS,false,"dd",playerid,++s_FishingCatch[playerid][E_FISHING_CATCH_HOLD_TOKEN]);
}

static Fishing_Clear(playerid)
{
	Fishing_StopReelSwap(playerid);

	if (IsValidDynamicObject(s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER]))
	{
		DestroyDynamicObject(s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER]);
	}

	s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	Fishing_ClearLine(playerid);
	s_FishingCatch[playerid][E_FISHING_CATCH_BREED] = -1;
	s_FishingCatch[playerid][E_FISHING_CATCH_GRAMS] = 0;
	s_FishingCatch[playerid][E_FISHING_CATCH_NOTHING] = false;

	if (IsPlayerConnected(playerid))
	{
		RemovePlayerAttachedObject(playerid,FISHING_ROD_SLOT);
	}
}

static Fishing_AttachRod(playerid,stage)
{
	new index = Util_ClampInt(stage,0,sizeof(g_FishingRodStageModels) - 1);
	SetPlayerAttachedObject(playerid,FISHING_ROD_SLOT,g_FishingRodStageModels[index],ATTACH_BONE_RIGHT_HAND,0.1,0.05,0.0,g_FishingRodStageRotations[index][0],g_FishingRodStageRotations[index][1],g_FishingRodStageRotations[index][2],1.0,1.0,1.0);
}

static Fishing_PlaceBobber(playerid)
{
	new nodeid = Work_GetSceneTarget(playerid);

	if (!Work_IsValidNode(nodeid) || IsValidDynamicObject(s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER]))
	{
		return;
	}

	new Float:x, Float:y, Float:z, Float:level;
	Work_GetNodePos(nodeid,x,y,z);
	new Float:bobX = x + (float(random(101)) / 50.0 - 1.0) * FISHING_BOBBER_SPREAD, Float:bobY = y + (float(random(101)) / 50.0 - 1.0) * FISHING_BOBBER_SPREAD;

	if (Fishing_WaterAt(bobX,bobY,level) == FISHING_WATER_NONE)
	{
		bobX = x;
		bobY = y;

		if (Fishing_WaterAt(x,y,level) == FISHING_WATER_NONE)
		{
			level = z;
		}
	}

	s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER] = CreateDynamicObject(FISHING_BOBBER_MODEL,bobX,bobY,level,0.0,0.0,0.0,GetPlayerVirtualWorld(playerid),-1,-1,FISHING_BOBBER_STREAM);
	Nearby_StreamObjectsAt(bobX,bobY,level,GetPlayerVirtualWorld(playerid),-1,FISHING_BOBBER_STREAM);
}

static Fishing_DrawLine(playerid,stage)
{
	new STREAMER_TAG_OBJECT:bobber = s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER];

	if (!IsValidDynamicObject(bobber) || stage < FISHING_STAGE_WAIT || stage >= sizeof(g_FishingLineAnchors))
	{
		Fishing_ClearLine(playerid);
		return;
	}

	new Float:x, Float:y, Float:z, Float:angle, Float:tipX, Float:tipY, Float:bobX, Float:bobY, Float:bobZ;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,angle);
	Util_GetOffsetPoint(x,y,angle,g_FishingLineAnchors[stage][0],tipX,tipY);
	Util_GetOffsetPoint(tipX,tipY,angle + 90.0,g_FishingLineAnchors[stage][1],tipX,tipY);
	new Float:tipZ = z + g_FishingLineAnchors[stage][2];
	GetDynamicObjectPos(bobber,bobX,bobY,bobZ);

	new Float:dx = bobX - tipX, Float:dy = bobY - tipY, Float:dz = bobZ - tipZ, Float:flat = VectorSize(dx,dy,0.0), Float:length = VectorSize(dx,dy,dz);
	new index = Util_ClampInt(floatround((length - FISHING_LINE_SHORTEST) / FISHING_LINE_STEP,floatround_ceil),0,sizeof(g_FishingLineModels) - 1);
	new STREAMER_TAG_OBJECT:line = s_FishingCatch[playerid][E_FISHING_CATCH_LINE];

	if (IsValidDynamicObject(line) && Streamer_GetIntData(STREAMER_TYPE_OBJECT,line,E_STREAMER_MODEL_ID) == g_FishingLineModels[index])
	{
		SetDynamicObjectPos(line,tipX,tipY,tipZ);
		SetDynamicObjectRot(line,atan2(dz,flat),0.0,atan2(-dx,dy));
		return;
	}

	Fishing_ClearLine(playerid);
	s_FishingCatch[playerid][E_FISHING_CATCH_LINE] = CreateDynamicObject(g_FishingLineModels[index],tipX,tipY,tipZ,atan2(dz,flat),0.0,atan2(-dx,dy),GetPlayerVirtualWorld(playerid),-1,-1,FISHING_BOBBER_STREAM);
	Nearby_StreamObjectsAt(tipX,tipY,tipZ,GetPlayerVirtualWorld(playerid),-1,FISHING_BOBBER_STREAM);
}

static Fishing_DipBobber(playerid)
{
	new STREAMER_TAG_OBJECT:bobber = s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER];

	if (IsValidDynamicObject(bobber))
	{
		new Float:x, Float:y, Float:z;
		GetDynamicObjectPos(bobber,x,y,z);
		MoveDynamicObject(bobber,x,y,z - FISHING_BOBBER_DIP,FISHING_BOBBER_DIP_SPEED);
	}
}

static Fishing_WaterAtSpot(playerid)
{
	new nodeid = Work_GetSceneTarget(playerid), Float:x, Float:y, Float:z, Float:level;

	if (!Work_IsValidNode(nodeid))
	{
		return FISHING_WATER_NONE;
	}

	Work_GetNodePos(nodeid,x,y,z);
	return Fishing_WaterAt(x,y,level);
}

static Fishing_RollForPlayer(playerid)
{
	new E_ITEM_KIND:kind, param, stars, grams, baitBit = 0;

	if (Work_GetReservedItem(playerid,0,kind,param,stars))
	{
		baitBit = Fishing_GetBaitBit(param);
	}

	new breed = Fishing_RollCatch(Fishing_WaterAtSpot(playerid),Calendar_GetSeason(),Calendar_GetHour(),Calendar_GetMoon(),baitBit,Calendar_IsNight(),grams);
	Fishing_SetPendingCatch(playerid,breed,grams);
}

static Fishing_WearRod(playerid)
{
	new slot = Inventory_Find(playerid,ITEM_KIND_TOOL,ITEM_FISHING_ROD);

	if (slot == -1)
	{
		return;
	}

	new wear = Inventory_GetSlotWear(playerid,slot) + FISHING_ROD_WEAR;

	if (wear >= ITEM_WEAR_MAX)
	{
		Inventory_TakeSlot(playerid,slot,1);
		Gui_Notify(playerid,"Your fishing rod snapped. You'll need a new one.");
		return;
	}

	Inventory_SetSlotWear(playerid,slot,wear);
}

forward Task:Fishing_RecordCatch(playerid,item,grams,const catchText[]);
#pragma warning push
#pragma warning disable 204
async Task:Fishing_RecordCatch(playerid,item,grams,const catchText[])
{
	new characterid = Character_GetId(playerid), best = 0, text[48];
	strcopy(text,catchText);
	await mysql_aquery_s(g_Mysql,str_format("SELECT grams FROM fishing_records WHERE item = %d",item));

	if (cache_num_rows() > 0)
	{
		cache_get_value_name_int(0,"grams",best);
	}

	if (grams <= best)
	{
		return async 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("REPLACE INTO fishing_records (item, character_id, grams, caught_at) VALUES (%d, %d, %d, NOW())",item,characterid,grams));

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid && best > 0)
	{
		Gui_Notify(playerid,sprintf("That %s is the heaviest ever caught here!",text));
	}

	return async 1;
}
#pragma warning pop

static Fishing_Land(playerid,stars)
{
	new breed = s_FishingCatch[playerid][E_FISHING_CATCH_BREED], grams = s_FishingCatch[playerid][E_FISHING_CATCH_GRAMS];

	if (breed == -1)
	{
		return;
	}

	new item = g_FishBreeds[breed][E_FISH_BREED_ITEM], text[48], name[ITEM_NAME_LEN];
	Fishing_FormatCatch(breed,grams,text);

	if (!Inventory_Give(playerid,ITEM_KIND_MATERIAL,item,1,stars))
	{
		Claims_Give(Character_GetId(playerid),ITEM_KIND_MATERIAL,item,1,stars,"fishing");
	}

	Gui_Notify(playerid,sprintf("You caught a %s!",text));

	if (g_FishBreeds[breed][E_FISH_BREED_LORD])
	{
		Item_GetName(ITEM_KIND_MATERIAL,item,name);
		SendClientMessage(playerid,FISHING_NOTE_COLOUR,sprintf("A %s is a lord's fish. By law it belongs to the count.",name));
	}

	Fishing_RecordCatch(playerid,item,grams,text);
}

forward Fishing_ReelSwap(playerid);

public Fishing_ReelSwap(playerid)
{
	if (!IsPlayerConnected(playerid) || !Work_IsWorking(playerid))
	{
		Fishing_StopReelSwap(playerid);
		return 1;
	}

	s_FishingCatch[playerid][E_FISHING_CATCH_REELING] = !s_FishingCatch[playerid][E_FISHING_CATCH_REELING];

	new pose = FISHING_STAGE_LAND;

	if (s_FishingCatch[playerid][E_FISHING_CATCH_REELING])
	{
		ApplyAnimation(playerid,"SWORD","sword_idle",FISHING_REEL_SWAP_BLEND,true,true,true,true,0,SYNC_ALL);
	}
	else
	{
		ApplyAnimation(playerid,"SAMP","FishingIdle",FISHING_REEL_SWAP_BLEND,true,true,true,true,0,SYNC_ALL);
		pose = FISHING_POSE_LAND_ALT;
	}

	Fishing_AttachRod(playerid,pose);
	Fishing_DrawLine(playerid,pose);
	return 1;
}

forward Fishing_HoldDone(playerid,token);

public Fishing_HoldDone(playerid,token)
{
	if (!IsPlayerConnected(playerid) || s_FishingCatch[playerid][E_FISHING_CATCH_HOLD_TOKEN] != token)
	{
		return 1;
	}

	RemovePlayerAttachedObject(playerid,FISHING_ROD_SLOT);
	ClearAnimations(playerid,SYNC_ALL);
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	s_FishingRecipe = Recipe_FindByName("Fish");
}

hook OnPlayerConnect(playerid)
{
	s_FishingCatch[playerid][E_FISHING_CATCH_BOBBER] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_FishingCatch[playerid][E_FISHING_CATCH_LINE] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_FishingCatch[playerid][E_FISHING_CATCH_BREED] = -1;
	s_FishingCatch[playerid][E_FISHING_CATCH_SWAP_TIMER] = 0;
	s_FishingCatch[playerid][E_FISHING_CATCH_HOLD_TOKEN]++;
}

hook OnPlayerDisconnect(playerid,reason)
{
	Fishing_Clear(playerid);
}

hook Work_OnStageStarting(playerid,recipe,stage)
{
	if (recipe != s_FishingRecipe || s_FishingRecipe == -1)
	{
		return;
	}

	if (stage == 0)
	{
		s_FishingCatch[playerid][E_FISHING_CATCH_HOLD_TOKEN]++;
	}

	Fishing_AttachRod(playerid,stage);

	switch (stage)
	{
		case FISHING_STAGE_WAIT:
		{
			Fishing_RollForPlayer(playerid);
			Fishing_PlaceBobber(playerid);
			Work_SetChallengeTuning(playerid,0,s_FishingCatch[playerid][E_FISHING_CATCH_NOTHING] ? FISHING_WAIT_MAX_MS : Fishing_GetWaitMs(Calendar_GetHour(),Calendar_GetMoon()));
		}
		case FISHING_STAGE_STRIKE:
		{
			if (s_FishingCatch[playerid][E_FISHING_CATCH_NOTHING])
			{
				Work_SetChallengeTuning(playerid,0,0,1);
			}
			else
			{
				Fishing_DipBobber(playerid);
				PlayerPlaySound(playerid,FISHING_SOUND_BITE,0.0,0.0,0.0);
				Work_SetChallengeTuning(playerid,0,0,FISHING_STRIKE_MS);
			}
		}
		case FISHING_STAGE_REEL:
		{
			Work_SetChallengeTuning(playerid,Fishing_GetStrength(s_FishingCatch[playerid][E_FISHING_CATCH_GRAMS]),0);
		}
		case FISHING_STAGE_LAND:
		{
			Fishing_StopReelSwap(playerid);
			Fishing_StartReelSwap(playerid);
		}
		default: {}
	}

	Fishing_DrawLine(playerid,stage);
}

hook Work_OnFinished(playerid,recipe,stars)
{
	if (recipe != s_FishingRecipe || s_FishingRecipe == -1)
	{
		return;
	}

	new breed = s_FishingCatch[playerid][E_FISHING_CATCH_BREED];
	Fishing_WearRod(playerid);
	Fishing_Land(playerid,stars);
	Fishing_Clear(playerid);

	if (breed != -1)
	{
		Fishing_HoldCatch(playerid,g_FishBreeds[breed][E_FISH_BREED_ITEM]);
	}
}

hook Work_OnRuined(playerid,recipe,stage)
{
	if (recipe != s_FishingRecipe || s_FishingRecipe == -1)
	{
		return;
	}

	new text[48];

	if (s_FishingCatch[playerid][E_FISHING_CATCH_NOTHING])
	{
		Gui_Notify(playerid,"Nothing took the bait. Try another spot, bait or time of day.");
	}
	else if (stage >= FISHING_STAGE_STRIKE && s_FishingCatch[playerid][E_FISHING_CATCH_BREED] != -1)
	{
		Fishing_FormatCatch(s_FishingCatch[playerid][E_FISHING_CATCH_BREED],s_FishingCatch[playerid][E_FISHING_CATCH_GRAMS],text);
		Gui_Notify(playerid,sprintf("The %s got away. Your bait is gone too.",text));
	}
	else
	{
		Gui_Notify(playerid,"You fumbled it and lost the bait.");
	}

	Fishing_WearRod(playerid);
	Fishing_Clear(playerid);
}

hook Work_OnAborted(playerid,recipe)
{
	if (recipe == s_FishingRecipe && s_FishingRecipe != -1)
	{
		Fishing_Clear(playerid);
	}
}
