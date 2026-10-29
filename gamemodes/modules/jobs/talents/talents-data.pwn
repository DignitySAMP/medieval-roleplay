#define TALENT_KEY_LEN (16)
#define TALENT_NAME_LEN (24)
#define TALENT_ROOT_KEY "campfire"
#define TALENT_MINUTES_PER_POINT (30)
#define TALENT_LEVEL_BASE (2)
#define TALENT_LEVEL_PER_NODE (2)
#define TALENT_LEVEL_MAX (10)
#define TALENT_FIRST_COST (2)
#define TALENT_NODE_MAX (48)
#define TALENT_REVEALS_LEN (48)

enum E_TALENT_NODE_DEF
{
	E_TALENT_NODE_DEF_KEY[TALENT_KEY_LEN],
	E_TALENT_NODE_DEF_NAME[TALENT_NAME_LEN],
	E_TALENT_NODE_DEF_TRADE,
	E_TALENT_NODE_DEF_PARENT[TALENT_KEY_LEN],
	E_TALENT_NODE_DEF_REVEALS[TALENT_REVEALS_LEN],
}

static const s_TalentNodeDefs[][E_TALENT_NODE_DEF] = {
	{"campfire", "Campfire", TRADE_TAVERN, "", ""},
	{"hearth", "Hearth", TRADE_TAVERN, "campfire", ""},
	{"table", "Serving table", TRADE_TAVERN, "hearth", ""},
	{"smokehouse", "Smokehouse", TRADE_FISHING, "hearth", ""},
	{"well", "Well", TRADE_WATER, "campfire", ""},
	{"quern", "Hand quern", TRADE_BAKER, "campfire", ""},
	{"oven", "Oven", TRADE_BAKER, "quern", ""},
	{"mill", "Millstones", TRADE_MILLER, "quern", ""},
	{"vat", "Vat", TRADE_BREWER, "hearth", ""},
	{"press", "Press", TRADE_BREWER, "vat", ""},
	{"block", "Chopping block", TRADE_WOODCUTTING, "campfire", ""},
	{"clamp", "Charcoal clamp", TRADE_WOODCUTTING, "block", ""},
	{"bench", "Workbench", TRADE_CARPENTER, "block", ""},
	{"hook", "Hanging hook", TRADE_BUTCHER, "block", ""},
	{"loom", "Loom", TRADE_TAILOR, "bench", ""},
	{"frame", "Parchment frame", TRADE_SCRIBE, "bench", ""},
	{"desk", "Scribe's desk", TRADE_SCRIBE, "frame", ""},
	{"henhouse", "Henhouse", TRADE_FARMING, "bench", ""},
	{"skep", "Skep", TRADE_BEEKEEPER, "bench", ""},
	{"herbalist", "Herbalist's table", TRADE_HERBALIST, "campfire", ""},
	{"churn", "Butter churn", TRADE_HERDSMAN, "bench", ""},
	{"cheese_press", "Cheese press", TRADE_HERDSMAN, "churn", ""},
	{"stall", "Market stall", TRADE_MERCHANT, "bench", ""},
	{"herald", "Herald's table", TRADE_MERCHANT, "stall", ""},
	{"forge", "Forge", TRADE_SMITH, "hearth", ""},
	{"anvil", "Anvil", TRADE_SMITH, "forge", ""},
	{"bloomery", "Bloomery", TRADE_SMITH, "anvil", ""},
	{"wheel", "Potter's wheel", TRADE_POTTER, "campfire", ""},
	{"kiln", "Kiln", TRADE_POTTER, "wheel", ""},
	{"altar", "Altar", TRADE_FAITH, "campfire", ""},
	{"eye_wood", "Woodsman's eye", TRADE_WOODCUTTING, "block", "trunk,stump,windfall"},
	{"eye_herbs", "Herbalist's eye", TRADE_HERBALIST, "campfire", "herbs,fruitbush"},
	{"eye_stone", "Prospector's eye", TRADE_MINING, "campfire", "outcrop,seam"},
	{"eye_earth", "Digger's eye", TRADE_POTTER, "wheel", "claypit,ground,bog"},
	{"eye_bees", "Beekeeper's eye", TRADE_BEEKEEPER, "skep", "wildhive,swarm"}
};

stock Talent_GetNodeCount()
{
	return sizeof(s_TalentNodeDefs);
}

stock bool:Talent_IsValidNode(node)
{
	return node >= 0 && node < sizeof(s_TalentNodeDefs);
}

stock Talent_FindNode(const key[])
{
	for (new i = 0;i < sizeof(s_TalentNodeDefs);i++)
	{
		if (strcmp(s_TalentNodeDefs[i][E_TALENT_NODE_DEF_KEY],key) == 0)
		{
			return i;
		}
	}

	return -1;
}

stock Talent_GetNodeKey(node,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Talent_IsValidNode(node))
	{
		strcopy(dest,s_TalentNodeDefs[node][E_TALENT_NODE_DEF_KEY],size);
	}
}

stock Talent_GetNodeName(node,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Talent_IsValidNode(node))
	{
		strcopy(dest,s_TalentNodeDefs[node][E_TALENT_NODE_DEF_NAME],size);
	}
}

stock Talent_GetNodeTrade(node)
{
	return Talent_IsValidNode(node) ? s_TalentNodeDefs[node][E_TALENT_NODE_DEF_TRADE] : TRADE_NONE;
}

stock bool:Talent_IsStationNode(node)
{
	return Talent_IsValidNode(node) && s_TalentNodeDefs[node][E_TALENT_NODE_DEF_REVEALS][0] == EOS;
}

stock Talent_GetStationNodeCount()
{
	new count = 0;

	for (new i = 0;i < sizeof(s_TalentNodeDefs);i++)
	{
		if (s_TalentNodeDefs[i][E_TALENT_NODE_DEF_REVEALS][0] == EOS)
		{
			count++;
		}
	}

	return count;
}

stock Talent_GetNodeReveals(node,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Talent_IsValidNode(node))
	{
		strcopy(dest,s_TalentNodeDefs[node][E_TALENT_NODE_DEF_REVEALS],size);
	}
}

stock bool:Talent_NodeReveals(node,const kind[])
{
	if (!Talent_IsValidNode(node) || kind[0] == EOS)
	{
		return false;
	}

	new length = strlen(kind), position = -1;

	while ((position = strfind(s_TalentNodeDefs[node][E_TALENT_NODE_DEF_REVEALS],kind,false,position + 1)) != -1)
	{
		new after = s_TalentNodeDefs[node][E_TALENT_NODE_DEF_REVEALS][position + length];

		if ((position == 0 || s_TalentNodeDefs[node][E_TALENT_NODE_DEF_REVEALS][position - 1] == ',') && (after == EOS || after == ','))
		{
			return true;
		}
	}

	return false;
}

stock bool:Talent_IsKindHidden(const kind[])
{
	for (new i = 0;i < sizeof(s_TalentNodeDefs);i++)
	{
		if (Talent_NodeReveals(i,kind))
		{
			return true;
		}
	}

	return false;
}

stock Talent_GetNodeParent(node)
{
	return Talent_IsValidNode(node) && s_TalentNodeDefs[node][E_TALENT_NODE_DEF_PARENT][0] != EOS ? Talent_FindNode(s_TalentNodeDefs[node][E_TALENT_NODE_DEF_PARENT]) : -1;
}

stock bool:Talent_IsFreeNode(node)
{
	return Talent_IsValidNode(node) && strcmp(s_TalentNodeDefs[node][E_TALENT_NODE_DEF_KEY],TALENT_ROOT_KEY) == 0;
}
