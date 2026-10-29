static s_LightTorchCarry[MAX_PLAYERS];
static s_LightLanternCarry[MAX_PLAYERS];
static s_LightHandModel[MAX_PLAYERS];
static s_LightBeltModel[MAX_PLAYERS];

stock bool:Light_HasTorchLit(playerid)
{
	return Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT) > 0;
}

stock bool:Light_HasLanternLit(playerid)
{
	return Inventory_Count(playerid,ITEM_KIND_MISC,ITEM_LANTERN_LIT) > 0;
}

stock bool:Light_HasLight(playerid)
{
	return Util_IsValidPlayer(playerid) && Session_IsPlaying(playerid) && (Light_HasTorchLit(playerid) || Light_HasLanternLit(playerid));
}

stock Light_GetTorchSecondsLeft(playerid)
{
	new index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT);
	return index == -1 ? 0 : (ITEM_WEAR_MAX - Inventory_GetSlotWear(playerid,index)) * LIGHT_TORCH_SECONDS / ITEM_WEAR_MAX;
}

stock Light_GetLanternSecondsLeft(playerid)
{
	new index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_LANTERN_LIT);

	if (index == -1)
	{
		index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_LANTERN);
	}

	return index == -1 ? 0 : (ITEM_WEAR_MAX - Inventory_GetSlotWear(playerid,index)) * LIGHT_LANTERN_SECONDS / ITEM_WEAR_MAX;
}

static Light_FindLantern(playerid,bool:isLit)
{
	return Inventory_Find(playerid,ITEM_KIND_MISC,isLit ? ITEM_LANTERN_LIT : ITEM_LANTERN);
}

static bool:Light_SwapItem(playerid,index,newItem,wear)
{
	new E_ITEM_KIND:kind, param, amount, stars = Inventory_GetSlotStars(playerid,index);

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || amount <= 0)
	{
		return false;
	}

	if (!Inventory_TakeSlot(playerid,index,1))
	{
		return false;
	}

	if (!Inventory_Give(playerid,ITEM_KIND_MISC,newItem,1,stars,ITEM_FRESH_NOW,wear))
	{
		Inventory_Give(playerid,kind,param,1,stars);
		return false;
	}

	return true;
}

stock bool:Light_CanKindle(playerid)
{
	if (Light_HasLight(playerid) || Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_FLINT) > 0)
	{
		return true;
	}

	new Float:x, Float:y, Float:z, world = GetPlayerVirtualWorld(playerid);
	GetPlayerPos(playerid,x,y,z);

	if (Light_FindSourceNear(x,y,z - 0.9,world,LIGHT_KINDLE_REACH,true) != -1)
	{
		return true;
	}

	new Float:distance, station = Work_FindNearestStation(x,y,z,world,LIGHT_KINDLE_REACH,distance,true);

	if (station != -1 && Work_IsStationAlight(station))
	{
		return true;
	}

	foreach (new i : Player)
	{
		if (i != playerid && GetPlayerVirtualWorld(i) == world && Light_HasTorchLit(i) && GetPlayerDistanceFromPoint(i,x,y,z) <= LIGHT_KINDLE_REACH)
		{
			return true;
		}
	}

	return false;
}

stock Light_SyncAttachments(playerid)
{
	if (!IsPlayerConnected(playerid) || IsPlayerNPC(playerid))
	{
		return;
	}

	new hand = Session_IsPlaying(playerid) && Light_HasTorchLit(playerid) ? MODEL_LIGHT_TORCH_LIT : 0;
	new belt = Session_IsPlaying(playerid) && Light_HasLanternLit(playerid) ? MODEL_LIGHT_LANTERN_LIT : 0;

	if (hand != s_LightHandModel[playerid])
	{
		s_LightHandModel[playerid] = hand;

		if (hand == 0)
		{
			RemovePlayerAttachedObject(playerid,LIGHT_SLOT_HAND);
			RemovePlayerAttachedObject(playerid,LIGHT_SLOT_FLAME);
		}
		else
		{
			new Float:fx, Float:fy, Float:fz;
			Light_GetHandFlame(fx,fy,fz);
			Light_AttachGrip(playerid,LIGHT_SLOT_HAND,hand);
			SetPlayerAttachedObject(playerid,LIGHT_SLOT_FLAME,LIGHT_HAND_FLAME_MODEL,ATTACH_BONE_LEFT_HAND,fx,fy,fz - LIGHT_HAND_FLAME_LIFT * LIGHT_FLAME_SCALE,0.0,0.0,0.0,LIGHT_FLAME_SCALE,LIGHT_FLAME_SCALE,LIGHT_FLAME_SCALE);
		}
	}

	if (belt != s_LightBeltModel[playerid])
	{
		s_LightBeltModel[playerid] = belt;

		if (belt == 0)
		{
			RemovePlayerAttachedObject(playerid,LIGHT_SLOT_BELT);
		}
		else
		{
			Light_AttachGrip(playerid,LIGHT_SLOT_BELT,belt);
		}
	}
}

stock Light_FindGrip(model)
{
	for (new i = 0;i < sizeof(g_LightGrips);i++)
	{
		if (g_LightGrips[i][E_LIGHT_GRIP_MODEL] == model)
		{
			return i;
		}
	}

	return -1;
}

stock Light_AttachGrip(playerid,slot,model)
{
	new grip = Light_FindGrip(model);

	if (grip == -1)
	{
		return;
	}

	SetPlayerAttachedObject(playerid,slot,model,g_LightGrips[grip][E_LIGHT_GRIP_BONE],g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][0],g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][1],g_LightGrips[grip][E_LIGHT_GRIP_OFFSET][2],g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][0],g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][1],g_LightGrips[grip][E_LIGHT_GRIP_ROTATION][2]);
}

stock Light_ReattachGrips(playerid)
{
	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	s_LightHandModel[playerid] = 0;
	s_LightBeltModel[playerid] = 0;
	Light_SyncAttachments(playerid);
}

stock bool:Light_LightTorch(playerid,bool:isQuiet = false)
{
	if (Light_HasTorchLit(playerid))
	{
		return false;
	}

	if (Combat_GetShield(playerid) != INVALID_SHIELD_INDEX)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"A torch goes in your left hand. Put your shield away first.");
		}

		return false;
	}

	new index = -1, bestWear = -1;

	for (new i = 0, count = Inventory_GetCount(playerid);i < count;i++)
	{
		new E_ITEM_KIND:kind, param, amount;
		Inventory_GetSlot(playerid,i,kind,param,amount);

		if (kind == ITEM_KIND_MISC && param == ITEM_TORCH_BURNT && Inventory_GetSlotWear(playerid,i) > bestWear)
		{
			index = i;
			bestWear = Inventory_GetSlotWear(playerid,i);
		}
	}

	if (index == -1)
	{
		index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH);
		bestWear = 0;
	}

	if (index == -1)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You have no torch in your bag.");
		}

		return false;
	}

	if (!Light_CanKindle(playerid))
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You need a flame to light it: flint in your bag, a fire, or someone's torch close by.");
		}

		return false;
	}

	if (!Light_SwapItem(playerid,index,ITEM_TORCH_LIT,max(bestWear,0)))
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"There's no room in your bag to light it.");
		}

		return false;
	}

	s_LightTorchCarry[playerid] = 0;
	Light_SyncAttachments(playerid);

	if (!isQuiet)
	{
		Gui_Notify(playerid,"You light the torch. It burns for about twenty minutes.");
	}

	pawn_call_public("Light_OnTorchLit","d",playerid);
	return true;
}

stock bool:Light_PutOutTorch(playerid,const reason[] = "")
{
	new index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT);

	if (index == -1)
	{
		return false;
	}

	new wear = Inventory_GetSlotWear(playerid,index);

	if (!Light_SwapItem(playerid,index,ITEM_TORCH_BURNT,wear))
	{
		Inventory_TakeSlot(playerid,index,1);
	}

	Light_SyncAttachments(playerid);

	if (reason[0] != EOS)
	{
		Gui_Notify(playerid,reason);
	}

	return true;
}

stock bool:Light_PlantTorch(playerid)
{
	new index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT);

	if (index == -1)
	{
		return false;
	}

	if (GetPlayerInterior(playerid) != 0)
	{
		Gui_Notify(playerid,"There's no soft ground to plant a torch in here.");
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a, Float:groundZ;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += LIGHT_PLANT_AHEAD * floatsin(-a,degrees);
	y += LIGHT_PLANT_AHEAD * floatcos(-a,degrees);

	if (!Placement_FindSurface(x,y,z + 0.5,LIGHT_PLACE_REACH,groundZ))
	{
		Gui_Notify(playerid,"There's no ground there to plant it in.");
		return false;
	}

	new seconds = (ITEM_WEAR_MAX - Inventory_GetSlotWear(playerid,index)) * LIGHT_TORCH_SECONDS / ITEM_WEAR_MAX;

	if (Light_AddSource(0,LIGHT_SOURCE_POLE_TORCH,x,y,groundZ,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid),seconds) == -1)
	{
		Gui_Notify(playerid,"You can't plant it here right now.");
		return false;
	}

	Inventory_TakeSlot(playerid,index,1);
	Light_SyncAttachments(playerid);
	Anim_Apply(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
	Gui_Notify(playerid,"You plant the torch in the ground. Press ~y~Y~w~ beside it to take it up again.");
	return true;
}

stock bool:Light_TakePoleTorch(playerid,source)
{
	if (Light_GetSourceKind(source) != LIGHT_SOURCE_POLE_TORCH)
	{
		return false;
	}

	if (Light_HasTorchLit(playerid))
	{
		Gui_Notify(playerid,"You're already holding a lit torch.");
		return false;
	}

	if (Combat_GetShield(playerid) != INVALID_SHIELD_INDEX)
	{
		Gui_Notify(playerid,"A torch goes in your left hand. Put your shield away first.");
		return false;
	}

	new seconds = Light_GetSourceSeconds(source), item = seconds > 0 ? ITEM_TORCH_LIT : ITEM_TORCH_BURNT;

	if (seconds <= 0)
	{
		Gui_Notify(playerid,"It has burnt down to nothing.");
		return false;
	}

	new wear = ITEM_WEAR_MAX - seconds * ITEM_WEAR_MAX / LIGHT_TORCH_SECONDS;

	if (!Inventory_Give(playerid,ITEM_KIND_MISC,item,1,ITEM_STARS_MIN,ITEM_FRESH_NOW,Util_ClampInt(wear,0,ITEM_WEAR_MAX - 1)))
	{
		Gui_Notify(playerid,"There's no room in your bag for it.");
		return false;
	}

	Light_RemoveSource(source);
	s_LightTorchCarry[playerid] = 0;
	Light_SyncAttachments(playerid);
	Gui_Notify(playerid,"You pull the torch out of the ground.");
	return true;
}

stock bool:Light_LoadLantern(playerid,bool:isQuiet = false)
{
	new index = Light_FindLantern(playerid,false), bool:isLit = false;

	if (index == -1)
	{
		index = Light_FindLantern(playerid,true);
		isLit = index != -1;
	}

	if (index == -1)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You have no lantern.");
		}

		return false;
	}

	new candle = ITEM_CANDLE_WAX, fuel = LIGHT_CANDLE_WAX_FUEL;

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX) == 0)
	{
		candle = ITEM_CANDLE;
		fuel = LIGHT_CANDLE_TALLOW_FUEL;
	}

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,candle) == 0)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You have no candle to put in the lantern.");
		}

		return false;
	}

	new wear = Inventory_GetSlotWear(playerid,index);

	if (wear == 0)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"The lantern's candle is still whole.");
		}

		return false;
	}

	Inventory_Take(playerid,ITEM_KIND_MATERIAL,candle,1);
	index = Light_FindLantern(playerid,isLit);
	Inventory_SetSlotWear(playerid,index,max(wear - fuel,0));

	if (!isQuiet)
	{
		Gui_Notify(playerid,candle == ITEM_CANDLE_WAX ? ("You put a wax candle in the lantern. It burns for an hour.") : ("You put a tallow candle in the lantern. It burns for half an hour."));
	}

	return true;
}

stock bool:Light_LightLantern(playerid,bool:isQuiet = false)
{
	if (Light_HasLanternLit(playerid))
	{
		return false;
	}

	new index = Light_FindLantern(playerid,false);

	if (index == -1)
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You have no lantern.");
		}

		return false;
	}

	if (Inventory_GetSlotWear(playerid,index) >= ITEM_WEAR_MAX && !Light_LoadLantern(playerid,isQuiet))
	{
		return false;
	}

	index = Light_FindLantern(playerid,false);

	if (!Light_CanKindle(playerid))
	{
		if (!isQuiet)
		{
			Gui_Notify(playerid,"You need a flame to light it: flint in your bag, a fire, or someone's torch close by.");
		}

		return false;
	}

	if (!Light_SwapItem(playerid,index,ITEM_LANTERN_LIT,Inventory_GetSlotWear(playerid,index)))
	{
		return false;
	}

	s_LightLanternCarry[playerid] = 0;
	Light_SyncAttachments(playerid);

	if (!isQuiet)
	{
		Gui_Notify(playerid,"You light the lantern and hang it from your belt.");
	}

	return true;
}

stock bool:Light_PutOutLantern(playerid,const reason[] = "")
{
	new index = Light_FindLantern(playerid,true);

	if (index == -1)
	{
		return false;
	}

	Light_SwapItem(playerid,index,ITEM_LANTERN,Inventory_GetSlotWear(playerid,index));
	Light_SyncAttachments(playerid);

	if (reason[0] != EOS)
	{
		Gui_Notify(playerid,reason);
	}

	return true;
}

stock bool:Light_SetCandleDown(playerid)
{
	new candle = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX) > 0 ? ITEM_CANDLE_WAX : ITEM_CANDLE;

	if (Inventory_Count(playerid,ITEM_KIND_MATERIAL,candle) == 0)
	{
		Gui_Notify(playerid,"You have no candle.");
		return false;
	}

	if (!Light_CanKindle(playerid))
	{
		Gui_Notify(playerid,"You need a flame to light it: flint in your bag, a fire, or someone's torch close by.");
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a, Float:surfaceZ;
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);
	x += LIGHT_CANDLE_AHEAD * floatsin(-a,degrees);
	y += LIGHT_CANDLE_AHEAD * floatcos(-a,degrees);

	if (!Placement_FindSurface(x,y,z + 0.5,LIGHT_PLACE_REACH,surfaceZ))
	{
		Gui_Notify(playerid,"There's nothing there to stand a candle on.");
		return false;
	}

	if (Light_PlaceCandle(candle == ITEM_CANDLE_WAX,x,y,surfaceZ,a,GetPlayerVirtualWorld(playerid),GetPlayerInterior(playerid)) == -1)
	{
		Gui_Notify(playerid,"You can't set a candle down here right now.");
		return false;
	}

	Inventory_Take(playerid,ITEM_KIND_MATERIAL,candle,1);
	Anim_Apply(playerid,"BOMBER","BOM_Plant",4.1,false,false,false,false,0);
	Gui_Notify(playerid,"You light a candle and set it down.");
	pawn_call_public("Light_OnCandleSet","dfff",playerid,x,y,surfaceZ);
	return true;
}

stock Light_HandTick(playerid,seconds)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	new torch = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT);

	if (torch != -1)
	{
		if (Combat_GetShield(playerid) != INVALID_SHIELD_INDEX)
		{
			Light_PutOutTorch(playerid,"You put the torch out to take up your shield.");
		}
		else if (Movement_IsPlayerInWater(playerid))
		{
			Light_PutOutTorch(playerid,"The water puts your torch out.");
		}
		else
		{
			s_LightTorchCarry[playerid] += seconds;
			new perPercent = LIGHT_TORCH_SECONDS / ITEM_WEAR_MAX;

			if (s_LightTorchCarry[playerid] >= perPercent)
			{
				new steps = s_LightTorchCarry[playerid] / perPercent, wear = Inventory_GetSlotWear(playerid,torch) + steps;
				s_LightTorchCarry[playerid] -= steps * perPercent;

				if (wear >= ITEM_WEAR_MAX)
				{
					Inventory_TakeSlot(playerid,torch,1);
					Light_SyncAttachments(playerid);
					Gui_Notify(playerid,"Your torch burns down to a stub and you throw it away.");
					pawn_call_public("Light_OnTorchBurntOut","d",playerid);
				}
				else
				{
					Inventory_SetSlotWear(playerid,torch,wear);
				}
			}
		}
	}

	new lantern = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_LANTERN_LIT);

	if (lantern != -1)
	{
		s_LightLanternCarry[playerid] += seconds;
		new perPercent = LIGHT_LANTERN_SECONDS / ITEM_WEAR_MAX;

		if (s_LightLanternCarry[playerid] >= perPercent)
		{
			new steps = s_LightLanternCarry[playerid] / perPercent, wear = Inventory_GetSlotWear(playerid,lantern) + steps;
			s_LightLanternCarry[playerid] -= steps * perPercent;
			Inventory_SetSlotWear(playerid,lantern,min(wear,ITEM_WEAR_MAX));

			if (wear >= ITEM_WEAR_MAX)
			{
				Light_PutOutLantern(playerid,"The candle in your lantern has burnt out.");
			}
		}
	}

	Light_SyncAttachments(playerid);
}

stock Light_DouseOnLoad(playerid)
{
	new index;

	while ((index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_TORCH_LIT)) != -1)
	{
		if (!Light_SwapItem(playerid,index,ITEM_TORCH_BURNT,Inventory_GetSlotWear(playerid,index)))
		{
			break;
		}
	}

	while ((index = Inventory_Find(playerid,ITEM_KIND_MISC,ITEM_LANTERN_LIT)) != -1)
	{
		if (!Light_SwapItem(playerid,index,ITEM_LANTERN,Inventory_GetSlotWear(playerid,index)))
		{
			break;
		}
	}
}

static Light_FormatLeft(seconds,dest[],size = sizeof(dest))
{
	if (seconds >= 120)
	{
		format(dest,size,"%d min left",seconds / 60);
	}
	else
	{
		strcopy(dest,"almost out",size);
	}
}

stock Light_OpenPanel(playerid)
{
	new epoch = Gui_BeginFlow(playerid);

	for (;;)
	{
		new picks[8], labels[8][64], count = 0, left[24];
		new bool:hasTorch = Light_HasTorchLit(playerid), bool:hasLanternLit = Light_HasLanternLit(playerid);
		new lantern = Light_FindLantern(playerid,false), candles = Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE) + Inventory_Count(playerid,ITEM_KIND_MATERIAL,ITEM_CANDLE_WAX);

		if (hasTorch)
		{
			Light_FormatLeft(Light_GetTorchSecondsLeft(playerid),left);
			format(labels[count],64,"Put the torch out (%s)",left);
			picks[count++] = LIGHT_PICK_TORCH_OUT;
			strcopy(labels[count],"Plant the torch in the ground here",64);
			picks[count++] = LIGHT_PICK_TORCH_PLANT;
		}

		if (hasLanternLit)
		{
			Light_FormatLeft(Light_GetLanternSecondsLeft(playerid),left);
			format(labels[count],64,"Put the lantern out (%s)",left);
			picks[count++] = LIGHT_PICK_LANTERN_OUT;
		}
		else if (lantern != -1)
		{
			strcopy(labels[count],"Light your lantern",64);
			picks[count++] = LIGHT_PICK_LANTERN_LIGHT;
		}

		if (lantern != -1 || hasLanternLit)
		{
			if (candles > 0)
			{
				strcopy(labels[count],"Put a candle in your lantern",64);
				picks[count++] = LIGHT_PICK_LANTERN_LOAD;
			}
		}

		if (candles > 0)
		{
			strcopy(labels[count],"Light a candle and set it down",64);
			picks[count++] = LIGHT_PICK_CANDLE_DOWN;
		}

		if (count == 0)
		{
			Kit_Close(playerid);
			Gui_Notify(playerid,"You carry nothing to light.");
			return;
		}

		new Float:x, Float:y, Float:width;
		Kit_Begin(playerid,KIT_LAYER_SCREEN,LIGHT_PANEL_TITLE);
		Kit_OpenPanel(playerid,KIT_ANCHOR_CENTRE,LIGHT_PANEL_WIDTH,float(count) * KIT_ROW + 6.0 + KIT_ROW + 12.0,LIGHT_PANEL_TITLE,x,y,width);

		for (new i = 0;i < count;i++)
		{
			Kit_AddChoice(playerid,x,y + KIT_ROW * float(i),width,labels[i],picks[i]);
		}

		Kit_AddButton(playerid,x + width / 2.0 - 40.0,y + float(count) * KIT_ROW + 8.0,80.0,GUI_BUTTON_BACK,KIT_BACK);

		new pick = await Kit_Present(playerid);

		if (!Gui_IsFlowCurrent(playerid,epoch) || pick == KIT_BACK)
		{
			Kit_Close(playerid);
			return;
		}

		switch (pick)
		{
			case LIGHT_PICK_TORCH_OUT:
			{
				Light_PutOutTorch(playerid,"You put the torch out. Light it again from your bag.");
			}
			case LIGHT_PICK_TORCH_PLANT:
			{
				Kit_Close(playerid);
				Light_PlantTorch(playerid);
				return;
			}
			case LIGHT_PICK_LANTERN_OUT:
			{
				Light_PutOutLantern(playerid,"You put the lantern out.");
			}
			case LIGHT_PICK_LANTERN_LIGHT:
			{
				Light_LightLantern(playerid);
			}
			case LIGHT_PICK_LANTERN_LOAD:
			{
				Light_LoadLantern(playerid);
			}
			case LIGHT_PICK_CANDLE_DOWN:
			{
				Kit_Close(playerid);
				Light_SetCandleDown(playerid);
				return;
			}
		}
	}
}

forward Light_OpenPanelDeferred(playerid);

public Light_OpenPanelDeferred(playerid)
{
	if (IsPlayerConnected(playerid) && Session_IsPlaying(playerid))
	{
		Light_OpenPanel(playerid);
	}

	return 1;
}

forward Light_OnTorchLit(playerid);

public Light_OnTorchLit(playerid)
{
	return 1;
}

forward Light_OnTorchBurntOut(playerid);

public Light_OnTorchBurntOut(playerid)
{
	return 1;
}

forward Light_OnCandleSet(playerid,Float:x,Float:y,Float:z);

public Light_OnCandleSet(playerid,Float:x,Float:y,Float:z)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_LightTorchCarry[playerid] = 0;
	s_LightLanternCarry[playerid] = 0;
	s_LightHandModel[playerid] = 0;
	s_LightBeltModel[playerid] = 0;
}

hook Inventory_OnLoaded(playerid)
{
	Light_DouseOnLoad(playerid);
	Light_SyncAttachments(playerid);
}

hook Inventory_OnChanged(playerid)
{
	Light_SyncAttachments(playerid);
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars, index

	if (E_ITEM_KIND:kind != ITEM_KIND_MISC && E_ITEM_KIND:kind != ITEM_KIND_MATERIAL)
	{
		return;
	}

	switch (param)
	{
		case ITEM_TORCH, ITEM_TORCH_BURNT:
		{
			if (E_ITEM_KIND:kind != ITEM_KIND_MISC)
			{
				return;
			}

			if (Light_HasTorchLit(playerid))
			{
				Inventory_CloseBagAfterUse(playerid);
				SetTimerEx("Light_OpenPanelDeferred",0,false,"d",playerid);
				return;
			}

			if (Light_LightTorch(playerid))
			{
				Inventory_CloseBagAfterUse(playerid);
			}
		}
		case ITEM_LANTERN:
		{
			if (E_ITEM_KIND:kind != ITEM_KIND_MISC)
			{
				return;
			}

			if (Light_LightLantern(playerid))
			{
				Inventory_CloseBagAfterUse(playerid);
			}
		}
		case ITEM_TORCH_LIT, ITEM_LANTERN_LIT:
		{
			if (E_ITEM_KIND:kind != ITEM_KIND_MISC)
			{
				return;
			}

			Inventory_CloseBagAfterUse(playerid);
			SetTimerEx("Light_OpenPanelDeferred",0,false,"d",playerid);
		}
		case ITEM_CANDLE, ITEM_CANDLE_WAX:
		{
			if (E_ITEM_KIND:kind != ITEM_KIND_MATERIAL)
			{
				return;
			}

			Inventory_CloseBagAfterUse(playerid);
			SetTimerEx("Light_OpenPanelDeferred",0,false,"d",playerid);
		}
	}
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from, to

	Light_SyncAttachments(playerid);
}
