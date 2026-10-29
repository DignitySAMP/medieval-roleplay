#define WORK_KIND_KEY_LEN (16)
#define WORK_KIND_NAME_LEN (24)
#define WORK_KIND_VERB_LEN (32)
#define WORK_PROP_SLOTS (16)
#define WORK_NO_MODEL (0)
#define WORK_STAR_CAP (5)
#define WORK_WOOD_MODEL (16052)
#define WORK_WOOD_TXD "oldwest"
#define WORK_WOOD_TEXTURE "des_ghotwood1"
#define WORK_WOOD_MATERIALS (4)
#define WORK_PLACEHOLDER_MODEL (2912)
#define WORK_BUILD_MAX (4)
#define WORK_FUEL_MAX (3)
#define WORK_BASE_SECONDS (10800)
#define WORK_SCENE_BURN_SECONDS (600)
#define WORK_MENU_MAX (16)
#define WORK_FUEL_CAP_SECONDS (43200)

enum E_WORK_KIND_DEF
{
	E_WORK_KIND_DEF_KEY[WORK_KIND_KEY_LEN],
	E_WORK_KIND_DEF_NAME[WORK_KIND_NAME_LEN],
	E_WORK_KIND_DEF_VERB[WORK_KIND_VERB_LEN],
	bool:E_WORK_KIND_DEF_IS_NODE,
	E_WORK_KIND_DEF_MODEL_FULL,
	E_WORK_KIND_DEF_MODEL_HALF,
	E_WORK_KIND_DEF_MODEL_EMPTY,
	E_WORK_KIND_DEF_STOCK,
	E_WORK_KIND_DEF_REGROW_HOURS,
	E_WORK_KIND_DEF_STAR_CAP,
}

static const s_WorkKindDefs[][E_WORK_KIND_DEF] = {
	{"campfire", "Campfire", "cook at the campfire", false, 0, 0, 0, 0, 0, 3},
	{"hearth", "Hearth", "cook at the hearth", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"oven", "Oven", "bake at the oven", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"anvil", "Anvil", "work the anvil", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"forge", "Forge", "work the forge", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"bloomery", "Bloomery", "fire the bloomery", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"bench", "Workbench", "work at the bench", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"block", "Chopping block", "work at the block", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"table", "Table", "work at the table", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"desk", "Desk", "sit at the desk", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"wheel", "Wheel", "sit at the wheel", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"loom", "Loom", "sit at the loom", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"frame", "Frame", "work the frame", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"vat", "Vat", "work the vat", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"press", "Press", "work the press", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"mill", "Millstones", "work the mill", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"quern", "Hand quern", "grind at the quern", false, 0, 0, 0, 0, 0, 3},
	{"kiln", "Kiln", "fire the kiln", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"clamp", "Charcoal clamp", "tend the clamp", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"smokehouse", "Smokehouse", "work the smokehouse", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"hook", "Hanging hook", "work at the hook", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"well", "Well", "draw from the well", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"altar", "Altar", "kneel at the altar", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"skep", "Skep", "tend the skep", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"henhouse", "Henhouse", "tend the henhouse", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"herbalist", "Herbalist's table", "work at the herbalist's table", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"churn", "Butter churn", "work the churn", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"cheese_press", "Cheese press", "work the cheese press", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"stall", "Market stall", "tend the market stall", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"herald", "Herald's table", "sign the herald's roll", false, 0, 0, 0, 0, 0, WORK_STAR_CAP},
	{"trunk", "Felled trunk", "work the trunk", true, 0, 0, 0, 3, 72, WORK_STAR_CAP},
	{"stump", "Old stump", "work the stump", true, 0, 0, 0, 2, 48, WORK_STAR_CAP},
	{"windfall", "Windfall", "gather from the windfall", true, 0, 0, 0, 4, 24, WORK_STAR_CAP},
	{"fruitbush", "Fruit bush", "pick from the bush", true, 0, 0, 0, 3, 24, WORK_STAR_CAP},
	{"outcrop", "Rock outcrop", "work the outcrop", true, 0, 0, 0, 4, 96, WORK_STAR_CAP},
	{"seam", "Ore seam", "work the seam", true, 0, 0, 0, 3, 120, WORK_STAR_CAP},
	{"claypit", "Clay pit", "dig the pit", true, 0, 0, 0, 4, 48, WORK_STAR_CAP},
	{"ground", "Digging ground", "dig here", true, 0, 0, 0, 2, 24, WORK_STAR_CAP},
	{"bog", "Bog pool", "work the bog", true, 0, 0, 0, 3, 48, WORK_STAR_CAP},
	{"strip", "Field strip", "work the strip", true, 0, 0, 0, 3, 24, WORK_STAR_CAP},
	{"herbs", "Herb patch", "gather herbs", true, 0, 0, 0, 3, 24, WORK_STAR_CAP},
	{"wildhive", "Wild hive", "take from the hive", true, 0, 0, 0, 2, 72, WORK_STAR_CAP},
	{"swarm", "Swarm", "catch the swarm", true, 0, 0, 0, 1, 168, WORK_STAR_CAP},
	{"tanpit", "Tanning pit", "work the tanning pit", true, 0, 0, 0, 2, 48, WORK_STAR_CAP},
	{"fishing", "Fishing spot", "fish here", true, 0, 0, 0, 6, 2, WORK_STAR_CAP},
	{"kill", "A dead deer", "dress the deer", true, 0, 0, 0, 1, 0, WORK_STAR_CAP},
	{"kill_boar", "A dead boar", "dress the boar", true, 0, 0, 0, 1, 0, WORK_STAR_CAP},
	{"kill_wolf", "A dead wolf", "skin the wolf", true, 0, 0, 0, 1, 0, WORK_STAR_CAP},
	{"kill_bear", "A dead bear", "dress the bear", true, 0, 0, 0, 1, 0, WORK_STAR_CAP}
};

enum E_WORK_BUILD_DEF
{
	E_WORK_BUILD_DEF_KIND[WORK_KIND_KEY_LEN],
	E_WORK_BUILD_DEF_ITEM[WORK_BUILD_MAX],
	E_WORK_BUILD_DEF_AMOUNT[WORK_BUILD_MAX],
	bool:E_WORK_BUILD_DEF_IS_FIRE,
}

static const s_WorkBuildDefs[][E_WORK_BUILD_DEF] = {
	{"campfire", {ITEM_FIREWOOD, ITEM_STONE_BLOCK, -1, -1}, {2, 2, 0, 0}, true},
	{"hearth", {ITEM_STONE_BLOCK, ITEM_FIREWOOD, ITEM_POT, -1}, {6, 3, 1, 0}, true},
	{"oven", {ITEM_CLAY, ITEM_STONE_BLOCK, ITEM_PLANK, -1}, {8, 6, 2, 0}, true},
	{"anvil", {ITEM_IRON_BLOOM, ITEM_LOG_OAK, ITEM_HAMMER, -1}, {1, 1, 1, 0}, false},
	{"forge", {ITEM_STONE_BLOCK, ITEM_CHARCOAL, ITEM_IRON_BAR, -1}, {8, 2, 1, 0}, true},
	{"bloomery", {ITEM_CLAY, ITEM_STONE_BLOCK, ITEM_CHARCOAL, -1}, {10, 4, 3, 0}, true},
	{"bench", {ITEM_PLANK, ITEM_LOG_OAK, ITEM_SAW, -1}, {6, 2, 1, 0}, false},
	{"block", {ITEM_LOG_OAK, -1, -1, -1}, {1, 0, 0, 0}, false},
	{"table", {ITEM_PLANK, ITEM_NAILS, -1, -1}, {4, 1, 0, 0}, false},
	{"desk", {ITEM_PLANK, ITEM_NAILS, -1, -1}, {4, 1, 0, 0}, false},
	{"wheel", {ITEM_PLANK, ITEM_STONE_BLOCK, -1, -1}, {3, 2, 0, 0}, false},
	{"loom", {ITEM_BEAM, ITEM_PLANK, ITEM_ROPE, -1}, {2, 2, 2, 0}, false},
	{"frame", {ITEM_BEAM, ITEM_ROPE, -1, -1}, {1, 2, 0, 0}, false},
	{"vat", {ITEM_STAVE, ITEM_NAILS, -1, -1}, {8, 2, 0, 0}, false},
	{"press", {ITEM_BEAM, ITEM_PLANK, ITEM_NAILS, -1}, {2, 4, 2, 0}, false},
	{"mill", {ITEM_STONE_BLOCK, ITEM_BEAM, ITEM_PLANK, -1}, {8, 2, 4, 0}, false},
	{"quern", {ITEM_STONE_BLOCK, -1, -1, -1}, {2, 0, 0, 0}, false},
	{"kiln", {ITEM_CLAY, ITEM_BRICK, -1, -1}, {12, 6, 0, 0}, true},
	{"clamp", {ITEM_LOG_SOFTWOOD, ITEM_FIREWOOD, -1, -1}, {6, 4, 0, 0}, true},
	{"smokehouse", {ITEM_PLANK, ITEM_FIREWOOD, ITEM_ROPE, -1}, {4, 4, 1, 0}, true},
	{"hook", {ITEM_BEAM, ITEM_NAILS, ITEM_ROPE, -1}, {1, 1, 1, 0}, false},
	{"well", {ITEM_STONE_BLOCK, ITEM_ROPE, ITEM_PLANK, -1}, {10, 2, 2, 0}, false},
	{"altar", {ITEM_STONE_BLOCK, ITEM_LINEN, -1, -1}, {6, 1, 0, 0}, false},
	{"skep", {ITEM_KINDLING, ITEM_ROPE, -1, -1}, {4, 1, 0, 0}, false},
	{"henhouse", {ITEM_PLANK, ITEM_NAILS, -1, -1}, {4, 2, 0, 0}, false},
	{"herbalist", {ITEM_PLANK, ITEM_STONE_BLOCK, ITEM_NAILS, -1}, {4, 2, 1, 0}, true},
	{"churn", {ITEM_STAVE, ITEM_NAILS, -1, -1}, {6, 1, 0, 0}, false},
	{"cheese_press", {ITEM_BEAM, ITEM_PLANK, ITEM_NAILS, -1}, {1, 3, 1, 0}, false},
	{"stall", {ITEM_BEAM, ITEM_PLANK, ITEM_LINEN, -1}, {2, 6, 2, 0}, false},
	{"herald", {ITEM_BEAM, ITEM_PLANK, ITEM_LINEN, -1}, {1, 4, 1, 0}, false}
};

static const s_WorkFireFuels[WORK_FUEL_MAX][2] = {
	{ITEM_FIREWOOD, 3600},
	{ITEM_CHARCOAL, 7200},
	{ITEM_KINDLING, 1200}
};

static const s_WorkColdFuels[WORK_FUEL_MAX][2] = {
	{ITEM_ROPE, 7200},
	{ITEM_NAILS, 3600},
	{ITEM_LINEN, 7200}
};

enum E_WORK_PROP_DEF
{
	E_WORK_PROP_DEF_KIND[WORK_KIND_KEY_LEN],
	E_WORK_PROP_DEF_SLOT,
	E_WORK_PROP_DEF_MODEL,
	Float:E_WORK_PROP_DEF_OFFSET[3],
	Float:E_WORK_PROP_DEF_ROT[3],
	bool:E_WORK_PROP_DEF_IS_WOOD,
	bool:E_WORK_PROP_DEF_IS_LABEL,
}

static const s_WorkPropDefs[][E_WORK_PROP_DEF] = {
	{"campfire", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"hearth", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"oven", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"anvil", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"forge", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"bloomery", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"bench", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"block", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"table", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"desk", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"wheel", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"loom", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"frame", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"vat", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"press", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"mill", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"quern", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"kiln", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"clamp", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"smokehouse", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"hook", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"well", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"altar", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"skep", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"henhouse", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"herbalist", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"churn", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"cheese_press", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"stall", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true},
	{"herald", 0, WORK_PLACEHOLDER_MODEL, {0.0, 0.0, 0.01}, {0.0, 0.0, 0.0}, false, true}
};

stock Work_GetKindCount()
{
	return sizeof(s_WorkKindDefs);
}

stock bool:Work_IsValidKind(kind)
{
	return kind >= 0 && kind < sizeof(s_WorkKindDefs);
}

stock Work_FindKind(const key[])
{
	for (new i = 0;i < sizeof(s_WorkKindDefs);i++)
	{
		if (strcmp(s_WorkKindDefs[i][E_WORK_KIND_DEF_KEY],key) == 0)
		{
			return i;
		}
	}

	return -1;
}

stock Work_GetKindKey(kind,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Work_IsValidKind(kind))
	{
		strcopy(dest,s_WorkKindDefs[kind][E_WORK_KIND_DEF_KEY],size);
	}
}

stock Work_GetKindName(kind,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Work_IsValidKind(kind))
	{
		strcopy(dest,s_WorkKindDefs[kind][E_WORK_KIND_DEF_NAME],size);
	}
}

stock Work_GetKindVerb(kind,dest[],size = sizeof(dest))
{
	dest[0] = EOS;

	if (Work_IsValidKind(kind))
	{
		strcopy(dest,s_WorkKindDefs[kind][E_WORK_KIND_DEF_VERB],size);
	}
}

stock bool:Work_IsNodeKind(kind)
{
	return Work_IsValidKind(kind) && s_WorkKindDefs[kind][E_WORK_KIND_DEF_IS_NODE];
}

stock Work_GetKindStarCap(kind)
{
	return Work_IsValidKind(kind) ? s_WorkKindDefs[kind][E_WORK_KIND_DEF_STAR_CAP] : WORK_STAR_CAP;
}

stock Work_GetKindStock(kind)
{
	return Work_IsValidKind(kind) ? s_WorkKindDefs[kind][E_WORK_KIND_DEF_STOCK] : 0;
}

stock Work_GetKindRegrowHours(kind)
{
	return Work_IsValidKind(kind) ? s_WorkKindDefs[kind][E_WORK_KIND_DEF_REGROW_HOURS] : 0;
}

stock bool:Work_GetKindProp(kind,slot,&model,&Float:ox,&Float:oy,&Float:oz,&Float:rx,&Float:ry,&Float:rz,&bool:isWood = false,&bool:isLabel = false)
{
	if (!Work_IsValidKind(kind))
	{
		return false;
	}

	for (new i = 0;i < sizeof(s_WorkPropDefs);i++)
	{
		if (s_WorkPropDefs[i][E_WORK_PROP_DEF_SLOT] != slot || strcmp(s_WorkPropDefs[i][E_WORK_PROP_DEF_KIND],s_WorkKindDefs[kind][E_WORK_KIND_DEF_KEY]) != 0)
		{
			continue;
		}

		model = s_WorkPropDefs[i][E_WORK_PROP_DEF_MODEL];
		ox = s_WorkPropDefs[i][E_WORK_PROP_DEF_OFFSET][0];
		oy = s_WorkPropDefs[i][E_WORK_PROP_DEF_OFFSET][1];
		oz = s_WorkPropDefs[i][E_WORK_PROP_DEF_OFFSET][2];
		rx = s_WorkPropDefs[i][E_WORK_PROP_DEF_ROT][0];
		ry = s_WorkPropDefs[i][E_WORK_PROP_DEF_ROT][1];
		rz = s_WorkPropDefs[i][E_WORK_PROP_DEF_ROT][2];
		isWood = s_WorkPropDefs[i][E_WORK_PROP_DEF_IS_WOOD];
		isLabel = s_WorkPropDefs[i][E_WORK_PROP_DEF_IS_LABEL];
		return true;
	}

	return false;
}

static Work_FindBuildDef(kind)
{
	if (!Work_IsValidKind(kind))
	{
		return -1;
	}

	for (new i = 0;i < sizeof(s_WorkBuildDefs);i++)
	{
		if (strcmp(s_WorkBuildDefs[i][E_WORK_BUILD_DEF_KIND],s_WorkKindDefs[kind][E_WORK_KIND_DEF_KEY]) == 0)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Work_GetBuildMaterial(kind,index,&item,&amount)
{
	new def = Work_FindBuildDef(kind);

	if (def == -1 || index < 0 || index >= WORK_BUILD_MAX || s_WorkBuildDefs[def][E_WORK_BUILD_DEF_ITEM][index] < 0)
	{
		return false;
	}

	item = s_WorkBuildDefs[def][E_WORK_BUILD_DEF_ITEM][index];
	amount = s_WorkBuildDefs[def][E_WORK_BUILD_DEF_AMOUNT][index];
	return true;
}

stock bool:Work_IsFireKind(kind)
{
	new def = Work_FindBuildDef(kind);
	return def != -1 && s_WorkBuildDefs[def][E_WORK_BUILD_DEF_IS_FIRE];
}

stock Work_GetFuelSeconds(kind,item)
{
	for (new i = 0;i < WORK_FUEL_MAX;i++)
	{
		if (Work_IsFireKind(kind) ? (s_WorkFireFuels[i][0] == item) : (s_WorkColdFuels[i][0] == item))
		{
			return Work_IsFireKind(kind) ? s_WorkFireFuels[i][1] : s_WorkColdFuels[i][1];
		}
	}

	return 0;
}

stock Work_GetFuelItem(kind,index)
{
	if (index < 0 || index >= WORK_FUEL_MAX)
	{
		return -1;
	}

	return Work_IsFireKind(kind) ? s_WorkFireFuels[index][0] : s_WorkColdFuels[index][0];
}

stock Work_CountRecipesForKind(kind)
{
	new key[WORK_KIND_KEY_LEN], node[RECIPE_NODE_LEN], count = 0;
	Work_GetKindKey(kind,key);

	for (new recipe = 0;recipe < Recipe_GetCount();recipe++)
	{
		Recipe_GetNode(recipe,node);

		if (strcmp(node,key) == 0)
		{
			count++;
		}
	}

	return count;
}

stock Work_GetRecipesForKind(kind,recipes[],maxRecipes = sizeof(recipes))
{
	new key[WORK_KIND_KEY_LEN], node[RECIPE_NODE_LEN], count = 0;
	Work_GetKindKey(kind,key);

	for (new recipe = 0;recipe < Recipe_GetCount() && count < maxRecipes;recipe++)
	{
		Recipe_GetNode(recipe,node);

		if (strcmp(node,key) == 0)
		{
			recipes[count++] = recipe;
		}
	}

	return count;
}
