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

#include <string.h>
#include <float.h>
#include <stdlib.h>
#include <new>
#include "DetourCrowd.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshQuery.h"
#include "DetourObstacleAvoidance.h"
#include "DetourCommon.h"
#include "DetourMath.h"
#include "DetourAssert.h"
#include "DetourAlloc.h"

dtCrowd* dtAllocCrowd()
{
	void* mem = dtAlloc(sizeof(dtCrowd), DT_ALLOC_PERM);
	if (!mem) return 0;
	return new(mem) dtCrowd;
}

void dtFreeCrowd(dtCrowd* ptr)
{
	if (!ptr) return;
	ptr->~dtCrowd();
	dtFree(ptr);
}

static const int MAX_ITERS_PER_UPDATE = 100;

static const int MAX_PATHQUEUE_NODES = 4096;
static const int MAX_COMMON_NODES = 512;

inline float tween(const float t, const float t0, const float t1)
{
	return dtClamp((t-t0) / (t1-t0), 0.0f, 1.0f);
}

static void integrate(dtCrowdAgent* ag, const float dt)
{
	const float maxDelta = ag->params.maxAcceleration * dt;
	float dv[3];
	dtVsub(dv, ag->nvel, ag->vel);
	float ds = dtVlen(dv);
	if (ds > maxDelta)
		dtVscale(dv, dv, maxDelta/ds);
	dtVadd(ag->vel, ag->vel, dv);
	
	if (dtVlen(ag->vel) > 0.0001f)
		dtVmad(ag->npos, ag->npos, ag->vel, dt);
	else
		dtVset(ag->vel,0,0,0);
}

static bool overOffmeshConnection(const dtCrowdAgent* ag, const float radius)
{
	if (!ag->ncorners)
		return false;
	
	const bool offMeshConnection = (ag->cornerFlags[ag->ncorners-1] & DT_STRAIGHTPATH_OFFMESH_CONNECTION) ? true : false;
	if (offMeshConnection)
	{
		const float distSq = dtVdist2DSqr(ag->npos, &ag->cornerVerts[(ag->ncorners-1)*3]);
		if (distSq < radius*radius)
			return true;
	}
	
	return false;
}

static float getDistanceToGoal(const dtCrowdAgent* ag, const float range)
{
	if (!ag->ncorners)
		return range;
	
	const bool endOfPath = (ag->cornerFlags[ag->ncorners-1] & DT_STRAIGHTPATH_END) ? true : false;
	if (endOfPath)
		return dtMin(dtVdist2D(ag->npos, &ag->cornerVerts[(ag->ncorners-1)*3]), range);
	
	return range;
}

static void calcSmoothSteerDirection(const dtCrowdAgent* ag, float* dir)
{
	if (!ag->ncorners)
	{
		dtVset(dir, 0,0,0);
		return;
	}
	
	const int ip0 = 0;
	const int ip1 = dtMin(1, ag->ncorners-1);
	const float* p0 = &ag->cornerVerts[ip0*3];
	const float* p1 = &ag->cornerVerts[ip1*3];
	
	float dir0[3], dir1[3];
	dtVsub(dir0, p0, ag->npos);
	dtVsub(dir1, p1, ag->npos);
	dir0[1] = 0;
	dir1[1] = 0;
	
	float len0 = dtVlen(dir0);
	float len1 = dtVlen(dir1);
	if (len1 > 0.001f)
		dtVscale(dir1,dir1,1.0f/len1);
	
	dir[0] = dir0[0] - dir1[0]*len0*0.5f;
	dir[1] = 0;
	dir[2] = dir0[2] - dir1[2]*len0*0.5f;
	
	dtVnormalize(dir);
}

static void calcStraightSteerDirection(const dtCrowdAgent* ag, float* dir)
{
	if (!ag->ncorners)
	{
		dtVset(dir, 0,0,0);
		return;
	}
	dtVsub(dir, &ag->cornerVerts[0], ag->npos);
	dir[1] = 0;
	dtVnormalize(dir);
}

static int addNeighbour(const int idx, const float dist,
						dtCrowdNeighbour* neis, const int nneis, const int maxNeis)
{
	dtCrowdNeighbour* nei = 0;
	if (!nneis)
	{
		nei = &neis[nneis];
	}
	else if (dist >= neis[nneis-1].dist)
	{
		if (nneis >= maxNeis)
			return nneis;
		nei = &neis[nneis];
	}
	else
	{
		int i;
		for (i = 0; i < nneis; ++i)
			if (dist <= neis[i].dist)
				break;
		
		const int tgt = i+1;
		const int n = dtMin(nneis-i, maxNeis-tgt);
		
		dtAssert(tgt+n <= maxNeis);
		
		if (n > 0)
			memmove(&neis[tgt], &neis[i], sizeof(dtCrowdNeighbour)*n);
		nei = &neis[i];
	}
	
	memset(nei, 0, sizeof(dtCrowdNeighbour));
	
	nei->idx = idx;
	nei->dist = dist;
	
	return dtMin(nneis+1, maxNeis);
}

static int getNeighbours(const float* pos, const float height, const float range,
						 const dtCrowdAgent* skip, dtCrowdNeighbour* result, const int maxResult,
						 dtCrowdAgent** agents, const int , dtProximityGrid* grid)
{
	int n = 0;
	
	static const int MAX_NEIS = 32;
	unsigned short ids[MAX_NEIS];
	int nids = grid->queryItems(pos[0]-range, pos[2]-range,
								pos[0]+range, pos[2]+range,
								ids, MAX_NEIS);
	
	for (int i = 0; i < nids; ++i)
	{
		const dtCrowdAgent* ag = agents[ids[i]];
		
		if (ag == skip) continue;
		
		float diff[3];
		dtVsub(diff, pos, ag->npos);
		if (dtMathFabsf(diff[1]) >= (height+ag->params.height)/2.0f)
			continue;
		diff[1] = 0;
		const float distSqr = dtVlenSqr(diff);
		if (distSqr > dtSqr(range))
			continue;
		
		n = addNeighbour(ids[i], distSqr, result, n, maxResult);
	}
	return n;
}

static int addToOptQueue(dtCrowdAgent* newag, dtCrowdAgent** agents, const int nagents, const int maxAgents)
{
	int slot = 0;
	if (!nagents)
	{
		slot = nagents;
	}
	else if (newag->topologyOptTime <= agents[nagents-1]->topologyOptTime)
	{
		if (nagents >= maxAgents)
			return nagents;
		slot = nagents;
	}
	else
	{
		int i;
		for (i = 0; i < nagents; ++i)
			if (newag->topologyOptTime >= agents[i]->topologyOptTime)
				break;
		
		const int tgt = i+1;
		const int n = dtMin(nagents-i, maxAgents-tgt);
		
		dtAssert(tgt+n <= maxAgents);
		
		if (n > 0)
			memmove(&agents[tgt], &agents[i], sizeof(dtCrowdAgent*)*n);
		slot = i;
	}
	
	agents[slot] = newag;
	
	return dtMin(nagents+1, maxAgents);
}

static int addToPathQueue(dtCrowdAgent* newag, dtCrowdAgent** agents, const int nagents, const int maxAgents)
{
	int slot = 0;
	if (!nagents)
	{
		slot = nagents;
	}
	else if (newag->targetReplanTime <= agents[nagents-1]->targetReplanTime)
	{
		if (nagents >= maxAgents)
			return nagents;
		slot = nagents;
	}
	else
	{
		int i;
		for (i = 0; i < nagents; ++i)
			if (newag->targetReplanTime >= agents[i]->targetReplanTime)
				break;
		
		const int tgt = i+1;
		const int n = dtMin(nagents-i, maxAgents-tgt);
		
		dtAssert(tgt+n <= maxAgents);
		
		if (n > 0)
			memmove(&agents[tgt], &agents[i], sizeof(dtCrowdAgent*)*n);
		slot = i;
	}
	
	agents[slot] = newag;
	
	return dtMin(nagents+1, maxAgents);
}

dtCrowd::dtCrowd() :
	m_maxAgents(0),
	m_agents(0),
	m_activeAgents(0),
	m_agentAnims(0),
	m_obstacleQuery(0),
	m_grid(0),
	m_pathResult(0),
	m_maxPathResult(0),
	m_maxAgentRadius(0),
	m_velocitySampleCount(0),
	m_navquery(0)
{
}

dtCrowd::~dtCrowd()
{
	purge();
}

void dtCrowd::purge()
{
	for (int i = 0; i < m_maxAgents; ++i)
		m_agents[i].~dtCrowdAgent();
	dtFree(m_agents);
	m_agents = 0;
	m_maxAgents = 0;
	
	dtFree(m_activeAgents);
	m_activeAgents = 0;

	dtFree(m_agentAnims);
	m_agentAnims = 0;
	
	dtFree(m_pathResult);
	m_pathResult = 0;
	
	dtFreeProximityGrid(m_grid);
	m_grid = 0;

	dtFreeObstacleAvoidanceQuery(m_obstacleQuery);
	m_obstacleQuery = 0;
	
	dtFreeNavMeshQuery(m_navquery);
	m_navquery = 0;
}

bool dtCrowd::init(const int maxAgents, const float maxAgentRadius, dtNavMesh* nav)
{
	purge();
	
	m_maxAgents = maxAgents;
	m_maxAgentRadius = maxAgentRadius;

	dtVset(m_agentPlacementHalfExtents, m_maxAgentRadius*2.0f, m_maxAgentRadius*1.5f, m_maxAgentRadius*2.0f);
	
	m_grid = dtAllocProximityGrid();
	if (!m_grid)
		return false;
	if (!m_grid->init(m_maxAgents*4, maxAgentRadius*3))
		return false;
	
	m_obstacleQuery = dtAllocObstacleAvoidanceQuery();
	if (!m_obstacleQuery)
		return false;
	if (!m_obstacleQuery->init(6, 8))
		return false;

	memset(m_obstacleQueryParams, 0, sizeof(m_obstacleQueryParams));
	for (int i = 0; i < DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS; ++i)
	{
		dtObstacleAvoidanceParams* params = &m_obstacleQueryParams[i];
		params->velBias = 0.4f;
		params->weightDesVel = 2.0f;
		params->weightCurVel = 0.75f;
		params->weightSide = 0.75f;
		params->weightToi = 2.5f;
		params->horizTime = 2.5f;
		params->gridSize = 33;
		params->adaptiveDivs = 7;
		params->adaptiveRings = 2;
		params->adaptiveDepth = 5;
	}
	
	m_maxPathResult = 256;
	m_pathResult = (dtPolyRef*)dtAlloc(sizeof(dtPolyRef)*m_maxPathResult, DT_ALLOC_PERM);
	if (!m_pathResult)
		return false;
	
	if (!m_pathq.init(m_maxPathResult, MAX_PATHQUEUE_NODES, nav))
		return false;
	
	m_agents = (dtCrowdAgent*)dtAlloc(sizeof(dtCrowdAgent)*m_maxAgents, DT_ALLOC_PERM);
	if (!m_agents)
		return false;
	
	m_activeAgents = (dtCrowdAgent**)dtAlloc(sizeof(dtCrowdAgent*)*m_maxAgents, DT_ALLOC_PERM);
	if (!m_activeAgents)
		return false;

	m_agentAnims = (dtCrowdAgentAnimation*)dtAlloc(sizeof(dtCrowdAgentAnimation)*m_maxAgents, DT_ALLOC_PERM);
	if (!m_agentAnims)
		return false;
	
	for (int i = 0; i < m_maxAgents; ++i)
	{
		new(&m_agents[i]) dtCrowdAgent();
		m_agents[i].active = false;
		if (!m_agents[i].corridor.init(m_maxPathResult))
			return false;
	}

	for (int i = 0; i < m_maxAgents; ++i)
	{
		m_agentAnims[i].active = false;
	}

	m_navquery = dtAllocNavMeshQuery();
	if (!m_navquery)
		return false;
	if (dtStatusFailed(m_navquery->init(nav, MAX_COMMON_NODES)))
		return false;
	
	return true;
}

void dtCrowd::setObstacleAvoidanceParams(const int idx, const dtObstacleAvoidanceParams* params)
{
	if (idx >= 0 && idx < DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS)
		memcpy(&m_obstacleQueryParams[idx], params, sizeof(dtObstacleAvoidanceParams));
}

const dtObstacleAvoidanceParams* dtCrowd::getObstacleAvoidanceParams(const int idx) const
{
	if (idx >= 0 && idx < DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS)
		return &m_obstacleQueryParams[idx];
	return 0;
}

int dtCrowd::getAgentCount() const
{
	return m_maxAgents;
}

const dtCrowdAgent* dtCrowd::getAgent(const int idx)
{
	if (idx < 0 || idx >= m_maxAgents)
		return 0;
	return &m_agents[idx];
}

dtCrowdAgent* dtCrowd::getEditableAgent(const int idx)
{
	if (idx < 0 || idx >= m_maxAgents)
		return 0;
	return &m_agents[idx];
}

void dtCrowd::updateAgentParameters(const int idx, const dtCrowdAgentParams* params)
{
	if (idx < 0 || idx >= m_maxAgents)
		return;
	memcpy(&m_agents[idx].params, params, sizeof(dtCrowdAgentParams));
}

int dtCrowd::addAgent(const float* pos, const dtCrowdAgentParams* params)
{
	int idx = -1;
	for (int i = 0; i < m_maxAgents; ++i)
	{
		if (!m_agents[i].active)
		{
			idx = i;
			break;
		}
	}
	if (idx == -1)
		return -1;
	
	dtCrowdAgent* ag = &m_agents[idx];		

	updateAgentParameters(idx, params);
	
	float nearest[3];
	dtPolyRef ref = 0;
	dtVcopy(nearest, pos);
	dtStatus status = m_navquery->findNearestPoly(pos, m_agentPlacementHalfExtents, &m_filters[ag->params.queryFilterType], &ref, nearest);
	if (dtStatusFailed(status))
	{
		dtVcopy(nearest, pos);
		ref = 0;
	}
	
	ag->corridor.reset(ref, nearest);
	ag->boundary.reset();
	ag->partial = false;

	ag->topologyOptTime = 0;
	ag->targetReplanTime = 0;
	ag->nneis = 0;
	
	dtVset(ag->dvel, 0,0,0);
	dtVset(ag->nvel, 0,0,0);
	dtVset(ag->vel, 0,0,0);
	dtVcopy(ag->npos, nearest);
	
	ag->desiredSpeed = 0;

	if (ref)
		ag->state = DT_CROWDAGENT_STATE_WALKING;
	else
		ag->state = DT_CROWDAGENT_STATE_INVALID;
	
	ag->targetState = DT_CROWDAGENT_TARGET_NONE;
	
	ag->active = true;

	return idx;
}

void dtCrowd::removeAgent(const int idx)
{
	if (idx >= 0 && idx < m_maxAgents)
	{
		m_agents[idx].active = false;
	}
}

bool dtCrowd::requestMoveTargetReplan(const int idx, dtPolyRef ref, const float* pos)
{
	if (idx < 0 || idx >= m_maxAgents)
		return false;
	
	dtCrowdAgent* ag = &m_agents[idx];
	
	ag->targetRef = ref;
	dtVcopy(ag->targetPos, pos);
	ag->targetPathqRef = DT_PATHQ_INVALID;
	ag->targetReplan = true;
	if (ag->targetRef)
		ag->targetState = DT_CROWDAGENT_TARGET_REQUESTING;
	else
		ag->targetState = DT_CROWDAGENT_TARGET_FAILED;
	
	return true;
}

bool dtCrowd::requestMoveTarget(const int idx, dtPolyRef ref, const float* pos)
{
	if (idx < 0 || idx >= m_maxAgents)
		return false;
	if (!ref)
		return false;

	dtCrowdAgent* ag = &m_agents[idx];
	
	ag->targetRef = ref;
	dtVcopy(ag->targetPos, pos);
	ag->targetPathqRef = DT_PATHQ_INVALID;
	ag->targetReplan = false;
	if (ag->targetRef)
		ag->targetState = DT_CROWDAGENT_TARGET_REQUESTING;
	else
		ag->targetState = DT_CROWDAGENT_TARGET_FAILED;

	return true;
}

bool dtCrowd::requestMoveVelocity(const int idx, const float* vel)
{
	if (idx < 0 || idx >= m_maxAgents)
		return false;
	
	dtCrowdAgent* ag = &m_agents[idx];
	
	ag->targetRef = 0;
	dtVcopy(ag->targetPos, vel);
	ag->targetPathqRef = DT_PATHQ_INVALID;
	ag->targetReplan = false;
	ag->targetState = DT_CROWDAGENT_TARGET_VELOCITY;
	
	return true;
}

bool dtCrowd::resetMoveTarget(const int idx)
{
	if (idx < 0 || idx >= m_maxAgents)
		return false;
	
	dtCrowdAgent* ag = &m_agents[idx];
	
	ag->targetRef = 0;
	dtVset(ag->targetPos, 0,0,0);
	dtVset(ag->dvel, 0,0,0);
	ag->targetPathqRef = DT_PATHQ_INVALID;
	ag->targetReplan = false;
	ag->targetState = DT_CROWDAGENT_TARGET_NONE;
	
	return true;
}

int dtCrowd::getActiveAgents(dtCrowdAgent** agents, const int maxAgents)
{
	int n = 0;
	for (int i = 0; i < m_maxAgents; ++i)
	{
		if (!m_agents[i].active) continue;
		if (n < maxAgents)
			agents[n++] = &m_agents[i];
	}
	return n;
}

void dtCrowd::updateMoveRequest(const float )
{
	const int PATH_MAX_AGENTS = 8;
	dtCrowdAgent* queue[PATH_MAX_AGENTS];
	int nqueue = 0;
	
	for (int i = 0; i < m_maxAgents; ++i)
	{
		dtCrowdAgent* ag = &m_agents[i];
		if (!ag->active)
			continue;
		if (ag->state == DT_CROWDAGENT_STATE_INVALID)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;

		if (ag->targetState == DT_CROWDAGENT_TARGET_REQUESTING)
		{
			const dtPolyRef* path = ag->corridor.getPath();
			const int npath = ag->corridor.getPathCount();
			dtAssert(npath);

			static const int MAX_RES = 32;
			float reqPos[3];
			dtPolyRef reqPath[MAX_RES];
			int reqPathCount = 0;

			static const int MAX_ITER = 20;
			m_navquery->initSlicedFindPath(path[0], ag->targetRef, ag->npos, ag->targetPos, &m_filters[ag->params.queryFilterType]);
			m_navquery->updateSlicedFindPath(MAX_ITER, 0);
			dtStatus status = 0;
			if (ag->targetReplan)
			{
				status = m_navquery->finalizeSlicedFindPathPartial(path, npath, reqPath, &reqPathCount, MAX_RES);
			}
			else
			{
				status = m_navquery->finalizeSlicedFindPath(reqPath, &reqPathCount, MAX_RES);
			}

			if (!dtStatusFailed(status) && reqPathCount > 0)
			{
				if (reqPath[reqPathCount-1] != ag->targetRef)
				{
					status = m_navquery->closestPointOnPoly(reqPath[reqPathCount-1], ag->targetPos, reqPos, 0);
					if (dtStatusFailed(status))
						reqPathCount = 0;
				}
				else
				{
					dtVcopy(reqPos, ag->targetPos);
				}
			}
			else
			{
				reqPathCount = 0;
			}
				
			if (!reqPathCount)
			{
				dtVcopy(reqPos, ag->npos);
				reqPath[0] = path[0];
				reqPathCount = 1;
			}

			ag->corridor.setCorridor(reqPos, reqPath, reqPathCount);
			ag->boundary.reset();
			ag->partial = false;

			if (reqPath[reqPathCount-1] == ag->targetRef)
			{
				ag->targetState = DT_CROWDAGENT_TARGET_VALID;
				ag->targetReplanTime = 0.0;
			}
			else
			{
				ag->targetState = DT_CROWDAGENT_TARGET_WAITING_FOR_QUEUE;
			}
		}
		
		if (ag->targetState == DT_CROWDAGENT_TARGET_WAITING_FOR_QUEUE)
		{
			nqueue = addToPathQueue(ag, queue, nqueue, PATH_MAX_AGENTS);
		}
	}

	for (int i = 0; i < nqueue; ++i)
	{
		dtCrowdAgent* ag = queue[i];
		ag->targetPathqRef = m_pathq.request(ag->corridor.getLastPoly(), ag->targetRef,
											 ag->corridor.getTarget(), ag->targetPos, &m_filters[ag->params.queryFilterType]);
		if (ag->targetPathqRef != DT_PATHQ_INVALID)
			ag->targetState = DT_CROWDAGENT_TARGET_WAITING_FOR_PATH;
	}

	m_pathq.update(MAX_ITERS_PER_UPDATE);

	dtStatus status;

	for (int i = 0; i < m_maxAgents; ++i)
	{
		dtCrowdAgent* ag = &m_agents[i];
		if (!ag->active)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;
		
		if (ag->targetState == DT_CROWDAGENT_TARGET_WAITING_FOR_PATH)
		{
			status = m_pathq.getRequestStatus(ag->targetPathqRef);
			if (dtStatusFailed(status))
			{
				ag->targetPathqRef = DT_PATHQ_INVALID;
				if (ag->targetRef)
					ag->targetState = DT_CROWDAGENT_TARGET_REQUESTING;
				else
					ag->targetState = DT_CROWDAGENT_TARGET_FAILED;
				ag->targetReplanTime = 0.0;
			}
			else if (dtStatusSucceed(status))
			{
				const dtPolyRef* path = ag->corridor.getPath();
				const int npath = ag->corridor.getPathCount();
				dtAssert(npath);
				
				float targetPos[3];
				dtVcopy(targetPos, ag->targetPos);
				
				dtPolyRef* res = m_pathResult;
				bool valid = true;
				int nres = 0;
				status = m_pathq.getPathResult(ag->targetPathqRef, res, &nres, m_maxPathResult);
				if (dtStatusFailed(status) || !nres)
					valid = false;

				if (dtStatusDetail(status, DT_PARTIAL_RESULT))
					ag->partial = true;
				else
					ag->partial = false;

				if (valid && path[npath-1] != res[0])
					valid = false;
				
				if (valid)
				{
					if (npath > 1)
					{
						if ((npath-1)+nres > m_maxPathResult)
							nres = m_maxPathResult - (npath-1);
						
						memmove(res+npath-1, res, sizeof(dtPolyRef)*nres);
						memcpy(res, path, sizeof(dtPolyRef)*(npath-1));
						nres += npath-1;
						
						for (int j = 0; j < nres; ++j)
						{
							if (j-1 >= 0 && j+1 < nres)
							{
								if (res[j-1] == res[j+1])
								{
									memmove(res+(j-1), res+(j+1), sizeof(dtPolyRef)*(nres-(j+1)));
									nres -= 2;
									j -= 2;
								}
							}
						}
						
					}
					
					if (res[nres-1] != ag->targetRef)
					{
						float nearest[3];
						status = m_navquery->closestPointOnPoly(res[nres-1], targetPos, nearest, 0);
						if (dtStatusSucceed(status))
							dtVcopy(targetPos, nearest);
						else
							valid = false;
					}
				}
				
				if (valid)
				{
					ag->corridor.setCorridor(targetPos, res, nres);
					ag->boundary.reset();
					ag->targetState = DT_CROWDAGENT_TARGET_VALID;
				}
				else
				{
					ag->targetState = DT_CROWDAGENT_TARGET_FAILED;
				}

				ag->targetReplanTime = 0.0;
			}
		}
	}
	
}

void dtCrowd::updateTopologyOptimization(dtCrowdAgent** agents, const int nagents, const float dt)
{
	if (!nagents)
		return;
	
	const float OPT_TIME_THR = 0.5f;
	const int OPT_MAX_AGENTS = 1;
	dtCrowdAgent* queue[OPT_MAX_AGENTS];
	int nqueue = 0;
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;
		if ((ag->params.updateFlags & DT_CROWD_OPTIMIZE_TOPO) == 0)
			continue;
		ag->topologyOptTime += dt;
		if (ag->topologyOptTime >= OPT_TIME_THR)
			nqueue = addToOptQueue(ag, queue, nqueue, OPT_MAX_AGENTS);
	}

	for (int i = 0; i < nqueue; ++i)
	{
		dtCrowdAgent* ag = queue[i];
		ag->corridor.optimizePathTopology(m_navquery, &m_filters[ag->params.queryFilterType]);
		ag->topologyOptTime = 0;
	}

}

void dtCrowd::checkPathValidity(dtCrowdAgent** agents, const int nagents, const float dt)
{
	static const int CHECK_LOOKAHEAD = 10;
	static const float TARGET_REPLAN_DELAY = 1.0;
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
			
		ag->targetReplanTime += dt;

		bool replan = false;

		const int idx = getAgentIndex(ag);
		float agentPos[3];
		dtPolyRef agentRef = ag->corridor.getFirstPoly();
		dtVcopy(agentPos, ag->npos);
		if (!m_navquery->isValidPolyRef(agentRef, &m_filters[ag->params.queryFilterType]))
		{
			float nearest[3];
			dtVcopy(nearest, agentPos);
			agentRef = 0;
			m_navquery->findNearestPoly(ag->npos, m_agentPlacementHalfExtents, &m_filters[ag->params.queryFilterType], &agentRef, nearest);
			dtVcopy(agentPos, nearest);

			if (!agentRef)
			{
				ag->corridor.reset(0, agentPos);
				ag->partial = false;
				ag->boundary.reset();
				ag->state = DT_CROWDAGENT_STATE_INVALID;
				continue;
			}

			ag->corridor.fixPathStart(agentRef, agentPos);
			ag->boundary.reset();
			dtVcopy(ag->npos, agentPos);

			replan = true;
		}

		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;

		if (ag->targetState != DT_CROWDAGENT_TARGET_NONE && ag->targetState != DT_CROWDAGENT_TARGET_FAILED)
		{
			if (!m_navquery->isValidPolyRef(ag->targetRef, &m_filters[ag->params.queryFilterType]))
			{
				float nearest[3];
				dtVcopy(nearest, ag->targetPos);
				ag->targetRef = 0;
				m_navquery->findNearestPoly(ag->targetPos, m_agentPlacementHalfExtents, &m_filters[ag->params.queryFilterType], &ag->targetRef, nearest);
				dtVcopy(ag->targetPos, nearest);
				replan = true;
			}
			if (!ag->targetRef)
			{
				ag->corridor.reset(agentRef, agentPos);
				ag->partial = false;
				ag->targetState = DT_CROWDAGENT_TARGET_NONE;
			}
		}

		if (!ag->corridor.isValid(CHECK_LOOKAHEAD, m_navquery, &m_filters[ag->params.queryFilterType]))
		{
			replan = true;
		}
		
		if (ag->targetState == DT_CROWDAGENT_TARGET_VALID)
		{
			if (ag->targetReplanTime > TARGET_REPLAN_DELAY &&
				ag->corridor.getPathCount() < CHECK_LOOKAHEAD &&
				ag->corridor.getLastPoly() != ag->targetRef)
				replan = true;
		}

		if (replan)
		{
			if (ag->targetState != DT_CROWDAGENT_TARGET_NONE)
			{
				requestMoveTargetReplan(idx, ag->targetRef, ag->targetPos);
			}
		}
	}
}
	
void dtCrowd::update(const float dt, dtCrowdAgentDebugInfo* debug)
{
	m_velocitySampleCount = 0;
	
	const int debugIdx = debug ? debug->idx : -1;
	
	dtCrowdAgent** agents = m_activeAgents;
	int nagents = getActiveAgents(agents, m_maxAgents);

	checkPathValidity(agents, nagents, dt);
	
	updateMoveRequest(dt);

	updateTopologyOptimization(agents, nagents, dt);
	
	m_grid->clear();
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		const float* p = ag->npos;
		const float r = ag->params.radius;
		m_grid->addItem((unsigned short)i, p[0]-r, p[2]-r, p[0]+r, p[2]+r);
	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;

		const float updateThr = ag->params.collisionQueryRange*0.25f;
		if (dtVdist2DSqr(ag->npos, ag->boundary.getCenter()) > dtSqr(updateThr) ||
			!ag->boundary.isValid(m_navquery, &m_filters[ag->params.queryFilterType]))
		{
			ag->boundary.update(ag->corridor.getFirstPoly(), ag->npos, ag->params.collisionQueryRange,
								m_navquery, &m_filters[ag->params.queryFilterType]);
		}
		ag->nneis = getNeighbours(ag->npos, ag->params.height, ag->params.collisionQueryRange,
								  ag, ag->neis, DT_CROWDAGENT_MAX_NEIGHBOURS,
								  agents, nagents, m_grid);
		for (int j = 0; j < ag->nneis; j++)
			ag->neis[j].idx = getAgentIndex(agents[ag->neis[j].idx]);
	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;
		
		ag->ncorners = ag->corridor.findCorners(ag->cornerVerts, ag->cornerFlags, ag->cornerPolys,
												DT_CROWDAGENT_MAX_CORNERS, m_navquery, &m_filters[ag->params.queryFilterType]);
		
		if ((ag->params.updateFlags & DT_CROWD_OPTIMIZE_VIS) && ag->ncorners > 0)
		{
			const float* target = &ag->cornerVerts[dtMin(1,ag->ncorners-1)*3];
			ag->corridor.optimizePathVisibility(target, ag->params.pathOptimizationRange, m_navquery, &m_filters[ag->params.queryFilterType]);
			
			if (debugIdx == i)
			{
				dtVcopy(debug->optStart, ag->corridor.getPos());
				dtVcopy(debug->optEnd, target);
			}
		}
		else
		{
			if (debugIdx == i)
			{
				dtVset(debug->optStart, 0,0,0);
				dtVset(debug->optEnd, 0,0,0);
			}
		}
	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
			continue;
		
		const float triggerRadius = ag->params.radius*2.25f;
		if (overOffmeshConnection(ag, triggerRadius))
		{
			const int idx = (int)(ag - m_agents);
			dtCrowdAgentAnimation* anim = &m_agentAnims[idx];
			
			dtPolyRef refs[2];
			if (ag->corridor.moveOverOffmeshConnection(ag->cornerPolys[ag->ncorners-1], refs,
													   anim->startPos, anim->endPos, m_navquery))
			{
				dtVcopy(anim->initPos, ag->npos);
				anim->polyRef = refs[1];
				anim->active = true;
				anim->t = 0.0f;
				anim->tmax = (dtVdist2D(anim->startPos, anim->endPos) / ag->params.maxSpeed) * 0.5f;
				
				ag->state = DT_CROWDAGENT_STATE_OFFMESH;
				ag->ncorners = 0;
				ag->nneis = 0;
				continue;
			}
			else
			{
			}
		}
	}
		
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];

		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE)
			continue;
		
		float dvel[3] = {0,0,0};

		if (ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
		{
			dtVcopy(dvel, ag->targetPos);
			ag->desiredSpeed = dtVlen(ag->targetPos);
		}
		else
		{
			if (ag->params.updateFlags & DT_CROWD_ANTICIPATE_TURNS)
				calcSmoothSteerDirection(ag, dvel);
			else
				calcStraightSteerDirection(ag, dvel);
			
			const float slowDownRadius = ag->params.radius*2;
			const float speedScale = getDistanceToGoal(ag, slowDownRadius) / slowDownRadius;
				
			ag->desiredSpeed = ag->params.maxSpeed;
			dtVscale(dvel, dvel, ag->desiredSpeed * speedScale);
		}

		if (ag->params.updateFlags & DT_CROWD_SEPARATION)
		{
			const float separationDist = ag->params.collisionQueryRange; 
			const float invSeparationDist = 1.0f / separationDist; 
			const float separationWeight = ag->params.separationWeight;
			
			float w = 0;
			float disp[3] = {0,0,0};
			
			for (int j = 0; j < ag->nneis; ++j)
			{
				const dtCrowdAgent* nei = &m_agents[ag->neis[j].idx];
				
				float diff[3];
				dtVsub(diff, ag->npos, nei->npos);
				diff[1] = 0;
				
				const float distSqr = dtVlenSqr(diff);
				if (distSqr < 0.00001f)
					continue;
				if (distSqr > dtSqr(separationDist))
					continue;
				const float dist = dtMathSqrtf(distSqr);
				const float weight = separationWeight * (1.0f - dtSqr(dist*invSeparationDist));
				
				dtVmad(disp, disp, diff, weight/dist);
				w += 1.0f;
			}
			
			if (w > 0.0001f)
			{
				dtVmad(dvel, dvel, disp, 1.0f/w);
				const float speedSqr = dtVlenSqr(dvel);
				const float desiredSqr = dtSqr(ag->desiredSpeed);
				if (speedSqr > desiredSqr)
					dtVscale(dvel, dvel, desiredSqr/speedSqr);
			}
		}
		
		dtVcopy(ag->dvel, dvel);
	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		
		if (ag->params.updateFlags & DT_CROWD_OBSTACLE_AVOIDANCE)
		{
			m_obstacleQuery->reset();
			
			for (int j = 0; j < ag->nneis; ++j)
			{
				const dtCrowdAgent* nei = &m_agents[ag->neis[j].idx];
				m_obstacleQuery->addCircle(nei->npos, nei->params.radius, nei->vel, nei->dvel);
			}

			for (int j = 0; j < ag->boundary.getSegmentCount(); ++j)
			{
				const float* s = ag->boundary.getSegment(j);
				if (dtTriArea2D(ag->npos, s, s+3) < 0.0f)
					continue;
				m_obstacleQuery->addSegment(s, s+3);
			}

			dtObstacleAvoidanceDebugData* vod = 0;
			if (debugIdx == i) 
				vod = debug->vod;
			
			bool adaptive = true;
			int ns = 0;

			const dtObstacleAvoidanceParams* params = &m_obstacleQueryParams[ag->params.obstacleAvoidanceType];
				
			if (adaptive)
			{
				ns = m_obstacleQuery->sampleVelocityAdaptive(ag->npos, ag->params.radius, ag->desiredSpeed,
															 ag->vel, ag->dvel, ag->nvel, params, vod);
			}
			else
			{
				ns = m_obstacleQuery->sampleVelocityGrid(ag->npos, ag->params.radius, ag->desiredSpeed,
														 ag->vel, ag->dvel, ag->nvel, params, vod);
			}
			m_velocitySampleCount += ns;
		}
		else
		{
			dtVcopy(ag->nvel, ag->dvel);
		}
	}

	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		integrate(ag, dt);
	}
	
	static const float COLLISION_RESOLVE_FACTOR = 0.7f;
	
	for (int iter = 0; iter < 4; ++iter)
	{
		for (int i = 0; i < nagents; ++i)
		{
			dtCrowdAgent* ag = agents[i];
			const int idx0 = getAgentIndex(ag);
			
			if (ag->state != DT_CROWDAGENT_STATE_WALKING)
				continue;

			dtVset(ag->disp, 0,0,0);
			
			float w = 0;

			for (int j = 0; j < ag->nneis; ++j)
			{
				const dtCrowdAgent* nei = &m_agents[ag->neis[j].idx];
				const int idx1 = getAgentIndex(nei);

				float diff[3];
				dtVsub(diff, ag->npos, nei->npos);
				diff[1] = 0;
				
				float dist = dtVlenSqr(diff);
				if (dist > dtSqr(ag->params.radius + nei->params.radius))
					continue;
				dist = dtMathSqrtf(dist);
				float pen = (ag->params.radius + nei->params.radius) - dist;
				if (dist < 0.0001f)
				{
					if (idx0 > idx1)
						dtVset(diff, -ag->dvel[2],0,ag->dvel[0]);
					else
						dtVset(diff, ag->dvel[2],0,-ag->dvel[0]);
					pen = 0.01f;
				}
				else
				{
					pen = (1.0f/dist) * (pen*0.5f) * COLLISION_RESOLVE_FACTOR;
				}
				
				dtVmad(ag->disp, ag->disp, diff, pen);			
				
				w += 1.0f;
			}
			
			if (w > 0.0001f)
			{
				const float iw = 1.0f / w;
				dtVscale(ag->disp, ag->disp, iw);
			}
		}
		
		for (int i = 0; i < nagents; ++i)
		{
			dtCrowdAgent* ag = agents[i];
			if (ag->state != DT_CROWDAGENT_STATE_WALKING)
				continue;
			
			dtVadd(ag->npos, ag->npos, ag->disp);
		}
	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		if (ag->state != DT_CROWDAGENT_STATE_WALKING)
			continue;
		
		ag->corridor.movePosition(ag->npos, m_navquery, &m_filters[ag->params.queryFilterType]);
		dtVcopy(ag->npos, ag->corridor.getPos());

		if (ag->targetState == DT_CROWDAGENT_TARGET_NONE || ag->targetState == DT_CROWDAGENT_TARGET_VELOCITY)
		{
			ag->corridor.reset(ag->corridor.getFirstPoly(), ag->npos);
			ag->partial = false;
		}

	}
	
	for (int i = 0; i < nagents; ++i)
	{
		dtCrowdAgent* ag = agents[i];
		const int idx = (int)(ag - m_agents);
		dtCrowdAgentAnimation* anim = &m_agentAnims[idx];
		if (!anim->active)
			continue;
		
		anim->t += dt;
		if (anim->t > anim->tmax)
		{
			anim->active = false;
			ag->state = DT_CROWDAGENT_STATE_WALKING;
			continue;
		}
		
		const float ta = anim->tmax*0.15f;
		const float tb = anim->tmax;
		if (anim->t < ta)
		{
			const float u = tween(anim->t, 0.0, ta);
			dtVlerp(ag->npos, anim->initPos, anim->startPos, u);
		}
		else
		{
			const float u = tween(anim->t, ta, tb);
			dtVlerp(ag->npos, anim->startPos, anim->endPos, u);
		}
			
		dtVset(ag->vel, 0,0,0);
		dtVset(ag->dvel, 0,0,0);
	}
	
}
