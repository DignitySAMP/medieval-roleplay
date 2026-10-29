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
#include "DetourNavMeshQuery.h"
#include "DetourNavMesh.h"
#include "DetourNode.h"
#include "DetourCommon.h"
#include "DetourMath.h"
#include "DetourAlloc.h"
#include "DetourAssert.h"
#include <new>

dtQueryFilter::dtQueryFilter() :
	m_includeFlags(0xffff),
	m_excludeFlags(0)
{
	for (int i = 0; i < DT_MAX_AREAS; ++i)
		m_areaCost[i] = 1.0f;
}

#ifdef DT_VIRTUAL_QUERYFILTER
bool dtQueryFilter::passFilter(const dtPolyRef ,
							   const dtMeshTile* ,
							   const dtPoly* poly) const
{
	return (poly->flags & m_includeFlags) != 0 && (poly->flags & m_excludeFlags) == 0;
}

float dtQueryFilter::getCost(const float* pa, const float* pb,
							 const dtPolyRef , const dtMeshTile* , const dtPoly* ,
							 const dtPolyRef , const dtMeshTile* , const dtPoly* curPoly,
							 const dtPolyRef , const dtMeshTile* , const dtPoly* ) const
{
	return dtVdist(pa, pb) * m_areaCost[curPoly->getArea()];
}
#else
inline bool dtQueryFilter::passFilter(const dtPolyRef ,
									  const dtMeshTile* ,
									  const dtPoly* poly) const
{
	return (poly->flags & m_includeFlags) != 0 && (poly->flags & m_excludeFlags) == 0;
}

inline float dtQueryFilter::getCost(const float* pa, const float* pb,
									const dtPolyRef , const dtMeshTile* , const dtPoly* ,
									const dtPolyRef , const dtMeshTile* , const dtPoly* curPoly,
									const dtPolyRef , const dtMeshTile* , const dtPoly* ) const
{
	return dtVdist(pa, pb) * m_areaCost[curPoly->getArea()];
}
#endif	
	
static const float H_SCALE = 0.999f;

dtNavMeshQuery* dtAllocNavMeshQuery()
{
	void* mem = dtAlloc(sizeof(dtNavMeshQuery), DT_ALLOC_PERM);
	if (!mem) return 0;
	return new(mem) dtNavMeshQuery;
}

void dtFreeNavMeshQuery(dtNavMeshQuery* navmesh)
{
	if (!navmesh) return;
	navmesh->~dtNavMeshQuery();
	dtFree(navmesh);
}

dtPolyQuery::~dtPolyQuery()
{
}

dtNavMeshQuery::dtNavMeshQuery() :
	m_nav(0),
	m_tinyNodePool(0),
	m_nodePool(0),
	m_openList(0)
{
	memset(&m_query, 0, sizeof(dtQueryData));
}

dtNavMeshQuery::~dtNavMeshQuery()
{
	if (m_tinyNodePool)
		m_tinyNodePool->~dtNodePool();
	if (m_nodePool)
		m_nodePool->~dtNodePool();
	if (m_openList)
		m_openList->~dtNodeQueue();
	dtFree(m_tinyNodePool);
	dtFree(m_nodePool);
	dtFree(m_openList);
}

dtStatus dtNavMeshQuery::init(const dtNavMesh* nav, const int maxNodes)
{
	if (maxNodes > DT_NULL_IDX || maxNodes > (1 << DT_NODE_PARENT_BITS) - 1)
		return DT_FAILURE | DT_INVALID_PARAM;

	m_nav = nav;
	
	if (!m_nodePool || m_nodePool->getMaxNodes() < maxNodes)
	{
		if (m_nodePool)
		{
			m_nodePool->~dtNodePool();
			dtFree(m_nodePool);
			m_nodePool = 0;
		}
		m_nodePool = new (dtAlloc(sizeof(dtNodePool), DT_ALLOC_PERM)) dtNodePool(maxNodes, dtNextPow2(maxNodes/4));
		if (!m_nodePool)
			return DT_FAILURE | DT_OUT_OF_MEMORY;
	}
	else
	{
		m_nodePool->clear();
	}
	
	if (!m_tinyNodePool)
	{
		m_tinyNodePool = new (dtAlloc(sizeof(dtNodePool), DT_ALLOC_PERM)) dtNodePool(64, 32);
		if (!m_tinyNodePool)
			return DT_FAILURE | DT_OUT_OF_MEMORY;
	}
	else
	{
		m_tinyNodePool->clear();
	}
	
	if (!m_openList || m_openList->getCapacity() < maxNodes)
	{
		if (m_openList)
		{
			m_openList->~dtNodeQueue();
			dtFree(m_openList);
			m_openList = 0;
		}
		m_openList = new (dtAlloc(sizeof(dtNodeQueue), DT_ALLOC_PERM)) dtNodeQueue(maxNodes);
		if (!m_openList)
			return DT_FAILURE | DT_OUT_OF_MEMORY;
	}
	else
	{
		m_openList->clear();
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::findRandomPoint(const dtQueryFilter* filter, float (*frand)(),
										 dtPolyRef* randomRef, float* randomPt) const
{
	dtAssert(m_nav);

	if (!filter || !frand || !randomRef || !randomPt)
		return DT_FAILURE | DT_INVALID_PARAM;

	const dtMeshTile* tile = 0;
	float tsum = 0.0f;
	for (int i = 0; i < m_nav->getMaxTiles(); i++)
	{
		const dtMeshTile* t = m_nav->getTile(i);
		if (!t || !t->header) continue;
		
		const float area = 1.0f;
		tsum += area;
		const float u = frand();
		if (u*tsum <= area)
			tile = t;
	}
	if (!tile)
		return DT_FAILURE;

	const dtPoly* poly = 0;
	dtPolyRef polyRef = 0;
	const dtPolyRef base = m_nav->getPolyRefBase(tile);

	float areaSum = 0.0f;
	for (int i = 0; i < tile->header->polyCount; ++i)
	{
		const dtPoly* p = &tile->polys[i];
		if (p->getType() != DT_POLYTYPE_GROUND)
			continue;
		const dtPolyRef ref = base | (dtPolyRef)i;
		if (!filter->passFilter(ref, tile, p))
			continue;

		float polyArea = 0.0f;
		for (int j = 2; j < p->vertCount; ++j)
		{
			const float* va = &tile->verts[p->verts[0]*3];
			const float* vb = &tile->verts[p->verts[j-1]*3];
			const float* vc = &tile->verts[p->verts[j]*3];
			polyArea += dtTriArea2D(va,vb,vc);
		}

		areaSum += polyArea;
		const float u = frand();
		if (u*areaSum <= polyArea)
		{
			poly = p;
			polyRef = ref;
		}
	}
	
	if (!poly)
		return DT_FAILURE;

	const float* v = &tile->verts[poly->verts[0]*3];
	float verts[3*DT_VERTS_PER_POLYGON];
	float areas[DT_VERTS_PER_POLYGON];
	dtVcopy(&verts[0*3],v);
	for (int j = 1; j < poly->vertCount; ++j)
	{
		v = &tile->verts[poly->verts[j]*3];
		dtVcopy(&verts[j*3],v);
	}
	
	const float s = frand();
	const float t = frand();
	
	float pt[3];
	dtRandomPointInConvexPoly(verts, poly->vertCount, areas, s, t, pt);
	
	closestPointOnPoly(polyRef, pt, pt, NULL);
	
	dtVcopy(randomPt, pt);
	*randomRef = polyRef;

	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::findRandomPointAroundCircle(dtPolyRef startRef, const float* centerPos, const float maxRadius,
													 const dtQueryFilter* filter, float (*frand)(),
													 dtPolyRef* randomRef, float* randomPt) const
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);
	
	if (!m_nav->isValidPolyRef(startRef) ||
		!centerPos || !dtVisfinite(centerPos) ||
		maxRadius < 0 || !dtMathIsfinite(maxRadius) ||
		!filter || !frand || !randomRef || !randomPt)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	const dtMeshTile* startTile = 0;
	const dtPoly* startPoly = 0;
	m_nav->getTileAndPolyByRefUnsafe(startRef, &startTile, &startPoly);
	if (!filter->passFilter(startRef, startTile, startPoly))
		return DT_FAILURE | DT_INVALID_PARAM;
	
	m_nodePool->clear();
	m_openList->clear();
	
	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, centerPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	dtStatus status = DT_SUCCESS;
	
	const float radiusSqr = dtSqr(maxRadius);
	float areaSum = 0.0f;

	const dtMeshTile* randomTile = 0;
	const dtPoly* randomPoly = 0;
	dtPolyRef randomPolyRef = 0;

	while (!m_openList->empty())
	{
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(bestRef, &bestTile, &bestPoly);

		if (bestPoly->getType() == DT_POLYTYPE_GROUND)
		{
			float polyArea = 0.0f;
			for (int j = 2; j < bestPoly->vertCount; ++j)
			{
				const float* va = &bestTile->verts[bestPoly->verts[0]*3];
				const float* vb = &bestTile->verts[bestPoly->verts[j-1]*3];
				const float* vc = &bestTile->verts[bestPoly->verts[j]*3];
				polyArea += dtTriArea2D(va,vb,vc);
			}
			areaSum += polyArea;
			const float u = frand();
			if (u*areaSum <= polyArea)
			{
				randomTile = bestTile;
				randomPoly = bestPoly;
				randomPolyRef = bestRef;
			}
		}
		
		dtPolyRef parentRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		if (bestNode->pidx)
			parentRef = m_nodePool->getNodeAtIdx(bestNode->pidx)->id;
		if (parentRef)
			m_nav->getTileAndPolyByRefUnsafe(parentRef, &parentTile, &parentPoly);
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			const dtLink* link = &bestTile->links[i];
			dtPolyRef neighbourRef = link->ref;
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);
			
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;
			
			float va[3], vb[3];
			if (!getPortalPoints(bestRef, bestPoly, bestTile, neighbourRef, neighbourPoly, neighbourTile, va, vb))
				continue;
			
			float tseg;
			float distSqr = dtDistancePtSegSqr2D(centerPos, va, vb, tseg);
			if (distSqr > radiusSqr)
				continue;
			
			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef);
			if (!neighbourNode)
			{
				status |= DT_OUT_OF_NODES;
				continue;
			}
			
			if (neighbourNode->flags & DT_NODE_CLOSED)
				continue;
			
			if (neighbourNode->flags == 0)
				dtVlerp(neighbourNode->pos, va, vb, 0.5f);
			
			const float total = bestNode->total + dtVdist(bestNode->pos, neighbourNode->pos);
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->id = neighbourRef;
			neighbourNode->flags = (neighbourNode->flags & ~DT_NODE_CLOSED);
			neighbourNode->pidx = m_nodePool->getNodeIdx(bestNode);
			neighbourNode->total = total;
			
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags = DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
		}
	}
	
	if (!randomPoly)
		return DT_FAILURE;
	
	const float* v = &randomTile->verts[randomPoly->verts[0]*3];
	float verts[3*DT_VERTS_PER_POLYGON];
	float areas[DT_VERTS_PER_POLYGON];
	dtVcopy(&verts[0*3],v);
	for (int j = 1; j < randomPoly->vertCount; ++j)
	{
		v = &randomTile->verts[randomPoly->verts[j]*3];
		dtVcopy(&verts[j*3],v);
	}
	
	const float s = frand();
	const float t = frand();
	
	float pt[3];
	dtRandomPointInConvexPoly(verts, randomPoly->vertCount, areas, s, t, pt);
	
	closestPointOnPoly(randomPolyRef, pt, pt, NULL);
	
	dtVcopy(randomPt, pt);
	*randomRef = randomPolyRef;
	
	return status;
}

dtStatus dtNavMeshQuery::closestPointOnPoly(dtPolyRef ref, const float* pos, float* closest, bool* posOverPoly) const
{
	dtAssert(m_nav);
	if (!m_nav->isValidPolyRef(ref) ||
		!pos || !dtVisfinite(pos) ||
		!closest)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}

	m_nav->closestPointOnPoly(ref, pos, closest, posOverPoly);
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::closestPointOnPolyBoundary(dtPolyRef ref, const float* pos, float* closest) const
{
	dtAssert(m_nav);
	
	const dtMeshTile* tile = 0;
	const dtPoly* poly = 0;
	if (dtStatusFailed(m_nav->getTileAndPolyByRef(ref, &tile, &poly)))
		return DT_FAILURE | DT_INVALID_PARAM;

	if (!pos || !dtVisfinite(pos) || !closest)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	float verts[DT_VERTS_PER_POLYGON*3];	
	float edged[DT_VERTS_PER_POLYGON];
	float edget[DT_VERTS_PER_POLYGON];
	int nv = 0;
	for (int i = 0; i < (int)poly->vertCount; ++i)
	{
		dtVcopy(&verts[nv*3], &tile->verts[poly->verts[i]*3]);
		nv++;
	}		
	
	bool inside = dtDistancePtPolyEdgesSqr(pos, verts, nv, edged, edget);
	if (inside)
	{
		dtVcopy(closest, pos);
	}
	else
	{
		float dmin = edged[0];
		int imin = 0;
		for (int i = 1; i < nv; ++i)
		{
			if (edged[i] < dmin)
			{
				dmin = edged[i];
				imin = i;
			}
		}
		const float* va = &verts[imin*3];
		const float* vb = &verts[((imin+1)%nv)*3];
		dtVlerp(closest, va, vb, edget[imin]);
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::getPolyHeight(dtPolyRef ref, const float* pos, float* height) const
{
	dtAssert(m_nav);

	const dtMeshTile* tile = 0;
	const dtPoly* poly = 0;
	if (dtStatusFailed(m_nav->getTileAndPolyByRef(ref, &tile, &poly)))
		return DT_FAILURE | DT_INVALID_PARAM;

	if (!pos || !dtVisfinite2D(pos))
		return DT_FAILURE | DT_INVALID_PARAM;

	if (poly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
	{
		const float* v0 = &tile->verts[poly->verts[0]*3];
		const float* v1 = &tile->verts[poly->verts[1]*3];
		float t;
		dtDistancePtSegSqr2D(pos, v0, v1, t);
		if (height)
			*height = v0[1] + (v1[1] - v0[1])*t;

		return DT_SUCCESS;
	}

	return m_nav->getPolyHeight(tile, poly, pos, height)
		? DT_SUCCESS
		: DT_FAILURE | DT_INVALID_PARAM;
}

class dtFindNearestPolyQuery : public dtPolyQuery
{
	const dtNavMeshQuery* m_query;
	const float* m_center;
	float m_nearestDistanceSqr;
	dtPolyRef m_nearestRef;
	float m_nearestPoint[3];
	bool m_overPoly;

public:
	dtFindNearestPolyQuery(const dtNavMeshQuery* query, const float* center)
		: m_query(query), m_center(center), m_nearestDistanceSqr(FLT_MAX), m_nearestRef(0), m_nearestPoint(), m_overPoly(false)
	{
	}

	virtual ~dtFindNearestPolyQuery();

	dtPolyRef nearestRef() const { return m_nearestRef; }
	const float* nearestPoint() const { return m_nearestPoint; }
	bool isOverPoly() const { return m_overPoly; }

	void process(const dtMeshTile* tile, dtPoly** polys, dtPolyRef* refs, int count)
	{
		dtIgnoreUnused(polys);

		for (int i = 0; i < count; ++i)
		{
			dtPolyRef ref = refs[i];
			float closestPtPoly[3];
			float diff[3];
			bool posOverPoly = false;
			float d;
			m_query->closestPointOnPoly(ref, m_center, closestPtPoly, &posOverPoly);

			dtVsub(diff, m_center, closestPtPoly);
			if (posOverPoly)
			{
				d = dtAbs(diff[1]) - tile->header->walkableClimb;
				d = d > 0 ? d*d : 0;			
			}
			else
			{
				d = dtVlenSqr(diff);
			}
			
			if (d < m_nearestDistanceSqr)
			{
				dtVcopy(m_nearestPoint, closestPtPoly);

				m_nearestDistanceSqr = d;
				m_nearestRef = ref;
				m_overPoly = posOverPoly;
			}
		}
	}
};

dtFindNearestPolyQuery::~dtFindNearestPolyQuery()
{
}

dtStatus dtNavMeshQuery::findNearestPoly(const float* center, const float* halfExtents,
										 const dtQueryFilter* filter,
										 dtPolyRef* nearestRef, float* nearestPt) const
{
	return findNearestPoly(center, halfExtents, filter, nearestRef, nearestPt, NULL);
}

dtStatus dtNavMeshQuery::findNearestPoly(const float* center, const float* halfExtents,
										 const dtQueryFilter* filter,
										 dtPolyRef* nearestRef, float* nearestPt, bool* isOverPoly) const
{
	dtAssert(m_nav);

	if (!nearestRef)
		return DT_FAILURE | DT_INVALID_PARAM;

	dtFindNearestPolyQuery query(this, center);

	dtStatus status = queryPolygons(center, halfExtents, filter, &query);
	if (dtStatusFailed(status))
		return status;

	*nearestRef = query.nearestRef();
	if (nearestPt && *nearestRef)
	{
		dtVcopy(nearestPt, query.nearestPoint());
		if (isOverPoly)
			*isOverPoly = query.isOverPoly();
	}
	
	return DT_SUCCESS;
}

void dtNavMeshQuery::queryPolygonsInTile(const dtMeshTile* tile, const float* qmin, const float* qmax,
										 const dtQueryFilter* filter, dtPolyQuery* query) const
{
	dtAssert(m_nav);
	static const int batchSize = 32;
	dtPolyRef polyRefs[batchSize];
	dtPoly* polys[batchSize];
	int n = 0;

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

		const dtPolyRef base = m_nav->getPolyRefBase(tile);
		while (node < end)
		{
			const bool overlap = dtOverlapQuantBounds(bmin, bmax, node->bmin, node->bmax);
			const bool isLeafNode = node->i >= 0;

			if (isLeafNode && overlap)
			{
				dtPolyRef ref = base | (dtPolyRef)node->i;
				if (filter->passFilter(ref, tile, &tile->polys[node->i]))
				{
					polyRefs[n] = ref;
					polys[n] = &tile->polys[node->i];

					if (n == batchSize - 1)
					{
						query->process(tile, polys, polyRefs, batchSize);
						n = 0;
					}
					else
					{
						n++;
					}
				}
			}

			if (overlap || isLeafNode)
				node++;
			else
			{
				const int escapeIndex = -node->i;
				node += escapeIndex;
			}
		}
	}
	else
	{
		float bmin[3], bmax[3];
		const dtPolyRef base = m_nav->getPolyRefBase(tile);
		for (int i = 0; i < tile->header->polyCount; ++i)
		{
			dtPoly* p = &tile->polys[i];
			if (p->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
				continue;
			const dtPolyRef ref = base | (dtPolyRef)i;
			if (!filter->passFilter(ref, tile, p))
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
			if (dtOverlapBounds(qmin, qmax, bmin, bmax))
			{
				polyRefs[n] = ref;
				polys[n] = p;

				if (n == batchSize - 1)
				{
					query->process(tile, polys, polyRefs, batchSize);
					n = 0;
				}
				else
				{
					n++;
				}
			}
		}
	}

	if (n > 0)
		query->process(tile, polys, polyRefs, n);
}

class dtCollectPolysQuery : public dtPolyQuery
{
	dtPolyRef* m_polys;
	const int m_maxPolys;
	int m_numCollected;
	bool m_overflow;

public:
	dtCollectPolysQuery(dtPolyRef* polys, const int maxPolys)
		: m_polys(polys), m_maxPolys(maxPolys), m_numCollected(0), m_overflow(false)
	{
	}

	virtual ~dtCollectPolysQuery();

	int numCollected() const { return m_numCollected; }
	bool overflowed() const { return m_overflow; }

	void process(const dtMeshTile* tile, dtPoly** polys, dtPolyRef* refs, int count)
	{
		dtIgnoreUnused(tile);
		dtIgnoreUnused(polys);

		int numLeft = m_maxPolys - m_numCollected;
		int toCopy = count;
		if (toCopy > numLeft)
		{
			m_overflow = true;
			toCopy = numLeft;
		}

		memcpy(m_polys + m_numCollected, refs, (size_t)toCopy * sizeof(dtPolyRef));
		m_numCollected += toCopy;
	}
};

dtCollectPolysQuery::~dtCollectPolysQuery()
{
}

dtStatus dtNavMeshQuery::queryPolygons(const float* center, const float* halfExtents,
									   const dtQueryFilter* filter,
									   dtPolyRef* polys, int* polyCount, const int maxPolys) const
{
	if (!polys || !polyCount || maxPolys < 0)
		return DT_FAILURE | DT_INVALID_PARAM;

	dtCollectPolysQuery collector(polys, maxPolys);

	dtStatus status = queryPolygons(center, halfExtents, filter, &collector);
	if (dtStatusFailed(status))
		return status;

	*polyCount = collector.numCollected();
	return collector.overflowed() ? DT_SUCCESS | DT_BUFFER_TOO_SMALL : DT_SUCCESS;
}

dtStatus dtNavMeshQuery::queryPolygons(const float* center, const float* halfExtents,
									   const dtQueryFilter* filter, dtPolyQuery* query) const
{
	dtAssert(m_nav);

	if (!center || !dtVisfinite(center) ||
		!halfExtents || !dtVisfinite(halfExtents) ||
		!filter || !query)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}

	float bmin[3], bmax[3];
	dtVsub(bmin, center, halfExtents);
	dtVadd(bmax, center, halfExtents);
	
	int minx, miny, maxx, maxy;
	m_nav->calcTileLoc(bmin, &minx, &miny);
	m_nav->calcTileLoc(bmax, &maxx, &maxy);

	static const int MAX_NEIS = 32;
	const dtMeshTile* neis[MAX_NEIS];
	
	for (int y = miny; y <= maxy; ++y)
	{
		for (int x = minx; x <= maxx; ++x)
		{
			const int nneis = m_nav->getTilesAt(x,y,neis,MAX_NEIS);
			for (int j = 0; j < nneis; ++j)
			{
				queryPolygonsInTile(neis[j], bmin, bmax, filter, query);
			}
		}
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::findPath(dtPolyRef startRef, dtPolyRef endRef,
								  const float* startPos, const float* endPos,
								  const dtQueryFilter* filter,
								  dtPolyRef* path, int* pathCount, const int maxPath) const
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);

	if (!pathCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*pathCount = 0;
	
	if (!m_nav->isValidPolyRef(startRef) || !m_nav->isValidPolyRef(endRef) ||
		!startPos || !dtVisfinite(startPos) ||
		!endPos || !dtVisfinite(endPos) ||
		!filter || !path || maxPath <= 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}

	if (startRef == endRef)
	{
		path[0] = startRef;
		*pathCount = 1;
		return DT_SUCCESS;
	}
	
	m_nodePool->clear();
	m_openList->clear();
	
	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, startPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = dtVdist(startPos, endPos) * H_SCALE;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	dtNode* lastBestNode = startNode;
	float lastBestNodeCost = startNode->total;
	
	bool outOfNodes = false;
	
	while (!m_openList->empty())
	{
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		if (bestNode->id == endRef)
		{
			lastBestNode = bestNode;
			break;
		}
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(bestRef, &bestTile, &bestPoly);
		
		dtPolyRef parentRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		if (bestNode->pidx)
			parentRef = m_nodePool->getNodeAtIdx(bestNode->pidx)->id;
		if (parentRef)
			m_nav->getTileAndPolyByRefUnsafe(parentRef, &parentTile, &parentPoly);
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			dtPolyRef neighbourRef = bestTile->links[i].ref;
			
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);			
			
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;

			unsigned char crossSide = 0;
			if (bestTile->links[i].side != 0xff)
				crossSide = bestTile->links[i].side >> 1;

			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef, crossSide);
			if (!neighbourNode)
			{
				outOfNodes = true;
				continue;
			}
			
			if (neighbourNode->flags == 0)
			{
				getEdgeMidPoint(bestRef, bestPoly, bestTile,
								neighbourRef, neighbourPoly, neighbourTile,
								neighbourNode->pos);
			}

			float cost = 0;
			float heuristic = 0;
			
			if (neighbourRef == endRef)
			{
				const float curCost = filter->getCost(bestNode->pos, neighbourNode->pos,
													  parentRef, parentTile, parentPoly,
													  bestRef, bestTile, bestPoly,
													  neighbourRef, neighbourTile, neighbourPoly);
				const float endCost = filter->getCost(neighbourNode->pos, endPos,
													  bestRef, bestTile, bestPoly,
													  neighbourRef, neighbourTile, neighbourPoly,
													  0, 0, 0);
				
				cost = bestNode->cost + curCost + endCost;
				heuristic = 0;
			}
			else
			{
				const float curCost = filter->getCost(bestNode->pos, neighbourNode->pos,
													  parentRef, parentTile, parentPoly,
													  bestRef, bestTile, bestPoly,
													  neighbourRef, neighbourTile, neighbourPoly);
				cost = bestNode->cost + curCost;
				heuristic = dtVdist(neighbourNode->pos, endPos)*H_SCALE;
			}

			const float total = cost + heuristic;
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			if ((neighbourNode->flags & DT_NODE_CLOSED) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->pidx = m_nodePool->getNodeIdx(bestNode);
			neighbourNode->id = neighbourRef;
			neighbourNode->flags = (neighbourNode->flags & ~DT_NODE_CLOSED);
			neighbourNode->cost = cost;
			neighbourNode->total = total;
			
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags |= DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
			
			if (heuristic < lastBestNodeCost)
			{
				lastBestNodeCost = heuristic;
				lastBestNode = neighbourNode;
			}
		}
	}

	dtStatus status = getPathToNode(lastBestNode, path, pathCount, maxPath);

	if (lastBestNode->id != endRef)
		status |= DT_PARTIAL_RESULT;

	if (outOfNodes)
		status |= DT_OUT_OF_NODES;
	
	return status;
}

dtStatus dtNavMeshQuery::getPathToNode(dtNode* endNode, dtPolyRef* path, int* pathCount, int maxPath) const
{
	dtNode* curNode = endNode;
	int length = 0;
	do
	{
		length++;
		curNode = m_nodePool->getNodeAtIdx(curNode->pidx);
	} while (curNode);

	curNode = endNode;
	int writeCount;
	for (writeCount = length; writeCount > maxPath; writeCount--)
	{
		dtAssert(curNode);

		curNode = m_nodePool->getNodeAtIdx(curNode->pidx);
	}

	for (int i = writeCount - 1; i >= 0; i--)
	{
		dtAssert(curNode);

		path[i] = curNode->id;
		curNode = m_nodePool->getNodeAtIdx(curNode->pidx);
	}

	dtAssert(!curNode);

	*pathCount = dtMin(length, maxPath);

	if (length > maxPath)
		return DT_SUCCESS | DT_BUFFER_TOO_SMALL;

	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::initSlicedFindPath(dtPolyRef startRef, dtPolyRef endRef,
											const float* startPos, const float* endPos,
											const dtQueryFilter* filter, const unsigned int options)
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);

	memset(&m_query, 0, sizeof(dtQueryData));
	m_query.status = DT_FAILURE;
	m_query.startRef = startRef;
	m_query.endRef = endRef;
	if (startPos)
		dtVcopy(m_query.startPos, startPos);
	if (endPos)
		dtVcopy(m_query.endPos, endPos);
	m_query.filter = filter;
	m_query.options = options;
	m_query.raycastLimitSqr = FLT_MAX;
	
	if (!m_nav->isValidPolyRef(startRef) || !m_nav->isValidPolyRef(endRef) ||
		!startPos || !dtVisfinite(startPos) ||
		!endPos || !dtVisfinite(endPos) || !filter)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}

	if (options & DT_FINDPATH_ANY_ANGLE)
	{
		const dtMeshTile* tile = m_nav->getTileByRef(startRef);
		float agentRadius = tile->header->walkableRadius;
		m_query.raycastLimitSqr = dtSqr(agentRadius * DT_RAY_CAST_LIMIT_PROPORTIONS);
	}

	if (startRef == endRef)
	{
		m_query.status = DT_SUCCESS;
		return DT_SUCCESS;
	}
	
	m_nodePool->clear();
	m_openList->clear();
	
	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, startPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = dtVdist(startPos, endPos) * H_SCALE;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	m_query.status = DT_IN_PROGRESS;
	m_query.lastBestNode = startNode;
	m_query.lastBestNodeCost = startNode->total;
	
	return m_query.status;
}
	
dtStatus dtNavMeshQuery::updateSlicedFindPath(const int maxIter, int* doneIters)
{
	if (!dtStatusInProgress(m_query.status))
		return m_query.status;

	if (!m_nav->isValidPolyRef(m_query.startRef) || !m_nav->isValidPolyRef(m_query.endRef))
	{
		m_query.status = DT_FAILURE;
		return DT_FAILURE;
	}

	dtRaycastHit rayHit;
	rayHit.maxPath = 0;
		
	int iter = 0;
	while (iter < maxIter && !m_openList->empty())
	{
		iter++;
		
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		if (bestNode->id == m_query.endRef)
		{
			m_query.lastBestNode = bestNode;
			const dtStatus details = m_query.status & DT_STATUS_DETAIL_MASK;
			m_query.status = DT_SUCCESS | details;
			if (doneIters)
				*doneIters = iter;
			return m_query.status;
		}
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		if (dtStatusFailed(m_nav->getTileAndPolyByRef(bestRef, &bestTile, &bestPoly)))
		{
			m_query.status = DT_FAILURE;
			if (doneIters)
				*doneIters = iter;
			return m_query.status;
		}
		
		dtPolyRef parentRef = 0, grandpaRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		dtNode* parentNode = 0;
		if (bestNode->pidx)
		{
			parentNode = m_nodePool->getNodeAtIdx(bestNode->pidx);
			parentRef = parentNode->id;
			if (parentNode->pidx)
				grandpaRef = m_nodePool->getNodeAtIdx(parentNode->pidx)->id;
		}
		if (parentRef)
		{
			bool invalidParent = dtStatusFailed(m_nav->getTileAndPolyByRef(parentRef, &parentTile, &parentPoly));
			if (invalidParent || (grandpaRef && !m_nav->isValidPolyRef(grandpaRef)) )
			{
				m_query.status = DT_FAILURE;
				if (doneIters)
					*doneIters = iter;
				return m_query.status;
			}
		}

		bool tryLOS = false;
		if (m_query.options & DT_FINDPATH_ANY_ANGLE)
		{
			if ((parentRef != 0) && (dtVdistSqr(parentNode->pos, bestNode->pos) < m_query.raycastLimitSqr))
				tryLOS = true;
		}
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			dtPolyRef neighbourRef = bestTile->links[i].ref;
			
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);			
			
			if (!m_query.filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;
			
			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef, 0);
			if (!neighbourNode)
			{
				m_query.status |= DT_OUT_OF_NODES;
				continue;
			}
			
			if (neighbourNode->pidx != 0 && neighbourNode->pidx == bestNode->pidx)
				continue;

			if (neighbourNode->flags == 0)
			{
				getEdgeMidPoint(bestRef, bestPoly, bestTile,
								neighbourRef, neighbourPoly, neighbourTile,
								neighbourNode->pos);
			}
			
			float cost = 0;
			float heuristic = 0;
			
			bool foundShortCut = false;
			rayHit.pathCost = rayHit.t = 0;
			if (tryLOS)
			{
				raycast(parentRef, parentNode->pos, neighbourNode->pos, m_query.filter, DT_RAYCAST_USE_COSTS, &rayHit, grandpaRef);
				foundShortCut = rayHit.t >= 1.0f;
			}

			if (foundShortCut)
			{
				cost = parentNode->cost + rayHit.pathCost;
			}
			else
			{
				const float curCost = m_query.filter->getCost(bestNode->pos, neighbourNode->pos,
															  parentRef, parentTile, parentPoly,
															bestRef, bestTile, bestPoly,
															neighbourRef, neighbourTile, neighbourPoly);
				cost = bestNode->cost + curCost;
			}

			if (neighbourRef == m_query.endRef)
			{
				const float endCost = m_query.filter->getCost(neighbourNode->pos, m_query.endPos,
															  bestRef, bestTile, bestPoly,
															  neighbourRef, neighbourTile, neighbourPoly,
															  0, 0, 0);
				
				cost = cost + endCost;
				heuristic = 0;
			}
			else
			{
				heuristic = dtVdist(neighbourNode->pos, m_query.endPos)*H_SCALE;
			}
			
			const float total = cost + heuristic;
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			if ((neighbourNode->flags & DT_NODE_CLOSED) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->pidx = foundShortCut ? bestNode->pidx : m_nodePool->getNodeIdx(bestNode);
			neighbourNode->id = neighbourRef;
			neighbourNode->flags = (neighbourNode->flags & ~(DT_NODE_CLOSED | DT_NODE_PARENT_DETACHED));
			neighbourNode->cost = cost;
			neighbourNode->total = total;
			if (foundShortCut)
				neighbourNode->flags = (neighbourNode->flags | DT_NODE_PARENT_DETACHED);
			
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags |= DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
			
			if (heuristic < m_query.lastBestNodeCost)
			{
				m_query.lastBestNodeCost = heuristic;
				m_query.lastBestNode = neighbourNode;
			}
		}
	}
	
	if (m_openList->empty())
	{
		const dtStatus details = m_query.status & DT_STATUS_DETAIL_MASK;
		m_query.status = DT_SUCCESS | details;
	}

	if (doneIters)
		*doneIters = iter;

	return m_query.status;
}

dtStatus dtNavMeshQuery::finalizeSlicedFindPath(dtPolyRef* path, int* pathCount, const int maxPath)
{
	if (!pathCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*pathCount = 0;

	if (!path || maxPath <= 0)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	if (dtStatusFailed(m_query.status))
	{
		memset(&m_query, 0, sizeof(dtQueryData));
		return DT_FAILURE;
	}

	int n = 0;

	if (m_query.startRef == m_query.endRef)
	{
		path[n++] = m_query.startRef;
	}
	else
	{
		dtAssert(m_query.lastBestNode);
		
		if (m_query.lastBestNode->id != m_query.endRef)
			m_query.status |= DT_PARTIAL_RESULT;
		
		dtNode* prev = 0;
		dtNode* node = m_query.lastBestNode;
		int prevRay = 0;
		do
		{
			dtNode* next = m_nodePool->getNodeAtIdx(node->pidx);
			node->pidx = m_nodePool->getNodeIdx(prev);
			prev = node;
			int nextRay = node->flags & DT_NODE_PARENT_DETACHED;
			node->flags = (node->flags & ~DT_NODE_PARENT_DETACHED) | prevRay;
			prevRay = nextRay;
			node = next;
		}
		while (node);
		
		node = prev;
		do
		{
			dtNode* next = m_nodePool->getNodeAtIdx(node->pidx);
			dtStatus status = 0;
			if (node->flags & DT_NODE_PARENT_DETACHED)
			{
				float t, normal[3];
				int m;
				status = raycast(node->id, node->pos, next->pos, m_query.filter, &t, normal, path+n, &m, maxPath-n);
				n += m;
				if (path[n-1] == next->id)
					n--;
			}
			else
			{
				path[n++] = node->id;
				if (n >= maxPath)
					status = DT_BUFFER_TOO_SMALL;
			}

			if (status & DT_STATUS_DETAIL_MASK)
			{
				m_query.status |= status & DT_STATUS_DETAIL_MASK;
				break;
			}
			node = next;
		}
		while (node);
	}
	
	const dtStatus details = m_query.status & DT_STATUS_DETAIL_MASK;

	memset(&m_query, 0, sizeof(dtQueryData));
	
	*pathCount = n;
	
	return DT_SUCCESS | details;
}

dtStatus dtNavMeshQuery::finalizeSlicedFindPathPartial(const dtPolyRef* existing, const int existingSize,
													   dtPolyRef* path, int* pathCount, const int maxPath)
{
	if (!pathCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*pathCount = 0;

	if (!existing || existingSize <= 0 || !path || !pathCount || maxPath <= 0)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	if (dtStatusFailed(m_query.status))
	{
		memset(&m_query, 0, sizeof(dtQueryData));
		return DT_FAILURE;
	}
	
	int n = 0;
	
	if (m_query.startRef == m_query.endRef)
	{
		path[n++] = m_query.startRef;
	}
	else
	{
		dtNode* prev = 0;
		dtNode* node = 0;
		for (int i = existingSize-1; i >= 0; --i)
		{
			m_nodePool->findNodes(existing[i], &node, 1);
			if (node)
				break;
		}
		
		if (!node)
		{
			m_query.status |= DT_PARTIAL_RESULT;
			dtAssert(m_query.lastBestNode);
			node = m_query.lastBestNode;
		}
		
		int prevRay = 0;
		do
		{
			dtNode* next = m_nodePool->getNodeAtIdx(node->pidx);
			node->pidx = m_nodePool->getNodeIdx(prev);
			prev = node;
			int nextRay = node->flags & DT_NODE_PARENT_DETACHED;
			node->flags = (node->flags & ~DT_NODE_PARENT_DETACHED) | prevRay;
			prevRay = nextRay;
			node = next;
		}
		while (node);
		
		node = prev;
		do
		{
			dtNode* next = m_nodePool->getNodeAtIdx(node->pidx);
			dtStatus status = 0;
			if (node->flags & DT_NODE_PARENT_DETACHED)
			{
				float t, normal[3];
				int m;
				status = raycast(node->id, node->pos, next->pos, m_query.filter, &t, normal, path+n, &m, maxPath-n);
				n += m;
				if (path[n-1] == next->id)
					n--;
			}
			else
			{
				path[n++] = node->id;
				if (n >= maxPath)
					status = DT_BUFFER_TOO_SMALL;
			}

			if (status & DT_STATUS_DETAIL_MASK)
			{
				m_query.status |= status & DT_STATUS_DETAIL_MASK;
				break;
			}
			node = next;
		}
		while (node);
	}
	
	const dtStatus details = m_query.status & DT_STATUS_DETAIL_MASK;

	memset(&m_query, 0, sizeof(dtQueryData));
	
	*pathCount = n;
	
	return DT_SUCCESS | details;
}

dtStatus dtNavMeshQuery::appendVertex(const float* pos, const unsigned char flags, const dtPolyRef ref,
									  float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
									  int* straightPathCount, const int maxStraightPath) const
{
	if ((*straightPathCount) > 0 && dtVequal(&straightPath[((*straightPathCount)-1)*3], pos))
	{
		if (straightPathFlags)
			straightPathFlags[(*straightPathCount)-1] = flags;
		if (straightPathRefs)
			straightPathRefs[(*straightPathCount)-1] = ref;
	}
	else
	{
		dtVcopy(&straightPath[(*straightPathCount)*3], pos);
		if (straightPathFlags)
			straightPathFlags[(*straightPathCount)] = flags;
		if (straightPathRefs)
			straightPathRefs[(*straightPathCount)] = ref;
		(*straightPathCount)++;

		if ((*straightPathCount) >= maxStraightPath)
		{
			return DT_SUCCESS | DT_BUFFER_TOO_SMALL;
		}

		if (flags == DT_STRAIGHTPATH_END)
		{
			return DT_SUCCESS;
		}
	}
	return DT_IN_PROGRESS;
}

dtStatus dtNavMeshQuery::appendPortals(const int startIdx, const int endIdx, const float* endPos, const dtPolyRef* path,
									  float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
									  int* straightPathCount, const int maxStraightPath, const int options) const
{
	const float* startPos = &straightPath[(*straightPathCount-1)*3];
	dtStatus stat = 0;
	for (int i = startIdx; i < endIdx; i++)
	{
		const dtPolyRef from = path[i];
		const dtMeshTile* fromTile = 0;
		const dtPoly* fromPoly = 0;
		if (dtStatusFailed(m_nav->getTileAndPolyByRef(from, &fromTile, &fromPoly)))
			return DT_FAILURE | DT_INVALID_PARAM;
		
		const dtPolyRef to = path[i+1];
		const dtMeshTile* toTile = 0;
		const dtPoly* toPoly = 0;
		if (dtStatusFailed(m_nav->getTileAndPolyByRef(to, &toTile, &toPoly)))
			return DT_FAILURE | DT_INVALID_PARAM;
		
		float left[3], right[3];
		if (dtStatusFailed(getPortalPoints(from, fromPoly, fromTile, to, toPoly, toTile, left, right)))
			break;
	
		if (options & DT_STRAIGHTPATH_AREA_CROSSINGS)
		{
			if (fromPoly->getArea() == toPoly->getArea())
				continue;
		}
		
		float s,t;
		if (dtIntersectSegSeg2D(startPos, endPos, left, right, s, t))
		{
			float pt[3];
			dtVlerp(pt, left,right, t);

			stat = appendVertex(pt, 0, path[i+1],
								straightPath, straightPathFlags, straightPathRefs,
								straightPathCount, maxStraightPath);
			if (stat != DT_IN_PROGRESS)
				return stat;
		}
	}
	return DT_IN_PROGRESS;
}

dtStatus dtNavMeshQuery::findStraightPath(const float* startPos, const float* endPos,
										  const dtPolyRef* path, const int pathSize,
										  float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
										  int* straightPathCount, const int maxStraightPath, const int options) const
{
	dtAssert(m_nav);

	if (!straightPathCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*straightPathCount = 0;

	if (!startPos || !dtVisfinite(startPos) ||
		!endPos || !dtVisfinite(endPos) ||
		!path || pathSize <= 0 || !path[0] ||
		maxStraightPath <= 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	dtStatus stat = 0;
	
	float closestStartPos[3];
	if (dtStatusFailed(closestPointOnPolyBoundary(path[0], startPos, closestStartPos)))
		return DT_FAILURE | DT_INVALID_PARAM;

	float closestEndPos[3];
	if (dtStatusFailed(closestPointOnPolyBoundary(path[pathSize-1], endPos, closestEndPos)))
		return DT_FAILURE | DT_INVALID_PARAM;
	
	stat = appendVertex(closestStartPos, DT_STRAIGHTPATH_START, path[0],
						straightPath, straightPathFlags, straightPathRefs,
						straightPathCount, maxStraightPath);
	if (stat != DT_IN_PROGRESS)
		return stat;
	
	if (pathSize > 1)
	{
		float portalApex[3], portalLeft[3], portalRight[3];
		dtVcopy(portalApex, closestStartPos);
		dtVcopy(portalLeft, portalApex);
		dtVcopy(portalRight, portalApex);
		int apexIndex = 0;
		int leftIndex = 0;
		int rightIndex = 0;
		
		unsigned char leftPolyType = 0;
		unsigned char rightPolyType = 0;
		
		dtPolyRef leftPolyRef = path[0];
		dtPolyRef rightPolyRef = path[0];
		
		for (int i = 0; i < pathSize; ++i)
		{
			float left[3], right[3];
			unsigned char toType;
			
			if (i+1 < pathSize)
			{
				unsigned char fromType;

				if (dtStatusFailed(getPortalPoints(path[i], path[i+1], left, right, fromType, toType)))
				{
					
					if (dtStatusFailed(closestPointOnPolyBoundary(path[i], endPos, closestEndPos)))
					{
						return DT_FAILURE | DT_INVALID_PARAM;
					}

					if (options & (DT_STRAIGHTPATH_AREA_CROSSINGS | DT_STRAIGHTPATH_ALL_CROSSINGS))
					{
						appendPortals(apexIndex, i, closestEndPos, path,
											 straightPath, straightPathFlags, straightPathRefs,
											 straightPathCount, maxStraightPath, options);
					}

					appendVertex(closestEndPos, 0, path[i],
										straightPath, straightPathFlags, straightPathRefs,
										straightPathCount, maxStraightPath);
					
					return DT_SUCCESS | DT_PARTIAL_RESULT | ((*straightPathCount >= maxStraightPath) ? DT_BUFFER_TOO_SMALL : 0);
				}
				
				if (i == 0)
				{
					float t;
					if (dtDistancePtSegSqr2D(portalApex, left, right, t) < dtSqr(0.001f))
						continue;
				}
			}
			else
			{
				dtVcopy(left, closestEndPos);
				dtVcopy(right, closestEndPos);
				
				toType = DT_POLYTYPE_GROUND;
			}
			
			if (dtTriArea2D(portalApex, portalRight, right) <= 0.0f)
			{
				if (dtVequal(portalApex, portalRight) || dtTriArea2D(portalApex, portalLeft, right) > 0.0f)
				{
					dtVcopy(portalRight, right);
					rightPolyRef = (i+1 < pathSize) ? path[i+1] : 0;
					rightPolyType = toType;
					rightIndex = i;
				}
				else
				{
					if (options & (DT_STRAIGHTPATH_AREA_CROSSINGS | DT_STRAIGHTPATH_ALL_CROSSINGS))
					{
						stat = appendPortals(apexIndex, leftIndex, portalLeft, path,
											 straightPath, straightPathFlags, straightPathRefs,
											 straightPathCount, maxStraightPath, options);
						if (stat != DT_IN_PROGRESS)
							return stat;					
					}
				
					dtVcopy(portalApex, portalLeft);
					apexIndex = leftIndex;
					
					unsigned char flags = 0;
					if (!leftPolyRef)
						flags = DT_STRAIGHTPATH_END;
					else if (leftPolyType == DT_POLYTYPE_OFFMESH_CONNECTION)
						flags = DT_STRAIGHTPATH_OFFMESH_CONNECTION;
					dtPolyRef ref = leftPolyRef;
					
					stat = appendVertex(portalApex, flags, ref,
										straightPath, straightPathFlags, straightPathRefs,
										straightPathCount, maxStraightPath);
					if (stat != DT_IN_PROGRESS)
						return stat;
					
					dtVcopy(portalLeft, portalApex);
					dtVcopy(portalRight, portalApex);
					leftIndex = apexIndex;
					rightIndex = apexIndex;
					
					i = apexIndex;
					
					continue;
				}
			}
			
			if (dtTriArea2D(portalApex, portalLeft, left) >= 0.0f)
			{
				if (dtVequal(portalApex, portalLeft) || dtTriArea2D(portalApex, portalRight, left) < 0.0f)
				{
					dtVcopy(portalLeft, left);
					leftPolyRef = (i+1 < pathSize) ? path[i+1] : 0;
					leftPolyType = toType;
					leftIndex = i;
				}
				else
				{
					if (options & (DT_STRAIGHTPATH_AREA_CROSSINGS | DT_STRAIGHTPATH_ALL_CROSSINGS))
					{
						stat = appendPortals(apexIndex, rightIndex, portalRight, path,
											 straightPath, straightPathFlags, straightPathRefs,
											 straightPathCount, maxStraightPath, options);
						if (stat != DT_IN_PROGRESS)
							return stat;
					}

					dtVcopy(portalApex, portalRight);
					apexIndex = rightIndex;
					
					unsigned char flags = 0;
					if (!rightPolyRef)
						flags = DT_STRAIGHTPATH_END;
					else if (rightPolyType == DT_POLYTYPE_OFFMESH_CONNECTION)
						flags = DT_STRAIGHTPATH_OFFMESH_CONNECTION;
					dtPolyRef ref = rightPolyRef;

					stat = appendVertex(portalApex, flags, ref,
										straightPath, straightPathFlags, straightPathRefs,
										straightPathCount, maxStraightPath);
					if (stat != DT_IN_PROGRESS)
						return stat;
					
					dtVcopy(portalLeft, portalApex);
					dtVcopy(portalRight, portalApex);
					leftIndex = apexIndex;
					rightIndex = apexIndex;
					
					i = apexIndex;
					
					continue;
				}
			}
		}

		if (options & (DT_STRAIGHTPATH_AREA_CROSSINGS | DT_STRAIGHTPATH_ALL_CROSSINGS))
		{
			stat = appendPortals(apexIndex, pathSize-1, closestEndPos, path,
								 straightPath, straightPathFlags, straightPathRefs,
								 straightPathCount, maxStraightPath, options);
			if (stat != DT_IN_PROGRESS)
				return stat;
		}
	}

	appendVertex(closestEndPos, DT_STRAIGHTPATH_END, 0,
						straightPath, straightPathFlags, straightPathRefs,
						straightPathCount, maxStraightPath);
	
	return DT_SUCCESS | ((*straightPathCount >= maxStraightPath) ? DT_BUFFER_TOO_SMALL : 0);
}

dtStatus dtNavMeshQuery::moveAlongSurface(dtPolyRef startRef, const float* startPos, const float* endPos,
										  const dtQueryFilter* filter,
										  float* resultPos, dtPolyRef* visited, int* visitedCount, const int maxVisitedSize) const
{
	dtAssert(m_nav);
	dtAssert(m_tinyNodePool);

	if (!visitedCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*visitedCount = 0;

	if (!m_nav->isValidPolyRef(startRef) ||
		!startPos || !dtVisfinite(startPos) ||
		!endPos || !dtVisfinite(endPos) ||
		!filter || !resultPos || !visited ||
		maxVisitedSize <= 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	dtStatus status = DT_SUCCESS;
	
	static const int MAX_STACK = 48;
	dtNode* stack[MAX_STACK];
	int nstack = 0;
	
	m_tinyNodePool->clear();
	
	dtNode* startNode = m_tinyNodePool->getNode(startRef);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_CLOSED;
	stack[nstack++] = startNode;
	
	float bestPos[3];
	float bestDist = FLT_MAX;
	dtNode* bestNode = 0;
	dtVcopy(bestPos, startPos);
	
	float searchPos[3], searchRadSqr;
	dtVlerp(searchPos, startPos, endPos, 0.5f);
	searchRadSqr = dtSqr(dtVdist(startPos, endPos)/2.0f + 0.001f);
	
	float verts[DT_VERTS_PER_POLYGON*3];
	
	while (nstack)
	{
		dtNode* curNode = stack[0];
		for (int i = 0; i < nstack-1; ++i)
			stack[i] = stack[i+1];
		nstack--;
		
		const dtPolyRef curRef = curNode->id;
		const dtMeshTile* curTile = 0;
		const dtPoly* curPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(curRef, &curTile, &curPoly);			
		
		const int nverts = curPoly->vertCount;
		for (int i = 0; i < nverts; ++i)
			dtVcopy(&verts[i*3], &curTile->verts[curPoly->verts[i]*3]);
		
		if (dtPointInPolygon(endPos, verts, nverts))
		{
			bestNode = curNode;
			dtVcopy(bestPos, endPos);
			break;
		}
		
		for (int i = 0, j = (int)curPoly->vertCount-1; i < (int)curPoly->vertCount; j = i++)
		{
			static const int MAX_NEIS = 8;
			int nneis = 0;
			dtPolyRef neis[MAX_NEIS];
			
			if (curPoly->neis[j] & DT_EXT_LINK)
			{
				for (unsigned int k = curPoly->firstLink; k != DT_NULL_LINK; k = curTile->links[k].next)
				{
					const dtLink* link = &curTile->links[k];
					if (link->edge == j)
					{
						if (link->ref != 0)
						{
							const dtMeshTile* neiTile = 0;
							const dtPoly* neiPoly = 0;
							m_nav->getTileAndPolyByRefUnsafe(link->ref, &neiTile, &neiPoly);
							if (filter->passFilter(link->ref, neiTile, neiPoly))
							{
								if (nneis < MAX_NEIS)
									neis[nneis++] = link->ref;
							}
						}
					}
				}
			}
			else if (curPoly->neis[j])
			{
				const unsigned int idx = (unsigned int)(curPoly->neis[j]-1);
				const dtPolyRef ref = m_nav->getPolyRefBase(curTile) | idx;
				if (filter->passFilter(ref, curTile, &curTile->polys[idx]))
				{
					neis[nneis++] = ref;
				}
			}
			
			if (!nneis)
			{
				const float* vj = &verts[j*3];
				const float* vi = &verts[i*3];
				float tseg;
				const float distSqr = dtDistancePtSegSqr2D(endPos, vj, vi, tseg);
				if (distSqr < bestDist)
				{
					dtVlerp(bestPos, vj,vi, tseg);
					bestDist = distSqr;
					bestNode = curNode;
				}
			}
			else
			{
				for (int k = 0; k < nneis; ++k)
				{
					dtNode* neighbourNode = m_tinyNodePool->getNode(neis[k]);
					if (!neighbourNode)
						continue;
					if (neighbourNode->flags & DT_NODE_CLOSED)
						continue;
					
					const float* vj = &verts[j*3];
					const float* vi = &verts[i*3];
					float tseg;
					float distSqr = dtDistancePtSegSqr2D(searchPos, vj, vi, tseg);
					if (distSqr > searchRadSqr)
						continue;
					
					if (nstack < MAX_STACK)
					{
						neighbourNode->pidx = m_tinyNodePool->getNodeIdx(curNode);
						neighbourNode->flags |= DT_NODE_CLOSED;
						stack[nstack++] = neighbourNode;
					}
				}
			}
		}
	}
	
	int n = 0;
	if (bestNode)
	{
		dtNode* prev = 0;
		dtNode* node = bestNode;
		do
		{
			dtNode* next = m_tinyNodePool->getNodeAtIdx(node->pidx);
			node->pidx = m_tinyNodePool->getNodeIdx(prev);
			prev = node;
			node = next;
		}
		while (node);
		
		node = prev;
		do
		{
			visited[n++] = node->id;
			if (n >= maxVisitedSize)
			{
				status |= DT_BUFFER_TOO_SMALL;
				break;
			}
			node = m_tinyNodePool->getNodeAtIdx(node->pidx);
		}
		while (node);
	}
	
	dtVcopy(resultPos, bestPos);
	
	*visitedCount = n;
	
	return status;
}

dtStatus dtNavMeshQuery::getPortalPoints(dtPolyRef from, dtPolyRef to, float* left, float* right,
										 unsigned char& fromType, unsigned char& toType) const
{
	dtAssert(m_nav);
	
	const dtMeshTile* fromTile = 0;
	const dtPoly* fromPoly = 0;
	if (dtStatusFailed(m_nav->getTileAndPolyByRef(from, &fromTile, &fromPoly)))
		return DT_FAILURE | DT_INVALID_PARAM;
	fromType = fromPoly->getType();

	const dtMeshTile* toTile = 0;
	const dtPoly* toPoly = 0;
	if (dtStatusFailed(m_nav->getTileAndPolyByRef(to, &toTile, &toPoly)))
		return DT_FAILURE | DT_INVALID_PARAM;
	toType = toPoly->getType();
		
	return getPortalPoints(from, fromPoly, fromTile, to, toPoly, toTile, left, right);
}

dtStatus dtNavMeshQuery::getPortalPoints(dtPolyRef from, const dtPoly* fromPoly, const dtMeshTile* fromTile,
										 dtPolyRef to, const dtPoly* toPoly, const dtMeshTile* toTile,
										 float* left, float* right) const
{
	const dtLink* link = 0;
	for (unsigned int i = fromPoly->firstLink; i != DT_NULL_LINK; i = fromTile->links[i].next)
	{
		if (fromTile->links[i].ref == to)
		{
			link = &fromTile->links[i];
			break;
		}
	}
	if (!link)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	if (fromPoly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
	{
		for (unsigned int i = fromPoly->firstLink; i != DT_NULL_LINK; i = fromTile->links[i].next)
		{
			if (fromTile->links[i].ref == to)
			{
				const int v = fromTile->links[i].edge;
				dtVcopy(left, &fromTile->verts[fromPoly->verts[v]*3]);
				dtVcopy(right, &fromTile->verts[fromPoly->verts[v]*3]);
				return DT_SUCCESS;
			}
		}
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	if (toPoly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
	{
		for (unsigned int i = toPoly->firstLink; i != DT_NULL_LINK; i = toTile->links[i].next)
		{
			if (toTile->links[i].ref == from)
			{
				const int v = toTile->links[i].edge;
				dtVcopy(left, &toTile->verts[toPoly->verts[v]*3]);
				dtVcopy(right, &toTile->verts[toPoly->verts[v]*3]);
				return DT_SUCCESS;
			}
		}
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	const int v0 = fromPoly->verts[link->edge];
	const int v1 = fromPoly->verts[(link->edge+1) % (int)fromPoly->vertCount];
	dtVcopy(left, &fromTile->verts[v0*3]);
	dtVcopy(right, &fromTile->verts[v1*3]);
	
	if (link->side != 0xff)
	{
		if (link->bmin != 0 || link->bmax != 255)
		{
			const float s = 1.0f/255.0f;
			const float tmin = link->bmin*s;
			const float tmax = link->bmax*s;
			dtVlerp(left, &fromTile->verts[v0*3], &fromTile->verts[v1*3], tmin);
			dtVlerp(right, &fromTile->verts[v0*3], &fromTile->verts[v1*3], tmax);
		}
	}
	
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::getEdgeMidPoint(dtPolyRef from, dtPolyRef to, float* mid) const
{
	float left[3], right[3];
	unsigned char fromType, toType;
	if (dtStatusFailed(getPortalPoints(from, to, left,right, fromType, toType)))
		return DT_FAILURE | DT_INVALID_PARAM;
	mid[0] = (left[0]+right[0])*0.5f;
	mid[1] = (left[1]+right[1])*0.5f;
	mid[2] = (left[2]+right[2])*0.5f;
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::getEdgeMidPoint(dtPolyRef from, const dtPoly* fromPoly, const dtMeshTile* fromTile,
										 dtPolyRef to, const dtPoly* toPoly, const dtMeshTile* toTile,
										 float* mid) const
{
	float left[3], right[3];
	if (dtStatusFailed(getPortalPoints(from, fromPoly, fromTile, to, toPoly, toTile, left, right)))
		return DT_FAILURE | DT_INVALID_PARAM;
	mid[0] = (left[0]+right[0])*0.5f;
	mid[1] = (left[1]+right[1])*0.5f;
	mid[2] = (left[2]+right[2])*0.5f;
	return DT_SUCCESS;
}

dtStatus dtNavMeshQuery::raycast(dtPolyRef startRef, const float* startPos, const float* endPos,
								 const dtQueryFilter* filter,
								 float* t, float* hitNormal, dtPolyRef* path, int* pathCount, const int maxPath) const
{
	dtRaycastHit hit;
	hit.path = path;
	hit.maxPath = maxPath;

	dtStatus status = raycast(startRef, startPos, endPos, filter, 0, &hit);
	
	*t = hit.t;
	if (hitNormal)
		dtVcopy(hitNormal, hit.hitNormal);
	if (pathCount)
		*pathCount = hit.pathCount;

	return status;
}

dtStatus dtNavMeshQuery::raycast(dtPolyRef startRef, const float* startPos, const float* endPos,
								 const dtQueryFilter* filter, const unsigned int options,
								 dtRaycastHit* hit, dtPolyRef prevRef) const
{
	dtAssert(m_nav);

	if (!hit)
		return DT_FAILURE | DT_INVALID_PARAM;

	hit->t = 0;
	hit->pathCount = 0;
	hit->pathCost = 0;

	if (!m_nav->isValidPolyRef(startRef) ||
		!startPos || !dtVisfinite(startPos) ||
		!endPos || !dtVisfinite(endPos) ||
		!filter ||
		(prevRef && !m_nav->isValidPolyRef(prevRef)))
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	float dir[3], curPos[3], lastPos[3];
	float verts[DT_VERTS_PER_POLYGON*3+3];	
	int n = 0;

	dtVcopy(curPos, startPos);
	dtVsub(dir, endPos, startPos);
	dtVset(hit->hitNormal, 0, 0, 0);

	dtStatus status = DT_SUCCESS;

	const dtMeshTile* prevTile, *tile, *nextTile;
	const dtPoly* prevPoly, *poly, *nextPoly;
	dtPolyRef curRef;

	curRef = startRef;
	tile = 0;
	poly = 0;
	m_nav->getTileAndPolyByRefUnsafe(curRef, &tile, &poly);
	nextTile = prevTile = tile;
	nextPoly = prevPoly = poly;
	if (prevRef)
		m_nav->getTileAndPolyByRefUnsafe(prevRef, &prevTile, &prevPoly);

	while (curRef)
	{
		
		int nv = 0;
		for (int i = 0; i < (int)poly->vertCount; ++i)
		{
			dtVcopy(&verts[nv*3], &tile->verts[poly->verts[i]*3]);
			nv++;
		}
		
		float tmin, tmax;
		int segMin, segMax;
		if (!dtIntersectSegmentPoly2D(startPos, endPos, verts, nv, tmin, tmax, segMin, segMax))
		{
			hit->pathCount = n;
			return status;
		}

		hit->hitEdgeIndex = segMax;

		if (tmax > hit->t)
			hit->t = tmax;
		
		if (n < hit->maxPath)
			hit->path[n++] = curRef;
		else
			status |= DT_BUFFER_TOO_SMALL;

		if (segMax == -1)
		{
			hit->t = FLT_MAX;
			hit->pathCount = n;
			
			if (options & DT_RAYCAST_USE_COSTS)
				hit->pathCost += filter->getCost(curPos, endPos, prevRef, prevTile, prevPoly, curRef, tile, poly, curRef, tile, poly);
			return status;
		}

		dtPolyRef nextRef = 0;
		
		for (unsigned int i = poly->firstLink; i != DT_NULL_LINK; i = tile->links[i].next)
		{
			const dtLink* link = &tile->links[i];
			
			if ((int)link->edge != segMax)
				continue;
			
			nextTile = 0;
			nextPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(link->ref, &nextTile, &nextPoly);
			
			if (nextPoly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
				continue;
			
			if (!filter->passFilter(link->ref, nextTile, nextPoly))
				continue;
			
			if (link->side == 0xff)
			{
				nextRef = link->ref;
				break;
			}
			
			if (link->bmin == 0 && link->bmax == 255)
			{
				nextRef = link->ref;
				break;
			}
			
			const int v0 = poly->verts[link->edge];
			const int v1 = poly->verts[(link->edge+1) % poly->vertCount];
			const float* left = &tile->verts[v0*3];
			const float* right = &tile->verts[v1*3];
			
			if (link->side == 0 || link->side == 4)
			{
				const float s = 1.0f/255.0f;
				float lmin = left[2] + (right[2] - left[2])*(link->bmin*s);
				float lmax = left[2] + (right[2] - left[2])*(link->bmax*s);
				if (lmin > lmax) dtSwap(lmin, lmax);
				
				float z = startPos[2] + (endPos[2]-startPos[2])*tmax;
				if (z >= lmin && z <= lmax)
				{
					nextRef = link->ref;
					break;
				}
			}
			else if (link->side == 2 || link->side == 6)
			{
				const float s = 1.0f/255.0f;
				float lmin = left[0] + (right[0] - left[0])*(link->bmin*s);
				float lmax = left[0] + (right[0] - left[0])*(link->bmax*s);
				if (lmin > lmax) dtSwap(lmin, lmax);
				
				float x = startPos[0] + (endPos[0]-startPos[0])*tmax;
				if (x >= lmin && x <= lmax)
				{
					nextRef = link->ref;
					break;
				}
			}
		}
		
		if (options & DT_RAYCAST_USE_COSTS)
		{
			dtVcopy(lastPos, curPos);
			dtVmad(curPos, startPos, dir, hit->t);
			float* e1 = &verts[segMax*3];
			float* e2 = &verts[((segMax+1)%nv)*3];
			float eDir[3], diff[3];
			dtVsub(eDir, e2, e1);
			dtVsub(diff, curPos, e1);
			float s = dtSqr(eDir[0]) > dtSqr(eDir[2]) ? diff[0] / eDir[0] : diff[2] / eDir[2];
			curPos[1] = e1[1] + eDir[1] * s;

			hit->pathCost += filter->getCost(lastPos, curPos, prevRef, prevTile, prevPoly, curRef, tile, poly, nextRef, nextTile, nextPoly);
		}

		if (!nextRef)
		{
			
			const int a = segMax;
			const int b = segMax+1 < nv ? segMax+1 : 0;
			const float* va = &verts[a*3];
			const float* vb = &verts[b*3];
			const float dx = vb[0] - va[0];
			const float dz = vb[2] - va[2];
			hit->hitNormal[0] = dz;
			hit->hitNormal[1] = 0;
			hit->hitNormal[2] = -dx;
			dtVnormalize(hit->hitNormal);
			
			hit->pathCount = n;
			return status;
		}

		prevRef = curRef;
		curRef = nextRef;
		prevTile = tile;
		tile = nextTile;
		prevPoly = poly;
		poly = nextPoly;
	}
	
	hit->pathCount = n;
	
	return status;
}

dtStatus dtNavMeshQuery::findPolysAroundCircle(dtPolyRef startRef, const float* centerPos, const float radius,
											   const dtQueryFilter* filter,
											   dtPolyRef* resultRef, dtPolyRef* resultParent, float* resultCost,
											   int* resultCount, const int maxResult) const
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);

	if (!resultCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*resultCount = 0;

	if (!m_nav->isValidPolyRef(startRef) ||
		!centerPos || !dtVisfinite(centerPos) ||
		radius < 0 || !dtMathIsfinite(radius) ||
		!filter || maxResult < 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	m_nodePool->clear();
	m_openList->clear();
	
	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, centerPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	dtStatus status = DT_SUCCESS;
	
	int n = 0;
	
	const float radiusSqr = dtSqr(radius);
	
	while (!m_openList->empty())
	{
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(bestRef, &bestTile, &bestPoly);
		
		dtPolyRef parentRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		if (bestNode->pidx)
			parentRef = m_nodePool->getNodeAtIdx(bestNode->pidx)->id;
		if (parentRef)
			m_nav->getTileAndPolyByRefUnsafe(parentRef, &parentTile, &parentPoly);

		if (n < maxResult)
		{
			if (resultRef)
				resultRef[n] = bestRef;
			if (resultParent)
				resultParent[n] = parentRef;
			if (resultCost)
				resultCost[n] = bestNode->total;
			++n;
		}
		else
		{
			status |= DT_BUFFER_TOO_SMALL;
		}
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			const dtLink* link = &bestTile->links[i];
			dtPolyRef neighbourRef = link->ref;
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);
		
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;
			
			float va[3], vb[3];
			if (!getPortalPoints(bestRef, bestPoly, bestTile, neighbourRef, neighbourPoly, neighbourTile, va, vb))
				continue;
			
			float tseg;
			float distSqr = dtDistancePtSegSqr2D(centerPos, va, vb, tseg);
			if (distSqr > radiusSqr)
				continue;
			
			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef);
			if (!neighbourNode)
			{
				status |= DT_OUT_OF_NODES;
				continue;
			}
				
			if (neighbourNode->flags & DT_NODE_CLOSED)
				continue;
			
			if (neighbourNode->flags == 0)
				dtVlerp(neighbourNode->pos, va, vb, 0.5f);
			
			float cost = filter->getCost(
				bestNode->pos, neighbourNode->pos,
				parentRef, parentTile, parentPoly,
				bestRef, bestTile, bestPoly,
				neighbourRef, neighbourTile, neighbourPoly);

			const float total = bestNode->total + cost;
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->id = neighbourRef;
			neighbourNode->pidx = m_nodePool->getNodeIdx(bestNode);
			neighbourNode->total = total;
			
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags = DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
		}
	}
	
	*resultCount = n;
	
	return status;
}

dtStatus dtNavMeshQuery::findPolysAroundShape(dtPolyRef startRef, const float* verts, const int nverts,
											  const dtQueryFilter* filter,
											  dtPolyRef* resultRef, dtPolyRef* resultParent, float* resultCost,
											  int* resultCount, const int maxResult) const
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);

	if (!resultCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*resultCount = 0;

	if (!m_nav->isValidPolyRef(startRef) ||
		!verts || nverts < 3 ||
		!filter || maxResult < 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	if (!startRef || !m_nav->isValidPolyRef(startRef))
		return DT_FAILURE | DT_INVALID_PARAM;
	
	m_nodePool->clear();
	m_openList->clear();
	
	float centerPos[3] = {0,0,0};
	for (int i = 0; i < nverts; ++i)
		dtVadd(centerPos,centerPos,&verts[i*3]);
	dtVscale(centerPos,centerPos,1.0f/nverts);

	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, centerPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	dtStatus status = DT_SUCCESS;

	int n = 0;
	
	while (!m_openList->empty())
	{
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(bestRef, &bestTile, &bestPoly);
		
		dtPolyRef parentRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		if (bestNode->pidx)
			parentRef = m_nodePool->getNodeAtIdx(bestNode->pidx)->id;
		if (parentRef)
			m_nav->getTileAndPolyByRefUnsafe(parentRef, &parentTile, &parentPoly);

		if (n < maxResult)
		{
			if (resultRef)
				resultRef[n] = bestRef;
			if (resultParent)
				resultParent[n] = parentRef;
			if (resultCost)
				resultCost[n] = bestNode->total;

			++n;
		}
		else
		{
			status |= DT_BUFFER_TOO_SMALL;
		}
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			const dtLink* link = &bestTile->links[i];
			dtPolyRef neighbourRef = link->ref;
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);
			
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;
			
			float va[3], vb[3];
			if (!getPortalPoints(bestRef, bestPoly, bestTile, neighbourRef, neighbourPoly, neighbourTile, va, vb))
				continue;
			
			float tmin, tmax;
			int segMin, segMax;
			if (!dtIntersectSegmentPoly2D(va, vb, verts, nverts, tmin, tmax, segMin, segMax))
				continue;
			if (tmin > 1.0f || tmax < 0.0f)
				continue;
			
			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef);
			if (!neighbourNode)
			{
				status |= DT_OUT_OF_NODES;
				continue;
			}
			
			if (neighbourNode->flags & DT_NODE_CLOSED)
				continue;
			
			if (neighbourNode->flags == 0)
				dtVlerp(neighbourNode->pos, va, vb, 0.5f);
			
			float cost = filter->getCost(
				bestNode->pos, neighbourNode->pos,
				parentRef, parentTile, parentPoly,
				bestRef, bestTile, bestPoly,
				neighbourRef, neighbourTile, neighbourPoly);

			const float total = bestNode->total + cost;
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->id = neighbourRef;
			neighbourNode->pidx = m_nodePool->getNodeIdx(bestNode);
			neighbourNode->total = total;
			
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags = DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
		}
	}
	
	*resultCount = n;
	
	return status;
}

dtStatus dtNavMeshQuery::getPathFromDijkstraSearch(dtPolyRef endRef, dtPolyRef* path, int* pathCount, int maxPath) const
{
	if (!m_nav->isValidPolyRef(endRef) || !path || !pathCount || maxPath < 0)
		return DT_FAILURE | DT_INVALID_PARAM;

	*pathCount = 0;

	dtNode* endNode;
	if (m_nodePool->findNodes(endRef, &endNode, 1) != 1 ||
		(endNode->flags & DT_NODE_CLOSED) == 0)
		return DT_FAILURE | DT_INVALID_PARAM;

	return getPathToNode(endNode, path, pathCount, maxPath);
}

dtStatus dtNavMeshQuery::findLocalNeighbourhood(dtPolyRef startRef, const float* centerPos, const float radius,
												const dtQueryFilter* filter,
												dtPolyRef* resultRef, dtPolyRef* resultParent,
												int* resultCount, const int maxResult) const
{
	dtAssert(m_nav);
	dtAssert(m_tinyNodePool);

	if (!resultCount)
		return DT_FAILURE | DT_INVALID_PARAM;

	*resultCount = 0;

	if (!m_nav->isValidPolyRef(startRef) ||
		!centerPos || !dtVisfinite(centerPos) ||
		radius < 0 || !dtMathIsfinite(radius) ||
		!filter || maxResult < 0)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}

	static const int MAX_STACK = 48;
	dtNode* stack[MAX_STACK];
	int nstack = 0;
	
	m_tinyNodePool->clear();
	
	dtNode* startNode = m_tinyNodePool->getNode(startRef);
	startNode->pidx = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_CLOSED;
	stack[nstack++] = startNode;
	
	const float radiusSqr = dtSqr(radius);
	
	float pa[DT_VERTS_PER_POLYGON*3];
	float pb[DT_VERTS_PER_POLYGON*3];
	
	dtStatus status = DT_SUCCESS;
	
	int n = 0;
	if (n < maxResult)
	{
		resultRef[n] = startNode->id;
		if (resultParent)
			resultParent[n] = 0;
		++n;
	}
	else
	{
		status |= DT_BUFFER_TOO_SMALL;
	}
	
	while (nstack)
	{
		dtNode* curNode = stack[0];
		for (int i = 0; i < nstack-1; ++i)
			stack[i] = stack[i+1];
		nstack--;
		
		const dtPolyRef curRef = curNode->id;
		const dtMeshTile* curTile = 0;
		const dtPoly* curPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(curRef, &curTile, &curPoly);
		
		for (unsigned int i = curPoly->firstLink; i != DT_NULL_LINK; i = curTile->links[i].next)
		{
			const dtLink* link = &curTile->links[i];
			dtPolyRef neighbourRef = link->ref;
			if (!neighbourRef)
				continue;
			
			dtNode* neighbourNode = m_tinyNodePool->getNode(neighbourRef);
			if (!neighbourNode)
				continue;
			if (neighbourNode->flags & DT_NODE_CLOSED)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);
			
			if (neighbourPoly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
				continue;
			
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;
			
			float va[3], vb[3];
			if (!getPortalPoints(curRef, curPoly, curTile, neighbourRef, neighbourPoly, neighbourTile, va, vb))
				continue;
			
			float tseg;
			float distSqr = dtDistancePtSegSqr2D(centerPos, va, vb, tseg);
			if (distSqr > radiusSqr)
				continue;
			
			neighbourNode->flags |= DT_NODE_CLOSED;
			neighbourNode->pidx = m_tinyNodePool->getNodeIdx(curNode);
			
			const int npa = neighbourPoly->vertCount;
			for (int k = 0; k < npa; ++k)
				dtVcopy(&pa[k*3], &neighbourTile->verts[neighbourPoly->verts[k]*3]);
			
			bool overlap = false;
			for (int j = 0; j < n; ++j)
			{
				dtPolyRef pastRef = resultRef[j];
				
				bool connected = false;
				for (unsigned int k = curPoly->firstLink; k != DT_NULL_LINK; k = curTile->links[k].next)
				{
					if (curTile->links[k].ref == pastRef)
					{
						connected = true;
						break;
					}
				}
				if (connected)
					continue;
				
				const dtMeshTile* pastTile = 0;
				const dtPoly* pastPoly = 0;
				m_nav->getTileAndPolyByRefUnsafe(pastRef, &pastTile, &pastPoly);
				
				const int npb = pastPoly->vertCount;
				for (int k = 0; k < npb; ++k)
					dtVcopy(&pb[k*3], &pastTile->verts[pastPoly->verts[k]*3]);
				
				if (dtOverlapPolyPoly2D(pa,npa, pb,npb))
				{
					overlap = true;
					break;
				}
			}
			if (overlap)
				continue;
			
			if (n < maxResult)
			{
				resultRef[n] = neighbourRef;
				if (resultParent)
					resultParent[n] = curRef;
				++n;
			}
			else
			{
				status |= DT_BUFFER_TOO_SMALL;
			}
			
			if (nstack < MAX_STACK)
			{
				stack[nstack++] = neighbourNode;
			}
		}
	}
	
	*resultCount = n;
	
	return status;
}

struct dtSegInterval
{
	dtPolyRef ref;
	short tmin, tmax;
};

static void insertInterval(dtSegInterval* ints, int& nints, const int maxInts,
						   const short tmin, const short tmax, const dtPolyRef ref)
{
	if (nints+1 > maxInts) return;
	int idx = 0;
	while (idx < nints)
	{
		if (tmax <= ints[idx].tmin)
			break;
		idx++;
	}
	if (nints-idx)
		memmove(ints+idx+1, ints+idx, sizeof(dtSegInterval)*(nints-idx));
	ints[idx].ref = ref;
	ints[idx].tmin = tmin;
	ints[idx].tmax = tmax;
	nints++;
}

dtStatus dtNavMeshQuery::getPolyWallSegments(dtPolyRef ref, const dtQueryFilter* filter,
											 float* segmentVerts, dtPolyRef* segmentRefs, int* segmentCount,
											 const int maxSegments) const
{
	dtAssert(m_nav);

	if (!segmentCount)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	*segmentCount = 0;

	const dtMeshTile* tile = 0;
	const dtPoly* poly = 0;
	if (dtStatusFailed(m_nav->getTileAndPolyByRef(ref, &tile, &poly)))
		return DT_FAILURE | DT_INVALID_PARAM;

	if (!filter || !segmentVerts || maxSegments < 0)
		return DT_FAILURE | DT_INVALID_PARAM;
	
	int n = 0;
	static const int MAX_INTERVAL = 16;
	dtSegInterval ints[MAX_INTERVAL];
	int nints;
	
	const bool storePortals = segmentRefs != 0;
	
	dtStatus status = DT_SUCCESS;
	
	for (int i = 0, j = (int)poly->vertCount-1; i < (int)poly->vertCount; j = i++)
	{
		nints = 0;
		if (poly->neis[j] & DT_EXT_LINK)
		{
			for (unsigned int k = poly->firstLink; k != DT_NULL_LINK; k = tile->links[k].next)
			{
				const dtLink* link = &tile->links[k];
				if (link->edge == j)
				{
					if (link->ref != 0)
					{
						const dtMeshTile* neiTile = 0;
						const dtPoly* neiPoly = 0;
						m_nav->getTileAndPolyByRefUnsafe(link->ref, &neiTile, &neiPoly);
						if (filter->passFilter(link->ref, neiTile, neiPoly))
						{
							insertInterval(ints, nints, MAX_INTERVAL, link->bmin, link->bmax, link->ref);
						}
					}
				}
			}
		}
		else
		{
			dtPolyRef neiRef = 0;
			if (poly->neis[j])
			{
				const unsigned int idx = (unsigned int)(poly->neis[j]-1);
				neiRef = m_nav->getPolyRefBase(tile) | idx;
				if (!filter->passFilter(neiRef, tile, &tile->polys[idx]))
					neiRef = 0;
			}

			if (neiRef != 0 && !storePortals)
				continue;
			
			if (n < maxSegments)
			{
				const float* vj = &tile->verts[poly->verts[j]*3];
				const float* vi = &tile->verts[poly->verts[i]*3];
				float* seg = &segmentVerts[n*6];
				dtVcopy(seg+0, vj);
				dtVcopy(seg+3, vi);
				if (segmentRefs)
					segmentRefs[n] = neiRef;
				n++;
			}
			else
			{
				status |= DT_BUFFER_TOO_SMALL;
			}
			
			continue;
		}
		
		insertInterval(ints, nints, MAX_INTERVAL, -1, 0, 0);
		insertInterval(ints, nints, MAX_INTERVAL, 255, 256, 0);
		
		const float* vj = &tile->verts[poly->verts[j]*3];
		const float* vi = &tile->verts[poly->verts[i]*3];
		for (int k = 1; k < nints; ++k)
		{
			if (storePortals && ints[k].ref)
			{
				const float tmin = ints[k].tmin/255.0f; 
				const float tmax = ints[k].tmax/255.0f; 
				if (n < maxSegments)
				{
					float* seg = &segmentVerts[n*6];
					dtVlerp(seg+0, vj,vi, tmin);
					dtVlerp(seg+3, vj,vi, tmax);
					if (segmentRefs)
						segmentRefs[n] = ints[k].ref;
					n++;
				}
				else
				{
					status |= DT_BUFFER_TOO_SMALL;
				}
			}

			const int imin = ints[k-1].tmax;
			const int imax = ints[k].tmin;
			if (imin != imax)
			{
				const float tmin = imin/255.0f; 
				const float tmax = imax/255.0f; 
				if (n < maxSegments)
				{
					float* seg = &segmentVerts[n*6];
					dtVlerp(seg+0, vj,vi, tmin);
					dtVlerp(seg+3, vj,vi, tmax);
					if (segmentRefs)
						segmentRefs[n] = 0;
					n++;
				}
				else
				{
					status |= DT_BUFFER_TOO_SMALL;
				}
			}
		}
	}
	
	*segmentCount = n;
	
	return status;
}

dtStatus dtNavMeshQuery::findDistanceToWall(dtPolyRef startRef, const float* centerPos, const float maxRadius,
											const dtQueryFilter* filter,
											float* hitDist, float* hitPos, float* hitNormal) const
{
	dtAssert(m_nav);
	dtAssert(m_nodePool);
	dtAssert(m_openList);
	
	if (!m_nav->isValidPolyRef(startRef) ||
		!centerPos || !dtVisfinite(centerPos) ||
		maxRadius < 0 || !dtMathIsfinite(maxRadius) ||
		!filter || !hitDist || !hitPos || !hitNormal)
	{
		return DT_FAILURE | DT_INVALID_PARAM;
	}
	
	m_nodePool->clear();
	m_openList->clear();
	
	dtNode* startNode = m_nodePool->getNode(startRef);
	dtVcopy(startNode->pos, centerPos);
	startNode->pidx = 0;
	startNode->cost = 0;
	startNode->total = 0;
	startNode->id = startRef;
	startNode->flags = DT_NODE_OPEN;
	m_openList->push(startNode);
	
	float radiusSqr = dtSqr(maxRadius);
	
	dtStatus status = DT_SUCCESS;
	
	while (!m_openList->empty())
	{
		dtNode* bestNode = m_openList->pop();
		bestNode->flags &= ~DT_NODE_OPEN;
		bestNode->flags |= DT_NODE_CLOSED;
		
		const dtPolyRef bestRef = bestNode->id;
		const dtMeshTile* bestTile = 0;
		const dtPoly* bestPoly = 0;
		m_nav->getTileAndPolyByRefUnsafe(bestRef, &bestTile, &bestPoly);
		
		dtPolyRef parentRef = 0;
		const dtMeshTile* parentTile = 0;
		const dtPoly* parentPoly = 0;
		if (bestNode->pidx)
			parentRef = m_nodePool->getNodeAtIdx(bestNode->pidx)->id;
		if (parentRef)
			m_nav->getTileAndPolyByRefUnsafe(parentRef, &parentTile, &parentPoly);
		
		for (int i = 0, j = (int)bestPoly->vertCount-1; i < (int)bestPoly->vertCount; j = i++)
		{
			if (bestPoly->neis[j] & DT_EXT_LINK)
			{
				bool solid = true;
				for (unsigned int k = bestPoly->firstLink; k != DT_NULL_LINK; k = bestTile->links[k].next)
				{
					const dtLink* link = &bestTile->links[k];
					if (link->edge == j)
					{
						if (link->ref != 0)
						{
							const dtMeshTile* neiTile = 0;
							const dtPoly* neiPoly = 0;
							m_nav->getTileAndPolyByRefUnsafe(link->ref, &neiTile, &neiPoly);
							if (filter->passFilter(link->ref, neiTile, neiPoly))
								solid = false;
						}
						break;
					}
				}
				if (!solid) continue;
			}
			else if (bestPoly->neis[j])
			{
				const unsigned int idx = (unsigned int)(bestPoly->neis[j]-1);
				const dtPolyRef ref = m_nav->getPolyRefBase(bestTile) | idx;
				if (filter->passFilter(ref, bestTile, &bestTile->polys[idx]))
					continue;
			}
			
			const float* vj = &bestTile->verts[bestPoly->verts[j]*3];
			const float* vi = &bestTile->verts[bestPoly->verts[i]*3];
			float tseg;
			float distSqr = dtDistancePtSegSqr2D(centerPos, vj, vi, tseg);
			
			if (distSqr > radiusSqr)
				continue;
			
			radiusSqr = distSqr;
			hitPos[0] = vj[0] + (vi[0] - vj[0])*tseg;
			hitPos[1] = vj[1] + (vi[1] - vj[1])*tseg;
			hitPos[2] = vj[2] + (vi[2] - vj[2])*tseg;
		}
		
		for (unsigned int i = bestPoly->firstLink; i != DT_NULL_LINK; i = bestTile->links[i].next)
		{
			const dtLink* link = &bestTile->links[i];
			dtPolyRef neighbourRef = link->ref;
			if (!neighbourRef || neighbourRef == parentRef)
				continue;
			
			const dtMeshTile* neighbourTile = 0;
			const dtPoly* neighbourPoly = 0;
			m_nav->getTileAndPolyByRefUnsafe(neighbourRef, &neighbourTile, &neighbourPoly);
			
			if (neighbourPoly->getType() == DT_POLYTYPE_OFFMESH_CONNECTION)
				continue;
			
			const float* va = &bestTile->verts[bestPoly->verts[link->edge]*3];
			const float* vb = &bestTile->verts[bestPoly->verts[(link->edge+1) % bestPoly->vertCount]*3];
			float tseg;
			float distSqr = dtDistancePtSegSqr2D(centerPos, va, vb, tseg);
			
			if (distSqr > radiusSqr)
				continue;
			
			if (!filter->passFilter(neighbourRef, neighbourTile, neighbourPoly))
				continue;

			dtNode* neighbourNode = m_nodePool->getNode(neighbourRef);
			if (!neighbourNode)
			{
				status |= DT_OUT_OF_NODES;
				continue;
			}
			
			if (neighbourNode->flags & DT_NODE_CLOSED)
				continue;
			
			if (neighbourNode->flags == 0)
			{
				getEdgeMidPoint(bestRef, bestPoly, bestTile,
								neighbourRef, neighbourPoly, neighbourTile, neighbourNode->pos);
			}
			
			const float total = bestNode->total + dtVdist(bestNode->pos, neighbourNode->pos);
			
			if ((neighbourNode->flags & DT_NODE_OPEN) && total >= neighbourNode->total)
				continue;
			
			neighbourNode->id = neighbourRef;
			neighbourNode->flags = (neighbourNode->flags & ~DT_NODE_CLOSED);
			neighbourNode->pidx = m_nodePool->getNodeIdx(bestNode);
			neighbourNode->total = total;
				
			if (neighbourNode->flags & DT_NODE_OPEN)
			{
				m_openList->modify(neighbourNode);
			}
			else
			{
				neighbourNode->flags |= DT_NODE_OPEN;
				m_openList->push(neighbourNode);
			}
		}
	}
	
	dtVsub(hitNormal, centerPos, hitPos);
	dtVnormalize(hitNormal);
	
	*hitDist = dtMathSqrtf(radiusSqr);
	
	return status;
}

bool dtNavMeshQuery::isValidPolyRef(dtPolyRef ref, const dtQueryFilter* filter) const
{
	const dtMeshTile* tile = 0;
	const dtPoly* poly = 0;
	dtStatus status = m_nav->getTileAndPolyByRef(ref, &tile, &poly);
	if (dtStatusFailed(status))
		return false;
	if (!filter->passFilter(ref, tile, poly))
		return false;
	return true;
}

bool dtNavMeshQuery::isInClosedList(dtPolyRef ref) const
{
	if (!m_nodePool) return false;
	
	dtNode* nodes[DT_MAX_STATES_PER_NODE];
	int n= m_nodePool->findNodes(ref, nodes, DT_MAX_STATES_PER_NODE);

	for (int i=0; i<n; i++)
	{
		if (nodes[i]->flags & DT_NODE_CLOSED)
			return true;
	}		

	return false;
}
