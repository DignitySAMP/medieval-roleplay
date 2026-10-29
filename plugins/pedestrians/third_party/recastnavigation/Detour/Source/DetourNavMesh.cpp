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

#include <float.h>
#include <string.h>
#include <stdio.h>
#include "DetourNavMesh.h"
#include "DetourNode.h"
#include "DetourCommon.h"
#include "DetourMath.h"
#include "DetourAlloc.h"
#include "DetourAssert.h"
#include <new>

inline bool overlapSlabs(const float* amin, const float* amax,
						 const float* bmin, const float* bmax,
						 const float px, const float py)
{
	const float minx = dtMax(amin[0]+px,bmin[0]+px);
	const float maxx = dtMin(amax[0]-px,bmax[0]-px);
	if (minx > maxx)
		return false;
	
	const float ad = (amax[1]-amin[1]) / (amax[0]-amin[0]);
	const float ak = amin[1] - ad*amin[0];
	const float bd = (bmax[1]-bmin[1]) / (bmax[0]-bmin[0]);
	const float bk = bmin[1] - bd*bmin[0];
	const float aminy = ad*minx + ak;
	const float amaxy = ad*maxx + ak;
	const float bminy = bd*minx + bk;
	const float bmaxy = bd*maxx + bk;
	const float dmin = bminy - aminy;
	const float dmax = bmaxy - amaxy;
		
	if (dmin*dmax < 0)
		return true;
		
	const float thr = dtSqr(py*2);
	if (dmin*dmin <= thr || dmax*dmax <= thr)
		return true;
		
	return false;
}

static float getSlabCoord(const float* va, const int side)
{
	if (side == 0 || side == 4)
		return va[0];
	else if (side == 2 || side == 6)
		return va[2];
	return 0;
}

static void calcSlabEndPoints(const float* va, const float* vb, float* bmin, float* bmax, const int side)
{
	if (side == 0 || side == 4)
	{
		if (va[2] < vb[2])
		{
			bmin[0] = va[2];
			bmin[1] = va[1];
			bmax[0] = vb[2];
			bmax[1] = vb[1];
		}
		else
		{
			bmin[0] = vb[2];
			bmin[1] = vb[1];
			bmax[0] = va[2];
			bmax[1] = va[1];
		}
	}
	else if (side == 2 || side == 6)
	{
		if (va[0] < vb[0])
		{
			bmin[0] = va[0];
			bmin[1] = va[1];
			bmax[0] = vb[0];
			bmax[1] = vb[1];
		}
		else
		{
			bmin[0] = vb[0];
			bmin[1] = vb[1];
			bmax[0] = va[0];
			bmax[1] = va[1];
		}
	}
}

inline int computeTileHash(int x, int y, const int mask)
{
	const unsigned int h1 = 0x8da6b343;
	const unsigned int h2 = 0xd8163841;
	unsigned int n = h1 * x + h2 * y;
	return (int)(n & mask);
}

inline unsigned int allocLink(dtMeshTile* tile)
{
	if (tile->linksFreeList == DT_NULL_LINK)
		return DT_NULL_LINK;
	unsigned int link = tile->linksFreeList;
	tile->linksFreeList = tile->links[link].next;
	return link;
}

inline void freeLink(dtMeshTile* tile, unsigned int link)
{
	tile->links[link].next = tile->linksFreeList;
	tile->linksFreeList = link;
}

dtNavMesh* dtAllocNavMesh()
{
	void* mem = dtAlloc(sizeof(dtNavMesh), DT_ALLOC_PERM);
	if (!mem) return 0;
	return new(mem) dtNavMesh;
}

void dtFreeNavMesh(dtNavMesh* navmesh)
{
	if (!navmesh) return;
	navmesh->~dtNavMesh();
	dtFree(navmesh);
}

dtNavMesh::dtNavMesh() :
	m_tileWidth(0),
	m_tileHeight(0),
	m_maxTiles(0),
	m_tileLutSize(0),
	m_tileLutMask(0),
	m_posLookup(0),
	m_nextFree(0),
	m_tiles(0)
{
#ifndef DT_POLYREF64
	m_saltBits = 0;
	m_tileBits = 0;
	m_polyBits = 0;
#endif
	memset(&m_params, 0, sizeof(dtNavMeshParams));
	m_orig[0] = 0;
	m_orig[1] = 0;
	m_orig[2] = 0;
}

dtNavMesh::~dtNavMesh()
{
	for (int i = 0; i < m_maxTiles; ++i)
	{
		if (m_tiles[i].flags & DT_TILE_FREE_DATA)
		{
			dtFree(m_tiles[i].data);
			m_tiles[i].data = 0;
			m_tiles[i].dataSize = 0;
		}
	}
	dtFree(m_posLookup);
	dtFree(m_tiles);
}
		
dtStatus dtNavMesh::init(const dtNavMeshParams* params)
{
	memcpy(&m_params, params, sizeof(dtNavMeshParams));
	dtVcopy(m_orig, params->orig);
	m_tileWidth = params->tileWidth;
	m_tileHeight = params->tileHeight;
	
	m_maxTiles = params->maxTiles;
	m_tileLutSize = dtNextPow2(params->maxTiles/4);
	if (!m_tileLutSize) m_tileLutSize = 1;
	m_tileLutMask = m_tileLutSize-1;
	
	m_tiles = (dtMeshTile*)dtAlloc(sizeof(dtMeshTile)*m_maxTiles, DT_ALLOC_PERM);
	if (!m_tiles)
		return DT_FAILURE | DT_OUT_OF_MEMORY;
	m_posLookup = (dtMeshTile**)dtAlloc(sizeof(dtMeshTile*)*m_tileLutSize, DT_ALLOC_PERM);
	if (!m_posLookup)
		return DT_FAILURE | DT_OUT_OF_MEMORY;
	memset(m_tiles, 0, sizeof(dtMeshTile)*m_maxTiles);
	memset(m_posLookup, 0, sizeof(dtMeshTile*)*m_tileLutSize);
	m_nextFree = 0;
	for (int i = m_maxTiles-1; i >= 0; --i)
	{
		m_tiles[i].salt = 1;
		m_tiles[i].next = m_nextFree;
		m_nextFree = &m_tiles[i];
	}
	
#ifndef DT_POLYREF64
	m_tileBits = dtIlog2(dtNextPow2((unsigned int)params->maxTiles));
	m_polyBits = dtIlog2(dtNextPow2((unsigned int)params->maxPolys));
	m_saltBits = dtMin((unsigned int)31, 32 - m_tileBits - m_polyBits);

	if (m_saltBits < 10)
		return DT_FAILURE | DT_INVALID_PARAM;
#endif
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::init(unsigned char* data, const int dataSize, const int flags)
{
	dtMeshHeader* header = (dtMeshHeader*)data;
	if (header->magic != DT_NAVMESH_MAGIC)
		return DT_FAILURE | DT_WRONG_MAGIC;
	if (header->version != DT_NAVMESH_VERSION)
		return DT_FAILURE | DT_WRONG_VERSION;

	dtNavMeshParams params;
	dtVcopy(params.orig, header->bmin);
	params.tileWidth = header->bmax[0] - header->bmin[0];
	params.tileHeight = header->bmax[2] - header->bmin[2];
	params.maxTiles = 1;
	params.maxPolys = header->polyCount;
	
	dtStatus status = init(&params);
	if (dtStatusFailed(status))
		return status;

	return addTile(data, dataSize, flags, 0, 0);
}

const dtNavMeshParams* dtNavMesh::getParams() const
{
	return &m_params;
}

int dtNavMesh::findConnectingPolys(const float* va, const float* vb,
								   const dtMeshTile* tile, int side,
								   dtPolyRef* con, float* conarea, int maxcon) const
{
	if (!tile) return 0;
	
	float amin[2], amax[2];
	calcSlabEndPoints(va, vb, amin, amax, side);
	const float apos = getSlabCoord(va, side);

	float bmin[2], bmax[2];
	unsigned short m = DT_EXT_LINK | (unsigned short)side;
	int n = 0;
	
	dtPolyRef base = getPolyRefBase(tile);
	
	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		dtPoly* poly = &tile->polys[i];
		const int nv = poly->vertCount;
		for (int j = 0; j < nv; ++j)
		{
			if (poly->neis[j] != m) continue;
			
			const float* vc = &tile->verts[poly->verts[j]*3];
			const float* vd = &tile->verts[poly->verts[(j+1) % nv]*3];
			const float bpos = getSlabCoord(vc, side);
			
			if (dtAbs(apos-bpos) > 0.01f)
				continue;
			
			calcSlabEndPoints(vc,vd, bmin,bmax, side);
			
			if (!overlapSlabs(amin,amax, bmin,bmax, 0.01f, tile->header->walkableClimb)) continue;
			
			if (n < maxcon)
			{
				conarea[n*2+0] = dtMax(amin[0], bmin[0]);
				conarea[n*2+1] = dtMin(amax[0], bmax[0]);
				con[n] = base | (dtPolyRef)i;
				n++;
			}
			break;
		}
	}
	return n;
}

void dtNavMesh::unconnectLinks(dtMeshTile* tile, dtMeshTile* target)
{
	if (!tile || !target) return;

	const unsigned int targetNum = decodePolyIdTile(getTileRef(target));

	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		dtPoly* poly = &tile->polys[i];
		unsigned int j = poly->firstLink;
		unsigned int pj = DT_NULL_LINK;
		while (j != DT_NULL_LINK)
		{
			if (decodePolyIdTile(tile->links[j].ref) == targetNum)
			{
				unsigned int nj = tile->links[j].next;
				if (pj == DT_NULL_LINK)
					poly->firstLink = nj;
				else
					tile->links[pj].next = nj;
				freeLink(tile, j);
				j = nj;
			}
			else
			{
				pj = j;
				j = tile->links[j].next;
			}
		}
	}
}

void dtNavMesh::connectExtLinks(dtMeshTile* tile, dtMeshTile* target, int side)
{
	if (!tile) return;
	
	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		dtPoly* poly = &tile->polys[i];

		const int nv = poly->vertCount;
		for (int j = 0; j < nv; ++j)
		{
			if ((poly->neis[j] & DT_EXT_LINK) == 0)
				continue;
			
			const int dir = (int)(poly->neis[j] & 0xff);
			if (side != -1 && dir != side)
				continue;
			
			const float* va = &tile->verts[poly->verts[j]*3];
			const float* vb = &tile->verts[poly->verts[(j+1) % nv]*3];
			dtPolyRef nei[4];
			float neia[4*2];
			int nnei = findConnectingPolys(va,vb, target, dtOppositeTile(dir), nei,neia,4);
			for (int k = 0; k < nnei; ++k)
			{
				unsigned int idx = allocLink(tile);
				if (idx != DT_NULL_LINK)
				{
					dtLink* link = &tile->links[idx];
					link->ref = nei[k];
					link->edge = (unsigned char)j;
					link->side = (unsigned char)dir;
					
					link->next = poly->firstLink;
					poly->firstLink = idx;

					if (dir == 0 || dir == 4)
					{
						float tmin = (neia[k*2+0]-va[2]) / (vb[2]-va[2]);
						float tmax = (neia[k*2+1]-va[2]) / (vb[2]-va[2]);
						if (tmin > tmax)
							dtSwap(tmin,tmax);
						link->bmin = (unsigned char)roundf(dtClamp(tmin, 0.0f, 1.0f)*255.0f);
						link->bmax = (unsigned char)roundf(dtClamp(tmax, 0.0f, 1.0f)*255.0f);
					}
					else if (dir == 2 || dir == 6)
					{
						float tmin = (neia[k*2+0]-va[0]) / (vb[0]-va[0]);
						float tmax = (neia[k*2+1]-va[0]) / (vb[0]-va[0]);
						if (tmin > tmax)
							dtSwap(tmin,tmax);
						link->bmin = (unsigned char)roundf(dtClamp(tmin, 0.0f, 1.0f)*255.0f);
						link->bmax = (unsigned char)roundf(dtClamp(tmax, 0.0f, 1.0f)*255.0f);
					}
				}
			}
		}
	}
}

void dtNavMesh::connectExtOffMeshLinks(dtMeshTile* tile, dtMeshTile* target, int side)
{
	if (!tile) return;
	
	const unsigned char oppositeSide = (side == -1) ? 0xff : (unsigned char)dtOppositeTile(side);
	
	for (int i = 0; i < target->header->offMeshConCount; ++i)
	{
		dtOffMeshConnection* targetCon = &target->offMeshCons[i];
		if (targetCon->side != oppositeSide)
			continue;

		dtPoly* targetPoly = &target->polys[targetCon->poly];
		if (targetPoly->firstLink == DT_NULL_LINK)
			continue;
		
		const float halfExtents[3] = { targetCon->rad, target->header->walkableClimb, targetCon->rad };
		
		const float* p = &targetCon->pos[3];
		float nearestPt[3];
		dtPolyRef ref = findNearestPolyInTile(tile, p, halfExtents, nearestPt);
		if (!ref)
			continue;
		if (dtSqr(nearestPt[0]-p[0])+dtSqr(nearestPt[2]-p[2]) > dtSqr(targetCon->rad))
			continue;
		float* v = &target->verts[targetPoly->verts[1]*3];
		dtVcopy(v, nearestPt);
				
		unsigned int idx = allocLink(target);
		if (idx != DT_NULL_LINK)
		{
			dtLink* link = &target->links[idx];
			link->ref = ref;
			link->edge = (unsigned char)1;
			link->side = oppositeSide;
			link->bmin = link->bmax = 0;
			link->next = targetPoly->firstLink;
			targetPoly->firstLink = idx;
		}
		
		if (targetCon->flags & DT_OFFMESH_CON_BIDIR)
		{
			unsigned int tidx = allocLink(tile);
			if (tidx != DT_NULL_LINK)
			{
				const unsigned short landPolyIdx = (unsigned short)decodePolyIdPoly(ref);
				dtPoly* landPoly = &tile->polys[landPolyIdx];
				dtLink* link = &tile->links[tidx];
				link->ref = getPolyRefBase(target) | (dtPolyRef)(targetCon->poly);
				link->edge = 0xff;
				link->side = (unsigned char)(side == -1 ? 0xff : side);
				link->bmin = link->bmax = 0;
				link->next = landPoly->firstLink;
				landPoly->firstLink = tidx;
			}
		}
	}

}

void dtNavMesh::connectIntLinks(dtMeshTile* tile)
{
	if (!tile) return;

	dtPolyRef base = getPolyRefBase(tile);

	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		dtPoly* poly = &tile->polys[i];
		poly->firstLink = DT_NULL_LINK;

		if (poly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
			continue;
			
		for (int j = poly->vertCount-1; j >= 0; --j)
		{
			if (poly->neis[j] == 0 || (poly->neis[j] & DT_EXT_LINK)) continue;

			unsigned int idx = allocLink(tile);
			if (idx != DT_NULL_LINK)
			{
				dtLink* link = &tile->links[idx];
				link->ref = base | (dtPolyRef)(poly->neis[j]-1);
				link->edge = (unsigned char)j;
				link->side = 0xff;
				link->bmin = link->bmax = 0;
				link->next = poly->firstLink;
				poly->firstLink = idx;
			}
		}			
	}
}

void dtNavMesh::baseOffMeshLinks(dtMeshTile* tile)
{
	if (!tile) return;
	
	dtPolyRef base = getPolyRefBase(tile);
	
	for (int i = 0; i < tile->header->offMeshConCount; ++i)
	{
		dtOffMeshConnection* con = &tile->offMeshCons[i];
		dtPoly* poly = &tile->polys[con->poly];
	
		const float halfExtents[3] = { con->rad, tile->header->walkableClimb, con->rad };
		
		const float* p = &con->pos[0];
		float nearestPt[3];
		dtPolyRef ref = findNearestPolyInTile(tile, p, halfExtents, nearestPt);
		if (!ref) continue;
		if (dtSqr(nearestPt[0]-p[0])+dtSqr(nearestPt[2]-p[2]) > dtSqr(con->rad))
			continue;
		float* v = &tile->verts[poly->verts[0]*3];
		dtVcopy(v, nearestPt);

		unsigned int idx = allocLink(tile);
		if (idx != DT_NULL_LINK)
		{
			dtLink* link = &tile->links[idx];
			link->ref = ref;
			link->edge = (unsigned char)0;
			link->side = 0xff;
			link->bmin = link->bmax = 0;
			link->next = poly->firstLink;
			poly->firstLink = idx;
		}

		unsigned int tidx = allocLink(tile);
		if (tidx != DT_NULL_LINK)
		{
			const unsigned short landPolyIdx = (unsigned short)decodePolyIdPoly(ref);
			dtPoly* landPoly = &tile->polys[landPolyIdx];
			dtLink* link = &tile->links[tidx];
			link->ref = base | (dtPolyRef)(con->poly);
			link->edge = 0xff;
			link->side = 0xff;
			link->bmin = link->bmax = 0;
			link->next = landPoly->firstLink;
			landPoly->firstLink = tidx;
		}
	}
}

namespace
{
	template<bool onlyBoundary>
	void closestPointOnDetailEdges(const dtMeshTile* tile, const dtPoly* poly, const float* pos, float* closest)
	{
		const unsigned int ip = (unsigned int)(poly - tile->polys);
		const dtPolyDetail* pd = &tile->detailMeshes[ip];

		float dmin = FLT_MAX;
		float tmin = 0;
		const float* pmin = 0;
		const float* pmax = 0;

		for (int i = 0; i < pd->triCount; i++)
		{
			const unsigned char* tris = &tile->detailTris[(pd->triBase + i) * 4];
			const int ANY_BOUNDARY_EDGE =
				(DT_DETAIL_EDGE_BOUNDARY << 0) |
				(DT_DETAIL_EDGE_BOUNDARY << 2) |
				(DT_DETAIL_EDGE_BOUNDARY << 4);
			if (onlyBoundary && (tris[3] & ANY_BOUNDARY_EDGE) == 0)
				continue;

			const float* v[3];
			for (int j = 0; j < 3; ++j)
			{
				if (tris[j] < poly->vertCount)
					v[j] = &tile->verts[poly->verts[tris[j]] * 3];
				else
					v[j] = &tile->detailVerts[(pd->vertBase + (tris[j] - poly->vertCount)) * 3];
			}

			for (int k = 0, j = 2; k < 3; j = k++)
			{
				if ((dtGetDetailTriEdgeFlags(tris[3], j) & DT_DETAIL_EDGE_BOUNDARY) == 0 &&
					(onlyBoundary || tris[j] < tris[k]))
				{
					continue;
				}

				float t;
				float d = dtDistancePtSegSqr2D(pos, v[j], v[k], t);
				if (d < dmin)
				{
					dmin = d;
					tmin = t;
					pmin = v[j];
					pmax = v[k];
				}
			}
		}

		dtVlerp(closest, pmin, pmax, tmin);
	}
}

bool dtNavMesh::getPolyHeight(const dtMeshTile* tile, const dtPoly* poly, const float* pos, float* height) const
{
	if (poly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
		return false;

	const unsigned int ip = (unsigned int)(poly - tile->polys);
	const dtPolyDetail* pd = &tile->detailMeshes[ip];
	
	float verts[DT_VERTS_PER_POLYGON*3];	
	const int nv = poly->vertCount;
	for (int i = 0; i < nv; ++i)
		dtVcopy(&verts[i*3], &tile->verts[poly->verts[i]*3]);
	
	if (!dtPointInPolygon(pos, verts, nv))
		return false;

	if (!height)
		return true;
	
	for (int j = 0; j < pd->triCount; ++j)
	{
		const unsigned char* t = &tile->detailTris[(pd->triBase+j)*4];
		const float* v[3];
		for (int k = 0; k < 3; ++k)
		{
			if (t[k] < poly->vertCount)
				v[k] = &tile->verts[poly->verts[t[k]]*3];
			else
				v[k] = &tile->detailVerts[(pd->vertBase+(t[k]-poly->vertCount))*3];
		}
		float h;
		if (dtClosestHeightPointTriangle(pos, v[0], v[1], v[2], h))
		{
			*height = h;
			return true;
		}
	}

	float closest[3];
	closestPointOnDetailEdges<false>(tile, poly, pos, closest);
	*height = closest[1];
	return true;
}

void dtNavMesh::closestPointOnPoly(dtPolyRef ref, const float* pos, float* closest, bool* posOverPoly) const
{
	const dtMeshTile* tile = 0;
	const dtPoly* poly = 0;
	getTileAndPolyByRefUnsafe(ref, &tile, &poly);

	dtVcopy(closest, pos);
	if (getPolyHeight(tile, poly, pos, &closest[1]))
	{
		if (posOverPoly)
			*posOverPoly = true;
		return;
	}

	if (posOverPoly)
		*posOverPoly = false;

	if (poly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
	{
		const float* v0 = &tile->verts[poly->verts[0]*3];
		const float* v1 = &tile->verts[poly->verts[1]*3];
		float t;
		dtDistancePtSegSqr2D(pos, v0, v1, t);
		dtVlerp(closest, v0, v1, t);
		return;
	}

	closestPointOnDetailEdges<true>(tile, poly, pos, closest);
}

dtPolyRef dtNavMesh::findNearestPolyInTile(const dtMeshTile* tile,
										   const float* center, const float* halfExtents,
										   float* nearestPt) const
{
	float bmin[3], bmax[3];
	dtVsub(bmin, center, halfExtents);
	dtVadd(bmax, center, halfExtents);
	
	dtPolyRef polys[128];
	int polyCount = queryPolygonsInTile(tile, bmin, bmax, polys, 128);
	
	dtPolyRef nearest = 0;
	float nearestDistanceSqr = FLT_MAX;
	for (int i = 0; i < polyCount; ++i)
	{
		dtPolyRef ref = polys[i];
		float closestPtPoly[3];
		float diff[3];
		bool posOverPoly = false;
		float d;
		closestPointOnPoly(ref, center, closestPtPoly, &posOverPoly);

		dtVsub(diff, center, closestPtPoly);
		if (posOverPoly)
		{
			d = dtAbs(diff[1]) - tile->header->walkableClimb;
			d = d > 0 ? d*d : 0;			
		}
		else
		{
			d = dtVlenSqr(diff);
		}
		
		if (d < nearestDistanceSqr)
		{
			dtVcopy(nearestPt, closestPtPoly);
			nearestDistanceSqr = d;
			nearest = ref;
		}
	}
	
	return nearest;
}

int dtNavMesh::queryPolygonsInTile(const dtMeshTile* tile, const float* qmin, const float* qmax,
								   dtPolyRef* polys, const int maxPolys) const
{
	if (tile->bvTree)
	{
		const dtBVNode* node = &tile->bvTree[0];
		const dtBVNode* end = &tile->bvTree[tile->header->bvNodeCount];
		const float* tbmin = tile->header->bmin;
		const float* tbmax = tile->header->bmax;
		const float qfac = tile->header->bvQuantFactor;
		
		unsigned short bmin[3], bmax[3];
		float minx = dtClamp(qmin[0], tbmin[0], tbmax[0]) - tbmin[0];
		float miny = dtClamp(qmin[1], tbmin[1], tbmax[1]) - tbmin[1];
		float minz = dtClamp(qmin[2], tbmin[2], tbmax[2]) - tbmin[2];
		float maxx = dtClamp(qmax[0], tbmin[0], tbmax[0]) - tbmin[0];
		float maxy = dtClamp(qmax[1], tbmin[1], tbmax[1]) - tbmin[1];
		float maxz = dtClamp(qmax[2], tbmin[2], tbmax[2]) - tbmin[2];
		bmin[0] = (unsigned short)(qfac * minx) & 0xfffe;
		bmin[1] = (unsigned short)(qfac * miny) & 0xfffe;
		bmin[2] = (unsigned short)(qfac * minz) & 0xfffe;
		bmax[0] = (unsigned short)(qfac * maxx + 1) | 1;
		bmax[1] = (unsigned short)(qfac * maxy + 1) | 1;
		bmax[2] = (unsigned short)(qfac * maxz + 1) | 1;
		
		dtPolyRef base = getPolyRefBase(tile);
		int n = 0;
		while (node < end)
		{
			const bool overlap = dtOverlapQuantBounds(bmin, bmax, node->bmin, node->bmax);
			const bool isLeafNode = node->i >= 0;
			
			if (isLeafNode && overlap)
			{
				if (n < maxPolys)
					polys[n++] = base | (dtPolyRef)node->i;
			}
			
			if (overlap || isLeafNode)
				node++;
			else
			{
				const int escapeIndex = -node->i;
				node += escapeIndex;
			}
		}
		
		return n;
	}
	else
	{
		float bmin[3], bmax[3];
		int n = 0;
		dtPolyRef base = getPolyRefBase(tile);
		for (int i = 0; i < tile->header->polyCount; ++i)
		{
			dtPoly* p = &tile->polys[i];
			if (p->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
				continue;
			const float* v = &tile->verts[p->verts[0]*3];
			dtVcopy(bmin, v);
			dtVcopy(bmax, v);
			for (int j = 1; j < p->vertCount; ++j)
			{
				v = &tile->verts[p->verts[j]*3];
				dtVmin(bmin, v);
				dtVmax(bmax, v);
			}
			if (dtOverlapBounds(qmin,qmax, bmin,bmax))
			{
				if (n < maxPolys)
					polys[n++] = base | (dtPolyRef)i;
			}
		}
		return n;
	}
}

dtStatus dtNavMesh::addTile(unsigned char* data, int dataSize, int flags,
							dtTileRef lastRef, dtTileRef* result)
{
	dtMeshHeader* header = (dtMeshHeader*)data;
	if (header->magic != DT_NAVMESH_MAGIC)
		return DT_FAILURE | DT_WRONG_MAGIC;
	if (header->version != DT_NAVMESH_VERSION)
		return DT_FAILURE | DT_WRONG_VERSION;

#ifndef DT_POLYREF64
	if (m_polyBits < dtIlog2(dtNextPow2((unsigned int)header->polyCount)))
		return DT_FAILURE | DT_INVALID_PARAM;
#endif
		
	if (getTileAt(header->x, header->y, header->layer))
		return DT_FAILURE | DT_ALREADY_OCCUPIED;
		
	dtMeshTile* tile = 0;
	if (!lastRef)
	{
		if (m_nextFree)
		{
			tile = m_nextFree;
			m_nextFree = tile->next;
			tile->next = 0;
		}
	}
	else
	{
		int tileIndex = (int)decodePolyIdTile((dtPolyRef)lastRef);
		if (tileIndex >= m_maxTiles)
			return DT_FAILURE | DT_OUT_OF_MEMORY;
		dtMeshTile* target = &m_tiles[tileIndex];
		dtMeshTile* prev = 0;
		tile = m_nextFree;
		while (tile && tile != target)
		{
			prev = tile;
			tile = tile->next;
		}
		if (tile != target)
			return DT_FAILURE | DT_OUT_OF_MEMORY;
		if (!prev)
			m_nextFree = tile->next;
		else
			prev->next = tile->next;

		tile->salt = decodePolyIdSalt((dtPolyRef)lastRef);
	}

	if (!tile)
		return DT_FAILURE | DT_OUT_OF_MEMORY;
	
	int h = computeTileHash(header->x, header->y, m_tileLutMask);
	tile->next = m_posLookup[h];
	m_posLookup[h] = tile;
	
	const int headerSize = dtAlign4(sizeof(dtMeshHeader));
	const int vertsSize = dtAlign4(sizeof(float)*3*header->vertCount);
	const int polysSize = dtAlign4(sizeof(dtPoly)*header->polyCount);
	const int linksSize = dtAlign4(sizeof(dtLink)*(header->maxLinkCount));
	const int detailMeshesSize = dtAlign4(sizeof(dtPolyDetail)*header->detailMeshCount);
	const int detailVertsSize = dtAlign4(sizeof(float)*3*header->detailVertCount);
	const int detailTrisSize = dtAlign4(sizeof(unsigned char)*4*header->detailTriCount);
	const int bvtreeSize = dtAlign4(sizeof(dtBVNode)*header->bvNodeCount);
	const int offMeshLinksSize = dtAlign4(sizeof(dtOffMeshConnection)*header->offMeshConCount);
	
	unsigned char* d = data + headerSize;
	tile->verts = dtGetThenAdvanceBufferPointer<float>(d, vertsSize);
	tile->polys = dtGetThenAdvanceBufferPointer<dtPoly>(d, polysSize);
	tile->links = dtGetThenAdvanceBufferPointer<dtLink>(d, linksSize);
	tile->detailMeshes = dtGetThenAdvanceBufferPointer<dtPolyDetail>(d, detailMeshesSize);
	tile->detailVerts = dtGetThenAdvanceBufferPointer<float>(d, detailVertsSize);
	tile->detailTris = dtGetThenAdvanceBufferPointer<unsigned char>(d, detailTrisSize);
	tile->bvTree = dtGetThenAdvanceBufferPointer<dtBVNode>(d, bvtreeSize);
	tile->offMeshCons = dtGetThenAdvanceBufferPointer<dtOffMeshConnection>(d, offMeshLinksSize);

	if (!bvtreeSize)
		tile->bvTree = 0;

	tile->linksFreeList = 0;
	tile->links[header->maxLinkCount-1].next = DT_NULL_LINK;
	for (int i = 0; i < header->maxLinkCount-1; ++i)
		tile->links[i].next = i+1;

	tile->header = header;
	tile->data = data;
	tile->dataSize = dataSize;
	tile->flags = flags;

	connectIntLinks(tile);

	baseOffMeshLinks(tile);
	connectExtOffMeshLinks(tile, tile, -1);

	static const int MAX_NEIS = 32;
	dtMeshTile* neis[MAX_NEIS];
	int nneis;
	
	nneis = getTilesAt(header->x, header->y, neis, MAX_NEIS);
	for (int j = 0; j < nneis; ++j)
	{
		if (neis[j] == tile)
			continue;
	
		connectExtLinks(tile, neis[j], -1);
		connectExtLinks(neis[j], tile, -1);
		connectExtOffMeshLinks(tile, neis[j], -1);
		connectExtOffMeshLinks(neis[j], tile, -1);
	}
	
	for (int i = 0; i < 8; ++i)
	{
		nneis = getNeighbourTilesAt(header->x, header->y, i, neis, MAX_NEIS);
		for (int j = 0; j < nneis; ++j)
		{
			connectExtLinks(tile, neis[j], i);
			connectExtLinks(neis[j], tile, dtOppositeTile(i));
			connectExtOffMeshLinks(tile, neis[j], i);
			connectExtOffMeshLinks(neis[j], tile, dtOppositeTile(i));
		}
	}
	
	if (result)
		*result = getTileRef(tile);
	
	return DT_SUCCESS;
}

const dtMeshTile* dtNavMesh::getTileAt(const int x, const int y, const int layer) const
{
	int h = computeTileHash(x,y,m_tileLutMask);
	dtMeshTile* tile = m_posLookup[h];
	while (tile)
	{
		if (tile->header &&
			tile->header->x == x &&
			tile->header->y == y &&
			tile->header->layer == layer)
		{
			return tile;
		}
		tile = tile->next;
	}
	return 0;
}

int dtNavMesh::getNeighbourTilesAt(const int x, const int y, const int side, dtMeshTile** tiles, const int maxTiles) const
{
	int nx = x, ny = y;
	switch (side)
	{
		case 0: nx++; break;
		case 1: nx++; ny++; break;
		case 2: ny++; break;
		case 3: nx--; ny++; break;
		case 4: nx--; break;
		case 5: nx--; ny--; break;
		case 6: ny--; break;
		case 7: nx++; ny--; break;
	};

	return getTilesAt(nx, ny, tiles, maxTiles);
}

int dtNavMesh::getTilesAt(const int x, const int y, dtMeshTile** tiles, const int maxTiles) const
{
	int n = 0;
	
	int h = computeTileHash(x,y,m_tileLutMask);
	dtMeshTile* tile = m_posLookup[h];
	while (tile)
	{
		if (tile->header &&
			tile->header->x == x &&
			tile->header->y == y)
		{
			if (n < maxTiles)
				tiles[n++] = tile;
		}
		tile = tile->next;
	}
	
	return n;
}

int dtNavMesh::getTilesAt(const int x, const int y, dtMeshTile const** tiles, const int maxTiles) const
{
	int n = 0;
	
	int h = computeTileHash(x,y,m_tileLutMask);
	dtMeshTile* tile = m_posLookup[h];
	while (tile)
	{
		if (tile->header &&
			tile->header->x == x &&
			tile->header->y == y)
		{
			if (n < maxTiles)
				tiles[n++] = tile;
		}
		tile = tile->next;
	}
	
	return n;
}

dtTileRef dtNavMesh::getTileRefAt(const int x, const int y, const int layer) const
{
	int h = computeTileHash(x,y,m_tileLutMask);
	dtMeshTile* tile = m_posLookup[h];
	while (tile)
	{
		if (tile->header &&
			tile->header->x == x &&
			tile->header->y == y &&
			tile->header->layer == layer)
		{
			return getTileRef(tile);
		}
		tile = tile->next;
	}
	return 0;
}

const dtMeshTile* dtNavMesh::getTileByRef(dtTileRef ref) const
{
	if (!ref)
		return 0;
	unsigned int tileIndex = decodePolyIdTile((dtPolyRef)ref);
	unsigned int tileSalt = decodePolyIdSalt((dtPolyRef)ref);
	if ((int)tileIndex >= m_maxTiles)
		return 0;
	const dtMeshTile* tile = &m_tiles[tileIndex];
	if (tile->salt != tileSalt)
		return 0;
	return tile;
}

int dtNavMesh::getMaxTiles() const
{
	return m_maxTiles;
}

dtMeshTile* dtNavMesh::getTile(int i)
{
	return &m_tiles[i];
}

const dtMeshTile* dtNavMesh::getTile(int i) const
{
	return &m_tiles[i];
}

void dtNavMesh::calcTileLoc(const float* pos, int* tx, int* ty) const
{
	*tx = (int)floorf((pos[0]-m_orig[0]) / m_tileWidth);
	*ty = (int)floorf((pos[2]-m_orig[2]) / m_tileHeight);
}

dtStatus dtNavMesh::getTileAndPolyByRef(const dtPolyRef ref, const dtMeshTile** tile, const dtPoly** poly) const
{
	if (!ref) return DT_FAILURE;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	if (ip >= (unsigned int)m_tiles[it].header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	*tile = &m_tiles[it];
	*poly = &m_tiles[it].polys[ip];
	return DT_SUCCESS;
}

void dtNavMesh::getTileAndPolyByRefUnsafe(const dtPolyRef ref, const dtMeshTile** tile, const dtPoly** poly) const
{
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	*tile = &m_tiles[it];
	*poly = &m_tiles[it].polys[ip];
}

bool dtNavMesh::isValidPolyRef(dtPolyRef ref) const
{
	if (!ref) return false;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return false;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return false;
	if (ip >= (unsigned int)m_tiles[it].header->polyCount) return false;
	return true;
}

dtStatus dtNavMesh::removeTile(dtTileRef ref, unsigned char** data, int* dataSize)
{
	if (!ref)
		return DT_FAILURE | DT_INVALID_PARAM;
	unsigned int tileIndex = decodePolyIdTile((dtPolyRef)ref);
	unsigned int tileSalt = decodePolyIdSalt((dtPolyRef)ref);
	if ((int)tileIndex >= m_maxTiles)
		return DT_FAILURE | DT_INVALID_PARAM;
	dtMeshTile* tile = &m_tiles[tileIndex];
	if (tile->salt != tileSalt)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	int h = computeTileHash(tile->header->x,tile->header->y,m_tileLutMask);
	dtMeshTile* prev = 0;
	dtMeshTile* cur = m_posLookup[h];
	while (cur)
	{
		if (cur == tile)
		{
			if (prev)
				prev->next = cur->next;
			else
				m_posLookup[h] = cur->next;
			break;
		}
		prev = cur;
		cur = cur->next;
	}
	
	static const int MAX_NEIS = 32;
	dtMeshTile* neis[MAX_NEIS];
	int nneis;
	
	nneis = getTilesAt(tile->header->x, tile->header->y, neis, MAX_NEIS);
	for (int j = 0; j < nneis; ++j)
	{
		if (neis[j] == tile) continue;
		unconnectLinks(neis[j], tile);
	}
	
	for (int i = 0; i < 8; ++i)
	{
		nneis = getNeighbourTilesAt(tile->header->x, tile->header->y, i, neis, MAX_NEIS);
		for (int j = 0; j < nneis; ++j)
			unconnectLinks(neis[j], tile);
	}
		
	if (tile->flags & DT_TILE_FREE_DATA)
	{
		dtFree(tile->data);
		tile->data = 0;
		tile->dataSize = 0;
		if (data) *data = 0;
		if (dataSize) *dataSize = 0;
	}
	else
	{
		if (data) *data = tile->data;
		if (dataSize) *dataSize = tile->dataSize;
	}

	tile->header = 0;
	tile->flags = 0;
	tile->linksFreeList = 0;
	tile->polys = 0;
	tile->verts = 0;
	tile->links = 0;
	tile->detailMeshes = 0;
	tile->detailVerts = 0;
	tile->detailTris = 0;
	tile->bvTree = 0;
	tile->offMeshCons = 0;

#ifdef DT_POLYREF64
	tile->salt = (tile->salt+1) & ((1<<DT_SALT_BITS)-1);
#else
	tile->salt = (tile->salt+1) & ((1<<m_saltBits)-1);
#endif
	if (tile->salt == 0)
		tile->salt++;

	tile->next = m_nextFree;
	m_nextFree = tile;

	return DT_SUCCESS;
}

dtTileRef dtNavMesh::getTileRef(const dtMeshTile* tile) const
{
	if (!tile) return 0;
	const unsigned int it = (unsigned int)(tile - m_tiles);
	return (dtTileRef)encodePolyId(tile->salt, it, 0);
}

dtPolyRef dtNavMesh::getPolyRefBase(const dtMeshTile* tile) const
{
	if (!tile) return 0;
	const unsigned int it = (unsigned int)(tile - m_tiles);
	return encodePolyId(tile->salt, it, 0);
}

struct dtTileState
{
	int magic;
	int version;
	dtTileRef ref;
};

struct dtPolyState
{
	unsigned short flags;
	unsigned char area;
};

int dtNavMesh::getTileStateSize(const dtMeshTile* tile) const
{
	if (!tile) return 0;
	const int headerSize = dtAlign4(sizeof(dtTileState));
	const int polyStateSize = dtAlign4(sizeof(dtPolyState) * tile->header->polyCount);
	return headerSize + polyStateSize;
}

dtStatus dtNavMesh::storeTileState(const dtMeshTile* tile, unsigned char* data, const int maxDataSize) const
{
	const int sizeReq = getTileStateSize(tile);
	if (maxDataSize < sizeReq)
		return DT_FAILURE | DT_BUFFER_TOO_SMALL;
		
	dtTileState* tileState = dtGetThenAdvanceBufferPointer<dtTileState>(data, dtAlign4(sizeof(dtTileState)));
	dtPolyState* polyStates = dtGetThenAdvanceBufferPointer<dtPolyState>(data, dtAlign4(sizeof(dtPolyState) * tile->header->polyCount));
	
	tileState->magic = DT_NAVMESH_STATE_MAGIC;
	tileState->version = DT_NAVMESH_STATE_VERSION;
	tileState->ref = getTileRef(tile);
	
	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		const dtPoly* p = &tile->polys[i];
		dtPolyState* s = &polyStates[i];
		s->flags = p->flags;
		s->area = p->getArea();
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::restoreTileState(dtMeshTile* tile, const unsigned char* data, const int maxDataSize)
{
	const int sizeReq = getTileStateSize(tile);
	if (maxDataSize < sizeReq)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	const dtTileState* tileState = dtGetThenAdvanceBufferPointer<const dtTileState>(data, dtAlign4(sizeof(dtTileState)));
	const dtPolyState* polyStates = dtGetThenAdvanceBufferPointer<const dtPolyState>(data, dtAlign4(sizeof(dtPolyState) * tile->header->polyCount));
	
	if (tileState->magic != DT_NAVMESH_STATE_MAGIC)
		return DT_FAILURE | DT_WRONG_MAGIC;
	if (tileState->version != DT_NAVMESH_STATE_VERSION)
		return DT_FAILURE | DT_WRONG_VERSION;
	if (tileState->ref != getTileRef(tile))
		return DT_FAILURE | DT_INVALID_PARAM;
	
	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		dtPoly* p = &tile->polys[i];
		const dtPolyState* s = &polyStates[i];
		p->flags = s->flags;
		p->setArea(s->area);
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::getOffMeshConnectionPolyEndPoints(dtPolyRef prevRef, dtPolyRef polyRef, float* startPos, float* endPos) const
{
	unsigned int salt, it, ip;

	if (!polyRef)
		return DT_FAILURE;
	
	decodePolyId(polyRef, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	const dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	const dtPoly* poly = &tile->polys[ip];

	if (poly->getType() != DT_POLYTYPE_OFFMESH_CONNECTION)
		return DT_FAILURE;

	int idx0 = 0, idx1 = 1;
	
	for (unsigned int i = poly->firstLink; i != DT_NULL_LINK; i = tile->links[i].next)
	{
		if (tile->links[i].edge == 0)
		{
			if (tile->links[i].ref != prevRef)
			{
				idx0 = 1;
				idx1 = 0;
			}
			break;
		}
	}
	
	dtVcopy(startPos, &tile->verts[poly->verts[idx0]*3]);
	dtVcopy(endPos, &tile->verts[poly->verts[idx1]*3]);

	return DT_SUCCESS;
}

const dtOffMeshConnection* dtNavMesh::getOffMeshConnectionByRef(dtPolyRef ref) const
{
	unsigned int salt, it, ip;
	
	if (!ref)
		return 0;
	
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return 0;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return 0;
	const dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return 0;
	const dtPoly* poly = &tile->polys[ip];
	
	if (poly->getType() != DT_POLYTYPE_OFFMESH_CONNECTION)
		return 0;

	const unsigned int idx =  ip - tile->header->offMeshBase;
	dtAssert(idx < (unsigned int)tile->header->offMeshConCount);
	return &tile->offMeshCons[idx];
}

dtStatus dtNavMesh::setPolyFlags(dtPolyRef ref, unsigned short flags)
{
	if (!ref) return DT_FAILURE;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	dtPoly* poly = &tile->polys[ip];
	
	poly->flags = flags;
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::getPolyFlags(dtPolyRef ref, unsigned short* resultFlags) const
{
	if (!ref) return DT_FAILURE;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	const dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	const dtPoly* poly = &tile->polys[ip];

	*resultFlags = poly->flags;
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::setPolyArea(dtPolyRef ref, unsigned char area)
{
	if (!ref) return DT_FAILURE;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	dtPoly* poly = &tile->polys[ip];
	
	poly->setArea(area);
	
	return DT_SUCCESS;
}

dtStatus dtNavMesh::getPolyArea(dtPolyRef ref, unsigned char* resultArea) const
{
	if (!ref) return DT_FAILURE;
	unsigned int salt, it, ip;
	decodePolyId(ref, salt, it, ip);
	if (it >= (unsigned int)m_maxTiles) return DT_FAILURE | DT_INVALID_PARAM;
	if (m_tiles[it].salt != salt || m_tiles[it].header == 0) return DT_FAILURE | DT_INVALID_PARAM;
	const dtMeshTile* tile = &m_tiles[it];
	if (ip >= (unsigned int)tile->header->polyCount) return DT_FAILURE | DT_INVALID_PARAM;
	const dtPoly* poly = &tile->polys[ip];
	
	*resultArea = poly->getArea();
	
	return DT_SUCCESS;
}
