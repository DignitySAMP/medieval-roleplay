#pragma once

#include <sdk.hpp>
#include <Server/Components/NPCs/npcs.hpp>
#include <Server/Components/Pawn/pawn.hpp>

#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <random>
#include <shared_mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "colandreas.hpp"
#include "node-graph.hpp"
#include "paths.hpp"

constexpr int PATHS_LAYERS = 2;
constexpr size_t PATHS_MAX_POINTS = 2048;
constexpr int PATHS_DEFAULT_WORKERS = 1;
constexpr int PATHS_MAX_WORKERS = 4;
constexpr int PATHS_DEFAULT_QUEUE = 64;
constexpr float PATHS_DEFAULT_LEVEL_TOLERANCE = 6.0f;
constexpr float PATHS_DEFAULT_MAX_DIST = 60.0f;
constexpr float PATHS_DEFAULT_POINT_RANGE_PED = 1.0f;
constexpr float PATHS_DEFAULT_POINT_RANGE_CAR = 3.0f;
constexpr uint32_t PATHS_MAX_ITERATIONS = 200000;
constexpr float PATHS_WALK_BODY = 1.0f;

struct PathRequest
{
	int id = 0;
	uint8_t layer = 0;
	Vector3 from {};
	Vector3 to {};
	uint32_t startFlat = PATHS_NO_FLAT;
	uint32_t targetFlat = PATHS_NO_FLAT;
	bool straight = false;
	int npcId = -1;
	NPCMoveType moveType = NPCMoveType_Auto;
	float speed = NPC_MOVE_SPEED_AUTO;
	float stopRange = 1.0f;
	uint64_t generation = 0;
	PathsResultHandler* handler = nullptr;
};

struct PathResult
{
	PathRequest request;
	bool success = false;
	int reason = PathsReason_Ok;
	std::vector<Vector3> points;
};

struct NpcSlot
{
	int requestId = 0;
	int pathId = -1;
};

class PathsComponent final : public IPathsComponent, public CoreEventHandler, public PawnEventHandler, public NPCEventHandler
{
private:
	ICore* core_ = nullptr;
	IPawnComponent* pawn_ = nullptr;
	INPCComponent* npcs_ = nullptr;
	IColAndreasComponent* colandreas_ = nullptr;

	RawAreas raw_;
	std::mutex rawMutex_;
	std::unordered_map<uint64_t, bool> manualBlocks_;
	std::shared_mutex graphMutex_;
	std::shared_ptr<LayerGraph> graphs_[PATHS_LAYERS];

	std::vector<std::thread> workers_;
	int workerCount_ = PATHS_DEFAULT_WORKERS;
	int queueLimit_ = PATHS_DEFAULT_QUEUE;
	float levelTolerance_ = PATHS_DEFAULT_LEVEL_TOLERANCE;
	float pointRange_[PATHS_LAYERS] = { PATHS_DEFAULT_POINT_RANGE_PED, PATHS_DEFAULT_POINT_RANGE_CAR };
	std::deque<PathRequest> tasks_;
	std::mutex taskMutex_;
	std::condition_variable taskCv_;
	bool stopWorkers_ = false;
	std::atomic<int> active_ { 0 };
	std::vector<PathResult> results_;
	std::mutex resultMutex_;

	int nextRequest_ = 1;
	uint64_t generation_ = 1;
	std::unordered_set<int> cancelled_;
	NpcSlot slots_[PLAYER_POOL_SIZE];
	std::mt19937 rng_ { std::random_device {}() };
	std::vector<NoSpawnArea> noSpawn_;
	std::vector<uint32_t> syncCameFrom_;
	std::vector<float> syncG_;
	std::vector<uint32_t> syncStamp_;
	uint32_t syncGen_ = 0;
	int nextNoSpawn_ = 1;

	inline static PathsComponent* instance_ = nullptr;

	std::shared_ptr<LayerGraph> graph(uint8_t layer)
	{
		std::shared_lock<std::shared_mutex> lock(graphMutex_);
		return layer < PATHS_LAYERS ? graphs_[layer] : nullptr;
	}

	void rebuild();
	void ensureWorkers();
	void workerLoop();
	void solve(PathRequest& request, PathResult& result, std::vector<uint32_t>& cameFrom, std::vector<float>& gScore, std::vector<uint32_t>& stamp, uint32_t& gen);
	int prepare(PathRequest& request);
	int submit(PathRequest request);
	void deliver(PathResult& result);
	void clearSlot(int npcId, bool stopEngine);
	bool floorAt(const Vector3& at, float above, float below, float& z);
	void applyLastMile(PathResult& result);

	template <typename... T>
	void callPublic(const char* name, T... args)
	{
		if (!pawn_)
		{
			return;
		}
		IPawnScript* script = pawn_->mainScript();
		if (script)
		{
			script->Call(name, DefaultReturnValue_True, args...);
		}
	}

public:
	PathsComponent();
	~PathsComponent();
	static PathsComponent* getInstance();

	StringView componentName() const override { return "paths"; }
	SemanticVersion componentVersion() const override { return SemanticVersion(0, 1, 0, 0); }

	void onLoad(ICore* c) override;
	void onInit(IComponentList* components) override;
	void onReady() override { }
	void onFree(IComponent* component) override;
	void free() override { delete this; }
	void reset() override;

	void onAmxLoad(IPawnScript& script) override;
	void onAmxUnload(IPawnScript& script) override;
	void onTick(Microseconds elapsed, TimePoint now) override;

	void onNPCFinishMovePath(INPC& npc, int pathId) override;
	void onNPCDestroy(INPC& npc) override;
	void onNPCRespawn(INPC& npc) override;

	int find(PathsLayer layer, const Vector3& from, const Vector3& to, PathsResultHandler* handler) override;
	int route(PathsLayer layer, const Vector3& from, const Vector3& to, Span<Vector3> out) override;
	bool cancel(int requestId) override;
	bool closestNode(PathsLayer layer, const Vector3& at, int& area, int& node, float maxDist) override;
	bool nodePos(PathsLayer layer, int area, int node, Vector3& out) override;
	bool randomNode(PathsLayer layer, const Vector3& around, float minDist, float maxDist, int& area, int& node) override;
	int linkCount(PathsLayer layer, int area, int node) override;
	bool link(PathsLayer layer, int area, int node, int index, int& toArea, int& toNode) override;
	int speedClass(int area, int node) override;
	int nodeCount(PathsLayer layer) override;
	bool isBlocked(PathsLayer layer, int area, int node) override;
	bool setBlocked(PathsLayer layer, int area, int node, bool blocked) override;
	bool spawnAllowed(const Vector3& at) override;
	int addNoSpawnArea(float minX, float minY, float maxX, float maxY) override;
	bool removeNoSpawnArea(int id) override;
	int noSpawnAreaCount() override;

	int moveNpc(int npcId, uint8_t layer, const Vector3& to, NPCMoveType moveType, float speed, float stopRange);
	bool stopNpc(int npcId);
	bool isNpcMoving(int npcId);
	int npcRequest(int npcId);
	float nodeDistance(uint8_t layer, int area1, int node1, int area2, int node2);
	int addNode(uint8_t layer, int area, const Vector3& at);
	bool addLink(uint8_t layer, int area, int node, int toArea, int toNode);
	bool loadCustom(const std::string& file);
	bool setWorkers(int count);
	bool setQueueLimit(int count);
	bool setLevelTolerance(float tolerance);
	bool setPointRange(uint8_t layer, float range);
	int pending();
};
