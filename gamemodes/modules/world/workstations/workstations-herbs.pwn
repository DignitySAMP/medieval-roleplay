#define WORK_HERB_KEY_LEN (16)
#define WORK_HERB_NAME_LEN (24)
#define WORK_HERB_REVEAL_LEVEL (3)
#define WORK_HERB_WINTER_SHARE (25)
#define WORK_HERB_MOON_MIN (1)
#define WORK_HERB_MOON_MAX (3)
#define WORK_HERB_WOLF_MONTH (1)
#define WORK_HERB_WI (1 << _:SEASON_WINTER)
#define WORK_HERB_SP (1 << _:SEASON_SPRING)
#define WORK_HERB_SU (1 << _:SEASON_SUMMER)
#define WORK_HERB_AU (1 << _:SEASON_AUTUMN)
#define WORK_HERB_ALL_SEASONS (WORK_HERB_WI | WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU)
#define WORK_HERB_ALL_HABITATS (WORK_HABITAT_FOREST | WORK_HABITAT_EDGE | WORK_HABITAT_ROCK | WORK_HABITAT_WET | WORK_HABITAT_MEADOW | WORK_HABITAT_VILLAGE)

enum
{
	WORK_HERB_MOON_NONE,
	WORK_HERB_MOON_FULL,
	WORK_HERB_MOON_WOLF,
}

enum
{
	WORK_HERB_POOL_HERBS,
	WORK_HERB_POOL_MUSHROOMS,
}

enum
{
	WORK_HERB_YARROW,
	WORK_HERB_PLANTAIN,
	WORK_HERB_COMFREY,
	WORK_HERB_WILLOW,
	WORK_HERB_CHAMOMILE,
	WORK_HERB_STJOHNS,
	WORK_HERB_NIGHTSHADE,
	WORK_HERB_POPPY,
	WORK_HERB_MOONWORT,
	WORK_HERB_NETTLE,
	WORK_HERB_VALERIAN,
	WORK_HERB_MINT,
	WORK_HERB_WORMWOOD,
	WORK_HERB_MUGWORT,
	WORK_HERB_BETONY,
	WORK_HERB_AGRIMONY,
	WORK_HERB_ELDER,
	WORK_HERB_RAMSONS,
	WORK_HERB_HENBANE,
	WORK_HERB_HEMLOCK,
	WORK_HERB_FOXGLOVE,
	WORK_HERB_WOLFSBANE,
	WORK_HERB_CEP,
	WORK_HERB_DEATHCAP,
	WORK_HERB_WELD,
	WORK_HERB_WILDCARROT,
	WORK_HERB_MAYWEED,
	WORK_HERB_DWARFELDER,
	WORK_HERB_LILYVALLEY,
	WORK_HERB_AUTUMNCROCUS,
	WORK_HERB_BILBERRY,
	WORK_HERB_CHERRY,
	WORK_HERB_COWPARSLEY,
	WORK_HERB_FIELDMUSHROOM,
	WORK_HERB_COUNT,
}

enum E_WORK_HERB_DEF
{
	E_WORK_HERB_DEF_KEY[WORK_HERB_KEY_LEN],
	E_WORK_HERB_DEF_NAME[WORK_HERB_NAME_LEN],
	E_WORK_HERB_DEF_HABITAT,
	E_WORK_HERB_DEF_SEASONS,
	E_WORK_HERB_DEF_MOON,
	E_WORK_HERB_DEF_WEIGHT,
	E_WORK_HERB_DEF_ITEM,
	E_WORK_HERB_DEF_YIELD,
	E_WORK_HERB_DEF_SEEN_AS,
	E_WORK_HERB_DEF_POOL,
	bool:E_WORK_HERB_DEF_IS_REMEDY,
}

static const s_WorkHerbDefs[WORK_HERB_COUNT][E_WORK_HERB_DEF] = {
	{"yarrow", "Yarrow", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 12, ITEM_YARROW, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"plantain", "Ribwort plantain", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE, WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 12, ITEM_PLANTAIN, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"comfrey", "Comfrey", WORK_HABITAT_WET | WORK_HABITAT_EDGE, WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 6, ITEM_COMFREY, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"willow", "Willow", WORK_HABITAT_WET, WORK_HERB_ALL_SEASONS, WORK_HERB_MOON_NONE, 6, ITEM_WILLOW_BARK, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"chamomile", "Chamomile", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 8, ITEM_CHAMOMILE, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"stjohns", "St John's wort", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 6, ITEM_ST_JOHNS_WORT, 2, -1, WORK_HERB_POOL_HERBS, true},
	{"nightshade", "Deadly nightshade", WORK_HABITAT_FOREST | WORK_HABITAT_EDGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 2, ITEM_NIGHTSHADE, 2, WORK_HERB_BILBERRY, WORK_HERB_POOL_HERBS, false},
	{"poppy", "Poppy", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 3, ITEM_POPPY, 2, -1, WORK_HERB_POOL_HERBS, false},
	{"moonwort", "Moonwort", WORK_HABITAT_MEADOW | WORK_HABITAT_FOREST, WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_FULL, 1, ITEM_HERBS_RARE, 1, -1, WORK_HERB_POOL_HERBS, false},
	{"nettle", "Stinging nettle", WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE | WORK_HABITAT_FOREST, WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 10, ITEM_NETTLE, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"valerian", "Valerian", WORK_HABITAT_WET | WORK_HABITAT_EDGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 4, ITEM_VALERIAN, 2, -1, WORK_HERB_POOL_HERBS, true},
	{"mint", "Water mint", WORK_HABITAT_WET, WORK_HERB_SU, WORK_HERB_MOON_NONE, 5, ITEM_MINT, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"wormwood", "Wormwood", WORK_HABITAT_ROCK | WORK_HABITAT_EDGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 4, ITEM_WORMWOOD, 2, -1, WORK_HERB_POOL_HERBS, true},
	{"mugwort", "Mugwort", WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 6, ITEM_MUGWORT, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"betony", "Betony", WORK_HABITAT_FOREST | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 4, ITEM_BETONY, 2, -1, WORK_HERB_POOL_HERBS, true},
	{"agrimony", "Agrimony", WORK_HABITAT_EDGE | WORK_HABITAT_MEADOW, WORK_HERB_SU, WORK_HERB_MOON_NONE, 4, ITEM_AGRIMONY, 2, -1, WORK_HERB_POOL_HERBS, true},
	{"elder", "Elder", WORK_HABITAT_EDGE | WORK_HABITAT_FOREST, WORK_HERB_SP | WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 5, ITEM_ELDER, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"ramsons", "Wild garlic", WORK_HABITAT_FOREST, WORK_HERB_SP, WORK_HERB_MOON_NONE, 6, ITEM_RAMSONS, 3, -1, WORK_HERB_POOL_HERBS, true},
	{"henbane", "Henbane", WORK_HABITAT_VILLAGE | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 2, ITEM_HENBANE, 2, -1, WORK_HERB_POOL_HERBS, false},
	{"hemlock", "Hemlock", WORK_HABITAT_WET | WORK_HABITAT_EDGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 2, ITEM_HEMLOCK, 2, WORK_HERB_YARROW, WORK_HERB_POOL_HERBS, false},
	{"foxglove", "Foxglove", WORK_HABITAT_FOREST, WORK_HERB_SU, WORK_HERB_MOON_NONE, 2, ITEM_FOXGLOVE, 2, WORK_HERB_COMFREY, WORK_HERB_POOL_HERBS, false},
	{"wolfsbane", "Wolfsbane", WORK_HABITAT_ROCK | WORK_HABITAT_WET, WORK_HERB_WI, WORK_HERB_MOON_WOLF, 1, ITEM_WOLFSBANE, 1, -1, WORK_HERB_POOL_HERBS, false},
	{"cep", "Ceps", WORK_HABITAT_FOREST, WORK_HERB_AU, WORK_HERB_MOON_NONE, 6, ITEM_CEP, 3, -1, WORK_HERB_POOL_MUSHROOMS, false},
	{"deathcap", "Death caps", WORK_HABITAT_FOREST, WORK_HERB_AU, WORK_HERB_MOON_NONE, 3, ITEM_DEATH_CAP, 2, WORK_HERB_CEP, WORK_HERB_POOL_MUSHROOMS, false},
	{"weld", "Dyer's weld", WORK_HABITAT_MEADOW | WORK_HABITAT_ROCK, WORK_HERB_SU, WORK_HERB_MOON_NONE, 3, ITEM_DYE_PLANT, 2, -1, WORK_HERB_POOL_HERBS, false},
	{"wildcarrot", "Wild carrot", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 4, ITEM_WILD_CARROT, 3, WORK_HERB_YARROW, WORK_HERB_POOL_HERBS, false},
	{"mayweed", "Mayweed", WORK_HABITAT_MEADOW | WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE, WORK_HERB_SU, WORK_HERB_MOON_NONE, 4, ITEM_MAYWEED, 3, WORK_HERB_CHAMOMILE, WORK_HERB_POOL_HERBS, false},
	{"dwarfelder", "Dwarf elder", WORK_HABITAT_EDGE | WORK_HABITAT_VILLAGE, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 3, ITEM_DWARF_ELDER, 3, WORK_HERB_ELDER, WORK_HERB_POOL_HERBS, false},
	{"lilyvalley", "Lily of the valley", WORK_HABITAT_FOREST, WORK_HERB_SP, WORK_HERB_MOON_NONE, 3, ITEM_LILY_OF_THE_VALLEY, 2, WORK_HERB_RAMSONS, WORK_HERB_POOL_HERBS, false},
	{"autumncrocus", "Autumn crocus", WORK_HABITAT_MEADOW | WORK_HABITAT_FOREST, WORK_HERB_SP | WORK_HERB_AU, WORK_HERB_MOON_NONE, 2, ITEM_AUTUMN_CROCUS, 2, WORK_HERB_RAMSONS, WORK_HERB_POOL_HERBS, false},
	{"bilberry", "Bilberries", WORK_HABITAT_FOREST, WORK_HERB_SU, WORK_HERB_MOON_NONE, 4, ITEM_BILBERRY, 3, -1, WORK_HERB_POOL_HERBS, false},
	{"cherry", "Wild cherry", WORK_HABITAT_EDGE | WORK_HABITAT_FOREST, WORK_HERB_SU, WORK_HERB_MOON_NONE, 3, ITEM_WILD_CHERRY, 3, -1, WORK_HERB_POOL_HERBS, false},
	{"cowparsley", "Cow parsley", WORK_HABITAT_EDGE | WORK_HABITAT_MEADOW | WORK_HABITAT_VILLAGE, WORK_HERB_SP | WORK_HERB_SU, WORK_HERB_MOON_NONE, 5, ITEM_COW_PARSLEY, 3, WORK_HERB_YARROW, WORK_HERB_POOL_HERBS, false},
	{"fieldmushroom", "Field mushrooms", WORK_HABITAT_MEADOW, WORK_HERB_SU | WORK_HERB_AU, WORK_HERB_MOON_NONE, 4, ITEM_FIELD_MUSHROOM, 3, -1, WORK_HERB_POOL_MUSHROOMS, false}
};

static const s_WorkHerbFoodGroups[][2] = {
	{ITEM_BERRIES, ITEM_BILBERRY},
	{ITEM_CHERRIES, ITEM_WILD_CHERRY},
	{ITEM_MUSHROOMS, ITEM_FIELD_MUSHROOM}
};

stock bool:Work_IsValidHerb(species)
{
	return species >= 0 && species < WORK_HERB_COUNT;
}

stock Work_GetHerbKey(species,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Work_IsValidHerb(species))
	{
		strcopy(dest,s_WorkHerbDefs[species][E_WORK_HERB_DEF_KEY],size);
	}
}

stock Work_FindHerb(const key[])
{
	for (new species = 0;species < WORK_HERB_COUNT;species++)
	{
		if (!strcmp(s_WorkHerbDefs[species][E_WORK_HERB_DEF_KEY],key))
		{
			return species;
		}
	}

	return -1;
}

stock Work_GetHerbName(species,dest[],size = sizeof(dest))
{
	if (!Work_IsValidHerb(species))
	{
		strcopy(dest,"Herb patch",size);
		return;
	}

	strcopy(dest,s_WorkHerbDefs[species][E_WORK_HERB_DEF_NAME],size);
}

stock Work_GetHerbSeenAs(playerid,species)
{
	if (!Work_IsValidHerb(species) || s_WorkHerbDefs[species][E_WORK_HERB_DEF_SEEN_AS] == -1 || Work_GetLevel(playerid,TRADE_HERBALIST) >= WORK_HERB_REVEAL_LEVEL)
	{
		return species;
	}

	return s_WorkHerbDefs[species][E_WORK_HERB_DEF_SEEN_AS];
}

stock Work_GetHerbTwin(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_SEEN_AS] : -1;
}

stock Work_GetHerbHabitat(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_HABITAT] : 0;
}

stock Work_GetHerbMoon(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_MOON] : WORK_HERB_MOON_NONE;
}

stock Work_GetHerbItem(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_ITEM] : ITEM_HERBS;
}

stock Work_GetHerbYield(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_YIELD] : 0;
}

stock Work_GetHerbWeight(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_WEIGHT] : 0;
}

stock Work_GetHerbPool(species)
{
	return Work_IsValidHerb(species) ? s_WorkHerbDefs[species][E_WORK_HERB_DEF_POOL] : -1;
}

stock bool:Work_IsHerbRemedy(species)
{
	return Work_IsValidHerb(species) && s_WorkHerbDefs[species][E_WORK_HERB_DEF_IS_REMEDY];
}

stock bool:Work_IsHerbInSeason(species,E_SEASON:season)
{
	return Work_IsValidHerb(species) && (s_WorkHerbDefs[species][E_WORK_HERB_DEF_SEASONS] & (1 << _:season)) != 0;
}

stock bool:Work_IsHerbMoonOpen(species,E_MOON:moon,month,bool:isNight)
{
	switch (Work_GetHerbMoon(species))
	{
		case WORK_HERB_MOON_FULL:
		{
			return isNight && moon == MOON_FULL;
		}
		case WORK_HERB_MOON_WOLF:
		{
			return isNight && moon == MOON_FULL && month == WORK_HERB_WOLF_MONTH;
		}
	}

	return true;
}

stock bool:Work_IsHerbUp(species,E_SEASON:season,E_MOON:moon,month,bool:isNight)
{
	return Work_GetHerbPool(species) == WORK_HERB_POOL_HERBS && Work_IsHerbInSeason(species,season) && Work_IsHerbMoonOpen(species,moon,month,isNight);
}

stock bool:Work_IsHerbUpNow(species)
{
	new day, month, year;
	Calendar_GetDate(day,month,year);
	return Work_IsHerbUp(species,Calendar_GetSeason(),Calendar_GetMoon(),month,Calendar_IsNight());
}

stock bool:Work_IsHerbStanding(species,habitat,E_SEASON:season)
{
	return Work_GetHerbMoon(species) == WORK_HERB_MOON_NONE && (Work_GetHerbHabitat(species) & habitat) != 0 && Work_IsHerbUp(species,season,MOON_NEW,0,false);
}

stock Work_GetHerbWeightFor(habitat,E_SEASON:season)
{
	new total = 0;

	for (new species = 0;species < WORK_HERB_COUNT;species++)
	{
		if (Work_IsHerbStanding(species,habitat,season))
		{
			total += s_WorkHerbDefs[species][E_WORK_HERB_DEF_WEIGHT];
		}
	}

	return total;
}

stock Work_RollHerb(habitat,E_SEASON:season)
{
	new total = Work_GetHerbWeightFor(habitat,season);

	if (total <= 0)
	{
		return -1;
	}

	new pick = random(total);

	for (new species = 0;species < WORK_HERB_COUNT;species++)
	{
		if (!Work_IsHerbStanding(species,habitat,season))
		{
			continue;
		}

		pick -= s_WorkHerbDefs[species][E_WORK_HERB_DEF_WEIGHT];

		if (pick < 0)
		{
			return species;
		}
	}

	return -1;
}

stock Work_GetHerbModel(species,stage)
{
	if (!Work_IsValidHerb(species) || stage < 0 || stage >= sizeof(g_RegistryHerbs[]))
	{
		return WORK_NO_MODEL;
	}

	return g_RegistryHerbs[species][stage];
}

stock Work_RegisterHerbItems()
{
	for (new species = 0;species < WORK_HERB_COUNT;species++)
	{
		if (s_WorkHerbDefs[species][E_WORK_HERB_DEF_IS_REMEDY])
		{
			Item_AddToGroup(ITEM_HERBS,s_WorkHerbDefs[species][E_WORK_HERB_DEF_ITEM]);
		}
	}

	for (new i = 0;i < sizeof(s_WorkHerbFoodGroups);i++)
	{
		Item_AddToGroup(s_WorkHerbFoodGroups[i][0],s_WorkHerbFoodGroups[i][1]);
	}
}
