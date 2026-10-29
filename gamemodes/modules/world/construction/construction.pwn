enum E_BUILD_PROJECT
{
	bool:E_BUILD_USED,
	E_BUILD_ROW,
	E_BUILD_BUILDING,
	E_BUILD_KIND,
	E_BUILD_COMMISSIONER,
	E_BUILD_STOCKPILE,
	E_BUILD_STAGE_COUNT,
	E_BUILD_STAGE[BUILD_STAGES_MAX],
	E_BUILD_NEED[BUILD_STAGES_MAX],
	E_BUILD_DONE[BUILD_STAGES_MAX],
	bool:E_BUILD_FINISHED,
	E_BUILD_CREATED,
}

static s_BuildProjects[BUILD_PROJECTS_MAX][E_BUILD_PROJECT];
static s_BuildCondition[FIRE_SEED_BUILDINGS] = {BUILD_CONDITION_MAX, ...};
static bool:s_BuildTiled[FIRE_SEED_BUILDINGS];
static s_BuildDawns;
static STREAMER_TAG_3D_TEXT_LABEL:s_BuildLabels[FIRE_SEED_BUILDINGS] = {STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID, ...};

forward Task:Build_Start(building,kind,commissioner);
forward Task:Build_Load();
forward bool:Build_ReleaseIfEmpty(project);

stock Build_GetCondition(building)
{
	return Fire_IsValid(building) ? s_BuildCondition[building] : 0;
}

stock bool:Build_IsDamaged(building)
{
	return Fire_IsValid(building) && !Fire_IsGutted(building) && s_BuildCondition[building] < BUILD_DAMAGED_AT;
}

stock bool:Build_IsTiled(building)
{
	return Fire_IsValid(building) && s_BuildTiled[building];
}

stock Build_ConditionWord(building,dest[],size = sizeof(dest))
{
	new condition = Build_GetCondition(building);

	if (Fire_IsGutted(building))
	{
		strcopy(dest,"burnt out",size);
	}
	else if (condition >= 85)
	{
		strcopy(dest,"sound",size);
	}
	else if (condition >= BUILD_DAMAGED_AT)
	{
		strcopy(dest,"weathered",size);
	}
	else if (condition >= BUILD_POOR_AT)
	{
		strcopy(dest,"in need of repair",size);
	}
	else
	{
		strcopy(dest,"falling apart",size);
	}
}

static Build_SaveBuilding(building)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO buildings (building_key, county_id, x, y, z, radius, flammable, state, `condition`, roof) VALUES ('%e', %d, %f, %f, %f, %f, 1, 0, %d, %d) ON DUPLICATE KEY UPDATE `condition` = VALUES(`condition`), roof = VALUES(roof)",g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],REALM_COUNTY,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][2],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_REACH],s_BuildCondition[building],_:s_BuildTiled[building]));
}

stock Build_SetCondition(building,condition,bool:isSaved = true)
{
	if (!Fire_IsValid(building))
	{
		return;
	}

	s_BuildCondition[building] = Util_ClampInt(condition,0,BUILD_CONDITION_MAX);
	Fire_SetFrailty(building,s_BuildCondition[building] < BUILD_DAMAGED_AT ? (BUILD_DAMAGED_AT - s_BuildCondition[building]) / 3 : 0);
	Build_RefreshLabel(building);

	if (isSaved)
	{
		Build_SaveBuilding(building);
	}
}

stock Build_SetTiled(building,bool:isTiled,bool:isSaved = true)
{
	if (!Fire_IsValid(building))
	{
		return;
	}

	s_BuildTiled[building] = isTiled;
	Fire_SetTiled(building,isTiled);

	if (isSaved)
	{
		Build_SaveBuilding(building);
	}
}

stock bool:Build_IsProject(project)
{
	return project >= 0 && project < BUILD_PROJECTS_MAX && s_BuildProjects[project][E_BUILD_USED];
}

stock Build_FindProject(building)
{
	for (new project = 0;project < BUILD_PROJECTS_MAX;project++)
	{
		if (s_BuildProjects[project][E_BUILD_USED] && s_BuildProjects[project][E_BUILD_BUILDING] == building)
		{
			return project;
		}
	}

	return -1;
}

stock Build_CountProjects()
{
	new count = 0;

	for (new project = 0;project < BUILD_PROJECTS_MAX;project++)
	{
		if (s_BuildProjects[project][E_BUILD_USED])
		{
			count++;
		}
	}

	return count;
}

stock Build_GetRow(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_ROW] : 0;
}

stock Build_GetBuilding(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_BUILDING] : -1;
}

stock Build_GetKind(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_KIND] : -1;
}

stock Build_GetStockpile(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_STOCKPILE] : INVALID_CONTAINER_ID;
}

stock Build_GetCommissioner(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_COMMISSIONER] : 0;
}

stock bool:Build_IsFinished(project)
{
	return Build_IsProject(project) && s_BuildProjects[project][E_BUILD_FINISHED];
}

stock Build_GetStageCount(project)
{
	return Build_IsProject(project) ? s_BuildProjects[project][E_BUILD_STAGE_COUNT] : 0;
}

stock Build_GetStage(project,index,&stage,&need,&done)
{
	if (!Build_IsProject(project) || index < 0 || index >= s_BuildProjects[project][E_BUILD_STAGE_COUNT])
	{
		stage = -1;
		need = 0;
		done = 0;
		return;
	}

	stage = s_BuildProjects[project][E_BUILD_STAGE][index];
	need = s_BuildProjects[project][E_BUILD_NEED][index];
	done = s_BuildProjects[project][E_BUILD_DONE][index];
}

stock Build_GetProgress(project,&done,&total)
{
	done = 0;
	total = 0;

	for (new i = 0;Build_IsProject(project) && i < s_BuildProjects[project][E_BUILD_STAGE_COUNT];i++)
	{
		done += min(s_BuildProjects[project][E_BUILD_DONE][i],s_BuildProjects[project][E_BUILD_NEED][i]);
		total += s_BuildProjects[project][E_BUILD_NEED][i];
	}
}

stock Build_Plan(building,kind,stages[],needs[])
{
	new count = 0;

	if (kind == BUILD_KIND_REPAIR)
	{
		new damage = BUILD_CONDITION_MAX - Build_GetCondition(building), units = max(1,(damage + BUILD_REPAIR_UNIT - 1) / BUILD_REPAIR_UNIT);
		stages[count] = BUILD_STAGE_FRAME;
		needs[count++] = units;
		stages[count] = Build_IsTiled(building) ? BUILD_STAGE_RETILE : BUILD_STAGE_THATCH;
		needs[count++] = units;
		stages[count] = BUILD_STAGE_STONE;
		needs[count++] = max(1,units / 2);
	}
	else if (kind == BUILD_KIND_TILE_ROOF)
	{
		stages[count] = BUILD_STAGE_STRIP;
		needs[count++] = 2;
		stages[count] = BUILD_STAGE_LATH;
		needs[count++] = 3;
		stages[count] = BUILD_STAGE_MORTAR;
		needs[count++] = 2;
		stages[count] = BUILD_STAGE_TILE;
		needs[count++] = 4;
	}

	return count;
}

stock bool:Build_StageReady(project,index)
{
	new stage, need, done;
	Build_GetStage(project,index,stage,need,done);

	if (stage == -1 || done >= need)
	{
		return false;
	}

	new stockpile = s_BuildProjects[project][E_BUILD_STOCKPILE];

	for (new m = 0;m < 2;m++)
	{
		new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m], amount = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m];

		if (item != -1 && amount > 0 && Container_Count(stockpile,Item_GetDefKind(item),item) < amount)
		{
			return false;
		}
	}

	return true;
}

stock bool:Build_TakeMaterials(project,stage)
{
	new stockpile = s_BuildProjects[project][E_BUILD_STOCKPILE];

	for (new m = 0;m < 2;m++)
	{
		new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m];

		if (item != -1 && Container_Count(stockpile,Item_GetDefKind(item),item) < g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m])
		{
			return false;
		}
	}

	for (new m = 0;m < 2;m++)
	{
		new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m], amount = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m];

		if (item != -1 && amount > 0)
		{
			Container_Take(stockpile,Item_GetDefKind(item),item,amount);
		}
	}

	return true;
}

stock Build_ReturnMaterials(project,stage)
{
	new stockpile = s_BuildProjects[project][E_BUILD_STOCKPILE];

	for (new m = 0;m < 2;m++)
	{
		new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m], amount = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m];

		if (item != -1 && amount > 0)
		{
			Container_Add(stockpile,Item_GetDefKind(item),item,amount);
		}
	}
}

stock Build_DescribeNeeds(project,dest[],size = sizeof(dest))
{
	new items[BUILD_STAGES_MAX * 2], amounts[BUILD_STAGES_MAX * 2], count = 0, stockpile = s_BuildProjects[project][E_BUILD_STOCKPILE];
	dest[0] = EOS;

	for (new i = 0;Build_IsProject(project) && i < s_BuildProjects[project][E_BUILD_STAGE_COUNT];i++)
	{
		new stage = s_BuildProjects[project][E_BUILD_STAGE][i], left = s_BuildProjects[project][E_BUILD_NEED][i] - s_BuildProjects[project][E_BUILD_DONE][i];

		for (new m = 0;m < 2 && left > 0;m++)
		{
			new item = g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_ITEM][m], found = -1;

			if (item == -1)
			{
				continue;
			}

			for (new j = 0;j < count;j++)
			{
				if (items[j] == item)
				{
					found = j;
				}
			}

			if (found == -1)
			{
				found = count++;
				items[found] = item;
				amounts[found] = 0;
			}

			amounts[found] += left * g_BuildStageDefs[stage][E_BUILD_STAGE_DEF_AMOUNT][m];
		}
	}

	for (new j = 0;j < count;j++)
	{
		new want = amounts[j] - Container_Count(stockpile,Item_GetDefKind(items[j]),items[j]), name[ITEM_NAME_LEN];

		if (want <= 0)
		{
			continue;
		}

		Item_GetName(Item_GetDefKind(items[j]),items[j],name);
		format(dest,size,"%s%s%d %s",dest,dest[0] != EOS ? (", ") : (""),want,name);
	}

	if (dest[0] == EOS)
	{
		strcopy(dest,"nothing more",size);
	}
}

stock Build_RefreshLabel(building)
{
	if (IsValidDynamic3DTextLabel(s_BuildLabels[building]))
	{
		DestroyDynamic3DTextLabel(s_BuildLabels[building]);
	}

	s_BuildLabels[building] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;
	new project = Build_FindProject(building), text[96];

	if (project != -1 && !s_BuildProjects[project][E_BUILD_FINISHED])
	{
		new done, total;
		Build_GetProgress(project,done,total);
		format(text,sizeof(text),"Building work: %s (%d of %d turns done)",g_BuildKindNames[s_BuildProjects[project][E_BUILD_KIND]],done,total);
	}
	else if (Build_IsDamaged(building))
	{
		Build_ConditionWord(building,text);
		text[0] = toupper(text[0]);
	}
	else
	{
		return;
	}

	s_BuildLabels[building] = CreateDynamic3DTextLabel(text,0xC9B27CFF,g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][0],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_ROOF][1],g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_DOOR][2] + 2.2,14.0,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,0,0);
}

#pragma warning push
#pragma warning disable 204
async Task:Build_Start(building,kind,commissioner)
{
	if (!Fire_IsValid(building) || Fire_IsGutted(building) || Build_FindProject(building) != -1 || kind < 0 || kind >= BUILD_KIND_COUNT || (kind == BUILD_KIND_TILE_ROOF && Build_IsTiled(building)))
	{
		wait_ticks(1);
		return async -1;
	}

	new project = -1;

	for (new i = 0;i < BUILD_PROJECTS_MAX;i++)
	{
		if (!s_BuildProjects[i][E_BUILD_USED])
		{
			project = i;
			break;
		}
	}

	if (project == -1)
	{
		wait_ticks(1);
		return async -1;
	}

	s_BuildProjects[project][E_BUILD_USED] = true;
	s_BuildProjects[project][E_BUILD_ROW] = 0;
	s_BuildProjects[project][E_BUILD_BUILDING] = building;
	s_BuildProjects[project][E_BUILD_KIND] = kind;
	s_BuildProjects[project][E_BUILD_COMMISSIONER] = commissioner;
	s_BuildProjects[project][E_BUILD_STOCKPILE] = INVALID_CONTAINER_ID;
	s_BuildProjects[project][E_BUILD_FINISHED] = false;
	s_BuildProjects[project][E_BUILD_CREATED] = gettime();
	new stages[BUILD_STAGES_MAX], needs[BUILD_STAGES_MAX], count = Build_Plan(building,kind,stages,needs);
	s_BuildProjects[project][E_BUILD_STAGE_COUNT] = count;

	for (new i = 0;i < count;i++)
	{
		s_BuildProjects[project][E_BUILD_STAGE][i] = stages[i];
		s_BuildProjects[project][E_BUILD_NEED][i] = needs[i];
		s_BuildProjects[project][E_BUILD_DONE][i] = 0;
	}

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO build_projects (building_key, kind, commissioned_by, stockpile_container_id, stage, state, created_at, done_at) VALUES ('%e', %d, %d, 0, 0, 0, %d, 0)",g_FireBuildingDefs[building][E_FIRE_BUILDING_DEF_KEY],kind,commissioner,s_BuildProjects[project][E_BUILD_CREATED]));
	new row = cache_insert_id(), label[40];

	if (row <= 0 || !s_BuildProjects[project][E_BUILD_USED] || s_BuildProjects[project][E_BUILD_BUILDING] != building)
	{
		return async -1;
	}

	s_BuildProjects[project][E_BUILD_ROW] = row;

	for (new i = 0;i < count;i++)
	{
		mysql_tquery_s(g_Mysql,str_format("INSERT INTO project_stages (project_id, idx, stage, need, done) VALUES (%d, %d, %d, %d, 0)",row,i,stages[i],needs[i]));
	}

	format(label,sizeof(label),"Building stockpile");
	new stockpile = await Container_Create(CONTAINER_OWNER_SITE,row,BUILD_STOCKPILE_SLOTS,label);

	if (!s_BuildProjects[project][E_BUILD_USED] || s_BuildProjects[project][E_BUILD_ROW] != row)
	{
		return async -1;
	}

	if (stockpile != INVALID_CONTAINER_ID)
	{
		await Container_Load(stockpile);
	}

	s_BuildProjects[project][E_BUILD_STOCKPILE] = stockpile;
	mysql_tquery_s(g_Mysql,str_format("UPDATE build_projects SET stockpile_container_id = %d WHERE id = %d",stockpile,row));
	Build_RefreshLabel(building);
	pawn_call_public("Build_OnStarted","dd",building,kind);
	return async project;
}
#pragma warning pop

stock bool:Build_AddTurn(project,index,characterid)
{
	if (!Build_IsProject(project) || s_BuildProjects[project][E_BUILD_FINISHED] || index < 0 || index >= s_BuildProjects[project][E_BUILD_STAGE_COUNT] || s_BuildProjects[project][E_BUILD_DONE][index] >= s_BuildProjects[project][E_BUILD_NEED][index])
	{
		return false;
	}

	new row = s_BuildProjects[project][E_BUILD_ROW];
	s_BuildProjects[project][E_BUILD_DONE][index]++;

	if (row > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE project_stages SET done = %d WHERE project_id = %d AND idx = %d",s_BuildProjects[project][E_BUILD_DONE][index],row,index));

		if (characterid > 0)
		{
			mysql_tquery_s(g_Mysql,str_format("INSERT INTO project_labour (project_id, character_id, scenes) VALUES (%d, %d, 1) ON DUPLICATE KEY UPDATE scenes = scenes + 1",row,characterid));
		}
	}

	new done, total;
	Build_GetProgress(project,done,total);

	if (done >= total)
	{
		Build_Finish(project);
	}
	else
	{
		Build_RefreshLabel(s_BuildProjects[project][E_BUILD_BUILDING]);
	}

	return true;
}

stock Build_Finish(project)
{
	if (!Build_IsProject(project) || s_BuildProjects[project][E_BUILD_FINISHED])
	{
		return;
	}

	new building = s_BuildProjects[project][E_BUILD_BUILDING], kind = s_BuildProjects[project][E_BUILD_KIND];
	s_BuildProjects[project][E_BUILD_FINISHED] = true;

	if (kind == BUILD_KIND_TILE_ROOF)
	{
		Build_SetTiled(building,true,false);
	}

	Build_SetCondition(building,BUILD_CONDITION_MAX);

	if (s_BuildProjects[project][E_BUILD_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE build_projects SET state = 1, done_at = %d WHERE id = %d",gettime(),s_BuildProjects[project][E_BUILD_ROW]));
	}

	pawn_call_public("Build_OnFinished","dd",building,kind);
	Build_ReleaseIfEmpty(project);
}

stock bool:Build_ReleaseIfEmpty(project)
{
	if (!Build_IsProject(project) || !s_BuildProjects[project][E_BUILD_FINISHED])
	{
		return false;
	}

	new stockpile = s_BuildProjects[project][E_BUILD_STOCKPILE];

	if (stockpile != INVALID_CONTAINER_ID && Container_GetCount(stockpile) > 0)
	{
		return false;
	}

	new building = s_BuildProjects[project][E_BUILD_BUILDING];

	if (stockpile != INVALID_CONTAINER_ID)
	{
		Container_Delete(stockpile);
	}

	s_BuildProjects[project][E_BUILD_USED] = false;
	s_BuildProjects[project][E_BUILD_STOCKPILE] = INVALID_CONTAINER_ID;
	Build_RefreshLabel(building);
	return true;
}

stock Build_Abandon(project)
{
	if (!Build_IsProject(project) || s_BuildProjects[project][E_BUILD_FINISHED])
	{
		return;
	}

	s_BuildProjects[project][E_BUILD_FINISHED] = true;

	if (s_BuildProjects[project][E_BUILD_ROW] > 0)
	{
		mysql_tquery_s(g_Mysql,str_format("UPDATE build_projects SET state = 2, done_at = %d WHERE id = %d",gettime(),s_BuildProjects[project][E_BUILD_ROW]));
	}

	Build_ReleaseIfEmpty(project);
	Build_RefreshLabel(s_BuildProjects[project][E_BUILD_BUILDING]);
}

stock Build_Decay(amount)
{
	for (new building = 0;building < FIRE_SEED_BUILDINGS;building++)
	{
		if (!Fire_IsGutted(building) && Build_FindProject(building) == -1)
		{
			Build_SetCondition(building,s_BuildCondition[building] - amount);
		}
	}
}

#pragma warning push
#pragma warning disable 204
async Task:Build_Load()
{
	await mysql_aquery_s(g_Mysql,str_new("SELECT building_key, `condition`, roof FROM buildings"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new key[16], condition, roof;
		cache_get_value_name(r,"building_key",key);
		cache_get_value_name_int(r,"condition",condition);
		cache_get_value_name_int(r,"roof",roof);
		new building = Fire_FindByKey(key);

		if (building != -1)
		{
			s_BuildTiled[building] = roof != 0;
			Fire_SetTiled(building,roof != 0);
			Build_SetCondition(building,condition,false);
		}
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, building_key, kind, commissioned_by, stockpile_container_id, state FROM build_projects WHERE state = 0 OR (state > 0 AND stockpile_container_id > 0 AND done_at > UNIX_TIMESTAMP() - 604800) ORDER BY id"));
	new rows = min(cache_num_rows(),BUILD_PROJECTS_MAX), ids[BUILD_PROJECTS_MAX], buildings[BUILD_PROJECTS_MAX], kinds[BUILD_PROJECTS_MAX], commissioners[BUILD_PROJECTS_MAX], stockpiles[BUILD_PROJECTS_MAX], states[BUILD_PROJECTS_MAX];

	for (new r = 0;r < rows;r++)
	{
		new key[16];
		cache_get_value_name_int(r,"id",ids[r]);
		cache_get_value_name(r,"building_key",key);
		cache_get_value_name_int(r,"kind",kinds[r]);
		cache_get_value_name_int(r,"commissioned_by",commissioners[r]);
		cache_get_value_name_int(r,"stockpile_container_id",stockpiles[r]);
		cache_get_value_name_int(r,"state",states[r]);
		buildings[r] = Fire_FindByKey(key);
	}

	new loaded = 0;

	for (new r = 0;r < rows;r++)
	{
		if (buildings[r] == -1 || Build_FindProject(buildings[r]) != -1)
		{
			continue;
		}

		new project = loaded++;
		s_BuildProjects[project][E_BUILD_USED] = true;
		s_BuildProjects[project][E_BUILD_ROW] = ids[r];
		s_BuildProjects[project][E_BUILD_BUILDING] = buildings[r];
		s_BuildProjects[project][E_BUILD_KIND] = Util_ClampInt(kinds[r],0,BUILD_KIND_COUNT - 1);
		s_BuildProjects[project][E_BUILD_COMMISSIONER] = commissioners[r];
		s_BuildProjects[project][E_BUILD_STOCKPILE] = stockpiles[r] > 0 ? stockpiles[r] : INVALID_CONTAINER_ID;
		s_BuildProjects[project][E_BUILD_FINISHED] = states[r] != 0;
		s_BuildProjects[project][E_BUILD_STAGE_COUNT] = 0;
		await mysql_aquery_s(g_Mysql,str_format("SELECT idx, stage, need, done FROM project_stages WHERE project_id = %d ORDER BY idx",ids[r]));

		for (new s = 0, stages = min(cache_num_rows(),BUILD_STAGES_MAX);s < stages;s++)
		{
			cache_get_value_name_int(s,"stage",s_BuildProjects[project][E_BUILD_STAGE][s]);
			cache_get_value_name_int(s,"need",s_BuildProjects[project][E_BUILD_NEED][s]);
			cache_get_value_name_int(s,"done",s_BuildProjects[project][E_BUILD_DONE][s]);
			s_BuildProjects[project][E_BUILD_STAGE_COUNT]++;
		}

		if (s_BuildProjects[project][E_BUILD_STOCKPILE] != INVALID_CONTAINER_ID)
		{
			await Container_Load(s_BuildProjects[project][E_BUILD_STOCKPILE]);
		}

		Build_RefreshLabel(buildings[r]);
	}

	return async loaded;
}
#pragma warning pop

forward Build_OnStarted(building,kind);

public Build_OnStarted(building,kind)
{
	return 1;
}

forward Build_OnFinished(building,kind);

public Build_OnFinished(building,kind)
{
	return 1;
}

#include <pp-hooks>

hook Calendar_OnDawn()
{
	if (++s_BuildDawns % BUILD_DECAY_EVERY_DAYS == 0)
	{
		Build_Decay(BUILD_DECAY_PER_DAY);
	}

	for (new project = 0;project < BUILD_PROJECTS_MAX;project++)
	{
		Build_ReleaseIfEmpty(project);
	}
}

#pragma warning push
#pragma warning disable 204
static async Task:Build_ReleaseLater(project,containerid)
{
	wait_ticks(1);

	if (Build_IsProject(project) && Build_GetStockpile(project) == containerid)
	{
		Build_ReleaseIfEmpty(project);
	}

	return async true;
}
#pragma warning pop

hook Container_OnChanged(containerid)
{
	for (new project = 0;project < BUILD_PROJECTS_MAX;project++)
	{
		if (Build_IsProject(project) && s_BuildProjects[project][E_BUILD_FINISHED] && s_BuildProjects[project][E_BUILD_STOCKPILE] == containerid && Container_GetCount(containerid) == 0)
		{
			Build_ReleaseLater(project,containerid);
			return;
		}
	}
}

hook Fire_OnOut(building)
{
	Build_SetCondition(building,Build_GetCondition(building) - BUILD_FIRE_DAMAGE);
}

hook Fire_OnGutted(building)
{
	new project = Build_FindProject(building);

	if (project != -1)
	{
		Build_Abandon(project);
	}

	Build_RefreshLabel(building);
}

hook Fire_OnRebuilt(building)
{
	Build_SetCondition(building,BUILD_CONDITION_MAX);
}

hook Disasters_OnBegin(kind,severity)
{
	if (kind == DISASTER_STORM)
	{
		Build_Decay(BUILD_STORM_DAMAGE * severity);
	}
}
