#define WARMTH_MIN (-1000)
#define WARMTH_MAX (1000)
#define WARMTH_FREEZING (-600)
#define WARMTH_HOT (600)
#define WARMTH_COLD (-200)
#define WARMTH_WARM (200)
#define WARMTH_BASE_CLOTHING (6)
#define WARMTH_CLOTHING_CAP (12)
#define WARMTH_DRIFT_PER_SECOND (1)
#define WARMTH_CHILL_SECONDS (6)
#define WARMTH_FREEZE_HEALTH_PER_SECOND (0.2)
#define WARMTH_COMFORT_CELSIUS (18.0)
#define WARMTH_FIRE_RECOVERY (4)
#define WARMTH_HEAT_FX_PEAK (180)

forward bool:Light_IsPlayerWarmed(playerid);

enum E_WARMTH_BAND
{
	WARMTH_BAND_FREEZING,
	WARMTH_BAND_COLD,
	WARMTH_BAND_FINE,
	WARMTH_BAND_WARM,
	WARMTH_BAND_HOT,
}

static const s_WarmthBandNames[E_WARMTH_BAND][12] = {"Freezing", "Cold", "Fine", "Warm", "Hot"};

static s_Warmth[MAX_PLAYERS];
static E_WARMTH_BAND:s_WarmthBand[MAX_PLAYERS];
static s_WarmthExtraClothing[MAX_PLAYERS];
static bool:s_WarmthImmune[MAX_PLAYERS];
static bool:s_WarmthBoon[MAX_PLAYERS];
static s_WarmthCarry[MAX_PLAYERS];
static s_WarmthWarmCarry[MAX_PLAYERS];

stock Warmth_Get(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Warmth[playerid] / 10 : 0;
}

stock Warmth_GetRaw(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Warmth[playerid] : 0;
}

stock E_WARMTH_BAND:Warmth_GetBand(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_WarmthBand[playerid] : WARMTH_BAND_FINE;
}

stock Warmth_BandName(E_WARMTH_BAND:band,dest[],size = sizeof(dest))
{
	strcopy(dest,s_WarmthBandNames[band],size);
}

stock Warmth_GetClothing(playerid)
{
	new total = WARMTH_BASE_CLOTHING + s_WarmthExtraClothing[playerid];
	return total > WARMTH_CLOTHING_CAP ? WARMTH_CLOTHING_CAP : total;
}

stock Warmth_SetExtraClothing(playerid,amount)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WarmthExtraClothing[playerid] = amount;
	}
}

stock Warmth_Needed(Float:celsius)
{
	new needed = floatround((WARMTH_COMFORT_CELSIUS - celsius) / 3.0,floatround_ceil);
	return Util_ClampInt(needed,0,WARMTH_CLOTHING_CAP);
}

static E_WARMTH_BAND:Warmth_BandOf(value)
{
	if (value <= WARMTH_FREEZING) return WARMTH_BAND_FREEZING;
	if (value < WARMTH_COLD) return WARMTH_BAND_COLD;
	if (value >= WARMTH_HOT) return WARMTH_BAND_HOT;
	if (value > WARMTH_WARM) return WARMTH_BAND_WARM;
	return WARMTH_BAND_FINE;
}

stock Float:Warmth_GetPercent(playerid)
{
	return float(s_Warmth[playerid] - WARMTH_MIN) * 100.0 / float(WARMTH_MAX - WARMTH_MIN);
}

stock Warmth_Set(playerid,value)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Warmth[playerid] = Util_ClampInt(value,WARMTH_MIN,WARMTH_MAX);
	new E_WARMTH_BAND:band = Warmth_BandOf(s_Warmth[playerid]);
	if (band != s_WarmthBand[playerid])
	{
		new E_WARMTH_BAND:from = s_WarmthBand[playerid];
		s_WarmthBand[playerid] = band;
		if (Session_IsPlaying(playerid))
		{
			switch (band)
			{
				case WARMTH_BAND_FREEZING: Gui_Notify(playerid,"You're freezing and losing health. Stand near a lit fire or put on warmer clothes.");
				case WARMTH_BAND_COLD: Gui_Notify(playerid,"You're getting cold. Standing near a lit fire or wearing warmer clothes will help.");
				case WARMTH_BAND_HOT: Gui_Notify(playerid,"The heat is getting to you.");
				default: {}
			}
		}
		pawn_call_public("Warmth_OnBandChanged","ddd",playerid,_:from,_:band);
	}

	Hud_SetWarmth(playerid,Warmth_GetPercent(playerid));
	Warmth_ApplyScreenFx(playerid);
}

static Warmth_ApplyScreenFx(playerid)
{
	if (!Session_IsPlaying(playerid))
	{
		ScreenFx_SetLevel(playerid,SCREENFX_COLD,0);
		ScreenFx_SetLevel(playerid,SCREENFX_HEAT,0);
		return;
	}

	new Float:warmth = float(s_Warmth[playerid]);
	ScreenFx_SetLevel(playerid,SCREENFX_COLD,ScreenFx_Scale(warmth,float(WARMTH_COLD),float(WARMTH_MIN),255));
	ScreenFx_SetLevel(playerid,SCREENFX_HEAT,ScreenFx_Scale(warmth,float(WARMTH_WARM),float(WARMTH_MAX),WARMTH_HEAT_FX_PEAK));
}

stock Warmth_Step(playerid,seconds = 1)
{
	if (!Session_IsPlaying(playerid))
	{
		return;
	}

	if (s_WarmthImmune[playerid] || s_WarmthBoon[playerid])
	{
		Warmth_Set(playerid,0);
		return;
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	new Float:celsius = Calendar_GetTemperature(x,y,z,GetPlayerInterior(playerid));
	new clothing = Warmth_GetClothing(playerid), needed = Util_ClampInt(Warmth_Needed(celsius) + Traits_Get(playerid,TRAIT_EFFECT_WARMTH_NEEDED),0,WARMTH_CLOTHING_CAP), gap = clothing - needed;

	if (gap > 0 && s_Warmth[playerid] >= 0)
	{
		gap = max(clothing - max(needed,WARMTH_BASE_CLOTHING),0);
	}

	if (gap < WARMTH_FIRE_RECOVERY && Light_IsPlayerWarmed(playerid))
	{
		gap = max(gap,s_Warmth[playerid] < 0 ? WARMTH_FIRE_RECOVERY : 0);
	}

	new drift = gap * WARMTH_DRIFT_PER_SECOND * seconds;
	if (gap == 0)
	{
		drift = s_Warmth[playerid] > 0 ? -seconds : (s_Warmth[playerid] < 0 ? seconds : 0);
	}
	else if ((gap < 0 && s_Warmth[playerid] <= 0) || (gap > 0 && s_Warmth[playerid] >= 0))
	{
		s_WarmthCarry[playerid] += drift;
		drift = s_WarmthCarry[playerid] / WARMTH_CHILL_SECONDS;
		s_WarmthCarry[playerid] -= drift * WARMTH_CHILL_SECONDS;
	}

	if (drift > 0 && Traits_Get(playerid,TRAIT_EFFECT_WARMING) != 100)
	{
		s_WarmthWarmCarry[playerid] += drift * Traits_Get(playerid,TRAIT_EFFECT_WARMING);
		drift = s_WarmthWarmCarry[playerid] / 100;
		s_WarmthWarmCarry[playerid] -= drift * 100;
	}

	Warmth_Set(playerid,s_Warmth[playerid] + drift);

	if (s_WarmthBand[playerid] == WARMTH_BAND_FREEZING)
	{
		Vitals_Damage(playerid,WARMTH_FREEZE_HEALTH_PER_SECOND * seconds,"cold");
	}
}

Warmth_Reset(playerid)
{
	s_Warmth[playerid] = 0;
	s_WarmthBand[playerid] = WARMTH_BAND_FINE;
	s_WarmthExtraClothing[playerid] = 0;
	s_WarmthImmune[playerid] = false;
	s_WarmthBoon[playerid] = false;
	s_WarmthCarry[playerid] = 0;
	s_WarmthWarmCarry[playerid] = 0;
}

stock Warmth_SetBoon(playerid,bool:isOn)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WarmthBoon[playerid] = isOn;
	}
}

stock bool:Warmth_HasBoon(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WarmthBoon[playerid];
}

forward Warmth_OnBandChanged(playerid,from,to);

public Warmth_OnBandChanged(playerid,from,to)
{
	return 1;
}

CMD<ADMIN_LEVEL_TRIAL>:warm(cmdid, playerid, params[])
{
	#pragma unused cmdid
	#pragma unused params

	s_WarmthImmune[playerid] = !s_WarmthImmune[playerid];
	if (s_WarmthImmune[playerid])
	{
		Warmth_Set(playerid,0);
	}
	SendClientMessage(playerid,0xFFFFFFFF,s_WarmthImmune[playerid] ? ("Cold immunity is on. You'll stay comfortable until you log off or use /warm again.") : ("Cold immunity off."));
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Warmth_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	s_Warmth[playerid] = Character_GetStoredWarmth(playerid);
	s_WarmthBand[playerid] = Warmth_BandOf(s_Warmth[playerid]);
}

hook Character_OnUnloaded(playerid)
{
	Warmth_Reset(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to == SESSION_PLAYING)
	{
		Hud_SetWarmth(playerid,Warmth_GetPercent(playerid));
		Warmth_ApplyScreenFx(playerid);
	}
	else if (from == SESSION_PLAYING)
	{
		Warmth_ApplyScreenFx(playerid);
		Character_SetStoredWarmth(playerid,s_Warmth[playerid]);
	}
}

hook Tick_OnPlayerSecond(playerid)
{
	Warmth_Step(playerid,1);
	Character_SetStoredWarmth(playerid,s_Warmth[playerid]);
}
