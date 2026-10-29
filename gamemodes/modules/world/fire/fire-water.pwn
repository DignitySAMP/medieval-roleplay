#define FIRE_PROMPT_NONE (0)
#define FIRE_PROMPT_FILL (1)
#define FIRE_PROMPT_THROW (2)
#define FIRE_PROMPT_ARSON (3)
#define FIRE_PROMPT_RUIN (4)
#define FIRE_SOURCE_RIVER (0)
#define FIRE_SOURCE_YARD (1000)
#define FIRE_SOURCE_WELL (2000)

static bool:s_BucketFull[MAX_PLAYERS];
static s_FirePrompt[MAX_PLAYERS];
static s_FirePromptTarget[MAX_PLAYERS];
static s_FireInfobox[MAX_PLAYERS];
static bool:s_FireBusy[MAX_PLAYERS];

stock bool:Fire_HasBucket(playerid)
{
	return Inventory_Count(playerid,Item_GetDefKind(ITEM_BUCKET),ITEM_BUCKET) > 0;
}

stock bool:Fire_IsBucketFull(playerid)
{
	return Util_IsValidPlayer(playerid) && s_BucketFull[playerid];
}

stock Fire_SetBucketFull(playerid,bool:isFull)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_BucketFull[playerid] = isFull;

	if (isFull && !IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_SLOT_HAND_LEFT))
	{
		SetPlayerAttachedObject(playerid,ATTACH_SLOT_HAND_LEFT,MODEL_CARRY_BUCKET,ATTACH_BONE_LEFT_HAND,0.08,0.02,0.0,0.0,-90.0,0.0);
	}
	else if (!isFull && IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_SLOT_HAND_LEFT))
	{
		RemovePlayerAttachedObject(playerid,ATTACH_SLOT_HAND_LEFT);
	}
}

stock Fire_FindWater(playerid)
{
	if (Yard_IsAtRiver(playerid))
	{
		return FIRE_SOURCE_RIVER;
	}

	new node = Yard_FindNodeNear(playerid);

	if (node != -1)
	{
		new kind = Yard_GetKind(node);

		if (kind == YARD_KIND_SPRING || ((kind == YARD_KIND_WASHTUB || kind == YARD_KIND_TROUGH) && Yard_GetLevel(node) > 0))
		{
			return FIRE_SOURCE_YARD + node;
		}
	}

	new Float:x, Float:y, Float:z, Float:distance, well = Work_FindKind("well");
	GetPlayerPos(playerid,x,y,z);
	new nodeid = Work_FindNearestNode(x,y,z,GetPlayerVirtualWorld(playerid),2.5,distance);

	if (well != -1 && nodeid != -1 && Work_GetTargetKind(WORK_TARGET_NODE,nodeid) == well)
	{
		return FIRE_SOURCE_WELL + nodeid;
	}

	return -1;
}

stock bool:Fire_Fill(playerid,source)
{
	if (!Fire_HasBucket(playerid) || s_BucketFull[playerid] || source < 0)
	{
		return false;
	}

	if (source >= FIRE_SOURCE_YARD && source < FIRE_SOURCE_WELL)
	{
		new node = source - FIRE_SOURCE_YARD, kind = Yard_GetKind(node);

		if (kind != YARD_KIND_SPRING)
		{
			if (Yard_GetLevel(node) <= 0)
			{
				return false;
			}

			Yard_SetLevel(node,Yard_GetLevel(node) - 1);
		}
	}

	Fire_SetBucketFull(playerid,true);
	return true;
}

stock Fire_Throw(playerid,building)
{
	if (!s_BucketFull[playerid] || !Fire_IsBurning(building))
	{
		return -1;
	}

	Fire_SetBucketFull(playerid,false);
	new others = Fire_RecordThrow(building,playerid), amount = FIRE_THROW + others * FIRE_CHAIN_BONUS;
	Anim_Apply(playerid,"GRENADE","WEAPON_throwu",4.1,false,false,false,false,0);

	if (Fire_Douse(building,amount))
	{
		Gui_Notify(playerid,"The last flames hiss out.");
		pawn_call_public("Fire_OnDoused","ddd",playerid,building,1);
		return 0;
	}

	if (others > 0)
	{
		Gui_Notify(playerid,sprintf("The chain keeps the water coming: the flames sink. (%d left)",Fire_GetHeat(building)));
	}
	else
	{
		Gui_Notify(playerid,sprintf("The water hisses on the flames. Fetch more, and bring help. (%d left)",Fire_GetHeat(building)));
	}

	pawn_call_public("Fire_OnDoused","ddd",playerid,building,0);
	return Fire_GetHeat(building);
}

static Fire_ClearPrompt(playerid)
{
	if (s_FireInfobox[playerid] != 0)
	{
		Infobox_Hide(playerid,s_FireInfobox[playerid]);
	}

	s_FirePrompt[playerid] = FIRE_PROMPT_NONE;
	s_FirePromptTarget[playerid] = -1;
	s_FireInfobox[playerid] = 0;
}

static Fire_PromptAt(playerid,&target)
{
	target = -1;

	if (GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0)
	{
		return FIRE_PROMPT_NONE;
	}

	new Float:x, Float:y, Float:z, Float:distance;
	GetPlayerPos(playerid,x,y,z);
	new building = Fire_FindNear(x,y,z,FIRE_THROW_REACH,distance);

	if (building != -1 && Fire_IsGutted(building) && VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1],0.0) <= FIRE_DOOR_REACH)
	{
		target = building;
		return FIRE_PROMPT_RUIN;
	}

	if (building != -1 && Fire_IsBurning(building) && s_BucketFull[playerid])
	{
		target = building;
		return FIRE_PROMPT_THROW;
	}

	if (!s_BucketFull[playerid] && Fire_CountBurning() > 0 && Fire_HasBucket(playerid))
	{
		target = Fire_FindWater(playerid);

		if (target != -1)
		{
			return FIRE_PROMPT_FILL;
		}
	}

	if (building != -1 && Fire_GetState(building) == FIRE_STATE_SOUND && Light_HasTorchLit(playerid) && VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],0.0) <= 5.0 && VectorSize(x - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][0],y - g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][1],0.0) > 2.0)
	{
		target = building;
		return FIRE_PROMPT_ARSON;
	}

	return FIRE_PROMPT_NONE;
}

static Fire_ShowPrompt(playerid,kind,target)
{
	new title[28], text[128], money[24];

	switch (kind)
	{
		case FIRE_PROMPT_FILL:
		{
			strcopy(title,"Water");
			strcopy(text,"Press ~y~Y~w~ to fill your bucket.");
		}
		case FIRE_PROMPT_THROW:
		{
			Fire_GetName(target,title);
			title[0] = toupper(title[0]);
			strcopy(text,"Press ~y~Y~w~ to throw the water on the flames.");
		}
		case FIRE_PROMPT_ARSON:
		{
			Fire_GetName(target,title);
			title[0] = toupper(title[0]);
			strcopy(text,"Press ~y~Walk + Y~w~ to put your torch to the thatch.");
		}
		case FIRE_PROMPT_RUIN:
		{
			Fire_GetName(target,title);
			title[0] = toupper(title[0]);

			if (Fire_IsRebuildPaid(target))
			{
				strcopy(text,"Burnt out. It's paid for: the carpenters rebuild it by dawn.");
			}
			else
			{
				Economy_Format(Fire_GetRebuildFee(target),money);
				format(text,sizeof(text),"Burnt out. Press ~y~Y~w~ to pay the carpenters (%s, to the county).",money);
			}
		}
	}

	s_FireInfobox[playerid] = Infobox_ShowPrompt(playerid,s_FireInfobox[playerid],title,text,3);
}

static Fire_Confirm(playerid,const title[],const text[],const yes[])
{
	new epoch = Gui_BeginFlow(playerid), Float:x, Float:y, Float:width;
	Kit_Begin(playerid,KIT_LAYER_SCREEN,title);
	Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,280.0,KIT_ROW * 4.0 + 6.0 + KIT_ROW + 12.0,title,x,y,width);
	Kit_AddText(playerid,x,y,text,KIT_COLOUR_TEXT,KIT_TEXT_ROW,TEXT_DRAW_FONT_1,false,width);
	Kit_AddChoice(playerid,x,y + KIT_ROW * 3.0,width * 0.48,yes,1,KIT_COLOUR_GOOD);
	Kit_AddChoice(playerid,x + width * 0.52,y + KIT_ROW * 3.0,width * 0.48,"No",2,KIT_COLOUR_MUTED);
	new pick = await Kit_Present(playerid);

	if (Gui_IsFlowCurrent(playerid,epoch))
	{
		Kit_Close(playerid);
	}

	return pick == 1;
}

stock Fire_Arson(playerid,building)
{
	if (!Fire_Confirm(playerid,"Arson","Set it alight? Arson is one of the gravest crimes if anyone sees you, and fire spreads to the houses next door.","Set it alight"))
	{
		return;
	}

	if (!Light_HasTorchLit(playerid) || Fire_GetState(building) != FIRE_STATE_SOUND)
	{
		return;
	}

	Anim_Apply(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
	Fire_Start(building,FIRE_CAUSE_ARSON,Character_GetId(playerid));
	Law_Commit(playerid,LAW_CRIME_ARSON);
}

stock Fire_PayRebuild(playerid,building)
{
	new fee = Fire_GetRebuildFee(building), money[24], name[28];
	Economy_Format(fee,money);
	Fire_GetName(building,name);

	if (!Fire_Confirm(playerid,"Rebuilding",sprintf("Pay %s to the county for the carpenters to rebuild %s overnight?",money,name),"Pay"))
	{
		return;
	}

	if (!Fire_IsGutted(building) || Fire_IsRebuildPaid(building))
	{
		return;
	}

	if (Economy_Pay(playerid,fee,Realm_GetTreasury(),"rebuilding") != PAY_OK)
	{
		Gui_Notify(playerid,"You can't pay that.");
		return;
	}

	Fire_SetRebuildPaid(building);
	Gui_Notify(playerid,"The carpenters will have it standing again by dawn.");
}

Timer_Declare(Fire_PromptTick)
{
	foreach (new playerid : Player)
	{
		if (IsPlayerNPC(playerid))
		{
			continue;
		}

		new target, kind = Session_IsPlaying(playerid) && !Gui_IsBusy(playerid) && !s_FireBusy[playerid] && GetPlayerState(playerid) == PLAYER_STATE_ONFOOT ? Fire_PromptAt(playerid,target) : FIRE_PROMPT_NONE;

		if (kind == FIRE_PROMPT_NONE)
		{
			Fire_ClearPrompt(playerid);
			continue;
		}

		if (kind == s_FirePrompt[playerid] && target == s_FirePromptTarget[playerid] && Infobox_IsShown(playerid,s_FireInfobox[playerid]))
		{
			continue;
		}

		s_FirePrompt[playerid] = kind;
		s_FirePromptTarget[playerid] = target;
		Fire_ShowPrompt(playerid,kind,target);
	}

	return 1;
}

forward bool:Fire_PromptContext(playerid);

public bool:Fire_PromptContext(playerid)
{
	return s_FireBusy[playerid] || (s_FirePrompt[playerid] != FIRE_PROMPT_NONE && s_FirePrompt[playerid] != FIRE_PROMPT_ARSON);
}

forward Fire_FillDone(playerid,source,token);

public Fire_FillDone(playerid,source,token)
{
	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token)
	{
		return 1;
	}

	s_FireBusy[playerid] = false;
	ClearAnimations(playerid);

	if (Fire_Fill(playerid,source))
	{
		Gui_Notify(playerid,"Your bucket is full. Take it to the fire and press ~y~Y~w~ to throw.");
	}

	return 1;
}

forward Fire_OnDoused(playerid,building,isOut);

public Fire_OnDoused(playerid,building,isOut)
{
	return 1;
}

forward Fire_PromptDeferred(playerid,kind,target);

public Fire_PromptDeferred(playerid,kind,target)
{
	if (!IsPlayerConnected(playerid))
	{
		return 1;
	}

	if (kind == FIRE_PROMPT_ARSON)
	{
		Fire_Arson(playerid,target);
	}
	else if (kind == FIRE_PROMPT_RUIN && !Fire_IsRebuildPaid(target))
	{
		Fire_PayRebuild(playerid,target);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_BucketFull[playerid] = false;
	s_FirePrompt[playerid] = FIRE_PROMPT_NONE;
	s_FirePromptTarget[playerid] = -1;
	s_FireInfobox[playerid] = 0;
	s_FireBusy[playerid] = false;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if (!(newkeys & KEY_YES) || (oldkeys & KEY_YES) || s_FirePrompt[playerid] == FIRE_PROMPT_NONE || s_FireBusy[playerid] || Infobox_IsPromptBlocked(playerid,s_FireInfobox[playerid]) || Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_SCENE))
	{
		return;
	}

	new kind = s_FirePrompt[playerid], target = s_FirePromptTarget[playerid], bool:walk = (newkeys & KEY_WALK) != KEY:0;

	if ((kind == FIRE_PROMPT_ARSON) != walk)
	{
		return;
	}

	Fire_ClearPrompt(playerid);

	switch (kind)
	{
		case FIRE_PROMPT_FILL:
		{
			s_FireBusy[playerid] = true;
			ApplyAnimation(playerid,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,false,0,SYNC_ALL);
			SetTimerEx("Fire_FillDone",FIRE_FILL_MS,false,"ddd",playerid,target,Account_GetToken(playerid));
		}
		case FIRE_PROMPT_THROW: Fire_Throw(playerid,target);
		case FIRE_PROMPT_ARSON, FIRE_PROMPT_RUIN: SetTimerEx("Fire_PromptDeferred",0,false,"ddd",playerid,kind,target);
	}
}

hook Inventory_OnDropped(playerid,kind,param)
{
	#pragma unused kind

	if (param == ITEM_BUCKET && s_BucketFull[playerid] && !Fire_HasBucket(playerid))
	{
		Fire_SetBucketFull(playerid,false);
	}
}
