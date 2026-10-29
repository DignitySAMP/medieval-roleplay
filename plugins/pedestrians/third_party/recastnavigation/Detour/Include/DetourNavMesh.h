// Copyright (c) 2009-2010 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//

#ifndef DETOURNAVMESH_H
#define DETOURNAVMESH_H

#include "DetourAlloc.h"
#include "DetourStatus.h"

#ifdef DT_POLYREF64
#include <stdint.h>
#endif

#ifdef DT_POLYREF64
static const unsigned int DT_SALT_BITS = 16;
static const unsigned int DT_TILE_BITS = 28;
static const unsigned int DT_POLY_BITS = 20;
typedef uint64_t dtPolyRef;
#else
typedef unsigned int dtPolyRef;
#endif

#ifdef DT_POLYREF64
typedef uint64_t dtTileRef;
#else
typedef unsigned int dtTileRef;
#endif

static const int DT_VERTS_PER_POLYGON = 6;

static const int DT_NAVMESH_MAGIC = 'D'<<24 | 'N'<<16 | 'A'<<8 | 'V';

static const int DT_NAVMESH_VERSION = 7;

static const int DT_NAVMESH_STATE_MAGIC = 'D'<<24 | 'N'<<16 | 'M'<<8 | 'S';

static const int DT_NAVMESH_STATE_VERSION = 1;

static const unsigned short DT_EXT_LINK = 0x8000;

static const unsigned int DT_NULL_LINK = 0xffffffff;

static const unsigned int DT_OFFMESH_CON_BIDIR = 1;

static const int DT_MAX_AREAS = 64;

enum dtTileFlags
{
	DT_TILE_FREE_DATA = 0x01
};

enum dtStraightPathFlags
{
	DT_STRAIGHTPATH_START = 0x01,
	DT_STRAIGHTPATH_END = 0x02,
	DT_STRAIGHTPATH_OFFMESH_CONNECTION = 0x04
};

enum dtStraightPathOptions
{
	DT_STRAIGHTPATH_AREA_CROSSINGS = 0x01,
	DT_STRAIGHTPATH_ALL_CROSSINGS = 0x02
};

enum dtFindPathOptions
{
	DT_FINDPATH_ANY_ANGLE	= 0x02
};

enum dtRaycastOptions
{
	DT_RAYCAST_USE_COSTS = 0x01
};

enum dtDetailTriEdgeFlags
{
	DT_DETAIL_EDGE_BOUNDARY = 0x01
};

static const float DT_RAY_CAST_LIMIT_PROPORTIONS = 50.0f;

enum dtPolyTypes
{
	DT_POLYTYPE_GROUND = 0,
	DT_POLYTYPE_OFFMESH_CONNECTION = 1
};

struct dtPoly
{
	unsigned int firstLink;

	unsigned short verts[DT_VERTS_PER_POLYGON];

	unsigned short neis[DT_VERTS_PER_POLYGON];

	unsigned short flags;

	unsigned char vertCount;

	unsigned char areaAndtype;

	inline void setArea(unsigned char a) { areaAndtype = (areaAndtype & 0xc0) | (a & 0x3f); }

	inline void setType(unsigned char t) { areaAndtype = (areaAndtype & 0x3f) | (t << 6); }

	inline unsigned char getArea() const { return areaAndtype & 0x3f; }

	inline unsigned char getType() const { return areaAndtype >> 6; }
};

struct dtPolyDetail
{
	unsigned int vertBase;
	unsigned int triBase;
	unsigned char vertCount;
	unsigned char triCount;
};

struct dtLink
{
	dtPolyRef ref;
	unsigned int next;
	unsigned char edge;
	unsigned char side;
	unsigned char bmin;
	unsigned char bmax;
};

struct dtBVNode
{
	unsigned short bmin[3];
	unsigned short bmax[3];
	int i;
};

struct dtOffMeshConnection
{
	float pos[6];

	float rad;		

	unsigned short poly;

	unsigned char flags;

	unsigned char side;

	unsigned int userId;
};

struct dtMeshHeader
{
	int magic;
	int version;
	int x;
	int y;
	int layer;
	unsigned int userId;
	int polyCount;
	int vertCount;
	int maxLinkCount;
	int detailMeshCount;
	
	int detailVertCount;
	
	int detailTriCount;
	int bvNodeCount;
	int offMeshConCount;
	int offMeshBase;
	float walkableHeight;
	float walkableRadius;
	float walkableClimb;
	float bmin[3];
	float bmax[3];
	
	float bvQuantFactor;
};

struct dtMeshTile
{
	unsigned int salt;

	unsigned int linksFreeList;
	dtMeshHeader* header;
	dtPoly* polys;
	float* verts;
	dtLink* links;
	dtPolyDetail* detailMeshes;
	
	float* detailVerts;	

	unsigned char* detailTris;	

	dtBVNode* bvTree;

	dtOffMeshConnection* offMeshCons;
		
	unsigned char* data;
	int dataSize;
	int flags;
	dtMeshTile* next;
private:
	dtMeshTile(const dtMeshTile&);
	dtMeshTile& operator=(const dtMeshTile&);
};

inline int dtGetDetailTriEdgeFlags(unsigned char triFlags, int edgeIndex)
{
	return (triFlags >> (edgeIndex * 2)) & 0x3;
}

struct dtNavMeshParams
{
	float orig[3];
	float tileWidth;
	float tileHeight;
	int maxTiles;
	int maxPolys;
};

class dtNavMesh
{
public:
	dtNavMesh();
	~dtNavMesh();

	dtStatus init(const dtNavMeshParams* params);

	dtStatus init(unsigned char* data, const int dataSize, const int flags);
	
	const dtNavMeshParams* getParams() const;

	dtStatus addTile(unsigned char* data, int dataSize, int flags, dtTileRef lastRef, dtTileRef* result);
	
	dtStatus removeTile(dtTileRef ref, unsigned char** data, int* dataSize);

	void calcTileLoc(const float* pos, int* tx, int* ty) const;

	const dtMeshTile* getTileAt(const int x, const int y, const int layer) const;

	int getTilesAt(const int x, const int y,
				   dtMeshTile const** tiles, const int maxTiles) const;
	
	dtTileRef getTileRefAt(int x, int y, int layer) const;

	dtTileRef getTileRef(const dtMeshTile* tile) const;

	const dtMeshTile* getTileByRef(dtTileRef ref) const;
	
	int getMaxTiles() const;
	
	const dtMeshTile* getTile(int i) const;

	dtStatus getTileAndPolyByRef(const dtPolyRef ref, const dtMeshTile** tile, const dtPoly** poly) const;
	
	void getTileAndPolyByRefUnsafe(const dtPolyRef ref, const dtMeshTile** tile, const dtPoly** poly) const;

	bool isValidPolyRef(dtPolyRef ref) const;
	
	dtPolyRef getPolyRefBase(const dtMeshTile* tile) const;
	
	dtStatus getOffMeshConnectionPolyEndPoints(dtPolyRef prevRef, dtPolyRef polyRef, float* startPos, float* endPos) const;

	const dtOffMeshConnection* getOffMeshConnectionByRef(dtPolyRef ref) const;
	
	dtStatus setPolyFlags(dtPolyRef ref, unsigned short flags);

	dtStatus getPolyFlags(dtPolyRef ref, unsigned short* resultFlags) const;

	dtStatus setPolyArea(dtPolyRef ref, unsigned char area);

	dtStatus getPolyArea(dtPolyRef ref, unsigned char* resultArea) const;

	int getTileStateSize(const dtMeshTile* tile) const;
	
	dtStatus storeTileState(const dtMeshTile* tile, unsigned char* data, const int maxDataSize) const;
	
	dtStatus restoreTileState(dtMeshTile* tile, const unsigned char* data, const int maxDataSize);
	
	inline dtPolyRef encodePolyId(unsigned int salt, unsigned int it, unsigned int ip) const
	{
#ifdef DT_POLYREF64
		return ((dtPolyRef)salt << (DT_POLY_BITS+DT_TILE_BITS)) | ((dtPolyRef)it << DT_POLY_BITS) | (dtPolyRef)ip;
#else
		return ((dtPolyRef)salt << (m_polyBits+m_tileBits)) | ((dtPolyRef)it << m_polyBits) | (dtPolyRef)ip;
#endif
	}
	
	inline void decodePolyId(dtPolyRef ref, unsigned int& salt, unsigned int& it, unsigned int& ip) const
	{
#ifdef DT_POLYREF64
		const dtPolyRef saltMask = ((dtPolyRef)1<<DT_SALT_BITS)-1;
		const dtPolyRef tileMask = ((dtPolyRef)1<<DT_TILE_BITS)-1;
		const dtPolyRef polyMask = ((dtPolyRef)1<<DT_POLY_BITS)-1;
		salt = (unsigned int)((ref >> (DT_POLY_BITS+DT_TILE_BITS)) & saltMask);
		it = (unsigned int)((ref >> DT_POLY_BITS) & tileMask);
		ip = (unsigned int)(ref & polyMask);
#else
		const dtPolyRef saltMask = ((dtPolyRef)1<<m_saltBits)-1;
		const dtPolyRef tileMask = ((dtPolyRef)1<<m_tileBits)-1;
		const dtPolyRef polyMask = ((dtPolyRef)1<<m_polyBits)-1;
		salt = (unsigned int)((ref >> (m_polyBits+m_tileBits)) & saltMask);
		it = (unsigned int)((ref >> m_polyBits) & tileMask);
		ip = (unsigned int)(ref & polyMask);
#endif
	}

	inline unsigned int decodePolyIdSalt(dtPolyRef ref) const
	{
#ifdef DT_POLYREF64
		const dtPolyRef saltMask = ((dtPolyRef)1<<DT_SALT_BITS)-1;
		return (unsigned int)((ref >> (DT_POLY_BITS+DT_TILE_BITS)) & saltMask);
#else
		const dtPolyRef saltMask = ((dtPolyRef)1<<m_saltBits)-1;
		return (unsigned int)((ref >> (m_polyBits+m_tileBits)) & saltMask);
#endif
	}
	
	inline unsigned int decodePolyIdTile(dtPolyRef ref) const
	{
#ifdef DT_POLYREF64
		const dtPolyRef tileMask = ((dtPolyRef)1<<DT_TILE_BITS)-1;
		return (unsigned int)((ref >> DT_POLY_BITS) & tileMask);
#else
		const dtPolyRef tileMask = ((dtPolyRef)1<<m_tileBits)-1;
		return (unsigned int)((ref >> m_polyBits) & tileMask);
#endif
	}
	
	inline unsigned int decodePolyIdPoly(dtPolyRef ref) const
	{
#ifdef DT_POLYREF64
		const dtPolyRef polyMask = ((dtPolyRef)1<<DT_POLY_BITS)-1;
		return (unsigned int)(ref & polyMask);
#else
		const dtPolyRef polyMask = ((dtPolyRef)1<<m_polyBits)-1;
		return (unsigned int)(ref & polyMask);
#endif
	}

private:
	dtNavMesh(const dtNavMesh&);
	dtNavMesh& operator=(const dtNavMesh&);

	dtMeshTile* getTile(int i);

	int getTilesAt(const int x, const int y,
				   dtMeshTile** tiles, const int maxTiles) const;

	int getNeighbourTilesAt(const int x, const int y, const int side,
							dtMeshTile** tiles, const int maxTiles) const;
	
	int findConnectingPolys(const float* va, const float* vb,
							const dtMeshTile* tile, int side,
							dtPolyRef* con, float* conarea, int maxcon) const;
	
	void connectIntLinks(dtMeshTile* tile);
	void baseOffMeshLinks(dtMeshTile* tile);

	void connectExtLinks(dtMeshTile* tile, dtMeshTile* target, int side);
	void connectExtOffMeshLinks(dtMeshTile* tile, dtMeshTile* target, int side);
	
	void unconnectLinks(dtMeshTile* tile, dtMeshTile* target);
	
	int queryPolygonsInTile(const dtMeshTile* tile, const float* qmin, const float* qmax,
							dtPolyRef* polys, const int maxPolys) const;
	dtPolyRef findNearestPolyInTile(const dtMeshTile* tile, const float* center,
									const float* halfExtents, float* nearestPt) const;
	bool getPolyHeight(const dtMeshTile* tile, const dtPoly* poly, const float* pos, float* height) const;
	void closestPointOnPoly(dtPolyRef ref, const float* pos, float* closest, bool* posOverPoly) const;
	
	dtNavMeshParams m_params;
	float m_orig[3];
	float m_tileWidth, m_tileHeight;
	int m_maxTiles;
	int m_tileLutSize;
	int m_tileLutMask;

	dtMeshTile** m_posLookup;
	dtMeshTile* m_nextFree;
	dtMeshTile* m_tiles;
		
#ifndef DT_POLYREF64
	unsigned int m_saltBits;
	unsigned int m_tileBits;
	unsigned int m_polyBits;
#endif

	friend class dtNavMeshQuery;
};

dtNavMesh* dtAllocNavMesh();

void dtFreeNavMesh(dtNavMesh* navmesh);

#endif
