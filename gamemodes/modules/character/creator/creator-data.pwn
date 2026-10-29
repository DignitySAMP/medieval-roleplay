#define CREATOR_AGE_MIN (16)
#define CREATOR_AGE_MAX (60)
#define CREATOR_ATTR_MIN (1)
#define CREATOR_ATTR_MAX (5)
#define CREATOR_ATTR_POOL (10)
#define CREATOR_ORIGIN_ROWS (3)
#define CREATOR_TRAIT_PICKS (2)
#define CREATOR_LABEL_LEN (28)
#define CREATOR_TEXT_LEN (128)

enum E_ATTRIBUTE
{
	ATTR_WILLPOWER,
	ATTR_CRAFTMANSHIP,
	ATTR_INTELLIGENCE,
	ATTR_HONOR_GRACE,
	ATTR_PIETY,
	ATTR_COUNT,
}

static const s_AttributeNames[E_ATTRIBUTE][CREATOR_LABEL_LEN] = {
	"Willpower", "Craftmanship", "Intelligence", "Honor and Grace", "Piety", ""
};

static const s_AttributeColours[E_ATTRIBUTE] = {
	0xB5543CFF, 0xB8844AFF, 0x6D8FB3FF, 0xD9A441FF, 0xC9C2B0FF, 0
};

enum E_ORIGIN
{
	ORIGIN_VILLAGE,
	ORIGIN_TOWN,
	ORIGIN_FOREST,
	ORIGIN_MONASTERY,
	ORIGIN_SOLDIER,
	ORIGIN_FOREIGNER,
	ORIGIN_COUNT,
}

enum E_ORIGIN_ROW
{
	E_ORIGIN_NAME[CREATOR_LABEL_LEN],
	E_ORIGIN_TEXT[CREATOR_TEXT_LEN],
	E_ATTRIBUTE:E_ORIGIN_BONUS,
	E_ORIGIN_COIN,
}

static const s_Origins[E_ORIGIN][E_ORIGIN_ROW] = {
	{"Village peasant", "You grew up working the fields. You get 1 extra Willpower and start with 20 pfennig.", ATTR_WILLPOWER, 20},
	{"Town burgher", "You grew up behind town walls, among traders and guilds. You get 1 extra Honor and Grace and start with 60 pfennig.", ATTR_HONOR_GRACE, 60},
	{"Forest folk", "You grew up in the woods, far from any village. You get 1 extra Craftmanship and start with 15 pfennig.", ATTR_CRAFTMANSHIP, 15},
	{"Monastery ward", "You were left at the abbey gate and taught to read and pray. You get 1 extra Piety and start with 10 pfennig.", ATTR_PIETY, 10},
	{"Soldier's child", "You followed the army from camp to camp. You get 1 extra Willpower and start with 30 pfennig.", ATTR_WILLPOWER, 30},
	{"Foreigner", "You come from beyond the mountains. You get 1 extra Intelligence and start with 40 pfennig.", ATTR_INTELLIGENCE, 40},
	{"", "", ATTR_WILLPOWER, 0}
};

enum E_TRAIT
{
	TRAIT_HARDY,
	TRAIT_DEVOUT,
	TRAIT_GLUTTON,
	TRAIT_THICK_SKINNED,
	TRAIT_SILVER_TONGUE,
	TRAIT_THIEFS_HANDS,
	TRAIT_EARLY_RISER,
	TRAIT_BRAWLER,
	TRAIT_FRUGAL,
	TRAIT_KEEN_EYE,
	TRAIT_SOFT_HEARTED,
	TRAIT_STUBBORN,
	TRAIT_BOOKISH,
	TRAIT_WANDERER,
	TRAIT_COLD_BLOODED,
	TRAIT_HEAVY_SLEEPER,
	TRAIT_COUNT,
}

enum E_TRAIT_ROW
{
	E_TRAIT_NAME[CREATOR_LABEL_LEN],
	E_TRAIT_TEXT[CREATOR_TEXT_LEN],
}

static const s_Traits[E_TRAIT][E_TRAIT_ROW] = {
	{"Hardy", "You get hungry slower but feel the cold sooner."},
	{"Devout", "Prayer and confession weigh more, sins weigh double."},
	{"Glutton", "Food fills you more, but you need it more often."},
	{"Thick-skinned", "Blows hurt less, warmth is harder to feel."},
	{"Silver tongue", "Better prices at any counter, worse standing with priests."},
	{"Thief's hands", "Quick fingers. Sin creeps in even when you behave."},
	{"Early riser", "Stamina returns faster by day, slower by night."},
	{"Brawler", "Harder swings, weaker blocks."},
	{"Frugal", "Coin lasts longer, meals fill less."},
	{"Keen eye", "You spot what others miss, and sleep badly for it."},
	{"Soft-hearted", "Helping others earns repute, hurting them costs you twice."},
	{"Stubborn", "Struck down, you last longer. Healing takes longer too."},
	{"Bookish", "Recipes and letters come easy, fieldwork wears you out."},
	{"Wanderer", "Travel costs less strength, home comforts mean less."},
	{"Cold-blooded", "Killing does not shake you. Neither does mercy."},
	{"Heavy sleeper", "Nights restore you fully, mornings are slow."},
	{"", ""}
};

enum E_LIFESTYLE
{
	LIFESTYLE_FARMHAND,
	LIFESTYLE_KITCHEN_HAND,
	LIFESTYLE_APPRENTICE,
	LIFESTYLE_NOVICE,
	LIFESTYLE_RECRUIT,
	LIFESTYLE_COUNT,
}

enum E_LIFESTYLE_ROW
{
	E_LIFESTYLE_NAME[CREATOR_LABEL_LEN],
	E_LIFESTYLE_TEXT[CREATOR_TEXT_LEN],
}

static const Float:s_LifestyleSpawns[E_LIFESTYLE][4] = {
	{597.7131, -3487.1489, 19.0691, 292.9802},
	{1037.6252, -2880.5337, 81.0030, 348.7503},
	{695.4445, -3211.9221, 23.7031, 320.9077},
	{714.5767, -3627.9961, 18.3047, 38.5884},
	{730.1012, -3192.3254, 23.7092, 334.3504},
	{0.0, 0.0, 0.0, 0.0}
};

static const s_Lifestyles[E_LIFESTYLE][E_LIFESTYLE_ROW] = {
	{"Farmhand", "You start out working on a farm."},
	{"Kitchen hand", "You start out working in a tavern kitchen."},
	{"Apprentice", "You start out as an apprentice at a craftsman's bench."},
	{"Novice", "You start out as a novice at the chapel."},
	{"Recruit", "You start out as a recruit in the guard."},
	{"", ""}
};

static const s_AgeChoices[] = {16, 18, 20, 25, 30, 35, 40, 45, 50, 55, 60};

stock Creator_AttributeName(E_ATTRIBUTE:attr,dest[],size = sizeof(dest))
{
	if (attr < ATTR_WILLPOWER || attr >= ATTR_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_AttributeNames[attr],size);
}

stock Creator_AttributeColour(E_ATTRIBUTE:attr)
{
	return (attr < ATTR_WILLPOWER || attr >= ATTR_COUNT) ? 0xD8CCB2FF : s_AttributeColours[attr];
}

stock Creator_OriginName(E_ORIGIN:origin,dest[],size = sizeof(dest))
{
	if (origin < ORIGIN_VILLAGE || origin >= ORIGIN_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Origins[origin][E_ORIGIN_NAME],size);
}

stock Creator_OriginText(E_ORIGIN:origin,dest[],size = sizeof(dest))
{
	strcopy(dest,s_Origins[origin][E_ORIGIN_TEXT],size);
}

stock E_ATTRIBUTE:Creator_OriginBonus(E_ORIGIN:origin)
{
	if (origin < ORIGIN_VILLAGE || origin >= ORIGIN_COUNT)
	{
		return ATTR_WILLPOWER;
	}

	return s_Origins[origin][E_ORIGIN_BONUS];
}

stock Creator_OriginCoin(E_ORIGIN:origin)
{
	if (origin < ORIGIN_VILLAGE || origin >= ORIGIN_COUNT)
	{
		return 0;
	}

	return s_Origins[origin][E_ORIGIN_COIN];
}

stock Creator_TraitName(E_TRAIT:trait,dest[],size = sizeof(dest))
{
	if (trait < TRAIT_HARDY || trait >= TRAIT_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Traits[trait][E_TRAIT_NAME],size);
}

stock Creator_TraitText(E_TRAIT:trait,dest[],size = sizeof(dest))
{
	strcopy(dest,s_Traits[trait][E_TRAIT_TEXT],size);
}

stock Creator_LifestyleName(E_LIFESTYLE:lifestyle,dest[],size = sizeof(dest))
{
	if (lifestyle < LIFESTYLE_FARMHAND || lifestyle >= LIFESTYLE_COUNT)
	{
		dest[0] = EOS;
		return;
	}

	strcopy(dest,s_Lifestyles[lifestyle][E_LIFESTYLE_NAME],size);
}

stock Creator_LifestyleText(E_LIFESTYLE:lifestyle,dest[],size = sizeof(dest))
{
	strcopy(dest,s_Lifestyles[lifestyle][E_LIFESTYLE_TEXT],size);
}

stock Creator_GetLifestyleSpawn(E_LIFESTYLE:lifestyle,&Float:x,&Float:y,&Float:z,&Float:angle)
{
	if (lifestyle < LIFESTYLE_FARMHAND || lifestyle >= LIFESTYLE_COUNT)
	{
		lifestyle = LIFESTYLE_FARMHAND;
	}

	x = s_LifestyleSpawns[lifestyle][0];
	y = s_LifestyleSpawns[lifestyle][1];
	z = s_LifestyleSpawns[lifestyle][2];
	angle = s_LifestyleSpawns[lifestyle][3];
}

stock Creator_LifeClockAt(age,willpower)
{
	new clock = 1;

	if (age < 30)
	{
		clock = 5;
	}
	else if (age < 45)
	{
		clock = 4;
	}
	else if (age < 55)
	{
		clock = 3;
	}
	else if (age < 65)
	{
		clock = 2;
	}

	return willpower >= 5 ? clock + 1 : clock;
}

stock Creator_AgeChoiceCount()
{
	return sizeof(s_AgeChoices);
}

stock Creator_AgeChoice(index)
{
	if (index < 0 || index >= sizeof(s_AgeChoices))
	{
		return CREATOR_AGE_MIN;
	}

	return s_AgeChoices[index];
}

stock bool:Creator_ValidAttributes(const values[E_ATTRIBUTE])
{
	new total = 0;
	for (new E_ATTRIBUTE:a = ATTR_WILLPOWER; a < ATTR_COUNT; a++)
	{
		if (values[a] < CREATOR_ATTR_MIN || values[a] > CREATOR_ATTR_MAX)
		{
			return false;
		}

		total += values[a];
	}

	return total == CREATOR_ATTR_POOL;
}
