enum E_WOUND
{
	E_WOUND_PART,
	E_WOUND_KIND,
	E_WOUND_SEVERITY,
	E_WOUND_FLAGS,
	Float:E_WOUND_BLEED,
	E_WOUND_HEAL_LEFT,
}

static s_Wounds[MAX_PLAYERS][WOUND_MAX][E_WOUND];
static s_WoundCount[MAX_PLAYERS];
static bool:s_WoundsLoaded[MAX_PLAYERS];
static bool:s_WoundsWasBleeding[MAX_PLAYERS];
static s_WoundsLastSwing[MAX_PLAYERS];
static s_WoundsFesterTick[MAX_PLAYERS];
static s_WoundsHealBonus[MAX_PLAYERS];
static s_WoundsRestBonus[MAX_PLAYERS];

stock bool:Wounds_IsLoaded(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WoundsLoaded[playerid];
}

stock Wounds_Count(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_WoundCount[playerid] : 0;
}

stock bool:Wounds_GetAt(playerid,index,&part,&kind,&severity,&flags,&Float:bleed)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_WoundCount[playerid])
	{
		return false;
	}

	part = s_Wounds[playerid][index][E_WOUND_PART];
	kind = s_Wounds[playerid][index][E_WOUND_KIND];
	severity = s_Wounds[playerid][index][E_WOUND_SEVERITY];
	flags = s_Wounds[playerid][index][E_WOUND_FLAGS];
	bleed = s_Wounds[playerid][index][E_WOUND_BLEED];
	return true;
}

stock Wounds_GetHealLeft(playerid,index)
{
	return Util_IsValidPlayer(playerid) && index >= 0 && index < s_WoundCount[playerid] ? s_Wounds[playerid][index][E_WOUND_HEAL_LEFT] : 0;
}

stock Float:Wounds_GetBleedRate(playerid)
{
	new Float:total = 0.0;

	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_WoundCount[playerid];i++)
	{
		total += s_Wounds[playerid][i][E_WOUND_BLEED];
	}

	return total > WOUND_BLEED_CAP ? WOUND_BLEED_CAP : total;
}

stock bool:Wounds_IsBleeding(playerid)
{
	return Wounds_GetBleedRate(playerid) > 0.0;
}

stock Wounds_Find(playerid,part,kind)
{
	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_PART] == part && s_Wounds[playerid][i][E_WOUND_KIND] == kind)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Wounds_HasBroken(playerid,part,bool:isUnsplintedOnly = false)
{
	new index = Wounds_Find(playerid,part,WOUND_BROKEN);
	return index != -1 && (!isUnsplintedOnly || !(s_Wounds[playerid][index][E_WOUND_FLAGS] & WOUND_FLAG_SPLINTED));
}

stock bool:Wounds_HasUnsplintedLeg(playerid)
{
	return Wounds_HasBroken(playerid,WOUND_PART_LEFT_LEG,true) || Wounds_HasBroken(playerid,WOUND_PART_RIGHT_LEG,true);
}

stock Wounds_FindForTreatment(playerid,treatment)
{
	new best = -1;

	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_WoundCount[playerid];i++)
	{
		new kind = s_Wounds[playerid][i][E_WOUND_KIND], flags = s_Wounds[playerid][i][E_WOUND_FLAGS];

		if (treatment == WOUND_TREAT_SPLINT)
		{
			if (kind != WOUND_BROKEN || (flags & WOUND_FLAG_SPLINTED))
			{
				continue;
			}

			if (best == -1 || s_Wounds[playerid][i][E_WOUND_SEVERITY] > s_Wounds[playerid][best][E_WOUND_SEVERITY])
			{
				best = i;
			}

			continue;
		}

		if (treatment == WOUND_TREAT_CLEAN || treatment == WOUND_TREAT_STITCH || treatment == WOUND_TREAT_SET || treatment == WOUND_TREAT_LANCE)
		{
			if (Wounds_Needs(kind,s_Wounds[playerid][i][E_WOUND_SEVERITY],flags,treatment) && (best == -1 || s_Wounds[playerid][i][E_WOUND_SEVERITY] > s_Wounds[playerid][best][E_WOUND_SEVERITY] || (s_Wounds[playerid][i][E_WOUND_SEVERITY] == s_Wounds[playerid][best][E_WOUND_SEVERITY] && s_Wounds[playerid][i][E_WOUND_BLEED] > s_Wounds[playerid][best][E_WOUND_BLEED])))
			{
				best = i;
			}

			continue;
		}

		if (!Wounds_KindBleeds(kind) || (flags & WOUND_FLAG_BANDAGED))
		{
			continue;
		}

		if (best == -1 || s_Wounds[playerid][i][E_WOUND_BLEED] > s_Wounds[playerid][best][E_WOUND_BLEED] || (s_Wounds[playerid][i][E_WOUND_BLEED] == s_Wounds[playerid][best][E_WOUND_BLEED] && s_Wounds[playerid][i][E_WOUND_SEVERITY] > s_Wounds[playerid][best][E_WOUND_SEVERITY]))
		{
			best = i;
		}
	}

	return best;
}

static Wounds_Persist(playerid,index)
{
	if (Character_GetId(playerid) <= 0)
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO character_wounds (character_id, part, kind, severity, flags, bleed, heal_left) VALUES (%d, %d, %d, %d, %d, %f, %d)",Character_GetId(playerid),s_Wounds[playerid][index][E_WOUND_PART],s_Wounds[playerid][index][E_WOUND_KIND],s_Wounds[playerid][index][E_WOUND_SEVERITY],s_Wounds[playerid][index][E_WOUND_FLAGS],s_Wounds[playerid][index][E_WOUND_BLEED],s_Wounds[playerid][index][E_WOUND_HEAL_LEFT]));
}

static Wounds_PersistAll(playerid)
{
	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		Wounds_Persist(playerid,i);
	}
}

static Wounds_Erase(playerid,index)
{
	if (Character_GetId(playerid) > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("DELETE FROM character_wounds WHERE character_id = %d AND part = %d AND kind = %d",Character_GetId(playerid),s_Wounds[playerid][index][E_WOUND_PART],s_Wounds[playerid][index][E_WOUND_KIND]));
	}

	s_WoundCount[playerid]--;

	if (index != s_WoundCount[playerid])
	{
		s_Wounds[playerid][index] = s_Wounds[playerid][s_WoundCount[playerid]];
	}
}

static Wounds_RefreshCue(playerid)
{
	new cue[NAMETAG_CUE_LEN], worst = -1;

	if (Wounds_HasUnsplintedLeg(playerid))
	{
		strcopy(cue,"limps");
	}

	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_BLEED] > 0.0 && (worst == -1 || s_Wounds[playerid][i][E_WOUND_BLEED] > s_Wounds[playerid][worst][E_WOUND_BLEED]))
		{
			worst = i;
		}
	}

	if (worst != -1)
	{
		new part[12];
		Wounds_CuePartName(s_Wounds[playerid][worst][E_WOUND_PART],part);
		format(cue,sizeof(cue),"%s%sbleeds from the %s",cue,cue[0] != EOS ? (", ") : (""),part);
	}

	Nametag_SetCue(playerid,NAMETAG_CUE_WOUND,cue);
}

static Wounds_Apply(playerid)
{
	new worst = 0, torso = 0, bool:isBroken = Wounds_HasBroken(playerid,WOUND_PART_RIGHT_ARM,true);

	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_PART] == WOUND_PART_RIGHT_ARM && s_Wounds[playerid][i][E_WOUND_SEVERITY] > worst)
		{
			worst = s_Wounds[playerid][i][E_WOUND_SEVERITY];
		}

		if (s_Wounds[playerid][i][E_WOUND_PART] == WOUND_PART_TORSO && s_Wounds[playerid][i][E_WOUND_SEVERITY] > torso)
		{
			torso = s_Wounds[playerid][i][E_WOUND_SEVERITY];
		}
	}

	Combat_SetStrikeFactor(playerid,Wounds_StrikeFactorFor(worst,isBroken));
	Combat_SetBlockBarred(playerid,Wounds_HasBroken(playerid,WOUND_PART_LEFT_ARM,true));
	Vitals_SetStaminaWoundCap(playerid,Wounds_TorsoStaminaCapFor(torso));
	Wounds_SetLame(playerid,Wounds_HasUnsplintedLeg(playerid));
	Wounds_RefreshCue(playerid);

	if (Wounds_HasUnsplintedLeg(playerid) && Mount_IsRiding(playerid))
	{
		Mount_Dismount(playerid);
		Gui_Notify(playerid,"Your broken leg won't hold you in the saddle.");
	}
}

static Wounds_UpdateBleeding(playerid)
{
	new bool:isBleeding = Wounds_IsBleeding(playerid);

	if (isBleeding)
	{
		Injury_StartBleeding(playerid);
	}
	else if (s_WoundsWasBleeding[playerid])
	{
		Injury_StopBleeding(playerid);
	}

	s_WoundsWasBleeding[playerid] = isBleeding;
	Wounds_RefreshCue(playerid);
}

stock Wounds_Inflict(playerid,part,kind,severity,const source[] = "")
{
	if (!Util_IsValidPlayer(playerid) || !s_WoundsLoaded[playerid] || !Wounds_IsValidPart(part) || !Wounds_IsValidKind(kind))
	{
		return -1;
	}

	severity = clamp(severity,WOUND_GRAZE,WOUND_GRAVE);
	new index = Wounds_Find(playerid,part,kind);

	if (index != -1)
	{
		new existing = s_Wounds[playerid][index][E_WOUND_SEVERITY];
		severity = severity >= existing ? min(existing + 1,WOUND_GRAVE) : existing;
		s_Wounds[playerid][index][E_WOUND_FLAGS] &= ~(WOUND_FLAG_BANDAGED | WOUND_FLAG_CLEANED);
	}
	else
	{
		if (s_WoundCount[playerid] >= WOUND_MAX)
		{
			return -1;
		}

		index = s_WoundCount[playerid]++;
		s_Wounds[playerid][index][E_WOUND_PART] = part;
		s_Wounds[playerid][index][E_WOUND_KIND] = kind;
		s_Wounds[playerid][index][E_WOUND_FLAGS] = 0;
		s_Wounds[playerid][index][E_WOUND_BLEED] = 0.0;
	}

	s_Wounds[playerid][index][E_WOUND_SEVERITY] = severity;
	s_Wounds[playerid][index][E_WOUND_HEAL_LEFT] = Traits_Scale(playerid,TRAIT_EFFECT_HEALING,Wounds_HealSecondsFor(severity));

	if (Wounds_BleedFor(kind,severity) > s_Wounds[playerid][index][E_WOUND_BLEED])
	{
		s_Wounds[playerid][index][E_WOUND_BLEED] = Wounds_BleedFor(kind,severity);
	}

	Wounds_Persist(playerid,index);
	Wounds_Apply(playerid);
	Wounds_UpdateBleeding(playerid);

	if (severity == WOUND_GRAVE)
	{
		Wounds_Sway(playerid);
	}

	new text[64], partName[12], wound[WOUND_NAME_LEN];
	Wounds_PartName(part,partName);
	Wounds_Describe(kind,severity,wound);
	format(text,sizeof(text),"%s: %s.",partName,wound);
	Gui_Notify(playerid,text);
	pawn_call_public("Wounds_OnWounded","dddds",playerid,part,kind,severity,source);
	return index;
}

stock bool:Wounds_Treat(playerid,index,treatment)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_WoundCount[playerid])
	{
		return false;
	}

	if (treatment == WOUND_TREAT_SPLINT)
	{
		if (s_Wounds[playerid][index][E_WOUND_KIND] != WOUND_BROKEN || (s_Wounds[playerid][index][E_WOUND_FLAGS] & WOUND_FLAG_SPLINTED))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_SPLINTED;
	}
	else if (treatment == WOUND_TREAT_CLEAN)
	{
		if (!Wounds_CanBeCleaned(s_Wounds[playerid][index][E_WOUND_KIND],s_Wounds[playerid][index][E_WOUND_SEVERITY],s_Wounds[playerid][index][E_WOUND_FLAGS]))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_CLEANED;
	}
	else if (treatment == WOUND_TREAT_STITCH)
	{
		if (!Wounds_CanBeStitched(s_Wounds[playerid][index][E_WOUND_KIND],s_Wounds[playerid][index][E_WOUND_SEVERITY],s_Wounds[playerid][index][E_WOUND_FLAGS]))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_STITCHED | WOUND_FLAG_BANDAGED | WOUND_FLAG_CLEANED;
		s_Wounds[playerid][index][E_WOUND_BLEED] = 0.0;
		s_Wounds[playerid][index][E_WOUND_HEAL_LEFT] /= WOUND_MENDED_HEAL_DIVISOR;
	}
	else if (treatment == WOUND_TREAT_SET)
	{
		if (!Wounds_CanBeSet(s_Wounds[playerid][index][E_WOUND_KIND],s_Wounds[playerid][index][E_WOUND_FLAGS]))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_SET | WOUND_FLAG_SPLINTED;
		s_Wounds[playerid][index][E_WOUND_HEAL_LEFT] /= WOUND_MENDED_HEAL_DIVISOR;
	}
	else if (treatment == WOUND_TREAT_LANCE)
	{
		if (!Wounds_CanBeLanced(s_Wounds[playerid][index][E_WOUND_FLAGS]))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] &= ~WOUND_FLAG_FESTERING;
		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_CLEANED;
	}
	else
	{
		if (!Wounds_KindBleeds(s_Wounds[playerid][index][E_WOUND_KIND]) || (s_Wounds[playerid][index][E_WOUND_FLAGS] & WOUND_FLAG_BANDAGED))
		{
			return false;
		}

		s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_BANDAGED;
		s_Wounds[playerid][index][E_WOUND_BLEED] = 0.0;
	}

	Wounds_Persist(playerid,index);
	Wounds_Apply(playerid);
	Wounds_UpdateBleeding(playerid);
	pawn_call_public("Wounds_OnTreated","ddd",playerid,s_Wounds[playerid][index][E_WOUND_PART],treatment);
	return true;
}

stock Wounds_Clear(playerid,bool:isLeavingMarks = true)
{
	if (!Util_IsValidPlayer(playerid))
	{
		return;
	}

	while (s_WoundCount[playerid] > 0)
	{
		new index = s_WoundCount[playerid] - 1;

		if (isLeavingMarks)
		{
			Wounds_LeaveMark(playerid,index);
		}

		Wounds_Erase(playerid,index);
	}

	Wounds_Apply(playerid);
	Wounds_UpdateBleeding(playerid);
}

static Wounds_LeaveMark(playerid,index)
{
	new kind = s_Wounds[playerid][index][E_WOUND_KIND];

	if (Wounds_KindBleeds(kind) && s_Wounds[playerid][index][E_WOUND_SEVERITY] == WOUND_GRAVE)
	{
		Ailment_GiveMark(playerid,MARK_SCAR);
	}
	else if (kind == WOUND_BROKEN && !(s_Wounds[playerid][index][E_WOUND_FLAGS] & WOUND_FLAG_SPLINTED))
	{
		Ailment_GiveMark(playerid,MARK_CROOKED_LIMB);
	}
}

stock Wounds_Sway(playerid)
{
	if (GetPlayerDrunkLevel(playerid) < WOUND_SWAY_LEVEL)
	{
		SetPlayerDrunkLevel(playerid,WOUND_SWAY_LEVEL);
	}
}

static Wounds_TickBleeding(playerid)
{
	new Float:rate = Wounds_GetBleedRate(playerid);

	if (rate <= 0.0)
	{
		return;
	}

	if (random(100) < WOUND_BLEED_CHANCE)
	{
		Vitals_Damage(playerid,rate,"bleeding");
	}

	new bleeding = 0, Float:health = Vitals_GetHealth(playerid);

	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_BLEED] > 0.0)
		{
			bleeding++;
		}
	}

	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		new Float:bleed = s_Wounds[playerid][i][E_WOUND_BLEED];

		if (bleed <= 0.0 || random(100) >= WOUND_DECAY_CHANCE)
		{
			continue;
		}

		bleed -= (((VITALS_MAX - health) / WOUND_DECAY_HEALTH_DIVISOR) * bleed) / float(bleeding) / 100.0 + Wounds_BleedFloorFor(s_Wounds[playerid][i][E_WOUND_SEVERITY]);
		s_Wounds[playerid][i][E_WOUND_BLEED] = bleed > 0.0 ? bleed : 0.0;
	}

	if (!Wounds_IsBleeding(playerid))
	{
		Wounds_PersistAll(playerid);
		Gui_Notify(playerid,"The bleeding has stopped.");
		Wounds_UpdateBleeding(playerid);
		return;
	}

	Wounds_UpdateBleeding(playerid);
}

static Wounds_TickHealing(playerid)
{
	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_BLEED] > 0.0 || (s_Wounds[playerid][i][E_WOUND_FLAGS] & WOUND_FLAG_FESTERING))
		{
			continue;
		}

		if (s_WoundsHealBonus[playerid] > 0 && random(100) < s_WoundsHealBonus[playerid])
		{
			s_Wounds[playerid][i][E_WOUND_HEAL_LEFT]--;
		}

		if (s_WoundsRestBonus[playerid] > 0 && random(100) < s_WoundsRestBonus[playerid])
		{
			s_Wounds[playerid][i][E_WOUND_HEAL_LEFT]--;
		}

		if (--s_Wounds[playerid][i][E_WOUND_HEAL_LEFT] > 0)
		{
			continue;
		}

		new part = s_Wounds[playerid][i][E_WOUND_PART], kind = s_Wounds[playerid][i][E_WOUND_KIND], partName[12], text[64];
		Wounds_LeaveMark(playerid,i);
		Wounds_Erase(playerid,i);
		Wounds_PartName(part,partName);
		partName[0] = tolower(partName[0]);
		format(text,sizeof(text),"Your %s has healed.",partName);
		Gui_Notify(playerid,text);
		pawn_call_public("Wounds_OnHealed","ddd",playerid,part,kind);
		Wounds_Apply(playerid);
		i--;
	}
}

stock bool:Wounds_Fester(playerid,index)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_WoundCount[playerid] || (s_Wounds[playerid][index][E_WOUND_FLAGS] & WOUND_FLAG_FESTERING))
	{
		return false;
	}

	s_Wounds[playerid][index][E_WOUND_FLAGS] |= WOUND_FLAG_FESTERING;
	Wounds_Persist(playerid,index);
	Ailment_Give(playerid,AILMENT_GANGRENE,"festering wound");
	pawn_call_public("Wounds_OnFestered","dd",playerid,s_Wounds[playerid][index][E_WOUND_PART]);
	return true;
}

static Wounds_TickFestering(playerid)
{
	for (new i = 0;i < s_WoundCount[playerid];i++)
	{
		new kind = s_Wounds[playerid][i][E_WOUND_KIND], flags = s_Wounds[playerid][i][E_WOUND_FLAGS];

		if (!Wounds_KindBleeds(kind) || s_Wounds[playerid][i][E_WOUND_SEVERITY] < WOUND_OPEN || (flags & WOUND_FLAG_FESTERING))
		{
			continue;
		}

		if (random(((flags & WOUND_FLAG_BANDAGED) ? WOUND_FESTER_ODDS_BANDAGED : WOUND_FESTER_ODDS_OPEN) * ((flags & WOUND_FLAG_CLEANED) ? WOUND_FESTER_CLEAN_FACTOR : 1)) != 0)
		{
			continue;
		}

		Wounds_Fester(playerid,i);
	}

	Wounds_PersistAll(playerid);
}

stock Wounds_Tick(playerid)
{
	if (!s_WoundsLoaded[playerid] || s_WoundCount[playerid] == 0 || !Session_IsPlaying(playerid))
	{
		return;
	}

	Wounds_TickBleeding(playerid);
	Wounds_TickHealing(playerid);

	if (++s_WoundsFesterTick[playerid] >= WOUND_FESTER_SECONDS)
	{
		s_WoundsFesterTick[playerid] = 0;
		Wounds_TickFestering(playerid);
	}
}

stock Wounds_SetHealBonus(playerid,percent)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WoundsHealBonus[playerid] = Util_ClampInt(percent,0,100);
	}
}

stock Wounds_SetRestBonus(playerid,percent)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_WoundsRestBonus[playerid] = Util_ClampInt(percent,0,100);
	}
}

stock Wounds_GetRestBonus(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_WoundsRestBonus[playerid] : 0;
}

stock bool:Wounds_StopFestering(playerid)
{
	new bool:isChanged = false;

	for (new i = 0;Util_IsValidPlayer(playerid) && i < s_WoundCount[playerid];i++)
	{
		if (s_Wounds[playerid][i][E_WOUND_FLAGS] & WOUND_FLAG_FESTERING)
		{
			s_Wounds[playerid][i][E_WOUND_FLAGS] &= ~WOUND_FLAG_FESTERING;
			s_Wounds[playerid][i][E_WOUND_FLAGS] |= WOUND_FLAG_CLEANED;
			Wounds_Persist(playerid,i);
			isChanged = true;
		}
	}

	return isChanged;
}

stock Wounds_Advance(playerid,seconds)
{
	for (new i = 0;i < seconds;i++)
	{
		Wounds_TickHealing(playerid);
	}
}

Wounds_Reset(playerid)
{
	s_WoundCount[playerid] = 0;
	s_WoundsLoaded[playerid] = false;
	s_WoundsWasBleeding[playerid] = false;
	s_WoundsLastSwing[playerid] = 0;
	s_WoundsFesterTick[playerid] = 0;
	s_WoundsHealBonus[playerid] = 0;
	s_WoundsRestBonus[playerid] = 0;
}

static Wounds_Load(playerid,token)
{
	yield 1;

	new characterid = Character_GetId(playerid);
	await mysql_aquery_s(g_Mysql,str_format("SELECT part, kind, severity, flags, bleed, heal_left FROM character_wounds WHERE character_id = %d LIMIT %d",characterid,WOUND_MAX));

	if (!IsPlayerConnected(playerid) || Account_GetToken(playerid) != token || Character_GetId(playerid) != characterid)
	{
		return;
	}

	new rows = cache_num_rows();
	s_WoundCount[playerid] = 0;

	for (new r = 0;r < rows;r++)
	{
		new slot = s_WoundCount[playerid];
		cache_get_value_name_int(r,"part",s_Wounds[playerid][slot][E_WOUND_PART]);
		cache_get_value_name_int(r,"kind",s_Wounds[playerid][slot][E_WOUND_KIND]);
		cache_get_value_name_int(r,"severity",s_Wounds[playerid][slot][E_WOUND_SEVERITY]);
		cache_get_value_name_int(r,"flags",s_Wounds[playerid][slot][E_WOUND_FLAGS]);
		cache_get_value_name_float(r,"bleed",s_Wounds[playerid][slot][E_WOUND_BLEED]);
		cache_get_value_name_int(r,"heal_left",s_Wounds[playerid][slot][E_WOUND_HEAL_LEFT]);

		if (Wounds_IsValidPart(s_Wounds[playerid][slot][E_WOUND_PART]) && Wounds_IsValidKind(s_Wounds[playerid][slot][E_WOUND_KIND]))
		{
			s_WoundCount[playerid]++;
		}
	}

	s_WoundsLoaded[playerid] = true;
	Wounds_Apply(playerid);
	Wounds_UpdateBleeding(playerid);
}

forward Wounds_OnWounded(playerid,part,kind,severity,const source[]);

public Wounds_OnWounded(playerid,part,kind,severity,const source[])
{
	return 1;
}

forward Wounds_OnTreated(playerid,part,treatment);

public Wounds_OnTreated(playerid,part,treatment)
{
	return 1;
}

forward Wounds_OnHealed(playerid,part,kind);

public Wounds_OnHealed(playerid,part,kind)
{
	return 1;
}

forward Wounds_OnFestered(playerid,part);

public Wounds_OnFestered(playerid,part)
{
	return 1;
}

forward Wounds_LoadDeferred(playerid,token);

public Wounds_LoadDeferred(playerid,token)
{
	if (IsPlayerConnected(playerid) && Account_GetToken(playerid) == token)
	{
		Wounds_Load(playerid,token);
	}

	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	Wounds_Reset(playerid);
}

hook Character_OnLoaded(playerid,characterid)
{
	#pragma unused characterid

	Wounds_Reset(playerid);
	SetTimerEx("Wounds_LoadDeferred",0,false,"dd",playerid,Account_GetToken(playerid));
}

hook Character_OnUnloaded(playerid)
{
	if (s_WoundsLoaded[playerid])
	{
		Wounds_PersistAll(playerid);
	}

	Wounds_Reset(playerid);
}

hook Tick_OnPlayerSecond(playerid)
{
	Wounds_Tick(playerid);
}

hook Combat_OnSwing(playerid,anim)
{
	s_WoundsLastSwing[playerid] = anim;
}

hook Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	if (!Session_HasCharacter(targetid) || !s_WoundsLoaded[targetid])
	{
		return;
	}

	new part;

	if (Weapon_IsRanged(weapon))
	{
		part = Wounds_PartForArrow(damage / Weapon_GetRangedScale(weapon));
	}
	else
	{
		part = Wounds_PickPart(Util_IsValidPlayer(attackerid) ? s_WoundsLastSwing[attackerid] : 0,Util_IsValidPlayer(attackerid) && attackerid != targetid && Combat_IsBehind(attackerid,targetid));
	}

	new source[COMBAT_NAME_LEN];
	Weapon_GetName(weapon,source);

	if (source[0] == EOS)
	{
		strcopy(source,"fists");
	}

	Wounds_Inflict(targetid,part,Wounds_KindForWeapon(weapon,damage,part),Wounds_SeverityFor(damage),source);

	if (damage >= WOUND_SWAY_DAMAGE)
	{
		Wounds_Sway(targetid);
	}
}

hook Combat_OnBlocked(defenderid,attackerid,Float:damage)
{
	#pragma unused attackerid

	if (damage >= WOUND_BLOCK_BRUISE && s_WoundsLoaded[defenderid])
	{
		Wounds_Inflict(defenderid,WOUND_PART_LEFT_ARM,WOUND_BRUISE,WOUND_GRAZE,"a blocked blow");
	}
}

hook OnPlayerTakeDamage(playerid,issuerid,Float:amount,WEAPON:weaponid,bodypart)
{
	#pragma unused bodypart

	if (weaponid != WEAPON_COLLISION || issuerid != INVALID_PLAYER_ID || amount < WOUND_FALL_BRUISE || !s_WoundsLoaded[playerid] || !Session_IsPlaying(playerid) || Mount_IsRiding(playerid))
	{
		return;
	}

	new part = random(2) ? WOUND_PART_LEFT_LEG : WOUND_PART_RIGHT_LEG;

	if (amount >= WOUND_FALL_BREAK)
	{
		Wounds_Inflict(playerid,part,WOUND_BROKEN,WOUND_OPEN,"a fall");
		return;
	}

	Wounds_Inflict(playerid,part,WOUND_BRUISE,amount >= WOUND_FALL_HEAVY ? WOUND_OPEN : WOUND_GRAZE,"a fall");
}

hook Vitals_OnDepleted(playerid,const source[])
{
	#pragma unused source

	Wounds_Clear(playerid,true);
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	#pragma unused killerid, reason

	if (s_WoundsLoaded[playerid] && s_WoundCount[playerid] > 0)
	{
		Wounds_Clear(playerid,true);
	}
}

hook Ailment_OnCured(playerid,ailment,const source[])
{
	#pragma unused source

	if (ailment == AILMENT_GANGRENE && s_WoundsLoaded[playerid])
	{
		Wounds_StopFestering(playerid);
	}
}

hook Mount_OnMounted(playerid,horseid)
{
	#pragma unused horseid

	if (Wounds_HasUnsplintedLeg(playerid))
	{
		Mount_Dismount(playerid);
		Gui_Notify(playerid,"Your broken leg won't hold you in the saddle. Splint it first.");
	}
}
