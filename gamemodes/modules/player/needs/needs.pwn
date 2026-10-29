#define NEEDS_SCALE (1000)
#define NEEDS_MAX (100 * NEEDS_SCALE)
#define NEEDS_LOW (20 * NEEDS_SCALE)
#define NEEDS_HUNGER_PER_HOUR (4 * NEEDS_SCALE)
#define NEEDS_THIRST_PER_HOUR (6 * NEEDS_SCALE)
#define NEEDS_LOW_STAMINA_CAP (50.0)
#define NEEDS_STARVE_HEALTH_PER_MINUTE (2.0)
#define NEEDS_ALE_HYDRATION_SHARE (2)
#define NEEDS_ALE_NUTRITION (5)

enum E_NEED
{
	NEED_HUNGER,
	NEED_THIRST,
	NEED_COUNT,
}

static s_Needs[MAX_PLAYERS][E_NEED];
static bool:s_NeedsLow[MAX_PLAYERS][E_NEED];
static s_NeedsFactor[MAX_PLAYERS][E_NEED];

stock Needs_Get(playerid,E_NEED:need)
{
	return Util_IsValidPlayer(playerid) ? s_Needs[playerid][need] / NEEDS_SCALE : 0;
}

stock Needs_GetHunger(playerid)
{
	return Needs_Get(playerid,NEED_HUNGER);
}

stock Needs_GetThirst(playerid)
{
	return Needs_Get(playerid,NEED_THIRST);
}

stock bool:Needs_IsLow(playerid,E_NEED:need)
{
	return Util_IsValidPlayer(playerid) && s_NeedsLow[playerid][need];
}

static Needs_PushHud(playerid)
{
	Hud_SetBar(playerid,HUD_BAR_HUNGER,float(s_Needs[playerid][NEED_HUNGER]) / float(NEEDS_SCALE));
	Hud_SetBar(playerid,HUD_BAR_THIRST,float(s_Needs[playerid][NEED_THIRST]) / float(NEEDS_SCALE));
}

static Needs_ApplyCap(playerid)
{
	Vitals_SetStaminaCap(playerid,(s_NeedsLow[playerid][NEED_HUNGER] || s_NeedsLow[playerid][NEED_THIRST]) ? NEEDS_LOW_STAMINA_CAP : VITALS_MAX);
}

stock Needs_SetDrainFactor(playerid,E_NEED:need,percent)
{
	if (!Util_IsValidPlayer(playerid) || need < NEED_HUNGER || need >= NEED_COUNT)
	{
		return;
	}

	s_NeedsFactor[playerid][need] = Util_ClampInt(percent,10,1000);
}

stock Needs_GetSecondsUntilLow(playerid,E_NEED:need)
{
	if (!Util_IsValidPlayer(playerid) || need < NEED_HUNGER || need >= NEED_COUNT || s_Needs[playerid][need] <= NEEDS_LOW)
	{
		return 0;
	}

	new perHour = (need == NEED_HUNGER ? Traits_Scale(playerid,TRAIT_EFFECT_HUNGER,NEEDS_HUNGER_PER_HOUR) : NEEDS_THIRST_PER_HOUR) * s_NeedsFactor[playerid][need] / 100;
	return perHour > 0 ? (s_Needs[playerid][need] - NEEDS_LOW) / perHour * Needs_SecondsPerHour() + (s_Needs[playerid][need] - NEEDS_LOW) % perHour * Needs_SecondsPerHour() / perHour : cellmax;
}

stock Needs_GetDrainFactor(playerid,E_NEED:need)
{
	return Util_IsValidPlayer(playerid) && need >= NEED_HUNGER && need < NEED_COUNT ? s_NeedsFactor[playerid][need] : 100;
}

stock Needs_SetRaw(playerid,E_NEED:need,value)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Needs[playerid][need] = Util_ClampInt(value,0,NEEDS_MAX);
	new bool:low = s_Needs[playerid][need] < NEEDS_LOW;
	if (low != s_NeedsLow[playerid][need])
	{
		s_NeedsLow[playerid][need] = low;
		if (low && Session_IsPlaying(playerid))
		{
			Gui_Notify(playerid,need == NEED_HUNGER ? "Your stomach growls. Find something to eat." : "Your throat is parched. Find something to drink.");
		}
		Needs_ApplyCap(playerid);
	}

	Character_SetStoredNeed(playerid,need == NEED_THIRST,s_Needs[playerid][need]);
	Needs_PushHud(playerid);
}

stock Needs_Set(playerid,E_NEED:need,value)
{
	Needs_SetRaw(playerid,need,value * NEEDS_SCALE);
}

stock Needs_Feed(playerid,E_NEED:need,amount)
{
	if (!Util_IsValidPlayer(playerid) || amount <= 0)
	{
		return;
	}

	Needs_SetRaw(playerid,need,s_Needs[playerid][need] + (need == NEED_HUNGER ? Traits_Scale(playerid,TRAIT_EFFECT_FOOD,amount * NEEDS_SCALE) : amount * NEEDS_SCALE));
	pawn_call_public("Needs_OnFed","ddd",playerid,_:need,amount);
}

static Needs_SecondsPerHour()
{
	return Calendar_MsPerMinute() * 60 / 1000;
}

static bool:Needs_IsIdle(playerid)
{
	new Float:vx, Float:vy, Float:vz;
	GetPlayerVelocity(playerid,vx,vy,vz);
	return vx * vx + vy * vy + vz * vz < 0.0001;
}

static bool:Needs_IsExerting(playerid)
{
	new KEY:keys, updown, leftright;
	GetPlayerKeys(playerid,keys,updown,leftright);
	return (keys & KEY_SPRINT) != KEY:0 || Vitals_IsBusy(playerid);
}

stock Needs_Step(playerid,seconds = 1)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	new hunger = NEEDS_HUNGER_PER_HOUR * seconds / Needs_SecondsPerHour();
	new thirst = NEEDS_THIRST_PER_HOUR * seconds / Needs_SecondsPerHour();

	if (Needs_IsExerting(playerid))
	{
		hunger = hunger * 3 / 2;
		thirst = thirst * 3 / 2;
	}
	else if (Needs_IsIdle(playerid))
	{
		hunger = hunger * 2 / 3;
		thirst = thirst * 2 / 3;
	}
	else
	{
		hunger = Traits_Scale(playerid,TRAIT_EFFECT_MOVING,hunger);
		thirst = Traits_Scale(playerid,TRAIT_EFFECT_MOVING,thirst);
	}

	hunger = Traits_Scale(playerid,TRAIT_EFFECT_HUNGER,hunger);

	switch (Warmth_GetBand(playerid))
	{
		case WARMTH_BAND_HOT: thirst *= 2;
		case WARMTH_BAND_FREEZING: hunger *= 2;
		default: {}
	}

	hunger = hunger * s_NeedsFactor[playerid][NEED_HUNGER] / 100;
	thirst = thirst * s_NeedsFactor[playerid][NEED_THIRST] / 100;

	Needs_SetRaw(playerid,NEED_HUNGER,s_Needs[playerid][NEED_HUNGER] - hunger);
	Needs_SetRaw(playerid,NEED_THIRST,s_Needs[playerid][NEED_THIRST] - thirst);

	for (new E_NEED:need = NEED_HUNGER; need < NEED_COUNT; need++)
	{
		if (s_Needs[playerid][need] > 0)
		{
			continue;
		}

		Vitals_Damage(playerid,NEEDS_STARVE_HEALTH_PER_MINUTE * float(seconds) * 1000.0 / float(Calendar_MsPerMinute()),need == NEED_HUNGER ? "starvation" : "thirst");
		pawn_call_public("Needs_OnStarving","dd",playerid,_:need);
	}
}

Needs_Reset(playerid)
{
	for (new E_NEED:need = NEED_HUNGER; need < NEED_COUNT; need++)
	{
		s_Needs[playerid][need] = NEEDS_MAX;
		s_NeedsLow[playerid][need] = false;
		s_NeedsFactor[playerid][need] = 100;
	}
}

forward Needs_OnFed(playerid,need,amount);

public Needs_OnFed(playerid,need,amount)
{
	return 1;
}

forward Needs_OnStarving(playerid,need);

public Needs_OnStarving(playerid,need)
{
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Needs_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	s_Needs[playerid][NEED_HUNGER] = Util_ClampInt(Character_GetStoredNeed(playerid,false),0,NEEDS_MAX);
	s_Needs[playerid][NEED_THIRST] = Util_ClampInt(Character_GetStoredNeed(playerid,true),0,NEEDS_MAX);
	for (new E_NEED:need = NEED_HUNGER; need < NEED_COUNT; need++)
	{
		s_NeedsLow[playerid][need] = s_Needs[playerid][need] < NEEDS_LOW;
	}
}

hook Character_OnUnloaded(playerid)
{
	Needs_Reset(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to == SESSION_PLAYING)
	{
		Needs_PushHud(playerid);
		Needs_ApplyCap(playerid);
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	Needs_Step(playerid,1);
}
