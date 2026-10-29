#define PLACEMENT_SUPPORT_ABOVE (0.3)
#define PLACEMENT_SUPPORT_REACH (1.5)
#define PLACEMENT_SUPPORT_TOLERANCE (0.15)
#define PLACEMENT_REST_LIFT (0.08)
#define PLACEMENT_TILT_DEFAULT (10.0)
#define PLACEMENT_SNAP_ABOVE (0.5)
#define PLACEMENT_SNAP_REACH (10.0)
#define PLACEMENT_SNAP_INSET (0.8)

enum E_PLACEMENT_RESULT
{
	PLACEMENT_OK = 0,
	PLACEMENT_FLOATING,
	PLACEMENT_SINKING,
	PLACEMENT_THROUGH_WALL,
	PLACEMENT_TILTED,
	PLACEMENT_CANCELLED,
}

enum (<<= 1)
{
	PLACEMENT_CHECK_SUPPORT = 1,
	PLACEMENT_CHECK_CONTACT,
	PLACEMENT_CHECK_TILT,
}

static const s_PlacementReasons[E_PLACEMENT_RESULT][24] = {
	"",
	"floating",
	"sunk into the ground",
	"going through a wall",
	"tipped over",
	"cancelled"
};

static Task:s_PlacementTask[MAX_PLAYERS];
static STREAMER_TAG_OBJECT:s_PlacementObject[MAX_PLAYERS] = {STREAMER_TAG_OBJECT:INVALID_STREAMER_ID, ...};
static Float:s_PlacementPose[MAX_PLAYERS][6];

stock Placement_GetReason(E_PLACEMENT_RESULT:result,dest[],size = sizeof(dest))
{
	strcopy(dest,s_PlacementReasons[result],size);
}

stock bool:Placement_FindSurface(Float:x,Float:y,Float:fromZ,Float:reach,&Float:surfaceZ)
{
	new Float:hitX[MAX_MULTICAST_SIZE], Float:hitY[MAX_MULTICAST_SIZE], Float:hitZ[MAX_MULTICAST_SIZE], Float:hitDist[MAX_MULTICAST_SIZE], hitModel[MAX_MULTICAST_SIZE];
	new hits = CA_RayCastMultiLine(x,y,fromZ,x,y,fromZ - reach,hitX,hitY,hitZ,hitDist,hitModel);
	new bool:isFound = false;

	for (new i = 0;i < hits;i++)
	{
		if (hitModel[i] == WATER_OBJECT)
		{
			continue;
		}

		if (!isFound || hitZ[i] > surfaceZ)
		{
			surfaceZ = hitZ[i];
			isFound = true;
		}
	}

	return isFound;
}

stock bool:Placement_GetHeightRange(modelid,&Float:bottom,&Float:top)
{
	new Float:minX, Float:minY, Float:maxX, Float:maxY;

	if (!CA_GetModelBoundingBox(modelid,minX,minY,bottom,maxX,maxY,top))
	{
		bottom = 0.0;
		top = PLACEMENT_SUPPORT_ABOVE;
		return false;
	}

	return true;
}

stock Float:Placement_GetBaseOffset(modelid)
{
	new Float:bottom, Float:top;
	Placement_GetHeightRange(modelid,bottom,top);
	return bottom;
}

stock bool:Placement_SnapBox(Float:x,Float:y,&Float:z,Float:rz,Float:minX,Float:minY,Float:maxX,Float:maxY,Float:bottom,Float:top)
{
	new Float:samples[5][2], Float:highest, bool:isFound = false, Float:start = z + top + PLACEMENT_SNAP_ABOVE;
	samples[0][0] = (minX + maxX) / 2.0;
	samples[0][1] = (minY + maxY) / 2.0;
	samples[1][0] = minX * PLACEMENT_SNAP_INSET;
	samples[1][1] = minY * PLACEMENT_SNAP_INSET;
	samples[2][0] = maxX * PLACEMENT_SNAP_INSET;
	samples[2][1] = minY * PLACEMENT_SNAP_INSET;
	samples[3][0] = minX * PLACEMENT_SNAP_INSET;
	samples[3][1] = maxY * PLACEMENT_SNAP_INSET;
	samples[4][0] = maxX * PLACEMENT_SNAP_INSET;
	samples[4][1] = maxY * PLACEMENT_SNAP_INSET;

	for (new i = 0;i < sizeof(samples);i++)
	{
		new Float:sx = x + samples[i][0] * floatcos(rz,degrees) - samples[i][1] * floatsin(rz,degrees);
		new Float:sy = y + samples[i][0] * floatsin(rz,degrees) + samples[i][1] * floatcos(rz,degrees);
		new Float:surfaceZ;

		if (Placement_FindSurface(sx,sy,start,start - (z + bottom) + PLACEMENT_SNAP_REACH,surfaceZ) && (!isFound || surfaceZ > highest))
		{
			highest = surfaceZ;
			isFound = true;
		}
	}

	if (!isFound)
	{
		return false;
	}

	z = highest - bottom;
	return true;
}

stock bool:Placement_SnapToSurface(modelid,Float:x,Float:y,&Float:z,Float:rz)
{
	new Float:minX, Float:minY, Float:bottom, Float:maxX, Float:maxY, Float:top;

	if (!CA_GetModelBoundingBox(modelid,minX,minY,bottom,maxX,maxY,top))
	{
		minX = -0.2;
		minY = -0.2;
		maxX = 0.2;
		maxY = 0.2;
		bottom = 0.0;
		top = PLACEMENT_SUPPORT_ABOVE;
	}

	return Placement_SnapBox(x,y,z,rz,minX,minY,maxX,maxY,bottom,top);
}

static Float:Placement_NormalizeTilt(Float:angle)
{
	new Float:tilt = Util_NormalizeAngle(angle);
	return tilt > 180.0 ? tilt - 360.0 : tilt;
}

stock E_PLACEMENT_RESULT:Placement_Check(modelid,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz,checks = PLACEMENT_CHECK_SUPPORT | PLACEMENT_CHECK_CONTACT | PLACEMENT_CHECK_TILT,Float:maxTilt = PLACEMENT_TILT_DEFAULT)
{
	if ((checks & PLACEMENT_CHECK_TILT) && (floatabs(Placement_NormalizeTilt(rx)) > maxTilt || floatabs(Placement_NormalizeTilt(ry)) > maxTilt))
	{
		return PLACEMENT_TILTED;
	}

	if (checks & PLACEMENT_CHECK_SUPPORT)
	{
		new Float:bottom, Float:top, Float:surfaceZ;
		Placement_GetHeightRange(modelid,bottom,top);

		new Float:base = z + bottom, Float:start = z + (top > bottom + PLACEMENT_SUPPORT_ABOVE ? top : bottom + PLACEMENT_SUPPORT_ABOVE);

		if (!Placement_FindSurface(x,y,start,start - base + PLACEMENT_SUPPORT_REACH,surfaceZ) || surfaceZ < base - PLACEMENT_SUPPORT_TOLERANCE)
		{
			return PLACEMENT_FLOATING;
		}

		if (surfaceZ > base + PLACEMENT_SUPPORT_TOLERANCE)
		{
			return PLACEMENT_SINKING;
		}
	}

	if ((checks & PLACEMENT_CHECK_CONTACT) && CA_ContactTest(modelid,x,y,z + PLACEMENT_REST_LIFT,rx,ry,rz))
	{
		return PLACEMENT_THROUGH_WALL;
	}

	return PLACEMENT_OK;
}

stock bool:Placement_IsEditing(playerid)
{
	return Util_IsValidPlayer(playerid) && s_PlacementObject[playerid] != STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

stock Placement_GetPose(playerid,&Float:x,&Float:y,&Float:z,&Float:rx,&Float:ry,&Float:rz)
{
	x = s_PlacementPose[playerid][0];
	y = s_PlacementPose[playerid][1];
	z = s_PlacementPose[playerid][2];
	rx = s_PlacementPose[playerid][3];
	ry = s_PlacementPose[playerid][4];
	rz = s_PlacementPose[playerid][5];
}

stock STREAMER_TAG_OBJECT:Placement_GetEditedObject(playerid)
{
	return Util_IsValidPlayer(playerid) ? s_PlacementObject[playerid] : STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
}

forward Task:Placement_Edit(playerid,STREAMER_TAG_OBJECT:objectid);

stock Task:Placement_Edit(playerid,STREAMER_TAG_OBJECT:objectid)
{
	Placement_Release(playerid,false);
	s_PlacementTask[playerid] = task_new();
	s_PlacementObject[playerid] = objectid;
	GetDynamicObjectPos(objectid,s_PlacementPose[playerid][0],s_PlacementPose[playerid][1],s_PlacementPose[playerid][2]);
	GetDynamicObjectRot(objectid,s_PlacementPose[playerid][3],s_PlacementPose[playerid][4],s_PlacementPose[playerid][5]);
	Streamer_Update(playerid,STREAMER_TYPE_OBJECT);
	EditDynamicObject(playerid,objectid);
	return s_PlacementTask[playerid];
}

static Placement_Release(playerid,bool:isSaved)
{
	if (s_PlacementObject[playerid] == STREAMER_TAG_OBJECT:INVALID_STREAMER_ID)
	{
		return;
	}

	s_PlacementObject[playerid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;

	new Task:task = s_PlacementTask[playerid];
	s_PlacementTask[playerid] = INVALID_TASK;

	if (task_valid(task))
	{
		task_set_result(task,isSaved);
	}
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_PlacementObject[playerid] = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
	s_PlacementTask[playerid] = INVALID_TASK;
}

hook OnPlayerDisconnect(playerid,reason)
{
	Placement_Release(playerid,false);
}

hook OnPlayerEditDynamicObject(playerid,STREAMER_TAG_OBJECT:objectid,response,Float:x,Float:y,Float:z,Float:rx,Float:ry,Float:rz)
{
	if (objectid != s_PlacementObject[playerid])
	{
		return;
	}

	if (response == _:EDIT_RESPONSE_UPDATE)
	{
		return;
	}

	if (response == _:EDIT_RESPONSE_FINAL)
	{
		s_PlacementPose[playerid][0] = x;
		s_PlacementPose[playerid][1] = y;
		s_PlacementPose[playerid][2] = z;
		s_PlacementPose[playerid][3] = rx;
		s_PlacementPose[playerid][4] = ry;
		s_PlacementPose[playerid][5] = rz;
	}

	Placement_Release(playerid,response == _:EDIT_RESPONSE_FINAL);
}
