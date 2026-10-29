#pragma once

#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

#include "DetourNavMesh.h"
#include "DetourNavMeshQuery.h"
#include "DetourCommon.h"
#include "DetourCrowd.h"
#include "navset.h"

enum { NAV_BODY_PEOPLE = 0, NAV_BODY_DEER = 1, NAV_BODY_SHEEP = 2, NAV_BODY_COUNT = 3 };

#define NAV_MAX_CORNERS 96
#define NAV_MAX_POLYS 1024
#define NAV_CROWD_AGENTS 192

static const char* const NAV_BODY_FILE[NAV_BODY_COUNT] = {"people", "deer", "sheep"};
static const float NAV_START_EXT[3] = {1.5f, 2.5f, 1.5f};
static const float NAV_END_EXT[3] = {2.0f, 4.0f, 2.0f};

struct NavBody {
    dtNavMesh* mesh = nullptr;
    dtNavMeshQuery* query = nullptr;
    dtCrowd* crowd = nullptr;
    dtQueryFilter filter;
    NavSetHeader header;
    int tiles = 0;
    int owner[NAV_CROWD_AGENTS];
    int ownerKey[NAV_CROWD_AGENTS];
    bool seen[NAV_CROWD_AGENTS];
};

static NavBody g_NavBodies[NAV_BODY_COUNT];
static bool g_NavEnabled = true;
static bool g_NavCrowdEnabled = true;

static inline void NavToDetour(float x, float y, float z, float* o) { o[0] = x; o[1] = z; o[2] = -y; }
static inline void NavToSA(const float* v, float& x, float& y, float& z) { x = v[0]; y = -v[2]; z = v[1]; }

static inline bool NavReady(int body) {
    return g_NavEnabled && body >= 0 && body < NAV_BODY_COUNT && g_NavBodies[body].mesh != nullptr;
}

static bool NavLoadBody(int body, const char* path) {
    NavBody& nb = g_NavBodies[body];
    FILE* f = fopen(path, "rb");
    if (!f) return false;
    NavSetHeader h;
    if (fread(&h, sizeof(h), 1, f) != 1 || h.magic != NAVSET_MAGIC || h.version != NAVSET_VERSION) {
        logprintf("[Pedestrians] nav: %s is not a navmesh set this build reads", path);
        fclose(f);
        return false;
    }
    dtNavMesh* mesh = dtAllocNavMesh();
    if (!mesh || dtStatusFailed(mesh->init(&h.params))) {
        fclose(f);
        return false;
    }
    int added = 0;
    for (int i = 0; i < h.numTiles; i++) {
        NavTileHeader th;
        if (fread(&th, sizeof(th), 1, f) != 1) break;
        unsigned char* data = (unsigned char*)dtAlloc(th.dataSize, DT_ALLOC_PERM);
        if (!data || fread(data, 1, th.dataSize, f) != (size_t)th.dataSize) { dtFree(data); break; }
        if (dtStatusFailed(mesh->addTile(data, th.dataSize, DT_TILE_FREE_DATA, 0, nullptr))) { dtFree(data); continue; }
        added++;
    }
    fclose(f);
    if (added != h.numTiles) {
        logprintf("[Pedestrians] nav: %s holds %d tiles, %d loaded", path, h.numTiles, added);
        dtFreeNavMesh(mesh);
        return false;
    }
    nb.mesh = mesh;
    nb.header = h;
    nb.tiles = added;
    nb.filter.setIncludeFlags(NAV_FLAG_WALK);
    nb.filter.setExcludeFlags(0);
    nb.query = dtAllocNavMeshQuery();
    nb.query->init(mesh, 4096);
    nb.crowd = dtAllocCrowd();
    if (nb.crowd && nb.crowd->init(NAV_CROWD_AGENTS, 1.0f, mesh)) {
        dtObstacleAvoidanceParams oa;
        memcpy(&oa, nb.crowd->getObstacleAvoidanceParams(0), sizeof(oa));
        oa.velBias = 0.5f;
        oa.adaptiveDivs = 7;
        oa.adaptiveRings = 2;
        oa.adaptiveDepth = 3;
        nb.crowd->setObstacleAvoidanceParams(0, &oa);
        for (int i = 0; i < NAV_CROWD_AGENTS; i++) { nb.owner[i] = -1; nb.ownerKey[i] = 0; }
    } else {
        if (nb.crowd) dtFreeCrowd(nb.crowd);
        nb.crowd = nullptr;
        logprintf("[Pedestrians] nav: no crowd for %s, walkers near humans path without avoidance", NAV_BODY_FILE[body]);
    }
    return true;
}

static void NavUnload() {
    for (int b = 0; b < NAV_BODY_COUNT; b++) {
        NavBody& nb = g_NavBodies[b];
        if (nb.crowd) dtFreeCrowd(nb.crowd);
        if (nb.query) dtFreeNavMeshQuery(nb.query);
        if (nb.mesh) dtFreeNavMesh(nb.mesh);
        nb.crowd = nullptr; nb.query = nullptr; nb.mesh = nullptr; nb.tiles = 0;
    }
}

static int NavLoadAll(const char* dir) {
    NavUnload();
    int loaded = 0;
    for (int b = 0; b < NAV_BODY_COUNT; b++) {
        char path[256];
        snprintf(path, sizeof(path), "%s/%s.bin", dir, NAV_BODY_FILE[b]);
        if (NavLoadBody(b, path)) {
            loaded++;
            logprintf("[Pedestrians] nav: %s mesh loaded, %d tiles (radius %.2f, height %.2f, climb %.2f)", NAV_BODY_FILE[b], g_NavBodies[b].tiles, g_NavBodies[b].header.bodyRadius, g_NavBodies[b].header.bodyHeight, g_NavBodies[b].header.bodyClimb);
        } else {
            logprintf("[Pedestrians] WARNING: nav: no usable %s - %s actors walk the old way (straight lines, ground search)", path, NAV_BODY_FILE[b]);
        }
    }
    return loaded;
}

static int NavBodyForKind(int kind) {
    if (kind < 50 || kind >= 100) return NAV_BODY_PEOPLE;
    static const int table[16] = {
        NAV_BODY_DEER, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_DEER, NAV_BODY_DEER, NAV_BODY_DEER,
        NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_SHEEP, NAV_BODY_DEER};
    int species = kind - 50;
    return species < 16 ? table[species] : NAV_BODY_SHEEP;
}

static bool NavFindPoly(int body, float x, float y, float z, const float* ext, dtPolyRef& ref, float* snappedSA) {
    NavBody& nb = g_NavBodies[body];
    float c[3], nearest[3];
    NavToDetour(x, y, z, c);
    ref = 0;
    nb.query->findNearestPoly(c, ext, &nb.filter, &ref, nearest);
    if (!ref) return false;
    if (snappedSA) NavToSA(nearest, snappedSA[0], snappedSA[1], snappedSA[2]);
    return true;
}

static bool NavPolyHeight(int body, dtPolyRef ref, float x, float y, float& z) {
    NavBody& nb = g_NavBodies[body];
    float p[3], h = 0;
    NavToDetour(x, y, 0.0f, p);
    if (dtStatusFailed(nb.query->getPolyHeight(ref, p, &h))) return false;
    z = h;
    return true;
}

struct NavRoute {
    float pts[NAV_MAX_CORNERS * 3];
    int n = 0;
    dtPolyRef startRef = 0, endRef = 0;
    float endPos[3];
    bool complete = false;
    float length = 0;
    int fail = 0;
    float startSnap = -1, endSnap = -1;
    int pathPolys = 0;
};

static bool NavBuildRoute(int body, const float* from, const float* to, NavRoute& r, dtPolyRef knownStart = 0) {
    NavBody& nb = g_NavBodies[body];
    r.n = 0; r.complete = false; r.length = 0; r.fail = 0; r.startSnap = -1; r.endSnap = -1; r.pathPolys = 0;
    float s[3], e[3], sn[3];
    dtPolyRef sref = knownStart, eref = 0;
    NavToDetour(from[0], from[1], from[2], s);
    if (!sref) {
        float ss[3];
        if (!NavFindPoly(body, from[0], from[1], from[2], NAV_START_EXT, sref, ss)) { r.fail = 1; return false; }
        r.startSnap = std::sqrt((ss[0] - from[0]) * (ss[0] - from[0]) + (ss[1] - from[1]) * (ss[1] - from[1]));
    }
    float snapped[3];
    if (!NavFindPoly(body, to[0], to[1], to[2], NAV_END_EXT, eref, snapped)) { r.fail = 2; return false; }
    r.endSnap = std::sqrt((snapped[0] - to[0]) * (snapped[0] - to[0]) + (snapped[1] - to[1]) * (snapped[1] - to[1]));
    NavToDetour(snapped[0], snapped[1], snapped[2], e);
    nb.query->closestPointOnPoly(sref, s, sn, nullptr);
    dtPolyRef polys[NAV_MAX_POLYS];
    int npolys = 0;
    nb.query->findPath(sref, eref, sn, e, &nb.filter, polys, &npolys, NAV_MAX_POLYS);
    r.pathPolys = npolys;
    if (npolys == 0 || polys[npolys - 1] != eref) { r.fail = 3; return false; }
    float straight[NAV_MAX_CORNERS * 3];
    int ns = 0;
    nb.query->findStraightPath(sn, e, polys, npolys, straight, nullptr, nullptr, &ns, NAV_MAX_CORNERS);
    if (ns < 1) { r.fail = 4; return false; }
    for (int i = 0; i < ns; i++) NavToSA(&straight[i * 3], r.pts[i * 3], r.pts[i * 3 + 1], r.pts[i * 3 + 2]);
    r.n = ns;
    r.startRef = sref;
    r.endRef = eref;
    r.endPos[0] = snapped[0]; r.endPos[1] = snapped[1]; r.endPos[2] = snapped[2];
    r.complete = true;
    for (int i = 1; i < ns; i++) r.length += std::sqrt((r.pts[i * 3] - r.pts[i * 3 - 3]) * (r.pts[i * 3] - r.pts[i * 3 - 3]) + (r.pts[i * 3 + 1] - r.pts[i * 3 - 2]) * (r.pts[i * 3 + 1] - r.pts[i * 3 - 2]));
    return true;
}

static bool NavMoveAlong(int body, dtPolyRef& ref, float x, float y, float z, float nx, float ny, float* out) {
    NavBody& nb = g_NavBodies[body];
    float a[3], b[3], res[3];
    NavToDetour(x, y, z, a);
    NavToDetour(nx, ny, z, b);
    dtPolyRef visited[16];
    int nv = 0;
    if (dtStatusFailed(nb.query->moveAlongSurface(ref, a, b, &nb.filter, res, visited, &nv, 16)) || nv == 0) return false;
    ref = visited[nv - 1];
    float h = z;
    NavToSA(res, out[0], out[1], out[2]);
    if (NavPolyHeight(body, ref, out[0], out[1], h)) out[2] = h; else out[2] = z;
    return true;
}

static bool NavFleeGoal(int body, const float* from, const float* threat, float* goal, float* outLength) {
    float ax = from[0] - threat[0], ay = from[1] - threat[1];
    float len = std::sqrt(ax * ax + ay * ay);
    if (len < 0.01f) { ax = 1.0f; ay = 0.0f; len = 1.0f; }
    ax /= len; ay /= len;
    static const float dists[3] = {30.0f, 18.0f, 9.0f};
    NavRoute r;
    float bestScore = -1e30f;
    bool found = false;
    dtPolyRef start = 0;
    NavFindPoly(body, from[0], from[1], from[2], NAV_START_EXT, start, nullptr);
    if (!start) return false;
    for (int d = 0; d < 3 && !found; d++) {
        for (int k = 0; k < 13; k++) {
            float ang = (k - 6) * (80.0f / 6.0f) * 3.14159265f / 180.0f;
            float dx = ax * std::cos(ang) - ay * std::sin(ang), dy = ax * std::sin(ang) + ay * std::cos(ang);
            float to[3] = {from[0] + dx * dists[d], from[1] + dy * dists[d], from[2]};
            if (!NavBuildRoute(body, from, to, r, start)) continue;
            float gx = r.endPos[0] - threat[0], gy = r.endPos[1] - threat[1];
            float away = std::sqrt(gx * gx + gy * gy);
            float cur = len;
            if (away < cur + dists[d] * 0.35f) continue;
            if (r.length > dists[d] * 1.8f) continue;
            if (r.n >= 2) {
                float fx = r.pts[3] - from[0], fy = r.pts[4] - from[1];
                float fl = std::sqrt(fx * fx + fy * fy);
                if (fl > 0.2f && (fx * ax + fy * ay) / fl < -0.25f) continue;
            }
            float score = away - 0.25f * r.length;
            if (score > bestScore) {
                bestScore = score;
                goal[0] = r.endPos[0]; goal[1] = r.endPos[1]; goal[2] = r.endPos[2];
                if (outLength) *outLength = r.length;
                found = true;
            }
        }
    }
    return found;
}

#define NAV_OWNER_FREE (-1)
#define NAV_OWNER_HUMAN (-2)
#define NAV_OWNER_HELD (-3)

static void NavCrowdRemove(int body, int idx) {
    NavBody& nb = g_NavBodies[body];
    if (!nb.crowd || idx < 0 || idx >= NAV_CROWD_AGENTS) return;
    nb.crowd->removeAgent(idx);
    nb.owner[idx] = NAV_OWNER_FREE;
}

static int NavCrowdAddWalker(int body, int slot, const float* sa, float speed, dtPolyRef endRef, const float* endSA) {
    NavBody& nb = g_NavBodies[body];
    if (!g_NavCrowdEnabled || !nb.crowd) return -1;
    dtCrowdAgentParams p;
    memset(&p, 0, sizeof(p));
    p.radius = nb.header.bodyRadius;
    p.height = nb.header.bodyHeight;
    p.maxAcceleration = 9.0f;
    p.maxSpeed = speed;
    p.collisionQueryRange = p.radius * 14.0f;
    p.pathOptimizationRange = p.radius * 30.0f;
    p.separationWeight = 0.2f;
    p.updateFlags = DT_CROWD_ANTICIPATE_TURNS | DT_CROWD_OBSTACLE_AVOIDANCE | DT_CROWD_SEPARATION | DT_CROWD_OPTIMIZE_VIS;
    float pos[3], tgt[3];
    NavToDetour(sa[0], sa[1], sa[2], pos);
    int idx = nb.crowd->addAgent(pos, &p);
    if (idx < 0) return -1;
    nb.owner[idx] = slot;
    nb.seen[idx] = true;
    NavToDetour(endSA[0], endSA[1], endSA[2], tgt);
    if (!nb.crowd->requestMoveTarget(idx, endRef, tgt)) { NavCrowdRemove(body, idx); return -1; }
    return idx;
}

static bool NavCrowdOwned(int body, int idx, int slot) {
    NavBody& nb = g_NavBodies[body];
    return nb.crowd && idx >= 0 && idx < NAV_CROWD_AGENTS && nb.owner[idx] == slot;
}

static void NavCrowdSetSpeed(int body, int idx, float speed) {
    NavBody& nb = g_NavBodies[body];
    const dtCrowdAgent* ag = nb.crowd->getAgent(idx);
    if (!ag || !ag->active || std::fabs(ag->params.maxSpeed - speed) < 0.01f) return;
    dtCrowdAgentParams p = ag->params;
    p.maxSpeed = speed;
    nb.crowd->updateAgentParameters(idx, &p);
}

static bool NavCrowdRead(int body, int idx, float* posSA, float* velSA, bool& targetFailed, dtPolyRef& ref) {
    NavBody& nb = g_NavBodies[body];
    const dtCrowdAgent* ag = nb.crowd->getAgent(idx);
    if (!ag || !ag->active || ag->state != DT_CROWDAGENT_STATE_WALKING) return false;
    float z;
    NavToSA(ag->npos, posSA[0], posSA[1], posSA[2]);
    z = 0;
    NavToSA(ag->vel, velSA[0], velSA[1], z);
    targetFailed = ag->targetState == DT_CROWDAGENT_TARGET_FAILED;
    ref = ag->corridor.getFirstPoly();
    return true;
}

static void NavCrowdBegin(int body) {
    NavBody& nb = g_NavBodies[body];
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) nb.seen[i] = false;
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) if (nb.owner[i] >= 0 && nb.crowd && nb.crowd->getAgent(i)->active) nb.seen[i] = true;
}

static void NavCrowdStatic(int body, int type, int key, float x, float y, float groundZ) {
    NavBody& nb = g_NavBodies[body];
    if (!nb.crowd) return;
    int idx = -1;
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) {
        if (nb.owner[i] == type && nb.ownerKey[i] == key) { idx = i; break; }
    }
    float pos[3];
    NavToDetour(x, y, groundZ, pos);
    if (idx < 0) {
        dtCrowdAgentParams p;
        memset(&p, 0, sizeof(p));
        p.radius = 0.4f;
        p.height = 1.8f;
        p.collisionQueryRange = 1.0f;
        p.pathOptimizationRange = 1.0f;
        idx = nb.crowd->addAgent(pos, &p);
        if (idx < 0) return;
        nb.owner[idx] = type;
        nb.ownerKey[idx] = key;
    }
    dtCrowdAgent* ag = nb.crowd->getEditableAgent(idx);
    ag->npos[0] = pos[0]; ag->npos[1] = pos[1]; ag->npos[2] = pos[2];
    ag->vel[0] = ag->vel[1] = ag->vel[2] = 0; ag->dvel[0] = ag->dvel[1] = ag->dvel[2] = 0; ag->nvel[0] = ag->nvel[1] = ag->nvel[2] = 0;
    nb.seen[idx] = true;
}

static void NavCrowdEnd(int body, float dt) {
    NavBody& nb = g_NavBodies[body];
    if (!nb.crowd) return;
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) {
        if (nb.owner[i] < -1 && !nb.seen[i]) NavCrowdRemove(body, i);
    }
    bool any = false;
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) if (nb.owner[i] >= 0) { any = true; break; }
    if (any) nb.crowd->update(dt, nullptr);
}

static int NavCrowdWalkerCount(int body) {
    NavBody& nb = g_NavBodies[body];
    int n = 0;
    for (int i = 0; i < NAV_CROWD_AGENTS; i++) if (nb.owner[i] >= 0) n++;
    return n;
}
