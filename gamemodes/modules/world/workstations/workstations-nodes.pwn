#define WORK_MAX_NODES (1024)

#define WORK_NODE_FX_MODEL (18717)
#define WORK_NODE_FX_EMITTER (1.611)
#define WORK_NODE_FX_RANGE (60.0)
#define WORK_KIND_RULES_MAX (8)
#define WORK_KIND_FX_FRAMES (4)
#define WORK_NODE_FX_FRAME_MS (450)
#define WORK_REACH_FACING (50.0)
#define WORK_REACH_LEVEL (6.0)
#define WORK_NODE_STREAM_DISTANCE (150.0)

enum E_WORK_NODE
{
	bool:E_WORK_NODE_USED,
	E_WORK_NODE_ROW,
	E_WORK_NODE_KIND,
	E_WORK_NODE_SPECIES,
	Float:E_WORK_NODE_POS[4],
	E_WORK_NODE_WORLD,
	E_WORK_NODE_INTERIOR,
	E_WORK_NODE_STOCK,
	E_WORK_NODE_MAX_STOCK,
	E_WORK_NODE_REGROW_LEFT,
	E_WORK_NODE_HOLDER,
	E_WORK_NODE_SPOT,
	STREAMER_TAG_OBJECT:E_WORK_NODE_OBJECT,
	STREAMER_TAG_OBJECT:E_WORK_NODE_FX,
	bool:E_WORK_NODE_FX_HIDDEN,
	E_WORK_NODE_FX_RULE,
	E_WORK_NODE_WORKER,
}

new g_WorkNodes[WORK_MAX_NODES][E_WORK_NODE];

static Work_GetNodeStageDef(kind,amount,maxStock)
{
	if (!Work_IsValidKind(kind))
	{
		return -1;
	}

	new key[WORK_KIND_KEY_LEN], first = -1, count = 0;
	Work_GetKindKey(kind,key);

	for (new i = 0;i < WORK_NODE_STAGE_COUNT;i++)
	{
		if (strcmp(g_WorkNodeStageDefs[i][E_WORK_NODE_STAGE_DEF_KIND],key) == 0)
		{
			if (first == -1)
			{
				first = i;
			}

			count++;
		}
	}

	if (count == 0)
	{
		return -1;
	}

	new stage;

	if (amount >= maxStock)
	{
		stage = 0;
	}
	else if (amount <= 0)
	{
		stage = count - 1;
	}
	else if (count <= 2)
	{
		stage = 0;
	}
	else
	{
		stage = 1 + (maxStock - amount - 1) * (count - 2) / max(maxStock - 1,1);
	}

	return first + Util_ClampInt(stage,0,count - 1);
}

stock Work_GetNodeModel(kind,amount,maxStock)
{
	new def = Work_GetNodeStageDef(kind,amount,maxStock);
	return def == -1 ? WORK_NO_MODEL : g_WorkNodeStageDefs[def][E_WORK_NODE_STAGE_DEF_MODEL];
}

static Work_GetNodeSpeciesModel(nodeid)
{
	new def = Work_GetNodeStageDef(g_WorkNodes[nodeid][E_WORK_NODE_KIND],g_WorkNodes[nodeid][E_WORK_NODE_STOCK],g_WorkNodes[nodeid][E_WORK_NODE_MAX_STOCK]);

	if (def == -1)
	{
		return WORK_NO_MODEL;
	}

	new stage = g_WorkNodeStageDefs[def][E_WORK_NODE_STAGE_DEF_INDEX];

	if (strcmp(g_WorkNodeStageDefs[def][E_WORK_NODE_STAGE_DEF_KIND],"herbs") != 0 || stage >= sizeof(g_RegistryHerbs[]))
	{
		return g_WorkNodeStageDefs[def][E_WORK_NODE_STAGE_DEF_MODEL];
	}

	new species = g_WorkNodes[nodeid][E_WORK_NODE_SPECIES] > 0 ? g_WorkNodes[nodeid][E_WORK_NODE_SPECIES] - 1 : g_WorkNodes[nodeid][E_WORK_NODE_ROW];
	return g_RegistryHerbs[species % REGISTRY_HERBS_VARIANTS][stage];
}

stock Float:Work_GetNodeHeight(kind,amount,maxStock)
{
	new def = Work_GetNodeStageDef(kind,amount,maxStock);
	return def == -1 ? 0.0 : g_WorkNodeStageDefs[def][E_WORK_NODE_STAGE_DEF_HEIGHT];
}

stock bool:Work_IsValidNode(nodeid)
{
	return nodeid >= 0 && nodeid < WORK_MAX_NODES && g_WorkNodes[nodeid][E_WORK_NODE_USED];
}

stock bool:Work_GetNodePos(nodeid,&Float:x,&Float:y,&Float:z)
{
	if (!Work_IsValidNode(nodeid))
	{
		return false;
	}

	x = g_WorkNodes[nodeid][E_WORK_NODE_POS][0];
	y = g_WorkNodes[nodeid][E_WORK_NODE_POS][1];
	z = g_WorkNodes[nodeid][E_WORK_NODE_POS][2];
	return true;
}

stock Work_CountKind(kind)
{
	new count = 0;

	if (Work_IsNodeKind(kind))
	{
		for (new i = 0;i < WORK_MAX_NODES;i++)
		{
			if (g_WorkNodes[i][E_WORK_NODE_USED] && g_WorkNodes[i][E_WORK_NODE_KIND] == kind)
			{
				count++;
			}
		}

		return count;
	}

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && g_WorkStations[i][E_WORK_STATION_KIND] == kind)
		{
			count++;
		}
	}

	return count;
}

stock Work_GetNodeCount()
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (g_WorkNodes[i][E_WORK_NODE_USED])
		{
			count++;
		}
	}

	return count;
}

stock Work_GetNodeSpot(nodeid)
{
	return Work_IsValidNode(nodeid) ? g_WorkNodes[nodeid][E_WORK_NODE_SPOT] : -1;
}

stock Work_GetNodeStock(nodeid)
{
	return Work_IsValidNode(nodeid) ? g_WorkNodes[nodeid][E_WORK_NODE_STOCK] : 0;
}

stock Work_GetNodeWorld(nodeid)
{
	return Work_IsValidNode(nodeid) ? g_WorkNodes[nodeid][E_WORK_NODE_WORLD] : 0;
}

stock Work_GetNodeInterior(nodeid)
{
	return Work_IsValidNode(nodeid) ? g_WorkNodes[nodeid][E_WORK_NODE_INTERIOR] : 0;
}

stock Work_GetNodeHerb(nodeid)
{
	if (!Work_IsValidNode(nodeid) || g_WorkNodes[nodeid][E_WORK_NODE_SPECIES] <= 0)
	{
		return -1;
	}

	new key[WORK_KIND_KEY_LEN], species = g_WorkNodes[nodeid][E_WORK_NODE_SPECIES] - 1;
	Work_GetKindKey(g_WorkNodes[nodeid][E_WORK_NODE_KIND],key);
	return strcmp(key,"herbs") == 0 && Work_IsValidHerb(species) ? species : -1;
}

stock Work_GetNodeName(playerid,nodeid,dest[],size = sizeof(dest))
{
	new species = Work_GetNodeHerb(nodeid);

	if (species != -1)
	{
		Work_GetHerbName(playerid == INVALID_PLAYER_ID ? species : Work_GetHerbSeenAs(playerid,species),dest,size);
		return;
	}

	Work_GetKindName(Work_IsValidNode(nodeid) ? g_WorkNodes[nodeid][E_WORK_NODE_KIND] : -1,dest,size);
}

stock bool:Work_GetNodeYield(nodeid,&param,&amount)
{
	new species = Work_GetNodeHerb(nodeid);

	if (species == -1)
	{
		return false;
	}

	param = Work_GetHerbItem(species);
	amount = Work_GetHerbYield(species);
	return true;
}

static Work_ClearNodeFx(nodeid)
{
	if (IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_FX]))
	{
		DestroyDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_FX]);
	}

	g_WorkNodes[nodeid][E_WORK_NODE_FX] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	g_WorkNodes[nodeid][E_WORK_NODE_FX_HIDDEN] = false;
	g_WorkNodes[nodeid][E_WORK_NODE_FX_RULE] = -1;
}

enum E_WORK_KIND_RULE
{
	E_WORK_KIND_RULE_KEY[WORK_KIND_KEY_LEN],
	E_WORK_KIND_RULE_SIGHT_TOOL,
	Float:E_WORK_KIND_RULE_REACH,
	E_WORK_KIND_RULE_FX_FRAMES[WORK_KIND_FX_FRAMES],
	E_WORK_KIND_RULE_FX_COUNT,
	Float:E_WORK_KIND_RULE_FX_LIFT,
}

static s_WorkKindRules[WORK_KIND_RULES_MAX][E_WORK_KIND_RULE];
static s_WorkKindRuleCount;
static s_WorkNodeFxFrame;
static bool:s_WorkHadSightTool[MAX_PLAYERS][WORK_KIND_RULES_MAX];

static Work_FindKindRule(const key[])
{
	for (new i = 0;i < s_WorkKindRuleCount;i++)
	{
		if (!strcmp(s_WorkKindRules[i][E_WORK_KIND_RULE_KEY],key))
		{
			return i;
		}
	}

	return -1;
}

stock bool:Work_SetKindRule(const key[],sightTool,Float:reach)
{
	new rule = Work_FindKindRule(key);

	if (rule == -1)
	{
		if (s_WorkKindRuleCount >= WORK_KIND_RULES_MAX)
		{
			return false;
		}

		rule = s_WorkKindRuleCount++;
	}

	strcopy(s_WorkKindRules[rule][E_WORK_KIND_RULE_KEY],key,WORK_KIND_KEY_LEN);
	s_WorkKindRules[rule][E_WORK_KIND_RULE_SIGHT_TOOL] = sightTool;
	s_WorkKindRules[rule][E_WORK_KIND_RULE_REACH] = reach;
	return true;
}

stock bool:Work_SetKindFx(const key[],const frames[],count,Float:lift)
{
	new rule = Work_FindKindRule(key);

	if (rule == -1 || count < 1 || count > WORK_KIND_FX_FRAMES)
	{
		return false;
	}

	for (new i = 0;i < count;i++)
	{
		s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_FRAMES][i] = frames[i];
	}

	s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_COUNT] = count;
	s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_LIFT] = lift;
	return true;
}

static Work_GetNodeFxRule(nodeid)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(g_WorkNodes[nodeid][E_WORK_NODE_KIND],key);
	new rule = Work_FindKindRule(key);
	return rule != -1 && s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_COUNT] > 0 ? rule : -1;
}

stock Work_GetNodeFxModel(nodeid)
{
	if (!IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_FX]))
	{
		return 0;
	}

	return Streamer_GetIntData(STREAMER_TYPE_OBJECT,g_WorkNodes[nodeid][E_WORK_NODE_FX],E_STREAMER_MODEL_ID);
}

stock bool:Work_KindHasReach(kind)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);
	new rule = Work_FindKindRule(key);
	return rule != -1 && s_WorkKindRules[rule][E_WORK_KIND_RULE_REACH] > 0.0;
}

static bool:Work_HasSightTool(playerid,const key[])
{
	new rule = Work_FindKindRule(key);

	if (rule == -1 || s_WorkKindRules[rule][E_WORK_KIND_RULE_SIGHT_TOOL] == -1)
	{
		return true;
	}

	new tool = s_WorkKindRules[rule][E_WORK_KIND_RULE_SIGHT_TOOL];
	return Inventory_Count(playerid,Item_GetDefKind(tool),tool) > 0;
}

static bool:Work_IsKindSighted(const key[])
{
	new rule = Work_FindKindRule(key);
	return rule != -1 && s_WorkKindRules[rule][E_WORK_KIND_RULE_SIGHT_TOOL] != -1;
}

static bool:Work_SeesNodeKind(playerid,const key[])
{
	return (!Talent_IsKindHidden(key) || Talent_SeesKind(playerid,key)) && Work_HasSightTool(playerid,key);
}

stock Work_FindReachNode(playerid,Float:x,Float:y,Float:z,world)
{
	new best = -1, Float:bestDistance = 1000.0, Float:facing, key[WORK_KIND_KEY_LEN];
	GetPlayerFacingAngle(playerid,facing);

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (!g_WorkNodes[i][E_WORK_NODE_USED] || g_WorkNodes[i][E_WORK_NODE_WORLD] != world)
		{
			continue;
		}

		Work_GetKindKey(g_WorkNodes[i][E_WORK_NODE_KIND],key);
		new rule = Work_FindKindRule(key);

		if (rule == -1 || s_WorkKindRules[rule][E_WORK_KIND_RULE_REACH] <= 0.0)
		{
			continue;
		}

		new Float:dx = g_WorkNodes[i][E_WORK_NODE_POS][0] - x, Float:dy = g_WorkNodes[i][E_WORK_NODE_POS][1] - y, Float:d = VectorSize(dx,dy,0.0);

		if (d > s_WorkKindRules[rule][E_WORK_KIND_RULE_REACH] || d >= bestDistance || floatabs(g_WorkNodes[i][E_WORK_NODE_POS][2] - z) > WORK_REACH_LEVEL)
		{
			continue;
		}

		new Float:off = floatabs(facing - (atan2(dy,dx) - 90.0));

		while (off > 180.0)
		{
			off = floatabs(off - 360.0);
		}

		if (off <= WORK_REACH_FACING)
		{
			best = i;
			bestDistance = d;
		}
	}

	return best;
}

static Work_ApplyNodeFxViewers(nodeid)
{
	new STREAMER_TAG_OBJECT:fx = g_WorkNodes[nodeid][E_WORK_NODE_FX], key[WORK_KIND_KEY_LEN];

	if (!IsValidDynamicObject(fx))
	{
		return;
	}

	Work_GetKindKey(g_WorkNodes[nodeid][E_WORK_NODE_KIND],key);
	g_WorkNodes[nodeid][E_WORK_NODE_FX_HIDDEN] = Talent_IsKindHidden(key) || Work_IsKindSighted(key);

	if (!g_WorkNodes[nodeid][E_WORK_NODE_FX_HIDDEN])
	{
		return;
	}

	new nobody[1] = {INVALID_PLAYER_ID};
	Streamer_SetArrayData(STREAMER_TYPE_OBJECT,fx,E_STREAMER_PLAYER_ID,nobody);

	foreach (new playerid : Player)
	{
		if (Work_SeesNodeKind(playerid,key))
		{
			Streamer_AppendArrayData(STREAMER_TYPE_OBJECT,fx,E_STREAMER_PLAYER_ID,playerid);
		}
	}
}

stock Work_RefreshNodeFxFor(playerid,bool:isLeaving = false)
{
	new key[WORK_KIND_KEY_LEN];

	for (new i = 0;i < s_WorkKindRuleCount;i++)
	{
		s_WorkHadSightTool[playerid][i] = !isLeaving && s_WorkKindRules[i][E_WORK_KIND_RULE_SIGHT_TOOL] != -1 && Work_HasSightTool(playerid,s_WorkKindRules[i][E_WORK_KIND_RULE_KEY]);
	}

	for (new nodeid = 0;nodeid < WORK_MAX_NODES;nodeid++)
	{
		if (!g_WorkNodes[nodeid][E_WORK_NODE_USED] || !g_WorkNodes[nodeid][E_WORK_NODE_FX_HIDDEN] || !IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_FX]))
		{
			continue;
		}

		Work_GetKindKey(g_WorkNodes[nodeid][E_WORK_NODE_KIND],key);

		if (!isLeaving && Work_SeesNodeKind(playerid,key))
		{
			Streamer_AppendArrayData(STREAMER_TYPE_OBJECT,g_WorkNodes[nodeid][E_WORK_NODE_FX],E_STREAMER_PLAYER_ID,playerid);
		}
		else
		{
			Streamer_RemoveArrayData(STREAMER_TYPE_OBJECT,g_WorkNodes[nodeid][E_WORK_NODE_FX],E_STREAMER_PLAYER_ID,playerid);
		}
	}

	if (!isLeaving)
	{
		Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
	}
}

stock bool:Work_CanSeeNodeFx(playerid,nodeid)
{
	return Work_IsValidNode(nodeid) && IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_FX]) && Streamer_IsInArrayData(STREAMER_TYPE_OBJECT,g_WorkNodes[nodeid][E_WORK_NODE_FX],E_STREAMER_PLAYER_ID,playerid) != 0;
}

static Work_RefreshNodeModel(nodeid)
{
	if (IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_OBJECT]))
	{
		DestroyDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_OBJECT]);
	}

	g_WorkNodes[nodeid][E_WORK_NODE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	Work_ClearNodeFx(nodeid);

	if (g_WorkNodes[nodeid][E_WORK_NODE_STOCK] > 0)
	{
		new Float:height = Work_GetNodeHeight(g_WorkNodes[nodeid][E_WORK_NODE_KIND],g_WorkNodes[nodeid][E_WORK_NODE_STOCK],g_WorkNodes[nodeid][E_WORK_NODE_MAX_STOCK]), rule = Work_GetNodeFxRule(nodeid);
		new fxModel = rule == -1 ? WORK_NODE_FX_MODEL : s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_FRAMES][s_WorkNodeFxFrame % s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_COUNT]], Float:fxZ = rule == -1 ? g_WorkNodes[nodeid][E_WORK_NODE_POS][2] + height * 0.5 - WORK_NODE_FX_EMITTER : g_WorkNodes[nodeid][E_WORK_NODE_POS][2] + s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_LIFT];
		g_WorkNodes[nodeid][E_WORK_NODE_FX_RULE] = rule;
		g_WorkNodes[nodeid][E_WORK_NODE_FX] = CreateDynamicObject(fxModel,g_WorkNodes[nodeid][E_WORK_NODE_POS][0],g_WorkNodes[nodeid][E_WORK_NODE_POS][1],fxZ,0.0,0.0,float(random(360)),g_WorkNodes[nodeid][E_WORK_NODE_WORLD],g_WorkNodes[nodeid][E_WORK_NODE_INTERIOR],-1,WORK_NODE_FX_RANGE,WORK_NODE_FX_RANGE);
		Work_ApplyNodeFxViewers(nodeid);
	}

	new model = Work_GetNodeSpeciesModel(nodeid);

	if (model == WORK_NO_MODEL)
	{
		return;
	}

	g_WorkNodes[nodeid][E_WORK_NODE_OBJECT] = CreateDynamicObject(model,g_WorkNodes[nodeid][E_WORK_NODE_POS][0],g_WorkNodes[nodeid][E_WORK_NODE_POS][1],g_WorkNodes[nodeid][E_WORK_NODE_POS][2],0.0,0.0,g_WorkNodes[nodeid][E_WORK_NODE_POS][3],g_WorkNodes[nodeid][E_WORK_NODE_WORLD],g_WorkNodes[nodeid][E_WORK_NODE_INTERIOR],-1,WORK_NODE_STREAM_DISTANCE,WORK_NODE_STREAM_DISTANCE);
	Work_StreamNear(g_WorkNodes[nodeid][E_WORK_NODE_POS][0],g_WorkNodes[nodeid][E_WORK_NODE_POS][1],g_WorkNodes[nodeid][E_WORK_NODE_POS][2],g_WorkNodes[nodeid][E_WORK_NODE_WORLD]);
}

static Work_ClearNode(nodeid)
{
	if (IsValidDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_OBJECT]))
	{
		DestroyDynamicObject(g_WorkNodes[nodeid][E_WORK_NODE_OBJECT]);
	}

	Work_ClearNodeFx(nodeid);
	Work_ClearNodeDecor(nodeid);

	g_WorkNodes[nodeid][E_WORK_NODE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	g_WorkNodes[nodeid][E_WORK_NODE_USED] = false;
	g_WorkNodes[nodeid][E_WORK_NODE_ROW] = 0;
	g_WorkNodes[nodeid][E_WORK_NODE_WORKER] = INVALID_PLAYER_ID;
	g_WorkNodes[nodeid][E_WORK_NODE_HOLDER] = 0;
	g_WorkNodes[nodeid][E_WORK_NODE_SPOT] = -1;
}

static Work_AddNode(row,kind,species,Float:x,Float:y,Float:z,Float:a,world,interior,stockLeft,maxStock,regrowLeft,holder,spot)
{
	new nodeid = -1;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (!g_WorkNodes[i][E_WORK_NODE_USED])
		{
			nodeid = i;
			break;
		}
	}

	if (nodeid == -1)
	{
		Log_Error("workstations","node table full at %d",WORK_MAX_NODES);
		return -1;
	}

	Work_ClearNode(nodeid);
	g_WorkNodes[nodeid][E_WORK_NODE_USED] = true;
	g_WorkNodes[nodeid][E_WORK_NODE_ROW] = row;
	g_WorkNodes[nodeid][E_WORK_NODE_KIND] = kind;
	g_WorkNodes[nodeid][E_WORK_NODE_SPECIES] = species;
	g_WorkNodes[nodeid][E_WORK_NODE_POS][0] = x;
	g_WorkNodes[nodeid][E_WORK_NODE_POS][1] = y;
	g_WorkNodes[nodeid][E_WORK_NODE_POS][2] = z;
	g_WorkNodes[nodeid][E_WORK_NODE_POS][3] = a;
	g_WorkNodes[nodeid][E_WORK_NODE_WORLD] = world;
	g_WorkNodes[nodeid][E_WORK_NODE_INTERIOR] = interior;
	g_WorkNodes[nodeid][E_WORK_NODE_STOCK] = stockLeft;
	g_WorkNodes[nodeid][E_WORK_NODE_MAX_STOCK] = maxStock;
	g_WorkNodes[nodeid][E_WORK_NODE_REGROW_LEFT] = regrowLeft;
	g_WorkNodes[nodeid][E_WORK_NODE_HOLDER] = holder;
	g_WorkNodes[nodeid][E_WORK_NODE_SPOT] = spot;
	Work_RefreshNodeModel(nodeid);
	Work_PlaceNodeDecor(nodeid);
	Work_BumpLayoutRevision();
	return nodeid;
}

#pragma warning push
#pragma warning disable 204
forward Task:Work_CreateNode(kind,Float:x,Float:y,Float:z,Float:a,world,interior,spot = -1,species = 0);

async Task:Work_CreateNode(kind,Float:x,Float:y,Float:z,Float:a,world,interior,spot = -1,species = 0)
{
	new key[WORK_KIND_KEY_LEN], maxStock = Work_GetKindStock(kind);
	Work_GetKindKey(kind,key);

	if (!strcmp(key,"herbs") && species <= 0)
	{
		species = 1 + Work_RollHerb(spot >= 0 && spot < WORK_SPOT_COUNT ? g_WorkSpotDefs[spot][E_WORK_SPOT_DEF_HABITAT] : WORK_HERB_ALL_HABITATS,Calendar_GetSeason());

		if (species <= 0)
		{
			return async -1;
		}
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO work_nodes (kind, species, x, y, z, a, world, interior, stock, max_stock, regrow_left, spot) VALUES ('%e', %d, %f, %f, %f, %f, %d, %d, %d, %d, 0, %d)",key,species,x,y,z,a,world,interior,maxStock,maxStock,spot));

	new row = cache_insert_id();
	return async row > 0 ? Work_AddNode(row,kind,species,x,y,z,a,world,interior,maxStock,maxStock,0,0,spot) : -1;
}
#pragma warning pop

static Work_SaveNodeStock(nodeid)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE work_nodes SET stock = %d, regrow_left = %d WHERE id = %d",g_WorkNodes[nodeid][E_WORK_NODE_STOCK],g_WorkNodes[nodeid][E_WORK_NODE_REGROW_LEFT],g_WorkNodes[nodeid][E_WORK_NODE_ROW]));
}

stock bool:Work_TakeNodeStock(nodeid)
{
	if (!Work_IsValidNode(nodeid) || g_WorkNodes[nodeid][E_WORK_NODE_STOCK] <= 0)
	{
		return false;
	}

	g_WorkNodes[nodeid][E_WORK_NODE_STOCK]--;

	if (g_WorkNodes[nodeid][E_WORK_NODE_REGROW_LEFT] <= 0)
	{
		g_WorkNodes[nodeid][E_WORK_NODE_REGROW_LEFT] = Work_GetKindRegrowHours(g_WorkNodes[nodeid][E_WORK_NODE_KIND]);
	}

	Work_RefreshNodeModel(nodeid);
	Work_SaveNodeStock(nodeid);

	if (g_WorkNodes[nodeid][E_WORK_NODE_STOCK] == 0 && g_WorkNodes[nodeid][E_WORK_NODE_SPOT] != -1)
	{
		Work_WildOnEmptied(nodeid);
	}

	return true;
}

stock Work_RefillNode(nodeid)
{
	if (!Work_IsValidNode(nodeid))
	{
		return;
	}

	g_WorkNodes[nodeid][E_WORK_NODE_STOCK] = g_WorkNodes[nodeid][E_WORK_NODE_MAX_STOCK];
	g_WorkNodes[nodeid][E_WORK_NODE_REGROW_LEFT] = 0;
	Work_RefreshNodeModel(nodeid);
	Work_SaveNodeStock(nodeid);
}

stock Work_RegrowNodes(hours = 1)
{
	new regrown = 0;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (!g_WorkNodes[i][E_WORK_NODE_USED] || g_WorkNodes[i][E_WORK_NODE_SPOT] != -1 || g_WorkNodes[i][E_WORK_NODE_STOCK] >= g_WorkNodes[i][E_WORK_NODE_MAX_STOCK])
		{
			continue;
		}

		g_WorkNodes[i][E_WORK_NODE_REGROW_LEFT] -= hours;

		if (g_WorkNodes[i][E_WORK_NODE_REGROW_LEFT] <= 0)
		{
			g_WorkNodes[i][E_WORK_NODE_STOCK]++;
			g_WorkNodes[i][E_WORK_NODE_REGROW_LEFT] = g_WorkNodes[i][E_WORK_NODE_STOCK] < g_WorkNodes[i][E_WORK_NODE_MAX_STOCK] ? Work_GetKindRegrowHours(g_WorkNodes[i][E_WORK_NODE_KIND]) : 0;
			Work_RefreshNodeModel(i);
			regrown++;
		}

		Work_SaveNodeStock(i);
	}

	return regrown;
}

stock Work_DeleteNode(nodeid)
{
	if (!Work_IsValidNode(nodeid))
	{
		return;
	}

	pawn_call_public("Work_OnNodeChanged","d",nodeid);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM work_nodes WHERE id = %d",g_WorkNodes[nodeid][E_WORK_NODE_ROW]));
	Work_ClearNode(nodeid);
	Work_BumpLayoutRevision();
}

stock Work_FindNearestNode(Float:x,Float:y,Float:z,world,Float:range,&Float:distance = 0.0)
{
	new best = -1;
	distance = range;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		if (!g_WorkNodes[i][E_WORK_NODE_USED] || g_WorkNodes[i][E_WORK_NODE_WORLD] != world)
		{
			continue;
		}

		new Float:d = Util_GetDistance3D(x,y,z,g_WorkNodes[i][E_WORK_NODE_POS][0],g_WorkNodes[i][E_WORK_NODE_POS][1],g_WorkNodes[i][E_WORK_NODE_POS][2]);

		if (d < distance)
		{
			distance = d;
			best = i;
		}
	}

	return best;
}

forward Work_LoadNodesOnBoot();

public Work_LoadNodesOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, species, x, y, z, a, world, interior, stock, max_stock, regrow_left, IFNULL(holder_character_id, 0) AS holder, spot FROM work_nodes ORDER BY id"));

	new placed = 0, skipped = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, key[WORK_KIND_KEY_LEN], species, Float:pos[4], world, interior, stockLeft, maxStock, regrowLeft, holder, spot;
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"kind",key);
		cache_get_value_name_int(r,"species",species);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);
		cache_get_value_name_int(r,"stock",stockLeft);
		cache_get_value_name_int(r,"max_stock",maxStock);
		cache_get_value_name_int(r,"regrow_left",regrowLeft);
		cache_get_value_name_int(r,"holder",holder);
		cache_get_value_name_int(r,"spot",spot);

		new kind = Work_FindKind(key);

		if (kind == -1 || !Work_IsNodeKind(kind) || Work_AddNode(row,kind,species,pos[0],pos[1],pos[2],pos[3],world,interior,stockLeft,maxStock,regrowLeft,holder,spot) == -1)
		{
			skipped++;
			continue;
		}

		placed++;
	}

	Log_Info("workstations","%d node(s) placed, %d skipped",placed,skipped);
	Boot_LoaderDone();
}

forward Work_OnNodeChanged(nodeid);

public Work_OnNodeChanged(nodeid)
{
	return 1;
}

Timer_Declare(Work_NodeFxTimer)
{
	s_WorkNodeFxFrame++;

	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		new rule = g_WorkNodes[i][E_WORK_NODE_FX_RULE];

		if (rule == -1 || s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_COUNT] < 2 || !IsValidDynamicObject(g_WorkNodes[i][E_WORK_NODE_FX]))
		{
			continue;
		}

		Streamer_SetIntData(STREAMER_TYPE_OBJECT,g_WorkNodes[i][E_WORK_NODE_FX],E_STREAMER_MODEL_ID,s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_FRAMES][(s_WorkNodeFxFrame + i) % s_WorkKindRules[rule][E_WORK_KIND_RULE_FX_COUNT]]);
	}

	return true;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0;i < WORK_MAX_NODES;i++)
	{
		g_WorkNodes[i][E_WORK_NODE_OBJECT] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		g_WorkNodes[i][E_WORK_NODE_FX] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		Work_ClearNode(i);
	}

	Timer_Start(Work_NodeFxTimer,WORK_NODE_FX_FRAME_MS);
}

hook Talent_OnLoaded(playerid)
{
	Work_RefreshNodeFxFor(playerid);
}

hook Talent_OnUnlocked(playerid,node)
{
	if (!Talent_IsStationNode(node))
	{
		Work_RefreshNodeFxFor(playerid);
	}
}

hook OnPlayerDisconnect(playerid,reason)
{
	Work_RefreshNodeFxFor(playerid,true);
}

hook Inventory_OnChanged(playerid)
{
	new bool:changed = false;

	for (new i = 0;i < s_WorkKindRuleCount;i++)
	{
		if (s_WorkKindRules[i][E_WORK_KIND_RULE_SIGHT_TOOL] == -1)
		{
			continue;
		}

		new bool:has = Work_HasSightTool(playerid,s_WorkKindRules[i][E_WORK_KIND_RULE_KEY]);

		if (has != s_WorkHadSightTool[playerid][i])
		{
			s_WorkHadSightTool[playerid][i] = has;
			changed = true;
		}
	}

	if (changed)
	{
		Work_RefreshNodeFxFor(playerid);
	}
}

hook Calendar_OnHour(hour)
{
	#pragma unused hour
	Work_RegrowNodes(1);
}
