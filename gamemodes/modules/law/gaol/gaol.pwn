#define GAOL_SKY_X (3000.0)
#define GAOL_SKY_Y (3000.0)
#define GAOL_SKY_Z (1200.0)
#define GAOL_CELLS (3)
#define GAOL_PIECES_MAX (16)
#define GAOL_DOOR_REACH (2.0)
#define GAOL_GRATE_REACH (1.6)
#define GAOL_STREAM_RANGE (80.0)
#define GAOL_WORK_MS (20000)
#define GAOL_LOOSE_PERCENT (60)
#define GAOL_NOISE_RANGE (25.0)
#define GAOL_CAUGHT_LOSS (25)
#define GAOL_CAUGHT_MINUTES (15)
#define GAOL_DOOR_SET_IN (0.2)
#define MODEL_GAOL_WALL_DOOR (-8201)
#define MODEL_GAOL_WALL_DOOR_SHUT (-8202)
#define MODEL_GAOL_WALL_WINDOW (-8203)
#define GAOL_PLUG_LOCKED (MODEL_GAOL_WALL_DOOR_SHUT)
#define GAOL_PLUG_FREE (MODEL_GAOL_WALL_DOOR)
#define GAOL_HOLD_Y (200.0)
#define GAOL_HOLD_PIECES (3 + GAOL_CELLS * 5)
#define GAOL_HOLD_PRELOAD_MS (1500)
#define GAOL_DOORWAY_GAP (1.0)
#define GAOL_KEEPER_RANGE (12.0)
#define GAOL_LIGHTS_CELLS (0)
#define GAOL_LIGHTS_HOLD (1)

new const Float:g_GaolCellCentres[GAOL_CELLS][3] = {
	{-8.0, -14.0, 90.0},
	{8.0, -14.0, 90.0},
	{0.0, -22.0, 0.0}
};

new const Float:g_GaolCellDoors[GAOL_CELLS][3] = {
	{-6.0, -14.0, 90.0},
	{6.0, -14.0, 270.0},
	{0.0, -20.0, 180.0}
};

new const Float:g_GaolCellGrates[GAOL_CELLS][3] = {
	{-9.8, -14.0, 90.0},
	{9.8, -14.0, 270.0},
	{0.0, -23.8, 180.0}
};

new const Float:g_GaolCellCaps[GAOL_CELLS][3] = {
	{-10.0, -14.0, 90.0},
	{10.0, -14.0, 270.0},
	{0.0, -24.0, 180.0}
};

static STREAMER_TAG_OBJECT:s_GaolPieces[GAOL_PIECES_MAX];
static s_GaolPieceCount;
static STREAMER_TAG_OBJECT:s_GaolGrates[GAOL_CELLS];
static STREAMER_TAG_OBJECT:s_GaolDoorPlugs[GAOL_CELLS];
static STREAMER_TAG_OBJECT:s_GaolCellDoors[GAOL_CELLS];
static s_GaolProgress[GAOL_CELLS];
static s_GaolPrisoner[GAOL_CELLS] = {INVALID_PLAYER_ID, ...};
static s_GaolKeeper[GAOL_CELLS] = {INVALID_PLAYER_ID, ...};
static s_GaolCellOf[MAX_PLAYERS] = {-1, ...};
static s_GaolWorkToken[MAX_PLAYERS];
static bool:s_GaolWorking[MAX_PLAYERS];
static STREAMER_TAG_OBJECT:s_GaolHoldPieces[GAOL_HOLD_PIECES];
static bool:s_GaolHeld[MAX_PLAYERS];

stock Gaol_ToWorld(Float:localX,Float:localY,Float:localZ,&Float:x,&Float:y,&Float:z)
{
	x = GAOL_SKY_X + localX;
	y = GAOL_SKY_Y + localY;
	z = GAOL_SKY_Z + localZ;
}

static Gaol_AddPiece(model,Float:localX,Float:localY,Float:localZ,Float:rz)
{
	if (s_GaolPieceCount >= GAOL_PIECES_MAX)
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(localX,localY,localZ,x,y,z);
	s_GaolPieces[s_GaolPieceCount++] = CreateDynamicObject(model,x,y,z,0.0,0.0,rz,GAOL_WORLD,GAOL_INTERIOR,-1,GAOL_STREAM_RANGE,GAOL_STREAM_RANGE);
	Util_WatchInteriorShell(s_GaolPieces[s_GaolPieceCount - 1]);
	Light_FollowModel(LIGHT_FOLLOW_GAOL,GAOL_LIGHTS_CELLS,model,x,y,z,rz,GAOL_WORLD,GAOL_INTERIOR);
}

stock Gaol_RefreshGrate(cell)
{
	if (IsValidDynamicObject(s_GaolGrates[cell]))
	{
		DestroyDynamicObject(s_GaolGrates[cell]);
	}

	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(g_GaolCellGrates[cell][0],g_GaolCellGrates[cell][1],1.3,x,y,z);
	s_GaolGrates[cell] = CreateDynamicObject(s_GaolProgress[cell] >= GAOL_LOOSE_PERCENT ? MODEL_VILLAGE_CELL_BARS_LOOSE : MODEL_VILLAGE_CELL_BARS,x,y,z,0.0,0.0,g_GaolCellGrates[cell][2],GAOL_WORLD,GAOL_INTERIOR,-1,GAOL_STREAM_RANGE,GAOL_STREAM_RANGE);
	Nearby_StreamObjectsAt(x,y,z,GAOL_WORLD,GAOL_INTERIOR,GAOL_STREAM_RANGE);
}

static bool:Gaol_IsInCellBox(playerid,cell,Float:offsetY)
{
	new Float:x, Float:y, Float:z, Float:cx, Float:cy, Float:cz;
	GetPlayerPos(playerid,x,y,z);
	Gaol_ToWorld(g_GaolCellCentres[cell][0],g_GaolCellCentres[cell][1] + offsetY,0.0,cx,cy,cz);

	if (g_GaolCellCentres[cell][2] == 90.0)
	{
		return floatabs(x - cx) <= 2.1 && floatabs(y - cy) <= 1.7;
	}

	return floatabs(x - cx) <= 1.7 && floatabs(y - cy) <= 2.1;
}

stock Gaol_RefreshDoor(cell)
{
	if (IsValidDynamicObject(s_GaolDoorPlugs[cell]))
	{
		DestroyDynamicObject(s_GaolDoorPlugs[cell]);
	}

	if (IsValidDynamicObject(s_GaolCellDoors[cell]))
	{
		DestroyDynamicObject(s_GaolCellDoors[cell]);
		s_GaolCellDoors[cell] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	}

	new Float:x, Float:y, Float:z, Float:rz = g_GaolCellDoors[cell][2];
	Gaol_ToWorld(g_GaolCellDoors[cell][0],g_GaolCellDoors[cell][1],0.0,x,y,z);
	s_GaolDoorPlugs[cell] = CreateDynamicObject(s_GaolKeeper[cell] == INVALID_PLAYER_ID ? GAOL_PLUG_LOCKED : GAOL_PLUG_FREE,x,y,z,0.0,0.0,rz,GAOL_WORLD,GAOL_INTERIOR,-1,GAOL_STREAM_RANGE,GAOL_STREAM_RANGE);

	if (s_GaolKeeper[cell] == INVALID_PLAYER_ID)
	{
		s_GaolCellDoors[cell] = CreateDynamicObject(MODEL_VILLAGE_CELL_DOOR,x + GAOL_DOOR_SET_IN * floatsin(rz,degrees),y - GAOL_DOOR_SET_IN * floatcos(rz,degrees),z,0.0,0.0,rz,GAOL_WORLD,GAOL_INTERIOR,-1,GAOL_STREAM_RANGE,GAOL_STREAM_RANGE);
	}

	Nearby_StreamObjectsAt(x,y,z,GAOL_WORLD,GAOL_INTERIOR,GAOL_STREAM_RANGE);
}

stock Gaol_GetDoorModel(cell)
{
	if (cell < 0 || cell >= GAOL_CELLS || !IsValidDynamicObject(s_GaolDoorPlugs[cell]))
	{
		return 0;
	}

	return Streamer_GetIntData(STREAMER_TYPE_OBJECT,s_GaolDoorPlugs[cell],E_STREAMER_MODEL_ID);
}

stock bool:Gaol_HasCellDoor(cell)
{
	return cell >= 0 && cell < GAOL_CELLS && IsValidDynamicObject(s_GaolCellDoors[cell]);
}

stock bool:Gaol_IsCellOpen(cell)
{
	return cell >= 0 && cell < GAOL_CELLS && s_GaolKeeper[cell] != INVALID_PLAYER_ID;
}

stock bool:Gaol_OpenCell(cell,playerid)
{
	if (cell < 0 || cell >= GAOL_CELLS || !Util_IsValidPlayer(playerid) || s_GaolKeeper[cell] != INVALID_PLAYER_ID)
	{
		return false;
	}

	s_GaolKeeper[cell] = playerid;
	Gaol_RefreshDoor(cell);
	return true;
}

stock bool:Gaol_IsDoorwayClear(cell)
{
	new Float:dx, Float:dy, Float:dz;
	Gaol_ToWorld(g_GaolCellDoors[cell][0],g_GaolCellDoors[cell][1],1.0,dx,dy,dz);

	foreach (new i : Player)
	{
		if (GetPlayerVirtualWorld(i) != GAOL_WORLD)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		GetPlayerPos(i,x,y,z);

		if ((floatabs(z - dz) < 2.0 && VectorSize(x - dx,y - dy,0.0) < GAOL_DOORWAY_GAP) || (i != s_GaolPrisoner[cell] && floatabs(z - dz) < 2.0 && Gaol_IsInCellBox(i,cell,0.0)))
		{
			return false;
		}
	}

	return true;
}

stock bool:Gaol_ShutCell(cell)
{
	if (cell < 0 || cell >= GAOL_CELLS || s_GaolKeeper[cell] == INVALID_PLAYER_ID || !Gaol_IsDoorwayClear(cell))
	{
		return false;
	}

	s_GaolKeeper[cell] = INVALID_PLAYER_ID;
	Gaol_RefreshDoor(cell);
	return true;
}

stock Gaol_IsAtCellDoor(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != GAOL_WORLD)
	{
		return -1;
	}

	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		new Float:x, Float:y, Float:z;
		Gaol_ToWorld(g_GaolCellDoors[cell][0],g_GaolCellDoors[cell][1],1.0,x,y,z);

		if (IsPlayerInRangeOfPoint(playerid,GAOL_DOOR_REACH,x,y,z))
		{
			return cell;
		}
	}

	return -1;
}

static Gaol_KeeperTick()
{
	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		new keeper = s_GaolKeeper[cell];

		if (keeper == INVALID_PLAYER_ID)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Gaol_ToWorld(g_GaolCellDoors[cell][0],g_GaolCellDoors[cell][1],1.0,x,y,z);

		if ((!IsPlayerConnected(keeper) || !Law_IsGuard(keeper) || GetPlayerVirtualWorld(keeper) != GAOL_WORLD || !IsPlayerInRangeOfPoint(keeper,GAOL_KEEPER_RANGE,x,y,z)) && Gaol_ShutCell(cell) && IsPlayerConnected(keeper))
		{
			Gui_Notify(keeper,"You leave the cell, and the door is locked behind you.");
		}
	}
}

static Gaol_AddHoldPiece(&count,model,Float:localX,Float:localY,Float:localZ,Float:rz)
{
	if (count >= GAOL_HOLD_PIECES)
	{
		return;
	}

	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(localX,localY + GAOL_HOLD_Y,localZ,x,y,z);
	s_GaolHoldPieces[count++] = CreateDynamicObject(model,x,y,z,0.0,0.0,rz,-1,GAOL_INTERIOR,-1,GAOL_STREAM_RANGE,GAOL_STREAM_RANGE);
	Util_WatchInteriorShell(s_GaolHoldPieces[count - 1]);
	Light_FollowModel(LIGHT_FOLLOW_GAOL,GAOL_LIGHTS_HOLD,model,x,y,z,rz,-1,GAOL_INTERIOR);
}

static Gaol_BuildHold()
{
	for (new i = 0;i < GAOL_HOLD_PIECES;i++)
	{
		if (IsValidDynamicObject(s_GaolHoldPieces[i]))
		{
			Util_WatchInteriorShell(s_GaolHoldPieces[i],false);
			DestroyDynamicObject(s_GaolHoldPieces[i]);
		}
	}

	Light_Unfollow(LIGHT_FOLLOW_GAOL,GAOL_LIGHTS_HOLD);
	new count = 0;
	Gaol_AddHoldPiece(count,MODEL_CRYPT_ENTRANCE,0.0,0.0,0.0,0.0);
	Gaol_AddHoldPiece(count,MODEL_CRYPT_CORRIDOR,0.0,-6.0,0.0,0.0);
	Gaol_AddHoldPiece(count,MODEL_CRYPT_CHAMBER_S,0.0,-14.0,0.0,0.0);

	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		new Float:rz = g_GaolCellDoors[cell][2];
		Gaol_AddHoldPiece(count,MODEL_CRYPT_CORRIDOR,g_GaolCellCentres[cell][0],g_GaolCellCentres[cell][1],0.0,g_GaolCellCentres[cell][2]);
		Gaol_AddHoldPiece(count,MODEL_GAOL_WALL_WINDOW,g_GaolCellCaps[cell][0],g_GaolCellCaps[cell][1],0.0,g_GaolCellCaps[cell][2]);
		Gaol_AddHoldPiece(count,MODEL_VILLAGE_CELL_BARS,g_GaolCellGrates[cell][0],g_GaolCellGrates[cell][1],1.3,g_GaolCellGrates[cell][2]);
		Gaol_AddHoldPiece(count,MODEL_VILLAGE_CELL_DOOR,g_GaolCellDoors[cell][0] + GAOL_DOOR_SET_IN * floatsin(rz,degrees),g_GaolCellDoors[cell][1] - GAOL_DOOR_SET_IN * floatcos(rz,degrees),0.0,rz);
		Gaol_AddHoldPiece(count,GAOL_PLUG_LOCKED,g_GaolCellDoors[cell][0],g_GaolCellDoors[cell][1],0.0,rz);
	}
}

stock Gaol_Build()
{
	for (new i = 0;i < s_GaolPieceCount;i++)
	{
		if (IsValidDynamicObject(s_GaolPieces[i]))
		{
			DestroyDynamicObject(s_GaolPieces[i]);
		}
	}

	s_GaolPieceCount = 0;
	Light_Unfollow(LIGHT_FOLLOW_GAOL,GAOL_LIGHTS_CELLS);

	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		s_GaolKeeper[cell] = INVALID_PLAYER_ID;
	}

	Gaol_AddPiece(MODEL_CRYPT_ENTRANCE,0.0,0.0,0.0,0.0);
	Gaol_AddPiece(MODEL_CRYPT_CORRIDOR,0.0,-6.0,0.0,0.0);
	Gaol_AddPiece(MODEL_CRYPT_CHAMBER_S,0.0,-14.0,0.0,0.0);

	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		Gaol_AddPiece(MODEL_CRYPT_CORRIDOR,g_GaolCellCentres[cell][0],g_GaolCellCentres[cell][1],0.0,g_GaolCellCentres[cell][2]);
		Gaol_AddPiece(MODEL_GAOL_WALL_WINDOW,g_GaolCellCaps[cell][0],g_GaolCellCaps[cell][1],0.0,g_GaolCellCaps[cell][2]);
		Gaol_RefreshDoor(cell);
		Gaol_RefreshGrate(cell);
	}

	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(0.0,-14.0,0.0,x,y,z);
	Nearby_StreamObjectsAt(x,y,z,GAOL_WORLD,GAOL_INTERIOR,GAOL_STREAM_RANGE);
	Gaol_BuildHold();
}

stock bool:Gaol_IsLocked(playerid)
{
	return Util_IsValidPlayer(playerid) && s_GaolCellOf[playerid] != -1;
}

stock Gaol_GetCell(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_GaolCellOf[playerid] : -1;
}

stock Gaol_GetProgress(cell)
{
	return cell >= 0 && cell < GAOL_CELLS ? s_GaolProgress[cell] : 0;
}

stock Gaol_CountFree()
{
	new count = 0;

	for (new i = 0;i < GAOL_CELLS;i++)
	{
		if (s_GaolPrisoner[i] == INVALID_PLAYER_ID)
		{
			count++;
		}
	}

	return count;
}

static Gaol_SaveCell(cell)
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO law_cells (cell, progress) VALUES (%d, %d) ON DUPLICATE KEY UPDATE progress = VALUES(progress)",cell,s_GaolProgress[cell]));
}

stock Gaol_SetProgress(cell,progress)
{
	if (cell < 0 || cell >= GAOL_CELLS)
	{
		return;
	}

	new bool:wasLoose = s_GaolProgress[cell] >= GAOL_LOOSE_PERCENT;
	s_GaolProgress[cell] = Util_ClampInt(progress,0,100);
	Gaol_SaveCell(cell);

	if (wasLoose != (s_GaolProgress[cell] >= GAOL_LOOSE_PERCENT))
	{
		Gaol_RefreshGrate(cell);
	}
}

static Gaol_PlaceInCell(playerid,cell)
{
	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(g_GaolCellCentres[cell][0],g_GaolCellCentres[cell][1],1.0,x,y,z);
	Util_SafeTeleport(playerid,x,y,z,Util_NormalizeAngle(g_GaolCellCentres[cell][2] + 180.0),GAOL_WORLD,GAOL_INTERIOR);
}

stock bool:Gaol_Lock(playerid)
{
	new cell = -1;

	for (new i = 0;i < GAOL_CELLS && cell == -1;i++)
	{
		if (s_GaolPrisoner[i] == INVALID_PLAYER_ID && s_GaolProgress[i] < 100)
		{
			cell = i;
		}
	}

	for (new i = 0;i < GAOL_CELLS && cell == -1;i++)
	{
		if (s_GaolPrisoner[i] == INVALID_PLAYER_ID)
		{
			cell = i;
		}
	}

	if (cell == -1)
	{
		return false;
	}

	s_GaolPrisoner[cell] = playerid;
	s_GaolCellOf[playerid] = cell;
	s_GaolWorking[playerid] = false;
	Gaol_PlaceInCell(playerid,cell);
	return true;
}

stock Gaol_Unlock(playerid)
{
	new cell = Gaol_GetCell(playerid);

	if (cell == -1)
	{
		return;
	}

	s_GaolPrisoner[cell] = INVALID_PLAYER_ID;
	s_GaolCellOf[playerid] = -1;
	s_GaolWorking[playerid] = false;
	s_GaolWorkToken[playerid]++;

	if (IsPlayerConnected(playerid) && GetPlayerVirtualWorld(playerid) == GAOL_WORLD)
	{
		Gaol_Leave(playerid);
	}
}

static bool:Gaol_IsInCell(playerid,cell)
{
	return GetPlayerVirtualWorld(playerid) == GAOL_WORLD && Gaol_IsInCellBox(playerid,cell,0.0);
}

stock bool:Gaol_IsHeld(playerid)
{
	return Util_IsValidPlayer(playerid) && s_GaolHeld[playerid];
}

stock bool:Gaol_IsInHold(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);
	return GetPlayerInterior(playerid) == GAOL_INTERIOR && floatabs(z - GAOL_SKY_Z - 1.0) < 3.0 && Gaol_IsInCellBox(playerid,0,GAOL_HOLD_Y);
}

stock Gaol_HoldInWorld(playerid,world)
{
	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(g_GaolCellCentres[0][0],g_GaolCellCentres[0][1] + GAOL_HOLD_Y,1.0,x,y,z);
	s_GaolHeld[playerid] = true;
	s_GaolWorking[playerid] = false;
	s_GaolWorkToken[playerid]++;
	Util_SafeTeleport(playerid,x,y,z,Util_NormalizeAngle(g_GaolCellCentres[0][2] + 180.0),world,GAOL_INTERIOR);
}

stock Gaol_ReleaseHold(playerid)
{
	if (Util_IsValidPlayer(playerid))
	{
		s_GaolHeld[playerid] = false;
	}
}

stock Gaol_HoldTick()
{
	Gaol_KeeperTick();

	for (new cell = 0;cell < GAOL_CELLS;cell++)
	{
		new prisoner = s_GaolPrisoner[cell];

		if (prisoner == INVALID_PLAYER_ID || !IsPlayerConnected(prisoner) || !Session_IsPlaying(prisoner) || s_GaolHeld[prisoner])
		{
			continue;
		}

		if (!Gaol_IsInCell(prisoner,cell))
		{
			Gaol_PlaceInCell(prisoner,cell);
			Gui_Notify(prisoner,s_GaolKeeper[cell] != INVALID_PLAYER_ID ? ("The guard at the door blocks your way and shoves you back into your cell.") : ("The cell door holds. You're back in your cell."));
		}
	}
}

stock bool:Gaol_IsAtDoor(playerid)
{
	return GetPlayerVirtualWorld(playerid) == 0 && IsPlayerInRangeOfPoint(playerid,GAOL_DOOR_REACH,g_LawSeedDoor[0],g_LawSeedDoor[1],g_LawSeedDoor[2] + 1.0);
}

stock bool:Gaol_IsAtExit(playerid)
{
	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(0.0,3.4,3.0,x,y,z);
	return GetPlayerVirtualWorld(playerid) == GAOL_WORLD && IsPlayerInRangeOfPoint(playerid,GAOL_DOOR_REACH + 1.0,x,y,z + 1.0);
}

stock Gaol_IsAtGrate(playerid)
{
	new cell = Gaol_GetCell(playerid);

	if (GetPlayerVirtualWorld(playerid) != GAOL_WORLD)
	{
		return -1;
	}

	for (new i = 0;i < GAOL_CELLS;i++)
	{
		if (cell != -1 && cell != i)
		{
			continue;
		}

		new Float:x, Float:y, Float:z;
		Gaol_ToWorld(g_GaolCellGrates[i][0],g_GaolCellGrates[i][1],1.0,x,y,z);

		if (IsPlayerInRangeOfPoint(playerid,GAOL_GRATE_REACH,x,y,z))
		{
			return i;
		}
	}

	return -1;
}

stock Gaol_Enter(playerid)
{
	new Float:x, Float:y, Float:z;
	Gaol_ToWorld(0.0,3.0,3.0,x,y,z);
	Util_SafeTeleport(playerid,x,y,z + 1.0,180.0,GAOL_WORLD,GAOL_INTERIOR);
	Gui_Notify(playerid,"You go down the steps into the gaol.");
}

stock Gaol_Leave(playerid)
{
	new Float:a = g_LawSeedDoor[3];
	Util_SafeTeleport(playerid,g_LawSeedDoor[0] - 1.2 * floatsin(a,degrees),g_LawSeedDoor[1] + 1.2 * floatcos(a,degrees),g_LawSeedDoor[2] + 1.0,a,0,0);
}

stock bool:Gaol_StartWork(playerid)
{
	new cell = Gaol_GetCell(playerid);

	if (cell == -1 || s_GaolWorking[playerid] || Gaol_IsAtGrate(playerid) != cell)
	{
		return false;
	}

	s_GaolWorking[playerid] = true;
	TogglePlayerControllable(playerid,false);
	ApplyAnimation(playerid,"BOMBER","BOM_Plant_Loop",4.1,true,false,false,true,0,SYNC_ALL);
	Gui_Notify(playerid,"You work at the grate with your fingers and a loose stone. Keep it quiet.");
	SetTimerEx("Gaol_WorkDone",GAOL_WORK_MS,false,"dd",playerid,++s_GaolWorkToken[playerid]);
	return true;
}

static bool:Gaol_IsGuardNear(playerid)
{
	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid,x,y,z);

	foreach (new i : Player)
	{
		if (i != playerid && Law_IsGuard(i) && GetPlayerVirtualWorld(i) == GAOL_WORLD && GetPlayerDistanceFromPoint(i,x,y,z) <= GAOL_NOISE_RANGE)
		{
			return true;
		}
	}

	return false;
}

stock Gaol_Escape(playerid)
{
	new description[LAW_DESCRIPTION_LEN];
	Law_Describe(playerid,description);
	Law_Release(playerid,"escaped");
	Util_SafeTeleport(playerid,g_LawSeedEscape[0],g_LawSeedEscape[1],g_LawSeedEscape[2] + 1.0,g_LawSeedEscape[3],0,0);
	Law_SetWanted(playerid,LAW_CRIME_ESCAPE,description);
	Gui_Notify(playerid,"The grate gives way. You squeeze through and drop into the dark behind the guardhouse. You're free, and wanted.");
	pawn_call_public("Gaol_OnEscape","d",playerid);
}

forward Gaol_WorkDone(playerid,token);

public Gaol_WorkDone(playerid,token)
{
	if (!IsPlayerConnected(playerid) || token != s_GaolWorkToken[playerid] || !s_GaolWorking[playerid])
	{
		return 1;
	}

	new cell = Gaol_GetCell(playerid);
	s_GaolWorking[playerid] = false;
	TogglePlayerControllable(playerid,true);
	ClearAnimations(playerid,SYNC_ALL);

	if (cell == -1)
	{
		return 1;
	}

	if (Gaol_IsGuardNear(playerid))
	{
		Gaol_SetProgress(cell,s_GaolProgress[cell] - GAOL_CAUGHT_LOSS);
		Law_AddServingMinutes(playerid,GAOL_CAUGHT_MINUTES);

		foreach (new i : Player)
		{
			if (Law_IsGuard(i) && GetPlayerVirtualWorld(i) == GAOL_WORLD)
			{
				Gui_Notify(i,"You hear scraping at a cell grate and put a stop to it.");
			}
		}

		Gui_Notify(playerid,"A guard heard you. The grate is wedged tight again and your time grows by a quarter hour.");
		return 1;
	}

	Gaol_SetProgress(cell,s_GaolProgress[cell] + 8 + random(9) + Character_GetAttribute(playerid,_:ATTR_WILLPOWER) / 2);

	if (s_GaolProgress[cell] >= 100)
	{
		Gaol_Escape(playerid);
		return 1;
	}

	new text[96];
	format(text,sizeof(text),"The grate gives a little. It's %d%% loose.",s_GaolProgress[cell]);
	Gui_Notify(playerid,text);
	return 1;
}

forward Gaol_OnEscape(playerid);

public Gaol_OnEscape(playerid)
{
	return 1;
}

forward Gaol_LoadOnBoot();

public Gaol_LoadOnBoot()
{
	yield 1;

	await mysql_aquery_s(g_Mysql,str_new("SELECT cell, progress FROM law_cells"));

	for (new r = 0, rows = cache_num_rows();r < rows;r++)
	{
		new cell, progress;
		cache_get_value_name_int(r,"cell",cell);
		cache_get_value_name_int(r,"progress",progress);

		if (cell >= 0 && cell < GAOL_CELLS)
		{
			s_GaolProgress[cell] = Util_ClampInt(progress,0,100);
		}
	}

	Gaol_Build();
	Log_Info("law","the gaol is built with %d cells",GAOL_CELLS);
	Boot_LoaderDone();
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_GaolCellOf[playerid] = -1;
	s_GaolWorking[playerid] = false;
	s_GaolHeld[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
	#pragma unused reason

	new cell = s_GaolCellOf[playerid];

	if (cell != -1)
	{
		s_GaolPrisoner[cell] = INVALID_PLAYER_ID;
		s_GaolCellOf[playerid] = -1;
	}

	s_GaolWorkToken[playerid]++;
}
