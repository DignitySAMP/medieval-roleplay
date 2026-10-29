#define JOB_NAME_LEN (24)

enum
{
	TRADE_FARMING = 0,
	TRADE_WATER,
	TRADE_ORCHARD,
	TRADE_HERDSMAN,
	TRADE_BUTCHER,
	TRADE_MILLER,
	TRADE_BAKER,
	TRADE_BREWER,
	TRADE_BEEKEEPER,
	TRADE_TAVERN,
	TRADE_WOODCUTTING,
	TRADE_MINING,
	TRADE_SMITH,
	TRADE_CARPENTER,
	TRADE_TAILOR,
	TRADE_POTTER,
	TRADE_HERBALIST,
	TRADE_PHYSICIAN,
	TRADE_FAITH,
	TRADE_HUNTING,
	TRADE_CHANDLER,
	TRADE_FISHING,
	TRADE_SCRIBE,
	TRADE_MERCHANT,
	TRADE_COUNT,
}

#define TRADE_NONE (-1)

enum
{
	RUNG_PEASANT = 0,
	RUNG_CRAFTSMAN,
	RUNG_BURGHER,
	RUNG_NOBLE,
	RUNG_COUNT,
}

enum E_TRADE_DEF
{
	E_TRADE_DEF_NAME[JOB_NAME_LEN],
}

enum E_OCCUPATION_DEF
{
	E_OCCUPATION_DEF_NAME[JOB_NAME_LEN],
	E_OCCUPATION_DEF_RUNG,
	E_OCCUPATION_DEF_TRADE,
}

static const s_TradeDefs[TRADE_COUNT][E_TRADE_DEF] = {
	{"Farming"},
	{"Water carrying"},
	{"Orchard keeping"},
	{"Herding"},
	{"Butchery"},
	{"Milling"},
	{"Baking"},
	{"Brewing"},
	{"Beekeeping"},
	{"Cooking"},
	{"Woodcutting"},
	{"Mining"},
	{"Smithing"},
	{"Carpentry"},
	{"Tailoring"},
	{"Pottery"},
	{"Herbalism"},
	{"Physic"},
	{"Faith"},
	{"Hunting"},
	{"Chandlery"},
	{"Fishing"},
	{"Scribing"},
	{"Trade"}
};

enum
{
	OCCUPATION_FARMHAND = 0,
	OCCUPATION_KITCHEN_HAND,
	OCCUPATION_APPRENTICE,
	OCCUPATION_NOVICE,
	OCCUPATION_RECRUIT,
	OCCUPATION_WATER_CARRIER,
	OCCUPATION_HERD_BOY,
	OCCUPATION_DIGGER,
	OCCUPATION_TOWN_CRIER,
	OCCUPATION_FARMER,
	OCCUPATION_ORCHARD_KEEPER,
	OCCUPATION_HERDSMAN,
	OCCUPATION_BEEKEEPER,
	OCCUPATION_BUTCHER,
	OCCUPATION_CHANDLER,
	OCCUPATION_SCRIBE,
	OCCUPATION_BAKER,
	OCCUPATION_MILLER,
	OCCUPATION_BREWER,
	OCCUPATION_SMITH,
	OCCUPATION_CARPENTER,
	OCCUPATION_TAILOR,
	OCCUPATION_POTTER,
	OCCUPATION_FORESTER,
	OCCUPATION_CHARCOAL_BURNER,
	OCCUPATION_MINER,
	OCCUPATION_FISHERMAN,
	OCCUPATION_HERBALIST,
	OCCUPATION_HUNTER,
	OCCUPATION_MASON,
	OCCUPATION_THATCHER,
	OCCUPATION_INNKEEPER,
	OCCUPATION_MERCHANT,
	OCCUPATION_PHYSICIAN,
	OCCUPATION_PRIEST,
	OCCUPATION_MONK,
	OCCUPATION_GUARD,
	OCCUPATION_COUNT_TITLE,
	OCCUPATION_DUKE,
	OCCUPATION_BISHOP,
	OCCUPATION_COUNT,
}

static const s_OccupationDefs[OCCUPATION_COUNT][E_OCCUPATION_DEF] = {
	{"Farmhand", RUNG_PEASANT, TRADE_FARMING},
	{"Kitchen hand", RUNG_PEASANT, TRADE_TAVERN},
	{"Apprentice", RUNG_PEASANT, TRADE_SMITH},
	{"Novice", RUNG_PEASANT, TRADE_FAITH},
	{"Recruit", RUNG_PEASANT, TRADE_NONE},
	{"Water carrier", RUNG_PEASANT, TRADE_WATER},
	{"Herd boy", RUNG_PEASANT, TRADE_HERDSMAN},
	{"Digger", RUNG_PEASANT, TRADE_MINING},
	{"Town crier", RUNG_PEASANT, TRADE_NONE},
	{"Farmer", RUNG_CRAFTSMAN, TRADE_FARMING},
	{"Orchard keeper", RUNG_CRAFTSMAN, TRADE_ORCHARD},
	{"Herdsman", RUNG_CRAFTSMAN, TRADE_HERDSMAN},
	{"Beekeeper", RUNG_CRAFTSMAN, TRADE_BEEKEEPER},
	{"Butcher", RUNG_CRAFTSMAN, TRADE_BUTCHER},
	{"Chandler", RUNG_CRAFTSMAN, TRADE_CHANDLER},
	{"Scribe", RUNG_CRAFTSMAN, TRADE_SCRIBE},
	{"Baker", RUNG_CRAFTSMAN, TRADE_BAKER},
	{"Miller", RUNG_CRAFTSMAN, TRADE_MILLER},
	{"Brewer", RUNG_CRAFTSMAN, TRADE_BREWER},
	{"Smith", RUNG_CRAFTSMAN, TRADE_SMITH},
	{"Carpenter", RUNG_CRAFTSMAN, TRADE_CARPENTER},
	{"Tailor", RUNG_CRAFTSMAN, TRADE_TAILOR},
	{"Potter", RUNG_CRAFTSMAN, TRADE_POTTER},
	{"Forester", RUNG_CRAFTSMAN, TRADE_WOODCUTTING},
	{"Charcoal burner", RUNG_CRAFTSMAN, TRADE_WOODCUTTING},
	{"Miner", RUNG_CRAFTSMAN, TRADE_MINING},
	{"Fisherman", RUNG_CRAFTSMAN, TRADE_FISHING},
	{"Herbalist", RUNG_CRAFTSMAN, TRADE_HERBALIST},
	{"Hunter", RUNG_CRAFTSMAN, TRADE_HUNTING},
	{"Mason", RUNG_CRAFTSMAN, TRADE_MINING},
	{"Thatcher", RUNG_CRAFTSMAN, TRADE_CARPENTER},
	{"Innkeeper", RUNG_BURGHER, TRADE_TAVERN},
	{"Merchant", RUNG_BURGHER, TRADE_MERCHANT},
	{"Physician", RUNG_BURGHER, TRADE_PHYSICIAN},
	{"Priest", RUNG_BURGHER, TRADE_FAITH},
	{"Monk", RUNG_BURGHER, TRADE_FAITH},
	{"Guard", RUNG_BURGHER, TRADE_NONE},
	{"Count", RUNG_NOBLE, TRADE_NONE},
	{"Duke", RUNG_NOBLE, TRADE_NONE},
	{"Bishop", RUNG_NOBLE, TRADE_FAITH}
};

stock bool:Trade_IsValid(trade)
{
	return trade >= 0 && trade < TRADE_COUNT;
}

stock Trade_GetName(trade,dest[],size = sizeof(dest))
{
	if (!Trade_IsValid(trade))
	{
		strcopy(dest,"No trade",size);
		return;
	}

	strcopy(dest,s_TradeDefs[trade][E_TRADE_DEF_NAME],size);
}

stock bool:Occupation_IsValid(occupation)
{
	return occupation >= 0 && occupation < OCCUPATION_COUNT;
}

stock Occupation_GetName(occupation,dest[],size = sizeof(dest))
{
	if (!Occupation_IsValid(occupation))
	{
		strcopy(dest,"Nobody",size);
		return;
	}

	strcopy(dest,s_OccupationDefs[occupation][E_OCCUPATION_DEF_NAME],size);
}

stock Occupation_GetRung(occupation)
{
	return Occupation_IsValid(occupation) ? s_OccupationDefs[occupation][E_OCCUPATION_DEF_RUNG] : -1;
}

stock Occupation_GetTrade(occupation)
{
	return Occupation_IsValid(occupation) ? s_OccupationDefs[occupation][E_OCCUPATION_DEF_TRADE] : TRADE_NONE;
}

stock Occupation_FindByName(const name[])
{
	for (new i = 0; i < OCCUPATION_COUNT; i++)
	{
		if (!strcmp(s_OccupationDefs[i][E_OCCUPATION_DEF_NAME],name,true))
		{
			return i;
		}
	}

	return -1;
}
