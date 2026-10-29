#define TRAITS_WILLPOWER_HUNGER (5)
#define TRAITS_WILLPOWER_FROM (2)
#define TRAITS_BUFF_A "trait_a"
#define TRAITS_BUFF_B "trait_b"
#define TRAITS_BUFF_WILLPOWER "willpower"
#define TRAITS_BUFF_KIND_HEART "kind_heart"
#define TRAITS_BUFF_REMORSE "remorse"
#define TRAITS_MOOD_SECONDS (600)
#define TRAITS_REMORSE_CAP (90.0)
#define TRAITS_KIND_HEART_REGEN (130)
#define TRAITS_MIDDAY_HOUR (12)

enum E_TRAIT_EFFECT
{
	TRAIT_EFFECT_HUNGER,
	TRAIT_EFFECT_FOOD,
	TRAIT_EFFECT_MOVING,
	TRAIT_EFFECT_WARMTH_NEEDED,
	TRAIT_EFFECT_WARMING,
	TRAIT_EFFECT_STAMINA_DAY,
	TRAIT_EFFECT_STAMINA_NIGHT,
	TRAIT_EFFECT_DAMAGE_DEALT,
	TRAIT_EFFECT_DAMAGE_TAKEN,
	TRAIT_EFFECT_PARRY,
	TRAIT_EFFECT_STRUCK,
	TRAIT_EFFECT_HEALING,
	TRAIT_EFFECT_FIELDWORK,
	TRAIT_EFFECT_CRAFT_EASE,
	TRAIT_EFFECT_FIND,
	TRAIT_EFFECT_BLESSING,
	TRAIT_EFFECT_HAND_EASE,
	TRAIT_EFFECT_STAMINA_MORNING,
	TRAIT_EFFECT_KIND_HEART,
	TRAIT_EFFECT_FINISH_STAMINA,
	TRAIT_EFFECT_SHOP_PRICE,
	TRAIT_EFFECT_COUNT,
}

static const s_TraitEffectBase[E_TRAIT_EFFECT] = {100, 100, 100, 0, 100, 100, 100, 100, 100, 100, 100, 100, 100, 0, 0, 100, 0, 100, 0, 0, 100};

static const s_TraitEffectRows[][3] = {
	{_:TRAIT_HARDY, _:TRAIT_EFFECT_HUNGER, 80},
	{_:TRAIT_HARDY, _:TRAIT_EFFECT_WARMTH_NEEDED, 1},
	{_:TRAIT_GLUTTON, _:TRAIT_EFFECT_FOOD, 125},
	{_:TRAIT_GLUTTON, _:TRAIT_EFFECT_HUNGER, 125},
	{_:TRAIT_THICK_SKINNED, _:TRAIT_EFFECT_DAMAGE_TAKEN, 85},
	{_:TRAIT_THICK_SKINNED, _:TRAIT_EFFECT_WARMING, 50},
	{_:TRAIT_EARLY_RISER, _:TRAIT_EFFECT_STAMINA_DAY, 130},
	{_:TRAIT_EARLY_RISER, _:TRAIT_EFFECT_STAMINA_NIGHT, 70},
	{_:TRAIT_BRAWLER, _:TRAIT_EFFECT_DAMAGE_DEALT, 115},
	{_:TRAIT_BRAWLER, _:TRAIT_EFFECT_PARRY, 150},
	{_:TRAIT_FRUGAL, _:TRAIT_EFFECT_FOOD, 85},
	{_:TRAIT_KEEN_EYE, _:TRAIT_EFFECT_FIND, 25},
	{_:TRAIT_STUBBORN, _:TRAIT_EFFECT_STRUCK, 150},
	{_:TRAIT_STUBBORN, _:TRAIT_EFFECT_HEALING, 125},
	{_:TRAIT_BOOKISH, _:TRAIT_EFFECT_CRAFT_EASE, 1},
	{_:TRAIT_BOOKISH, _:TRAIT_EFFECT_FIELDWORK, 125},
	{_:TRAIT_WANDERER, _:TRAIT_EFFECT_MOVING, 80},
	{_:TRAIT_DEVOUT, _:TRAIT_EFFECT_BLESSING, 150},
	{_:TRAIT_THIEFS_HANDS, _:TRAIT_EFFECT_HAND_EASE, 1},
	{_:TRAIT_HEAVY_SLEEPER, _:TRAIT_EFFECT_STAMINA_NIGHT, 130},
	{_:TRAIT_HEAVY_SLEEPER, _:TRAIT_EFFECT_STAMINA_MORNING, 70},
	{_:TRAIT_SOFT_HEARTED, _:TRAIT_EFFECT_KIND_HEART, 1},
	{_:TRAIT_COLD_BLOODED, _:TRAIT_EFFECT_FINISH_STAMINA, 20},
	{_:TRAIT_SILVER_TONGUE, _:TRAIT_EFFECT_SHOP_PRICE, 90}
};

static s_TraitValues[MAX_PLAYERS][E_TRAIT_EFFECT];
static s_TraitKindHeartUntil[MAX_PLAYERS];
static s_TraitRemorseUntil[MAX_PLAYERS];

stock Traits_CountEffects()
{
	return sizeof(s_TraitEffectRows);
}

static bool:Traits_IsAdditive(E_TRAIT_EFFECT:effect)
{
	return s_TraitEffectBase[effect] == 0;
}

stock Traits_Get(playerid,E_TRAIT_EFFECT:effect)
{
	if (effect < TRAIT_EFFECT_HUNGER || effect >= TRAIT_EFFECT_COUNT)
	{
		return 100;
	}

	return Util_IsValidPlayer(playerid) ? s_TraitValues[playerid][effect] : s_TraitEffectBase[effect];
}

stock Traits_Scale(playerid,E_TRAIT_EFFECT:effect,value)
{
	return value * Traits_Get(playerid,effect) / 100;
}

stock Float:Traits_Factor(playerid,E_TRAIT_EFFECT:effect)
{
	return float(Traits_Get(playerid,effect)) / 100.0;
}

static Traits_Reset(playerid)
{
	for (new E_TRAIT_EFFECT:effect = TRAIT_EFFECT_HUNGER;effect < TRAIT_EFFECT_COUNT;effect++)
	{
		s_TraitValues[playerid][effect] = s_TraitEffectBase[effect];
	}
}

static Traits_AddTrait(values[E_TRAIT_EFFECT],trait)
{
	for (new i = 0;i < sizeof(s_TraitEffectRows);i++)
	{
		if (s_TraitEffectRows[i][0] != trait)
		{
			continue;
		}

		new E_TRAIT_EFFECT:effect = E_TRAIT_EFFECT:s_TraitEffectRows[i][1];

		if (Traits_IsAdditive(effect))
		{
			values[effect] += s_TraitEffectRows[i][2];
		}
		else
		{
			values[effect] = values[effect] * s_TraitEffectRows[i][2] / 100;
		}
	}
}

static Traits_Fill(values[E_TRAIT_EFFECT],traitA,traitB,willpower)
{
	for (new E_TRAIT_EFFECT:effect = TRAIT_EFFECT_HUNGER;effect < TRAIT_EFFECT_COUNT;effect++)
	{
		values[effect] = s_TraitEffectBase[effect];
	}

	Traits_AddTrait(values,traitA);

	if (traitB != traitA)
	{
		Traits_AddTrait(values,traitB);
	}

	values[TRAIT_EFFECT_HUNGER] = values[TRAIT_EFFECT_HUNGER] * (100 - TRAITS_WILLPOWER_HUNGER * max(willpower - TRAITS_WILLPOWER_FROM,0)) / 100;
}

stock Traits_Compute(traitA,traitB,willpower,E_TRAIT_EFFECT:effect)
{
	if (effect < TRAIT_EFFECT_HUNGER || effect >= TRAIT_EFFECT_COUNT)
	{
		return 100;
	}

	new values[E_TRAIT_EFFECT];
	Traits_Fill(values,traitA,traitB,willpower);
	return values[effect];
}

static bool:Traits_Describe(playerid,trait,dest[],size)
{
	dest[0] = EOS;

	switch (E_TRAIT:trait)
	{
		case TRAIT_HARDY: strcopy(dest,"You get hungry slower. You need one more layer of clothes than others to keep warm.",size);
		case TRAIT_GLUTTON: strcopy(dest,"Food fills you up more. You also get hungry faster.",size);
		case TRAIT_THICK_SKINNED: strcopy(dest,"Blows hurt you less. Fires and clothes take twice as long to warm you up.",size);
		case TRAIT_EARLY_RISER: strcopy(dest,"Your stamina comes back faster by day and slower at night.",size);
		case TRAIT_BRAWLER: strcopy(dest,"Your hits do more damage. Blocking a hit costs you more stamina and does more damage to you or your shield.",size);
		case TRAIT_FRUGAL: strcopy(dest,"Meals fill you up less.",size);
		case TRAIT_KEEN_EYE: format(dest,size,"When you gather from a wild spot, 1 time in %d you get one extra.",100 / max(Traits_Get(playerid,TRAIT_EFFECT_FIND),1));
		case TRAIT_STUBBORN: format(dest,size,"If you're struck down, you have %d seconds instead of %d for someone to help you up. Wounds take longer to heal.",Combat_GetStruckSeconds(playerid),Combat_GetStruckSeconds(INVALID_PLAYER_ID));
		case TRAIT_BOOKISH: strcopy(dest,"Work at a station is a little more forgiving. Gathering at wild spots tires you out faster.",size);
		case TRAIT_WANDERER: strcopy(dest,"You get hungry and thirsty slower while you walk.",size);
		case TRAIT_DEVOUT: format(dest,size,"A priest's blessing lasts %d hours of play for you instead of %d.",Faith_GetBlessingSeconds(playerid) / 3600,Faith_GetBlessingSeconds(INVALID_PLAYER_ID) / 3600);
		case TRAIT_THIEFS_HANDS: strcopy(dest,"Your hands are quick. Key sequences and work done without a tool are a step easier.",size);
		case TRAIT_SOFT_HEARTED: format(dest,size,"Help someone to their feet and your stamina comes back faster for %d minutes. Strike someone down and it can't go above %d%% for %d minutes.",TRAITS_MOOD_SECONDS / 60,floatround(TRAITS_REMORSE_CAP),TRAITS_MOOD_SECONDS / 60);
		case TRAIT_COLD_BLOODED: format(dest,size,"Finishing off someone who's down gives you %d stamina back.",Traits_Get(playerid,TRAIT_EFFECT_FINISH_STAMINA));
		case TRAIT_HEAVY_SLEEPER: strcopy(dest,"Your stamina comes back faster at night and slower from dawn to midday.",size);
		case TRAIT_SILVER_TONGUE: format(dest,size,"Traders pay you %d%% more for your goods and sell to you for %d%% less.",100 - Traits_Get(playerid,TRAIT_EFFECT_SHOP_PRICE),100 - Traits_Get(playerid,TRAIT_EFFECT_SHOP_PRICE));
		default: {}
	}

	return dest[0] != EOS;
}

static Traits_ShowTraitBuff(playerid,const key[],trait)
{
	new name[CREATOR_LABEL_LEN], text[BUFF_TEXT_LEN];

	if (trait < 0 || trait >= _:TRAIT_COUNT || !Traits_Describe(playerid,trait,text,sizeof(text)))
	{
		Buff_Clear(playerid,key);
		return;
	}

	Creator_TraitName(E_TRAIT:trait,name);
	Buff_Set(playerid,key,name,text);
}

static Traits_ShowBuffs(playerid,traitA,traitB,willpower)
{
	Traits_ShowTraitBuff(playerid,TRAITS_BUFF_A,traitA);
	Traits_ShowTraitBuff(playerid,TRAITS_BUFF_B,traitB != traitA ? traitB : -1);

	if (willpower > TRAITS_WILLPOWER_FROM)
	{
		new text[BUFF_TEXT_LEN];
		format(text,sizeof(text),"With %d Willpower you get hungry slower.",willpower);
		Buff_Set(playerid,TRAITS_BUFF_WILLPOWER,"Willpower",text);
	}
	else
	{
		Buff_Clear(playerid,TRAITS_BUFF_WILLPOWER);
	}
}

static Traits_ClearBuffs(playerid)
{
	Buff_Clear(playerid,TRAITS_BUFF_A);
	Buff_Clear(playerid,TRAITS_BUFF_B);
	Buff_Clear(playerid,TRAITS_BUFF_WILLPOWER);
}

stock Traits_ApplyTimeOfDay(playerid)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new percent = Traits_Get(playerid,Calendar_IsNight() ? TRAIT_EFFECT_STAMINA_NIGHT : TRAIT_EFFECT_STAMINA_DAY);

	if (!Calendar_IsNight() && Calendar_GetHour() < TRAITS_MIDDAY_HOUR)
	{
		percent = percent * Traits_Get(playerid,TRAIT_EFFECT_STAMINA_MORNING) / 100;
	}

	if (s_TraitKindHeartUntil[playerid] > gettime())
	{
		percent = percent * TRAITS_KIND_HEART_REGEN / 100;
	}

	Vitals_SetStaminaRegenPercent(playerid,percent);
}

stock bool:Traits_HasKindHeart(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TraitKindHeartUntil[playerid] > gettime();
}

stock bool:Traits_HasRemorse(playerid)
{
	return Util_IsValidPlayer(playerid) && s_TraitRemorseUntil[playerid] > gettime();
}

static Traits_GiveKindHeart(playerid)
{
	if (Traits_Get(playerid,TRAIT_EFFECT_KIND_HEART) <= 0)
	{
		return;
	}

	new bool:renewed = Traits_HasKindHeart(playerid), text[BUFF_TEXT_LEN];
	s_TraitKindHeartUntil[playerid] = gettime() + TRAITS_MOOD_SECONDS;
	Buff_Set(playerid,TRAITS_BUFF_KIND_HEART,"Kind heart","Your stamina comes back faster.",TRAITS_MOOD_SECONDS,TRAITS_MOOD_SECONDS);
	Traits_ApplyTimeOfDay(playerid);
	format(text,sizeof(text),renewed ? ("Your kind heart is renewed. Your stamina comes back faster for another %d minutes.") : ("Helping them up lifted your spirits. Your stamina comes back faster for %d minutes."),TRAITS_MOOD_SECONDS / 60);
	Gui_Notify(playerid,text);
}

static Traits_GiveRemorse(playerid)
{
	if (Traits_Get(playerid,TRAIT_EFFECT_KIND_HEART) <= 0)
	{
		return;
	}

	new text[BUFF_TEXT_LEN];
	s_TraitRemorseUntil[playerid] = gettime() + TRAITS_MOOD_SECONDS;
	format(text,sizeof(text),"Your stamina can't go above %d%%.",floatround(TRAITS_REMORSE_CAP));
	Buff_Set(playerid,TRAITS_BUFF_REMORSE,"Remorse",text,TRAITS_MOOD_SECONDS,TRAITS_MOOD_SECONDS);
	Vitals_SetStaminaMoodCap(playerid,TRAITS_REMORSE_CAP);
	format(text,sizeof(text),"Striking them down weighs on you. Your stamina can't go above %d%% for %d minutes.",floatround(TRAITS_REMORSE_CAP),TRAITS_MOOD_SECONDS / 60);
	Gui_Notify(playerid,text);
}

static Traits_EndMoods(playerid,bool:isSilent)
{
	new now = gettime();

	if (s_TraitKindHeartUntil[playerid] != 0 && s_TraitKindHeartUntil[playerid] <= now)
	{
		s_TraitKindHeartUntil[playerid] = 0;
		Buff_Clear(playerid,TRAITS_BUFF_KIND_HEART);
		Traits_ApplyTimeOfDay(playerid);

		if (!isSilent)
		{
			Gui_Notify(playerid,"Your kind heart has worn off. Your stamina comes back at its usual pace.");
		}
	}

	if (s_TraitRemorseUntil[playerid] != 0 && s_TraitRemorseUntil[playerid] <= now)
	{
		s_TraitRemorseUntil[playerid] = 0;
		Buff_Clear(playerid,TRAITS_BUFF_REMORSE);
		Vitals_SetStaminaMoodCap(playerid,VITALS_MAX);

		if (!isSilent)
		{
			Gui_Notify(playerid,"Your remorse has passed. Your stamina can fill up again.");
		}
	}
}

stock Traits_Apply(playerid,traitA,traitB,willpower)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	new values[E_TRAIT_EFFECT];
	Traits_Fill(values,traitA,traitB,willpower);
	s_TraitValues[playerid] = values;
	Traits_ApplyTimeOfDay(playerid);
	Traits_ShowBuffs(playerid,traitA,traitB,willpower);
}

forward Traits_LoadDeferred(playerid,token);

public Traits_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token && Session_HasCharacter(playerid))
	{
		Traits_Apply(playerid,Character_GetTrait(playerid,false),Character_GetTrait(playerid,true),Character_GetAttribute(playerid,_:ATTR_WILLPOWER));
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Traits_Reset(playerid);
	s_TraitKindHeartUntil[playerid] = 0;
	s_TraitRemorseUntil[playerid] = 0;
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	SetTimerEx("Traits_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	Traits_Reset(playerid);
	Traits_ClearBuffs(playerid);
	s_TraitKindHeartUntil[playerid] = 0;
	s_TraitRemorseUntil[playerid] = 0;
	Buff_Clear(playerid,TRAITS_BUFF_KIND_HEART);
	Buff_Clear(playerid,TRAITS_BUFF_REMORSE);
	Vitals_SetStaminaMoodCap(playerid,VITALS_MAX);
	Vitals_SetStaminaRegenPercent(playerid,100);
}

hook Tick_OnPlayerSecond(playerid)
{
	if (s_TraitKindHeartUntil[playerid] != 0 || s_TraitRemorseUntil[playerid] != 0)
	{
		Traits_EndMoods(playerid,false);
	}
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour

	foreach (new playerid : Player)
	{
		Traits_ApplyTimeOfDay(playerid);
	}
}

hook Combat_OnRevived(playerid,helperid)
{
	if (Util_IsValidPlayer(helperid) && helperid != playerid)
	{
		Traits_GiveKindHeart(helperid);
	}
}

hook Combat_OnFelled(attackerid,targetid)
{
	if (Util_IsValidPlayer(attackerid) && attackerid != targetid)
	{
		Traits_GiveRemorse(attackerid);
	}
}

hook Combat_OnExecuted(playerid,executionerid)
{
	if (!Util_IsValidPlayer(executionerid) || executionerid == playerid)
	{
		return;
	}

	Traits_GiveRemorse(executionerid);

	new gain = Traits_Get(executionerid,TRAIT_EFFECT_FINISH_STAMINA);

	if (gain > 0)
	{
		new text[80];
		Vitals_SetStamina(executionerid,Vitals_GetStamina(executionerid) + float(gain));
		format(text,sizeof(text),"Finishing them off steadied you. You got %d stamina back.",gain);
		Gui_Notify(executionerid,text);
	}
}

hook Calendar_OnDawn()
{
	foreach (new playerid : Player)
	{
		Traits_ApplyTimeOfDay(playerid);
	}
}

hook Calendar_OnNightfall()
{
	foreach (new playerid : Player)
	{
		Traits_ApplyTimeOfDay(playerid);
	}
}
