#define WOUND_MAX (12)
#define WOUND_NAME_LEN (24)
#define WOUND_BLEED_CAP (0.5)
#define WOUND_BLEED_CHANCE (70)
#define WOUND_DECAY_CHANCE (50)
#define WOUND_DECAY_HEALTH_DIVISOR (360.0)
#define WOUND_FESTER_SECONDS (60)
#define WOUND_FESTER_ODDS_OPEN (60)
#define WOUND_FESTER_ODDS_BANDAGED (300)
#define WOUND_SWAY_DAMAGE (10.0)
#define WOUND_SWAY_LEVEL (2400)
#define WOUND_TREAT_RANGE (2.0)
#define WOUND_FALL_BRUISE (15.0)
#define WOUND_FALL_HEAVY (25.0)
#define WOUND_FALL_BREAK (40.0)
#define WOUND_HEAVY_BLUNT (9.0)
#define WOUND_BLOCK_BRUISE (8.0)
#define WOUND_POOL_MODEL (19836)
#define WOUND_POOL_SPLASHES (2)
#define WOUND_POOL_MS (60000)
#define WOUND_POOL_SPREAD (0.45)
#define WOUND_POOL_LIFT (0.03)
#define WOUND_POOL_RAY (1.5)
#define WOUND_BLOOD_STREAM (60.0)
#define WOUND_ARROW_HEAD_DAMAGE (25.0)
#define WOUND_ARROW_TORSO_DAMAGE (15.0)
#define WOUND_FESTER_CLEAN_FACTOR (3)
#define WOUND_LIMP_LIB "PED"
#define WOUND_LIMP_ANIM "WALK_OLD"
#define WOUND_STUMBLE_FIRST_MS (1000)
#define WOUND_STUMBLE_EVERY_MS (800)
#define WOUND_STUMBLE_MAX (3)
#define WOUND_FALL_DOWN_MS (1000)

enum
{
	WOUND_PART_HEAD,
	WOUND_PART_TORSO,
	WOUND_PART_LEFT_ARM,
	WOUND_PART_RIGHT_ARM,
	WOUND_PART_LEFT_LEG,
	WOUND_PART_RIGHT_LEG,
	WOUND_PART_COUNT,
}

enum
{
	WOUND_CUT,
	WOUND_STAB,
	WOUND_BRUISE,
	WOUND_BROKEN,
	WOUND_KIND_COUNT,
}

#define WOUND_GRAZE (1)
#define WOUND_OPEN (2)
#define WOUND_GRAVE (3)

#define WOUND_FLAG_BANDAGED (1)
#define WOUND_FLAG_SPLINTED (2)
#define WOUND_FLAG_FESTERING (4)
#define WOUND_FLAG_CLEANED (8)
#define WOUND_FLAG_STITCHED (16)
#define WOUND_FLAG_SET (32)
#define WOUND_MENDED_HEAL_DIVISOR (2)

enum
{
	WOUND_TREAT_BANDAGE,
	WOUND_TREAT_SPLINT,
	WOUND_TREAT_CLEAN,
	WOUND_TREAT_STITCH,
	WOUND_TREAT_SET,
	WOUND_TREAT_LANCE,
}

static const s_WoundPartNames[WOUND_PART_COUNT][12] = {"Head", "Torso", "Left arm", "Right arm", "Left leg", "Right leg"};
static const s_WoundCueParts[WOUND_PART_COUNT][12] = {"head", "chest", "left arm", "right arm", "left leg", "right leg"};
static const s_WoundTorsoStamina[4] = {0, 10, 25, 40};
static const s_WoundCleaners[] = {ITEM_WATER_SKIN, ITEM_ALE, ITEM_BEER, ITEM_MEAD};

static const s_WoundKindNames[WOUND_KIND_COUNT][3][WOUND_NAME_LEN] = {
	{"graze", "cut", "deep cut"},
	{"prick", "stab wound", "deep stab wound"},
	{"bruise", "heavy bruise", "battered"},
	{"cracked bone", "broken bone", "shattered bone"}
};

static const Float:s_WoundBleed[WOUND_KIND_COUNT][3] = {
	{0.04, 0.10, 0.20},
	{0.06, 0.14, 0.25},
	{0.0, 0.0, 0.0},
	{0.0, 0.0, 0.0}
};

static const Float:s_WoundBleedFloor[3] = {0.004, 0.0015, 0.0};

static const s_WoundHealSeconds[3] = {600, 3600, 14400};

static const s_WoundSwingOdds[4][WOUND_PART_COUNT] = {
	{45, 40, 7, 8, 0, 0},
	{0, 25, 2, 3, 35, 35},
	{10, 45, 0, 35, 5, 5},
	{10, 45, 35, 0, 5, 5}
};

static const s_WoundBehindOdds[WOUND_PART_COUNT] = {30, 70, 0, 0, 0, 0};

static const Float:s_WoundStrikeFactor[4] = {1.0, 0.95, 0.85, 0.7};
#define WOUND_STRIKE_BROKEN (0.5)

stock bool:Wounds_IsValidPart(part)
{
	return part >= WOUND_PART_HEAD && part < WOUND_PART_COUNT;
}

stock bool:Wounds_IsValidKind(kind)
{
	return kind >= WOUND_CUT && kind < WOUND_KIND_COUNT;
}

stock bool:Wounds_IsLimb(part)
{
	return part >= WOUND_PART_LEFT_ARM && part <= WOUND_PART_RIGHT_LEG;
}

stock bool:Wounds_IsLeg(part)
{
	return part == WOUND_PART_LEFT_LEG || part == WOUND_PART_RIGHT_LEG;
}

stock bool:Wounds_KindBleeds(kind)
{
	return kind == WOUND_CUT || kind == WOUND_STAB;
}

stock Wounds_PartName(part,dest[],size = sizeof(dest))
{
	if (!Wounds_IsValidPart(part))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_WoundPartNames[part],size);
}

stock Wounds_CuePartName(part,dest[],size = sizeof(dest))
{
	if (!Wounds_IsValidPart(part))
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_WoundCueParts[part],size);
}

stock Float:Wounds_TorsoStaminaCapFor(severity)
{
	return VITALS_MAX - float(s_WoundTorsoStamina[clamp(severity,0,WOUND_GRAVE)]);
}

stock bool:Wounds_CanBeCleaned(kind,severity,flags)
{
	return Wounds_KindBleeds(kind) && severity >= WOUND_OPEN && !(flags & (WOUND_FLAG_CLEANED | WOUND_FLAG_FESTERING));
}

stock bool:Wounds_CanBeStitched(kind,severity,flags)
{
	return Wounds_KindBleeds(kind) && severity >= WOUND_OPEN && !(flags & (WOUND_FLAG_STITCHED | WOUND_FLAG_FESTERING));
}

stock bool:Wounds_CanBeSet(kind,flags)
{
	return kind == WOUND_BROKEN && !(flags & WOUND_FLAG_SET);
}

stock bool:Wounds_CanBeLanced(flags)
{
	return (flags & WOUND_FLAG_FESTERING) != 0;
}

stock bool:Wounds_Needs(kind,severity,flags,treatment)
{
	switch (treatment)
	{
		case WOUND_TREAT_CLEAN:
		{
			return Wounds_CanBeCleaned(kind,severity,flags);
		}
		case WOUND_TREAT_STITCH:
		{
			return Wounds_CanBeStitched(kind,severity,flags);
		}
		case WOUND_TREAT_SET:
		{
			return Wounds_CanBeSet(kind,flags);
		}
		case WOUND_TREAT_LANCE:
		{
			return Wounds_CanBeLanced(flags);
		}
		case WOUND_TREAT_SPLINT:
		{
			return kind == WOUND_BROKEN && !(flags & WOUND_FLAG_SPLINTED);
		}
	}

	return Wounds_KindBleeds(kind) && !(flags & WOUND_FLAG_BANDAGED);
}

stock Wounds_CleanerCount()
{
	return sizeof(s_WoundCleaners);
}

stock Wounds_CleanerAt(index)
{
	return index >= 0 && index < sizeof(s_WoundCleaners) ? s_WoundCleaners[index] : -1;
}

stock Wounds_Describe(kind,severity,dest[],size = sizeof(dest))
{
	if (!Wounds_IsValidKind(kind) || severity < WOUND_GRAZE || severity > WOUND_GRAVE)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_WoundKindNames[kind][severity - 1],size);
}

stock Float:Wounds_BleedFor(kind,severity)
{
	return Wounds_IsValidKind(kind) && severity >= WOUND_GRAZE && severity <= WOUND_GRAVE ? s_WoundBleed[kind][severity - 1] : 0.0;
}

stock Float:Wounds_BleedFloorFor(severity)
{
	return severity >= WOUND_GRAZE && severity <= WOUND_GRAVE ? s_WoundBleedFloor[severity - 1] : 0.0;
}

stock Wounds_HealSecondsFor(severity)
{
	return severity >= WOUND_GRAZE && severity <= WOUND_GRAVE ? s_WoundHealSeconds[severity - 1] : s_WoundHealSeconds[0];
}

stock Float:Wounds_StrikeFactorFor(severity,bool:isBroken)
{
	if (isBroken)
	{
		return WOUND_STRIKE_BROKEN;
	}

	return severity >= 0 && severity <= WOUND_GRAVE ? s_WoundStrikeFactor[severity] : 1.0;
}

stock Wounds_SeverityFor(Float:damage)
{
	if (damage < 5.0)
	{
		return WOUND_GRAZE;
	}

	return damage < 10.0 ? WOUND_OPEN : WOUND_GRAVE;
}

static Wounds_RollOdds(const odds[WOUND_PART_COUNT])
{
	new total = 0;

	for (new part = 0;part < WOUND_PART_COUNT;part++)
	{
		total += odds[part];
	}

	new roll = random(total);

	for (new part = 0;part < WOUND_PART_COUNT;part++)
	{
		if (roll < odds[part])
		{
			return part;
		}

		roll -= odds[part];
	}

	return WOUND_PART_TORSO;
}

stock Wounds_PickPart(swing,bool:isFromBehind)
{
	if (isFromBehind)
	{
		return Wounds_RollOdds(s_WoundBehindOdds);
	}

	return Wounds_RollOdds(s_WoundSwingOdds[swing >= 0 && swing < 4 ? swing : 0]);
}

stock Wounds_PartForArrow(Float:damage)
{
	if (damage >= WOUND_ARROW_HEAD_DAMAGE)
	{
		return WOUND_PART_HEAD;
	}

	if (damage >= WOUND_ARROW_TORSO_DAMAGE)
	{
		return WOUND_PART_TORSO;
	}

	return WOUND_PART_LEFT_ARM + random(4);
}

stock Wounds_KindForWeapon(weapon,Float:damage,part)
{
	if (!Weapon_IsValid(weapon) || weapon == WEAPON_KNIFE_CLUB)
	{
		return WOUND_BRUISE;
	}

	switch (Weapon_GetType(weapon))
	{
		case WEAPON_TYPE_BLUNT:
		{
			return damage >= WOUND_HEAVY_BLUNT && Wounds_IsLimb(part) ? WOUND_BROKEN : WOUND_BRUISE;
		}
		case WEAPON_TYPE_DAGGER, WEAPON_TYPE_SPEAR, WEAPON_TYPE_BOW, WEAPON_TYPE_CROSSBOW:
		{
			return WOUND_STAB;
		}
		case WEAPON_TYPE_SLING:
		{
			return WOUND_BRUISE;
		}
	}

	return WOUND_CUT;
}
