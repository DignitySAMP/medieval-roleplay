#include "paths-component.hpp"

#include <Server/Components/Pawn/Impl/pawn_natives.hpp>
#include <Server/Components/Pawn/Impl/pawn_impl.hpp>

#include <algorithm>
#include <cmath>
#include <fstream>
#include <limits>
#include <sstream>

struct OpenItem
{
	float f;
	float g;
	uint32_t flat;
	bool operator>(const OpenItem& other) const
	{
		if (f == other.f)
		{
			return g < other.g;
		}
		return f > other.f;
	}
};

static float heuristic(const Vector3& at, const Vector3& target, const Vector3& start)
{
	const float dx = at.x - target.x;
	const float dy = at.y - target.y;
	const float dz = at.z - target.z;
	const float dist = std::sqrt(dx * dx + dy * dy + dz * dz);
	const float sx = start.x - target.x;
	const float sy = start.y - target.y;
	const float cross = std::abs(dx * sy - sx * dy);
	return dist + cross * 0.001f;
}

PathsComponent::PathsComponent()
{
	instance_ = this;
}

PathsComponent::~PathsComponent()
{
	{
		std::lock_guard<std::mutex> lock(taskMutex_);
		stopWorkers_ = true;
		tasks_.clear();
	}
	taskCv_.notify_all();
	for (std::thread& worker : workers_)
	{
		if (worker.joinable())
		{
			worker.join();
		}
	}
	if (pawn_)
	{
		pawn_->getEventDispatcher().removeEventHandler(this);
	}
	if (npcs_)
	{
		npcs_->getEventDispatcher().removeEventHandler(this);
	}
	if (core_)
	{
		core_->getEventDispatcher().removeEventHandler(this);
	}
	instance_ = nullptr;
}

PathsComponent* PathsComponent::getInstance()
{
	if (!instance_)
	{
		instance_ = new PathsComponent();
	}
	return instance_;
}

void PathsComponent::onLoad(ICore* c)
{
	core_ = c;
	core_->getEventDispatcher().addEventHandler(this);
	setAmxLookups(core_);
}

void PathsComponent::onInit(IComponentList* components)
{
	pawn_ = components->queryComponent<IPawnComponent>();
	npcs_ = components->queryComponent<INPCComponent>();
	colandreas_ = components->queryComponent<IColAndreasComponent>();
	if (pawn_)
	{
		setAmxFunctions(pawn_->getAmxFunctions());
		setAmxLookups(components);
		pawn_->getEventDispatcher().addEventHandler(this);
	}
	if (npcs_)
	{
		npcs_->getEventDispatcher().addEventHandler(this);
	}

	std::string log;
	{
		std::lock_guard<std::mutex> lock(rawMutex_);
		loadNodeFiles(raw_, log);
	}
	rebuild();

	auto ped = graph(0);
	auto car = graph(1);
	core_->printLn("[paths] loaded - %d areas, ped %u nodes / %u links, car %u nodes / %u links (%u one-way links dropped)%s%s, npcs %s",
		raw_.areasLoaded,
		ped ? static_cast<unsigned>(ped->positions.size()) : 0u, ped ? static_cast<unsigned>(ped->links.size()) : 0u,
		car ? static_cast<unsigned>(car->positions.size()) : 0u, car ? static_cast<unsigned>(car->links.size()) : 0u,
		static_cast<unsigned>(raw_.oneWayDropped),
		log.empty() ? "" : ", ", log.c_str(),
		npcs_ ? "yes" : "MISSING");
}

void PathsComponent::onFree(IComponent* component)
{
	if (component == pawn_)
	{
		pawn_->getEventDispatcher().removeEventHandler(this);
		pawn_ = nullptr;
		setAmxFunctions();
		setAmxLookups();
	}
	if (component == npcs_)
	{
		npcs_->getEventDispatcher().removeEventHandler(this);
		npcs_ = nullptr;
	}
	if (component == colandreas_)
	{
		colandreas_ = nullptr;
	}
}

void PathsComponent::reset()
{
	{
		std::lock_guard<std::mutex> lock(taskMutex_);
		tasks_.clear();
	}
	{
		std::lock_guard<std::mutex> lock(resultMutex_);
		results_.clear();
	}
	generation_++;
	cancelled_.clear();
	for (int id = 0; id < PLAYER_POOL_SIZE; ++id)
	{
		if (slots_[id].pathId != -1 && npcs_)
		{
			npcs_->destroyPath(slots_[id].pathId);
		}
		slots_[id] = NpcSlot {};
	}
	{
		std::lock_guard<std::mutex> lock(rawMutex_);
		for (int area = 0; area < PATHS_AREAS; ++area)
		{
			raw_.nodes[area].resize(raw_.fileNodeCount[area]);
			raw_.links[area].resize(raw_.fileLinkCount[area]);
			raw_.customLinks[area].clear();
		}
		manualBlocks_.clear();
	}
	noSpawn_.clear();
	rebuild();
}

void PathsComponent::onAmxLoad(IPawnScript& script)
{
	pawn_natives::AmxLoad(script.GetAMX());
	generation_++;
}

void PathsComponent::onAmxUnload(IPawnScript& script)
{
	generation_++;
}

void PathsComponent::rebuild()
{
	std::shared_ptr<LayerGraph> built[PATHS_LAYERS];
	{
		std::lock_guard<std::mutex> lock(rawMutex_);
		for (uint8_t layer = 0; layer < PATHS_LAYERS; ++layer)
		{
			built[layer] = buildLayer(layer, raw_, manualBlocks_);
		}
	}
	std::unique_lock<std::shared_mutex> lock(graphMutex_);
	for (uint8_t layer = 0; layer < PATHS_LAYERS; ++layer)
	{
		graphs_[layer] = built[layer];
	}
}

void PathsComponent::ensureWorkers()
{
	if (!workers_.empty())
	{
		return;
	}
	for (int i = 0; i < workerCount_; ++i)
	{
		workers_.emplace_back(&PathsComponent::workerLoop, this);
	}
}

void PathsComponent::workerLoop()
{
	std::vector<uint32_t> cameFrom;
	std::vector<float> gScore;
	std::vector<uint32_t> stamp;
	uint32_t gen = 0;

	while (true)
	{
		PathRequest request;
		{
			std::unique_lock<std::mutex> lock(taskMutex_);
			taskCv_.wait(lock, [this] { return stopWorkers_ || !tasks_.empty(); });
			if (stopWorkers_)
			{
				return;
			}
			request = std::move(tasks_.front());
			tasks_.pop_front();
			active_.fetch_add(1, std::memory_order_relaxed);
		}

		PathResult result;
		result.request = request;
		solve(request, result, cameFrom, gScore, stamp, gen);

		{
			std::lock_guard<std::mutex> lock(resultMutex_);
			results_.push_back(std::move(result));
		}
		active_.fetch_sub(1, std::memory_order_relaxed);
	}
}

void PathsComponent::solve(PathRequest& request, PathResult& result, std::vector<uint32_t>& cameFrom, std::vector<float>& gScore, std::vector<uint32_t>& stamp, uint32_t& gen)
{
	result.success = false;
	result.reason = PathsReason_Unreachable;

	if (request.straight)
	{
		result.points.push_back(request.from);
		result.points.push_back(request.to);
		result.success = true;
		result.reason = PathsReason_Ok;
		return;
	}

	auto g = graph(request.layer);
	if (!g || request.startFlat >= g->positions.size() || request.targetFlat >= g->positions.size())
	{
		return;
	}

	const size_t count = g->positions.size();
	if (cameFrom.size() < count)
	{
		cameFrom.resize(count, PATHS_NO_FLAT);
		gScore.resize(count, 0.0f);
		stamp.resize(count, 0);
	}
	if (++gen == 0)
	{
		std::fill(stamp.begin(), stamp.end(), 0u);
		gen = 1;
	}

	auto touch = [&](uint32_t f)
	{
		if (stamp[f] != gen)
		{
			stamp[f] = gen;
			gScore[f] = std::numeric_limits<float>::infinity();
			cameFrom[f] = PATHS_NO_FLAT;
		}
	};

	const Vector3& startPos = g->positions[request.startFlat];
	const Vector3& targetPos = g->positions[request.targetFlat];

	std::vector<OpenItem> open;
	open.reserve(4096);
	touch(request.startFlat);
	gScore[request.startFlat] = 0.0f;
	open.push_back({ heuristic(startPos, targetPos, startPos), 0.0f, request.startFlat });

	bool found = false;
	uint32_t iterations = 0;
	while (!open.empty())
	{
		if (++iterations > PATHS_MAX_ITERATIONS)
		{
			break;
		}
		std::pop_heap(open.begin(), open.end(), std::greater<OpenItem>());
		const OpenItem current = open.back();
		open.pop_back();

		touch(current.flat);
		if (current.g > gScore[current.flat])
		{
			continue;
		}
		if (current.flat == request.targetFlat)
		{
			found = true;
			break;
		}

		const GraphLinkInfo& info = g->linkInfo[current.flat];
		for (uint32_t i = 0; i < info.count; ++i)
		{
			const GraphLink& link = g->links[info.offset + i];
			if (g->isBlocked(link.target))
			{
				continue;
			}
			touch(link.target);
			const float tentative = current.g + link.cost;
			if (tentative < gScore[link.target])
			{
				gScore[link.target] = tentative;
				cameFrom[link.target] = current.flat;
				open.push_back({ tentative + heuristic(g->positions[link.target], targetPos, startPos), tentative, link.target });
				std::push_heap(open.begin(), open.end(), std::greater<OpenItem>());
			}
		}
	}

	if (!found)
	{
		return;
	}

	std::vector<uint32_t> reverse;
	uint32_t cur = request.targetFlat;
	while (cur != request.startFlat && cur != PATHS_NO_FLAT)
	{
		reverse.push_back(cur);
		cur = cameFrom[cur];
	}
	reverse.push_back(request.startFlat);

	result.points.reserve(reverse.size() + 2);
	result.points.push_back(request.from);
	for (auto it = reverse.rbegin(); it != reverse.rend(); ++it)
	{
		result.points.push_back(g->positions[*it]);
	}
	result.points.push_back(request.to);
	result.success = true;
	result.reason = PathsReason_Ok;

	if (result.points.size() > PATHS_MAX_POINTS)
	{
		result.points.resize(PATHS_MAX_POINTS);
		result.reason = PathsReason_LastMileBlocked;
	}
}

int PathsComponent::prepare(PathRequest& request)
{
	if (request.layer >= PATHS_LAYERS)
	{
		return -PathsReason_BadArgs;
	}
	auto g = graph(request.layer);
	if (!g || g->positions.empty())
	{
		return -PathsReason_NoStartNode;
	}

	request.startFlat = g->closest(request.from, PATHS_DEFAULT_MAX_DIST, true);
	if (request.startFlat == PATHS_NO_FLAT)
	{
		return -PathsReason_NoStartNode;
	}
	request.targetFlat = g->closest(request.to, PATHS_DEFAULT_MAX_DIST, true);
	if (request.targetFlat == PATHS_NO_FLAT)
	{
		return -PathsReason_NoTargetNode;
	}
	if (std::abs(g->positions[request.startFlat].z - request.from.z) > levelTolerance_
		|| std::abs(g->positions[request.targetFlat].z - request.to.z) > levelTolerance_)
	{
		return -PathsReason_LevelMismatch;
	}
	if (request.startFlat == request.targetFlat)
	{
		request.straight = true;
	}
	else if (g->wcc[request.startFlat] != g->wcc[request.targetFlat] || g->scc[request.startFlat] < g->scc[request.targetFlat])
	{
		return -PathsReason_Unreachable;
	}
	return PathsReason_Ok;
}

int PathsComponent::route(PathsLayer layer, const Vector3& from, const Vector3& to, Span<Vector3> out)
{
	PathRequest request;
	request.layer = static_cast<uint8_t>(layer);
	request.from = from;
	request.to = to;
	const int prepared = prepare(request);
	if (prepared != PathsReason_Ok)
	{
		return prepared;
	}

	PathResult result;
	solve(request, result, syncCameFrom_, syncG_, syncStamp_, syncGen_);
	if (!result.success)
	{
		return -result.reason;
	}

	const size_t first = 1;
	const size_t last = result.points.size() > 1 ? result.points.size() - 1 : first;
	size_t written = 0;
	for (size_t i = first; i < last && written < out.size(); ++i)
	{
		out[written++] = result.points[i];
	}
	return static_cast<int>(written);
}

int PathsComponent::submit(PathRequest request)
{
	const int prepared = prepare(request);
	if (prepared != PathsReason_Ok)
	{
		return prepared;
	}

	request.id = nextRequest_++;
	if (nextRequest_ <= 0)
	{
		nextRequest_ = 1;
	}
	request.generation = generation_;

	ensureWorkers();
	{
		std::lock_guard<std::mutex> lock(taskMutex_);
		if (static_cast<int>(tasks_.size()) >= queueLimit_)
		{
			return -PathsReason_QueueFull;
		}
		tasks_.push_back(request);
	}
	taskCv_.notify_one();
	return request.id;
}

int PathsComponent::find(PathsLayer layer, const Vector3& from, const Vector3& to, PathsResultHandler* handler)
{
	PathRequest request;
	request.layer = static_cast<uint8_t>(layer);
	request.from = from;
	request.to = to;
	request.handler = handler;
	return submit(request);
}

bool PathsComponent::cancel(int requestId)
{
	if (requestId <= 0)
	{
		return false;
	}
	cancelled_.insert(requestId);
	for (int id = 0; id < PLAYER_POOL_SIZE; ++id)
	{
		if (slots_[id].requestId == requestId && slots_[id].pathId == -1)
		{
			slots_[id] = NpcSlot {};
		}
	}
	return true;
}

int PathsComponent::moveNpc(int npcId, uint8_t layer, const Vector3& to, NPCMoveType moveType, float speed, float stopRange)
{
	if (!npcs_ || npcId < 0 || npcId >= PLAYER_POOL_SIZE)
	{
		return -PathsReason_BadArgs;
	}
	INPC* npc = npcs_->get(npcId);
	if (!npc)
	{
		return -PathsReason_NpcGone;
	}
	stopNpc(npcId);

	PathRequest request;
	request.layer = layer;
	request.from = npc->getPosition();
	request.to = to;
	request.npcId = npcId;
	request.moveType = moveType;
	request.speed = speed;
	request.stopRange = stopRange;
	const int id = submit(request);
	if (id > 0)
	{
		slots_[npcId].requestId = id;
		slots_[npcId].pathId = -1;
	}
	return id;
}

void PathsComponent::clearSlot(int npcId, bool stopEngine)
{
	NpcSlot& slot = slots_[npcId];
	if (slot.pathId != -1)
	{
		if (stopEngine && npcs_)
		{
			INPC* npc = npcs_->get(npcId);
			if (npc && npc->getCurrentPathId() == slot.pathId)
			{
				npc->stopPath();
			}
		}
		if (npcs_)
		{
			npcs_->destroyPath(slot.pathId);
		}
	}
	else if (slot.requestId != 0)
	{
		cancelled_.insert(slot.requestId);
	}
	slot = NpcSlot {};
}

bool PathsComponent::stopNpc(int npcId)
{
	if (npcId < 0 || npcId >= PLAYER_POOL_SIZE)
	{
		return false;
	}
	const bool active = slots_[npcId].requestId != 0;
	clearSlot(npcId, true);
	return active;
}

bool PathsComponent::isNpcMoving(int npcId)
{
	return npcId >= 0 && npcId < PLAYER_POOL_SIZE && slots_[npcId].requestId != 0;
}

int PathsComponent::npcRequest(int npcId)
{
	return npcId >= 0 && npcId < PLAYER_POOL_SIZE ? slots_[npcId].requestId : 0;
}

void PathsComponent::deliver(PathResult& result)
{
	PathRequest& request = result.request;

	if (request.generation != generation_)
	{
		return;
	}
	auto cancelledIt = cancelled_.find(request.id);
	if (cancelledIt != cancelled_.end())
	{
		cancelled_.erase(cancelledIt);
		return;
	}

	applyLastMile(result);

	if (request.handler)
	{
		request.handler->onPathsResult(request.id, result.success, result.reason, Span<const Vector3>(result.points.data(), result.points.size()));
		return;
	}

	if (request.npcId == -1)
	{
		int pathId = -1;
		if (result.success && npcs_)
		{
			pathId = npcs_->createPath();
			if (pathId < 0)
			{
				result.success = false;
				result.reason = PathsReason_MoveRejected;
			}
			else
			{
				const float range = pointRange_[request.layer];
				for (size_t i = 0; i < result.points.size(); ++i)
				{
					npcs_->addPointToPath(pathId, result.points[i], i + 1 == result.points.size() ? request.stopRange : range);
				}
			}
		}
		callPublic("OnPathsFound", request.id, result.success ? pathId : -1, result.success ? 1 : 0, result.reason);
		return;
	}

	NpcSlot& slot = slots_[request.npcId];
	if (slot.requestId != request.id)
	{
		return;
	}
	INPC* npc = npcs_ ? npcs_->get(request.npcId) : nullptr;
	if (!npc)
	{
		slot = NpcSlot {};
		callPublic("OnPathsNpcFail", request.npcId, request.id, static_cast<int>(PathsReason_NpcGone));
		return;
	}
	if (!result.success)
	{
		slot = NpcSlot {};
		callPublic("OnPathsNpcFail", request.npcId, request.id, result.reason);
		return;
	}

	const int pathId = npcs_->createPath();
	if (pathId < 0)
	{
		slot = NpcSlot {};
		callPublic("OnPathsNpcFail", request.npcId, request.id, static_cast<int>(PathsReason_MoveRejected));
		return;
	}
	const float range = pointRange_[request.layer];
	for (size_t i = 0; i < result.points.size(); ++i)
	{
		npcs_->addPointToPath(pathId, result.points[i], i + 1 == result.points.size() ? request.stopRange : range);
	}
	if (!npc->moveByPath(pathId, request.moveType, request.speed, false))
	{
		npcs_->destroyPath(pathId);
		slot = NpcSlot {};
		callPublic("OnPathsNpcFail", request.npcId, request.id, static_cast<int>(PathsReason_MoveRejected));
		return;
	}
	slot.pathId = pathId;
}

void PathsComponent::onTick(Microseconds elapsed, TimePoint now)
{
	std::vector<PathResult> batch;
	{
		std::lock_guard<std::mutex> lock(resultMutex_);
		if (results_.empty())
		{
			return;
		}
		batch.swap(results_);
	}
	for (PathResult& result : batch)
	{
		deliver(result);
	}
}

void PathsComponent::onNPCFinishMovePath(INPC& npc, int pathId)
{
	const int npcId = npc.getID();
	if (npcId < 0 || npcId >= PLAYER_POOL_SIZE)
	{
		return;
	}
	NpcSlot& slot = slots_[npcId];
	if (slot.pathId != pathId)
	{
		return;
	}
	const int requestId = slot.requestId;
	if (npcs_)
	{
		npcs_->destroyPath(pathId);
	}
	slot = NpcSlot {};
	callPublic("OnPathsNpcArrive", npcId, requestId);
}

void PathsComponent::onNPCDestroy(INPC& npc)
{
	const int npcId = npc.getID();
	if (npcId >= 0 && npcId < PLAYER_POOL_SIZE)
	{
		clearSlot(npcId, false);
	}
}

void PathsComponent::onNPCRespawn(INPC& npc)
{
	const int npcId = npc.getID();
	if (npcId >= 0 && npcId < PLAYER_POOL_SIZE)
	{
		clearSlot(npcId, false);
	}
}

bool PathsComponent::closestNode(PathsLayer layer, const Vector3& at, int& area, int& node, float maxDist)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->closest(at, maxDist, false);
	if (f == PATHS_NO_FLAT)
	{
		return false;
	}
	area = g->flatArea[f];
	node = g->flatNode[f];
	return true;
}

bool PathsComponent::nodePos(PathsLayer layer, int area, int node, Vector3& out)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->flat(area, node);
	if (f == PATHS_NO_FLAT)
	{
		return false;
	}
	out = g->positions[f];
	return true;
}

bool PathsComponent::randomNode(PathsLayer layer, const Vector3& around, float minDist, float maxDist, int& area, int& node)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->random(around, minDist, maxDist, rng_, noSpawn_);
	if (f == PATHS_NO_FLAT)
	{
		return false;
	}
	area = g->flatArea[f];
	node = g->flatNode[f];
	return true;
}

int PathsComponent::linkCount(PathsLayer layer, int area, int node)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return 0;
	}
	const uint32_t f = g->flat(area, node);
	return f == PATHS_NO_FLAT ? 0 : static_cast<int>(g->linkInfo[f].count);
}

bool PathsComponent::link(PathsLayer layer, int area, int node, int index, int& toArea, int& toNode)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->flat(area, node);
	if (f == PATHS_NO_FLAT || index < 0 || static_cast<uint32_t>(index) >= g->linkInfo[f].count)
	{
		return false;
	}
	const uint32_t target = g->links[g->linkInfo[f].offset + index].target;
	toArea = g->flatArea[target];
	toNode = g->flatNode[target];
	return true;
}

int PathsComponent::speedClass(int area, int node)
{
	std::lock_guard<std::mutex> lock(rawMutex_);
	if (area < 0 || area >= PATHS_AREAS || node < 0 || static_cast<size_t>(node) >= raw_.nodes[area].size())
	{
		return 0;
	}
	return raw_.nodes[area][node].speedClass;
}

int PathsComponent::nodeCount(PathsLayer layer)
{
	auto g = graph(static_cast<uint8_t>(layer));
	return g ? static_cast<int>(g->positions.size()) : 0;
}

bool PathsComponent::isBlocked(PathsLayer layer, int area, int node)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->flat(area, node);
	return f != PATHS_NO_FLAT && g->isBlocked(f);
}

bool PathsComponent::setBlocked(PathsLayer layer, int area, int node, bool blocked)
{
	auto g = graph(static_cast<uint8_t>(layer));
	if (!g)
	{
		return false;
	}
	const uint32_t f = g->flat(area, node);
	if (f == PATHS_NO_FLAT)
	{
		return false;
	}
	g->blocked[f].store(blocked ? 1 : 0, std::memory_order_relaxed);
	std::lock_guard<std::mutex> lock(rawMutex_);
	manualBlocks_[blockKey(static_cast<uint8_t>(layer), area, node)] = blocked;
	return true;
}

float PathsComponent::nodeDistance(uint8_t layer, int area1, int node1, int area2, int node2)
{
	auto g = graph(layer);
	if (!g)
	{
		return -1.0f;
	}
	const uint32_t a = g->flat(area1, node1);
	const uint32_t b = g->flat(area2, node2);
	if (a == PATHS_NO_FLAT || b == PATHS_NO_FLAT)
	{
		return -1.0f;
	}
	return glm::distance(g->positions[a], g->positions[b]);
}

int PathsComponent::addNode(uint8_t layer, int area, const Vector3& at)
{
	if (layer >= PATHS_LAYERS || area < 0 || area >= PATHS_AREAS)
	{
		return -1;
	}
	int id;
	{
		std::lock_guard<std::mutex> lock(rawMutex_);
		if (raw_.nodes[area].size() >= 0xFFFF)
		{
			return -1;
		}
		RawNode node {};
		node.position = at;
		node.layer = layer;
		node.custom = true;
		id = static_cast<int>(raw_.nodes[area].size());
		raw_.nodes[area].push_back(node);
	}
	rebuild();
	return id;
}

bool PathsComponent::addLink(uint8_t layer, int area, int node, int toArea, int toNode)
{
	if (layer >= PATHS_LAYERS || area < 0 || area >= PATHS_AREAS || toArea < 0 || toArea >= PATHS_AREAS || node < 0 || toNode < 0)
	{
		return false;
	}
	{
		std::lock_guard<std::mutex> lock(rawMutex_);
		if (static_cast<size_t>(node) >= raw_.nodes[area].size() || static_cast<size_t>(toNode) >= raw_.nodes[toArea].size())
		{
			return false;
		}
		if (raw_.nodes[area][node].layer != layer || raw_.nodes[toArea][toNode].layer != layer)
		{
			return false;
		}
		raw_.customLinks[area][static_cast<uint16_t>(node)].push_back({ static_cast<uint16_t>(toArea), static_cast<uint16_t>(toNode) });
		raw_.customLinks[toArea][static_cast<uint16_t>(toNode)].push_back({ static_cast<uint16_t>(area), static_cast<uint16_t>(node) });
	}
	rebuild();
	return true;
}

bool PathsComponent::loadCustom(const std::string& file)
{
	std::ifstream in("scriptfiles/" + file);
	if (!in.is_open())
	{
		return false;
	}
	int added = 0;
	std::string line;
	std::lock_guard<std::mutex> lock(rawMutex_);
	while (std::getline(in, line))
	{
		if (line.empty() || line[0] == '#' || line[0] == ';')
		{
			continue;
		}
		std::istringstream iss(line);
		char type;
		if (!(iss >> type))
		{
			continue;
		}
		if (type == 'N' || type == 'n')
		{
			int layer, area;
			float x, y, z;
			if (!(iss >> layer >> area >> x >> y >> z) || layer < 0 || layer >= PATHS_LAYERS || area < 0 || area >= PATHS_AREAS)
			{
				continue;
			}
			RawNode node {};
			node.position = Vector3(x, y, z);
			node.layer = static_cast<uint8_t>(layer);
			node.custom = true;
			raw_.nodes[area].push_back(node);
			added++;
		}
		else if (type == 'L' || type == 'l')
		{
			int layer, area, node, toArea, toNode;
			if (!(iss >> layer >> area >> node >> toArea >> toNode) || layer < 0 || layer >= PATHS_LAYERS)
			{
				continue;
			}
			if (area < 0 || area >= PATHS_AREAS || toArea < 0 || toArea >= PATHS_AREAS || node < 0 || toNode < 0)
			{
				continue;
			}
			if (static_cast<size_t>(node) >= raw_.nodes[area].size() || static_cast<size_t>(toNode) >= raw_.nodes[toArea].size())
			{
				continue;
			}
			raw_.customLinks[area][static_cast<uint16_t>(node)].push_back({ static_cast<uint16_t>(toArea), static_cast<uint16_t>(toNode) });
			raw_.customLinks[toArea][static_cast<uint16_t>(toNode)].push_back({ static_cast<uint16_t>(area), static_cast<uint16_t>(node) });
			added++;
		}
	}
	if (added == 0)
	{
		return false;
	}
	std::shared_ptr<LayerGraph> built[PATHS_LAYERS];
	for (uint8_t layer = 0; layer < PATHS_LAYERS; ++layer)
	{
		built[layer] = buildLayer(layer, raw_, manualBlocks_);
	}
	std::unique_lock<std::shared_mutex> graphLock(graphMutex_);
	for (uint8_t layer = 0; layer < PATHS_LAYERS; ++layer)
	{
		graphs_[layer] = built[layer];
	}
	return true;
}

bool PathsComponent::setWorkers(int count)
{
	if (count < 1 || count > PATHS_MAX_WORKERS || !workers_.empty())
	{
		return false;
	}
	workerCount_ = count;
	return true;
}

bool PathsComponent::setQueueLimit(int count)
{
	if (count < 1)
	{
		return false;
	}
	queueLimit_ = count;
	return true;
}

bool PathsComponent::setLevelTolerance(float tolerance)
{
	if (tolerance <= 0.0f)
	{
		return false;
	}
	levelTolerance_ = tolerance;
	return true;
}

bool PathsComponent::setPointRange(uint8_t layer, float range)
{
	if (layer >= PATHS_LAYERS || range <= 0.0f)
	{
		return false;
	}
	pointRange_[layer] = range;
	return true;
}

int PathsComponent::pending()
{
	std::lock_guard<std::mutex> lock(taskMutex_);
	return static_cast<int>(tasks_.size()) + active_.load(std::memory_order_relaxed);
}

bool PathsComponent::spawnAllowed(const Vector3& at)
{
	return spawnAllowedAt(at, noSpawn_);
}

int PathsComponent::addNoSpawnArea(float minX, float minY, float maxX, float maxY)
{
	if (minX > maxX)
	{
		std::swap(minX, maxX);
	}
	if (minY > maxY)
	{
		std::swap(minY, maxY);
	}
	NoSpawnArea area { nextNoSpawn_++, minX, minY, maxX, maxY };
	noSpawn_.push_back(area);
	return area.id;
}

bool PathsComponent::removeNoSpawnArea(int id)
{
	for (size_t i = 0; i < noSpawn_.size(); ++i)
	{
		if (noSpawn_[i].id == id)
		{
			noSpawn_.erase(noSpawn_.begin() + i);
			return true;
		}
	}
	return false;
}

int PathsComponent::noSpawnAreaCount()
{
	return static_cast<int>(noSpawn_.size());
}

bool PathsComponent::floorAt(const Vector3& at, float above, float below, float& z)
{
	Vector3 hit;
	const int model = colandreas_->rayCast(Vector3(at.x, at.y, at.z + above), Vector3(at.x, at.y, at.z - below), hit);
	if (model == 0 || model == 20000)
	{
		return false;
	}
	z = hit.z;
	return true;
}

void PathsComponent::applyLastMile(PathResult& result)
{
	if (!result.success || result.request.layer != 0 || result.points.size() < 2)
	{
		return;
	}
	if (!colandreas_ || !colandreas_->loaded() || !colandreas_->mapReady())
	{
		return;
	}
	Vector3& target = result.points.back();
	float floor;
	if (floorAt(target, 2.0f, 6.0f, floor))
	{
		target.z = floor + PATHS_WALK_BODY;
	}
}
