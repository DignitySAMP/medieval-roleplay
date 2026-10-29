#define CARRY_TICK_MS (1000)
#define CARRY_SLOT_LOAD (ATTACH_SLOT_BODY)
#define CARRY_SLOT_BACK (ATTACH_SLOT_BACK)
#define CARRY_SLOT_BASKET (ATTACH_SLOT_HAND_LEFT)

enum
{
	CARRY_LOAD_NONE,
	CARRY_LOAD_LOG,
	CARRY_LOAD_SACK,
	CARRY_LOAD_BARREL,
	CARRY_LOAD_STONE,
	CARRY_LOAD_COFFER,
	CARRY_LOAD_COUNT,
}

enum
{
	CARRY_GRIP_NONE,
	CARRY_GRIP_ARMS,
	CARRY_GRIP_SHOULDER,
}

new const g_CarryLoadModel[CARRY_LOAD_COUNT] = {0, MODEL_CARRY_CARRY_LOG, MODEL_CARRY_CARRY_SACK, MODEL_CARRY_CARRY_BARREL, MODEL_CARRY_CARRY_STONE, MODEL_CARRY_COFFER};
new const g_CarryLoadBone[CARRY_LOAD_COUNT] = {0, ATTACH_BONE_SPINE, ATTACH_BONE_SPINE, ATTACH_BONE_SPINE, ATTACH_BONE_SPINE, ATTACH_BONE_SPINE};
new const g_CarryLoadGrip[CARRY_LOAD_COUNT] = {CARRY_GRIP_NONE, CARRY_GRIP_SHOULDER, CARRY_GRIP_SHOULDER, CARRY_GRIP_ARMS, CARRY_GRIP_ARMS, CARRY_GRIP_ARMS};
new const Float:g_CarryLoadPose[CARRY_LOAD_COUNT][6] = {
	{0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
	{0.13, 0.0, -0.17, 79.6, 87.4, -79.6},
	{0.17, 0.0, -0.15, 79.6, 87.4, -79.6},
	{-0.2, 0.25, -0.04, 79.6, 87.4, -79.6},
	{-0.2, 0.3, -0.04, 79.6, 87.4, -79.6},
	{-0.6, 0.32, -0.04, 79.6, 87.4, -79.6}
};

enum E_CARRY
{
	E_CARRY_LOAD,
	E_CARRY_MODEL,
	E_CARRY_BACK,
	E_CARRY_BASKET,
	E_CARRY_BAND,
	E_CARRY_BULKY,
}

static s_Carry[MAX_PLAYERS][E_CARRY];

stock Carry_GetLoad(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Carry[playerid][E_CARRY_LOAD] : CARRY_LOAD_NONE;
}

stock Carry_GetModel(playerid)
{
    new model;

    if (Util_IsValidPlayer(playerid) && IsPlayerAttachedObjectSlotUsed(playerid,CARRY_SLOT_LOAD))
    {
        GetPlayerAttachedObject(playerid,CARRY_SLOT_LOAD,model);
    }

    return model;
}

stock bool:Carry_IsHolding(playerid)
{
	return Carry_GetLoad(playerid) != CARRY_LOAD_NONE || (Util_IsValidPlayer(playerid) && s_Carry[playerid][E_CARRY_BULKY] > 0);
}

stock Carry_GetBand(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Carry[playerid][E_CARRY_BAND] : CARRY_LIGHT;
}

stock Carry_Describe(playerid,dest[],size = sizeof(dest))
{
	new grams = Inventory_GetWeight(playerid), limit = Inventory_GetCarryLimit(playerid);

	switch (s_Carry[playerid][E_CARRY_BAND])
	{
		case CARRY_OVERLOADED: format(dest,size,"%.1f of %.0f kg: overloaded, slow",float(grams) / 1000.0,float(limit) / 1000.0);
		case CARRY_HEAVY: format(dest,size,"%.1f of %.0f kg: heavy, no running",float(grams) / 1000.0,float(limit) / 1000.0);
		default: format(dest,size,"%.1f of %.0f kg",float(grams) / 1000.0,float(limit) / 1000.0);
	}

	if (s_Carry[playerid][E_CARRY_BULKY] > 0)
	{
		format(dest,size,"%s, a load in your arms",dest);
	}
}

static Carry_ShowLoad(playerid,load,model)
{
	if (load == s_Carry[playerid][E_CARRY_LOAD] && model == s_Carry[playerid][E_CARRY_MODEL])
	{
		return;
	}

	s_Carry[playerid][E_CARRY_LOAD] = load;
	s_Carry[playerid][E_CARRY_MODEL] = model;

	if (load == CARRY_LOAD_NONE || Mount_IsRiding(playerid))
	{
		if (!Mount_IsRiding(playerid))
		{
			RemovePlayerAttachedObject(playerid,CARRY_SLOT_LOAD);
		}

		Carry_HoldPose(playerid,CARRY_GRIP_NONE);
		return;
	}

	SetPlayerAttachedObject(playerid,CARRY_SLOT_LOAD,model,g_CarryLoadBone[load],g_CarryLoadPose[load][0],g_CarryLoadPose[load][1],g_CarryLoadPose[load][2],g_CarryLoadPose[load][3],g_CarryLoadPose[load][4],g_CarryLoadPose[load][5]);
	SetPlayerArmedWeapon(playerid,WEAPON_FIST);
	Carry_HoldPose(playerid,g_CarryLoadGrip[load]);
}

static Carry_ShowBack(playerid,model)
{
	if (model == s_Carry[playerid][E_CARRY_BACK])
	{
		return;
	}

	s_Carry[playerid][E_CARRY_BACK] = model;

	if (model == 0)
	{
		RemovePlayerAttachedObject(playerid,CARRY_SLOT_BACK);
		return;
	}

	if (model == MODEL_CARRY_BACKPACK)
	{
		SetPlayerAttachedObject(playerid,CARRY_SLOT_BACK,model,ATTACH_BONE_SPINE,-0.394,-0.105,-0.003,79.6,87.4,-79.6);
	}
	else
	{
		SetPlayerAttachedObject(playerid,CARRY_SLOT_BACK,model,ATTACH_BONE_SPINE,-0.195,-0.125,-0.001,79.6,87.4,-79.6);
	}
}

static Carry_ShowBasket(playerid,model)
{
	if (model == s_Carry[playerid][E_CARRY_BASKET])
	{
		return;
	}

	s_Carry[playerid][E_CARRY_BASKET] = model;

	if (model == 0)
	{
		RemovePlayerAttachedObject(playerid,CARRY_SLOT_BASKET);
		return;
	}

	SetPlayerAttachedObject(playerid,CARRY_SLOT_BASKET,model,ATTACH_BONE_LEFT_HAND,0.096,0.038,0.0,0.0,-90.0,0.0);
}

stock Carry_Refresh(playerid)
{
	if (!Inventory_IsLoaded(playerid) || !Session_IsPlaying(playerid))
	{
		return;
	}

	new E_ITEM_KIND:kind, param, load = CARRY_LOAD_NONE, model = 0, bulky = Inventory_CountBulky(playerid), index = Inventory_GetHeaviestBulky(playerid,kind,param);

	if (bulky > 0 && index != -1)
	{
		load = Item_GetLoad(kind,param);
        model = kind == ITEM_KIND_MATERIAL && param == ITEM_CARCASS ? Item_GetModel(kind,param,Inventory_GetSlotData(playerid,index)) : g_CarryLoadModel[load];
	}

	s_Carry[playerid][E_CARRY_BULKY] = bulky;
	Carry_ShowLoad(playerid,load,model);

	if (Inventory_HasItem(playerid,ITEM_BACKPACK))
	{
		Carry_ShowBack(playerid,MODEL_CARRY_BACKPACK);
	}
	else if (Inventory_HasItem(playerid,ITEM_SATCHEL))
	{
		Carry_ShowBack(playerid,MODEL_CARRY_SATCHEL);
	}
	else
	{
		Carry_ShowBack(playerid,0);
	}

	if (Inventory_HasItem(playerid,ITEM_CREEL))
	{
		Carry_ShowBasket(playerid,MODEL_CARRY_CREEL);
	}
	else if (Inventory_HasItem(playerid,ITEM_BASKET))
	{
		Carry_ShowBasket(playerid,MODEL_CARRY_BASKET);
	}
	else if (Inventory_HasItem(playerid,ITEM_WOVEN_BASKET))
	{
		Carry_ShowBasket(playerid,MODEL_CARRY_WOVEN_BASKET);
	}
	else
	{
		Carry_ShowBasket(playerid,0);
	}

	new band = Inventory_GetLoadBand(playerid), old = s_Carry[playerid][E_CARRY_BAND];
	s_Carry[playerid][E_CARRY_BAND] = band;
	Carry_SetPace(playerid,Carry_PaceFor(band,bulky));

	if (band == CARRY_LIGHT && bulky == 0)
	{
		Buff_Clear(playerid,"carry");
	}
	else if (bulky > 1)
	{
		Buff_Set(playerid,"carry","Staggering",sprintf("You carry %d heavy loads at once. A cart or a pack animal carries many.",bulky));
	}
	else if (bulky == 1)
	{
		Buff_Set(playerid,"carry","Arms full","A load in your arms: slower, no weapon. Crouch to set it down.");
	}
	else if (band == CARRY_OVERLOADED)
	{
		Buff_Set(playerid,"carry","Overloaded","You walk slowly under the weight. Leave something behind, or use a bag or a cart.");
	}
	else
	{
		Buff_Set(playerid,"carry","Heavy","You can't run with all this. A bag on your back carries more.");
	}

	if (band > old)
	{
		pawn_call_public("Carry_OnBand","ddd",playerid,old,band);
	}
}

stock bool:Carry_PutDown(playerid)
{
	new E_ITEM_KIND:kind, param, index = Inventory_GetHeaviestBulky(playerid,kind,param);

	if (index == -1)
	{
		return false;
	}

	new Float:x, Float:y, Float:z, Float:a, stars = Inventory_GetSlotStars(playerid,index), wear = Inventory_GetSlotWear(playerid,index), fresh = Inventory_GetSlotFresh(playerid,index), data = Inventory_GetSlotData(playerid,index);
	GetPlayerPos(playerid,x,y,z);
	GetPlayerFacingAngle(playerid,a);

	if (!Inventory_TakeSlot(playerid,index,1))
	{
		return false;
	}

    if (kind == ITEM_KIND_MATERIAL && param == ITEM_CARCASS && Hunting_UnpackCarcass(data) != -1 && GetPlayerVirtualWorld(playerid) == 0)
    {
        Hunting_PutDownCarcass(data,x - floatsin(a,degrees) * 0.8,y + floatcos(a,degrees) * 0.8,z,a,Character_GetId(playerid));
    }
    else
    {
        Drop_Create(kind,param,1,x - floatsin(a,degrees) * 0.8,y + floatcos(a,degrees) * 0.8,z,GetPlayerVirtualWorld(playerid),stars,0,fresh,wear,data,.interior = GetPlayerInterior(playerid));
    }
	Carry_Refresh(playerid);
	ApplyAnimation(playerid,"CARRY","putdwn",4.1,false,false,false,false,0,SYNC_ALL);
	return true;
}

forward Task:Carry_Open(playerid,index);
#pragma warning push
#pragma warning disable 204
async Task:Carry_Open(playerid,index)
{
	new E_ITEM_KIND:kind, param, amount;

	if (!Inventory_GetSlot(playerid,index,kind,param,amount) || !Item_IsCarrier(kind,param))
	{
		wait_ticks(1);
		return async INVALID_CONTAINER_ID;
	}

	new containerid = Inventory_GetSlotData(playerid,index);

	if (containerid <= 0)
	{
		new name[ITEM_NAME_LEN];
		Item_GetName(kind,param,name);
		containerid = await Container_Create(CONTAINER_OWNER_CARRIED,param,Item_CarrierSlots(param),name);

		if (!IsPlayerConnected(playerid) || containerid == INVALID_CONTAINER_ID)
		{
			return async INVALID_CONTAINER_ID;
		}

		new E_ITEM_KIND:k2, p2, a2;

		if (!Inventory_GetSlot(playerid,index,k2,p2,a2) || p2 != param)
		{
			return async INVALID_CONTAINER_ID;
		}

		Inventory_SetSlotData(playerid,index,containerid);
	}
	else if (!Container_IsLoaded(containerid))
	{
		await Container_Load(containerid);
	}

	if (IsPlayerConnected(playerid))
	{
		ContainerGui_ShowDeferred(playerid,containerid);
	}

	wait_ticks(1);
	return async containerid;
}
#pragma warning pop

Timer_Declare(Carry_Tick)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && Session_IsPlaying(playerid))
		{
			Carry_Refresh(playerid);
		}
	}

	return 1;
}

forward Carry_OnBand(playerid,oldBand,newBand);

public Carry_OnBand(playerid,oldBand,newBand)
{
	return 1;
}

forward Carry_OpenDeferred(playerid,index);

public Carry_OpenDeferred(playerid,index)
{
	if (IsPlayerConnected(playerid))
	{
		Carry_Open(playerid,index);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_Carry[playerid][E_CARRY_LOAD] = CARRY_LOAD_NONE;
	s_Carry[playerid][E_CARRY_MODEL] = 0;
	s_Carry[playerid][E_CARRY_BACK] = 0;
	s_Carry[playerid][E_CARRY_BASKET] = 0;
	s_Carry[playerid][E_CARRY_BAND] = CARRY_LIGHT;
	s_Carry[playerid][E_CARRY_BULKY] = 0;
}

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
	if ((newkeys & KEY_CROUCH) && !(oldkeys & KEY_CROUCH) && s_Carry[playerid][E_CARRY_BULKY] > 0 && !Mount_IsRiding(playerid) && !Gui_IsBusy(playerid) && Carry_PutDown(playerid))
	{
		Gui_Notify(playerid,"You set the load down.");
	}
}

hook Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	#pragma unused source

	if (after < before && s_Carry[playerid][E_CARRY_BULKY] > 0 && Carry_PutDown(playerid))
	{
		Gui_Notify(playerid,"The blow knocks the load out of your arms.");
	}
}

hook Combat_OnModeChanged(playerid,enabled)
{
	if (enabled && s_Carry[playerid][E_CARRY_BULKY] > 0 && Carry_PutDown(playerid))
	{
		Gui_Notify(playerid,"You drop the load to free your hands.");
	}
}

hook Inventory_OnUse(playerid,kind,param,stars,index)
{
	#pragma unused stars

	if (Item_IsCarrier(E_ITEM_KIND:kind,param))
	{
		Inventory_CloseBagAfterUse(playerid);
		SetTimerEx("Carry_OpenDeferred",0,false,"dd",playerid,index);
	}
}

hook Mount_OnMounted(playerid,horseid)
{
	#pragma unused horseid
	s_Carry[playerid][E_CARRY_LOAD] = CARRY_LOAD_NONE;
	s_Carry[playerid][E_CARRY_MODEL] = 0;
}

hook Mount_OnDismounted(playerid,horseid)
{
	#pragma unused horseid
	s_Carry[playerid][E_CARRY_LOAD] = CARRY_LOAD_NONE;
	s_Carry[playerid][E_CARRY_MODEL] = 0;
	Carry_Refresh(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to != SESSION_PLAYING)
	{
		return;
	}

	s_Carry[playerid][E_CARRY_LOAD] = CARRY_LOAD_NONE;
	s_Carry[playerid][E_CARRY_MODEL] = 0;
	s_Carry[playerid][E_CARRY_BACK] = 0;
	s_Carry[playerid][E_CARRY_BASKET] = 0;
	Carry_Refresh(playerid);
}
