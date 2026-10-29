#pragma once
#include "DetourNavMesh.h"

#define NAVSET_MAGIC 0x3154534E
#define NAVSET_VERSION 1

#define NAV_AREA_GROUND 63
#define NAV_AREA_WATER 2
#define NAV_FLAG_WALK 0x01
#define NAV_FLAG_SWIM 0x02

struct NavSetHeader {
    int magic;
    int version;
    int numTiles;
    dtNavMeshParams params;
    float bodyRadius, bodyHeight, bodyClimb, bodySlope;
    float cs, ch;
};

struct NavTileHeader {
    dtTileRef tileRef;
    int dataSize;
};
