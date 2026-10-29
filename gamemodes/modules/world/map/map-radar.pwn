#define MAP_RADAR_MIN_X (250.0)
#define MAP_RADAR_MAX_Y (-2450.0)
#define MAP_RADAR_CELL (10.0)
#define MAP_RADAR_COLS (150)
#define MAP_RADAR_ROWS (170)
#define MAP_RADAR_RAY_TOP (400.0)
#define MAP_RADAR_RAY_BOTTOM (-60.0)
#define MAP_RADAR_SEA_LEVEL (0.5)
#define MAP_RADAR_FAR (20000.0)
#define MAP_RADAR_MAX_ZONES (1000)
#define MAP_RADAR_VEGETATION_PASSES (8)
#define MAP_RADAR_STRUCTURE_COVER (25.0)
#define MAP_RADAR_WATER_COVER (15.0)
#define MAP_RADAR_SLIVER_WIDTH (4)
#define MAP_RADAR_RING_MIN_X (-560.0)
#define MAP_RADAR_RING_MIN_Y (-4960.0)
#define MAP_RADAR_RING_MAX_X (2710.0)
#define MAP_RADAR_RING_MAX_Y (-1640.0)
#define MAP_WALL_POINTS (29)

enum
{
	MAP_RADAR_SEA,
	MAP_RADAR_LOW,
	MAP_RADAR_FOOTHILLS,
	MAP_RADAR_HILLS,
	MAP_RADAR_HIGH,
	MAP_RADAR_PEAKS,
	MAP_RADAR_BUILDING,
	MAP_RADAR_FORTIFICATION,
	MAP_RADAR_OUTSIDE,
	MAP_RADAR_RING,
	MAP_RADAR_WATER,
	MAP_RADAR_CLASSES,
}

static const s_MapRadarColours[MAP_RADAR_CLASSES] = {0x7896A8FF, 0x6A8A45FF, 0x86904FFF, 0x9C8C5EFF, 0xAA9678FF, 0xC2BAAAFF, 0x9E4B2CFF, 0x5E5A56FF, 0x000000FF, 0x4A6B35FF, 0x397DA8FF};
static const s_MapRadarAutumnColours[MAP_RADAR_CLASSES] = {0x7896A8FF, 0xAC783FFF, 0xB88548FF, 0xB08A59FF, 0xB49B7AFF, 0xC7BEAAFF, 0x9E4B2CFF, 0x5E5A56FF, 0x8E6438FF, 0x8E6438FF, 0x397DA8FF};
static s_MapRadarAutumnStage;
static s_MapRadarSnowStage;
static bool:s_MapRadarFrozen;
static const Float:s_MapRadarBands[MAP_RADAR_PEAKS] = {0.0, 12.0, 28.0, 50.0, 80.0};

static const Float:s_MapWall[MAP_WALL_POINTS][2] = {
	{560.0, -2770.0},
	{700.0, -2700.0},
	{900.0, -2665.0},
	{1100.0, -2650.0},
	{1300.0, -2640.0},
	{1500.0, -2650.0},
	{1690.0, -2670.0},
	{1710.0, -2850.0},
	{1700.0, -3050.0},
	{1560.0, -3080.0},
	{1445.0, -3110.0},
	{1440.0, -3400.0},
	{1450.0, -3720.0},
	{1300.0, -3810.0},
	{1170.0, -3885.0},
	{1080.0, -3945.0},
	{940.0, -3940.0},
	{800.0, -3905.0},
	{660.0, -3885.0},
	{585.0, -3830.0},
	{555.0, -3720.0},
	{530.0, -3600.0},
	{505.0, -3460.0},
	{440.0, -3335.0},
	{438.0, -3250.0},
	{470.0, -3130.0},
	{560.0, -3065.0},
	{578.0, -2950.0},
	{572.0, -2860.0}
};

#include "modules/world/map/map-radar-water.pwn"

static s_MapRadarZones[MAP_RADAR_MAX_ZONES];
static s_MapRadarZoneClass[MAP_RADAR_MAX_ZONES];
static s_MapRadarZoneCount;
static bool:s_MapRadarShown[MAX_PLAYERS];
static bool:s_MapRadarHidden[MAX_PLAYERS];

stock Map_GetRadarZoneCount()
{
	return s_MapRadarZoneCount;
}

stock Map_GetRadarZone(index)
{
	return index >= 0 && index < s_MapRadarZoneCount ? s_MapRadarZones[index] : -1;
}

stock Map_GetRadarColour(class)
{
    if (class < 0 || class >= MAP_RADAR_CLASSES)
    {
        return 0;
    }

    if (class == MAP_RADAR_WATER)
    {
        return s_MapRadarFrozen ? 0xB9DDE8FF : s_MapRadarColours[class];
    }

    if (class == MAP_RADAR_SEA || class == MAP_RADAR_BUILDING || class == MAP_RADAR_FORTIFICATION)
    {
        return s_MapRadarColours[class];
    }

    new colour = s_MapRadarAutumnStage > 0 ? s_MapRadarAutumnColours[class] : s_MapRadarColours[class == MAP_RADAR_OUTSIDE ? MAP_RADAR_RING : class];
    new stage = s_MapRadarSnowStage;
    new red = (colour >>> 24) & 255, green = (colour >>> 16) & 255, blue = (colour >>> 8) & 255;
    red += (232 - red) * stage / 5;
    green += (237 - green) * stage / 5;
    blue += (239 - blue) * stage / 5;
    return (red << 24) | (green << 16) | (blue << 8) | 255;
}

stock Map_SetRadarSeason(autumnStage, snowStage, bool:frozen)
{
    autumnStage = clamp(autumnStage, 0, 2);
    snowStage = clamp(snowStage, 0, 5);

    if (autumnStage == s_MapRadarAutumnStage && snowStage == s_MapRadarSnowStage && frozen == s_MapRadarFrozen)
    {
        return;
    }

    s_MapRadarAutumnStage = autumnStage;
    s_MapRadarSnowStage = snowStage;
    s_MapRadarFrozen = frozen;

    foreach (new playerid : Player)
    {
        if (s_MapRadarShown[playerid])
        {
            Map_ShowRadar(playerid);
        }
    }
}

stock bool:Map_IsInsideWall(Float:x,Float:y)
{
	new bool:isInside = false;

	for (new i = 0;i < MAP_WALL_POINTS;i++)
	{
		new j = (i == 0) ? MAP_WALL_POINTS - 1 : i - 1;

		if ((s_MapWall[i][1] > y) != (s_MapWall[j][1] > y) && x < (s_MapWall[j][0] - s_MapWall[i][0]) * (y - s_MapWall[i][1]) / (s_MapWall[j][1] - s_MapWall[i][1]) + s_MapWall[i][0])
		{
			isInside = !isInside;
		}
	}

	return isInside;
}

stock Map_GetRadarZoneClassAt(Float:x,Float:y)
{
	for (new i = s_MapRadarZoneCount - 1;i >= 0;i--)
	{
		new Float:minX, Float:minY, Float:maxX, Float:maxY;
		GangZoneGetPos(s_MapRadarZones[i],minX,minY,maxX,maxY);

		if (x >= minX && x < maxX && y >= minY && y < maxY)
		{
			return s_MapRadarZoneClass[i];
		}
	}

	return -1;
}

static Map_RadarClassAt(Float:x,Float:y)
{
	if (!Map_IsInsideWall(x,y))
	{
		return MAP_RADAR_RING;
	}

	new Float:hx, Float:hy, Float:hz, model = CA_RayCastLine(x,y,MAP_RADAR_RAY_TOP,x,y,MAP_RADAR_RAY_BOTTOM,hx,hy,hz);

	for (new pass = 0;pass < MAP_RADAR_VEGETATION_PASSES && Map_IsVegetationModel(model);pass++)
	{
		model = CA_RayCastLine(x,y,hz - 0.05,x,y,MAP_RADAR_RAY_BOTTOM,hx,hy,hz);
	}

	if (model == 0 || model == WATER_OBJECT || hz < MAP_RADAR_SEA_LEVEL)
	{
		return MAP_RADAR_SEA;
	}

	if (model > 0)
	{
		return MAP_RADAR_OUTSIDE;
	}

	for (new band = MAP_RADAR_PEAKS - 1;band > 0;band--)
	{
		if (hz >= s_MapRadarBands[band])
		{
			return MAP_RADAR_LOW + band;
		}
	}

	return MAP_RADAR_LOW;
}

static bool:Map_IsRadarSliver(before,class,after)
{
	if (before != after || before == class)
	{
		return false;
	}

	if (before < MAP_RADAR_LOW || before > MAP_RADAR_PEAKS || class < MAP_RADAR_LOW || class > MAP_RADAR_PEAKS)
	{
		return false;
	}

	return before - class == 1 || class - before == 1;
}

static Map_FoldRadarContours(grid[MAP_RADAR_ROWS][MAP_RADAR_COLS char])
{
	for (new axis = 0;axis < 2;axis++)
	{
		new lines = axis == 0 ? MAP_RADAR_ROWS : MAP_RADAR_COLS, cells = axis == 0 ? MAP_RADAR_COLS : MAP_RADAR_ROWS;

		for (new line = 0;line < lines;line++)
		{
			for (new cell = 1;cell < cells - MAP_RADAR_SLIVER_WIDTH;cell++)
			{
				new before = axis == 0 ? grid[line]{cell - 1} : grid[cell - 1]{line};

				for (new width = 2;width <= MAP_RADAR_SLIVER_WIDTH;width++)
				{
					new after = axis == 0 ? grid[line]{cell + width} : grid[cell + width]{line};

					if (before != after || before < MAP_RADAR_LOW || before > MAP_RADAR_PEAKS)
					{
						continue;
					}

					new bool:isSliver = true;

					for (new offset = 0;offset < width;offset++)
					{
						new class = axis == 0 ? grid[line]{cell + offset} : grid[cell + offset]{line};

						if (class != before && !Map_IsRadarSliver(before,class,after))
						{
							isSliver = false;
							break;
						}
					}

					if (isSliver)
					{
						for (new offset = 0;offset < width;offset++)
						{
							if (axis == 0)
							{
								grid[line]{cell + offset} = before;
							}
							else
							{
								grid[cell + offset]{line} = before;
							}
						}
					}
				}
			}
		}
	}

	for (new row = 0;row < MAP_RADAR_ROWS - 1;row += 2)
	{
		for (new col = 0;col < MAP_RADAR_COLS - 1;col += 2)
		{
			new classes[4], lowest = MAP_RADAR_CLASSES, highest = MAP_RADAR_SEA, chosen, most = 0;
			classes[0] = grid[row]{col};
			classes[1] = grid[row]{col + 1};
			classes[2] = grid[row + 1]{col};
			classes[3] = grid[row + 1]{col + 1};

			for (new i = 0;i < sizeof(classes);i++)
			{
				lowest = min(lowest,classes[i]);
				highest = max(highest,classes[i]);
				new count = 0;

				for (new j = 0;j < sizeof(classes);j++)
				{
					if (classes[j] == classes[i])
					{
						count++;
					}
				}

				if (count > most)
				{
					most = count;
					chosen = classes[i];
				}
			}

			if (lowest >= MAP_RADAR_LOW && highest <= MAP_RADAR_PEAKS && highest - lowest <= 1)
			{
				grid[row]{col} = chosen;
				grid[row]{col + 1} = chosen;
				grid[row + 1]{col} = chosen;
				grid[row + 1]{col + 1} = chosen;
			}
		}
	}
}

static Map_AddRadarZone(Float:minX,Float:minY,Float:maxX,Float:maxY,class)
{
	if (s_MapRadarZoneCount >= MAP_RADAR_MAX_ZONES)
	{
		return false;
	}

	new zone = GangZoneCreate(minX,minY,maxX,maxY);

	if (zone == INVALID_GANG_ZONE)
	{
		return false;
	}

	s_MapRadarZones[s_MapRadarZoneCount] = zone;
	s_MapRadarZoneClass[s_MapRadarZoneCount] = class;
	s_MapRadarZoneCount++;
	return true;
}

static Map_BuildRadar()
{
	new grid[MAP_RADAR_ROWS][MAP_RADAR_COLS char], bool:isUsed[MAP_RADAR_ROWS][MAP_RADAR_COLS char];

	for (new row = 0;row < MAP_RADAR_ROWS;row++)
	{
		for (new col = 0;col < MAP_RADAR_COLS;col++)
		{
			grid[row]{col} = Map_RadarClassAt(MAP_RADAR_MIN_X + (float(col) + 0.5) * MAP_RADAR_CELL,MAP_RADAR_MAX_Y - (float(row) + 0.5) * MAP_RADAR_CELL);
			isUsed[row]{col} = false;
		}
	}

	for (new i = 0;i < sizeof(g_MapRadarWaterRuns);i++)
	{
		new row = g_MapRadarWaterRuns[i][0];

		for (new col = g_MapRadarWaterRuns[i][1];col <= g_MapRadarWaterRuns[i][2];col++)
		{
			if (grid[row]{col} != MAP_RADAR_RING && grid[row]{col} != MAP_RADAR_OUTSIDE)
			{
				grid[row]{col} = MAP_RADAR_WATER;
			}
		}
	}

	for (new row = 0;row < MAP_RADAR_ROWS;row++)
	{
		for (new col = 1;col < MAP_RADAR_COLS - 1;col++)
		{
			if (Map_IsRadarSliver(grid[row]{col - 1},grid[row]{col},grid[row]{col + 1}))
			{
				grid[row]{col} = grid[row]{col - 1};
			}
		}
	}

	for (new col = 0;col < MAP_RADAR_COLS;col++)
	{
		for (new row = 1;row < MAP_RADAR_ROWS - 1;row++)
		{
			if (Map_IsRadarSliver(grid[row - 1]{col},grid[row]{col},grid[row + 1]{col}))
			{
				grid[row]{col} = grid[row - 1]{col};
			}
		}
	}

	Map_FoldRadarContours(grid);

	for (new i = 0;i < MAP_RADAR_STRUCTURE_COUNT;i++)
	{
		new Float:minX, Float:minY, Float:maxX, Float:maxY, bool:isFortified;
		Map_GetRadarStructure(i,minX,minY,maxX,maxY,isFortified);

		new colMin = floatround((minX - MAP_RADAR_MIN_X) / MAP_RADAR_CELL,floatround_floor), colMax = floatround((maxX - MAP_RADAR_MIN_X) / MAP_RADAR_CELL,floatround_floor);
		new rowMin = floatround((MAP_RADAR_MAX_Y - maxY) / MAP_RADAR_CELL,floatround_floor), rowMax = floatround((MAP_RADAR_MAX_Y - minY) / MAP_RADAR_CELL,floatround_floor);
		new centreCol = floatround(((minX + maxX) / 2.0 - MAP_RADAR_MIN_X) / MAP_RADAR_CELL,floatround_floor), centreRow = floatround((MAP_RADAR_MAX_Y - (minY + maxY) / 2.0) / MAP_RADAR_CELL,floatround_floor);

		for (new row = max(0,rowMin);row <= rowMax && row < MAP_RADAR_ROWS;row++)
		{
			for (new col = max(0,colMin);col <= colMax && col < MAP_RADAR_COLS;col++)
			{
				if (grid[row]{col} == MAP_RADAR_SEA || grid[row]{col} == MAP_RADAR_WATER || grid[row]{col} == MAP_RADAR_FORTIFICATION)
				{
					continue;
				}

				new Float:cellX = MAP_RADAR_MIN_X + float(col) * MAP_RADAR_CELL, Float:cellTop = MAP_RADAR_MAX_Y - float(row) * MAP_RADAR_CELL;
				new Float:overlapX = (maxX < cellX + MAP_RADAR_CELL ? maxX : cellX + MAP_RADAR_CELL) - (minX > cellX ? minX : cellX);
				new Float:overlapY = (maxY < cellTop ? maxY : cellTop) - (minY > cellTop - MAP_RADAR_CELL ? minY : cellTop - MAP_RADAR_CELL);

				if ((overlapX > 0.0 && overlapY > 0.0 && overlapX * overlapY >= MAP_RADAR_STRUCTURE_COVER) || (row == centreRow && col == centreCol))
				{
					grid[row]{col} = isFortified ? MAP_RADAR_FORTIFICATION : MAP_RADAR_BUILDING;
				}
			}
		}
	}

	for (new row = 0;row < MAP_RADAR_ROWS;row++)
	{
		for (new col = 0;col < MAP_RADAR_COLS;col++)
		{
			if (isUsed[row]{col})
			{
				continue;
			}

			new class = grid[row]{col}, width = 1, height = 1;

			while (col + width < MAP_RADAR_COLS && grid[row]{col + width} == class && !isUsed[row]{col + width})
			{
				width++;
			}

			for (;row + height < MAP_RADAR_ROWS;height++)
			{
				new bool:isRowSame = true;

				for (new k = 0;k < width;k++)
				{
					if (grid[row + height]{col + k} != class || isUsed[row + height]{col + k})
					{
						isRowSame = false;
						break;
					}
				}

				if (!isRowSame)
				{
					break;
				}
			}

			for (new r = row;r < row + height;r++)
			{
				for (new k = col;k < col + width;k++)
				{
					isUsed[r]{k} = true;
				}
			}

			new Float:minX = MAP_RADAR_MIN_X + float(col) * MAP_RADAR_CELL, Float:maxY = MAP_RADAR_MAX_Y - float(row) * MAP_RADAR_CELL;
			Map_AddRadarZone(minX,maxY - float(height) * MAP_RADAR_CELL,minX + float(width) * MAP_RADAR_CELL,maxY,class);
		}
	}

	new Float:maxX = MAP_RADAR_MIN_X + float(MAP_RADAR_COLS) * MAP_RADAR_CELL, Float:minY = MAP_RADAR_MAX_Y - float(MAP_RADAR_ROWS) * MAP_RADAR_CELL;
	Map_AddRadarZone(MAP_RADAR_RING_MIN_X,MAP_RADAR_RING_MIN_Y,MAP_RADAR_MIN_X,MAP_RADAR_RING_MAX_Y,MAP_RADAR_RING);
	Map_AddRadarZone(maxX,MAP_RADAR_RING_MIN_Y,MAP_RADAR_RING_MAX_X,MAP_RADAR_RING_MAX_Y,MAP_RADAR_RING);
	Map_AddRadarZone(MAP_RADAR_MIN_X,MAP_RADAR_MAX_Y,maxX,MAP_RADAR_RING_MAX_Y,MAP_RADAR_RING);
	Map_AddRadarZone(MAP_RADAR_MIN_X,MAP_RADAR_RING_MIN_Y,maxX,minY,MAP_RADAR_RING);
	Map_AddRadarZone(-MAP_RADAR_FAR,-MAP_RADAR_FAR,MAP_RADAR_RING_MIN_X,MAP_RADAR_FAR,MAP_RADAR_OUTSIDE);
	Map_AddRadarZone(MAP_RADAR_RING_MAX_X,-MAP_RADAR_FAR,MAP_RADAR_FAR,MAP_RADAR_FAR,MAP_RADAR_OUTSIDE);
	Map_AddRadarZone(MAP_RADAR_RING_MIN_X,MAP_RADAR_RING_MAX_Y,MAP_RADAR_RING_MAX_X,MAP_RADAR_FAR,MAP_RADAR_OUTSIDE);
	Map_AddRadarZone(MAP_RADAR_RING_MIN_X,-MAP_RADAR_FAR,MAP_RADAR_RING_MAX_X,MAP_RADAR_RING_MIN_Y,MAP_RADAR_OUTSIDE);
}

stock Map_ShowRadar(playerid)
{
	for (new i = 0;i < s_MapRadarZoneCount;i++)
	{
		GangZoneShowForPlayer(playerid,s_MapRadarZones[i],Map_GetRadarColour(s_MapRadarZoneClass[i]));
	}

	s_MapRadarShown[playerid] = true;
}

stock Map_HideRadar(playerid)
{
	for (new i = 0;i < s_MapRadarZoneCount;i++)
	{
		GangZoneHideForPlayer(playerid,s_MapRadarZones[i]);
	}

	s_MapRadarShown[playerid] = false;
}

stock bool:Map_IsRadarShown(playerid)
{
	return Util_IsValidPlayer(playerid) && s_MapRadarShown[playerid];
}

stock Map_ToggleRadar(playerid)
{
	s_MapRadarHidden[playerid] = s_MapRadarShown[playerid];

	if (s_MapRadarShown[playerid])
	{
		Map_HideRadar(playerid);
		return;
	}

	Map_ShowRadar(playerid);
}

forward Map_BuildRadarOnBoot();

public Map_BuildRadarOnBoot()
{
	new tick = GetTickCount();
	Map_BuildRadar();
	Log_Info("map","radar drawn in %d gangzones in %d ms",s_MapRadarZoneCount,GetTickCount() - tick);
	Boot_LoaderDone();
	return 1;
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
	s_MapRadarShown[playerid] = false;
	s_MapRadarHidden[playerid] = false;
}

hook OnPlayerSpawn(playerid)
{
	if (!s_MapRadarShown[playerid] && !s_MapRadarHidden[playerid] && !IsPlayerNPC(playerid))
	{
		Map_ShowRadar(playerid);
	}
}
