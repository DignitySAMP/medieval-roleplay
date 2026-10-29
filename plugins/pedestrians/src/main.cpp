#include "bridge.hpp"
#include "nav.hpp"
#include <nlohmann/json.hpp>
#include <fstream>
#include <random>
#include <algorithm>
#include <vector>
#include <cmath>
#include <iostream>
#include <unordered_set>
#include <unordered_map>
#include <chrono>
#include <map>
#include <cstdlib>

using json = nlohmann::json;

bool g_UseColAndreas = false;
bool g_AllowPedsInInteriors = false;

#define MAX_STREAM_ACTORS 500

int g_MaxActorsInPool = 500;
int g_CorpseTimeMs = 30000;
static const float PED_HEALTH = 25.0f;
int g_DebugLevel = 2;
bool g_NpcAsHuman = false;
#define PEDLOG(...) do { if (g_DebugLevel > 0) logprintf(__VA_ARGS__); } while (0)
#define PEDLOG2(...) do { if (g_DebugLevel > 1) logprintf(__VA_ARGS__); } while (0)
static bool g_RayHit = false, g_RayAccepted = false;
static float g_RayZ = 0.0f;
float g_PanicRadius = 50.0f;
int g_PanicDurationMs = 4000;
static const bool g_AmbientPanic = false;
uint64_t g_ShotPanicTick[1000] = {0};
int g_MaxActorsPerPlayer = 20;
float g_SpawnDensity = 1.0f;
float g_StreamingDistance = 220.0f;

std::unordered_set<uint32_t> g_IgnoredNodes;
static const float PED_INTERIOR_Z = 900.0f;

struct PedNode {
    int id;
    int area;
    float x, y, z;
    std::vector<uint32_t> links;
};

std::vector<PedNode> g_Nodes;
std::unordered_map<uint32_t, int> g_NodeIdToIndex;

enum {
    WALK_PLAYER = 0, WALK_CIVI, WALK_GANG1, WALK_GANG2,
    WALK_OLD, WALK_FATOLD, WALK_FAT, WOMAN_WALKOLD,
    WOMAN_WALKFATOLD, WALK_SHUFFLE, WOMAN_WALKNORM,
    WOMAN_WALKBUSY, WOMAN_WALKPRO, WOMAN_WALKSEXY,
    WALK_DRUNK, WALK_WUZI
};

const char* NameAnimations[] = {
    "WALK_player", "WALK_civi", "WALK_gang1", "WALK_gang2",
    "WALK_old", "WALK_fatold", "WALK_fat", "WOMAN_walkold",
    "WOMAN_walkfatold", "WALK_shuffle", "WOMAN_walknorm",
    "WOMAN_walkbusy", "WOMAN_walkpro", "WOMAN_walksexy",
    "WALK_drunk", "WALK_Wuzi"
};

std::vector<std::pair<int, int>> g_MaleSkins;
std::vector<std::pair<int, int>> g_FemaleSkins;
std::unordered_map<int, int> g_SkinWalkStyles;

uint64_t GetTimeMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()
    ).count();
}

#define PED_STATE_WALKING 1
#define PED_STATE_PANIC 2
#define PED_STATE_FALLEN 3
#define PED_STATE_STOPPED 4
#define PED_STATE_DEAD 5

#define AGGRO_NONE 0
#define AGGRO_HIT 1
#define AGGRO_CHASE 2
#define AGGRO_PUNCH 3

struct WalkingActor {
    int actorid;
    int skin;
    bool inUse;
    bool isDead;
    uint32_t currentNodeId;
    uint32_t targetNodeId;
    uint32_t previousNodeId;
    float currentX, currentY, currentZ;
    float speed;
    float currentAngle;
    float targetAngle;
    uint64_t lastUpdateTime;
    int walkStyle;
    uint64_t fallenTick;
    float health;
    int actionId;
    uint64_t actionTick;
    uint64_t panicTick;
    int state;
    int kind;
    uint64_t deadTick;
    bool hasTarget;
    float tgtX, tgtY, tgtZ;
    bool hasFleePoint;
    float fleeX, fleeY, fleeZ;
    bool aggroFlag;
    int aggroTarget;
    int aggroMode;
    uint64_t aggroTick;
    bool midPunch;
    bool knifeAlt;
    int surrenderBy;
    uint64_t scareTick;
    float steerOffset;
    uint64_t steerUntil;
    uint64_t nextObstacleCheck;
    uint64_t nextCurbCheck;
    bool nearHuman;
    uint64_t chokeUntil;
    uint64_t cutUntil;
    int cutBy;
    int gang;
    int packLeader;
    int packIndex;
    uint64_t huddleUntil;
    uint64_t nextHuddle;
    int gunTarget;
    uint64_t nextShot;
    uint64_t gangThink;
    bool following;
    uint64_t retargetAfter;
    uint64_t huddleAnimAt;
    float sentX, sentY, sentZ, sentAngle;
    bool sentValid;
    uint64_t holdUntil;
    float holdX, holdY;
    bool holdSettle;
    uint64_t dbgZAt, dbgBlockAt, dbgChaseAt, dbgPunchAt, dbgAnimAt;
    float trailX[8], trailY[8];
    int trailN;
    float homeX, homeY;
    int bloodObj1;
    bool scriptHold;
    bool floats;
    float floatZ;
    int body;
    dtPolyRef navRef;
    int navN, navIdx;
    float navPts[NAV_MAX_CORNERS * 3];
    float navEnd[3];
    dtPolyRef navEndRef;
    float navEndPos[3];
    uint64_t navNextPlan;
    bool navGoal;
    float goalX, goalY, goalZ;
    int crowdIdx;
    int crowdBody;
    uint64_t crowdBan;
    bool navOnMesh;
    uint64_t navRefTry;
    uint64_t crowdTick;
    bool navWaiting;
    uint64_t navFailUntil;
    int crowdIdxSeen;
    uint64_t crowdIdxAt;
    float crowdIdxDist;
};

WalkingActor g_Actors[MAX_STREAM_ACTORS];
std::unordered_map<int, int> g_SlotByActor;
int g_PlayerLastTarget[MAX_PLAYERS];
bool g_LastTargetInit = false;

static void MapActor(int actorid, int slot) {
    if (actorid >= 0 && actorid != 0xFFFF) g_SlotByActor[actorid] = slot;
}

static void UnmapActor(int actorid) {
    if (actorid >= 0 && actorid != 0xFFFF) g_SlotByActor.erase(actorid);
}

static void SendActorPos(int a, float x, float y, float z) {
    if (g_Actors[a].sentValid) {
        float dx = x - g_Actors[a].sentX, dy = y - g_Actors[a].sentY, dz = z - g_Actors[a].sentZ;
        if (dx*dx + dy*dy + dz*dz < 0.0004f) return;
        float jump = std::sqrt(dx*dx + dy*dy);
        if (jump > 0.4f || std::abs(dz) > 0.6f) {
            PEDLOG2("[Pedestrians] SNAP actor %d xy %.2f m z %.2f m (state %d aggro %d follow %d leader %d speed %.2f hold %d)", g_Actors[a].actorid, jump, dz, g_Actors[a].state, g_Actors[a].aggroMode, g_Actors[a].following ? 1 : 0, g_Actors[a].packLeader, g_Actors[a].speed, g_Actors[a].holdSettle ? 1 : 0);
        }
    }
    g_Actors[a].sentX = x; g_Actors[a].sentY = y; g_Actors[a].sentZ = z;
    g_Actors[a].sentValid = true;
    sampgdk_SetActorPos(g_Actors[a].actorid, x, y, z);
}

static void SendActorAngle(int a, float angle) {
    float d = angle - g_Actors[a].sentAngle;
    while (d > 180.0f) d -= 360.0f;
    while (d < -180.0f) d += 360.0f;
    if (g_Actors[a].sentValid && std::abs(d) < 1.0f) return;
    if (g_Actors[a].sentValid && std::abs(d) > 60.0f) {
        PEDLOG2("[Pedestrians] SPIN actor %d %.0f deg (state %d aggro %d follow %d)", g_Actors[a].actorid, d, g_Actors[a].state, g_Actors[a].aggroMode, g_Actors[a].following ? 1 : 0);
    }
    g_Actors[a].sentAngle = angle;
    sampgdk_SetActorFacingAngle(g_Actors[a].actorid, angle);
}

uint64_t g_LastStreamTick = 0;
uint64_t g_LastPhysicsTick = 0;
std::vector<AMX*> g_AMX;

std::vector<int> g_HumanPlayers;
bool g_PlayerHuman[1000];
struct PlayerHumanInit { PlayerHumanInit() { for (int i = 0; i < 1000; i++) g_PlayerHuman[i] = true; } } g_PlayerHumanInit;

void RebuildHumanPlayers() {
    g_HumanPlayers.clear();
    int poolSize = sampgdk_GetPlayerPoolSize();
    for (int i = 0; i <= poolSize && i < MAX_PLAYERS; i++) {
        if (sampgdk_IsPlayerConnected(i) && g_PlayerHuman[i] && (g_NpcAsHuman || !sampgdk_IsPlayerNPC(i))) {
            g_HumanPlayers.push_back(i);
        }
    }
}

struct ZoneSkin {
    std::string name;
    float minX, minY, minZ;
    float maxX, maxY, maxZ;
    int maxPeds;
    std::vector<int> skins[4];
};

std::vector<ZoneSkin> g_Zones;
std::vector<int> g_DefaultSkins;
int g_ServerHour = 12;
int g_ServerMinute = 0;

bool IsFemaleSkin(int skinId) {
    for (const auto& s : g_FemaleSkins) {
        if (s.first == skinId) return true;
    }
    for (const auto& s : g_MaleSkins) {
        if (s.first == skinId) return false;
    }
    auto it = g_SkinWalkStyles.find(skinId);
    if (it != g_SkinWalkStyles.end()) {
        int ws = it->second;
        if (ws == WOMAN_WALKOLD || ws == WOMAN_WALKFATOLD || ws == WOMAN_WALKNORM ||
            ws == WOMAN_WALKBUSY || ws == WOMAN_WALKPRO || ws == WOMAN_WALKSEXY) {
            return true;
        }
    }
    return false;
}

bool LoadZoneSkins() {
    std::ifstream file("scriptfiles/zone_skins.json");
    if (!file.is_open()) {
        file.open("zone_skins.json");
        if (!file.is_open()) {
            logprintf("[Pedestrians] WARNING: Could not open zone_skins.json in scriptfiles/ or root directory.");
            return false;
        }
    }

    try {
        json j;
        file >> j;

        g_DefaultSkins.clear();
        if (j.contains("default_skins") && j["default_skins"].is_array()) {
            for (auto& s : j["default_skins"]) {
                g_DefaultSkins.push_back(s.get<int>());
            }
        }
        if (g_DefaultSkins.empty()) {
            g_DefaultSkins = {7, 10, 14, 15, 17, 19, 20, 21, 22, 23, 24, 25, 28, 29};
        }

        g_SkinWalkStyles.clear();
        if (j.contains("skin_walkstyles") && j["skin_walkstyles"].is_object()) {
            for (auto& [key, val] : j["skin_walkstyles"].items()) {
                int skinId = std::stoi(key);
                int wsIndex = val.get<int>();
                g_SkinWalkStyles[skinId] = wsIndex;
            }
        }

        g_Zones.clear();
        if (j.contains("zones") && j["zones"].is_array()) {
            for (auto& z : j["zones"]) {
                ZoneSkin zs;
                zs.name = z.value("name", "");
                zs.minX = z["min"][0].get<float>();
                zs.minY = z["min"][1].get<float>();
                zs.minZ = z["min"][2].get<float>();
                zs.maxX = z["max"][0].get<float>();
                zs.maxY = z["max"][1].get<float>();
                zs.maxZ = z["max"][2].get<float>();
                zs.maxPeds = z.value("max_peds", 12);

                if (z.contains("skins") && z["skins"].is_object()) {
                    auto& sk = z["skins"];
                    if (sk.contains("morning")) for (auto& s : sk["morning"]) zs.skins[0].push_back(s.get<int>());
                    if (sk.contains("day")) for (auto& s : sk["day"]) zs.skins[1].push_back(s.get<int>());
                    if (sk.contains("evening")) for (auto& s : sk["evening"]) zs.skins[2].push_back(s.get<int>());
                    if (sk.contains("night")) for (auto& s : sk["night"]) zs.skins[3].push_back(s.get<int>());
                }
                g_Zones.push_back(zs);
            }
        }
        logprintf("[Pedestrians] Loaded %d zones, %d skin walkstyles, %d default skins",
            (int)g_Zones.size(), (int)g_SkinWalkStyles.size(), (int)g_DefaultSkins.size());
        return true;
    } catch (const std::exception& e) {
        logprintf("[Pedestrians] ERROR parsing zone_skins.json: %s", e.what());
        return false;
    }
}

int GetTimeSlot() {
    if (g_ServerHour >= 5 && g_ServerHour < 12) return 0;
    if (g_ServerHour >= 12 && g_ServerHour < 18) return 1;
    if (g_ServerHour >= 18 && g_ServerHour < 22) return 2;
    return 3;
}

int GetMaxPedsForPosition(float x, float y, float z) {
    for (const auto& zone : g_Zones) {
        if (x >= zone.minX && x <= zone.maxX &&
            y >= zone.minY && y <= zone.maxY) {
            return zone.maxPeds;
        }
    }
    return 10;
}

int GetSkinForPosition(float x, float y, float z) {
    static std::mt19937 rng(std::random_device{}());
    int timeSlot = GetTimeSlot();

    std::unordered_set<int> nearbySkins;
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse) {
            float adx = g_Actors[a].currentX - x;
            float ady = g_Actors[a].currentY - y;
            if (adx*adx + ady*ady <= 10000.0f) {
                nearbySkins.insert(g_Actors[a].skin);
            }
        }
    }

    for (const auto& zone : g_Zones) {
        if (x >= zone.minX && x <= zone.maxX &&
            y >= zone.minY && y <= zone.maxY) {

            bool isBeachZone = (zone.name == "SANTA_MARIA_BEACH_CUSTOM" || zone.name.find("BEACH") != std::string::npos);
            if (isBeachZone) {
                std::uniform_int_distribution<int> roll(0, 99);
                if (roll(rng) >= 40) {
                    continue;
                }
            }

            const auto& skins = zone.skins[timeSlot];
            if (!skins.empty()) {
                std::vector<int> uniqueSkins;
                for (int s : skins) {
                    if (nearbySkins.find(s) == nearbySkins.end()) {
                        uniqueSkins.push_back(s);
                    }
                }
                if (!uniqueSkins.empty()) {
                    std::uniform_int_distribution<size_t> dist(0, uniqueSkins.size() - 1);
                    return uniqueSkins[dist(rng)];
                }
                std::uniform_int_distribution<size_t> dist(0, skins.size() - 1);
                return skins[dist(rng)];
            }
        }
    }
    if (!g_DefaultSkins.empty()) {
        std::uniform_int_distribution<size_t> dist(0, g_DefaultSkins.size() - 1);
        return g_DefaultSkins[dist(rng)];
    }
    const size_t registered = g_MaleSkins.size() + g_FemaleSkins.size();
    if (registered > 0) {
        std::uniform_int_distribution<size_t> dist(0, registered - 1);
        const size_t pick = dist(rng);
        return pick < g_MaleSkins.size() ? g_MaleSkins[pick].first : g_FemaleSkins[pick - g_MaleSkins.size()].first;
    }
    return 7;
}

int GetWalkStyleForSkin(int skinId) {
    auto it = g_SkinWalkStyles.find(skinId);
    if (it != g_SkinWalkStyles.end()) {
        return it->second;
    }
    return 1;
}

static int SlotOf(int actorid);
std::vector<std::pair<int, uint64_t>> g_PendingBlood;

void CallPedCallback1(const char* name, int actorid) {
    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, name, &idx)) {
            amx_Push(amx, actorid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }
}

void SetPedState(int a, int newState) {
    if (g_Actors[a].state != newState) {
        int oldState = g_Actors[a].state;
        g_Actors[a].state = newState;
        for (AMX* amx : g_AMX) {
            int idx;
            if (!amx_FindPublic(amx, "OnPedestrianStateChange", &idx)) {
                amx_Push(amx, newState);
                amx_Push(amx, oldState);
                amx_Push(amx, g_Actors[a].actorid);
                cell ret;
                amx_Exec(amx, &ret, idx);
            }
        }
    }
}

static void RunAnimFor(int a, const char*& anim, float& speed) {
    bool female = IsFemaleSkin(g_Actors[a].skin);
    anim = female ? "woman_run" : "run_civi";
    speed = female ? 4.175f : 4.35f;
    switch (g_Actors[a].walkStyle) {
        case WALK_PLAYER: anim = "run_player"; speed = 5.8f; break;
        case WALK_GANG1: case WALK_GANG2: anim = "run_gang1"; speed = 4.415f; break;
        case WALK_OLD: case WALK_SHUFFLE: case WOMAN_WALKOLD: anim = "run_old"; speed = 2.7f; break;
        case WALK_FATOLD: anim = "run_fatold"; speed = 2.62f; break;
        case WOMAN_WALKFATOLD: anim = "WOMAN_runfatold"; speed = 2.62f; break;
        case WALK_FAT: anim = "run_fat"; speed = 2.61f; break;
        case WALK_WUZI: anim = "Run_Wuzi"; speed = 5.53f; break;
        case WOMAN_WALKBUSY: anim = "WOMAN_runbusy"; speed = 3.885f; break;
        case WOMAN_WALKSEXY: anim = "WOMAN_runsexy"; speed = 3.9f; break;
        default: break;
    }
}

static void StartPanicRun(int a) {
    bool female = IsFemaleSkin(g_Actors[a].skin);
    sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", female ? "woman_runpanic" : "sprint_panic", 4.1f, true, true, true, false, 0);
    g_Actors[a].speed = female ? 5.05f : 5.95f;
}

static const int BLOOD_MODEL = 19836;
struct BloodSplat { int objectid; uint64_t until; };
static std::vector<BloodSplat> g_BloodSplats;

static void BloodSplatAt(int a) {
    int obj = sampgdk_CreateObject(BLOOD_MODEL, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ + 0.03f, 0.0f, 0.0f, (float)(rand() % 360), 60.0f);
    if (obj == 0xFFFF || obj < 0) return;
    g_BloodSplats.push_back({obj, GetTimeMs() + 500});
}

static void BloodSplatTick(uint64_t now) {
    for (auto it = g_BloodSplats.begin(); it != g_BloodSplats.end();) {
        if (it->until <= now) { sampgdk_DestroyObject(it->objectid); it = g_BloodSplats.erase(it); }
        else ++it;
    }
}

static void BloodPoolDrop(int a) {
    if (g_Actors[a].bloodObj1 != 0) { sampgdk_DestroyObject(g_Actors[a].bloodObj1 - 1); g_Actors[a].bloodObj1 = 0; }
}

static void BloodPoolAt(int a) {
    BloodPoolDrop(a);
    int obj = sampgdk_CreateObject(BLOOD_MODEL, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ + 0.03f, 0.0f, 0.0f, (float)(rand() % 360), 60.0f);
    if (obj == 0xFFFF || obj < 0) return;
    g_Actors[a].bloodObj1 = obj + 1;
}

static void FleeBystandersFromViolence(int source);

void TriggerPedDeath(int a, int killerid, int reason) {
    if (g_Actors[a].isDead) return;
    g_Actors[a].isDead = true;
    g_Actors[a].speed = 0.0f;
    g_Actors[a].hasTarget = false;
    g_Actors[a].hasFleePoint = false;
    g_Actors[a].deadTick = GetTimeMs();
    g_Actors[a].aggroMode = AGGRO_NONE;
    g_Actors[a].aggroTarget = -1;
    g_Actors[a].surrenderBy = -1;
    g_Actors[a].scareTick = 0;
    SetPedState(a, PED_STATE_DEAD);
    sampgdk_ClearActorAnimations(g_Actors[a].actorid);
    sampgdk_SetActorHealth(g_Actors[a].actorid, 0.0f);
    BloodPoolAt(a);
    FleeBystandersFromViolence(a);

    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, "OnPedestrianDeath", &idx)) {
            amx_Push(amx, reason);
            amx_Push(amx, killerid);
            amx_Push(amx, g_Actors[a].actorid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }
}

void ApplyDamage(int a, float amount, int killerid, int reason) {
    if (g_Actors[a].isDead || amount <= 0.0f) return;
    g_Actors[a].health -= amount;
    if (g_Actors[a].health <= 0.0f) {
        TriggerPedDeath(a, killerid, reason);
    } else {
        FleeBystandersFromViolence(a);
        float bar = g_Actors[a].health / PED_HEALTH * 100.0f;
        if (bar > 100.0f) bar = 100.0f;
        if (bar < 1.0f) bar = 1.0f;
        sampgdk_SetActorHealth(g_Actors[a].actorid, bar);
        uint64_t now = GetTimeMs();
        if (g_Actors[a].gang == 0 && g_Actors[a].fallenTick == 0 && g_Actors[a].actionId == 0) {
            StartPanicRun(a);
            g_Actors[a].panicTick = now + 4000;
            SetPedState(a, PED_STATE_PANIC);
        }
    }
}

inline int FindNodeIndex(uint32_t id) {
    auto it = g_NodeIdToIndex.find(id);
    if (it != g_NodeIdToIndex.end()) {
        return it->second;
    }
    return -1;
}

int PickNextNode(int currentIdx, int previousNodeId) {
    if (currentIdx < 0 || (size_t)currentIdx >= g_Nodes.size()) return -1;
    const auto& links = g_Nodes[currentIdx].links;
    if (links.empty()) return g_Nodes[currentIdx].id;

    std::vector<int> validLinks;
    for (uint32_t linkId : links) {
        if ((int)linkId != previousNodeId && g_IgnoredNodes.count(linkId) == 0) {
            int linkIdx = FindNodeIndex(linkId);
            if (linkIdx != -1) validLinks.push_back((int)linkId);
        }
    }

    if (validLinks.empty()) {
        for (uint32_t linkId : links) {
            if (FindNodeIndex(linkId) != -1) return (int)linkId;
        }
        return g_Nodes[currentIdx].id;
    }

    static std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<size_t> dist(0, validLinks.size() - 1);
    return validLinks[dist(rng)];
}

int PickFarthestLink(int currentIdx, float fx, float fy, float fz) {
    if (currentIdx < 0 || (size_t)currentIdx >= g_Nodes.size()) return -1;
    const auto& links = g_Nodes[currentIdx].links;
    int best = -1;
    float bestDist = -1.0f;
    for (uint32_t linkId : links) {
        if (g_IgnoredNodes.count(linkId) != 0) continue;
        int linkIdx = FindNodeIndex(linkId);
        if (linkIdx == -1) continue;
        float dx = g_Nodes[linkIdx].x - fx;
        float dy = g_Nodes[linkIdx].y - fy;
        float dz = g_Nodes[linkIdx].z - fz;
        float d = dx*dx + dy*dy + dz*dz;
        if (d > bestDist) {
            bestDist = d;
            best = (int)linkId;
        }
    }
    return best;
}

static int GangAt(float x, float y);

static int PickTurfLink(int a, int currentIdx) {
    if (currentIdx < 0 || (size_t)currentIdx >= g_Nodes.size()) return -1;
    const auto& links = g_Nodes[currentIdx].links;
    std::vector<int> inZone;
    int nearest = -1;
    float nearestD = 1e30f;
    for (uint32_t linkId : links) {
        if ((int)linkId == g_Actors[a].previousNodeId || g_IgnoredNodes.count(linkId) != 0) continue;
        int idx = FindNodeIndex(linkId);
        if (idx == -1) continue;
        if (GangAt(g_Nodes[idx].x, g_Nodes[idx].y) == g_Actors[a].gang) inZone.push_back((int)linkId);
        float dx = g_Nodes[idx].x - g_Actors[a].homeX, dy = g_Nodes[idx].y - g_Actors[a].homeY;
        float d = dx*dx + dy*dy;
        if (d < nearestD) { nearestD = d; nearest = (int)linkId; }
    }
    if (!inZone.empty()) return inZone[rand() % inZone.size()];
    return nearest;
}

int PickNextNodeFor(int a, int currentIdx) {
    if (g_Actors[a].hasFleePoint && g_Actors[a].panicTick > GetTimeMs()) {
        int far = PickFarthestLink(currentIdx, g_Actors[a].fleeX, g_Actors[a].fleeY, g_Actors[a].fleeZ);
        if (far != -1) return far;
    }
    g_Actors[a].hasFleePoint = false;
    if (g_Actors[a].gang != 0 && g_Actors[a].packLeader == -1) {
        int turf = PickTurfLink(a, currentIdx);
        if (turf != -1) return turf;
    }
    return PickNextNode(currentIdx, g_Actors[a].previousNodeId);
}

void SnapToGraph(int a) {
    int bestIdx = -1;
    float bestDist = 1e30f;
    for (size_t i = 0; i < g_Nodes.size(); i++) {
        float dx = g_Nodes[i].x - g_Actors[a].currentX;
        float dy = g_Nodes[i].y - g_Actors[a].currentY;
        float d = dx*dx + dy*dy;
        if (d < bestDist) {
            bestDist = d;
            bestIdx = (int)i;
        }
    }
    if (bestIdx == -1) return;
    g_Actors[a].previousNodeId = g_Nodes[bestIdx].id;
    g_Actors[a].currentNodeId = g_Nodes[bestIdx].id;
    g_Actors[a].targetNodeId = g_Nodes[bestIdx].id;
    g_Actors[a].hasTarget = false;
}

bool LoadPedPaths() {
    g_Nodes.clear();
    g_NodeIdToIndex.clear();
    if (!Bridge_LoadNodes(g_Nodes)) {
        logprintf("[Pedestrians] ERROR: the paths component has no ped layer, no nodes loaded");
        return false;
    }
    g_NodeIdToIndex.reserve(g_Nodes.size());
    for (size_t i = 0; i < g_Nodes.size(); i++) {
        g_NodeIdToIndex[(uint32_t)g_Nodes[i].id] = (int)i;
    }
    logprintf("[Pedestrians] %d pedestrian nodes from the paths component's ped layer (interior nodes never exist there)", (int)g_Nodes.size());
    return true;
}

void SetActorWalk(int slot, uint32_t startNode, float speed) {
    int startIdx = FindNodeIndex(startNode);
    if (startIdx == -1) return;

    g_Actors[slot].speed = speed;
    g_Actors[slot].currentNodeId = startNode;
    g_Actors[slot].previousNodeId = startNode;
    g_Actors[slot].currentX = g_Nodes[startIdx].x;
    g_Actors[slot].currentY = g_Nodes[startIdx].y;
    g_Actors[slot].currentZ = g_Nodes[startIdx].z;
    g_Actors[slot].lastUpdateTime = GetTimeMs();

    g_Actors[slot].targetNodeId = PickNextNode(startIdx, startNode);

    int targetIdx = FindNodeIndex(g_Actors[slot].targetNodeId);
    if (targetIdx != -1) {
        float dx = g_Nodes[targetIdx].x - g_Actors[slot].currentX;
        float dy = g_Nodes[targetIdx].y - g_Actors[slot].currentY;
        g_Actors[slot].targetAngle = std::atan2(-dx, dy) * (180.0f / 3.14159265f);
        g_Actors[slot].currentAngle = g_Actors[slot].targetAngle;
    }
}

bool RayCastTerrain(float x, float y, float currentZ, float targetZ, float& outZ) {
    if (!g_UseColAndreas) return false;
    float hx = 0.0f, hy = 0.0f, caZ = 0.0f;
    int ret = Bridge_RayCast(x, y, currentZ + 3.0f, x, y, currentZ - 4.0f, &hx, &hy, &caZ);
    g_RayHit = (ret != 0);
    g_RayAccepted = false;
    g_RayZ = 0.0f;
    if (ret != 0) {
        g_RayZ = caZ;
        if (targetZ == 0.0f || std::abs(caZ - targetZ) <= 3.5f) {
            outZ = caZ;
            g_RayAccepted = true;
            return true;
        }
    }
    return false;
}

static bool RayCastSpawn(float x, float y, float z, float& outZ) {
    if (!g_UseColAndreas) return false;
    float hx = 0.0f, hy = 0.0f, hz = 0.0f;
    if (Bridge_RayCast(x, y, z + 3.0f, x, y, z - 12.0f, &hx, &hy, &hz) == 0) return false;
    outZ = hz;
    return true;
}

static bool RayCastGround(float x, float y, float currentZ, float& outZ) {
    if (!g_UseColAndreas) return false;
    float hx = 0.0f, hy = 0.0f, z = 0.0f;
    int ret = Bridge_RayCast(x, y, currentZ + 1.5f, x, y, currentZ - 2.5f, &hx, &hy, &z);
    g_RayHit = (ret != 0);
    g_RayAccepted = false;
    g_RayZ = 0.0f;
    if (ret != 0) {
        g_RayZ = z;
        if (z - currentZ <= 0.8f && currentZ - z <= 2.0f) { outZ = z; g_RayAccepted = true; return true; }
    }
    if (RayCastTerrain(x, y, currentZ, 0.0f, outZ)) return true;
    return RayCastSpawn(x, y, currentZ, outZ);
}

static std::vector<int> g_PathFailed;
static uint64_t g_NavPlans = 0, g_NavPlanFails = 0, g_NavOffMesh = 0;
static uint64_t g_NavFleeMesh = 0, g_NavFleeNoGoal = 0, g_NavFleeUnusable = 0;
static uint64_t g_NavLegsOk = 0, g_NavLegsFail = 0, g_NavTargetFails = 0, g_NavStalls = 0, g_NavFailReason[5] = {0, 0, 0, 0, 0};
static uint64_t g_PhysTicks = 0, g_PhysUs = 0, g_PhysMaxUs = 0, g_NavUs = 0, g_CrowdUs = 0;
static NavRoute g_ScratchRoute;
static std::vector<uint32_t> g_PhysSamples;
static inline uint64_t NowUs() { return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }

static int ActorBody(int a) {
    int b = g_Actors[a].body;
    return b >= 0 && b < NAV_BODY_COUNT ? b : NavBodyForKind(g_Actors[a].kind);
}

static bool NavUsable(int a) {
    const WalkingActor& w = g_Actors[a];
    if (!g_NavEnabled || w.floats || w.kind >= 100 || w.currentZ > PED_INTERIOR_Z) return false;
    return NavReady(ActorBody(a));
}

static void NavCrowdDrop(int a) {
    WalkingActor& w = g_Actors[a];
    if (w.crowdIdx >= 0) {
        if (NavCrowdOwned(w.crowdBody, w.crowdIdx, a)) NavCrowdRemove(w.crowdBody, w.crowdIdx);
        w.crowdIdx = -1;
    }
}

static void NavReset(int a) {
    WalkingActor& w = g_Actors[a];
    NavCrowdDrop(a);
    w.navRef = 0;
    w.navN = 0;
    w.navIdx = 0;
    w.navGoal = false;
    w.navNextPlan = 0;
    w.navRefTry = 0;
    w.crowdIdx = -1;
    w.crowdBan = 0;
    w.navOnMesh = false;
    w.navFailUntil = 0;
    w.navWaiting = false;
}

static bool NavEnsureRef(int a, uint64_t now) {
    WalkingActor& w = g_Actors[a];
    if (w.navRef) return true;
    if (now < w.navRefTry) return false;
    w.navRefTry = now + 1000;
    dtPolyRef ref;
    float snap[3];
    int body = ActorBody(a);
    if (!NavFindPoly(body, w.currentX, w.currentY, w.currentZ, NAV_START_EXT, ref, snap)) { g_NavOffMesh++; return false; }
    float dx = snap[0] - w.currentX, dy = snap[1] - w.currentY;
    if (dx * dx + dy * dy > 1.0f) { g_NavOffMesh++; return false; }
    w.navRef = ref;
    w.currentX = snap[0];
    w.currentY = snap[1];
    w.currentZ = snap[2];
    w.sentValid = false;
    return true;
}

static bool NavFollow(int a, float tx, float ty, float tz, uint64_t now, float& dist2D) {
    WalkingActor& w = g_Actors[a];
    int body = ActorBody(a);
    bool have = w.navN > 0;
    float ex = w.navEnd[0] - tx, ey = w.navEnd[1] - ty;
    float moved = ex * ex + ey * ey;
    if (!have && now < w.navFailUntil) return false;
    if (!have || moved >= 2.25f) {
        if (have && now < w.navFailUntil) {
        } else if (have && moved < 16.0f && now < w.navNextPlan) {
        } else {
            float from[3] = {w.currentX, w.currentY, w.currentZ}, to[3] = {tx, ty, tz};
            g_NavPlans++;
            w.navNextPlan = now + 400;
            if (!NavBuildRoute(body, from, to, g_ScratchRoute, w.navRef)) {
                g_NavPlanFails++;
                g_NavFailReason[std::min(std::max(g_ScratchRoute.fail, 0), 4)]++;
                static int logged = 0;
                if (logged < 60) {
                    logged++;
                    logprintf("[Pedestrians] navfail actor %d kind %d state %d body %d: reason %d (1 start poly, 2 end poly, 3 unreachable) from (%.1f, %.1f, %.1f) ref %u snap %.2f to (%.1f, %.1f, %.1f) snap %.2f polys %d hasTarget %d goal %d",
                        w.actorid, w.kind, w.state, body, g_ScratchRoute.fail, from[0], from[1], from[2], (unsigned)w.navRef, g_ScratchRoute.startSnap, to[0], to[1], to[2], g_ScratchRoute.endSnap, g_ScratchRoute.pathPolys, w.hasTarget ? 1 : 0, w.navGoal ? 1 : 0);
                }
                if (have) {
                    w.navFailUntil = now + 1500;
                    return true;
                }
                w.navN = 0;
                return false;
            }
            g_NavLegsOk++;
            w.navWaiting = false;
            w.navN = g_ScratchRoute.n;
            w.navIdx = g_ScratchRoute.n > 1 ? 1 : 0;
            memcpy(w.navPts, g_ScratchRoute.pts, sizeof(float) * 3 * g_ScratchRoute.n);
            w.navEnd[0] = tx; w.navEnd[1] = ty; w.navEnd[2] = tz;
            w.navEndRef = g_ScratchRoute.endRef;
            memcpy(w.navEndPos, g_ScratchRoute.endPos, sizeof(w.navEndPos));
            NavCrowdDrop(a);
        }
    }
    float cx = w.currentX, cy = w.currentY;
    while (w.navIdx < w.navN - 1) {
        float dx = w.navPts[w.navIdx * 3] - cx, dy = w.navPts[w.navIdx * 3 + 1] - cy;
        if (dx * dx + dy * dy < (w.crowdIdx >= 0 ? 1.0f : 0.25f)) w.navIdx++; else break;
    }
    int last = w.navN - 1;
    float lx = w.navPts[last * 3] - cx, ly = w.navPts[last * 3 + 1] - cy;
    if (w.navIdx >= last && lx * lx + ly * ly < 0.36f) {
        float fx = w.navPts[last * 3] - tx, fy = w.navPts[last * 3 + 1] - ty;
        if (w.navN < NAV_MAX_CORNERS || fx * fx + fy * fy < 6.25f) dist2D = 0.0f;
        else { w.navEnd[0] = 1e9f; w.navNextPlan = 0; }
    }
    return true;
}

static std::unordered_set<uint64_t> g_NavDeadLegs[NAV_BODY_COUNT];
static inline uint64_t NavLegKey(int from, int to) { return ((uint64_t)(uint32_t)from << 32) | (uint32_t)to; }

static bool NavDeadLeg(int a) {
    const WalkingActor& w = g_Actors[a];
    return !w.hasTarget && !w.navGoal && g_NavDeadLegs[ActorBody(a)].count(NavLegKey(w.currentNodeId, w.targetNodeId)) != 0;
}

static void NavNoteDeadLeg(int a, int toNode) {
    const WalkingActor& w = g_Actors[a];
    int cur = FindNodeIndex(w.currentNodeId);
    if (cur < 0 || g_ScratchRoute.fail != 3) return;
    float dx = g_Nodes[cur].x - w.currentX, dy = g_Nodes[cur].y - w.currentY;
    if (dx * dx + dy * dy > 9.0f || std::fabs(g_Nodes[cur].z - w.currentZ) > 2.5f) return;
    g_NavDeadLegs[ActorBody(a)].insert(NavLegKey(w.currentNodeId, toNode));
}

static bool NavRepickLeg(int a, uint64_t now, float& tx, float& ty, float& tz, float& dist2D) {
    WalkingActor& w = g_Actors[a];
    int cur = FindNodeIndex(w.currentNodeId);
    std::vector<int> cands;
    if (cur >= 0) {
        for (uint32_t l : g_Nodes[cur].links) {
            if (g_IgnoredNodes.count(l) != 0 || (int)l == w.targetNodeId || FindNodeIndex(l) == -1) continue;
            if (g_NavDeadLegs[ActorBody(a)].count(NavLegKey(w.currentNodeId, (int)l)) != 0) continue;
            cands.push_back((int)l);
        }
    }
    if (w.previousNodeId != w.currentNodeId && FindNodeIndex(w.previousNodeId) != -1 && std::find(cands.begin(), cands.end(), w.previousNodeId) == cands.end() && w.previousNodeId != w.targetNodeId) cands.push_back(w.previousNodeId);
    static std::mt19937 rng(std::random_device{}());
    std::shuffle(cands.begin(), cands.end(), rng);
    for (int id : cands) {
        int idx = FindNodeIndex(id);
        float nx = g_Nodes[idx].x, ny = g_Nodes[idx].y, nz = g_Nodes[idx].z;
        w.navN = 0;
        w.navFailUntil = 0;
        float d = std::sqrt((nx - w.currentX) * (nx - w.currentX) + (ny - w.currentY) * (ny - w.currentY));
        if (NavFollow(a, nx, ny, nz, now, d)) {
            w.targetNodeId = id;
            tx = nx; ty = ny; tz = nz;
            dist2D = d;
            return true;
        }
        NavNoteDeadLeg(a, id);
    }
    w.navN = 0;
    return false;
}

static void NavFail(int actorid) {
    g_PathFailed.push_back(actorid);
}

static bool NavStartFlee(int a, float x, float y, float z) {
    WalkingActor& w = g_Actors[a];
    uint64_t now = GetTimeMs();
    if (!NavUsable(a) || !NavEnsureRef(a, now)) { g_NavFleeUnusable++; return false; }
    float from[3] = {w.currentX, w.currentY, w.currentZ}, thr[3] = {x, y, z}, goal[3];
    if (!NavFleeGoal(ActorBody(a), from, thr, goal, nullptr)) { g_NavFleeNoGoal++; return false; }
    g_NavFleeMesh++;
    NavCrowdDrop(a);
    w.navGoal = true;
    w.goalX = goal[0]; w.goalY = goal[1]; w.goalZ = goal[2];
    w.hasTarget = false;
    w.navN = 0;
    w.navNextPlan = 0;
    return true;
}

static const float AGGRO_GIVE_UP = 50.0f;
static const float AGGRO_PUNCH_MAX = 1.2f;
static const float AGGRO_PUNCH_MIN = 0.5f;
static const float AGGRO_CLOSE = 5.0f;
static const float AGGRO_HEIGHT = 2.0f;
static const float AGGRO_STEP = 2.0f;
static const float AGGRO_STEP_SPEED = 2.7f;
static const float AGGRO_FRONT_PUSH = 5.0f;
static const float AGGRO_SOUND_RANGE = 25.0f;
static const int AGGRO_THINK_MS = 250;
static const int AGGRO_SIDE_HIT_MS = 1000;
static const int AGGRO_IDLE_MS = 1000;
static const int AGGRO_IDLE_LONG_MS = 1500;
static const int AGGRO_MISS_MS = 400;
static const int AGGRO_RECOVER_MS = 700;
static const int AGGRO_KICK_MS = 930;
static const int AGGRO_PUNCH_MS[3] = {420, 760, 860};
static const float AGGRO_NUDGE_SPEED[3] = {1.0f, 1.35f, 1.75f};
static const int AGGRO_BLOCK_ANIMS[] = {1139, 753, 497, 486, 485, 475, 426, 21, 1549};
static const int SURRENDER_SCARE_MS = 200;
static const int SURRENDER_ANIMS = 4;
static const char* SURRENDER_LIB[SURRENDER_ANIMS] = {"ped", "SHOP", "SHOP", "SHOP"};
static const char* SURRENDER_NAME[SURRENDER_ANIMS] = {"handsup", "SHP_HandsUp_Scr", "SHP_Rob_HandsUp", "SHP_Rob_React"};

static int SlotOf(int actorid) {
    auto it = g_SlotByActor.find(actorid);
    if (it == g_SlotByActor.end()) return -1;
    int a = it->second;
    if (a < 0 || a >= g_MaxActorsInPool || !g_Actors[a].inUse || g_Actors[a].actorid != actorid) return -1;
    return a;
}

static float NormAngle(float a) {
    while (a < 0.0f) a += 360.0f;
    while (a >= 360.0f) a -= 360.0f;
    return a;
}

static float AngleTo(float fx, float fy, float tx, float ty) {
    return NormAngle(std::atan2(-(tx - fx), ty - fy) * (180.0f / 3.14159265f));
}

static void OffsetPoint(float x, float y, float angle, float dist, float& ox, float& oy) {
    float rad = -angle * (3.14159265f / 180.0f);
    ox = x + std::sin(rad) * dist;
    oy = y + std::cos(rad) * dist;
}

static void PedAnim(int a, const char* lib, const char* name, bool loop, bool freeze, int time) {
    if (g_DebugLevel > 1 && (g_Actors[a].aggroMode != 0 || g_Actors[a].packLeader != -1 || g_Actors[a].kind >= 100)) {
        uint64_t t = GetTimeMs();
        logprintf("[Pedestrians] anim actor %d %s/%s loop %d freeze %d (+%llu ms) aggro %d", g_Actors[a].actorid, lib, name, loop ? 1 : 0, freeze ? 1 : 0, (unsigned long long)(g_Actors[a].dbgAnimAt ? t - g_Actors[a].dbgAnimAt : 0), g_Actors[a].aggroMode);
        g_Actors[a].dbgAnimAt = t;
    }
    sampgdk_ApplyActorAnimation(g_Actors[a].actorid, lib, name, 4.1f, loop, true, true, freeze, time);
}

static void SoundAround(float x, float y, float z, int soundid, float range) {
    for (int p : g_HumanPlayers) {
        if (sampgdk_IsPlayerInRangeOfPoint(p, range, x, y, z)) {
            sampgdk_PlayerPlaySound(p, soundid, x, y, z);
        }
    }
}

static void FaceSlot(int a, float angle) {
    angle = NormAngle(angle);
    g_Actors[a].currentAngle = angle;
    g_Actors[a].targetAngle = angle;
    SendActorAngle(a, angle);
}

static void StopSlot(int a) {
    if (g_Actors[a].aggroMode != 0) PEDLOG2("[Pedestrians] stop+clearanims actor %d (aggro %d speed %.2f)", g_Actors[a].actorid, g_Actors[a].aggroMode, g_Actors[a].speed);
    g_Actors[a].holdUntil = 0;
    g_Actors[a].holdSettle = false;
    g_Actors[a].speed = 0.0f;
    g_Actors[a].hasTarget = false;
    sampgdk_ClearActorAnimations(g_Actors[a].actorid);
    g_Actors[a].sentAngle = g_Actors[a].currentAngle;
    sampgdk_SetActorFacingAngle(g_Actors[a].actorid, g_Actors[a].currentAngle);
    SetPedState(a, PED_STATE_STOPPED);
}

static void ResumeSlot(int a) {
    if (g_Actors[a].hasTarget || g_Actors[a].state == PED_STATE_STOPPED) {
        SnapToGraph(a);
    }
    g_Actors[a].hasFleePoint = false;
    g_Actors[a].speed = 1.2f;
    g_Actors[a].lastUpdateTime = GetTimeMs();
    sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", NameAnimations[g_Actors[a].walkStyle], 4.1f, true, true, true, false, 0);
    SetPedState(a, PED_STATE_WALKING);
}

static void WalkSlotTo(int a, float x, float y, float z, float speed) {
    g_Actors[a].tgtX = x;
    g_Actors[a].tgtY = y;
    g_Actors[a].tgtZ = z;
    g_Actors[a].speed = speed;
    bool wasMoving = g_Actors[a].hasTarget && g_Actors[a].speed > 0.0f;
    g_Actors[a].hasTarget = true;
    g_Actors[a].hasFleePoint = false;
    g_Actors[a].panicTick = 0;
    if (!wasMoving) g_Actors[a].lastUpdateTime = GetTimeMs();
    if (g_Actors[a].state != PED_STATE_WALKING) SetPedState(a, PED_STATE_WALKING);
}

static void PanicSlot(int a, int ms) {
    StartPanicRun(a);
    g_Actors[a].hasTarget = false;
    g_Actors[a].panicTick = GetTimeMs() + ms;
    SetPedState(a, PED_STATE_PANIC);
}

static void AggroSchedule(int a, int ms) {
    g_Actors[a].aggroTick = GetTimeMs() + ms;
}

static void AggroClear(int a) {
    g_Actors[a].aggroTarget = -1;
    g_Actors[a].aggroMode = AGGRO_NONE;
    g_Actors[a].aggroTick = 0;
    g_Actors[a].midPunch = false;
}

static void AggroGiveUp(int a) {
    PEDLOG2("[Pedestrians] giveup actor %d target %d mode %d kind %d leader %d", g_Actors[a].actorid, g_Actors[a].aggroTarget, g_Actors[a].aggroMode, g_Actors[a].kind, g_Actors[a].packLeader);
    AggroClear(a);
    if (g_Actors[a].isDead) return;
    if (g_Actors[a].kind >= 100) g_Actors[a].retargetAfter = GetTimeMs() + 15000;
    if (g_Actors[a].kind >= 100 && g_Actors[a].packLeader != -1) {
        g_Actors[a].following = false;
        g_Actors[a].speed = 0.0f;
        return;
    }
    ResumeSlot(a);
}

static bool IsMeleeWeapon(int w) {
    switch (w) {
        case 0: case 1: case 2: case 3: case 5: case 6: case 7: case 10: case 11: case 12: case 13:
        case 14: case 15: case 39: case 40: case 41: case 42: case 43: case 44: case 45: case 46:
            return true;
    }
    return false;
}

static bool IsScaryWeapon(int w) {
    switch (w) {
        case 4: case 8: case 9: case 22: case 23: case 24: case 25: case 26: case 27: case 28:
        case 29: case 32: case 30: case 31: case 33: case 34: case 37: case 38:
            return true;
    }
    return false;
}

static void HaltSlot(int a) {
    g_Actors[a].holdUntil = 0;
    g_Actors[a].holdSettle = false;
    g_Actors[a].speed = 0.0f;
    g_Actors[a].hasTarget = false;
    g_Actors[a].hasFleePoint = false;
    if (g_Actors[a].state != PED_STATE_STOPPED) SetPedState(a, PED_STATE_STOPPED);
}

static void HoldSlot(int a, int ms, float heading, float dist) {
    g_Actors[a].speed = 0.0f;
    g_Actors[a].hasTarget = false;
    OffsetPoint(g_Actors[a].currentX, g_Actors[a].currentY, heading, dist, g_Actors[a].holdX, g_Actors[a].holdY);
    g_Actors[a].holdUntil = GetTimeMs() + ms;
    g_Actors[a].holdSettle = dist > 0.001f;
}

static void StepBackSlot(int a, float facing, float dist, float speed) {
    float tx, ty;
    OffsetPoint(g_Actors[a].currentX, g_Actors[a].currentY, facing + 180.0f, dist, tx, ty);
    WalkSlotTo(a, tx, ty, g_Actors[a].currentZ, speed);
}

static int FrontReaction(int a, int weaponid, float amount, float& speed) {
    int damage = (int)(amount + 0.5f);
    int ms = 600;
    speed = 3.2f;
    switch (weaponid) {
        case 0: case 1: case 10: case 12:
            if (damage == 4) { PedAnim(a, "ped", "HitA_1", false, false, 0); speed = 2.2f; ms = 300; }
            else if (damage == 7 || damage == 14) { PedAnim(a, "ped", "HitA_2", false, false, 0); ms = 530; }
            else { PedAnim(a, "ped", "HitA_3", false, false, 0); ms = 570; }
            break;
        case 4:
            if (damage == 20) { PedAnim(a, "KNIFE", "knife_hit_3", false, false, 0); speed = 1.0f; ms = 1200; }
            else {
                PedAnim(a, "KNIFE", g_Actors[a].knifeAlt ? "knife_hit_1" : "knife_hit_2", false, false, 0);
                speed = 3.0f;
                ms = g_Actors[a].knifeAlt ? 570 : 630;
                g_Actors[a].knifeAlt = !g_Actors[a].knifeAlt;
            }
            break;
        case 8: case 15:
            if (damage == 8) { PedAnim(a, "SWORD", "Sword_Hit_1", false, false, 0); speed = 1.5f; ms = 830; }
            else if (damage == 12) { PedAnim(a, "SWORD", "Sword_Hit_2", false, false, 0); speed = 1.7f; ms = 1030; }
            else { PedAnim(a, "SWORD", "Sword_Hit_3", false, false, 0); speed = 2.3f; ms = 870; }
            break;
        case 9: case 2: case 3: case 5: case 6: case 7:
            if (damage == 8 || damage == 41) { PedAnim(a, "BASEBALL", "Bat_Hit_1", false, false, 0); speed = 1.25f; ms = 830; }
            else if (damage == 14 || damage == 49) { PedAnim(a, "BASEBALL", "Bat_Hit_2", false, false, 0); speed = 1.65f; ms = 1070; }
            else { PedAnim(a, "BASEBALL", "Bat_Hit_3", false, false, 0); speed = 3.4f; ms = 730; }
            break;
        case 11: case 13:
            if (damage == 20) { PedAnim(a, "ped", "HitA_3", false, false, 0); ms = 570; }
            else {
                PedAnim(a, "ped", g_Actors[a].knifeAlt ? "HitA_1" : "HitA_2", false, false, 0);
                speed = g_Actors[a].knifeAlt ? 2.2f : 3.2f;
                ms = g_Actors[a].knifeAlt ? 300 : 530;
                g_Actors[a].knifeAlt = !g_Actors[a].knifeAlt;
            }
            break;
        case 14:
            if (damage == 4) { PedAnim(a, "ped", "HitA_1", false, false, 0); speed = 2.2f; }
            else { PedAnim(a, "Flowers", "Flower_Hit", false, false, 0); speed = 0.0f; }
            ms = 830;
            break;
        default:
            PedAnim(a, "ped", "HitA_2", false, false, 0);
            break;
    }
    return ms;
}

static void AggroOnDamage(int a, int playerid, int weaponid, float amount) {
    if (g_Actors[a].isDead || g_Actors[a].kind != 0) return;
    g_Actors[a].surrenderBy = -1;
    g_Actors[a].scareTick = 0;
    PEDLOG("[Pedestrians] actor %d hit by player %d weapon %d for %.1f (aggro %d)", g_Actors[a].actorid, playerid, weaponid, amount, g_Actors[a].aggroFlag ? 1 : 0);
    if (weaponid >= 0 && weaponid <= 15) {
        float px, py, pz;
        sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
        float facing = g_Actors[a].currentAngle;
        float rel = NormAngle(AngleTo(g_Actors[a].currentX, g_Actors[a].currentY, px, py) - facing);
        HaltSlot(a);
        g_Actors[a].aggroMode = AGGRO_HIT;
        if (rel < 45.0f || rel >= 315.0f) {
            float speed;
            int ms = FrontReaction(a, weaponid, amount, speed);
            float back = speed * (ms / 1000.0f);
            if (back > AGGRO_FRONT_PUSH) back = AGGRO_FRONT_PUSH;
            HoldSlot(a, ms, facing + 180.0f, speed > 0.0f ? back : 0.0f);
            AggroSchedule(a, ms);
        } else if (rel < 135.0f) {
            PedAnim(a, "ped", "HIT_L", false, false, 0);
            AggroSchedule(a, AGGRO_SIDE_HIT_MS);
        } else if (rel < 225.0f) {
            PedAnim(a, "ped", "HIT_back", false, false, 0);
            AggroSchedule(a, AGGRO_SIDE_HIT_MS);
        } else {
            PedAnim(a, "ped", "HIT_R", false, false, 0);
            AggroSchedule(a, AGGRO_SIDE_HIT_MS);
        }
        if (weaponid == 4 || weaponid == 8 || weaponid == 9) SetPedState(a, PED_STATE_PANIC);
    }
    if (g_Actors[a].aggroFlag && IsMeleeWeapon(weaponid)) {
        g_Actors[a].aggroTarget = playerid;
        if (g_Actors[a].aggroMode == AGGRO_NONE) {
            g_Actors[a].aggroMode = AGGRO_CHASE;
            AggroSchedule(a, AGGRO_THINK_MS);
        }
    }
}

static void AggroPunch(int a, int playerid) {
    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    float ax = g_Actors[a].currentX, ay = g_Actors[a].currentY, az = g_Actors[a].currentZ + 0.9f;
    float dx = px - ax, dy = py - ay;
    float distance = std::sqrt(dx*dx + dy*dy);
    float heightGap = std::abs(az - pz);
    bool combo = (rand() % 3) == 0;
    float facing = AngleTo(ax, ay, px, py);

    HaltSlot(a);
    FaceSlot(a, facing);

    if (distance > AGGRO_GIVE_UP) { AggroGiveUp(a); return; }

    PEDLOG2("[Pedestrians] punchthink actor %d player %d dist %.2f gap %.2f midPunch %d combo %d", g_Actors[a].actorid, playerid, distance, heightGap, g_Actors[a].midPunch ? 1 : 0, combo ? 1 : 0);
    if (g_Actors[a].midPunch && !combo) {
        g_Actors[a].midPunch = false;
        PedAnim(a, "ped", "FIGHTIDLE", true, false, 0);
        AggroSchedule(a, AGGRO_RECOVER_MS + (rand() % 300));
        return;
    }

    if (distance > AGGRO_PUNCH_MAX || distance < AGGRO_PUNCH_MIN || heightGap >= AGGRO_HEIGHT) {
        g_Actors[a].aggroMode = AGGRO_CHASE;
        g_Actors[a].midPunch = false;
        if ((rand() % 2) == 0 && distance > AGGRO_PUNCH_MIN) {
            PedAnim(a, "ped", "FIGHTIDLE", true, false, 0);
            AggroSchedule(a, AGGRO_IDLE_MS);
        } else {
            PedAnim(a, "ped", "FightSh_BWD", true, false, 0);
            StepBackSlot(a, facing, AGGRO_STEP, AGGRO_STEP_SPEED);
            AggroSchedule(a, AGGRO_THINK_MS);
        }
        return;
    }

    float playerFacing;
    sampgdk_GetPlayerFacingAngle(playerid, &playerFacing);
    float turned = NormAngle(playerFacing - facing);
    bool blocked = false;
    if (turned > 120.0f && turned < 230.0f) {
        int animIndex = sampgdk_GetPlayerAnimationIndex(playerid);
        for (int i = 0; i < (int)(sizeof(AGGRO_BLOCK_ANIMS) / sizeof(int)); i++) {
            if (AGGRO_BLOCK_ANIMS[i] == animIndex) { blocked = true; break; }
        }
    }

    if (blocked) {
        if ((rand() % 2) == 0) {
            SoundAround(px, py, pz, 4600 + (rand() % 3), AGGRO_SOUND_RANGE);
            PedAnim(a, "ped", "FightA_M", false, true, 0);
            HoldSlot(a, AGGRO_MISS_MS, facing, 0.0f);
            g_Actors[a].midPunch = true;
            AggroSchedule(a, AGGRO_MISS_MS);
        } else {
            g_Actors[a].aggroMode = AGGRO_CHASE;
            g_Actors[a].midPunch = false;
            PedAnim(a, "ped", "FIGHTIDLE", true, false, 0);
            AggroSchedule(a, AGGRO_IDLE_MS);
        }
        return;
    }

    if (sampgdk_GetPlayerState(playerid) == 7) {
        SoundAround(px, py, pz, 1136, AGGRO_SOUND_RANGE);
        PedAnim(a, "ped", "FightA_G", false, true, 0);
        HoldSlot(a, AGGRO_KICK_MS, facing, 0.0f);
        g_Actors[a].midPunch = true;
        AggroSchedule(a, AGGRO_KICK_MS);
        return;
    }

    int punch = rand() % 3;
    {
        uint64_t t = GetTimeMs();
        PEDLOG2("[Pedestrians] PUNCH actor %d -> player %d idx %d dist %.2f (+%llu ms since last punch)", g_Actors[a].actorid, playerid, punch, distance, (unsigned long long)(g_Actors[a].dbgPunchAt ? t - g_Actors[a].dbgPunchAt : 0));
        g_Actors[a].dbgPunchAt = t;
    }
    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, "OnPedestrianPunchPlayer", &idx)) {
            amx_Push(amx, punch);
            amx_Push(amx, playerid);
            amx_Push(amx, g_Actors[a].actorid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }

    float lunge = AGGRO_NUDGE_SPEED[punch] * (AGGRO_PUNCH_MS[punch] / 1000.0f);
    if (lunge > distance - 0.6f) lunge = distance - 0.6f;
    if (lunge < 0.0f) lunge = 0.0f;
    OffsetPoint(ax, ay, facing, lunge, g_Actors[a].holdX, g_Actors[a].holdY);
    g_Actors[a].holdUntil = GetTimeMs() + AGGRO_PUNCH_MS[punch];
    g_Actors[a].holdSettle = true;
    PedAnim(a, "ped", punch == 0 ? "FightA_1" : (punch == 1 ? "FightA_2" : "FightA_3"), false, true, 0);
    g_Actors[a].midPunch = true;
    AggroSchedule(a, AGGRO_PUNCH_MS[punch]);
}

static void AggroChase(int a, int playerid) {
    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    float ax = g_Actors[a].currentX, ay = g_Actors[a].currentY, az = g_Actors[a].currentZ + 0.9f;
    float dx = px - ax, dy = py - ay;
    float distance = std::sqrt(dx*dx + dy*dy);
    float heightGap = std::abs(az - pz);

    if (distance > AGGRO_GIVE_UP) { AggroGiveUp(a); return; }

    if (distance <= AGGRO_PUNCH_MAX && distance >= AGGRO_PUNCH_MIN && heightGap < AGGRO_HEIGHT) {
        g_Actors[a].aggroMode = AGGRO_PUNCH;
        AggroPunch(a, playerid);
        return;
    }

    float facing = AngleTo(ax, ay, px, py);
    {
        uint64_t t = GetTimeMs();
        if (t - g_Actors[a].dbgChaseAt >= 500) {
            g_Actors[a].dbgChaseAt = t;
            PEDLOG2("[Pedestrians] chase actor %d player %d dist %.2f gap %.2f speed %.2f", g_Actors[a].actorid, playerid, distance, heightGap, g_Actors[a].speed);
        }
    }
    if (distance < AGGRO_PUNCH_MIN && heightGap < AGGRO_HEIGHT) {
        PedAnim(a, "ped", "FightSh_BWD", true, false, 0);
        StepBackSlot(a, facing, AGGRO_STEP, AGGRO_STEP_SPEED);
    } else if (distance < AGGRO_CLOSE) {
        PedAnim(a, "ped", "FightSh_FWD", true, false, 0);
        WalkSlotTo(a, px, py, pz - 0.9f, AGGRO_STEP_SPEED);
    } else {
        const char* runAnim;
        float runSpeed;
        RunAnimFor(a, runAnim, runSpeed);
        PedAnim(a, "ped", runAnim, true, false, 0);
        WalkSlotTo(a, px, py, pz - 0.9f, runSpeed);
    }
    AggroSchedule(a, AGGRO_THINK_MS);
}

static void AggroTick(int a, uint64_t now) {
    if (g_Actors[a].aggroMode == AGGRO_NONE || g_Actors[a].aggroTick == 0 || g_Actors[a].aggroTick > now) return;
    g_Actors[a].aggroTick = 0;
    int playerid = g_Actors[a].aggroTarget;
    bool targetOk = playerid >= 0 && playerid < MAX_PLAYERS && sampgdk_IsPlayerConnected(playerid) && sampgdk_GetPlayerVirtualWorld(playerid) == sampgdk_GetActorVirtualWorld(g_Actors[a].actorid);

    if (g_Actors[a].aggroMode == AGGRO_HIT) {
        if (g_Actors[a].aggroFlag && targetOk) {
            g_Actors[a].aggroMode = AGGRO_CHASE;
            AggroChase(a, playerid);
        } else {
            AggroClear(a);
            PanicSlot(a, g_PanicDurationMs);
        }
        return;
    }
    if (!targetOk) { AggroGiveUp(a); return; }
    if (g_Actors[a].aggroMode == AGGRO_PUNCH) { AggroPunch(a, playerid); return; }
    AggroChase(a, playerid);
}

static void SurrenderBegin(int a, int playerid) {
    PEDLOG("[Pedestrians] actor %d surrenders to player %d", g_Actors[a].actorid, playerid);
    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    StopSlot(a);
    FaceSlot(a, AngleTo(g_Actors[a].currentX, g_Actors[a].currentY, px, py));
    int pick = rand() % SURRENDER_ANIMS;
    PedAnim(a, SURRENDER_LIB[pick], SURRENDER_NAME[pick], false, true, 0);
    g_Actors[a].surrenderBy = playerid;
}

static void SurrenderAimLost(int actorid, int playerid) {
    int a = SlotOf(actorid);
    if (a == -1 || g_Actors[a].isDead || g_Actors[a].surrenderBy != playerid) return;
    g_Actors[a].surrenderBy = -1;
    PedAnim(a, "ROB_BANK", "SHP_HandsUp_Scr", false, false, SURRENDER_SCARE_MS);
    g_Actors[a].scareTick = GetTimeMs() + SURRENDER_SCARE_MS;
}

static void SurrenderTick(int a, uint64_t now) {
    if (g_Actors[a].surrenderBy != -1) {
        int p = g_Actors[a].surrenderBy;
        if (!sampgdk_IsPlayerConnected(p) || sampgdk_GetPlayerTargetActor(p) != g_Actors[a].actorid) {
            SurrenderAimLost(g_Actors[a].actorid, p);
        }
        return;
    }
    if (g_Actors[a].scareTick != 0 && g_Actors[a].scareTick <= now) {
        g_Actors[a].scareTick = 0;
        if (!g_Actors[a].isDead) PanicSlot(a, g_PanicDurationMs);
    }
}

static void AggroOnAim(int a, int playerid) {
    if (!g_AmbientPanic) return;
    if (g_Actors[a].isDead || g_Actors[a].kind != 0 || g_Actors[a].surrenderBy != -1) return;
    if (g_Actors[a].aggroMode >= AGGRO_CHASE) return;
    if (!IsScaryWeapon(sampgdk_GetPlayerWeapon(playerid))) return;
    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    float dx = px - g_Actors[a].currentX, dy = py - g_Actors[a].currentY;
    float dist2D = std::sqrt(dx*dx + dy*dy);
    if (dist2D > 20.0f) return;
    float rad = -g_Actors[a].currentAngle * (3.14159265f / 180.0f);
    float dot = (dx / std::max(dist2D, 0.01f)) * std::sin(rad) + (dy / std::max(dist2D, 0.01f)) * std::cos(rad);
    if (dot <= 0.0f) return;
    SurrenderBegin(a, playerid);
}

static void AggroResetSlot(int a) {
    g_Actors[a].aggroFlag = false;
    g_Actors[a].aggroTarget = -1;
    g_Actors[a].aggroMode = AGGRO_NONE;
    g_Actors[a].aggroTick = 0;
    g_Actors[a].midPunch = false;
    g_Actors[a].knifeAlt = false;
    g_Actors[a].surrenderBy = -1;
    g_Actors[a].scareTick = 0;
}

static void AggroRoll(int a) {
    int odds = IsFemaleSkin(g_Actors[a].skin) ? 4 : 2;
    g_Actors[a].aggroFlag = (rand() % odds) == 0;
}

static const float STEER_HOLD_MS = 1500.0f;
static const int STEER_OBSTACLE_MS = 400;
static const int STEER_CURB_MS = 1000;
static const float STEER_NEAR_HUMAN = 60.0f;
bool g_SteerEnabled = true;

static bool RayHit(float x1, float y1, float z1, float x2, float y2, float z2) {
    if (!g_UseColAndreas) return false;
    float cx = 0.0f, cy = 0.0f, cz = 0.0f;
    return Bridge_RayCast(x1, y1, z1, x2, y2, z2, &cx, &cy, &cz) != 0;
}

static bool RayGroundZ(float x, float y, float z, float depth, float& outZ) {
    if (!g_UseColAndreas) return false;
    float cx = 0.0f, cy = 0.0f, cz = 0.0f;
    int ret = Bridge_RayCast(x, y, z, x, y, z - depth, &cx, &cy, &cz);
    if (ret == 0 || ret == 20000) return false;
    outZ = cz;
    return true;
}

static bool ProbeBlocked(float x, float y, float z, float angle, float dist, float dz) {
    float px, py;
    OffsetPoint(x, y, angle, dist, px, py);
    return RayHit(x, y, z, px, py, z + dz);
}

static bool FarBlocked(float x, float y, float z, float angle, float side) {
    return ProbeBlocked(x, y, z, angle + side * 15.0f, 2.64f, 0.3f) || ProbeBlocked(x, y, z, angle + side * 15.0f, 2.4f, -0.3f)
        || ProbeBlocked(x, y, z, angle + side * 25.0f, 2.64f, 0.3f) || ProbeBlocked(x, y, z, angle + side * 25.0f, 2.4f, -0.3f);
}

static bool NearBlocked(float x, float y, float z, float angle, float side) {
    return ProbeBlocked(x, y, z, angle + side * 40.0f, 0.6f, 0.3f) || ProbeBlocked(x, y, z, angle + side * 40.0f, 0.24f, -0.3f)
        || ProbeBlocked(x, y, z, angle + side * 60.0f, 0.6f, 0.3f) || ProbeBlocked(x, y, z, angle + side * 60.0f, 0.24f, -0.3f);
}

static bool AheadBlocked(float x, float y, float z, float angle) {
    return ProbeBlocked(x, y, z, angle, 3.24f, 0.3f) || ProbeBlocked(x, y, z, angle, 3.0f, -0.3f);
}

static bool CurbAhead(float x, float y, float z, float angle, float dist, float hereZ) {
    float px, py, thereZ;
    OffsetPoint(x, y, angle, dist, px, py);
    if (!RayGroundZ(px, py, z, 2.2f, thereZ)) return false;
    float drop = hereZ - thereZ;
    if (drop < 0.14f || drop > 0.2f) return false;
    float midZ = thereZ + drop * 0.5f;
    return !RayHit(x, y, midZ, px, py, midZ);
}

static void Steer(int a, float offset, uint64_t now) {
    g_Actors[a].steerOffset = offset;
    g_Actors[a].steerUntil = now + (uint64_t)STEER_HOLD_MS;
}

static void SteerSlot(int a, uint64_t now) {
    if (!g_SteerEnabled) return;
    if (!g_Actors[a].nearHuman || g_Actors[a].hasTarget || g_Actors[a].state == PED_STATE_STOPPED) return;
    float x = g_Actors[a].currentX, y = g_Actors[a].currentY, z = g_Actors[a].currentZ + 0.9f;
    float angle = g_Actors[a].currentAngle;

    if (g_Actors[a].nextObstacleCheck <= now) {
        g_Actors[a].nextObstacleCheck = now + STEER_OBSTACLE_MS;
        if (AheadBlocked(x, y, z, angle)) {
            bool left = FarBlocked(x, y, z, angle, 1.0f);
            bool right = FarBlocked(x, y, z, angle, -1.0f);
            if (left && right) Steer(a, (rand() % 2) ? 90.0f : -90.0f, now);
            else if (left) Steer(a, -35.0f, now);
            else if (right) Steer(a, 35.0f, now);
            else Steer(a, (rand() % 2) ? 35.0f : -35.0f, now);
            return;
        }
        if (NearBlocked(x, y, z, angle, 1.0f)) { Steer(a, -20.0f, now); return; }
        if (NearBlocked(x, y, z, angle, -1.0f)) { Steer(a, 20.0f, now); return; }
    }

    if (g_Actors[a].nextCurbCheck <= now) {
        g_Actors[a].nextCurbCheck = now + STEER_CURB_MS;
        float hereZ;
        if (RayGroundZ(x, y, z, 2.0f, hereZ) && CurbAhead(x, y, z, angle, 2.1f, hereZ)) {
            bool leftOk = !CurbAhead(x, y, z, angle + 40.0f, 2.5f, hereZ);
            bool rightOk = !CurbAhead(x, y, z, angle - 40.0f, 2.5f, hereZ);
            if (leftOk && !rightOk) Steer(a, 30.0f, now);
            else if (rightOk && !leftOk) Steer(a, -30.0f, now);
            else if (leftOk && rightOk) Steer(a, (rand() % 2) ? 30.0f : -30.0f, now);
        }
    }
}

static void SideStepSlot(int a, uint64_t now) {
    if (!g_SteerEnabled) return;
    if (!g_Actors[a].nearHuman || g_Actors[a].hasTarget || g_Actors[a].steerUntil > now) return;
    float x = g_Actors[a].currentX, y = g_Actors[a].currentY;
    float ax, ay;
    OffsetPoint(x, y, g_Actors[a].currentAngle, 1.0f, ax, ay);
    for (int p : g_HumanPlayers) {
        if (sampgdk_GetPlayerVirtualWorld(p) != 0) continue;
        float px, py, pz;
        sampgdk_GetPlayerPos(p, &px, &py, &pz);
        float dx = px - ax, dy = py - ay;
        if (dx*dx + dy*dy < 0.8f && std::abs(pz - g_Actors[a].currentZ) < 2.0f) {
            float rel = NormAngle(AngleTo(x, y, px, py) - g_Actors[a].currentAngle);
            Steer(a, rel < 180.0f ? -25.0f : 25.0f, now);
            return;
        }
    }
    for (int b = 0; b < g_MaxActorsInPool; b++) {
        if (b == a || !g_Actors[b].inUse || g_Actors[b].isDead) continue;
        float dx = g_Actors[b].currentX - ax, dy = g_Actors[b].currentY - ay;
        if (dx*dx + dy*dy < 0.6f) {
            float rel = NormAngle(AngleTo(x, y, g_Actors[b].currentX, g_Actors[b].currentY) - g_Actors[a].currentAngle);
            Steer(a, rel < 180.0f ? -25.0f : 25.0f, now);
            return;
        }
    }
}

static float WeaponDamageScale(int weaponid, int bodypart) {
    float scale = 1.0f;
    if (weaponid == 37) scale = 0.1f;
    else if (weaponid == 41 || weaponid == 42) scale = 0.2f;
    if (bodypart == 9) scale *= 10.0f;
    return scale;
}

static void ChokeSlot(int a, uint64_t now) {
    if (g_Actors[a].isDead) return;
    if (g_Actors[a].chokeUntil > now) return;
    g_Actors[a].chokeUntil = now + 3000;
    float tx, ty;
    OffsetPoint(g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentAngle + 180.0f, 3.0f, tx, ty);
    WalkSlotTo(a, tx, ty, g_Actors[a].currentZ, 0.7f);
    PedAnim(a, "ped", "gas_cwr", true, false, 0);
}

static void ChokeTick(int a, uint64_t now) {
    if (g_Actors[a].chokeUntil == 0 || g_Actors[a].chokeUntil > now) return;
    g_Actors[a].chokeUntil = 0;
    if (!g_Actors[a].isDead && g_Actors[a].aggroMode == AGGRO_NONE) ResumeSlot(a);
}

static void KnifeCutCheck(int playerid, int target, uint64_t now) {
    if (sampgdk_GetPlayerAnimationIndex(playerid) != 747) return;
    int a = SlotOf(target);
    if (a == -1 || g_Actors[a].isDead || g_Actors[a].cutUntil != 0) return;
    PEDLOG("[Pedestrians] player %d knifes actor %d from behind", playerid, target);
    StopSlot(a);
    PedAnim(a, "KNIFE", "KILL_Knife_Ped_Damage", false, true, 0);
    g_Actors[a].cutUntil = now + 2100;
    g_Actors[a].cutBy = playerid;
}

static void KnifeCutTick(int a, uint64_t now) {
    if (g_Actors[a].cutUntil == 0 || g_Actors[a].cutUntil > now) return;
    g_Actors[a].cutUntil = 0;
    if (g_Actors[a].isDead) return;
    g_Actors[a].health = 0.0f;
    TriggerPedDeath(a, g_Actors[a].cutBy, 4);
}

static void BloodTick(uint64_t now) {
    for (auto it = g_PendingBlood.begin(); it != g_PendingBlood.end();) {
        if (it->second <= now) {
            sampgdk_DestroyObject(it->first);
            it = g_PendingBlood.erase(it);
        } else {
            ++it;
        }
    }
}

struct ThrowState {
    int weapon;
    uint64_t tick;
    int ammo;
    float x, y, z, a;
    int ticks;
};
static ThrowState g_Throw[1000];

struct GasCloud {
    bool active;
    int obj1, obj2;
    float x, y, z;
    uint64_t until;
    uint64_t nextTick;
    int thrower;
};
#define MAX_GAS_CLOUDS 32
static GasCloud g_Gas[MAX_GAS_CLOUDS];
int g_GasTimeMs = 30000;

struct PendingGas {
    float x, y, z;
    uint64_t at;
    int thrower;
};
static std::vector<PendingGas> g_PendingGas;

static void XYFromAngle(float& x, float& y, float angle, float dist) {
    float rad = -angle * (3.14159265f / 180.0f);
    x += dist * std::sin(rad);
    y += dist * std::cos(rad);
}

static bool RayNormal(float x1, float y1, float z1, float x2, float y2, float z2, float col[3], float nrm[3]) {
    if (!g_UseColAndreas) return false;
    return Bridge_RayCastNormal(x1, y1, z1, x2, y2, z2, &col[0], &col[1], &col[2], &nrm[0], &nrm[1], &nrm[2]) != 0;
}

static bool RayReflection(float x1, float y1, float z1, float x2, float y2, float z2, float vec[3]) {
    if (!g_UseColAndreas) return false;
    float col[3], nrm[3];
    if (!RayNormal(x1, y1, z1, x2, y2, z2, col, nrm)) return false;
    float dx = x2 - x1, dy = y2 - y1, dz = z2 - z1;
    float len = std::sqrt(dx*dx + dy*dy + dz*dz);
    if (len < 0.0001f) return false;
    dx /= len; dy /= len; dz /= len;
    float dot = dx*nrm[0] + dy*nrm[1] + dz*nrm[2];
    vec[0] = dx - 2.0f * dot * nrm[0];
    vec[1] = dy - 2.0f * dot * nrm[1];
    vec[2] = dz - 2.0f * dot * nrm[2];
    return true;
}

static void LandingPos(ThrowState& st, int ticks, float& x, float& y, float& z, float reflection, int iteration) {
    int weapon = st.weapon;
    if (iteration == 0) {
        if (ticks > 500) ticks = 500;
        if (ticks < 95) ticks = 95;
        if (ticks < 200) ticks = ticks * (int)std::floor(1.30f - (float)(ticks + 100) / 1000.0f + 0.5f);
        if (ticks > 215) {
            st.z += 0.75f;
            float offset = 0.13f;
            if (weapon == 17) offset -= 0.65f;
            XYFromAngle(st.x, st.y, st.a - 90.0f, offset);
        }
    }
    if (weapon == 16) ticks = (int)std::floor(ticks * 1.03f + 0.5f);
    if (weapon == 17) ticks = (int)std::floor(ticks * 1.04f + 0.5f);
    if (weapon == 39) ticks = (int)std::floor(ticks * (0.50f * 500.0f / (float)(ticks + 700)) + 0.5f);
    float throwAngle = 18.0f * (1.0f + (float)ticks / 500.0f);
    if (iteration) throwAngle = reflection;
    float old[3] = {st.x, st.y, st.z};
    const float d2r = 3.14159265f / 180.0f;
    float v = std::sqrt((float)ticks / 9.0f);
    for (float t = 0.1f; t <= 7.0f; t += 0.1f) {
        float vx = -v * std::cos(throwAngle * d2r) * std::sin(st.a * d2r);
        float vy = v * std::cos(throwAngle * d2r) * std::cos(st.a * d2r);
        float vz = v * std::sin(throwAngle * d2r);
        x = st.x + vx * t;
        y = st.y + vy * t;
        z = st.z + vz * t - 0.5f * 2.05f * t * t;
        float col[3], nrm[3], vec[3] = {0, 0, 0};
        bool coln = RayNormal(old[0], old[1], old[2], x, y, z, col, nrm);
        if (coln) RayReflection(old[0], old[1], old[2], x, y, z, vec);
        old[0] = x; old[1] = y; old[2] = z;
        if (coln) {
            if (iteration >= 2 || weapon == 39) { x = col[0]; y = col[1]; z = col[2]; break; }
            float hrot = NormAngle(std::atan2(-nrm[0], nrm[1]) * (180.0f / 3.14159265f));
            float vrot = std::atan2(nrm[2], std::sqrt(nrm[0]*nrm[0] + nrm[1]*nrm[1])) * (180.0f / 3.14159265f);
            float dot = nrm[0]*vec[0] + nrm[1]*vec[1] + nrm[2]*vec[2];
            if (dot > 1.0f) dot = 1.0f;
            if (dot < -1.0f) dot = -1.0f;
            float angle = std::acos(dot) * (180.0f / 3.14159265f);
            float multi = 1.0f + (90.0f - std::abs(vrot)) / 60.0f;
            st.a = hrot;
            st.x = col[0]; st.y = col[1]; st.z = col[2];
            int next = (int)std::floor((angle * 0.2f * multi * (float)ticks / 100.0f) / (1.0f + iteration) + 0.5f);
            LandingPos(st, next, x, y, z, vrot, iteration + 1);
            break;
        }
    }
}

static void FleePedsFromPoint(float x, float y, float z, float range, int playerid) {
    uint64_t now = GetTimeMs();
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
        float dx = g_Actors[a].currentX - x, dy = g_Actors[a].currentY - y, dz = g_Actors[a].currentZ - z;
        if (dx*dx + dy*dy + dz*dz > range * range) continue;
        g_Actors[a].fleeX = x; g_Actors[a].fleeY = y; g_Actors[a].fleeZ = z;
        g_Actors[a].hasFleePoint = true;
        if (!NavStartFlee(a, x, y, z)) {
            if (g_Actors[a].hasTarget) SnapToGraph(a);
            int curIdx = FindNodeIndex(g_Actors[a].currentNodeId);
            int far = PickFarthestLink(curIdx, x, y, z);
            if (far != -1) g_Actors[a].targetNodeId = far;
        }
        AggroClear(a);
        PanicSlot(a, g_PanicDurationMs);
        (void)now;
    }
}

static void FleeBystandersFromViolence(int source) {
    if (g_Actors[source].kind < 0 || g_Actors[source].kind > 2) return;
    int world = sampgdk_GetActorVirtualWorld(g_Actors[source].actorid);
    float x = g_Actors[source].currentX, y = g_Actors[source].currentY, z = g_Actors[source].currentZ;
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (a == source || !g_Actors[a].inUse || g_Actors[a].isDead || g_Actors[a].scriptHold) continue;
        if (g_Actors[a].kind != 0 && g_Actors[a].kind != 1) continue;
        if (sampgdk_GetActorVirtualWorld(g_Actors[a].actorid) != world) continue;
        float dx = g_Actors[a].currentX - x, dy = g_Actors[a].currentY - y, dz = g_Actors[a].currentZ - z;
        if (dx*dx + dy*dy + dz*dz > g_PanicRadius * g_PanicRadius) continue;
        if (g_Actors[a].fallenTick != 0 || g_Actors[a].actionId != 0) continue;
        g_Actors[a].fleeX = x; g_Actors[a].fleeY = y; g_Actors[a].fleeZ = z;
        g_Actors[a].hasFleePoint = true;
        if (!NavStartFlee(a, x, y, z)) {
            if (g_Actors[a].hasTarget) SnapToGraph(a);
            int curIdx = FindNodeIndex(g_Actors[a].currentNodeId);
            int far = PickFarthestLink(curIdx, x, y, z);
            if (far != -1) g_Actors[a].targetNodeId = far;
        }
        AggroClear(a);
        PanicSlot(a, std::min(g_PanicDurationMs, 4000));
    }
}

static void ThrowLanded(int playerid, int weapon, float x, float y, float z) {
    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, "OnPlayerThrowThrowable", &idx)) {
            amx_Push(amx, amx_ftoc(z));
            amx_Push(amx, amx_ftoc(y));
            amx_Push(amx, amx_ftoc(x));
            amx_Push(amx, weapon);
            amx_Push(amx, playerid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }
    PEDLOG("[Pedestrians] player %d threw weapon %d, lands at %.1f %.1f %.1f", playerid, weapon, x, y, z);
    if (g_AmbientPanic) FleePedsFromPoint(x, y, z, 5.0f, playerid);
    if (weapon == 17) {
        g_PendingGas.push_back({x, y, z, GetTimeMs() + 3000, playerid});
    }
}

static void ThrowPoll(int i, uint64_t now) {
    if (i < 0 || i >= 1000) return;
    ThrowState& st = g_Throw[i];
    int weapon = sampgdk_GetPlayerWeapon(i);
    int keys = 0, ud = 0, lr = 0;
    sampgdk_GetPlayerKeys(i, &keys, &ud, &lr);
    int anim = sampgdk_GetPlayerAnimationIndex(i);
    bool throwable = (weapon == 16 || weapon == 17 || weapon == 18 || weapon == 39);
    if (anim == 644 && st.weapon == 0 && (keys & 4) && throwable) {
        st.tick = now;
        sampgdk_GetPlayerPos(i, &st.x, &st.y, &st.z);
        sampgdk_GetPlayerFacingAngle(i, &st.a);
        st.weapon = weapon;
        st.ammo = sampgdk_GetPlayerAmmo(i);
        st.ticks = 0;
        return;
    }
    if (st.weapon != 0 && weapon == st.weapon && (sampgdk_GetPlayerAmmo(i) + 1 == st.ammo || now - st.tick >= 750)) {
        sampgdk_GetPlayerFacingAngle(i, &st.a);
        if (st.ticks == 0) st.ticks = (int)(now - st.tick);
        XYFromAngle(st.x, st.y, st.a - 90.0f, 0.27f);
        if (st.weapon != 17) st.z -= 0.3f;
        float lx = st.x, ly = st.y, lz = st.z;
        LandingPos(st, st.ticks, lx, ly, lz, -1.0f, 0);
        int w = st.weapon;
        st.weapon = 0;
        ThrowLanded(i, w, lx, ly, lz);
        return;
    }
    if (st.weapon != 0 && !(keys & 4) && st.ticks == 0) {
        st.ticks = (int)(now - st.tick);
    }
}

static void GasTick(uint64_t now) {
    for (auto it = g_PendingGas.begin(); it != g_PendingGas.end();) {
        if (it->at > now) { ++it; continue; }
        int slot = -1;
        for (int g = 0; g < MAX_GAS_CLOUDS; g++) if (!g_Gas[g].active) { slot = g; break; }
        if (slot != -1) {
            g_Gas[slot].active = true;
            g_Gas[slot].x = it->x; g_Gas[slot].y = it->y; g_Gas[slot].z = it->z;
            g_Gas[slot].thrower = it->thrower;
            g_Gas[slot].until = now + g_GasTimeMs;
            g_Gas[slot].nextTick = now;
            g_Gas[slot].obj1 = sampgdk_CreateObject(1672, it->x, it->y, it->z + 0.15f, 0.0f, 0.0f, 0.0f, 100.0f);
            g_Gas[slot].obj2 = sampgdk_CreateObject(18732, it->x, it->y, it->z - 1.2f, 0.0f, 0.0f, 0.0f, 100.0f);
        }
        it = g_PendingGas.erase(it);
    }
    for (int g = 0; g < MAX_GAS_CLOUDS; g++) {
        if (!g_Gas[g].active) continue;
        if (g_Gas[g].until <= now) {
            sampgdk_DestroyObject(g_Gas[g].obj1);
            sampgdk_DestroyObject(g_Gas[g].obj2);
            g_Gas[g].active = false;
            continue;
        }
        if (g_Gas[g].nextTick > now) continue;
        g_Gas[g].nextTick = now + 1000;
        for (int a = 0; a < g_MaxActorsInPool; a++) {
            if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
            float dx = g_Actors[a].currentX - g_Gas[g].x, dy = g_Actors[a].currentY - g_Gas[g].y, dz = g_Actors[a].currentZ - g_Gas[g].z;
            if (dx*dx + dy*dy + dz*dz > 36.0f) continue;
            ChokeSlot(a, now);
            ApplyDamage(a, 7.0f, g_Gas[g].thrower, 17);
        }
        for (int p : g_HumanPlayers) {
            if (!sampgdk_IsPlayerInRangeOfPoint(p, 6.0f, g_Gas[g].x, g_Gas[g].y, g_Gas[g].z)) continue;
            for (AMX* amx : g_AMX) {
                int idx;
                if (!amx_FindPublic(amx, "OnPlayerInTearGas", &idx)) {
                    amx_Push(amx, g_Gas[g].thrower);
                    amx_Push(amx, p);
                    cell ret;
                    amx_Exec(amx, &ret, idx);
                }
            }
        }
    }
}

struct GangZoneBox {
    int gang;
    float minX, minY, maxX, maxY;
};
static std::vector<GangZoneBox> g_GangZones;
#define MAX_GANGS 8
static int g_GangSkins[MAX_GANGS][3] = {{0}};
static int g_PlayerGang[1000] = {0};
int g_PackOdds = 8;
float g_PackHostileRange = 20.0f;
int g_MaxPacksPerGang = 2;
static const float PACK_FOLLOW_GAP = 1.6f;
static const float PACK_GIVE_UP = 60.0f;
static const float PACK_GUN_RANGE = 8.0f;
static const int PACK_SHOT_MS = 1000;
static const int PACK_THINK_MS = 500;
static const int KIND_GANG_BASE = 100;

static int GangAt(float x, float y) {
    for (const auto& z : g_GangZones) {
        if (x >= z.minX && x <= z.maxX && y >= z.minY && y <= z.maxY) return z.gang;
    }
    return 0;
}

static int CountPacks(int gang) {
    int n = 0;
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && !g_Actors[a].isDead && g_Actors[a].gang == gang && g_Actors[a].packLeader == -1 && g_Actors[a].kind >= KIND_GANG_BASE) n++;
    }
    return n;
}

static int FreeSlot() {
    for (int a = 0; a < g_MaxActorsInPool; a++) if (!g_Actors[a].inUse) return a;
    return -1;
}

static bool FillSlot(int slot, int skin, float x, float y, float z, int walkStyle, int p, uint32_t nid) {
    if (g_Actors[slot].actorid != 0 && g_Actors[slot].actorid != 0xFFFF) {
        sampgdk_DestroyActor(g_Actors[slot].actorid);
    }
    BloodPoolDrop(slot);
    float rayZ = z;
    if (g_UseColAndreas) {
        if (!RayCastSpawn(x, y, z, rayZ)) return false;
        z = rayZ;
    }
    float spawnZ = z;
    if (!g_UseColAndreas) spawnZ += 0.9f;
    int newActor = sampgdk_CreateActor(skin, x, y, spawnZ, 0.0f);
    if (newActor == 0xFFFF || newActor < 0) return false;
    g_Actors[slot].actorid = newActor;
    MapActor(newActor, slot);
    g_Actors[slot].currentZ = z;
    g_Actors[slot].skin = skin;
    sampgdk_SetActorInvulnerable(newActor, false);
    sampgdk_SetActorVirtualWorld(newActor, sampgdk_GetPlayerVirtualWorld(p));
    sampgdk_ApplyActorAnimation(newActor, "PED", NameAnimations[walkStyle], 4.1f, true, true, true, false, 0);
    g_Actors[slot].inUse = true;
    g_Actors[slot].isDead = false;
    g_Actors[slot].walkStyle = walkStyle;
    g_Actors[slot].fallenTick = 0;
    g_Actors[slot].health = PED_HEALTH;
    g_Actors[slot].state = PED_STATE_WALKING;
    g_Actors[slot].panicTick = 0;
    g_Actors[slot].actionId = 0;
    g_Actors[slot].kind = 0;
    g_Actors[slot].deadTick = 0;
    g_Actors[slot].hasTarget = false;
    g_Actors[slot].hasFleePoint = false;
    AggroResetSlot(slot);
    g_Actors[slot].steerOffset = 0.0f;
    g_Actors[slot].steerUntil = 0;
    g_Actors[slot].nextObstacleCheck = 0;
    g_Actors[slot].nextCurbCheck = 0;
    g_Actors[slot].nearHuman = true;
    g_Actors[slot].chokeUntil = 0;
    g_Actors[slot].cutUntil = 0;
    g_Actors[slot].cutBy = -1;
    g_Actors[slot].gang = 0;
    g_Actors[slot].packLeader = -1;
    g_Actors[slot].packIndex = 0;
    g_Actors[slot].huddleUntil = 0;
    g_Actors[slot].nextHuddle = 0;
    g_Actors[slot].gunTarget = -1;
    g_Actors[slot].nextShot = 0;
    g_Actors[slot].gangThink = 0;
    g_Actors[slot].following = false;
    g_Actors[slot].retargetAfter = 0;
    g_Actors[slot].huddleAnimAt = 0;
    g_Actors[slot].sentValid = false;
    g_Actors[slot].holdUntil = 0;
    g_Actors[slot].holdSettle = false;
    g_Actors[slot].trailN = 0;
    g_Actors[slot].scriptHold = false;
    g_Actors[slot].floats = false;
    g_Actors[slot].body = -1;
    NavReset(slot);
    SetActorWalk(slot, nid, 1.2f);
    g_Actors[slot].currentX = x;
    g_Actors[slot].currentY = y;
    g_Actors[slot].currentZ = z;
    return true;
}

static int SpawnPack(int gang, uint32_t nid, float x, float y, float z, int p) {
    if (gang <= 0 || gang >= MAX_GANGS || g_GangSkins[gang][0] == 0) return 0;
    int slots[3];
    int found = 0;
    for (int a = 0; a < g_MaxActorsInPool && found < 3; a++) {
        if (!g_Actors[a].inUse) slots[found++] = a;
    }
    if (found < 3) return 0;
    uint64_t now = GetTimeMs();
    PEDLOG("[Pedestrians] gang %d pack spawns at %.1f %.1f for player %d", gang, x, y, p);
    for (int m = 0; m < 3; m++) {
        float mx = x, my = y;
        if (m > 0) OffsetPoint(x, y, (m == 1) ? 140.0f : 220.0f, PACK_FOLLOW_GAP, mx, my);
        int skin = g_GangSkins[gang][rand() % 3];
        if (!FillSlot(slots[m], skin, mx, my, z, WALK_GANG1, p, nid)) {
            if (m == 0) return 0;
            continue;
        }
        int a = slots[m];
        g_Actors[a].kind = KIND_GANG_BASE + gang;
        g_Actors[a].gang = gang;
        g_Actors[a].homeX = x;
        g_Actors[a].homeY = y;
        g_Actors[a].packLeader = (m == 0) ? -1 : slots[0];
        g_Actors[a].packIndex = m;
        g_Actors[a].nextHuddle = now + 20000 + (rand() % 20000);
        g_Actors[a].aggroFlag = false;
        PEDLOG("[Pedestrians]   member %d: actor %d slot %d leader slot %d", m, g_Actors[a].actorid, a, g_Actors[a].packLeader);
        for (AMX* amx : g_AMX) {
            int idx;
            if (!amx_FindPublic(amx, "OnPedestrianSpawn", &idx)) {
                amx_Push(amx, (cell)nid);
                amx_Push(amx, g_Actors[a].actorid);
                cell ret;
                amx_Exec(amx, &ret, idx);
            }
        }
    }
    return 3;
}

static void PackSetTarget(int leaderSlot, int playerid) {
    PEDLOG("[Pedestrians] pack of actor %d turns on player %d", g_Actors[leaderSlot].actorid, playerid);
    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, "OnPedestrianPackHostile", &idx)) {
            amx_Push(amx, playerid);
            amx_Push(amx, g_Actors[leaderSlot].actorid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
        if (a != leaderSlot && g_Actors[a].packLeader != leaderSlot) continue;
        g_Actors[a].huddleUntil = 0;
        g_Actors[a].following = false;
        g_Actors[a].scriptHold = false;
        g_Actors[a].aggroFlag = true;
        g_Actors[a].aggroTarget = playerid;
        if (g_Actors[a].aggroMode == AGGRO_NONE) {
            g_Actors[a].aggroMode = AGGRO_CHASE;
            AggroSchedule(a, 100 + (rand() % 400));
        }
    }
}

static void GangOnDamage(int a, int playerid) {
    if (g_Actors[a].kind < KIND_GANG_BASE || playerid < 0 || playerid >= 1000) return;
    int leader = (g_Actors[a].packLeader == -1) ? a : g_Actors[a].packLeader;
    PackSetTarget(leader, playerid);
}

static bool PackTargetOk(int playerid, int gang) {
    if (playerid < 0 || playerid >= 1000 || !sampgdk_IsPlayerConnected(playerid)) return false;
    if (!g_NpcAsHuman && sampgdk_IsPlayerNPC(playerid)) return false;
    int st = sampgdk_GetPlayerState(playerid);
    if (st == 7 || st == 0 || st == 9) return false;
    (void)gang;
    return true;
}

static int g_HuddlePick[MAX_STREAM_ACTORS];

static void HuddleAnim(int a) {
    int leader = (g_Actors[a].packLeader == -1) ? a : g_Actors[a].packLeader;
    bool used[4] = {false, false, false, false};
    for (int b = 0; b < g_MaxActorsInPool; b++) {
        if (b == a || !g_Actors[b].inUse || g_Actors[b].isDead) continue;
        if (b != leader && g_Actors[b].packLeader != leader) continue;
        if (g_HuddlePick[b] >= 0 && g_HuddlePick[b] < 4) used[g_HuddlePick[b]] = true;
    }
    int pick = 0;
    for (int tries = 0; tries < 8; tries++) {
        pick = rand() % 4;
        if (!used[pick]) break;
    }
    g_HuddlePick[a] = pick;
    switch (pick) {
        case 0: PedAnim(a, "PED", "IDLE_chat", true, false, 0); break;
        case 1: PedAnim(a, "GANGS", "prtial_gngtlkA", true, false, 0); break;
        case 2: PedAnim(a, "GANGS", "prtial_gngtlkB", true, false, 0); break;
        default: PedAnim(a, "GANGS", "prtial_gngtlkE", true, false, 0); break;
    }
    g_Actors[a].huddleAnimAt = GetTimeMs() + 3000 + (rand() % 3000);
}

static void HuddleAnimTick(int a, uint64_t now) {
    if (g_Actors[a].huddleAnimAt != 0 && g_Actors[a].huddleAnimAt <= now) HuddleAnim(a);
}

static void LeaderFaceHuddle(int a) {
    float cx = 0.0f, cy = 0.0f;
    int n = 0;
    for (int b = 0; b < g_MaxActorsInPool; b++) {
        if (!g_Actors[b].inUse || g_Actors[b].isDead || g_Actors[b].packLeader != a) continue;
        if (g_Actors[b].speed != 0.0f) return;
        cx += g_Actors[b].currentX;
        cy += g_Actors[b].currentY;
        n++;
    }
    if (n == 0) return;
    cx /= n;
    cy /= n;
    float want = AngleTo(g_Actors[a].currentX, g_Actors[a].currentY, cx, cy);
    if (std::abs(NormAngle(want - g_Actors[a].currentAngle + 180.0f) - 180.0f) > 3.0f) {
        FaceSlot(a, want);
    }
}

static void LeaderTick(int a, uint64_t now) {
    if (g_Actors[a].aggroMode != AGGRO_NONE || g_Actors[a].scriptHold) return;
    if (g_Actors[a].gangThink <= now && g_Actors[a].retargetAfter <= now) {
        g_Actors[a].gangThink = now + PACK_THINK_MS;
        for (int p : g_HumanPlayers) {
            if (g_PlayerGang[p] == 0 || g_PlayerGang[p] == g_Actors[a].gang) continue;
            if (!PackTargetOk(p, g_Actors[a].gang) || sampgdk_GetPlayerVirtualWorld(p) != sampgdk_GetActorVirtualWorld(g_Actors[a].actorid)) continue;
            float px, py, pz;
            sampgdk_GetPlayerPos(p, &px, &py, &pz);
            float dx = px - g_Actors[a].currentX, dy = py - g_Actors[a].currentY;
            if (dx*dx + dy*dy <= g_PackHostileRange * g_PackHostileRange && std::abs(pz - g_Actors[a].currentZ) < 6.0f) {
                PackSetTarget(a, p);
                return;
            }
        }
    }
    if (g_Actors[a].huddleUntil != 0) {
        if (g_Actors[a].huddleUntil <= now) {
            g_Actors[a].huddleUntil = 0;
            g_Actors[a].huddleAnimAt = 0;
            g_HuddlePick[a] = -1;
            g_Actors[a].nextHuddle = now + 20000 + (rand() % 20000);
            ResumeSlot(a);
        } else {
            LeaderFaceHuddle(a);
            HuddleAnimTick(a, now);
        }
        return;
    }
    if (g_Actors[a].nextHuddle <= now && g_Actors[a].state == PED_STATE_WALKING && g_Actors[a].aggroMode == AGGRO_NONE) {
        StopSlot(a);
        g_Actors[a].huddleUntil = now + 8000 + (rand() % 7000);
        HuddleAnim(a);
    }
}

static void TrailPush(int a) {
    if (g_Actors[a].trailN > 0) {
        float dx = g_Actors[a].currentX - g_Actors[a].trailX[0], dy = g_Actors[a].currentY - g_Actors[a].trailY[0];
        if (dx*dx + dy*dy < 0.25f) return;
    }
    for (int i = 7; i > 0; i--) { g_Actors[a].trailX[i] = g_Actors[a].trailX[i-1]; g_Actors[a].trailY[i] = g_Actors[a].trailY[i-1]; }
    g_Actors[a].trailX[0] = g_Actors[a].currentX;
    g_Actors[a].trailY[0] = g_Actors[a].currentY;
    if (g_Actors[a].trailN < 8) g_Actors[a].trailN++;
}

static void FollowerTick(int a, uint64_t now) {
    if (g_Actors[a].aggroMode != AGGRO_NONE || g_Actors[a].scriptHold) return;
    int L = g_Actors[a].packLeader;
    if (L < 0 || L >= g_MaxActorsInPool || !g_Actors[L].inUse || g_Actors[L].isDead || g_Actors[L].gang != g_Actors[a].gang) {
        PEDLOG("[Pedestrians] follower actor %d loses leader slot %d (inUse %d dead %d leader gang %d own gang %d)", g_Actors[a].actorid, L, (L >= 0 && L < g_MaxActorsInPool) ? (g_Actors[L].inUse ? 1 : 0) : -1, (L >= 0 && L < g_MaxActorsInPool) ? (g_Actors[L].isDead ? 1 : 0) : -1, (L >= 0 && L < g_MaxActorsInPool) ? g_Actors[L].gang : -1, g_Actors[a].gang);
        g_Actors[a].packLeader = -1;
        g_Actors[a].following = false;
        ResumeSlot(a);
        return;
    }
    if (g_Actors[L].huddleUntil != 0) {
        if (g_Actors[a].following || g_Actors[a].speed != 0.0f) {
            g_Actors[a].following = false;
            StopSlot(a);
            FaceSlot(a, AngleTo(g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[L].currentX, g_Actors[L].currentY));
            HuddleAnim(a);
        } else {
            HuddleAnimTick(a, now);
        }
        return;
    }
    g_Actors[a].huddleAnimAt = 0;
    g_HuddlePick[a] = -1;
    float tx, ty;
    int crumb = (g_Actors[a].packIndex == 1) ? 2 : 3;
    float side = (g_Actors[a].packIndex == 1) ? -0.7f : 0.7f;
    if (g_Actors[L].trailN > crumb) {
        float bx = g_Actors[L].trailX[crumb], by = g_Actors[L].trailY[crumb];
        float ax = g_Actors[L].trailX[crumb - 1] - bx, ay = g_Actors[L].trailY[crumb - 1] - by;
        float al = std::sqrt(ax*ax + ay*ay);
        if (al < 0.01f) { ax = 0.0f; ay = 1.0f; al = 1.0f; }
        tx = bx + (-ay / al) * side;
        ty = by + (ax / al) * side;
    } else {
        OffsetPoint(g_Actors[L].currentX, g_Actors[L].currentY, g_Actors[L].currentAngle + 180.0f + ((g_Actors[a].packIndex == 1) ? -40.0f : 40.0f), PACK_FOLLOW_GAP, tx, ty);
    }
    float dx = tx - g_Actors[a].currentX, dy = ty - g_Actors[a].currentY;
    float d = std::sqrt(dx*dx + dy*dy);
    if (g_Actors[L].speed == 0.0f && d < 1.2f) {
        if (g_Actors[a].following) {
            PEDLOG2("[Pedestrians] follower actor %d stops (gap %.2f, leader speed 0)", g_Actors[a].actorid, d);
            g_Actors[a].following = false;
            StopSlot(a);
            FaceSlot(a, g_Actors[L].currentAngle);
        }
        return;
    }
    float base = (g_Actors[L].speed > 0.0f) ? g_Actors[L].speed : 1.2f;
    float speed = base * (0.9f + (d - PACK_FOLLOW_GAP) * 0.6f);
    if (speed < 0.6f) speed = 0.6f;
    if (speed > base * 1.3f) speed = base * 1.3f;
    if (!g_Actors[a].following) {
        PEDLOG2("[Pedestrians] follower actor %d starts (gap %.2f, leader speed %.2f, own speed %.2f)", g_Actors[a].actorid, d, g_Actors[L].speed, speed);
        g_Actors[a].following = true;
        PedAnim(a, "PED", NameAnimations[g_Actors[a].walkStyle], true, false, 0);
    }
    WalkSlotTo(a, tx, ty, g_Actors[L].currentZ, speed);
}

static void IdleGagTick(int a, uint64_t now) {
    if (g_Actors[a].state != PED_STATE_STOPPED || g_Actors[a].kind >= KIND_GANG_BASE) return;
    if (g_Actors[a].huddleUntil != 0 || g_Actors[a].aggroMode != AGGRO_NONE || g_Actors[a].surrenderBy != -1) return;
    if (g_Actors[a].nextHuddle == 0) { g_Actors[a].nextHuddle = now + 20000; return; }
    if (g_Actors[a].nextHuddle > now) return;
    g_Actors[a].nextHuddle = now + 20000;
}

static void GangTick(int a, uint64_t now) {
    if (g_Actors[a].kind < KIND_GANG_BASE || g_Actors[a].isDead) return;
    if (g_Actors[a].packLeader == -1) LeaderTick(a, now);
    else FollowerTick(a, now);
}

static bool NavHandleNoRoute(int a, uint64_t now, float& tx, float& ty, float& tz, float& dist2D) {
    WalkingActor& w = g_Actors[a];
    if (w.hasTarget) {
        g_NavTargetFails++;
        w.navN = 0;
        NavCrowdDrop(a);
        StopSlot(a);
        NavFail(w.actorid);
        return false;
    }
    if (w.navGoal) {
        w.navGoal = false;
        w.navN = 0;
        NavCrowdDrop(a);
        SnapToGraph(a);
        return false;
    }
    if (w.navN == 0 && now < w.navFailUntil) return false;
    NavNoteDeadLeg(a, w.targetNodeId);
    if (NavRepickLeg(a, now, tx, ty, tz, dist2D)) return true;
    if (!w.navWaiting) g_NavLegsFail++;
    w.navWaiting = true;
    static int logged = 0;
    if (logged < 40) {
        logged++;
        logprintf("[Pedestrians] navleg actor %d kind %d body %d at (%.1f, %.1f, %.1f): no link of node %d reaches the mesh, waits", w.actorid, w.kind, ActorBody(a), w.currentX, w.currentY, w.currentZ, w.currentNodeId);
    }
    w.navFailUntil = now + 1500;
    NavCrowdDrop(a);
    return false;
}

void ProcessPhysics() {
    uint64_t now = GetTimeMs();

    if (!g_LastTargetInit) {
        for (int i = 0; i < MAX_PLAYERS; i++) g_PlayerLastTarget[i] = 0xFFFF;
        g_LastTargetInit = true;
    }
    int* playerLastTarget = g_PlayerLastTarget;
    for (int i : g_HumanPlayers) {
        ThrowPoll(i, now);
        {
            int target = sampgdk_GetPlayerTargetActor(i);
            if (target != 0xFFFF && target == playerLastTarget[i]) {
                KnifeCutCheck(i, target, now);
            }
            if (playerLastTarget[i] != 0xFFFF && playerLastTarget[i] != target) {
                SurrenderAimLost(playerLastTarget[i], i);
            }
            if (target != 0xFFFF && target != playerLastTarget[i]) {
                int pedSlot = SlotOf(target);
                bool isPed = pedSlot != -1;
                if (isPed) {
                    AggroOnAim(pedSlot, i);
                    KnifeCutCheck(i, target, now);
                    for (AMX* amx : g_AMX) {
                        int idx;
                        if (!amx_FindPublic(amx, "OnPlayerAimPedestrian", &idx)) {
                            amx_Push(amx, target);
                            amx_Push(amx, i);
                            cell ret;
                            amx_Exec(amx, &ret, idx);
                        }
                    }
                }
            }
            playerLastTarget[i] = target;
        }
    }

    int drivingPlayers[MAX_PLAYERS];
    int drivingVehicles[MAX_PLAYERS];
    float vehX[MAX_PLAYERS], vehY[MAX_PLAYERS], vehZ[MAX_PLAYERS];
    float vehVX[MAX_PLAYERS], vehVY[MAX_PLAYERS];
    int drivingCount = 0;

    for (int i : g_HumanPlayers) {
        if (sampgdk_GetPlayerState(i) == 2 && sampgdk_GetPlayerVirtualWorld(i) == 0) {
            int veh = sampgdk_GetPlayerVehicleID(i);
            float vx, vy, vz;
            sampgdk_GetVehicleVelocity(veh, &vx, &vy, &vz);
            if ((vx*vx + vy*vy) > 0.01f) {
                sampgdk_GetVehiclePos(veh, &vehX[drivingCount], &vehY[drivingCount], &vehZ[drivingCount]);
                vehVX[drivingCount] = vx;
                vehVY[drivingCount] = vy;
                drivingPlayers[drivingCount] = i;
                drivingVehicles[drivingCount] = veh;
                drivingCount++;
            }
        }
    }

    uint64_t physStartUs = NowUs();
    bool crowdBodies[NAV_BODY_COUNT] = {false, false, false};
    {
        int want[NAV_BODY_COUNT] = {0, 0, 0};
        for (int a = 0; a < g_MaxActorsInPool; a++) {
            if (!g_Actors[a].inUse || g_Actors[a].isDead || !g_Actors[a].nearHuman || !NavUsable(a)) continue;
            want[ActorBody(a)]++;
        }
        for (int b = 0; b < NAV_BODY_COUNT; b++) {
            if (!g_NavEnabled || !g_NavCrowdEnabled || !g_NavBodies[b].crowd) continue;
            crowdBodies[b] = true;
            NavCrowdBegin(b);
            if (!want[b]) continue;
            for (int hp : g_HumanPlayers) {
                if (sampgdk_GetPlayerVirtualWorld(hp) != 0 || sampgdk_GetPlayerState(hp) == 0) continue;
                float hx, hy, hz;
                sampgdk_GetPlayerPos(hp, &hx, &hy, &hz);
                NavCrowdStatic(b, NAV_OWNER_HUMAN, hp, hx, hy, hz - 1.0f);
            }
            for (int a = 0; a < g_MaxActorsInPool; a++) {
                const WalkingActor& w = g_Actors[a];
                if (!w.inUse || w.isDead || !w.nearHuman || w.navRef == 0 || w.crowdIdx >= 0 || ActorBody(a) != b || !NavUsable(a)) continue;
                if (w.state == PED_STATE_STOPPED || w.speed == 0.0f || w.scriptHold) NavCrowdStatic(b, NAV_OWNER_HELD, a, w.currentX, w.currentY, w.currentZ);
            }
        }
    }

    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;

        if (g_Actors[a].scriptHold) {
            NavCrowdDrop(a);
            g_Actors[a].lastUpdateTime = now;
            continue;
        }

        if (g_Actors[a].fallenTick > 0) {
            if (now - g_Actors[a].fallenTick > 2500) {
                g_Actors[a].fallenTick = 0;
                g_Actors[a].actionId = 1;
                g_Actors[a].actionTick = now;
                sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", "getup", 4.1f, false, false, false, false, 0);
            }
            g_Actors[a].lastUpdateTime = now;
            continue;
        }

        if (g_Actors[a].actionId == 1) {
            if (now - g_Actors[a].actionTick > 1500) {
                g_Actors[a].actionId = 0;
                if (g_Actors[a].panicTick > now) {
                    StartPanicRun(a);
                    SetPedState(a, PED_STATE_PANIC);
                } else {
                    g_Actors[a].speed = 1.2f;
                    sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", NameAnimations[g_Actors[a].walkStyle], 4.1f, true, true, true, false, 0);
                    SetPedState(a, PED_STATE_WALKING);
                }
            }
            g_Actors[a].lastUpdateTime = now;
            continue;
        }

        if (g_Actors[a].panicTick > 0 && g_Actors[a].panicTick <= now) {
            g_Actors[a].panicTick = 0;
            g_Actors[a].speed = 1.2f;
            sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", NameAnimations[g_Actors[a].walkStyle], 4.1f, true, true, true, false, 0);
            SetPedState(a, PED_STATE_WALKING);
        }

        if (g_Actors[a].holdUntil != 0) {
            if (g_Actors[a].holdUntil > now) continue;
            g_Actors[a].holdUntil = 0;
            if (g_Actors[a].holdSettle) {
                g_Actors[a].holdSettle = false;
                {
                    float mx = g_Actors[a].holdX - g_Actors[a].currentX, my = g_Actors[a].holdY - g_Actors[a].currentY;
                    PEDLOG2("[Pedestrians] settle actor %d %.2f m", g_Actors[a].actorid, std::sqrt(mx*mx + my*my));
                }
                g_Actors[a].currentX = g_Actors[a].holdX;
                g_Actors[a].currentY = g_Actors[a].holdY;
                g_Actors[a].sentValid = false;
            }
        }
        AggroTick(a, now);
        SurrenderTick(a, now);
        ChokeTick(a, now);
        KnifeCutTick(a, now);
        if (g_Actors[a].isDead) continue;
        GangTick(a, now);
        IdleGagTick(a, now);
        SteerSlot(a, now);
        SideStepSlot(a, now);

        float ax = g_Actors[a].currentX;
        float ay = g_Actors[a].currentY;
        float az = g_Actors[a].currentZ;

        for (int v = 0; v < drivingCount; v++) {
            float dx = ax - vehX[v];
            float dy = ay - vehY[v];
            float dz = std::abs(az - vehZ[v]);
            float distSq = dx*dx + dy*dy;

            if (dz <= 3.0f && distSq < 20.0f) {
                float vx = vehVX[v];
                float vy = vehVY[v];
                float speed = std::sqrt(vx*vx + vy*vy);

                float dot = dx * vx + dy * vy;
                if (dot > 0.0f) {
                    float cross = std::abs(dx * vy - dy * vx) / speed;
                    if (cross < 1.5f) {
                        g_Actors[a].speed = 0.0f;
                        sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", "KO_skid_front", 4.1f, false, true, true, true, 0);
                        g_Actors[a].fallenTick = now;
                        SetPedState(a, PED_STATE_FALLEN);

                        PEDLOG("[Pedestrians] run-over actor %d by player %d at %.0f km/h", g_Actors[a].actorid, drivingPlayers[v], speed * 195.20194f);
                        ApplyDamage(a, PED_HEALTH * 0.4f, drivingPlayers[v], 49);

                        for (AMX* amx : g_AMX) {
                            int idx;
                            if (!amx_FindPublic(amx, "OnPedestrianHitByVeh", &idx)) {
                                amx_Push(amx, g_Actors[a].actorid);
                                amx_Push(amx, drivingVehicles[v]);
                                amx_Push(amx, drivingPlayers[v]);
                                cell ret;
                                amx_Exec(amx, &ret, idx);
                            }
                        }
                        break;
                    }
                }
            }
        }

        if (g_Actors[a].fallenTick > 0) continue;
        if (g_Actors[a].speed == 0.0f) {
            NavCrowdDrop(a);
            float finalZ = g_Actors[a].currentZ + 0.9f;
            float rayZ = g_Actors[a].currentZ;
            if (g_Actors[a].navRef == 0 && RayCastTerrain(g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ, 0.0f, rayZ)) {
                if (g_Actors[a].floats && rayZ < g_Actors[a].floatZ) rayZ = g_Actors[a].floatZ;
                g_Actors[a].currentZ = rayZ;
                finalZ = rayZ + 0.9f;
            }
            SendActorPos(a, g_Actors[a].currentX, g_Actors[a].currentY, finalZ);
            continue;
        }

        float dt = (now > g_Actors[a].lastUpdateTime) ? (now - g_Actors[a].lastUpdateTime) / 1000.0f : 0.0f;
        if (dt > 0.5f) dt = 0.5f;
        g_Actors[a].lastUpdateTime = now;

        float tx, ty, tz;
        int targetIdx = -1;
        bool navOn = NavUsable(a) && NavEnsureRef(a, now);
        if (!navOn && g_Actors[a].navGoal) g_Actors[a].navGoal = false;
        if (g_Actors[a].hasTarget) {
            tx = g_Actors[a].tgtX;
            ty = g_Actors[a].tgtY;
            tz = g_Actors[a].tgtZ;
        } else if (g_Actors[a].navGoal) {
            tx = g_Actors[a].goalX;
            ty = g_Actors[a].goalY;
            tz = g_Actors[a].goalZ;
        } else {
            targetIdx = FindNodeIndex(g_Actors[a].targetNodeId);
            if (targetIdx == -1) continue;
            tx = g_Nodes[targetIdx].x;
            ty = g_Nodes[targetIdx].y;
            tz = g_Nodes[targetIdx].z;
        }

        float dx = tx - g_Actors[a].currentX;
        float dy = ty - g_Actors[a].currentY;
        float dist2D = std::sqrt(dx * dx + dy * dy);
        if (navOn) {
            uint64_t navT = NowUs();
            navOn = !NavDeadLeg(a) && NavFollow(a, tx, ty, tz, now, dist2D);
            if (!navOn) {
                if (!NavHandleNoRoute(a, now, tx, ty, tz, dist2D)) {
                    g_NavUs += NowUs() - navT;
                    if (g_Actors[a].speed != 0.0f) SendActorPos(a, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ + 0.9f);
                    continue;
                }
                navOn = true;
                targetIdx = FindNodeIndex(g_Actors[a].targetNodeId);
            }
            g_NavUs += NowUs() - navT;
        }

        if (g_Actors[a].hasTarget) {
            if (dist2D <= 1.0f) {
                g_Actors[a].hasTarget = false;
                g_Actors[a].speed = 0.0f;
                g_Actors[a].navN = 0;
                NavCrowdDrop(a);
                if (g_Actors[a].packLeader == -1 && g_Actors[a].kind < 100) {
                    CallPedCallback1("OnPedestrianReachTarget", g_Actors[a].actorid);
                }
                continue;
            }
        } else if (g_Actors[a].navGoal) {
            if (dist2D <= 1.0f) {
                g_Actors[a].navGoal = false;
                g_Actors[a].navN = 0;
                NavCrowdDrop(a);
                if (!(g_Actors[a].panicTick > now && g_Actors[a].hasFleePoint && NavStartFlee(a, g_Actors[a].fleeX, g_Actors[a].fleeY, g_Actors[a].fleeZ))) SnapToGraph(a);
                continue;
            }
        } else if (dist2D <= 1.8f) {
            g_Actors[a].previousNodeId = g_Actors[a].currentNodeId;
            g_Actors[a].currentNodeId = g_Actors[a].targetNodeId;
            g_Actors[a].targetNodeId = PickNextNodeFor(a, targetIdx);

            targetIdx = FindNodeIndex(g_Actors[a].targetNodeId);
            if (targetIdx != -1) {
                tx = g_Nodes[targetIdx].x;
                ty = g_Nodes[targetIdx].y;
                tz = g_Nodes[targetIdx].z;
                dx = tx - g_Actors[a].currentX;
                dy = ty - g_Actors[a].currentY;
                dist2D = std::sqrt(dx * dx + dy * dy);
                if (navOn) {
                    navOn = !NavDeadLeg(a) && NavFollow(a, tx, ty, tz, now, dist2D);
                    if (!navOn) {
                        if (!NavHandleNoRoute(a, now, tx, ty, tz, dist2D)) {
                            if (g_Actors[a].speed != 0.0f) SendActorPos(a, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ + 0.9f);
                            continue;
                        }
                        navOn = true;
                        targetIdx = FindNodeIndex(g_Actors[a].targetNodeId);
                    }
                }
            }
        }

        if (dist2D < 0.001f) dist2D = 0.001f;

        bool crowdDrive = false;
        float crowdPos[3] = {0, 0, 0}, crowdVel[3] = {0, 0, 0};
        g_Actors[a].navOnMesh = navOn;
        if (navOn) {
            int body = ActorBody(a);
            if (g_Actors[a].navN > 0) {
                dx = g_Actors[a].navPts[g_Actors[a].navIdx * 3] - g_Actors[a].currentX;
                dy = g_Actors[a].navPts[g_Actors[a].navIdx * 3 + 1] - g_Actors[a].currentY;
            }
            bool wantCrowd = crowdBodies[body] && g_Actors[a].nearHuman && now >= g_Actors[a].crowdBan && g_Actors[a].navN > 0;
            if (wantCrowd) {
                if (g_Actors[a].crowdIdx >= 0 && !NavCrowdOwned(g_Actors[a].crowdBody, g_Actors[a].crowdIdx, a)) g_Actors[a].crowdIdx = -1;
                if (g_Actors[a].crowdIdx < 0) {
                    uint64_t crowdT = NowUs();
                    float at[3] = {g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ};
                    g_Actors[a].crowdIdx = NavCrowdAddWalker(body, a, at, g_Actors[a].speed, g_Actors[a].navEndRef, g_Actors[a].navEndPos);
                    g_Actors[a].crowdBody = body;
                    g_Actors[a].crowdIdxAt = 0;
                    if (g_Actors[a].crowdIdx < 0) g_Actors[a].crowdBan = now + 2000;
                    g_CrowdUs += NowUs() - crowdT;
                }
                if (g_Actors[a].crowdIdx >= 0) {
                    bool failed = false;
                    dtPolyRef crowdRef = 0;
                    if (NavCrowdRead(body, g_Actors[a].crowdIdx, crowdPos, crowdVel, failed, crowdRef) && !failed && crowdRef) {
                        crowdDrive = true;
                        g_Actors[a].navRef = crowdRef;
                        {
                            float cdx = g_Actors[a].navPts[g_Actors[a].navIdx * 3] - g_Actors[a].currentX, cdy = g_Actors[a].navPts[g_Actors[a].navIdx * 3 + 1] - g_Actors[a].currentY;
                            float cd = std::sqrt(cdx * cdx + cdy * cdy);
                            if (g_Actors[a].crowdIdxSeen != g_Actors[a].navIdx || g_Actors[a].crowdIdxAt == 0) {
                                g_Actors[a].crowdIdxSeen = g_Actors[a].navIdx;
                                g_Actors[a].crowdIdxAt = now;
                                g_Actors[a].crowdIdxDist = cd;
                            } else if (now - g_Actors[a].crowdIdxAt > (uint64_t)((6.0f + 2.5f * g_Actors[a].crowdIdxDist / std::max(g_Actors[a].speed, 0.3f)) * 1000.0f)) {
                                g_NavStalls++;
                                const dtCrowdAgent* sag = g_NavBodies[body].crowd->getAgent(g_Actors[a].crowdIdx);
                                logprintf("[Pedestrians] crowd stall actor %d at (%.1f, %.1f) corner %d/%d %.1f m away for %.0f s, %d neighbours, speed %.2f of %.2f, target state %d, partial %d: the crowd lets go", g_Actors[a].actorid, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].navIdx, g_Actors[a].navN, cd, (now - g_Actors[a].crowdIdxAt) / 1000.0, sag ? sag->nneis : -1, sag ? std::sqrt(sag->vel[0] * sag->vel[0] + sag->vel[2] * sag->vel[2]) : -1.0f, g_Actors[a].speed, sag ? (int)sag->targetState : -1, sag ? (int)sag->partial : -1);
                                crowdDrive = false;
                                NavCrowdDrop(a);
                                g_Actors[a].crowdBan = now + 10000;
                                g_Actors[a].crowdIdxAt = now;
                            }
                        }
                        if (crowdDrive) {
                            NavCrowdSetSpeed(body, g_Actors[a].crowdIdx, g_Actors[a].speed);
                            g_Actors[a].crowdTick = now;
                            if (crowdVel[0] * crowdVel[0] + crowdVel[1] * crowdVel[1] > 0.04f) { dx = crowdVel[0]; dy = crowdVel[1]; }
                        }
                    } else {
                        NavCrowdDrop(a);
                        g_Actors[a].crowdBan = now + 3000;
                    }
                }
            } else {
                NavCrowdDrop(a);
            }
        } else {
            NavCrowdDrop(a);
        }

        float desiredAngle = std::atan2(-dx, dy) * (180.0f / 3.14159265f);
        if (g_Actors[a].steerUntil > now && !g_Actors[a].hasTarget) {
            desiredAngle += g_Actors[a].steerOffset;
        }
        float diff = desiredAngle - g_Actors[a].currentAngle;
        while(diff <= -180.0f) diff += 360.0f;
        while(diff > 180.0f) diff -= 360.0f;

        float baseTurnRate = (g_Actors[a].state == PED_STATE_PANIC) ? 250.0f : 120.0f;
        float maxTurnRate = baseTurnRate * dt;
        if (diff > maxTurnRate) diff = maxTurnRate;
        if (diff < -maxTurnRate) diff = -maxTurnRate;

        g_Actors[a].currentAngle += diff;
        while(g_Actors[a].currentAngle >= 360.0f) g_Actors[a].currentAngle -= 360.0f;
        while(g_Actors[a].currentAngle < 0.0f) g_Actors[a].currentAngle += 360.0f;

        float currentSpeed = g_Actors[a].speed;
        if (std::abs(diff) > 40.0f * dt) {
            currentSpeed *= 0.8f;
        }

        float rad = -g_Actors[a].currentAngle * (3.14159265f / 180.0f);
        float fwdX = std::sin(rad);
        float fwdY = std::cos(rad);

        float moveDist = currentSpeed * dt;
        float navZ = 0.0f;
        bool haveNavZ = false;
        if (crowdDrive) {
            g_Actors[a].currentX = crowdPos[0];
            g_Actors[a].currentY = crowdPos[1];
            navZ = crowdPos[2];
            haveNavZ = true;
            moveDist = 0.0f;
        } else {
        {
            float nxp = g_Actors[a].currentX + fwdX * moveDist;
            float nyp = g_Actors[a].currentY + fwdY * moveDist;
            bool blockedByPlayer = false;
            if (g_Actors[a].nearHuman) {
                for (int hp : g_HumanPlayers) {
                    float hx, hy, hz;
                    sampgdk_GetPlayerPos(hp, &hx, &hy, &hz);
                    float ddx = hx - nxp, ddy = hy - nyp;
                    if (ddx*ddx + ddy*ddy < 0.36f && std::abs(hz - (g_Actors[a].currentZ + 0.9f)) < 2.0f) { blockedByPlayer = true; break; }
                }
            }
            if (blockedByPlayer) {
                moveDist = 0.0f;
                if (now - g_Actors[a].dbgBlockAt >= 1000) {
                    g_Actors[a].dbgBlockAt = now;
                    PEDLOG2("[Pedestrians] blocked-by-player actor %d (aggro %d follow %d)", g_Actors[a].actorid, g_Actors[a].aggroMode, g_Actors[a].following ? 1 : 0);
                }
            }
        }
        if (navOn) {
            if (moveDist > 0.0f) {
                float out[3];
                if (NavMoveAlong(ActorBody(a), g_Actors[a].navRef, g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ, g_Actors[a].currentX + fwdX * moveDist, g_Actors[a].currentY + fwdY * moveDist, out)) {
                    g_Actors[a].currentX = out[0];
                    g_Actors[a].currentY = out[1];
                    navZ = out[2];
                    haveNavZ = true;
                } else {
                    g_Actors[a].navRef = 0;
                    g_Actors[a].navN = 0;
                    g_Actors[a].currentX += fwdX * moveDist;
                    g_Actors[a].currentY += fwdY * moveDist;
                }
            } else if (!haveNavZ) {
                NavPolyHeight(ActorBody(a), g_Actors[a].navRef, g_Actors[a].currentX, g_Actors[a].currentY, navZ);
                haveNavZ = true;
            }
        } else {
            g_Actors[a].currentX += fwdX * moveDist;
            g_Actors[a].currentY += fwdY * moveDist;
        }
        }
        if (moveDist > 0.0f && g_Actors[a].kind >= KIND_GANG_BASE && g_Actors[a].packLeader == -1) TrailPush(a);

        float oldZ = g_Actors[a].currentZ;
        float lerpZ = oldZ;
        float rayZ = oldZ;
        bool rayOk = false;
        if (haveNavZ) {
            rayZ = navZ;
            if (g_UseColAndreas) {
                float hx, hy, hz;
                if (Bridge_RayCast(g_Actors[a].currentX, g_Actors[a].currentY, navZ + 1.0f, g_Actors[a].currentX, g_Actors[a].currentY, navZ - 1.0f, &hx, &hy, &hz) != 0 && std::abs(hz - navZ) <= 0.5f) rayZ = hz;
            }
            rayOk = true;
        } else {
            rayOk = RayCastGround(g_Actors[a].currentX, g_Actors[a].currentY, oldZ, rayZ);
        }
        if (rayOk && g_Actors[a].floats && rayZ < g_Actors[a].floatZ) rayZ = g_Actors[a].floatZ;
        if (rayOk) {
            g_Actors[a].currentZ = rayZ;
        } else if (!g_UseColAndreas) {
            float dz = tz - g_Actors[a].currentZ;
            g_Actors[a].currentZ += dz * std::min(1.0f, dt * 2.5f);
            lerpZ = g_Actors[a].currentZ;
        }
        float finalZ = g_Actors[a].currentZ + 0.9f;
        if (g_DebugLevel > 1 && g_Actors[a].nearHuman && (std::abs(g_Actors[a].currentZ - oldZ) > 0.25f || !rayOk) && now - g_Actors[a].dbgZAt >= 1000) {
            g_Actors[a].dbgZAt = now;
            logprintf("[Pedestrians] HEIGHT actor %d at (%.1f,%.1f) z %.2f -> %.2f (lerp %.2f, node z %.2f, ray hit %d at %.2f accepted %d) target %d", g_Actors[a].actorid, g_Actors[a].currentX, g_Actors[a].currentY, oldZ, g_Actors[a].currentZ, lerpZ, tz, g_RayHit ? 1 : 0, g_RayZ, g_RayAccepted ? 1 : 0, g_Actors[a].hasTarget ? 1 : 0);
        }

        SendActorAngle(a, g_Actors[a].currentAngle);
        SendActorPos(a, g_Actors[a].currentX, g_Actors[a].currentY, finalZ);
    }

    uint64_t crowdStart = NowUs();
    static uint64_t s_lastCrowd = 0;
    float crowdDt = s_lastCrowd ? std::min(0.25f, std::max(0.03f, (now - s_lastCrowd) / 1000.0f)) : 0.08f;
    s_lastCrowd = now;
    for (int b = 0; b < NAV_BODY_COUNT; b++) {
        if (!crowdBodies[b]) continue;
        NavBody& nb = g_NavBodies[b];
        for (int i = 0; i < NAV_CROWD_AGENTS; i++) {
            int slot = nb.owner[i];
            if (slot < 0) continue;
            if (!g_Actors[slot].inUse || g_Actors[slot].isDead || g_Actors[slot].crowdIdx != i || g_Actors[slot].crowdTick != now) {
                NavCrowdRemove(b, i);
                if (g_Actors[slot].crowdIdx == i) g_Actors[slot].crowdIdx = -1;
            }
        }
        NavCrowdEnd(b, crowdDt);
    }
    uint64_t physUs = NowUs() - physStartUs;
    g_CrowdUs += NowUs() - crowdStart;
    g_PhysTicks++;
    g_PhysUs += physUs;
    if (g_PhysSamples.size() < 4096) g_PhysSamples.push_back((uint32_t)physUs);
    if (physUs > g_PhysMaxUs) g_PhysMaxUs = physUs;
}

static const float SPAWN_RING_MAX = 200.0f;
static const float SPAWN_RING_MIN = 35.0f;
static const float SPAWN_DESPAWN_MARGIN = 25.0f;

void ProcessStreaming() {
    float streamDistSq = g_StreamingDistance * g_StreamingDistance;
    float spawnMax = std::min(SPAWN_RING_MAX, g_StreamingDistance - SPAWN_DESPAWN_MARGIN);
    float spawnMin = std::min(SPAWN_RING_MIN, spawnMax * 0.5f);
    float spawnMaxSq = spawnMax * spawnMax;
    float spawnMinSq = spawnMin * spawnMin;

    uint64_t now = GetTimeMs();
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse) continue;

        if (g_Actors[a].isDead && now - g_Actors[a].deadTick >= (uint64_t)g_CorpseTimeMs) {
            BloodPoolDrop(a);
            sampgdk_SetActorPos(g_Actors[a].actorid, 0.0f, 0.0f, -1000.0f);
            g_Actors[a].inUse = false;
            UnmapActor(g_Actors[a].actorid);
            continue;
        }

        bool nearPlayer = false;
        bool closeHuman = false;
        float nearestSq = 1e30f;
        for (int p : g_HumanPlayers) {
            float px, py, pz;
            sampgdk_GetPlayerPos(p, &px, &py, &pz);
            float dx = g_Actors[a].currentX - px;
            float dy = g_Actors[a].currentY - py;
            float d = dx*dx + dy*dy;
            if (d < nearestSq) nearestSq = d;
            if (d < STEER_NEAR_HUMAN * STEER_NEAR_HUMAN) closeHuman = true;
            if (d < streamDistSq) {
                nearPlayer = true;
                if (closeHuman) break;
            }
        }
        g_Actors[a].nearHuman = closeHuman;

        if (!nearPlayer && g_Actors[a].kind != 2) {
            PEDLOG2("[Pedestrians] despawn actor %d nearest human %.0f m", g_Actors[a].actorid, std::sqrt(nearestSq));
            sampgdk_SetActorPos(g_Actors[a].actorid, 0.0f, 0.0f, -1000.0f);
            g_Actors[a].inUse = false;
            UnmapActor(g_Actors[a].actorid);
        }
    }

    for (int p : g_HumanPlayers) {
        if (sampgdk_GetPlayerState(p) == 0) continue;
        if (!g_AllowPedsInInteriors && sampgdk_GetPlayerInterior(p) != 0) continue;
        if (g_SpawnDensity <= 0.0f) continue;

        float px, py, pz;
        sampgdk_GetPlayerPos(p, &px, &py, &pz);

        int maxZonePeds = int(GetMaxPedsForPosition(px, py, pz) * g_SpawnDensity);
        if (maxZonePeds > g_MaxActorsPerPlayer) maxZonePeds = g_MaxActorsPerPlayer;
        if (maxZonePeds < 1) maxZonePeds = 1;

        int actorsNear = 0;
        for (int a = 0; a < g_MaxActorsInPool; a++) {
            if (!g_Actors[a].inUse || g_Actors[a].packLeader != -1) continue;
            float dx = g_Actors[a].currentX - px;
            float dy = g_Actors[a].currentY - py;
            if (dx*dx + dy*dy < 14400.0f) actorsNear++;
        }

        if (actorsNear < maxZonePeds) {
            float vx, vy, vz;
            sampgdk_GetPlayerVelocity(p, &vx, &vy, &vz);
            float speed = std::sqrt(vx*vx + vy*vy);

            float searchX = px;
            float searchY = py;
            if (speed > 0.05f) {
                float aheadMeters = std::min(speed * 250.0f, 150.0f);
                searchX += (vx / speed) * aheadMeters;
                searchY += (vy / speed) * aheadMeters;
            }

            std::vector<int> foundNodes;
            for (const auto& node : g_Nodes) {
                if (g_IgnoredNodes.count((uint32_t)node.id) != 0) continue;
                float dx = node.x - searchX;
                float dy = node.y - searchY;
                if (std::abs(dx) <= 300.0f && std::abs(dy) <= 300.0f) {
                    if (dx*dx + dy*dy <= 90000.0f) {
                        foundNodes.push_back(node.id);
                    }
                }
            }
            if (foundNodes.size() > 1) {
                static std::mt19937 rng(std::random_device{}());
                std::shuffle(foundNodes.begin(), foundNodes.end(), rng);
            }

            for (int nid : foundNodes) {
                if (actorsNear >= maxZonePeds) break;
                int idx = FindNodeIndex(nid);
                if (idx == -1) continue;

                float nx = g_Nodes[idx].x;
                float ny = g_Nodes[idx].y;
                float nz = g_Nodes[idx].z;

                float dx = nx - px;
                float dy = ny - py;
                if (dx*dx + dy*dy < spawnMinSq) continue;
                if (dx*dx + dy*dy > spawnMaxSq) continue;

                bool occupied = false;
                for (int a = 0; a < g_MaxActorsInPool; a++) {
                    if (g_Actors[a].inUse) {
                        float adx = nx - g_Actors[a].currentX;
                        float ady = ny - g_Actors[a].currentY;
                        if (adx*adx + ady*ady < 625.0f) {
                            occupied = true;
                            break;
                        }
                    }
                }
                if (occupied) continue;

                int slot = -1;
                for (int a = 0; a < g_MaxActorsInPool; a++) {
                    if (!g_Actors[a].inUse) {
                        slot = a;
                        break;
                    }
                }
                if (slot == -1) break;

                int gangHere = GangAt(nx, ny);
                if (gangHere != 0 && (rand() % g_PackOdds) == 0 && CountPacks(gangHere) < g_MaxPacksPerGang) {
                    int spawned = SpawnPack(gangHere, nid, nx, ny, nz, p);
                    if (spawned > 0) {
                        actorsNear += 1;
                        continue;
                    }
                }

                int skin = GetSkinForPosition(nx, ny, nz);
                int walkStyle = GetWalkStyleForSkin(skin);

                if (g_Actors[slot].actorid != 0 && g_Actors[slot].actorid != 0xFFFF) {
                    sampgdk_DestroyActor(g_Actors[slot].actorid);
                }
                BloodPoolDrop(slot);

                float rayZ = nz;
                if (g_UseColAndreas) {
                    if (!RayCastSpawn(nx, ny, nz, rayZ)) continue;
                    nz = rayZ;
                }

                float spawnZ = nz;
                if (!g_UseColAndreas) spawnZ += 0.9f;

                int newActor = sampgdk_CreateActor(skin, nx, ny, spawnZ, 0.0f);
                if (newActor == 0xFFFF || newActor < 0) continue;

                g_Actors[slot].actorid = newActor;
                MapActor(newActor, slot);
                if (g_DebugLevel > 1) {
                    float cx, cy, cz, fx, fy, fz;
                    sampgdk_GetPlayerCameraPos(p, &cx, &cy, &cz);
                    sampgdk_GetPlayerCameraFrontVector(p, &fx, &fy, &fz);
                    float vx2 = nx - cx, vy2 = ny - cy;
                    float vl = std::sqrt(vx2*vx2 + vy2*vy2), fl = std::sqrt(fx*fx + fy*fy);
                    float dot = (vl > 0.01f && fl > 0.01f) ? (vx2*fx + vy2*fy) / (vl * fl) : 0.0f;
                    logprintf("[Pedestrians] spawn actor %d %.0f m from player %d, camera dot %.2f (%s), near %d/%d", newActor, std::sqrt(dx*dx + dy*dy), p, dot, dot > 0.5f ? "IN VIEW" : "off screen", actorsNear, maxZonePeds);
                }
                g_Actors[slot].currentZ = nz;
                g_Actors[slot].skin = skin;
                sampgdk_SetActorInvulnerable(g_Actors[slot].actorid, false);
                sampgdk_SetActorVirtualWorld(g_Actors[slot].actorid, sampgdk_GetPlayerVirtualWorld(p));

                sampgdk_ApplyActorAnimation(g_Actors[slot].actorid, "PED", NameAnimations[walkStyle], 4.1f, true, true, true, false, 0);

                g_Actors[slot].inUse = true;
                g_Actors[slot].isDead = false;
                g_Actors[slot].walkStyle = walkStyle;
                g_Actors[slot].fallenTick = 0;
                g_Actors[slot].health = PED_HEALTH;
                g_Actors[slot].state = PED_STATE_WALKING;
                g_Actors[slot].panicTick = 0;
                g_Actors[slot].actionId = 0;
                g_Actors[slot].kind = 0;
                g_Actors[slot].deadTick = 0;
                g_Actors[slot].hasTarget = false;
                g_Actors[slot].hasFleePoint = false;
                AggroResetSlot(slot);
                AggroRoll(slot);
                g_Actors[slot].steerOffset = 0.0f;
                g_Actors[slot].steerUntil = 0;
                g_Actors[slot].nextObstacleCheck = 0;
                g_Actors[slot].nextCurbCheck = 0;
                g_Actors[slot].nearHuman = true;
                g_Actors[slot].chokeUntil = 0;
                g_Actors[slot].cutUntil = 0;
                g_Actors[slot].cutBy = -1;
                g_Actors[slot].gang = 0;
                g_Actors[slot].packLeader = -1;
                g_Actors[slot].packIndex = 0;
                g_Actors[slot].huddleUntil = 0;
                g_Actors[slot].nextHuddle = 0;
                g_Actors[slot].gunTarget = -1;
                g_Actors[slot].nextShot = 0;
                g_Actors[slot].gangThink = 0;
                g_Actors[slot].following = false;
                g_Actors[slot].retargetAfter = 0;
                g_Actors[slot].huddleAnimAt = 0;
                g_Actors[slot].sentValid = false;
                g_Actors[slot].holdUntil = 0;
                g_Actors[slot].holdSettle = false;
                g_Actors[slot].trailN = 0;
                g_Actors[slot].scriptHold = false;
                g_Actors[slot].floats = false;
                SetActorWalk(slot, nid, 1.2f);

                for (AMX* amx : g_AMX) {
                    int idx;
                    if (!amx_FindPublic(amx, "OnPedestrianSpawn", &idx)) {
                        amx_Push(amx, nid);
                        amx_Push(amx, g_Actors[slot].actorid);
                        cell ret;
                        amx_Exec(amx, &ret, idx);
                    }
                }

                actorsNear++;
            }
        }
    }
}

cell AMX_NATIVE_CALL n_Path_PrintNavStats(AMX* amx, cell* params);

void Ped_ProcessTick() {
    if (!g_PathFailed.empty()) {
        std::vector<int> failed;
        failed.swap(g_PathFailed);
        for (int actorid : failed) CallPedCallback1("OnPedestrianPathFailed", actorid);
    }
    if (g_HumanPlayers.empty()) {
        return;
    }

    uint64_t now = GetTimeMs();
    if (now - g_LastPhysicsTick >= 80) {
        g_LastPhysicsTick = now;
        ProcessPhysics();
        BloodTick(now);
        GasTick(now);
    }

    BloodSplatTick(now);
    if (now - g_LastStreamTick >= 1000) {
        g_LastStreamTick = now;
        ProcessStreaming();
        if (g_DebugLevel > 1) {
            static uint64_t lastCensus = 0;
            if (now - lastCensus >= 10000) {
                lastCensus = now;
                int alive = 0, dead = 0, gangs = 0, girls = 0, dealers = 0, walking = 0, stopped = 0, panic = 0;
                for (int a = 0; a < g_MaxActorsInPool; a++) {
                    if (!g_Actors[a].inUse) continue;
                    if (g_Actors[a].isDead) { dead++; continue; }
                    alive++;
                    if (g_Actors[a].kind >= KIND_GANG_BASE) gangs++;
                    else if (g_Actors[a].kind == 1) girls++;
                    else if (g_Actors[a].kind == 2) dealers++;
                    if (g_Actors[a].state == PED_STATE_WALKING) walking++;
                    else if (g_Actors[a].state == PED_STATE_STOPPED) stopped++;
                    else if (g_Actors[a].state == PED_STATE_PANIC) panic++;
                }
                logprintf("[Pedestrians] census: humans %d, alive %d (walking %d, stopped %d, panic %d), dead %d, gang %d, girls %d, dealers %d", (int)g_HumanPlayers.size(), alive, walking, stopped, panic, dead, gangs, girls, dealers);
                n_Path_PrintNavStats(nullptr, nullptr);
                for (int a = 0; a < g_MaxActorsInPool; a++) {
                    if (!g_Actors[a].inUse || g_Actors[a].isDead || g_Actors[a].kind < KIND_GANG_BASE || g_Actors[a].packLeader != -1) continue;
                    int members = 0;
                    float far = 0.0f;
                    for (int b = 0; b < g_MaxActorsInPool; b++) {
                        if (!g_Actors[b].inUse || g_Actors[b].isDead || g_Actors[b].packLeader != a) continue;
                        members++;
                        float dx = g_Actors[b].currentX - g_Actors[a].currentX, dy = g_Actors[b].currentY - g_Actors[a].currentY;
                        float d = std::sqrt(dx*dx + dy*dy);
                        if (d > far) far = d;
                    }
                    logprintf("[Pedestrians] pack leader %d gang %d: %d followers, farthest %.1f m, state %d, huddle %d, target %d", g_Actors[a].actorid, g_Actors[a].gang, members, far, g_Actors[a].state, g_Actors[a].huddleUntil != 0 ? 1 : 0, g_Actors[a].aggroTarget);
                }
            }
        }
    }
}

bool Ped_OnGameModeInit() {
    NavLoadAll("scriptfiles/nav");
    LoadZoneSkins();
    if (!LoadPedPaths()) {
        logprintf("[Pedestrians] WARNING: Nodes not loaded! Pedestrians will NOT spawn!");
    }
    for (int i = 0; i < MAX_STREAM_ACTORS; i++) {
        g_Actors[i].actorid = sampgdk_CreateActor(101, 0.0f, 0.0f, -1000.0f, 0.0f);
        if (g_Actors[i].actorid != 0xFFFF && g_Actors[i].actorid >= 0) {
            sampgdk_SetActorInvulnerable(g_Actors[i].actorid, false);
        }
        g_Actors[i].inUse = false;
    }
    RebuildHumanPlayers();
    logprintf("[Pedestrians] Configuration: MaxPool=%d, MaxPerPlayer=%d, Density=%.2f, StreamDist=%.1f",
        g_MaxActorsInPool, g_MaxActorsPerPlayer, g_SpawnDensity, g_StreamingDistance);
    return true;
}

bool Ped_OnPlayerConnect(int playerid) {
    RebuildHumanPlayers();
    return true;
}

bool Ped_OnPlayerDisconnect(int playerid, int reason) {
    if (playerid >= 0 && playerid < 1000) {
        g_PlayerGang[playerid] = 0;
        g_PlayerHuman[playerid] = true;
        g_Throw[playerid].weapon = 0;
        g_PlayerLastTarget[playerid] = 0xFFFF;
    }
    for (auto it = g_HumanPlayers.begin(); it != g_HumanPlayers.end(); ++it) {
        if (*it == playerid) {
            g_HumanPlayers.erase(it);
            break;
        }
    }
    return true;
}

bool Ped_OnPlayerWeaponShot(int playerid, int weaponid, int hittype, int hitid, float fX, float fY, float fZ) {
    if (!g_AmbientPanic) return true;
    if (weaponid == 43) return true;
    uint64_t now = GetTimeMs();
    if (playerid >= 0 && playerid < 1000) {
        if (now - g_ShotPanicTick[playerid] < 1000) return true;
        g_ShotPanicTick[playerid] = now;
    }

    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    float radiusSq = g_PanicRadius * g_PanicRadius;

    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
        float dx = g_Actors[a].currentX - px;
        float dy = g_Actors[a].currentY - py;
        float dz = std::abs(g_Actors[a].currentZ - pz);
        if (dz < 20.0f && (dx*dx + dy*dy < radiusSq)) {
            if (g_Actors[a].fallenTick == 0 && g_Actors[a].actionId == 0) {
                if (g_Actors[a].panicTick == 0) {
                    StartPanicRun(a);
                    SetPedState(a, PED_STATE_PANIC);
                }
            }
            g_Actors[a].panicTick = now + g_PanicDurationMs;
        }
    }
    return true;
}

cell AMX_NATIVE_CALL n_Path_AddMaleSkin(AMX* amx, cell* params) {
    int skinId = (int)params[1];
    int walkStyle = (int)params[2];
    g_MaleSkins.push_back({skinId, walkStyle});
    g_SkinWalkStyles[skinId] = walkStyle;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_AddFemaleSkin(AMX* amx, cell* params) {
    int skinId = (int)params[1];
    int walkStyle = (int)params[2];
    g_FemaleSkins.push_back({skinId, walkStyle});
    g_SkinWalkStyles[skinId] = walkStyle;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetTime(AMX* amx, cell* params) {
    g_ServerHour = (int)params[1];
    g_ServerMinute = (int)params[2];
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetMaxActorsInPool(AMX* amx, cell* params) {
    int count = (int)params[1];
    if (count < 1) count = 1;
    if (count > MAX_STREAM_ACTORS) count = MAX_STREAM_ACTORS;
    g_MaxActorsInPool = count;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_GetMaxActorsInPool(AMX* amx, cell* params) {
    return (cell)g_MaxActorsInPool;
}

cell AMX_NATIVE_CALL n_Path_SetMaxActorsPerPlayer(AMX* amx, cell* params) {
    int count = (int)params[1];
    if (count < 1) count = 1;
    if (count > MAX_STREAM_ACTORS) count = MAX_STREAM_ACTORS;
    g_MaxActorsPerPlayer = count;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_GetMaxActorsPerPlayer(AMX* amx, cell* params) {
    return (cell)g_MaxActorsPerPlayer;
}

cell AMX_NATIVE_CALL n_Path_SetSpawnDensity(AMX* amx, cell* params) {
    float density = amx_ctof(params[1]);
    if (density < 0.0f) density = 0.0f;
    if (density > 5.0f) density = 5.0f;
    g_SpawnDensity = density;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_GetSpawnDensity(AMX* amx, cell* params) {
    return amx_ftoc(g_SpawnDensity);
}

cell AMX_NATIVE_CALL n_Path_SetStreamingDistance(AMX* amx, cell* params) {
    float dist = amx_ctof(params[1]);
    if (dist < 30.0f) dist = 30.0f;
    if (dist > 600.0f) dist = 600.0f;
    g_StreamingDistance = dist;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_GetStreamingDistance(AMX* amx, cell* params) {
    return amx_ftoc(g_StreamingDistance);
}

cell AMX_NATIVE_CALL native_SetPedestrianHealth(AMX *amx, cell *params) {
    int actorid = params[1];
    float health = amx_ctof(params[2]);
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            g_Actors[a].health = health;
            if (health <= 0.0f) {
                TriggerPedDeath(a, 0xFFFF, 0);
            }
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_GetPedestrianHealth(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            return amx_ftoc(g_Actors[a].health);
        }
    }
    float zero = 0.0f;
    return amx_ftoc(zero);
}

cell AMX_NATIVE_CALL native_SetPedestrianSpeed(AMX *amx, cell *params) {
    int actorid = params[1];
    float speed = amx_ctof(params[2]);
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            if (g_Actors[a].isDead) return 0;
            g_Actors[a].speed = speed;
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_SetPedestrianFloats(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            g_Actors[a].floats = params[2] != 0;
            g_Actors[a].floatZ = amx_ctof(params[3]);
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_MakePedestrianPanic(AMX *amx, cell *params) {
    int actorid = params[1];
    int duration_ms = params[2];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            if (g_Actors[a].isDead) return 0;
            StartPanicRun(a);
            g_Actors[a].panicTick = GetTimeMs() + duration_ms;
            SetPedState(a, PED_STATE_PANIC);
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_IsPedestrianPanicking(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            return (g_Actors[a].panicTick > GetTimeMs()) ? 1 : 0;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_SetPedestrianSkin(AMX *amx, cell *params) {
    int actorid = params[1];
    int skinid = params[2];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            float ax, ay, az;
            sampgdk_GetActorPos(actorid, &ax, &ay, &az);
            sampgdk_DestroyActor(actorid);
            UnmapActor(actorid);
            int fresh = sampgdk_CreateActor(skinid, ax, ay, az, g_Actors[a].currentAngle);
            if (fresh == 0xFFFF || fresh < 0) {
                g_Actors[a].inUse = false;
                g_Actors[a].actorid = 0xFFFF;
                return 0xFFFF;
            }
            g_Actors[a].actorid = fresh;
            MapActor(fresh, a);
            g_Actors[a].sentValid = false;
            g_Actors[a].skin = skinid;
            g_Actors[a].walkStyle = GetWalkStyleForSkin(skinid);
            sampgdk_SetActorInvulnerable(g_Actors[a].actorid, false);

            if (g_Actors[a].isDead) {
                sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "CRACK", "crckdeth2", 4.1f, false, true, true, true, 0);
            } else if (g_Actors[a].state == PED_STATE_WALKING) {
                sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", NameAnimations[g_Actors[a].walkStyle], 4.1f, true, true, true, false, 0);
            } else if (g_Actors[a].state == PED_STATE_PANIC) {
                StartPanicRun(a);
            }
            return g_Actors[a].actorid;
        }
    }
    return 0xFFFF;
}

cell AMX_NATIVE_CALL native_GetPedestrianNode(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            return g_Actors[a].targetNodeId;
        }
    }
    return -1;
}

cell AMX_NATIVE_CALL native_PrintIgnoredNodesCount(AMX *amx, cell *params) {
    logprintf("[Pedestrians] Ignoring %u nodes.", (unsigned int)g_IgnoredNodes.size());
    return 1;
}

cell AMX_NATIVE_CALL native_GetClosestPedestrianID(AMX *amx, cell *params) {
    int playerid = params[1];
    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);
    int closestId = -1;
    float closestDist = 9999999.0f;
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse) continue;
        float ax, ay, az;
        sampgdk_GetActorPos(g_Actors[a].actorid, &ax, &ay, &az);
        float dx = ax - px; float dy = ay - py; float dz = az - pz;
        float dist = dx*dx + dy*dy + dz*dz;
        if (dist < closestDist) {
            closestDist = dist;
            closestId = g_Actors[a].actorid;
        }
    }
    return closestId;
}

cell AMX_NATIVE_CALL native_GetPedestrianSex(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            return IsFemaleSkin(g_Actors[a].skin) ? 2 : 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_StopPedestrian(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            if (g_Actors[a].isDead) return 0;
            AggroClear(a);
            StopSlot(a);
            g_Actors[a].scriptHold = true;
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL native_ResumePedestrian(AMX *amx, cell *params) {
    int actorid = params[1];
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            if (g_Actors[a].isDead) return 0;
            AggroClear(a);
            g_Actors[a].scriptHold = false;
            ResumeSlot(a);
            return 1;
        }
    }
    return 0;
}

cell AMX_NATIVE_CALL n_Path_AddNoSpawnArea(AMX *amx, cell *params) {
    float minX = amx_ctof(params[1]);
    float minY = amx_ctof(params[2]);
    float maxX = amx_ctof(params[3]);
    float maxY = amx_ctof(params[4]);
    if (minX > maxX) std::swap(minX, maxX);
    if (minY > maxY) std::swap(minY, maxY);
    int count = 0;
    for (const auto& node : g_Nodes) {
        if (node.x >= minX && node.x <= maxX && node.y >= minY && node.y <= maxY) {
            g_IgnoredNodes.insert((uint32_t)node.id);
            count++;
        }
    }
    return count;
}

cell AMX_NATIVE_CALL native_IgnorePedestrianNode(AMX *amx, cell *params) {
    g_IgnoredNodes.insert((uint32_t)params[1]);
    return 1;
}

cell AMX_NATIVE_CALL native_IsPlayerInFrontOfPed(AMX *amx, cell *params) {
    int playerid = params[1];
    int actorid = params[2];

    float px, py, pz;
    sampgdk_GetPlayerPos(playerid, &px, &py, &pz);

    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse && g_Actors[a].actorid == actorid) {
            float ax, ay, az;
            sampgdk_GetActorPos(actorid, &ax, &ay, &az);

            float dx = px - ax;
            float dy = py - ay;
            float dz = pz - az;
            float distSq = dx*dx + dy*dy + dz*dz;

            if (distSq > 400.0f) return 0;

            float pedDirX = std::sin(-g_Actors[a].currentAngle * 3.14159265f / 180.0f);
            float pedDirY = std::cos(-g_Actors[a].currentAngle * 3.14159265f / 180.0f);

            float dist2D = std::sqrt(dx*dx + dy*dy);
            if (dist2D < 0.01f) return 1;

            float dot = (dx / dist2D) * pedDirX + (dy / dist2D) * pedDirY;
            if (dot > 0.0f) return 1;
            return 0;
        }
    }
    return 0;
}

static int FindActorSlot(int actorid) {
    return SlotOf(actorid);
}

cell AMX_NATIVE_CALL native_IsValidPedestrian(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    return g_Actors[a].isDead ? 2 : 1;
}

cell AMX_NATIVE_CALL native_GetPedestriansInRange(AMX *amx, cell *params) {
    float x = amx_ctof(params[1]);
    float y = amx_ctof(params[2]);
    float z = amx_ctof(params[3]);
    float range = amx_ctof(params[4]);
    int max = (int)params[6];
    if (max > MAX_STREAM_ACTORS) max = MAX_STREAM_ACTORS;
    if (max < 0) max = 0;
    cell* out;
    amx_GetAddr(amx, params[5], &out);
    float rangeSq = range * range;
    int count = 0;
    for (int a = 0; a < g_MaxActorsInPool && count < max; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
        float dx = g_Actors[a].currentX - x;
        float dy = g_Actors[a].currentY - y;
        float dz = g_Actors[a].currentZ - z;
        if (dx*dx + dy*dy + dz*dz <= rangeSq) {
            out[count++] = g_Actors[a].actorid;
        }
    }
    return count;
}

cell AMX_NATIVE_CALL native_GetPedestrianPos(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    cell* addr;
    amx_GetAddr(amx, params[2], &addr); *addr = amx_ftoc(g_Actors[a].currentX);
    amx_GetAddr(amx, params[3], &addr); *addr = amx_ftoc(g_Actors[a].currentY);
    amx_GetAddr(amx, params[4], &addr); *addr = amx_ftoc(g_Actors[a].currentZ);
    return 1;
}

cell AMX_NATIVE_CALL native_SetPedestrianWalkStyle(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    int style = (int)params[2];
    if (a == -1 || style < 0 || style >= (int)(sizeof(NameAnimations) / sizeof(NameAnimations[0]))) return 0;
    g_Actors[a].walkStyle = style;
    if (g_Actors[a].state == PED_STATE_WALKING && !g_Actors[a].isDead) {
        sampgdk_ApplyActorAnimation(g_Actors[a].actorid, "PED", NameAnimations[style], 4.1f, true, true, true, false, 0);
    }
    return 1;
}

cell AMX_NATIVE_CALL native_SetPedestrianFacingAngle(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    float angle = amx_ctof(params[2]);
    while (angle >= 360.0f) angle -= 360.0f;
    while (angle < 0.0f) angle += 360.0f;
    g_Actors[a].currentAngle = angle;
    g_Actors[a].targetAngle = angle;
    g_Actors[a].sentAngle = angle;
    sampgdk_SetActorFacingAngle(g_Actors[a].actorid, angle);
    return 1;
}

cell AMX_NATIVE_CALL native_GetPedestrianFacingAngle(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    float angle = (a == -1) ? 0.0f : g_Actors[a].currentAngle;
    return amx_ftoc(angle);
}

cell AMX_NATIVE_CALL native_SetPedestrianTarget(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1 || g_Actors[a].isDead) return 0;
    AggroClear(a);
    g_Actors[a].scriptHold = false;
    g_Actors[a].surrenderBy = -1;
    g_Actors[a].scareTick = 0;
    g_Actors[a].tgtX = amx_ctof(params[2]);
    g_Actors[a].tgtY = amx_ctof(params[3]);
    g_Actors[a].tgtZ = amx_ctof(params[4]);
    g_Actors[a].speed = amx_ctof(params[5]);
    g_Actors[a].hasTarget = true;
    g_Actors[a].hasFleePoint = false;
    g_Actors[a].panicTick = 0;
    g_Actors[a].lastUpdateTime = GetTimeMs();
    g_Actors[a].navN = 0;
    g_Actors[a].navNextPlan = 0;
    g_Actors[a].navGoal = false;
    NavCrowdDrop(a);
    SetPedState(a, PED_STATE_WALKING);
    if (NavUsable(a) && NavEnsureRef(a, GetTimeMs())) {
        float from[3] = {g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ}, to[3] = {g_Actors[a].tgtX, g_Actors[a].tgtY, g_Actors[a].tgtZ};
        g_NavPlans++;
        if (!NavBuildRoute(ActorBody(a), from, to, g_ScratchRoute, g_Actors[a].navRef)) {
            g_NavPlanFails++;
            g_NavTargetFails++;
            g_NavFailReason[std::min(std::max(g_ScratchRoute.fail, 0), 4)]++;
            PEDLOG("[Pedestrians] no route for actor %d from (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f)", g_Actors[a].actorid, from[0], from[1], from[2], to[0], to[1], to[2]);
            g_Actors[a].hasTarget = false;
            StopSlot(a);
            NavFail(g_Actors[a].actorid);
            return 0;
        }
        g_NavLegsOk++;
        g_Actors[a].navN = g_ScratchRoute.n;
        g_Actors[a].navIdx = g_ScratchRoute.n > 1 ? 1 : 0;
        memcpy(g_Actors[a].navPts, g_ScratchRoute.pts, sizeof(float) * 3 * g_ScratchRoute.n);
        g_Actors[a].navEnd[0] = to[0]; g_Actors[a].navEnd[1] = to[1]; g_Actors[a].navEnd[2] = to[2];
        g_Actors[a].navEndRef = g_ScratchRoute.endRef;
        memcpy(g_Actors[a].navEndPos, g_ScratchRoute.endPos, sizeof(g_Actors[a].navEndPos));
        g_Actors[a].navNextPlan = GetTimeMs() + 400;
    } else if (NavUsable(a)) {
        g_NavOffMesh++;
        PEDLOG2("[Pedestrians] actor %d is off the %s mesh at (%.1f, %.1f, %.1f): old straight walk", g_Actors[a].actorid, NAV_BODY_FILE[ActorBody(a)], g_Actors[a].currentX, g_Actors[a].currentY, g_Actors[a].currentZ);
    }
    return 1;
}

cell AMX_NATIVE_CALL native_SetPedestrianBody(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    int body = (int)params[2];
    g_Actors[a].body = (body >= 0 && body < NAV_BODY_COUNT) ? body : -1;
    NavReset(a);
    return 1;
}

cell AMX_NATIVE_CALL native_GetPedestrianBody(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    return a == -1 ? -1 : ActorBody(a);
}

cell AMX_NATIVE_CALL native_IsPedestrianOnNav(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    return (a != -1 && g_Actors[a].navRef != 0 && NavUsable(a)) ? 1 : 0;
}

cell AMX_NATIVE_CALL native_PedestrianPathProbe(AMX *amx, cell *params) {
    int body = (int)params[1];
    if (!NavReady(body)) return -2;
    float from[3] = {amx_ctof(params[2]), amx_ctof(params[3]), amx_ctof(params[4])}, to[3] = {amx_ctof(params[5]), amx_ctof(params[6]), amx_ctof(params[7])};
    NavRoute r;
    bool ok = NavBuildRoute(body, from, to, r);
    cell* out;
    float lengthOut = ok ? r.length : -1.0f;
    if (amx_GetAddr(amx, params[8], &out) == AMX_ERR_NONE) *out = amx_ftoc(lengthOut);
    return ok ? r.n : -1;
}

cell AMX_NATIVE_CALL n_Path_SetNav(AMX* amx, cell* params) {
    g_NavEnabled = params[1] != 0;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetNavCrowd(AMX* amx, cell* params) {
    g_NavCrowdEnabled = params[1] != 0;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_ReloadNav(AMX* amx, cell* params) {
    for (int a = 0; a < MAX_STREAM_ACTORS; a++) g_Actors[a].crowdIdx = -1;
    int n = NavLoadAll("scriptfiles/nav");
    for (int b = 0; b < NAV_BODY_COUNT; b++) g_NavDeadLegs[b].clear();
    for (int a = 0; a < MAX_STREAM_ACTORS; a++) { g_Actors[a].navRef = 0; g_Actors[a].navN = 0; g_Actors[a].navGoal = false; }
    return n;
}

cell AMX_NATIVE_CALL n_Path_GetNavLegs(AMX* amx, cell* params) {
    cell* out;
    if (amx_GetAddr(amx, params[1], &out) == AMX_ERR_NONE) *out = (cell)g_NavLegsOk;
    if (amx_GetAddr(amx, params[2], &out) == AMX_ERR_NONE) *out = (cell)g_NavLegsFail;
    if (amx_GetAddr(amx, params[3], &out) == AMX_ERR_NONE) *out = (cell)g_NavStalls;
    if (params[0] >= 4 * (int)sizeof(cell) && amx_GetAddr(amx, params[4], &out) == AMX_ERR_NONE) *out = (cell)g_NavTargetFails;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_PrintNavStats(AMX* amx, cell* params) {
    uint32_t medianUs = 0;
    if (!g_PhysSamples.empty()) {
        size_t mid = g_PhysSamples.size() / 2;
        std::nth_element(g_PhysSamples.begin(), g_PhysSamples.begin() + mid, g_PhysSamples.end());
        medianUs = g_PhysSamples[mid];
    }
    g_PhysSamples.clear();
    int onNav = 0, alive = 0, waiting = 0;
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (!g_Actors[a].inUse || g_Actors[a].isDead) continue;
        alive++;
        if (g_Actors[a].navWaiting) waiting++;
        if (g_Actors[a].navRef != 0) onNav++;
    }
    logprintf("[Pedestrians] nav: %d alive, %d on a mesh, crowd agents %d/%d/%d, plans %llu (failed %llu), off-mesh %llu, physics %llu ticks avg %.0f us median %u us max %llu us (nav %llu us, crowd %llu us total)",
        alive, onNav, NavCrowdWalkerCount(0), NavCrowdWalkerCount(1), NavCrowdWalkerCount(2), (unsigned long long)g_NavPlans, (unsigned long long)g_NavPlanFails, (unsigned long long)g_NavOffMesh,
        (unsigned long long)g_PhysTicks, g_PhysTicks ? (double)g_PhysUs / (double)g_PhysTicks : 0.0, medianUs, (unsigned long long)g_PhysMaxUs, (unsigned long long)g_NavUs, (unsigned long long)g_CrowdUs);
    logprintf("[Pedestrians] navlegs: %llu routed, %llu graph legs with no route (%.2f%%), %llu scripted targets with no route, plan attempts %llu failed %llu (no start poly %llu, no end poly %llu, unreachable %llu, no corners %llu), crowd stalls %llu, %d walkers waiting for a route, flee starts: %llu on the mesh, %llu mesh found no goal, %llu actor off the mesh",
        (unsigned long long)g_NavLegsOk, (unsigned long long)g_NavLegsFail, (g_NavLegsOk + g_NavLegsFail) ? 100.0 * (double)g_NavLegsFail / (double)(g_NavLegsOk + g_NavLegsFail) : 0.0, (unsigned long long)g_NavTargetFails,
        (unsigned long long)g_NavPlans, (unsigned long long)g_NavPlanFails, (unsigned long long)g_NavFailReason[1], (unsigned long long)g_NavFailReason[2], (unsigned long long)g_NavFailReason[3], (unsigned long long)g_NavFailReason[4], (unsigned long long)g_NavStalls, waiting, (unsigned long long)g_NavFleeMesh, (unsigned long long)g_NavFleeNoGoal, (unsigned long long)g_NavFleeUnusable);
    g_PhysTicks = 0; g_PhysUs = 0; g_PhysMaxUs = 0; g_NavUs = 0; g_CrowdUs = 0;
    return alive;
}

cell AMX_NATIVE_CALL native_PedestrianFleeFrom(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1 || g_Actors[a].isDead) return 0;
    AggroClear(a);
    g_Actors[a].surrenderBy = -1;
    g_Actors[a].scareTick = 0;
    g_Actors[a].fleeX = amx_ctof(params[2]);
    g_Actors[a].fleeY = amx_ctof(params[3]);
    g_Actors[a].fleeZ = amx_ctof(params[4]);
    g_Actors[a].hasFleePoint = true;
    if (!NavStartFlee(a, g_Actors[a].fleeX, g_Actors[a].fleeY, g_Actors[a].fleeZ)) {
        if (g_Actors[a].hasTarget) {
            SnapToGraph(a);
        }
        int curIdx = FindNodeIndex(g_Actors[a].currentNodeId);
        int far = PickFarthestLink(curIdx, g_Actors[a].fleeX, g_Actors[a].fleeY, g_Actors[a].fleeZ);
        if (far != -1) g_Actors[a].targetNodeId = far;
    }
    StartPanicRun(a);
    g_Actors[a].panicTick = GetTimeMs() + (int)params[5];
    g_Actors[a].lastUpdateTime = GetTimeMs();
    SetPedState(a, PED_STATE_PANIC);
    return 1;
}

cell AMX_NATIVE_CALL native_SetPedestrianKind(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    g_Actors[a].kind = (int)params[2];
    if (g_Actors[a].kind != 0) {
        g_Actors[a].aggroFlag = false;
        AggroClear(a);
        g_Actors[a].surrenderBy = -1;
    }
    return 1;
}

cell AMX_NATIVE_CALL native_GetPedestrianKind(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    return g_Actors[a].kind;
}

static void FreeSlot(int a) {
    BloodPoolDrop(a);
    sampgdk_SetActorPos(g_Actors[a].actorid, 0.0f, 0.0f, -1000.0f);
    g_Actors[a].inUse = false;
    UnmapActor(g_Actors[a].actorid);
}

cell AMX_NATIVE_CALL native_DespawnPedestrian(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    FreeSlot(a);
    return 1;
}

cell AMX_NATIVE_CALL n_Path_ReloadNodes(AMX *amx, cell *params) {
    for (int a = 0; a < g_MaxActorsInPool; a++) {
        if (g_Actors[a].inUse) FreeSlot(a);
    }
    return LoadPedPaths() ? (cell)g_Nodes.size() : 0;
}

cell AMX_NATIVE_CALL n_Path_SetCorpseTime(AMX* amx, cell* params) {
    int ms = (int)params[1];
    if (ms < 0) ms = 0;
    g_CorpseTimeMs = ms;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetPanicRadius(AMX* amx, cell* params) {
    float r = amx_ctof(params[1]);
    if (r < 1.0f) r = 1.0f;
    g_PanicRadius = r;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetPanicDuration(AMX* amx, cell* params) {
    int ms = (int)params[1];
    if (ms < 100) ms = 100;
    g_PanicDurationMs = ms;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetGasTime(AMX* amx, cell* params) {
    int ms = (int)params[1];
    if (ms < 1000) ms = 1000;
    g_GasTimeMs = ms;
    return 1;
}

cell AMX_NATIVE_CALL native_IsPointInTearGas(AMX *amx, cell *params) {
    float x = amx_ctof(params[1]), y = amx_ctof(params[2]), z = amx_ctof(params[3]);
    for (int g = 0; g < MAX_GAS_CLOUDS; g++) {
        if (!g_Gas[g].active) continue;
        float dx = g_Gas[g].x - x, dy = g_Gas[g].y - y, dz = g_Gas[g].z - z;
        if (dx*dx + dy*dy + dz*dz <= 36.0f) return g_Gas[g].thrower + 1;
    }
    return 0;
}

cell AMX_NATIVE_CALL n_Path_AddGangZone(AMX* amx, cell* params) {
    GangZoneBox z;
    z.gang = (int)params[1];
    if (z.gang <= 0 || z.gang >= MAX_GANGS) return 0;
    z.minX = amx_ctof(params[2]); z.minY = amx_ctof(params[3]);
    z.maxX = amx_ctof(params[4]); z.maxY = amx_ctof(params[5]);
    if (z.minX > z.maxX) std::swap(z.minX, z.maxX);
    if (z.minY > z.maxY) std::swap(z.minY, z.maxY);
    g_GangZones.push_back(z);
    return (cell)g_GangZones.size();
}

cell AMX_NATIVE_CALL n_Path_SetGangSkins(AMX* amx, cell* params) {
    int gang = (int)params[1];
    if (gang <= 0 || gang >= MAX_GANGS) return 0;
    g_GangSkins[gang][0] = (int)params[2];
    g_GangSkins[gang][1] = (int)params[3];
    g_GangSkins[gang][2] = (int)params[4];
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetPlayerGang(AMX* amx, cell* params) {
    int playerid = (int)params[1];
    if (playerid < 0 || playerid >= 1000) return 0;
    g_PlayerGang[playerid] = (int)params[2];
    return 1;
}

cell AMX_NATIVE_CALL n_Path_GetPlayerGang(AMX* amx, cell* params) {
    int playerid = (int)params[1];
    if (playerid < 0 || playerid >= 1000) return 0;
    return g_PlayerGang[playerid];
}

cell AMX_NATIVE_CALL n_Path_SetPackOdds(AMX* amx, cell* params) {
    int odds = (int)params[1];
    if (odds < 1) odds = 1;
    g_PackOdds = odds;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetPackHostileRange(AMX* amx, cell* params) {
    float r = amx_ctof(params[1]);
    if (r < 1.0f) r = 1.0f;
    g_PackHostileRange = r;
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetMaxPacksPerGang(AMX* amx, cell* params) {
    int n = (int)params[1];
    if (n < 0) n = 0;
    g_MaxPacksPerGang = n;
    return 1;
}

cell AMX_NATIVE_CALL native_GetPedestrianGang(AMX *amx, cell *params) {
    int a = FindActorSlot((int)params[1]);
    if (a == -1) return 0;
    return g_Actors[a].gang;
}

cell AMX_NATIVE_CALL n_Path_SetPlayerHuman(AMX* amx, cell* params) {
    int playerid = (int)params[1];
    if (playerid < 0 || playerid >= 1000) return 0;
    g_PlayerHuman[playerid] = (params[2] != 0);
    RebuildHumanPlayers();
    return 1;
}

cell AMX_NATIVE_CALL n_Path_DebugThrow(AMX* amx, cell* params) {
    int playerid = (int)params[1];
    int weapon = (int)params[2];
    if (playerid < 0 || playerid >= 1000 || !sampgdk_IsPlayerConnected(playerid)) return 0;
    float x, y, z, facing;
    sampgdk_GetPlayerPos(playerid, &x, &y, &z);
    sampgdk_GetPlayerFacingAngle(playerid, &facing);
    float tx, ty;
    OffsetPoint(x, y, facing, 1.5f, tx, ty);
    ThrowLanded(playerid, weapon, tx, ty, z - 0.9f);
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetSteering(AMX* amx, cell* params) {
    g_SteerEnabled = (params[1] != 0);
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetDebug(AMX* amx, cell* params) {
    g_DebugLevel = (int)params[1];
    logprintf("[Pedestrians] debug level %d", g_DebugLevel);
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetNpcAsHuman(AMX* amx, cell* params) {
    g_NpcAsHuman = (params[1] != 0);
    RebuildHumanPlayers();
    logprintf("[Pedestrians] npc bots count as humans: %d (%d tracked)", g_NpcAsHuman ? 1 : 0, (int)g_HumanPlayers.size());
    return 1;
}

cell AMX_NATIVE_CALL n_TogglePedInInterior(AMX* amx, cell* params) {
    return 1;
}

cell AMX_NATIVE_CALL n_Path_SetUseColAndreas(AMX* amx, cell* params) {
    bool req = (params[1] != 0);
    if (req) {
        g_UseColAndreas = Bridge_HasCollision();
        return g_UseColAndreas ? 1 : 0;
    }
    g_UseColAndreas = false;
    return 1;
}

cell AMX_NATIVE_CALL native_ApplyPedestrianAnim(AMX *amx, cell *params) {
    int actorid = params[1];
    char animlib[64];
    char animname[64];
    cell *physAddr;
    int len;

    amx_GetAddr(amx, params[2], &physAddr);
    amx_StrLen(physAddr, &len);
    amx_GetString(animlib, physAddr, 0, sizeof(animlib));

    amx_GetAddr(amx, params[3], &physAddr);
    amx_StrLen(physAddr, &len);
    amx_GetString(animname, physAddr, 0, sizeof(animname));

    float fDelta = amx_ctof(params[4]);
    bool loop = (params[5] != 0);
    bool lockx = (params[6] != 0);
    bool locky = (params[7] != 0);
    bool freeze = (params[8] != 0);
    int time = params[9];

    sampgdk_ApplyActorAnimation(actorid, animlib, animname, fDelta, loop, lockx, locky, freeze, time);
    return 1;
}

void Ped_Load() {
    srand((unsigned)std::chrono::steady_clock::now().time_since_epoch().count());
}

void Ped_Unload() {
    for (int g = 0; g < MAX_GAS_CLOUDS; g++) {
        if (g_Gas[g].active) {
            sampgdk_DestroyObject(g_Gas[g].obj1);
            sampgdk_DestroyObject(g_Gas[g].obj2);
            g_Gas[g].active = false;
        }
    }
    for (int i = 0; i < MAX_STREAM_ACTORS; i++) {
        if (g_Actors[i].inUse || (g_Actors[i].actorid != 0 && g_Actors[i].actorid != 0xFFFF)) {
            sampgdk_DestroyActor(g_Actors[i].actorid);
            g_Actors[i].inUse = false;
            g_Actors[i].actorid = 0;
        }
    }
    NavUnload();
    g_Nodes.clear();
    g_NodeIdToIndex.clear();
    g_Zones.clear();
    g_SlotByActor.clear();
}

template <cell AMX_NATIVE_CALL (*Native)(AMX*, cell*)>
static cell AMX_NATIVE_CALL PedNativeTrampoline(AMX* amx, const cell* params) {
    return Native(amx, const_cast<cell*>(params));
}

#define PED_NATIVE(name, fn) { name, PedNativeTrampoline<&fn> }

static AMX_NATIVE_INFO ComponentNatives[] = {
    PED_NATIVE("TogglePedInInterior", n_TogglePedInInterior),
    PED_NATIVE("Path_SetUseColAndreas", n_Path_SetUseColAndreas),
    PED_NATIVE("Path_SetTime", n_Path_SetTime),
    PED_NATIVE("Path_SetMaxActorsInPool", n_Path_SetMaxActorsInPool),
    PED_NATIVE("Path_GetMaxActorsInPool", n_Path_GetMaxActorsInPool),
    PED_NATIVE("Path_SetMaxActorsPerPlayer", n_Path_SetMaxActorsPerPlayer),
    PED_NATIVE("Path_GetMaxActorsPerPlayer", n_Path_GetMaxActorsPerPlayer),
    PED_NATIVE("Path_SetSpawnDensity", n_Path_SetSpawnDensity),
    PED_NATIVE("Path_GetSpawnDensity", n_Path_GetSpawnDensity),
    PED_NATIVE("Path_SetStreamingDistance", n_Path_SetStreamingDistance),
    PED_NATIVE("Path_GetStreamingDistance", n_Path_GetStreamingDistance),
    PED_NATIVE("Path_AddMaleSkin", n_Path_AddMaleSkin),
    PED_NATIVE("Path_AddFemaleSkin", n_Path_AddFemaleSkin),
    PED_NATIVE("Path_IgnoreNode", native_IgnorePedestrianNode),
    PED_NATIVE("IgnorePedestrianNode", native_IgnorePedestrianNode),
    PED_NATIVE("Path_AddNoSpawnArea", n_Path_AddNoSpawnArea),
    PED_NATIVE("GetClosestPedestrianID", native_GetClosestPedestrianID),
    PED_NATIVE("GetPedestrianSex", native_GetPedestrianSex),
    PED_NATIVE("StopPedestrian", native_StopPedestrian),
    PED_NATIVE("ResumePedestrian", native_ResumePedestrian),
    PED_NATIVE("ApplyPedestrianAnim", native_ApplyPedestrianAnim),
    PED_NATIVE("IsPlayerInFrontOfPed", native_IsPlayerInFrontOfPed),
    PED_NATIVE("SetPedestrianHealth", native_SetPedestrianHealth),
    PED_NATIVE("GetPedestrianHealth", native_GetPedestrianHealth),
    PED_NATIVE("SetPedestrianSpeed", native_SetPedestrianSpeed),
    PED_NATIVE("SetPedestrianFloats", native_SetPedestrianFloats),
    PED_NATIVE("MakePedestrianPanic", native_MakePedestrianPanic),
    PED_NATIVE("IsPedestrianPanicking", native_IsPedestrianPanicking),
    PED_NATIVE("SetPedestrianSkin", native_SetPedestrianSkin),
    PED_NATIVE("GetPedestrianNode", native_GetPedestrianNode),
    PED_NATIVE("PrintIgnoredNodesCount", native_PrintIgnoredNodesCount),
    PED_NATIVE("IsValidPedestrian", native_IsValidPedestrian),
    PED_NATIVE("GetPedestriansInRange", native_GetPedestriansInRange),
    PED_NATIVE("GetPedestrianPos", native_GetPedestrianPos),
    PED_NATIVE("SetPedestrianFacingAngle", native_SetPedestrianFacingAngle),
    PED_NATIVE("SetPedestrianWalkStyle", native_SetPedestrianWalkStyle),
    PED_NATIVE("GetPedestrianFacingAngle", native_GetPedestrianFacingAngle),
    PED_NATIVE("SetPedestrianTarget", native_SetPedestrianTarget),
    PED_NATIVE("SetPedestrianBody", native_SetPedestrianBody),
    PED_NATIVE("GetPedestrianBody", native_GetPedestrianBody),
    PED_NATIVE("IsPedestrianOnNav", native_IsPedestrianOnNav),
    PED_NATIVE("PedestrianPathProbe", native_PedestrianPathProbe),
    PED_NATIVE("Path_SetNav", n_Path_SetNav),
    PED_NATIVE("Path_SetNavCrowd", n_Path_SetNavCrowd),
    PED_NATIVE("Path_ReloadNav", n_Path_ReloadNav),
    PED_NATIVE("Path_PrintNavStats", n_Path_PrintNavStats),
    PED_NATIVE("Path_GetNavLegs", n_Path_GetNavLegs),
    PED_NATIVE("PedestrianFleeFrom", native_PedestrianFleeFrom),
    PED_NATIVE("SetPedestrianKind", native_SetPedestrianKind),
    PED_NATIVE("GetPedestrianKind", native_GetPedestrianKind),
    PED_NATIVE("DespawnPedestrian", native_DespawnPedestrian),
    PED_NATIVE("Path_ReloadNodes", n_Path_ReloadNodes),
    PED_NATIVE("Path_SetCorpseTime", n_Path_SetCorpseTime),
    PED_NATIVE("Path_SetPanicRadius", n_Path_SetPanicRadius),
    PED_NATIVE("Path_SetPanicDuration", n_Path_SetPanicDuration),
    PED_NATIVE("Path_SetGasTime", n_Path_SetGasTime),
    PED_NATIVE("Path_SetDebug", n_Path_SetDebug),
    PED_NATIVE("Path_SetSteering", n_Path_SetSteering),
    PED_NATIVE("Path_DebugThrow", n_Path_DebugThrow),
    PED_NATIVE("Path_SetPlayerHuman", n_Path_SetPlayerHuman),
    PED_NATIVE("Path_SetNpcAsHuman", n_Path_SetNpcAsHuman),
    PED_NATIVE("Path_AddGangZone", n_Path_AddGangZone),
    PED_NATIVE("Path_SetGangSkins", n_Path_SetGangSkins),
    PED_NATIVE("Path_SetPlayerGang", n_Path_SetPlayerGang),
    PED_NATIVE("Path_GetPlayerGang", n_Path_GetPlayerGang),
    PED_NATIVE("Path_SetPackOdds", n_Path_SetPackOdds),
    PED_NATIVE("Path_SetPackHostileRange", n_Path_SetPackHostileRange),
    PED_NATIVE("Path_SetMaxPacksPerGang", n_Path_SetMaxPacksPerGang),
    PED_NATIVE("GetPedestrianGang", native_GetPedestrianGang),
    PED_NATIVE("IsPointInTearGas", native_IsPointInTearGas),
    {0, 0}
};

int Ped_AmxLoad(AMX *amx) {
    g_AMX.push_back(amx);
    return amx_Register(amx, ComponentNatives, -1);
}

int Ped_AmxUnload(AMX *amx) {
    for (auto it = g_AMX.begin(); it != g_AMX.end(); ++it) {
        if (*it == amx) {
            g_AMX.erase(it);
            break;
        }
    }
    return AMX_ERR_NONE;
}

bool Ped_OnPlayerGiveDamageActor(int playerid, int damaged_actorid, float amount, int weaponid, int bodypart) {
    int hitSlot = SlotOf(damaged_actorid);
    if (weaponid == 49 || weaponid == 50) hitSlot = -1;
    for (int a = hitSlot; a != -1; a = -1) {
        {
            float scaled = amount * WeaponDamageScale(weaponid, bodypart);
            if (weaponid >= 22 && weaponid <= 38 && bodypart != 9 && scaled > PED_HEALTH * 0.45f) scaled = PED_HEALTH * 0.45f;
            ApplyDamage(a, scaled, playerid, weaponid);
            if ((weaponid == 18 || weaponid == 37) && !g_Actors[a].isDead) {
                AggroClear(a);
                g_Actors[a].hasTarget = false;
                g_Actors[a].holdUntil = 0;
                g_Actors[a].holdSettle = false;
                g_Actors[a].huddleUntil = 0;
                g_Actors[a].following = false;
                StartPanicRun(a);
                g_Actors[a].panicTick = GetTimeMs() + 4000;
                if (g_Actors[a].state != PED_STATE_PANIC) SetPedState(a, PED_STATE_PANIC);
                break;
            }
            if ((weaponid == 41 || weaponid == 42) && !g_Actors[a].isDead && g_Actors[a].kind == 0) {
                ChokeSlot(a, GetTimeMs());
            } else if (g_Actors[a].kind >= KIND_GANG_BASE) {
                GangOnDamage(a, playerid);
            } else {
                AggroOnDamage(a, playerid, weaponid, amount);
            }
            break;
        }
    }
    for (AMX* amx : g_AMX) {
        int idx;
        if (!amx_FindPublic(amx, "OnPedestrianGetDamage", &idx)) {
            amx_Push(amx, amx_ftoc(amount));
            amx_Push(amx, weaponid);
            amx_Push(amx, playerid);
            amx_Push(amx, damaged_actorid);
            cell ret;
            amx_Exec(amx, &ret, idx);
        }
    }
    return true;
}
