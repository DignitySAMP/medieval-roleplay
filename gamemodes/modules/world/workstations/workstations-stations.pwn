#define WORK_MAX_STATIONS (256)
#define WORK_STAND_DISTANCE (0.9)
#define WORK_LABEL_COLOUR (0xD8CCB255)
#define WORK_LABEL_RANGE (6.0)
#define WORK_INVITES_MAX (8)
#define WORK_PART_BOB (0.05)
#define WORK_STREAM_RANGE (80.0)
#define WORK_PART_TXD "stations/stations.txd"
#define WORK_NEXT_FOLDER "stations_next/"
#define WORK_NEXT_TXD "stations_next/stations_next.txd"
#define WORK_BODY_TEXT_COLOUR (0xFFD8CCB2)
#define WORK_BODY_BACK_COLOUR (0xFF3A332A)
#define WORK_KIND_VIEW_MAX (64)
#define WORK_PART_PRIORITY (1)

enum E_WORK_STATION
{
	bool:E_WORK_STATION_USED,
	E_WORK_STATION_ROW,
	E_WORK_STATION_KIND,
	Float:E_WORK_STATION_POS[4],
	Float:E_WORK_STATION_STAND[4],
	E_WORK_STATION_WORLD,
	E_WORK_STATION_INTERIOR,
	Float:E_WORK_STATION_SHOT[4],
	STREAMER_TAG_3D_TEXT_LABEL:E_WORK_STATION_LABEL,
	STREAMER_TAG_OBJECT:E_WORK_STATION_PROPS[WORK_PROP_SLOTS],
	E_WORK_STATION_WORKER,
	E_WORK_STATION_OWNER,
	E_WORK_STATION_PLACED,
	E_WORK_STATION_GRACE,
	E_WORK_STATION_FUEL_ITEM,
	E_WORK_STATION_FUEL_UNITS,
	E_WORK_STATION_FUEL_SECONDS,
	E_WORK_STATION_INVITES[WORK_INVITES_MAX],
}

enum
{
	WORK_SHOT_DIST,
	WORK_SHOT_LIFT,
	WORK_SHOT_AIM,
	WORK_SHOT_SIDE,
}

new g_WorkStations[WORK_MAX_STATIONS][E_WORK_STATION];

enum E_WORK_KIND_VIEW
{
	bool:E_WORK_KIND_VIEW_SET,
	Float:E_WORK_KIND_VIEW_RIGHT,
	Float:E_WORK_KIND_VIEW_AHEAD,
	Float:E_WORK_KIND_VIEW_LIFT,
	Float:E_WORK_KIND_VIEW_TURN,
	Float:E_WORK_KIND_VIEW_SHOT[4],
}

static s_WorkKindViews[WORK_KIND_VIEW_MAX][E_WORK_KIND_VIEW];

enum E_WORK_KIND_STAND_DEF
{
	E_WORK_KIND_STAND_DEF_KIND[WORK_KIND_KEY_LEN],
	Float:E_WORK_KIND_STAND_DEF_RIGHT,
	Float:E_WORK_KIND_STAND_DEF_AHEAD,
	Float:E_WORK_KIND_STAND_DEF_TURN,
}

static const s_WorkKindStandDefs[][E_WORK_KIND_STAND_DEF] = {
	{"stall", 0.0, -0.12, 180.0},
	{"herald", 0.0, -0.95, 180.0}
};

static bool:s_WorkStationRuined[WORK_MAX_STATIONS];
static s_WorkLayoutRevision;

stock bool:Work_IsValidStation(stationid)
{
	return stationid >= 0 && stationid < WORK_MAX_STATIONS && g_WorkStations[stationid][E_WORK_STATION_USED];
}

stock bool:Work_IsStationRuined(stationid)
{
	return Work_IsValidStation(stationid) && s_WorkStationRuined[stationid];
}

stock Work_SetStationRuined(stationid,bool:isRuined)
{
	if (Work_IsValidStation(stationid))
	{
		s_WorkStationRuined[stationid] = isRuined;
	}
}

stock bool:Work_GetStationPos(stationid,&Float:x,&Float:y,&Float:z,&world = 0)
{
	if (!Work_IsValidStation(stationid))
	{
		return false;
	}

	x = g_WorkStations[stationid][E_WORK_STATION_POS][0];
	y = g_WorkStations[stationid][E_WORK_STATION_POS][1];
	z = g_WorkStations[stationid][E_WORK_STATION_POS][2];
	world = g_WorkStations[stationid][E_WORK_STATION_WORLD];
	return true;
}

stock bool:Work_GetStationPlace(stationid,&Float:x,&Float:y,&Float:z,&Float:a,&world,&interior)
{
	if (!Work_IsValidStation(stationid))
	{
		return false;
	}

	x = g_WorkStations[stationid][E_WORK_STATION_POS][0];
	y = g_WorkStations[stationid][E_WORK_STATION_POS][1];
	z = g_WorkStations[stationid][E_WORK_STATION_POS][2];
	a = g_WorkStations[stationid][E_WORK_STATION_POS][3];
	world = g_WorkStations[stationid][E_WORK_STATION_WORLD];
	interior = g_WorkStations[stationid][E_WORK_STATION_INTERIOR];
	return true;
}

stock Work_GetStationKind(stationid)
{
	return Work_IsValidStation(stationid) ? g_WorkStations[stationid][E_WORK_STATION_KIND] : -1;
}

stock bool:Work_IsStationAlight(stationid)
{
	if (!Work_IsValidStation(stationid) || !Work_IsFireKind(g_WorkStations[stationid][E_WORK_STATION_KIND]))
	{
		return false;
	}

	return g_WorkStations[stationid][E_WORK_STATION_OWNER] == 0 || Work_GetStationRemaining(stationid) > 0;
}

stock Work_GetLayoutRevision()
{
	return s_WorkLayoutRevision;
}

stock Work_BumpLayoutRevision()
{
	s_WorkLayoutRevision++;
}

stock Work_GetStationCount()
{
	new count = 0;

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED])
		{
			count++;
		}
	}

	return count;
}

stock Work_OffsetFrom(Float:x,Float:y,Float:angle,Float:ox,Float:oy,&Float:outX,&Float:outY)
{
	outX = x + ox * floatcos(angle,degrees) - oy * floatsin(angle,degrees);
	outY = y + ox * floatsin(angle,degrees) + oy * floatcos(angle,degrees);
}

static Work_DestroyStationVisuals(stationid)
{
	pawn_call_public("Work_OnStationVisuals","dd",stationid,false);
	Work_FxClearStation(stationid);

	if (IsValidDynamic3DTextLabel(g_WorkStations[stationid][E_WORK_STATION_LABEL]))
	{
		DestroyDynamic3DTextLabel(g_WorkStations[stationid][E_WORK_STATION_LABEL]);
	}

	g_WorkStations[stationid][E_WORK_STATION_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

	for (new slot = 0;slot < WORK_PROP_SLOTS;slot++)
	{
		if (IsValidDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]))
		{
			DestroyDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]);
		}

		g_WorkStations[stationid][E_WORK_STATION_PROPS][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}
}

stock bool:Work_GetKindParts(kind,&first,&count)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);
	first = -1;
	count = 0;

	for (new i = 0;i < WORK_PART_COUNT;i++)
	{
		if (key[0] == EOS || strcmp(g_WorkPartDefs[i][E_WORK_PART_DEF_KIND],key) != 0)
		{
			continue;
		}

		if (first == -1)
		{
			first = i;
		}

		count++;
	}

	count = min(count,WORK_PROP_SLOTS);
	return count > 0;
}

stock Work_GetKindBodyModel(kind)
{
	new first, count;

	if (Work_GetKindParts(kind,first,count))
	{
		for (new i = first;i < first + count;i++)
		{
			if (g_WorkPartDefs[i][E_WORK_PART_DEF_IS_BODY])
			{
				return g_WorkPartDefs[i][E_WORK_PART_DEF_MODEL];
			}
		}
	}

	return WORK_PLACEHOLDER_MODEL;
}

stock bool:Work_SnapKind(kind,Float:x,Float:y,&Float:z,Float:a)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	for (new i = 0;i < WORK_PART_KIND_COUNT;i++)
	{
		if (key[0] != EOS && strcmp(g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_KIND],key) == 0)
		{
			new Float:halfW = g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_SIZE][0] / 2.0, Float:halfD = g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_SIZE][1] / 2.0;
			return Placement_SnapBox(x,y,z,a,-halfW,-halfD,halfW,halfD,0.0,g_WorkPartKindDefs[i][E_WORK_PART_KIND_DEF_SIZE][2]);
		}
	}

	return Placement_SnapToSurface(WORK_PLACEHOLDER_MODEL,x,y,z,a);
}

stock Work_StreamNear(Float:x,Float:y,Float:z,world)
{
	foreach (new playerid : Player)
	{
		if (!IsPlayerNPC(playerid) && GetPlayerVirtualWorld(playerid) == world && IsPlayerInRangeOfPoint(playerid,WORK_STREAM_RANGE,x,y,z))
		{
			Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
		}
	}
}

static Work_StreamStation(stationid)
{
	Work_StreamNear(g_WorkStations[stationid][E_WORK_STATION_POS][0],g_WorkStations[stationid][E_WORK_STATION_POS][1],g_WorkStations[stationid][E_WORK_STATION_POS][2],g_WorkStations[stationid][E_WORK_STATION_WORLD]);
}

static Work_DestroyStationSlot(stationid,slot)
{
	if (IsValidDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]))
	{
		DestroyDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]);
	}

	g_WorkStations[stationid][E_WORK_STATION_PROPS][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

static Work_SpawnPart(stationid,part,slot)
{
	new Float:x = g_WorkStations[stationid][E_WORK_STATION_POS][0], Float:y = g_WorkStations[stationid][E_WORK_STATION_POS][1], Float:z = g_WorkStations[stationid][E_WORK_STATION_POS][2], Float:a = g_WorkStations[stationid][E_WORK_STATION_POS][3], Float:px, Float:py;
	Work_DestroyStationSlot(stationid,slot);
	Work_OffsetFrom(x,y,a,g_WorkPartDefs[part][E_WORK_PART_DEF_OFFSET][0],g_WorkPartDefs[part][E_WORK_PART_DEF_OFFSET][1],px,py);
	g_WorkStations[stationid][E_WORK_STATION_PROPS][slot] = CreateDynamicObject(g_WorkPartDefs[part][E_WORK_PART_DEF_MODEL],px,py,z + g_WorkPartDefs[part][E_WORK_PART_DEF_OFFSET][2],0.0,0.0,a,g_WorkStations[stationid][E_WORK_STATION_WORLD],g_WorkStations[stationid][E_WORK_STATION_INTERIOR],-1,STREAMER_OBJECT_SD,STREAMER_OBJECT_DD,STREAMER_TAG_AREA:-1,WORK_PART_PRIORITY);
}

static bool:Work_VerbsMatch(const verbs[],const stageName[])
{
	new verb[WORK_PART_VERBS_LEN], start = 0, length = strlen(verbs);

	for (new i = 0;i <= length;i++)
	{
		if (verbs[i] != '|' && verbs[i] != EOS)
		{
			continue;
		}

		strmid(verb,verbs,start,i);
		start = i + 1;

		if (verb[0] != EOS && strfind(stageName,verb,true) != -1)
		{
			return true;
		}
	}

	return false;
}

stock bool:Work_VerbsMatchText(const verbs[],const stageName[])
{
	return Work_VerbsMatch(verbs,stageName);
}

stock bool:Work_VerbsMatchPublic(part,const stageName[])
{
	return part >= 0 && part < WORK_PART_COUNT && Work_VerbsMatch(g_WorkPartDefs[part][E_WORK_PART_DEF_SWAP_VERBS],stageName);
}

stock Work_StationBob(stationid,const stageName[])
{
	new first, count, fallback = -1, chosen = -1;

	if (!Work_IsValidStation(stationid) || !Work_GetKindParts(g_WorkStations[stationid][E_WORK_STATION_KIND],first,count))
	{
		return;
	}

	for (new slot = 0;slot < count;slot++)
	{
		new part = first + slot;

		if (!IsValidDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]) || g_WorkPartDefs[part][E_WORK_PART_DEF_IS_BODY])
		{
			continue;
		}

		if (g_WorkPartDefs[part][E_WORK_PART_DEF_BOB_VERBS][0] != EOS && Work_VerbsMatch(g_WorkPartDefs[part][E_WORK_PART_DEF_BOB_VERBS],stageName))
		{
			chosen = slot;
			break;
		}

		if (fallback == -1 && (g_WorkPartDefs[part][E_WORK_PART_DEF_IS_WORKPIECE] || g_WorkPartDefs[part][E_WORK_PART_DEF_IS_MOVER]))
		{
			fallback = slot;
		}
	}

	if (chosen == -1)
	{
		chosen = fallback;
	}

	if (chosen == -1)
	{
		Work_FxBurst(stationid,stageName,false,0.0,0.0,0.0);
		return;
	}

	new STREAMER_TAG_OBJECT:objectid = g_WorkStations[stationid][E_WORK_STATION_PROPS][chosen], Float:ox, Float:oy, Float:oz;
	GetDynamicObjectPos(objectid,ox,oy,oz);
	Work_FxBurst(stationid,stageName,true,ox,oy,oz);
	SetDynamicObjectPos(objectid,ox,oy,oz + WORK_PART_BOB);
	MoveDynamicObject(objectid,ox,oy,oz,0.5);
}

stock Work_StationStageDone(stationid,const stageName[])
{
	new first, count;

	if (!Work_IsValidStation(stationid) || !Work_GetKindParts(g_WorkStations[stationid][E_WORK_STATION_KIND],first,count))
	{
		return;
	}

	new bool:wasShown[WORK_PROP_SLOTS];

	for (new slot = 0;slot < count;slot++)
	{
		wasShown[slot] = bool:IsValidDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]);
	}

	for (new slot = 0;slot < count;slot++)
	{
		new part = first + slot, target = g_WorkPartDefs[part][E_WORK_PART_DEF_SWAP_TO];

		if (wasShown[slot] && target >= first && target < first + count && Work_VerbsMatch(g_WorkPartDefs[part][E_WORK_PART_DEF_SWAP_VERBS],stageName))
		{
			Work_DestroyStationSlot(stationid,slot);
			Work_SpawnPart(stationid,target,target - first);
		}
		else if (!wasShown[slot] && !IsValidDynamicObject(g_WorkStations[stationid][E_WORK_STATION_PROPS][slot]) && g_WorkPartDefs[part][E_WORK_PART_DEF_SHOW_VERBS][0] != EOS && Work_VerbsMatch(g_WorkPartDefs[part][E_WORK_PART_DEF_SHOW_VERBS],stageName))
		{
			Work_SpawnPart(stationid,part,slot);
		}
	}

	Work_StreamStation(stationid);
}

stock Work_ResetStationProps(stationid)
{
	Work_FxClearStage(stationid);

	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND], world = g_WorkStations[stationid][E_WORK_STATION_WORLD], interior = g_WorkStations[stationid][E_WORK_STATION_INTERIOR];
	new Float:x = g_WorkStations[stationid][E_WORK_STATION_POS][0], Float:y = g_WorkStations[stationid][E_WORK_STATION_POS][1], Float:z = g_WorkStations[stationid][E_WORK_STATION_POS][2], Float:a = g_WorkStations[stationid][E_WORK_STATION_POS][3];

	for (new slot = 0;slot < WORK_PROP_SLOTS;slot++)
	{
		Work_DestroyStationSlot(stationid,slot);
	}

	new first, count;

	if (Work_GetKindParts(kind,first,count))
	{
		for (new slot = 0;slot < count;slot++)
		{
			if (g_WorkPartDefs[first + slot][E_WORK_PART_DEF_IS_VISIBLE])
			{
				Work_SpawnPart(stationid,first + slot,slot);
			}
		}

		Work_StreamStation(stationid);
		return;
	}

	for (new slot = 0;slot < WORK_PROP_SLOTS;slot++)
	{
		new model, Float:ox, Float:oy, Float:oz, Float:rx, Float:ry, Float:rz, Float:px, Float:py, bool:isWood, bool:isLabel;

		if (!Work_GetKindProp(kind,slot,model,ox,oy,oz,rx,ry,rz,isWood,isLabel))
		{
			continue;
		}

		Work_OffsetFrom(x,y,a,ox,oy,px,py);

		new STREAMER_TAG_OBJECT:objectid = CreateDynamicObject(model,px,py,z + oz,rx,ry,a + rz,world,interior,-1,STREAMER_OBJECT_SD,STREAMER_OBJECT_DD,STREAMER_TAG_AREA:-1,WORK_PART_PRIORITY);
		g_WorkStations[stationid][E_WORK_STATION_PROPS][slot] = objectid;

		for (new material = 0;isWood && material < WORK_WOOD_MATERIALS;material++)
		{
			SetDynamicObjectMaterial(objectid,material,WORK_WOOD_MODEL,WORK_WOOD_TXD,WORK_WOOD_TEXTURE,0);
		}

		if (isLabel)
		{
			new name[WORK_KIND_NAME_LEN];
			Work_GetKindName(kind,name);
			SetDynamicObjectMaterialText(objectid,0,name,_:OBJECT_MATERIAL_SIZE_256x128,"Arial",28,1,WORK_BODY_TEXT_COLOUR,WORK_BODY_BACK_COLOUR,1);
		}
	}

	Work_StreamStation(stationid);
}

static Work_BuildStationVisuals(stationid)
{
	Work_DestroyStationVisuals(stationid);

	new name[WORK_KIND_NAME_LEN];
	Work_GetKindName(g_WorkStations[stationid][E_WORK_STATION_KIND],name);
	g_WorkStations[stationid][E_WORK_STATION_LABEL] = CreateDynamic3DTextLabel(name,WORK_LABEL_COLOUR,g_WorkStations[stationid][E_WORK_STATION_POS][0],g_WorkStations[stationid][E_WORK_STATION_POS][1],g_WorkStations[stationid][E_WORK_STATION_POS][2] + 0.4,WORK_LABEL_RANGE,INVALID_PLAYER_ID,INVALID_VEHICLE_ID,1,g_WorkStations[stationid][E_WORK_STATION_WORLD],g_WorkStations[stationid][E_WORK_STATION_INTERIOR]);
	Work_ResetStationProps(stationid);
	Work_FxStationBuilt(stationid);
	pawn_call_public("Work_OnStationVisuals","dd",stationid,true);
}

static Work_FindFreeStation()
{
	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (!g_WorkStations[i][E_WORK_STATION_USED])
		{
			return i;
		}
	}

	return -1;
}

static Work_ClearStation(stationid)
{
	g_WorkStations[stationid][E_WORK_STATION_USED] = false;
	s_WorkStationRuined[stationid] = false;
	g_WorkStations[stationid][E_WORK_STATION_ROW] = 0;
	g_WorkStations[stationid][E_WORK_STATION_WORKER] = INVALID_PLAYER_ID;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_DIST] = 1.0;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_LIFT] = 0.0;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_AIM] = 0.0;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_SIDE] = 0.0;
	g_WorkStations[stationid][E_WORK_STATION_OWNER] = 0;
	g_WorkStations[stationid][E_WORK_STATION_PLACED] = 0;
	g_WorkStations[stationid][E_WORK_STATION_GRACE] = 0;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM] = -1;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS] = 0;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] = 0;

	for (new i = 0;i < WORK_INVITES_MAX;i++)
	{
		g_WorkStations[stationid][E_WORK_STATION_INVITES][i] = 0;
	}
}

static Work_AddStation(row,kind,Float:x,Float:y,Float:z,Float:a,Float:standX,Float:standY,Float:standZ,Float:standA,world,interior,const Float:shot[4],owner = 0,placed = 0,grace = 0,fuelItem = -1,fuelUnits = 0,fuelSeconds = 0)
{
	new stationid = Work_FindFreeStation();

	if (stationid == -1)
	{
		Log_Error("workstations","station table full at %d",WORK_MAX_STATIONS);
		return -1;
	}

	Work_ClearStation(stationid);
	g_WorkStations[stationid][E_WORK_STATION_USED] = true;
	s_WorkStationRuined[stationid] = false;
	g_WorkStations[stationid][E_WORK_STATION_ROW] = row;
	g_WorkStations[stationid][E_WORK_STATION_KIND] = kind;
	g_WorkStations[stationid][E_WORK_STATION_POS][0] = x;
	g_WorkStations[stationid][E_WORK_STATION_POS][1] = y;
	g_WorkStations[stationid][E_WORK_STATION_POS][2] = z;
	g_WorkStations[stationid][E_WORK_STATION_POS][3] = a;
	g_WorkStations[stationid][E_WORK_STATION_STAND][0] = standX;
	g_WorkStations[stationid][E_WORK_STATION_STAND][1] = standY;
	g_WorkStations[stationid][E_WORK_STATION_STAND][2] = standZ;
	g_WorkStations[stationid][E_WORK_STATION_STAND][3] = standA;
	g_WorkStations[stationid][E_WORK_STATION_WORLD] = world;
	g_WorkStations[stationid][E_WORK_STATION_INTERIOR] = interior;

	for (new i = 0;i < 4;i++)
	{
		g_WorkStations[stationid][E_WORK_STATION_SHOT][i] = shot[i];
	}

	g_WorkStations[stationid][E_WORK_STATION_OWNER] = owner;
	g_WorkStations[stationid][E_WORK_STATION_PLACED] = placed;
	g_WorkStations[stationid][E_WORK_STATION_GRACE] = grace;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM] = fuelItem;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS] = fuelUnits;
	g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS] = fuelSeconds;
	Work_BuildStationVisuals(stationid);
	s_WorkLayoutRevision++;
	return stationid;
}

static bool:Work_HasKindView(kind)
{
	return kind >= 0 && kind < WORK_KIND_VIEW_MAX && s_WorkKindViews[kind][E_WORK_KIND_VIEW_SET];
}

stock Work_FindKindStandDef(kind)
{
	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);

	for (new i = 0;key[0] != EOS && i < sizeof(s_WorkKindStandDefs);i++)
	{
		if (!strcmp(s_WorkKindStandDefs[i][E_WORK_KIND_STAND_DEF_KIND],key))
		{
			return i;
		}
	}

	return -1;
}

stock Work_GetKindStand(kind,Float:x,Float:y,Float:z,Float:a,&Float:standX,&Float:standY,&Float:standZ,&Float:standA)
{
	new def = Work_HasKindView(kind) ? -1 : Work_FindKindStandDef(kind);

	if (!Work_HasKindView(kind) && def == -1)
	{
		Work_GetDefaultStand(x,y,z,a,standX,standY,standZ,standA);
		return;
	}

	new Float:ahead, Float:right, Float:lift, Float:turn;

	if (def != -1)
	{
		ahead = s_WorkKindStandDefs[def][E_WORK_KIND_STAND_DEF_AHEAD];
		right = s_WorkKindStandDefs[def][E_WORK_KIND_STAND_DEF_RIGHT];
		lift = 1.0;
		turn = s_WorkKindStandDefs[def][E_WORK_KIND_STAND_DEF_TURN];
	}
	else
	{
		ahead = s_WorkKindViews[kind][E_WORK_KIND_VIEW_AHEAD];
		right = s_WorkKindViews[kind][E_WORK_KIND_VIEW_RIGHT];
		lift = s_WorkKindViews[kind][E_WORK_KIND_VIEW_LIFT];
		turn = s_WorkKindViews[kind][E_WORK_KIND_VIEW_TURN];
	}

	standX = x + ahead * floatsin(a,degrees) + right * floatcos(a,degrees);
	standY = y - ahead * floatcos(a,degrees) + right * floatsin(a,degrees);
	standZ = z + lift;

	new Float:surfaceZ;

	if (Placement_FindSurface(standX,standY,z + 1.5,4.0,surfaceZ))
	{
		standZ = surfaceZ + 1.0;
	}

	standA = Util_NormalizeAngle(a + turn);
}

stock Work_GetKindShot(kind,Float:shot[4])
{
	for (new i = 0;i < 4;i++)
	{
		shot[i] = Work_HasKindView(kind) ? s_WorkKindViews[kind][E_WORK_KIND_VIEW_SHOT][i] : (i == WORK_SHOT_DIST ? 1.0 : 0.0);
	}
}

static Work_SetKindViewLocal(kind,Float:right,Float:ahead,Float:lift,Float:turn,const Float:shot[4])
{
	if (kind < 0 || kind >= WORK_KIND_VIEW_MAX)
	{
		return;
	}

	s_WorkKindViews[kind][E_WORK_KIND_VIEW_SET] = true;
	s_WorkKindViews[kind][E_WORK_KIND_VIEW_RIGHT] = right;
	s_WorkKindViews[kind][E_WORK_KIND_VIEW_AHEAD] = ahead;
	s_WorkKindViews[kind][E_WORK_KIND_VIEW_LIFT] = lift;
	s_WorkKindViews[kind][E_WORK_KIND_VIEW_TURN] = turn;

	for (new i = 0;i < 4;i++)
	{
		s_WorkKindViews[kind][E_WORK_KIND_VIEW_SHOT][i] = shot[i];
	}
}

stock Work_ClearKindView(kind)
{
	if (!Work_HasKindView(kind))
	{
		return;
	}

	new key[WORK_KIND_KEY_LEN];
	Work_GetKindKey(kind,key);
	s_WorkKindViews[kind][E_WORK_KIND_VIEW_SET] = false;
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM station_kind_views WHERE kind = '%e'",key));
}

stock Work_SaveKindViewFrom(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return 0;
	}

	new kind = g_WorkStations[stationid][E_WORK_STATION_KIND], key[WORK_KIND_KEY_LEN], Float:shot[4];
	new Float:a = g_WorkStations[stationid][E_WORK_STATION_POS][3];
	new Float:dx = g_WorkStations[stationid][E_WORK_STATION_STAND][0] - g_WorkStations[stationid][E_WORK_STATION_POS][0];
	new Float:dy = g_WorkStations[stationid][E_WORK_STATION_STAND][1] - g_WorkStations[stationid][E_WORK_STATION_POS][1];
	new Float:ahead = dx * floatsin(a,degrees) - dy * floatcos(a,degrees);
	new Float:right = dx * floatcos(a,degrees) + dy * floatsin(a,degrees);
	new Float:lift = g_WorkStations[stationid][E_WORK_STATION_STAND][2] - g_WorkStations[stationid][E_WORK_STATION_POS][2];
	new Float:turn = Util_NormalizeAngle(g_WorkStations[stationid][E_WORK_STATION_STAND][3] - a);

	for (new i = 0;i < 4;i++)
	{
		shot[i] = g_WorkStations[stationid][E_WORK_STATION_SHOT][i];
	}

	Work_SetKindViewLocal(kind,right,ahead,lift,turn,shot);
	Work_GetKindKey(kind,key);
	mysql_tquery_s(g_Mysql,str_format("REPLACE INTO station_kind_views (kind, stand_right, stand_ahead, stand_lift, stand_turn, shot_dist, shot_lift, shot_aim, shot_side) VALUES ('%e', %f, %f, %f, %f, %f, %f, %f, %f)",key,right,ahead,lift,turn,shot[WORK_SHOT_DIST],shot[WORK_SHOT_LIFT],shot[WORK_SHOT_AIM],shot[WORK_SHOT_SIDE]));

	new updated = 0;

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (i == stationid || !g_WorkStations[i][E_WORK_STATION_USED] || g_WorkStations[i][E_WORK_STATION_KIND] != kind)
		{
			continue;
		}

		pawn_call_public("Work_OnStationChanged","d",i);
		Work_GetKindStand(kind,g_WorkStations[i][E_WORK_STATION_POS][0],g_WorkStations[i][E_WORK_STATION_POS][1],g_WorkStations[i][E_WORK_STATION_POS][2],g_WorkStations[i][E_WORK_STATION_POS][3],g_WorkStations[i][E_WORK_STATION_STAND][0],g_WorkStations[i][E_WORK_STATION_STAND][1],g_WorkStations[i][E_WORK_STATION_STAND][2],g_WorkStations[i][E_WORK_STATION_STAND][3]);

		for (new f = 0;f < 4;f++)
		{
			g_WorkStations[i][E_WORK_STATION_SHOT][f] = shot[f];
		}

		Work_SaveStation(i);
		Work_BuildDress(i);
		updated++;
	}

	return updated;
}

stock Work_GetDefaultStand(Float:x,Float:y,Float:z,Float:a,&Float:standX,&Float:standY,&Float:standZ,&Float:standA)
{
	standX = x + WORK_STAND_DISTANCE * floatsin(a,degrees);
	standY = y - WORK_STAND_DISTANCE * floatcos(a,degrees);
	standZ = z + 1.0;

	new Float:surfaceZ;

	if (Placement_FindSurface(standX,standY,z + 1.5,4.0,surfaceZ))
	{
		standZ = surfaceZ + 1.0;
	}

	standA = Util_NormalizeAngle(a);
}

#pragma warning push
#pragma warning disable 204
forward Task:Work_CreateStation(kind,Float:x,Float:y,Float:z,Float:a,world,interior,owner = 0);

async Task:Work_CreateStation(kind,Float:x,Float:y,Float:z,Float:a,world,interior,owner = 0)
{
	new key[WORK_KIND_KEY_LEN], Float:standX, Float:standY, Float:standZ, Float:standA, Float:shot[4], placed = gettime(), fuelSeconds = owner > 0 ? WORK_BASE_SECONDS : 0;
	Work_GetKindKey(kind,key);
	Work_GetKindStand(kind,x,y,z,a,standX,standY,standZ,standA);
	Work_GetKindShot(kind,shot);

	await mysql_aquery_s(g_Mysql,str_format("INSERT INTO stations (kind, x, y, z, a, stand_x, stand_y, stand_z, stand_a, world, interior, owner_character_id, placed_at, fuel_seconds, shot_dist, shot_lift, shot_aim, shot_side) VALUES ('%e', %f, %f, %f, %f, %f, %f, %f, %f, %d, %d, %d, %d, %d, %f, %f, %f, %f)",key,x,y,z,a,standX,standY,standZ,standA,world,interior,owner,placed,fuelSeconds,shot[WORK_SHOT_DIST],shot[WORK_SHOT_LIFT],shot[WORK_SHOT_AIM],shot[WORK_SHOT_SIDE]));

	new row = cache_insert_id();
	return async row > 0 ? Work_AddStation(row,kind,x,y,z,a,standX,standY,standZ,standA,world,interior,shot,owner,placed,0,-1,0,fuelSeconds) : -1;
}
#pragma warning pop

static Work_SaveStation(stationid)
{
	mysql_tquery_s(g_Mysql,str_format("UPDATE stations SET x = %f, y = %f, z = %f, a = %f, stand_x = %f, stand_y = %f, stand_z = %f, stand_a = %f, shot_dist = %f, shot_lift = %f, shot_aim = %f, shot_side = %f WHERE id = %d",g_WorkStations[stationid][E_WORK_STATION_POS][0],g_WorkStations[stationid][E_WORK_STATION_POS][1],g_WorkStations[stationid][E_WORK_STATION_POS][2],g_WorkStations[stationid][E_WORK_STATION_POS][3],g_WorkStations[stationid][E_WORK_STATION_STAND][0],g_WorkStations[stationid][E_WORK_STATION_STAND][1],g_WorkStations[stationid][E_WORK_STATION_STAND][2],g_WorkStations[stationid][E_WORK_STATION_STAND][3],g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_DIST],g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_LIFT],g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_AIM],g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_SIDE],g_WorkStations[stationid][E_WORK_STATION_ROW]));
}

stock Work_SaveStationState(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	mysql_tquery_s(g_Mysql,str_format("UPDATE stations SET grace_until = %d, fuel_item = %d, fuel_units = %d, fuel_seconds = %d WHERE id = %d",g_WorkStations[stationid][E_WORK_STATION_GRACE],g_WorkStations[stationid][E_WORK_STATION_FUEL_ITEM],g_WorkStations[stationid][E_WORK_STATION_FUEL_UNITS],g_WorkStations[stationid][E_WORK_STATION_FUEL_SECONDS],g_WorkStations[stationid][E_WORK_STATION_ROW]));
}

stock Work_MoveStation(stationid,Float:x,Float:y,Float:z,Float:a)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	pawn_call_public("Work_OnStationChanged","d",stationid);
	g_WorkStations[stationid][E_WORK_STATION_POS][0] = x;
	g_WorkStations[stationid][E_WORK_STATION_POS][1] = y;
	g_WorkStations[stationid][E_WORK_STATION_POS][2] = z;
	g_WorkStations[stationid][E_WORK_STATION_POS][3] = a;
	Work_GetKindStand(g_WorkStations[stationid][E_WORK_STATION_KIND],x,y,z,a,g_WorkStations[stationid][E_WORK_STATION_STAND][0],g_WorkStations[stationid][E_WORK_STATION_STAND][1],g_WorkStations[stationid][E_WORK_STATION_STAND][2],g_WorkStations[stationid][E_WORK_STATION_STAND][3]);
	Work_BuildStationVisuals(stationid);
	Work_SaveStation(stationid);
}

stock Work_SetStationStand(stationid,Float:x,Float:y,Float:z,Float:a)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	pawn_call_public("Work_OnStationChanged","d",stationid);
	g_WorkStations[stationid][E_WORK_STATION_STAND][0] = x;
	g_WorkStations[stationid][E_WORK_STATION_STAND][1] = y;
	g_WorkStations[stationid][E_WORK_STATION_STAND][2] = z;
	g_WorkStations[stationid][E_WORK_STATION_STAND][3] = a;
	Work_SaveStation(stationid);
	Work_SaveKindViewFrom(stationid);
	Work_BuildDress(stationid);
}

stock Work_AdjustStationShot(stationid,field,Float:delta)
{
	if (!Work_IsValidStation(stationid) || field < 0 || field >= 4)
	{
		return;
	}

	g_WorkStations[stationid][E_WORK_STATION_SHOT][field] += delta;

	if (field == WORK_SHOT_DIST)
	{
		g_WorkStations[stationid][E_WORK_STATION_SHOT][field] = Util_Clamp(g_WorkStations[stationid][E_WORK_STATION_SHOT][field],0.4,3.0);
	}

	Work_SaveStation(stationid);
	Work_SaveKindViewFrom(stationid);
}

stock bool:Work_SetShotFromCamera(stationid,Float:cameraX,Float:cameraY,Float:cameraZ,Float:frontX,Float:frontY,Float:frontZ)
{
	if (!Work_IsValidStation(stationid))
	{
		return false;
	}

	new Float:heading = g_WorkStations[stationid][E_WORK_STATION_STAND][3] + 180.0;
	new Float:dx = cameraX - g_WorkStations[stationid][E_WORK_STATION_POS][0], Float:dy = cameraY - g_WorkStations[stationid][E_WORK_STATION_POS][1];
	new Float:ahead = -dx * floatsin(heading,degrees) + dy * floatcos(heading,degrees);
	new Float:side = dx * floatcos(heading,degrees) + dy * floatsin(heading,degrees);
	new Float:flat = floatsqroot(frontX * frontX + frontY * frontY);

	if (ahead <= 0.2 || flat < 0.05)
	{
		return false;
	}

	new Float:reach = floatsqroot(ahead * ahead + side * side) / flat;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_DIST] = Util_Clamp(ahead / SCENE_DEFAULT_DIST,0.4,3.0);
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_SIDE] = side;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_LIFT] = cameraZ - g_WorkStations[stationid][E_WORK_STATION_POS][2] - SCENE_DEFAULT_LIFT;
	g_WorkStations[stationid][E_WORK_STATION_SHOT][WORK_SHOT_AIM] = cameraZ + frontZ * reach - g_WorkStations[stationid][E_WORK_STATION_POS][2] - SCENE_DEFAULT_AIM;
	Work_SaveStation(stationid);
	Work_SaveKindViewFrom(stationid);
	return true;
}

stock Float:Work_GetStationShot(stationid,field)
{
	return Work_IsValidStation(stationid) && field >= 0 && field < 4 ? g_WorkStations[stationid][E_WORK_STATION_SHOT][field] : 0.0;
}

stock Work_DeleteStationsInWorld(world)
{
	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (Work_IsValidStation(i) && g_WorkStations[i][E_WORK_STATION_WORLD] == world)
		{
			Work_DeleteStation(i);
		}
	}
}

stock Work_DeleteStation(stationid)
{
	if (!Work_IsValidStation(stationid))
	{
		return;
	}

	pawn_call_public("Work_OnStationChanged","d",stationid);
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM stations WHERE id = %d",g_WorkStations[stationid][E_WORK_STATION_ROW]));
	mysql_tquery_s(g_Mysql,str_format("DELETE FROM station_invites WHERE station_id = %d",g_WorkStations[stationid][E_WORK_STATION_ROW]));
	Work_DestroyStationVisuals(stationid);
	Work_ClearStation(stationid);
	s_WorkLayoutRevision++;
}

stock Work_FindStationByRow(row)
{
	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (g_WorkStations[i][E_WORK_STATION_USED] && g_WorkStations[i][E_WORK_STATION_ROW] == row)
		{
			return i;
		}
	}

	return -1;
}

stock bool:Work_AddInviteLocal(stationid,characterid)
{
	if (!Work_IsValidStation(stationid) || characterid <= 0)
	{
		return false;
	}

	for (new i = 0;i < WORK_INVITES_MAX;i++)
	{
		if (g_WorkStations[stationid][E_WORK_STATION_INVITES][i] == characterid)
		{
			return true;
		}
	}

	for (new i = 0;i < WORK_INVITES_MAX;i++)
	{
		if (g_WorkStations[stationid][E_WORK_STATION_INVITES][i] == 0)
		{
			g_WorkStations[stationid][E_WORK_STATION_INVITES][i] = characterid;
			return true;
		}
	}

	return false;
}

stock Work_FindNearestStation(Float:x,Float:y,Float:z,world,Float:range,&Float:distance = 0.0,bool:isAroundBody = false)
{
	new best = -1;
	distance = range;

	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		if (!g_WorkStations[i][E_WORK_STATION_USED] || g_WorkStations[i][E_WORK_STATION_WORLD] != world)
		{
			continue;
		}

		new Float:d = Util_GetDistance3D(x,y,z,g_WorkStations[i][E_WORK_STATION_STAND][0],g_WorkStations[i][E_WORK_STATION_STAND][1],g_WorkStations[i][E_WORK_STATION_STAND][2]);

		if (isAroundBody)
		{
			new Float:body = Util_GetDistance3D(x,y,z,g_WorkStations[i][E_WORK_STATION_POS][0],g_WorkStations[i][E_WORK_STATION_POS][1],g_WorkStations[i][E_WORK_STATION_POS][2]);

			if (body < d)
			{
				d = body;
			}
		}

		if (d < distance)
		{
			distance = d;
			best = i;
		}
	}

	return best;
}

forward Work_LoadStationsOnBoot();

public Work_LoadStationsOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT kind, stand_right, stand_ahead, stand_lift, stand_turn, shot_dist, shot_lift, shot_aim, shot_side FROM station_kind_views"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new key[WORK_KIND_KEY_LEN], Float:view[4], Float:shot[4];
		cache_get_value_name(r,"kind",key);
		cache_get_value_name_float(r,"stand_right",view[0]);
		cache_get_value_name_float(r,"stand_ahead",view[1]);
		cache_get_value_name_float(r,"stand_lift",view[2]);
		cache_get_value_name_float(r,"stand_turn",view[3]);
		cache_get_value_name_float(r,"shot_dist",shot[WORK_SHOT_DIST]);
		cache_get_value_name_float(r,"shot_lift",shot[WORK_SHOT_LIFT]);
		cache_get_value_name_float(r,"shot_aim",shot[WORK_SHOT_AIM]);
		cache_get_value_name_float(r,"shot_side",shot[WORK_SHOT_SIDE]);
		Work_SetKindViewLocal(Work_FindKind(key),view[0],view[1],view[2],view[3],shot);
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT id, kind, x, y, z, a, stand_x, stand_y, stand_z, stand_a, world, interior, shot_dist, shot_lift, shot_aim, shot_side, IFNULL(owner_character_id, 0) AS owner, placed_at, grace_until, fuel_item, fuel_units, fuel_seconds FROM stations ORDER BY id"));

	new placed = 0, skipped = 0;

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new row, key[WORK_KIND_KEY_LEN], Float:pos[4], Float:stand[4], Float:shot[4], world, interior, owner, placedAt, grace, fuelItem, fuelUnits, fuelSeconds;
		cache_get_value_name_int(r,"owner",owner);
		cache_get_value_name_int(r,"placed_at",placedAt);
		cache_get_value_name_int(r,"grace_until",grace);
		cache_get_value_name_int(r,"fuel_item",fuelItem);
		cache_get_value_name_int(r,"fuel_units",fuelUnits);
		cache_get_value_name_int(r,"fuel_seconds",fuelSeconds);
		cache_get_value_name_int(r,"id",row);
		cache_get_value_name(r,"kind",key);
		cache_get_value_name_float(r,"x",pos[0]);
		cache_get_value_name_float(r,"y",pos[1]);
		cache_get_value_name_float(r,"z",pos[2]);
		cache_get_value_name_float(r,"a",pos[3]);
		cache_get_value_name_float(r,"stand_x",stand[0]);
		cache_get_value_name_float(r,"stand_y",stand[1]);
		cache_get_value_name_float(r,"stand_z",stand[2]);
		cache_get_value_name_float(r,"stand_a",stand[3]);
		cache_get_value_name_int(r,"world",world);
		cache_get_value_name_int(r,"interior",interior);
		cache_get_value_name_float(r,"shot_dist",shot[WORK_SHOT_DIST]);
		cache_get_value_name_float(r,"shot_lift",shot[WORK_SHOT_LIFT]);
		cache_get_value_name_float(r,"shot_aim",shot[WORK_SHOT_AIM]);
		cache_get_value_name_float(r,"shot_side",shot[WORK_SHOT_SIDE]);

		new kind = Work_FindKind(key);

		if (kind != -1 && !Work_HasKindView(kind) && Work_FindKindStandDef(kind) != -1)
		{
			Work_GetKindStand(kind,pos[0],pos[1],pos[2],pos[3],stand[0],stand[1],stand[2],stand[3]);
		}

		if (kind == -1 || Work_IsNodeKind(kind) || Work_AddStation(row,kind,pos[0],pos[1],pos[2],pos[3],stand[0],stand[1],stand[2],stand[3],world,interior,shot,owner,placedAt,grace,fuelItem,fuelUnits,fuelSeconds) == -1)
		{
			skipped++;
			continue;
		}

		placed++;
	}

	await mysql_aquery_s(g_Mysql,str_new("SELECT i.character_id, s.id FROM station_invites i JOIN stations s ON s.id = i.station_id"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new characterid, row;
		cache_get_value_name_int(r,"character_id",characterid);
		cache_get_value_name_int(r,"id",row);
		Work_AddInviteLocal(Work_FindStationByRow(row),characterid);
	}

	Log_Info("workstations","%d station(s) placed, %d skipped",placed,skipped);
	Boot_LoaderDone();
}

forward Work_OnStationVisuals(stationid,bool:isShown);

public Work_OnStationVisuals(stationid,bool:isShown)
{
	return 1;
}

forward Work_OnStationChanged(stationid);

public Work_OnStationChanged(stationid)
{
	return 1;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	for (new i = 0;i < WORK_MAX_STATIONS;i++)
	{
		Work_ClearStation(i);
		g_WorkStations[i][E_WORK_STATION_LABEL] = STREAMER_TAG_3D_TEXT_LABEL:INVALID_STREAMER_ID;

		for (new slot = 0;slot < WORK_PROP_SLOTS;slot++)
		{
			g_WorkStations[i][E_WORK_STATION_PROPS][slot] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
		}
	}
}
