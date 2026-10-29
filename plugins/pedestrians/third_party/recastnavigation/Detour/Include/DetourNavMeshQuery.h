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

#ifndef DETOURNAVMESHQUERY_H
#define DETOURNAVMESHQUERY_H

#include "DetourNavMesh.h"
#include "DetourStatus.h"

class dtQueryFilter
{
	float m_areaCost[DT_MAX_AREAS];
	unsigned short m_includeFlags;
	unsigned short m_excludeFlags;
	
public:
	dtQueryFilter();
	
#ifdef DT_VIRTUAL_QUERYFILTER
	virtual ~dtQueryFilter() { }
#endif
	
#ifdef DT_VIRTUAL_QUERYFILTER
	virtual bool passFilter(const dtPolyRef ref,
							const dtMeshTile* tile,
							const dtPoly* poly) const;
#else
	bool passFilter(const dtPolyRef ref,
					const dtMeshTile* tile,
					const dtPoly* poly) const;
#endif

#ifdef DT_VIRTUAL_QUERYFILTER
	virtual float getCost(const float* pa, const float* pb,
						  const dtPolyRef prevRef, const dtMeshTile* prevTile, const dtPoly* prevPoly,
						  const dtPolyRef curRef, const dtMeshTile* curTile, const dtPoly* curPoly,
						  const dtPolyRef nextRef, const dtMeshTile* nextTile, const dtPoly* nextPoly) const;
#else
	float getCost(const float* pa, const float* pb,
				  const dtPolyRef prevRef, const dtMeshTile* prevTile, const dtPoly* prevPoly,
				  const dtPolyRef curRef, const dtMeshTile* curTile, const dtPoly* curPoly,
				  const dtPolyRef nextRef, const dtMeshTile* nextTile, const dtPoly* nextPoly) const;
#endif

	inline float getAreaCost(const int i) const { return m_areaCost[i]; }

	inline void setAreaCost(const int i, const float cost) { m_areaCost[i] = cost; } 

	inline unsigned short getIncludeFlags() const { return m_includeFlags; }

	inline void setIncludeFlags(const unsigned short flags) { m_includeFlags = flags; }

	inline unsigned short getExcludeFlags() const { return m_excludeFlags; }

	inline void setExcludeFlags(const unsigned short flags) { m_excludeFlags = flags; }	

};

struct dtRaycastHit
{
	float t; 
	
	float hitNormal[3];

	int hitEdgeIndex;
	
	dtPolyRef* path;
	
	int pathCount;

	int maxPath;

	float pathCost;
};

class dtPolyQuery
{
public:
	virtual ~dtPolyQuery();

	virtual void process(const dtMeshTile* tile, dtPoly** polys, dtPolyRef* refs, int count) = 0;
};

class dtNavMeshQuery
{
public:
	dtNavMeshQuery();
	~dtNavMeshQuery();
	
	dtStatus init(const dtNavMesh* nav, const int maxNodes);
	
	dtStatus findPath(dtPolyRef startRef, dtPolyRef endRef,
					  const float* startPos, const float* endPos,
					  const dtQueryFilter* filter,
					  dtPolyRef* path, int* pathCount, const int maxPath) const;

	dtStatus findStraightPath(const float* startPos, const float* endPos,
							  const dtPolyRef* path, const int pathSize,
							  float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
							  int* straightPathCount, const int maxStraightPath, const int options = 0) const;

	dtStatus initSlicedFindPath(dtPolyRef startRef, dtPolyRef endRef,
								const float* startPos, const float* endPos,
								const dtQueryFilter* filter, const unsigned int options = 0);

	dtStatus updateSlicedFindPath(const int maxIter, int* doneIters);

	dtStatus finalizeSlicedFindPath(dtPolyRef* path, int* pathCount, const int maxPath);
	
	dtStatus finalizeSlicedFindPathPartial(const dtPolyRef* existing, const int existingSize,
										   dtPolyRef* path, int* pathCount, const int maxPath);

	dtStatus findPolysAroundCircle(dtPolyRef startRef, const float* centerPos, const float radius,
								   const dtQueryFilter* filter,
								   dtPolyRef* resultRef, dtPolyRef* resultParent, float* resultCost,
								   int* resultCount, const int maxResult) const;
	
	dtStatus findPolysAroundShape(dtPolyRef startRef, const float* verts, const int nverts,
								  const dtQueryFilter* filter,
								  dtPolyRef* resultRef, dtPolyRef* resultParent, float* resultCost,
								  int* resultCount, const int maxResult) const;
	
	dtStatus getPathFromDijkstraSearch(dtPolyRef endRef, dtPolyRef* path, int* pathCount, int maxPath) const;

	dtStatus findNearestPoly(const float* center, const float* halfExtents,
							 const dtQueryFilter* filter,
							 dtPolyRef* nearestRef, float* nearestPt) const;

	dtStatus findNearestPoly(const float* center, const float* halfExtents,
							 const dtQueryFilter* filter,
							 dtPolyRef* nearestRef, float* nearestPt, bool* isOverPoly) const;
	
	dtStatus queryPolygons(const float* center, const float* halfExtents,
						   const dtQueryFilter* filter,
						   dtPolyRef* polys, int* polyCount, const int maxPolys) const;

	dtStatus queryPolygons(const float* center, const float* halfExtents,
						   const dtQueryFilter* filter, dtPolyQuery* query) const;

	dtStatus findLocalNeighbourhood(dtPolyRef startRef, const float* centerPos, const float radius,
									const dtQueryFilter* filter,
									dtPolyRef* resultRef, dtPolyRef* resultParent,
									int* resultCount, const int maxResult) const;

	dtStatus moveAlongSurface(dtPolyRef startRef, const float* startPos, const float* endPos,
							  const dtQueryFilter* filter,
							  float* resultPos, dtPolyRef* visited, int* visitedCount, const int maxVisitedSize) const;
	
	dtStatus raycast(dtPolyRef startRef, const float* startPos, const float* endPos,
					 const dtQueryFilter* filter,
					 float* t, float* hitNormal, dtPolyRef* path, int* pathCount, const int maxPath) const;
	
	dtStatus raycast(dtPolyRef startRef, const float* startPos, const float* endPos,
					 const dtQueryFilter* filter, const unsigned int options,
					 dtRaycastHit* hit, dtPolyRef prevRef = 0) const;

	dtStatus findDistanceToWall(dtPolyRef startRef, const float* centerPos, const float maxRadius,
								const dtQueryFilter* filter,
								float* hitDist, float* hitPos, float* hitNormal) const;
	
	dtStatus getPolyWallSegments(dtPolyRef ref, const dtQueryFilter* filter,
								 float* segmentVerts, dtPolyRef* segmentRefs, int* segmentCount,
								 const int maxSegments) const;

	dtStatus findRandomPoint(const dtQueryFilter* filter, float (*frand)(),
							 dtPolyRef* randomRef, float* randomPt) const;

	dtStatus findRandomPointAroundCircle(dtPolyRef startRef, const float* centerPos, const float maxRadius,
										 const dtQueryFilter* filter, float (*frand)(),
										 dtPolyRef* randomRef, float* randomPt) const;
	
	dtStatus closestPointOnPoly(dtPolyRef ref, const float* pos, float* closest, bool* posOverPoly) const;
	
	dtStatus closestPointOnPolyBoundary(dtPolyRef ref, const float* pos, float* closest) const;
	
	dtStatus getPolyHeight(dtPolyRef ref, const float* pos, float* height) const;

	bool isValidPolyRef(dtPolyRef ref, const dtQueryFilter* filter) const;

	bool isInClosedList(dtPolyRef ref) const;
	
	class dtNodePool* getNodePool() const { return m_nodePool; }
	
	const dtNavMesh* getAttachedNavMesh() const { return m_nav; }

private:
	dtNavMeshQuery(const dtNavMeshQuery&);
	dtNavMeshQuery& operator=(const dtNavMeshQuery&);
	
	void queryPolygonsInTile(const dtMeshTile* tile, const float* qmin, const float* qmax,
							 const dtQueryFilter* filter, dtPolyQuery* query) const;

	dtStatus getPortalPoints(dtPolyRef from, dtPolyRef to, float* left, float* right,
							 unsigned char& fromType, unsigned char& toType) const;
	dtStatus getPortalPoints(dtPolyRef from, const dtPoly* fromPoly, const dtMeshTile* fromTile,
							 dtPolyRef to, const dtPoly* toPoly, const dtMeshTile* toTile,
							 float* left, float* right) const;
	
	dtStatus getEdgeMidPoint(dtPolyRef from, dtPolyRef to, float* mid) const;
	dtStatus getEdgeMidPoint(dtPolyRef from, const dtPoly* fromPoly, const dtMeshTile* fromTile,
							 dtPolyRef to, const dtPoly* toPoly, const dtMeshTile* toTile,
							 float* mid) const;
	
	dtStatus appendVertex(const float* pos, const unsigned char flags, const dtPolyRef ref,
						  float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
						  int* straightPathCount, const int maxStraightPath) const;

	dtStatus appendPortals(const int startIdx, const int endIdx, const float* endPos, const dtPolyRef* path,
						   float* straightPath, unsigned char* straightPathFlags, dtPolyRef* straightPathRefs,
						   int* straightPathCount, const int maxStraightPath, const int options) const;

	dtStatus getPathToNode(struct dtNode* endNode, dtPolyRef* path, int* pathCount, int maxPath) const;
	
	const dtNavMesh* m_nav;

	struct dtQueryData
	{
		dtStatus status;
		struct dtNode* lastBestNode;
		float lastBestNodeCost;
		dtPolyRef startRef, endRef;
		float startPos[3], endPos[3];
		const dtQueryFilter* filter;
		unsigned int options;
		float raycastLimitSqr;
	};
	dtQueryData m_query;

	class dtNodePool* m_tinyNodePool;
	class dtNodePool* m_nodePool;
	class dtNodeQueue* m_openList;
};

dtNavMeshQuery* dtAllocNavMeshQuery();

void dtFreeNavMeshQuery(dtNavMeshQuery* query);

#endif
