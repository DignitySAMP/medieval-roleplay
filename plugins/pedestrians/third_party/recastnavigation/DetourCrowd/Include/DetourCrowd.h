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

#ifndef DETOURCROWD_H
#define DETOURCROWD_H

#include "DetourNavMeshQuery.h"
#include "DetourObstacleAvoidance.h"
#include "DetourLocalBoundary.h"
#include "DetourPathCorridor.h"
#include "DetourProximityGrid.h"
#include "DetourPathQueue.h"

static const int DT_CROWDAGENT_MAX_NEIGHBOURS = 6;

static const int DT_CROWDAGENT_MAX_CORNERS = 4;

static const int DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS = 8;

static const int DT_CROWD_MAX_QUERY_FILTER_TYPE = 16;

struct dtCrowdNeighbour
{
	int idx;
	float dist;
};

enum CrowdAgentState
{
	DT_CROWDAGENT_STATE_INVALID,
	DT_CROWDAGENT_STATE_WALKING,
	DT_CROWDAGENT_STATE_OFFMESH
};

struct dtCrowdAgentParams
{
	float radius;
	float height;
	float maxAcceleration;
	float maxSpeed;

	float collisionQueryRange;

	float pathOptimizationRange;

	float separationWeight;

	unsigned char updateFlags;

	unsigned char obstacleAvoidanceType;	

	unsigned char queryFilterType;

	void* userData;
};

enum MoveRequestState
{
	DT_CROWDAGENT_TARGET_NONE = 0,
	DT_CROWDAGENT_TARGET_FAILED,
	DT_CROWDAGENT_TARGET_VALID,
	DT_CROWDAGENT_TARGET_REQUESTING,
	DT_CROWDAGENT_TARGET_WAITING_FOR_QUEUE,
	DT_CROWDAGENT_TARGET_WAITING_FOR_PATH,
	DT_CROWDAGENT_TARGET_VELOCITY
};

struct dtCrowdAgent
{
	bool active;

	unsigned char state;

	bool partial;

	dtPathCorridor corridor;

	dtLocalBoundary boundary;
	
	float topologyOptTime;
	
	dtCrowdNeighbour neis[DT_CROWDAGENT_MAX_NEIGHBOURS];

	int nneis;
	
	float desiredSpeed;

	float npos[3];
	float disp[3];
	float dvel[3];
	float nvel[3];
	float vel[3];

	dtCrowdAgentParams params;

	float cornerVerts[DT_CROWDAGENT_MAX_CORNERS*3];

	unsigned char cornerFlags[DT_CROWDAGENT_MAX_CORNERS];

	dtPolyRef cornerPolys[DT_CROWDAGENT_MAX_CORNERS];

	int ncorners;
	
	unsigned char targetState;
	dtPolyRef targetRef;
	float targetPos[3];
	dtPathQueueRef targetPathqRef;
	bool targetReplan;
	float targetReplanTime;
};

struct dtCrowdAgentAnimation
{
	bool active;
	float initPos[3], startPos[3], endPos[3];
	dtPolyRef polyRef;
	float t, tmax;
};

enum UpdateFlags
{
	DT_CROWD_ANTICIPATE_TURNS = 1,
	DT_CROWD_OBSTACLE_AVOIDANCE = 2,
	DT_CROWD_SEPARATION = 4,
	DT_CROWD_OPTIMIZE_VIS = 8,
	DT_CROWD_OPTIMIZE_TOPO = 16
};

struct dtCrowdAgentDebugInfo
{
	int idx;
	float optStart[3], optEnd[3];
	dtObstacleAvoidanceDebugData* vod;
};

class dtCrowd
{
	int m_maxAgents;
	dtCrowdAgent* m_agents;
	dtCrowdAgent** m_activeAgents;
	dtCrowdAgentAnimation* m_agentAnims;
	
	dtPathQueue m_pathq;

	dtObstacleAvoidanceParams m_obstacleQueryParams[DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS];
	dtObstacleAvoidanceQuery* m_obstacleQuery;
	
	dtProximityGrid* m_grid;
	
	dtPolyRef* m_pathResult;
	int m_maxPathResult;
	
	float m_agentPlacementHalfExtents[3];

	dtQueryFilter m_filters[DT_CROWD_MAX_QUERY_FILTER_TYPE];

	float m_maxAgentRadius;

	int m_velocitySampleCount;

	dtNavMeshQuery* m_navquery;

	void updateTopologyOptimization(dtCrowdAgent** agents, const int nagents, const float dt);
	void updateMoveRequest(const float dt);
	void checkPathValidity(dtCrowdAgent** agents, const int nagents, const float dt);

	inline int getAgentIndex(const dtCrowdAgent* agent) const  { return (int)(agent - m_agents); }

	bool requestMoveTargetReplan(const int idx, dtPolyRef ref, const float* pos);

	void purge();
	
public:
	dtCrowd();
	~dtCrowd();
	
	bool init(const int maxAgents, const float maxAgentRadius, dtNavMesh* nav);
	
	void setObstacleAvoidanceParams(const int idx, const dtObstacleAvoidanceParams* params);

	const dtObstacleAvoidanceParams* getObstacleAvoidanceParams(const int idx) const;
	
	const dtCrowdAgent* getAgent(const int idx);

	dtCrowdAgent* getEditableAgent(const int idx);

	int getAgentCount() const;
	
	int addAgent(const float* pos, const dtCrowdAgentParams* params);

	void updateAgentParameters(const int idx, const dtCrowdAgentParams* params);

	void removeAgent(const int idx);
	
	bool requestMoveTarget(const int idx, dtPolyRef ref, const float* pos);

	bool requestMoveVelocity(const int idx, const float* vel);

	bool resetMoveTarget(const int idx);

	int getActiveAgents(dtCrowdAgent** agents, const int maxAgents);

	void update(const float dt, dtCrowdAgentDebugInfo* debug);
	
	inline const dtQueryFilter* getFilter(const int i) const { return (i >= 0 && i < DT_CROWD_MAX_QUERY_FILTER_TYPE) ? &m_filters[i] : 0; }
	
	inline dtQueryFilter* getEditableFilter(const int i) { return (i >= 0 && i < DT_CROWD_MAX_QUERY_FILTER_TYPE) ? &m_filters[i] : 0; }

	const float* getQueryHalfExtents() const { return m_agentPlacementHalfExtents; }

	const float* getQueryExtents() const { return m_agentPlacementHalfExtents; }
	
	inline int getVelocitySampleCount() const { return m_velocitySampleCount; }
	
	const dtProximityGrid* getGrid() const { return m_grid; }

	const dtPathQueue* getPathQueue() const { return &m_pathq; }

	const dtNavMeshQuery* getNavMeshQuery() const { return m_navquery; }

private:
	dtCrowd(const dtCrowd&);
	dtCrowd& operator=(const dtCrowd&);
};

dtCrowd* dtAllocCrowd();

void dtFreeCrowd(dtCrowd* ptr);

#endif
