#define WORK_RESERVE_MAX (RECIPE_MAX_INPUTS * 4)
#define WORK_REASON_LEN (144)
#define WORK_FADE_MS (400)
#define WORK_LAUNCH_MS (250)
#define WORK_STAGE_FLOOR_MS (2000)
#define WORK_BETWEEN_MS (700)
#define WORK_ABORT_TICKS (20)
#define WORK_PROP_BOB (0.06)
#define WORK_FADE_COLOUR (0x000000FF)
#define WORK_CLEAR_COLOUR (0x00000000)

enum
{
	WORK_TARGET_NONE,
	WORK_TARGET_STATION,
	WORK_TARGET_NODE,
}

enum
{
	WORK_PHASE_NONE,
	WORK_PHASE_ENTER,
	WORK_PHASE_OFFER,
	WORK_PHASE_STAGE,
	WORK_PHASE_BETWEEN,
}

enum E_WORK_SCENE
{
	bool:E_WORK_SCENE_ACTIVE,
	E_WORK_SCENE_TARGET_TYPE,
	E_WORK_SCENE_TARGET,
	E_WORK_SCENE_RECIPE,
	E_WORK_SCENE_STAGE,
	E_WORK_SCENE_PHASE,
	E_WORK_SCENE_PHASE_AT,
	E_WORK_SCENE_SCORE_TOTAL,
	E_WORK_SCENE_SCORED,
	bool:E_WORK_SCENE_PERFECT,
	E_WORK_SCENE_TIMER,
	KEY:E_WORK_SCENE_KEYS,
	E_WORK_SCENE_N_TICKS,
	E_WORK_SCENE_EASE,
	E_WORK_SCENE_TICK,
	Float:E_WORK_SCENE_ANCHOR[4],
	E_WORK_SCENE_RESERVED,
}

forward bool:Work_CanUseStation(playerid,stationid);
forward bool:Work_IsStationRuined(stationid);

static s_WorkScene[MAX_PLAYERS][E_WORK_SCENE];

static const s_WorkMeasures[][3][24] = {
	{"bread", "loaf", "loaves"},
	{"stew", "bowl", "bowls"},
	{"pottage", "bowl", "bowls"},
	{"porridge", "bowl", "bowls"},
	{"butter", "pat", "pats"},
	{"hardtack", "piece", "pieces"},
	{"cured meat", "cut", "cuts"},
	{"ale", "mug", "mugs"},
	{"beer", "mug", "mugs"},
	{"small beer", "mug", "mugs"},
	{"cider", "mug", "mugs"},
	{"perry", "mug", "mugs"},
	{"mead", "mug", "mugs"},
	{"clean water", "bucket", "buckets"},
	{"unclean water", "bucket", "buckets"},
	{"sand", "heap", "heaps"},
	{"bark", "strip", "strips"},
	{"willow bark", "strip", "strips"},
	{"soap", "bar", "bars"},
	{"bog iron", "lump", "lumps"},
	{"iron ore", "lump", "lumps"},
	{"copper ore", "lump", "lumps"},
	{"tin ore", "lump", "lumps"},
	{"silver ore", "lump", "lumps"},
	{"salt", "measure", "measures"},
	{"kindling", "bundle", "bundles"},
	{"straw", "bundle", "bundles"}
};

static const s_WorkIrregulars[][2][12] = {
	{"sheaf", "sheaves"},
	{"loaf", "loaves"},
	{"knife", "knives"},
	{"die", "dice"},
	{"fish", "fish"},
	{"trout", "trout"},
	{"salmon", "salmon"},
	{"carp", "carp"},
	{"pike", "pike"},
	{"perch", "perch"},
	{"bream", "bream"},
	{"cod", "cod"}
};
static s_WorkReserve[MAX_PLAYERS][WORK_RESERVE_MAX][5];

stock Work_DescribeAmount(amount,const name[],dest[],size = sizeof(dest))
{
	new lower[ITEM_NAME_LEN];
	strcopy(lower,name);

	if (strfind(lower,"St ") != 0)
	{
		lower[0] = tolower(lower[0]);
	}

	for (new i = 0;i < sizeof(s_WorkMeasures);i++)
	{
		if (!strcmp(lower,s_WorkMeasures[i][0],true))
		{
			if (amount == 1)
			{
				format(dest,size,"a %s of %s",s_WorkMeasures[i][1],lower);
			}
			else
			{
				format(dest,size,"%d %s of %s",amount,s_WorkMeasures[i][2],lower);
			}

			return;
		}
	}

	new length = strlen(lower), last = length - 1, wordStart = 0;

	for (new i = last;i > 0;i--)
	{
		if (lower[i - 1] == ' ')
		{
			wordStart = i;
			break;
		}
	}

	if (!strcmp(lower,"a ",false,2) || !strcmp(lower,"an ",false,3) || !strcmp(lower,"the ",false,4))
	{
		if (amount == 1)
		{
			strcopy(dest,lower,size);
		}
		else
		{
			format(dest,size,"%d of %s",amount,lower);
		}

		return;
	}

	new bool:isPlural = length > 1 && lower[last] == 's' && lower[last - 1] != 's';

	if (amount == 1)
	{
		if (isPlural)
		{
			format(dest,size,"some %s",lower);
		}
		else
		{
			format(dest,size,"%s %s",Util_StartsWithVowel(lower) ? ("an") : ("a"),lower);
		}

		return;
	}

	new head[ITEM_NAME_LEN], word[ITEM_NAME_LEN], plural[ITEM_NAME_LEN];
	strmid(head,lower,0,wordStart);
	strmid(word,lower,wordStart,length);
	strcopy(plural,word);

	if (!isPlural)
	{
		new bool:isIrregular = false, wordLength = strlen(word);

		for (new i = 0;i < sizeof(s_WorkIrregulars);i++)
		{
			if (!strcmp(word,s_WorkIrregulars[i][0]))
			{
				strcopy(plural,s_WorkIrregulars[i][1]);
				isIrregular = true;
				break;
			}
		}

		if (!isIrregular && wordLength > 0)
		{
			new end = word[wordLength - 1], before = wordLength > 1 ? word[wordLength - 2] : 0;

			if (end == 'x' || end == 'z' || end == 's' || (end == 'h' && (before == 'c' || before == 's')))
			{
				format(plural,sizeof(plural),"%ses",word);
			}
			else if (end == 'y' && before != 'a' && before != 'e' && before != 'o' && before != 'u')
			{
				strmid(plural,word,0,wordLength - 1);
				strcat(plural,"ies");
			}
			else
			{
				format(plural,sizeof(plural),"%ss",word);
			}
		}
	}

	format(dest,size,"%d %s%s",amount,head,plural);
}

stock bool:Work_IsWorking(playerid)
{
	return Util_IsValidPlayer(playerid) && s_WorkScene[playerid][E_WORK_SCENE_ACTIVE];
}

stock Work_GetSceneRecipe(playerid)
{
	return Work_IsWorking(playerid) ? s_WorkScene[playerid][E_WORK_SCENE_RECIPE] : -1;
}

stock Work_GetSceneStage(playerid)
{
	return Work_IsWorking(playerid) ? s_WorkScene[playerid][E_WORK_SCENE_STAGE] : -1;
}

stock bool:Work_IsLicensedTrade(trade)
{
	return trade == TRADE_WOODCUTTING || trade == TRADE_MINING || trade == TRADE_HUNTING;
}

stock Work_GetEase(playerid,recipe)
{
	new attr = Character_GetAttribute(playerid,_:Recipe_GetAttribute(recipe));
	return max(attr - 1,0) + (Work_GetLevel(playerid,Recipe_GetTrade(recipe)) - 1) / 2;
}

stock Work_GetTargetKind(targetType,target)
{
	if (targetType == WORK_TARGET_STATION && Work_IsValidStation(target))
	{
		return g_WorkStations[target][E_WORK_STATION_KIND];
	}

	if (targetType == WORK_TARGET_NODE && Work_IsValidNode(target))
	{
		return g_WorkNodes[target][E_WORK_NODE_KIND];
	}

	return -1;
}

static Work_GetTargetWorker(targetType,target)
{
	if (targetType == WORK_TARGET_STATION && Work_IsValidStation(target))
	{
		return g_WorkStations[target][E_WORK_STATION_WORKER];
	}

	if (targetType == WORK_TARGET_NODE && Work_IsValidNode(target))
	{
		return g_WorkNodes[target][E_WORK_NODE_WORKER];
	}

	return INVALID_PLAYER_ID;
}

static Work_SetTargetWorker(targetType,target,playerid)
{
	if (targetType == WORK_TARGET_STATION && Work_IsValidStation(target))
	{
		g_WorkStations[target][E_WORK_STATION_WORKER] = playerid;
	}
	else if (targetType == WORK_TARGET_NODE && Work_IsValidNode(target))
	{
		g_WorkNodes[target][E_WORK_NODE_WORKER] = playerid;
	}
}

static Work_CountInput(playerid,E_ITEM_KIND:kind,param,stars)
{
	new have = Inventory_Count(playerid,kind,param,stars);

	for (new nth = 1, member;(member = Item_GetGroupMember(param,nth)) != -1;nth++)
	{
		have += Inventory_Count(playerid,Item_GetDefKind(member),member,stars);
	}

	return have;
}

stock bool:Work_HasInputs(playerid,recipe)
{
	for (new i = 0;i < RECIPE_MAX_INPUTS;i++)
	{
		new E_ITEM_KIND:kind, param, amount, minStars;

		if (!Recipe_GetInput(recipe,i,kind,param,amount,minStars))
		{
			continue;
		}

		new have = 0;

		for (new stars = max(minStars,ITEM_STARS_MIN);stars <= ITEM_STARS_MAX;stars++)
		{
			have += Work_CountInput(playerid,kind,param,stars);
		}

		if (have < amount)
		{
			return false;
		}
	}

	return true;
}

stock Work_FormatMissing(playerid,recipe,dest[],size = sizeof(dest))
{
	new name[ITEM_NAME_LEN], part[48], count = 0;
	strcopy(dest,"You still need ",size);

	for (new i = 0;i < RECIPE_MAX_INPUTS;i++)
	{
		new E_ITEM_KIND:kind, param, amount, minStars;

		if (!Recipe_GetInput(recipe,i,kind,param,amount,minStars))
		{
			continue;
		}

		new have = 0;

		for (new stars = max(minStars,ITEM_STARS_MIN);stars <= ITEM_STARS_MAX;stars++)
		{
			have += Work_CountInput(playerid,kind,param,stars);
		}

		if (have >= amount)
		{
			continue;
		}

		Item_GetName(kind,param,name);

		if (minStars > ITEM_STARS_MIN)
		{
			format(part,sizeof(part),"%s%d %s (%d stars or better)",count > 0 ? (", ") : (""),amount - have,name,minStars);
		}
		else
		{
			format(part,sizeof(part),"%s%d %s",count > 0 ? (", ") : (""),amount - have,name);
		}

		strcat(dest,part,size);
		count++;
	}

	strcat(dest,".",size);
	return count;
}

stock bool:Work_HasTool(playerid,recipe)
{
	new tool = Recipe_GetTool(recipe);
	return tool == RECIPE_NO_TOOL || Inventory_Count(playerid,Item_GetDefKind(tool),tool) > 0 || Work_GetCrudeInUse(playerid,tool) != -1;
}

stock bool:Work_CheckStart(playerid,targetType,target,recipe,reason[],size = sizeof(reason))
{
	reason[0] = EOS;

	if (!Session_IsPlaying(playerid) || Work_IsWorking(playerid))
	{
		strcopy(reason,"You're busy with something else.",size);
	}
	else if (Combat_IsInMode(playerid) || Combat_IsStruckDown(playerid))
	{
		strcopy(reason,"Press Y to put your weapon away first.",size);
	}
	else if (Mount_IsRiding(playerid))
	{
		strcopy(reason,"Get off your mount first.",size);
	}
	else if (targetType == WORK_TARGET_STATION && Work_IsStationRuined(target))
	{
		strcopy(reason,"It burnt with the building. It's usable again once the building is rebuilt.",size);
	}
	else if (targetType == WORK_TARGET_STATION && !Work_CanUseStation(playerid,target))
	{
		strcopy(reason,"That isn't yours to use.",size);
	}
	else if (Work_GetTargetWorker(targetType,target) != INVALID_PLAYER_ID)
	{
		strcopy(reason,"Someone else is working here.",size);
	}
    else if (targetType == WORK_TARGET_NODE && recipe == Fishing_GetRecipe() && Fishing_IsNodeFrozen(target))
    {
        strcopy(reason,"The water is frozen. Wait for the ice to thaw before fishing here.",size);
    }
	else if (targetType == WORK_TARGET_NODE && Work_GetNodeStock(target) <= 0)
	{
		strcopy(reason,"There's nothing left here.",size);
	}
	else if (targetType == WORK_TARGET_NODE && Work_GetNodeCooldown(playerid,target) > 0)
	{
		new minutes = (Work_GetNodeCooldown(playerid,target) + 59) / 60;
		format(reason,size,"You took what you could from this. Come back in %d minute%s.",minutes,minutes == 1 ? ("") : ("s"));
	}
	else if (Work_GetLevel(playerid,Recipe_GetTrade(recipe)) < Recipe_GetLevel(recipe))
	{
		new trade[JOB_NAME_LEN];
		Trade_GetName(Recipe_GetTrade(recipe),trade);
		trade[0] = tolower(trade[0]);
		format(reason,size,"You need more practice at %s for that (level %d).",trade,Recipe_GetLevel(recipe));
	}
	else if (!Work_HasTool(playerid,recipe))
	{
		new name[ITEM_NAME_LEN], tool = Recipe_GetTool(recipe), crude = Work_FindCrudeFor(tool);
		Item_GetName(Item_GetDefKind(tool),tool,name);

		if (crude != -1)
		{
			new crudeName[ITEM_NAME_LEN];
			Item_GetName(Item_GetDefKind(crude),crude,crudeName);
			format(reason,size,"You need %s %s for that. A hand-made %s from Crafting works too.",Util_StartsWithVowel(name) ? ("an") : ("a"),name,crudeName);
		}
		else
		{
			format(reason,size,"You need %s %s for that.",Util_StartsWithVowel(name) ? ("an") : ("a"),name);
		}
	}
	else if (!Work_HasInputs(playerid,recipe))
	{
		Work_FormatMissing(playerid,recipe,reason,size);
	}
	else if (Vitals_GetStamina(playerid) < float(Recipe_GetStamina(recipe)))
	{
		strcopy(reason,"You're too tired. Rest until your stamina comes back.",size);
	}

	return reason[0] == EOS;
}

static Work_Reserve(playerid,recipe)
{
	new count = 0, characterid = Character_GetId(playerid);

	for (new i = 0;i < RECIPE_MAX_INPUTS;i++)
	{
		new E_ITEM_KIND:kind, param, amount, minStars;

		if (!Recipe_GetInput(recipe,i,kind,param,amount,minStars))
		{
			continue;
		}

		for (new stars = max(minStars,ITEM_STARS_MIN);stars <= ITEM_STARS_MAX && amount > 0 && count < WORK_RESERVE_MAX;stars++)
		{
			for (new nth = 0, member;amount > 0 && count < WORK_RESERVE_MAX && (member = Item_GetGroupMember(param,nth)) != -1;nth++)
			{
				new E_ITEM_KIND:memberKind = nth == 0 ? kind : Item_GetDefKind(member), take = min(Inventory_Count(playerid,memberKind,member,stars),amount), freshAt = Inventory_OldestFresh(playerid,memberKind,member,stars);

				if (take <= 0 || !Inventory_Take(playerid,memberKind,member,take,stars))
				{
					continue;
				}

				amount -= take;
				s_WorkReserve[playerid][count][0] = _:memberKind;
				s_WorkReserve[playerid][count][1] = member;
				s_WorkReserve[playerid][count][2] = take;
				s_WorkReserve[playerid][count][3] = stars;
				s_WorkReserve[playerid][count][4] = freshAt;
				count++;
				mysql_tquery_s(g_Mysql,str_format("INSERT INTO work_reservations (character_id, kind, param, amount, stars, fresh_at) VALUES (%d, %d, %d, %d, %d, %d)",characterid,_:memberKind,member,take,stars,freshAt));
			}
		}
	}

	s_WorkScene[playerid][E_WORK_SCENE_RESERVED] = count;
}

static Work_ConsumeReservation(playerid)
{
	s_WorkScene[playerid][E_WORK_SCENE_RESERVED] = 0;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM work_reservations WHERE character_id = %d",Character_GetId(playerid)));
}

static Work_ReturnReservation(playerid)
{
	for (new i = 0;i < s_WorkScene[playerid][E_WORK_SCENE_RESERVED];i++)
	{
		Inventory_Give(playerid,E_ITEM_KIND:s_WorkReserve[playerid][i][0],s_WorkReserve[playerid][i][1],s_WorkReserve[playerid][i][2],s_WorkReserve[playerid][i][3],s_WorkReserve[playerid][i][4]);
	}

	Work_ConsumeReservation(playerid);
}

forward Task:Work_RestoreReservations(playerid,characterid);
#pragma warning push
#pragma warning disable 204
async Task:Work_RestoreReservations(playerid,characterid)
{
	await mysql_aquery_s(g_Mysql,str_format("SELECT id, kind, param, amount, stars, fresh_at FROM work_reservations WHERE character_id = %d",characterid));

	new rows = min(cache_num_rows(),WORK_RESERVE_MAX), items[WORK_RESERVE_MAX][5], ids[WORK_RESERVE_MAX], idList[WORK_RESERVE_MAX * 12];

	if (rows == 0)
	{
		return async 0;
	}

	for (new r = 0;r < rows;r++)
	{
		cache_get_value_name_int(r,"id",ids[r]);
		cache_get_value_name_int(r,"kind",items[r][0]);
		cache_get_value_name_int(r,"param",items[r][1]);
		cache_get_value_name_int(r,"amount",items[r][2]);
		cache_get_value_name_int(r,"stars",items[r][3]);
		cache_get_value_name_int(r,"fresh_at",items[r][4]);
		format(idList,sizeof(idList),"%s%s%d",idList,r == 0 ? ("") : (","),ids[r]);
	}

	await mysql_aquery_s(g_Mysql,str_format("DELETE FROM work_reservations WHERE id IN (%s)",idList));

	if (cache_affected_rows() != rows || !IsPlayerConnected(playerid) || Character_GetId(playerid) != characterid)
	{
		return async 0;
	}

	for (new r = 0;r < rows;r++)
	{
		Inventory_Give(playerid,E_ITEM_KIND:items[r][0],items[r][1],items[r][2],items[r][3],items[r][4]);
	}

	Log_Info("workstations","player %d got %d unfinished work input(s) back",playerid,rows);
	return async rows;
}
#pragma warning pop

stock Work_GetShotCamera(Float:x,Float:y,Float:z,Float:heading,Float:dist,Float:lift,Float:aim,Float:side,&Float:cameraX,&Float:cameraY,&Float:cameraZ,&Float:lookX,&Float:lookY,&Float:lookZ)
{
	cameraX = x - dist * floatsin(heading,degrees) + side * floatcos(heading,degrees);
	cameraY = y + dist * floatcos(heading,degrees) + side * floatsin(heading,degrees);
	cameraZ = z + lift;
	lookX = x + side * floatcos(heading,degrees);
	lookY = y + side * floatsin(heading,degrees);
	lookZ = z + aim;
}

stock Work_PreviewStationShot(playerid,stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	new Float:cameraX, Float:cameraY, Float:cameraZ, Float:lookX, Float:lookY, Float:lookZ;
	Work_GetShotCamera(g_WorkStations[stationid][E_WORK_STATION_POS][0],g_WorkStations[stationid][E_WORK_STATION_POS][1],g_WorkStations[stationid][E_WORK_STATION_POS][2],g_WorkStations[stationid][E_WORK_STATION_STAND][3] + 180.0,SCENE_DEFAULT_DIST * Work_GetStationShot(stationid,WORK_SHOT_DIST),SCENE_DEFAULT_LIFT + Work_GetStationShot(stationid,WORK_SHOT_LIFT),SCENE_DEFAULT_AIM + Work_GetStationShot(stationid,WORK_SHOT_AIM),Work_GetStationShot(stationid,WORK_SHOT_SIDE),cameraX,cameraY,cameraZ,lookX,lookY,lookZ);
	SetPlayerCameraPos(playerid,cameraX,cameraY,cameraZ);
	SetPlayerCameraLookAt(playerid,lookX,lookY,lookZ,CAMERA_CUT);
}

static Work_FrameShot(playerid,stage)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], Float:rot, Float:dist, Float:lift, Float:aim, Float:side, moveMs;
	Recipe_GetStageShot(recipe,stage,rot,dist,lift,aim,side,moveMs);

	if (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] == WORK_TARGET_STATION)
	{
		new stationid = s_WorkScene[playerid][E_WORK_SCENE_TARGET];
		dist *= Work_GetStationShot(stationid,WORK_SHOT_DIST);
		lift += Work_GetStationShot(stationid,WORK_SHOT_LIFT);
		aim += Work_GetStationShot(stationid,WORK_SHOT_AIM);
		side += Work_GetStationShot(stationid,WORK_SHOT_SIDE);
	}

	new Float:cameraX, Float:cameraY, Float:cameraZ, Float:lookX, Float:lookY, Float:lookZ;
	Work_GetShotCamera(s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][0],s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][1],s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][2],s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][3] + rot,dist,lift,aim,side,cameraX,cameraY,cameraZ,lookX,lookY,lookZ);

	new Float:currentX, Float:currentY, Float:currentZ, Float:frontX, Float:frontY, Float:frontZ;
	GetPlayerCameraPos(playerid,currentX,currentY,currentZ);
	GetPlayerCameraFrontVector(playerid,frontX,frontY,frontZ);
	InterpolateCameraPos(playerid,currentX,currentY,currentZ,cameraX,cameraY,cameraZ,moveMs,CAMERA_MOVE);
	InterpolateCameraLookAt(playerid,currentX + frontX * 5.0,currentY + frontY * 5.0,currentZ + frontZ * 5.0,lookX,lookY,lookZ,moveMs,CAMERA_MOVE);
}

static Work_ApplyStageAnim(playerid,stage)
{
	new lib[SCENE_ANIM_LIB_LEN], name[SCENE_ANIM_NAME_LEN], bool:isLoop;
	Recipe_GetStageAnim(s_WorkScene[playerid][E_WORK_SCENE_RECIPE],stage,lib,name,isLoop);
	ApplyAnimation(playerid,lib,name,4.1,isLoop,true,true,true,0,SYNC_ALL);
}

static Work_BobProp(playerid)
{
	if (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] != WORK_TARGET_STATION)
	{
		return;
	}

	new name[RECIPE_STAGE_NAME_LEN];
	Recipe_GetStageName(s_WorkScene[playerid][E_WORK_SCENE_RECIPE],s_WorkScene[playerid][E_WORK_SCENE_STAGE],name);
	Work_StationBob(s_WorkScene[playerid][E_WORK_SCENE_TARGET],name);
}

static Work_RefreshStageLine(playerid)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], stage = s_WorkScene[playerid][E_WORK_SCENE_STAGE], name[RECIPE_STAGE_NAME_LEN], line[96];
	Recipe_GetStageName(recipe,stage,name);
	name[0] = toupper(name[0]);

	if (s_WorkScene[playerid][E_WORK_SCENE_SCORED] > 0)
	{
		new stars = Work_ComputeStars(playerid,recipe,s_WorkScene[playerid][E_WORK_SCENE_SCORE_TOTAL],s_WorkScene[playerid][E_WORK_SCENE_SCORED],s_WorkScene[playerid][E_WORK_SCENE_PERFECT],Work_GetKindStarCap(Work_GetTargetKind(s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE],s_WorkScene[playerid][E_WORK_SCENE_TARGET])));
		format(line,sizeof(line),"%d/%d  %s   ~w~%d star%s so far",stage + 1,Recipe_GetStageCount(recipe),name,stars,stars == 1 ? ("") : ("s"));
	}
	else
	{
		format(line,sizeof(line),"%d/%d  %s",stage + 1,Recipe_GetStageCount(recipe),name);
	}

	Work_SetPanelLines(playerid,line,"","");
}

static Work_BeginStage(playerid,stage)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE];
	s_WorkScene[playerid][E_WORK_SCENE_STAGE] = stage;
	s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT] = GetTickCount();
	Work_FrameShot(playerid,stage);
	Work_ApplyStageAnim(playerid,stage);
	Work_RefreshStageLine(playerid);

	if (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] == WORK_TARGET_STATION)
	{
		new name[RECIPE_STAGE_NAME_LEN];
		Recipe_GetStageName(recipe,stage,name);
		Work_FxStageBegin(s_WorkScene[playerid][E_WORK_SCENE_TARGET],name);
	}

	new flag = Recipe_GetStageFlag(recipe,stage);

	if (flag == STAGE_FLAG_OPTIONAL || flag == STAGE_FLAG_BRANCH)
	{
		s_WorkScene[playerid][E_WORK_SCENE_PHASE] = WORK_PHASE_OFFER;
		Work_SetPanelLines(playerid,"","~y~SPACE~w~ do it     ~y~N~w~ skip it","Skipping earns no bonus.  Hold ~y~N~w~ to walk away");
		return;
	}

	Work_StartChallenge(playerid);
}

static Work_StartChallenge(playerid)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], stage = s_WorkScene[playerid][E_WORK_SCENE_STAGE], kind = Recipe_GetStageKind(recipe,stage), hint[80], text[256];
	s_WorkScene[playerid][E_WORK_SCENE_PHASE] = WORK_PHASE_STAGE;
	s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT] = GetTickCount();
	pawn_call_public("Work_OnStageStarting","ddd",playerid,recipe,stage);
	Work_BeginChallenge(playerid,kind,s_WorkScene[playerid][E_WORK_SCENE_EASE] + (kind == CHALLENGE_SEQUENCE || Recipe_GetTool(recipe) == RECIPE_NO_TOOL ? Traits_Get(playerid,TRAIT_EFFECT_HAND_EASE) : 0));
	Work_GetChallengeHint(kind,hint);
	Work_FormatChallenge(playerid,text);
	Work_SetPanelLines(playerid,"",text,hint);
	Work_UpdateGlyphs(playerid);
}

static Work_NextStage(playerid)
{
	new next = s_WorkScene[playerid][E_WORK_SCENE_STAGE] + 1;

	if (next >= Recipe_GetStageCount(s_WorkScene[playerid][E_WORK_SCENE_RECIPE]))
	{
		Work_Finish(playerid);
		return;
	}

	Work_BeginStage(playerid,next);
}

static Work_EndStage(playerid,score)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], stage = s_WorkScene[playerid][E_WORK_SCENE_STAGE];
	pawn_call_public("Work_OnStageScored","dddd",playerid,recipe,stage,score);

	if (score <= 0)
	{
		Work_Ruin(playerid);
		return;
	}

	s_WorkScene[playerid][E_WORK_SCENE_SCORE_TOTAL] += score;
	s_WorkScene[playerid][E_WORK_SCENE_SCORED]++;

	if (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] == WORK_TARGET_STATION)
	{
		new name[RECIPE_STAGE_NAME_LEN];
		Recipe_GetStageName(recipe,stage,name);
		Work_StationStageDone(s_WorkScene[playerid][E_WORK_SCENE_TARGET],name);
	}

	if (score < 3)
	{
		s_WorkScene[playerid][E_WORK_SCENE_PERFECT] = false;
	}

	s_WorkScene[playerid][E_WORK_SCENE_PHASE] = WORK_PHASE_BETWEEN;
	s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT] = GetTickCount();
	Work_HideGlyphs(playerid);
	Work_SetPanelLines(playerid,"",score == 3 ? ("~y~Well done") : (score == 2 ? ("~g~Good") : ("~w~Rough, but done")),"_");
	Work_RefreshStageLine(playerid);
}

stock Work_ComputeStars(playerid,recipe,scoreTotal,scored,bool:isPerfect,starCap)
{
	new stars = 1 + (scored > 0 ? floatround(float(scoreTotal) / float(scored)) : 0);

	if (Character_GetAttribute(playerid,_:Recipe_GetAttribute(recipe)) >= 4)
	{
		stars++;
	}

	if (isPerfect && scored > 0)
	{
		stars = ITEM_STARS_MAX;
	}

	return Util_ClampInt(stars,ITEM_STARS_MIN,min(starCap,ITEM_STARS_MAX));
}

stock Work_DescribeGathered(amount,const name[],dest[],size = sizeof(dest))
{
	new length = strlen(name), lower[ITEM_NAME_LEN];

	if (length == 0 || name[length - 1] == 's' || strfind(name,"cherry",true) != -1 || strfind(name,"bark",true) != -1)
	{
		Work_DescribeAmount(amount,name,dest,size);
		return;
	}

	strcopy(lower,name);

	if (strfind(lower,"St ") != 0)
	{
		lower[0] = tolower(lower[0]);
	}

	if (amount == 1)
	{
		format(dest,size,"a bunch of %s",lower);
		return;
	}

	format(dest,size,"%d bunches of %s",amount,lower);
}

static Work_FinishVerb(targetType,kind)
{
	new verb[12] = "made";

	if (targetType == WORK_TARGET_NODE)
	{
		new key[WORK_KIND_KEY_LEN];
		Work_GetKindKey(kind,key);
		strcopy(verb,!strcmp(key,"herbs") || !strcmp(key,"fruitbush") || !strcmp(key,"windfall") ? ("gathered") : ("got"));
	}

	return verb;
}

static Work_Finish(playerid)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], kind = Work_GetTargetKind(s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE],s_WorkScene[playerid][E_WORK_SCENE_TARGET]);
	new crude = Work_GetCrudeInUse(playerid,Recipe_GetTool(recipe)), starCap = Work_GetKindStarCap(kind);

	if (crude != -1)
	{
		starCap = min(starCap,WORK_CRUDE_STAR_CAP);
	}

	new stars = Work_ComputeStars(playerid,recipe,s_WorkScene[playerid][E_WORK_SCENE_SCORE_TOTAL],s_WorkScene[playerid][E_WORK_SCENE_SCORED],s_WorkScene[playerid][E_WORK_SCENE_PERFECT],starCap);
	new E_ITEM_KIND:outKind, outParam, outAmount, name[ITEM_NAME_LEN], message[160];

	Work_ConsumeReservation(playerid);

	new targetType = s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE], target = s_WorkScene[playerid][E_WORK_SCENE_TARGET];
	new bool:hasOutput = Recipe_GetOutput(recipe,outKind,outParam,outAmount);

	new bool:isHerb = targetType == WORK_TARGET_NODE && Work_GetNodeHerb(target) != -1, verb[12];
	strcopy(verb,Work_FinishVerb(targetType,kind));

	if (targetType == WORK_TARGET_NODE)
	{
		if (hasOutput && Work_GetNodeYield(target,outParam,outAmount))
		{
			outKind = Item_GetDefKind(outParam);
		}

		Work_NoteNodeWorked(playerid,target);
		Work_TakeNodeStock(target);
	}

	if (hasOutput && outAmount > 0)
	{
		if (targetType == WORK_TARGET_NODE && random(100) < Traits_Get(playerid,TRAIT_EFFECT_FIND))
		{
			outAmount++;
		}

		new bool:isDropped = !Inventory_Give(playerid,outKind,outParam,outAmount,stars);

		if (isDropped)
		{
			new Float:x, Float:y, Float:z;
			GetPlayerPos(playerid,x,y,z);
			Drop_Create(outKind,outParam,outAmount,x,y,z - 0.9,GetPlayerVirtualWorld(playerid),stars,.interior = GetPlayerInterior(playerid));
		}

		new described[ITEM_NAME_LEN + 32];
		Item_GetName(outKind,outParam,name);
		if (isHerb)
		{
			Work_DescribeGathered(outAmount,name,described);
		}
		else
		{
			Work_DescribeAmount(outAmount,name,described);
		}

		format(message,sizeof(message),"You %s %s, %d star%s.",verb,described,stars,stars == 1 ? ("") : ("s"));

		if (isDropped)
		{
			strcat(message," Your bag is full! What didn't fit is on the ground at your feet.");
		}
	}
	else
	{
		format(message,sizeof(message),"You finished with %d star%s.",stars,stars == 1 ? ("") : ("s"));
	}

	Vitals_DrainStamina(playerid,float(Recipe_GetStamina(recipe)) * (targetType == WORK_TARGET_NODE ? Traits_Factor(playerid,TRAIT_EFFECT_FIELDWORK) : 1.0));
	Work_AddPractice(playerid,Recipe_GetTrade(recipe),stars * WORK_PRACTICE_PER_STAR);

	if (Work_IsLicensedTrade(Recipe_GetTrade(recipe)))
	{
		pawn_call_public("Work_OnPoached","dd",playerid,recipe);
	}

	Work_Release(playerid);
	Gui_Notify(playerid,message);
	Work_WearCrudeTool(playerid,crude);
	pawn_call_public("Work_OnFinished","ddd",playerid,recipe,stars);
	if (hasOutput && outAmount > 0 && !strcmp(verb,"gathered"))
	{
		Work_KeepNotice(playerid,message);
	}

	if (targetType == WORK_TARGET_STATION)
	{
		Work_BurnStation(target,WORK_SCENE_BURN_SECONDS);
	}
}

static Work_KeepNotice(playerid,const message[])
{
	new shown[SUBTITLE_TEXT_LEN];
	Subtitle_GetText(playerid,shown);

	if (!Subtitle_IsShown(playerid) || !strcmp(shown,message))
	{
		return;
	}

	SetTimerEx("Work_NotifyLater",max(SUBTITLE_MIN_SECONDS,strlen(shown) / SUBTITLE_CHARS_PER_SECOND + 2) * 1000,false,"ds",playerid,message);
}

forward Work_NotifyLater(playerid,const message[]);

public Work_NotifyLater(playerid,const message[])
{
	if (IsPlayerConnected(playerid))
	{
		Gui_Notify(playerid,message);
	}

	return 1;
}

static Work_Ruin(playerid)
{
	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE], stage = s_WorkScene[playerid][E_WORK_SCENE_STAGE];
	Work_ConsumeReservation(playerid);
	Vitals_DrainStamina(playerid,float(Recipe_GetStamina(recipe)) / 2.0 * (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] == WORK_TARGET_NODE ? Traits_Factor(playerid,TRAIT_EFFECT_FIELDWORK) : 1.0));
	Work_Release(playerid);
	Gui_Notify(playerid,"You messed up a step and ruined the batch. The materials are gone.");
	pawn_call_public("Work_OnRuined","ddd",playerid,recipe,stage);
}

stock Work_Abort(playerid)
{
	if (!Work_IsWorking(playerid))
	{
		return;
	}

	new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE];
	Work_ReturnReservation(playerid);
	Work_Release(playerid);
	Gui_Notify(playerid,"You stopped working. Your materials are back in your bag.");
	pawn_call_public("Work_OnAborted","dd",playerid,recipe);
}

static Work_Release(playerid)
{
	if (s_WorkScene[playerid][E_WORK_SCENE_TIMER] != 0)
	{
		KillTimer(s_WorkScene[playerid][E_WORK_SCENE_TIMER]);
		s_WorkScene[playerid][E_WORK_SCENE_TIMER] = 0;
	}

	new targetType = s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE], target = s_WorkScene[playerid][E_WORK_SCENE_TARGET];
	s_WorkScene[playerid][E_WORK_SCENE_ACTIVE] = false;
	s_WorkScene[playerid][E_WORK_SCENE_PHASE] = WORK_PHASE_NONE;
	Work_SetTargetWorker(targetType,target,INVALID_PLAYER_ID);

	if (targetType == WORK_TARGET_STATION)
	{
		Work_ResetStationProps(target);
	}

	if (!IsPlayerConnected(playerid))
	{
		return;
	}

	Work_HidePanel(playerid);
	ScreenFade_Stop(playerid);
	ScreenFade_Set(playerid,WORK_CLEAR_COLOUR);
	ClearAnimations(playerid,SYNC_ALL);
	SetCameraBehindPlayer(playerid);
	TogglePlayerControllable(playerid,true);
	Vitals_SetBusy(playerid,false);
}

static Work_Enter(playerid)
{
	new Float:x, Float:y, Float:z, Float:a;

	if (s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] == WORK_TARGET_STATION)
	{
		new stationid = s_WorkScene[playerid][E_WORK_SCENE_TARGET];
		SetPlayerPos(playerid,g_WorkStations[stationid][E_WORK_STATION_STAND][0],g_WorkStations[stationid][E_WORK_STATION_STAND][1],g_WorkStations[stationid][E_WORK_STATION_STAND][2]);
		SetPlayerFacingAngle(playerid,g_WorkStations[stationid][E_WORK_STATION_STAND][3]);
	}
	else
	{
		new nodeid = s_WorkScene[playerid][E_WORK_SCENE_TARGET];
		GetPlayerPos(playerid,x,y,z);
		a = atan2(g_WorkNodes[nodeid][E_WORK_NODE_POS][1] - y,g_WorkNodes[nodeid][E_WORK_NODE_POS][0] - x) - 90.0;
		SetPlayerFacingAngle(playerid,Util_NormalizeAngle(a));
	}

	Work_BeginStage(playerid,0);
	ScreenFade_Start(playerid,WORK_CLEAR_COLOUR,WORK_FADE_MS,8);
}

static s_WorkStartGate[MAX_PLAYERS][32];

stock Work_SetStartGate(playerid,const handler[])
{
	if (Util_IsValidPlayer(playerid))
	{
		strcopy(s_WorkStartGate[playerid],handler,sizeof(s_WorkStartGate[]));
	}
}

stock bool:Work_Start(playerid,targetType,target,recipe)
{
	new reason[WORK_REASON_LEN];

	if (!Work_CheckStart(playerid,targetType,target,recipe,reason))
	{
		Gui_Notify(playerid,reason);
		return false;
	}

	if (s_WorkStartGate[playerid][0] != EOS)
	{
		new handler[32];
		strcopy(handler,s_WorkStartGate[playerid]);
		s_WorkStartGate[playerid][0] = EOS;
		CallLocalFunction(handler,"dddd",playerid,targetType,target,recipe);
		return true;
	}

	new recipeName[RECIPE_NAME_LEN];
	Recipe_GetName(recipe,recipeName);

	s_WorkScene[playerid][E_WORK_SCENE_ACTIVE] = true;
	s_WorkScene[playerid][E_WORK_SCENE_TARGET_TYPE] = targetType;
	s_WorkScene[playerid][E_WORK_SCENE_TARGET] = target;
	s_WorkScene[playerid][E_WORK_SCENE_RECIPE] = recipe;
	s_WorkScene[playerid][E_WORK_SCENE_STAGE] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_SCORE_TOTAL] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_SCORED] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_PERFECT] = true;
	s_WorkScene[playerid][E_WORK_SCENE_N_TICKS] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_TICK] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_EASE] = Work_GetEase(playerid,recipe) + (targetType == WORK_TARGET_STATION ? Traits_Get(playerid,TRAIT_EFFECT_CRAFT_EASE) : 0);
	new updown, leftright;
	GetPlayerKeys(playerid,s_WorkScene[playerid][E_WORK_SCENE_KEYS],updown,leftright);
	#pragma unused updown, leftright

	if (targetType == WORK_TARGET_STATION)
	{
		for (new i = 0;i < 4;i++)
		{
			s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][i] = g_WorkStations[target][E_WORK_STATION_POS][i];
		}

		s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][3] = g_WorkStations[target][E_WORK_STATION_STAND][3] + 180.0;
	}
	else
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid,x,y,z);

		for (new i = 0;i < 3;i++)
		{
			s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][i] = g_WorkNodes[target][E_WORK_NODE_POS][i];
		}

		if (Work_KindHasReach(g_WorkNodes[target][E_WORK_NODE_KIND]))
		{
			s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][0] = x;
			s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][1] = y;
		}

		s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][2] = z - 0.3;
		s_WorkScene[playerid][E_WORK_SCENE_ANCHOR][3] = atan2(y - g_WorkNodes[target][E_WORK_NODE_POS][1],x - g_WorkNodes[target][E_WORK_NODE_POS][0]) - 90.0;
	}

	Work_SetTargetWorker(targetType,target,playerid);
	Work_Reserve(playerid,recipe);
	Vitals_SetBusy(playerid,true);
	TogglePlayerControllable(playerid,false);
	Work_ShowPanel(playerid,recipeName);
	s_WorkScene[playerid][E_WORK_SCENE_PHASE] = WORK_PHASE_ENTER;
	s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT] = GetTickCount();
	ScreenFade_Start(playerid,WORK_FADE_COLOUR,WORK_FADE_MS,8);
	s_WorkScene[playerid][E_WORK_SCENE_TIMER] = SetTimerEx("Work_Tick",WORK_TICK_MS,true,"d",playerid);
	return true;
}

stock bool:Work_GetReservedItem(playerid,index,&E_ITEM_KIND:kind,&param,&stars)
{
	if (!Util_IsValidPlayer(playerid) || index < 0 || index >= s_WorkScene[playerid][E_WORK_SCENE_RESERVED])
	{
		return false;
	}

	kind = E_ITEM_KIND:s_WorkReserve[playerid][index][0];
	param = s_WorkReserve[playerid][index][1];
	stars = s_WorkReserve[playerid][index][3];
	return true;
}

stock Work_GetSceneTarget(playerid)
{
	return Work_IsWorking(playerid) ? s_WorkScene[playerid][E_WORK_SCENE_TARGET] : -1;
}

stock Work_ForceStageScore(playerid,score)
{
	if (!Work_IsWorking(playerid))
	{
		return;
	}

	if (s_WorkScene[playerid][E_WORK_SCENE_PHASE] == WORK_PHASE_OFFER)
	{
		Work_StartChallenge(playerid);
	}

	if (s_WorkScene[playerid][E_WORK_SCENE_PHASE] == WORK_PHASE_STAGE)
	{
		Work_ResolveChallenge(playerid,score);
		s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT] = GetTickCount() - WORK_STAGE_FLOOR_MS;
	}
}

forward Work_Tick(playerid);

public Work_Tick(playerid)
{
	if (!IsPlayerConnected(playerid) || !Work_IsWorking(playerid))
	{
		return 1;
	}

	new KEY:keys, updown, leftright, now = GetTickCount(), elapsed = now - s_WorkScene[playerid][E_WORK_SCENE_PHASE_AT];
	GetPlayerKeys(playerid,keys,updown,leftright);

	#pragma unused updown, leftright
	new KEY:oldKeys = s_WorkScene[playerid][E_WORK_SCENE_KEYS];
	s_WorkScene[playerid][E_WORK_SCENE_KEYS] = keys;
	s_WorkScene[playerid][E_WORK_SCENE_TICK]++;

	new bool:isNTap = false;

	if (keys & KEY_NO)
	{
		if (++s_WorkScene[playerid][E_WORK_SCENE_N_TICKS] >= WORK_ABORT_TICKS)
		{
			Work_Abort(playerid);
			return 1;
		}
	}
	else
	{
		isNTap = s_WorkScene[playerid][E_WORK_SCENE_N_TICKS] > 0;
		s_WorkScene[playerid][E_WORK_SCENE_N_TICKS] = 0;
	}

	switch (s_WorkScene[playerid][E_WORK_SCENE_PHASE])
	{
		case WORK_PHASE_ENTER:
		{
			if (elapsed >= WORK_FADE_MS)
			{
				Work_Enter(playerid);
			}
		}
		case WORK_PHASE_OFFER:
		{
			if ((keys & KEY_SPRINT) && !(oldKeys & KEY_SPRINT))
			{
				Work_StartChallenge(playerid);
			}
			else if (isNTap)
			{
				Work_NextStage(playerid);
			}
		}
		case WORK_PHASE_STAGE:
		{
			if (elapsed < WORK_LAUNCH_MS)
			{
				return 1;
			}

			if (Work_ChallengeInput(playerid,keys,oldKeys))
			{
				Work_BobProp(playerid);
			}

			new score = Work_GetChallengeScore(playerid);

			if (score != -1 && elapsed >= WORK_STAGE_FLOOR_MS)
			{
				Work_EndStage(playerid,score);
				return 1;
			}

			if (s_WorkScene[playerid][E_WORK_SCENE_TICK] % 2 == 0)
			{
				new text[256];
				Work_FormatChallenge(playerid,text);
				Work_SetPanelLines(playerid,"",text,"");
			}

			Work_UpdateGlyphs(playerid);
		}
		case WORK_PHASE_BETWEEN:
		{
			if (elapsed >= WORK_BETWEEN_MS)
			{
				Work_NextStage(playerid);
			}
		}
	}

	return 1;
}

forward Work_RestoreDeferred(playerid,characterid);

public Work_RestoreDeferred(playerid,characterid)
{
	yield 1;

	if (IsPlayerConnected(playerid) && Character_GetId(playerid) == characterid)
	{
		SetTimerEx("Work_RestoreDeferred",0,false,"dd",playerid,characterid);
	}
}

forward bool:Work_SceneKeyContext(playerid);

public bool:Work_SceneKeyContext(playerid)
{
	return Work_IsWorking(playerid);
}

forward Work_OnStageStarting(playerid,recipe,stage);

public Work_OnStageStarting(playerid,recipe,stage)
{
	return 1;
}

forward Work_OnStageScored(playerid,recipe,stage,score);

public Work_OnStageScored(playerid,recipe,stage,score)
{
	return 1;
}

forward Work_OnFinished(playerid,recipe,stars);

public Work_OnFinished(playerid,recipe,stars)
{
	return 1;
}

forward Work_OnRuined(playerid,recipe,stage);

public Work_OnRuined(playerid,recipe,stage)
{
	return 1;
}

forward Work_OnAborted(playerid,recipe);

public Work_OnAborted(playerid,recipe)
{
	return 1;
}

forward Work_OnPoached(playerid,recipe);

public Work_OnPoached(playerid,recipe)
{
	return 1;
}

forward bool:Work_BusyCheck(playerid);

public bool:Work_BusyCheck(playerid)
{
	return Work_IsWorking(playerid);
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_WorkStartGate[playerid][0] = EOS;
	s_WorkScene[playerid][E_WORK_SCENE_ACTIVE] = false;
	s_WorkScene[playerid][E_WORK_SCENE_TIMER] = 0;
	s_WorkScene[playerid][E_WORK_SCENE_RESERVED] = 0;
}

hook OnPlayerDisconnect(playerid,reason)
{
	if (Work_IsWorking(playerid))
	{
		new recipe = s_WorkScene[playerid][E_WORK_SCENE_RECIPE];
		s_WorkScene[playerid][E_WORK_SCENE_RESERVED] = 0;
		Work_Release(playerid);
		pawn_call_public("Work_OnAborted","dd",playerid,recipe);
	}
}

hook OnPlayerDeath(playerid,killerid,WEAPON:reason)
{
	Work_Abort(playerid);
}

hook Combat_OnStruckDown(playerid)
{
	Work_Abort(playerid);
}

hook Combat_OnHit(attackerid,targetid,weapon,Float:damage)
{
	Work_Abort(targetid);
}

hook Session_OnStateChanged(playerid,E_SESSION_STATE:from,E_SESSION_STATE:to)
{
	if (from == SESSION_PLAYING && to != SESSION_DISCONNECTING)
	{
		Work_Abort(playerid);
	}
}

hook Inventory_OnLoaded(playerid)
{
	new characterid = Character_GetId(playerid);

	if (characterid > 0)
	{
		Work_RestoreReservations(playerid,characterid);
	}
}

hook Work_OnStationChanged(stationid)
{
	new worker = g_WorkStations[stationid][E_WORK_STATION_WORKER];

	if (worker != INVALID_PLAYER_ID)
	{
		Work_Abort(worker);
	}
}

hook Work_OnNodeChanged(nodeid)
{
	new worker = g_WorkNodes[nodeid][E_WORK_NODE_WORKER];

	if (worker != INVALID_PLAYER_ID)
	{
		Work_Abort(worker);
	}
}
