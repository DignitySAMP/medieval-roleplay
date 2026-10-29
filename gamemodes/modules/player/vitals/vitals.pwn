#define VITALS_MAX (100.0)
#define VITALS_BLOOD_FROM (75.0)
#define VITALS_STAMINA_REGEN_PER_TICK (25.0)
#define VITALS_STAMINA_REGEN_DELAY_MS (3000)
#define VITALS_TICK_MS (1000)
#define VITALS_ENGINE_HEALTH (100.0)

enum E_VITALS
{
	Float:E_VITALS_HEALTH,
	Float:E_VITALS_STAMINA,
	bool:E_VITALS_BUSY,
	Float:E_VITALS_STAMINA_CAP,
	Float:E_VITALS_STAMINA_LIMIT,
	Float:E_VITALS_STAMINA_WOUND,
	Float:E_VITALS_STAMINA_MOOD,
	Float:E_VITALS_STAMINA_FATIGUE,
	E_VITALS_REGEN_PERCENT,
	E_VITALS_SPENT_AT,
	Float:E_VITALS_HEALTH_LIMIT,
}

static s_Vitals[MAX_PLAYERS][E_VITALS];

stock Float:Vitals_GetHealth(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0.0;
	}

	return s_Vitals[playerid][E_VITALS_HEALTH];
}

stock Float:Vitals_GetStamina(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return 0.0;
	}

	return s_Vitals[playerid][E_VITALS_STAMINA];
}

stock bool:Vitals_IsBusy(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Vitals[playerid][E_VITALS_BUSY];
}

stock Vitals_SetBusy(playerid,bool:busy)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_BUSY] = busy;
}

static Vitals_Mirror(playerid)
{
	SetPlayerHealth(playerid,s_Vitals[playerid][E_VITALS_HEALTH] > 0.0 ? VITALS_ENGINE_HEALTH : 0.0);
	Hud_SetBar(playerid,HUD_BAR_HEALTH,s_Vitals[playerid][E_VITALS_HEALTH]);
	ScreenFx_SetLevel(playerid,SCREENFX_BLOOD,ScreenFx_Scale(s_Vitals[playerid][E_VITALS_HEALTH],VITALS_BLOOD_FROM,0.0,255));
}

stock Vitals_SetHealth(playerid,Float:amount,const source[] = "")
{
	if (!Util_IsValidPlayer(playerid) || !Session_HasCharacter(playerid))
	{
		return;
	}

	new Float:before = s_Vitals[playerid][E_VITALS_HEALTH];
	s_Vitals[playerid][E_VITALS_HEALTH] = Util_Clamp(amount,0.0,s_Vitals[playerid][E_VITALS_HEALTH_LIMIT]);
	Vitals_Mirror(playerid);
	Character_SetStoredHealth(playerid,s_Vitals[playerid][E_VITALS_HEALTH]);
	Character_RequestSave(playerid);
	pawn_call_public("Vitals_OnHealthChanged","dffs",playerid,before,s_Vitals[playerid][E_VITALS_HEALTH],source);

	if (before > 0.0 && s_Vitals[playerid][E_VITALS_HEALTH] <= 0.0)
	{
		pawn_call_public("Vitals_OnDepleted","ds",playerid,source);
	}
}

stock Vitals_Damage(playerid,Float:amount,const source[] = "")
{
	Vitals_SetHealth(playerid,Vitals_GetHealth(playerid) - amount,source);
}

stock Vitals_Heal(playerid,Float:amount,const source[] = "")
{
	Vitals_SetHealth(playerid,Vitals_GetHealth(playerid) + amount,source);
}

stock Float:Vitals_GetStaminaCap(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return VITALS_MAX;
	}

	new Float:cap = s_Vitals[playerid][E_VITALS_STAMINA_CAP];

	if (s_Vitals[playerid][E_VITALS_STAMINA_LIMIT] < cap)
	{
		cap = s_Vitals[playerid][E_VITALS_STAMINA_LIMIT];
	}

	if (s_Vitals[playerid][E_VITALS_STAMINA_MOOD] < cap)
	{
		cap = s_Vitals[playerid][E_VITALS_STAMINA_MOOD];
	}

	if (s_Vitals[playerid][E_VITALS_STAMINA_FATIGUE] < cap)
	{
		cap = s_Vitals[playerid][E_VITALS_STAMINA_FATIGUE];
	}

	return s_Vitals[playerid][E_VITALS_STAMINA_WOUND] < cap ? s_Vitals[playerid][E_VITALS_STAMINA_WOUND] : cap;
}

stock Vitals_SetStamina(playerid,Float:amount)
{
	if (!Util_IsValidPlayer(playerid) || !Session_HasCharacter(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA] = Util_Clamp(amount,0.0,Vitals_GetStaminaCap(playerid));
	Hud_SetBar(playerid,HUD_BAR_STAMINA,s_Vitals[playerid][E_VITALS_STAMINA]);
}

stock Vitals_SetStaminaCap(playerid,Float:cap)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA_CAP] = Util_Clamp(cap,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_STAMINA] > Vitals_GetStaminaCap(playerid))
	{
		Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	}
}

stock Vitals_SetStaminaRegenPercent(playerid,percent)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_Vitals[playerid][E_VITALS_REGEN_PERCENT] = Util_ClampInt(percent,10,300);
	}
}

stock Vitals_GetStaminaRegenPercent(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Vitals[playerid][E_VITALS_REGEN_PERCENT] : 100;
}

stock Vitals_SetStaminaWoundCap(playerid,Float:cap)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA_WOUND] = Util_Clamp(cap,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_STAMINA] > Vitals_GetStaminaCap(playerid))
	{
		Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	}
}

stock Vitals_SetStaminaMoodCap(playerid,Float:cap)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA_MOOD] = Util_Clamp(cap,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_STAMINA] > Vitals_GetStaminaCap(playerid))
	{
		Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	}
}

stock Vitals_SetStaminaFatigueCap(playerid,Float:cap)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA_FATIGUE] = Util_Clamp(cap,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_STAMINA] > Vitals_GetStaminaCap(playerid))
	{
		Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	}
}

stock Vitals_SetStaminaLimit(playerid,Float:limit)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_STAMINA_LIMIT] = Util_Clamp(limit,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_STAMINA] > Vitals_GetStaminaCap(playerid))
	{
		Vitals_SetStamina(playerid,Vitals_GetStaminaCap(playerid));
	}
}

stock Vitals_SetHealthLimit(playerid,Float:limit)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	s_Vitals[playerid][E_VITALS_HEALTH_LIMIT] = Util_Clamp(limit,1.0,VITALS_MAX);
	if (s_Vitals[playerid][E_VITALS_HEALTH] > s_Vitals[playerid][E_VITALS_HEALTH_LIMIT] && Session_HasCharacter(playerid))
	{
		Vitals_SetHealth(playerid,s_Vitals[playerid][E_VITALS_HEALTH_LIMIT],"limit");
	}
}

stock Float:Vitals_GetHealthLimit(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_Vitals[playerid][E_VITALS_HEALTH_LIMIT] : VITALS_MAX;
}

stock bool:Vitals_DrainStamina(playerid,Float:amount)
{
	if (Vitals_GetStamina(playerid) < amount)
	{
		return false;
	}

	Vitals_SetStamina(playerid,Vitals_GetStamina(playerid) - amount);

	if (amount > 0.0)
	{
		s_Vitals[playerid][E_VITALS_SPENT_AT] = GetTickCount();
	}

	return true;
}

stock bool:Vitals_IsStaminaResting(playerid)
{
	return Util_IsValidPlayer(playerid) && s_Vitals[playerid][E_VITALS_SPENT_AT] != 0 && GetTickCount() - s_Vitals[playerid][E_VITALS_SPENT_AT] < VITALS_STAMINA_REGEN_DELAY_MS;
}

Vitals_Reset(playerid)
{
	s_Vitals[playerid][E_VITALS_HEALTH] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_BUSY] = false;
	s_Vitals[playerid][E_VITALS_STAMINA_CAP] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_LIMIT] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_WOUND] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_MOOD] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_FATIGUE] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_REGEN_PERCENT] = 100;
	s_Vitals[playerid][E_VITALS_SPENT_AT] = 0;
	s_Vitals[playerid][E_VITALS_HEALTH_LIMIT] = VITALS_MAX;
}

Vitals_LoadFromCharacter(playerid,Float:health)
{
	s_Vitals[playerid][E_VITALS_HEALTH] = Util_Clamp(health,1.0,VITALS_MAX);
	s_Vitals[playerid][E_VITALS_STAMINA] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_BUSY] = false;
	s_Vitals[playerid][E_VITALS_STAMINA_CAP] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_LIMIT] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_WOUND] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_MOOD] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_STAMINA_FATIGUE] = VITALS_MAX;
	s_Vitals[playerid][E_VITALS_REGEN_PERCENT] = 100;
	s_Vitals[playerid][E_VITALS_SPENT_AT] = 0;
	s_Vitals[playerid][E_VITALS_HEALTH_LIMIT] = VITALS_MAX;
}

forward Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[]);

public Vitals_OnHealthChanged(playerid,Float:before,Float:after,const source[])
{
	return 1;
}

forward Vitals_OnDepleted(playerid,const source[]);

public Vitals_OnDepleted(playerid,const source[])
{
	return 1;
}

Timer_Declare(Vitals_Tick)
{
	foreach(new i : Player)
	{
		if (!Session_IsPlaying(i) || s_Vitals[i][E_VITALS_BUSY] || s_Vitals[i][E_VITALS_STAMINA] >= Vitals_GetStaminaCap(i) || Vitals_IsStaminaResting(i))
		{
			continue;
		}

		Vitals_SetStamina(i,s_Vitals[i][E_VITALS_STAMINA] + VITALS_STAMINA_REGEN_PER_TICK * float(s_Vitals[i][E_VITALS_REGEN_PERCENT]) / 100.0);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Vitals_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Vitals_LoadFromCharacter(playerid,Character_GetStoredHealth(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Vitals_Reset(playerid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	#pragma unused from

	if (to == SESSION_PLAYING)
	{
		if (s_Vitals[playerid][E_VITALS_HEALTH] <= 0.0)
		{
			s_Vitals[playerid][E_VITALS_HEALTH] = s_Vitals[playerid][E_VITALS_HEALTH_LIMIT];
			s_Vitals[playerid][E_VITALS_STAMINA] = Vitals_GetStaminaCap(playerid);
			Character_SetStoredHealth(playerid,s_Vitals[playerid][E_VITALS_HEALTH]);
		}

		Hud_Show(playerid);
		Vitals_Mirror(playerid);
		Hud_SetBar(playerid,HUD_BAR_STAMINA,s_Vitals[playerid][E_VITALS_STAMINA]);
		Hud_SetBar(playerid,HUD_BAR_HUNGER,VITALS_MAX);
		Hud_SetBar(playerid,HUD_BAR_THIRST,VITALS_MAX);
	}
	else if (to == SESSION_CHARACTER_SELECT || to == SESSION_DECEASED || to == SESSION_DISCONNECTING)
	{
		Hud_Hide(playerid);
		ScreenFx_SetLevel(playerid,SCREENFX_BLOOD,0);
	}
}

hook OnPlayerTakeDamage(playerid,issuerid,Float:amount,WEAPON:weaponid,bodypart)
{
	#pragma unused issuerid, amount, weaponid, bodypart

	if (Session_HasCharacter(playerid))
	{
		Vitals_Mirror(playerid);
	}
}
