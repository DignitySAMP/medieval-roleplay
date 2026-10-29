#include "node-graph.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <limits>

static int gridCell(float v)
{
	int c = static_cast<int>((v - PATHS_GRID_ORIGIN) / PATHS_GRID_CELL);
	return std::clamp(c, 0, PATHS_GRID_DIM - 1);
}

static int gridIndex(const Vector3& p)
{
	return gridCell(p.y) * PATHS_GRID_DIM + gridCell(p.x);
}

bool loadNodeFiles(RawAreas& raw, std::string& log)
{
	raw.areasLoaded = 0;
	std::string missing;
	for (int area = 0; area < PATHS_AREAS; ++area)
	{
		raw.nodes[area].clear();
		raw.links[area].clear();
		raw.customLinks[area].clear();
		raw.fileNodeCount[area] = 0;
		raw.fileLinkCount[area] = 0;

		const std::string path = "scriptfiles/NPCs/nodes/NODES" + std::to_string(area) + ".DAT";
		std::ifstream file(path, std::ios::binary);
		if (!file.is_open())
		{
			missing += (missing.empty() ? "" : ",") + std::to_string(area);
			continue;
		}

		NodeFileHeader header {};
		if (!file.read(reinterpret_cast<char*>(&header), sizeof(header)))
		{
			missing += (missing.empty() ? "" : ",") + std::to_string(area);
			continue;
		}

		const uint32_t total = header.vehicleNodes + header.pedNodes;
		std::vector<NodeFileNode> fileNodes(total);
		if (total > 0)
		{
			file.read(reinterpret_cast<char*>(fileNodes.data()), total * sizeof(NodeFileNode));
		}
		std::vector<NodeFileNavi> navi(header.naviNodes);
		if (header.naviNodes > 0)
		{
			file.read(reinterpret_cast<char*>(navi.data()), header.naviNodes * sizeof(NodeFileNavi));
		}
		if (header.links > 0)
		{
			raw.links[area].resize(header.links);
			file.read(reinterpret_cast<char*>(raw.links[area].data()), header.links * sizeof(NodeFileLink));
		}
		std::vector<uint16_t> naviLinks(header.links);
		if (header.links > 0)
		{
			file.seekg(768, std::ios::cur);
			file.read(reinterpret_cast<char*>(naviLinks.data()), header.links * sizeof(uint16_t));
		}
		raw.linkAllowed[area].assign(header.links, 1);

		raw.nodes[area].reserve(total);
		for (uint32_t i = 0; i < total; ++i)
		{
			const NodeFileNode& n = fileNodes[i];
			RawNode node {};
			node.position = Vector3(
				static_cast<float>(n.x) * PATHS_NODE_SCALE,
				static_cast<float>(n.y) * PATHS_NODE_SCALE,
				static_cast<float>(n.z) * PATHS_NODE_SCALE);
			node.layer = i < header.vehicleNodes ? 1 : 0;
			if (node.layer == 0)
			{
				node.position.z += PATHS_NODE_Z_OFFSET;
			}
			node.water = (n.flags & (1u << 7)) != 0;
			node.interior = node.position.z > PATHS_INTERIOR_Z;
			node.switchedOff = (n.flags & (1u << 5)) != 0;
			node.custom = false;
			node.speedClass = (n.flags & (1u << 13)) != 0 ? 1 : 0;
			node.linkStart = n.linkId;
			node.linkCount = n.flags & 0xF;
			raw.nodes[area].push_back(node);
			if (node.layer == 1 && file.good())
			{
				for (uint32_t k = 0; k < node.linkCount; ++k)
				{
					const size_t at = static_cast<size_t>(node.linkStart) + k;
					if (at >= naviLinks.size())
					{
						break;
					}
					const uint16_t v = naviLinks[at];
					const uint32_t idx = v & 0x3FFu;
					const uint32_t narea = v >> 10;
					if (narea != static_cast<uint32_t>(area) || idx >= navi.size())
					{
						continue;
					}
					const NodeFileNavi& nv = navi[idx];
					const int left = (nv.flags >> 8) & 7;
					const int right = (nv.flags >> 11) & 7;
					if ((left == 0 && right == 0) || (left > 0 && right > 0))
					{
						continue;
					}
					const float mx = static_cast<float>(nv.x) * PATHS_NODE_SCALE - node.position.x;
					const float my = static_cast<float>(nv.y) * PATHS_NODE_SCALE - node.position.y;
					const float along = mx * static_cast<float>(nv.dirX) + my * static_cast<float>(nv.dirY);
					const bool allowed = along >= 0.0f ? left > 0 : right > 0;
					if (!allowed)
					{
						raw.linkAllowed[area][at] = 0;
						++raw.oneWayDropped;
					}
				}
			}
		}
		raw.fileNodeCount[area] = raw.nodes[area].size();
		raw.fileLinkCount[area] = raw.links[area].size();
		raw.areasLoaded++;
	}

	log = missing.empty() ? "" : "missing areas " + missing;
	return raw.areasLoaded > 0;
}

std::shared_ptr<LayerGraph> buildLayer(uint8_t layer, const RawAreas& raw, const std::unordered_map<uint64_t, bool>& manualBlocks)
{
	auto graph = std::make_shared<LayerGraph>();

	uint32_t total = 0;
	for (int area = 0; area < PATHS_AREAS; ++area)
	{
		const auto& nodes = raw.nodes[area];
		graph->areaToFlat[area].assign(nodes.size(), PATHS_NO_FLAT);
		for (size_t id = 0; id < nodes.size(); ++id)
		{
			if (nodes[id].layer != layer || nodes[id].water || nodes[id].interior)
			{
				continue;
			}
			graph->areaToFlat[area][id] = total++;
			graph->flatArea.push_back(static_cast<uint16_t>(area));
			graph->flatNode.push_back(static_cast<uint16_t>(id));
		}
	}

	graph->positions.resize(total);
	graph->linkInfo.resize(total);
	graph->blocked = std::make_unique<std::atomic<uint8_t>[]>(total);
	std::vector<std::vector<uint32_t>> undirected(total);

	for (uint32_t f = 0; f < total; ++f)
	{
		const int area = graph->flatArea[f];
		const int id = graph->flatNode[f];
		const RawNode& n = raw.nodes[area][id];
		graph->positions[f] = n.position;

		bool blocked = false;
		auto manual = manualBlocks.find(blockKey(layer, area, id));
		if (manual != manualBlocks.end())
		{
			blocked = manual->second;
		}
		graph->blocked[f].store(blocked ? 1 : 0, std::memory_order_relaxed);

		const uint32_t offset = static_cast<uint32_t>(graph->links.size());

		auto addLink = [&](const NodeFileLink& ln)
		{
			if (ln.areaId >= PATHS_AREAS)
			{
				return;
			}
			const uint32_t target = graph->flat(ln.areaId, ln.nodeId);
			if (target == PATHS_NO_FLAT || target == f)
			{
				return;
			}
			const float cost = glm::distance(graph->positions[f], raw.nodes[ln.areaId][ln.nodeId].position);
			graph->links.push_back({ target, cost });
			undirected[f].push_back(target);
			undirected[target].push_back(f);
		};

		const auto& fileLinks = raw.links[area];
		const auto& allowed = raw.linkAllowed[area];
		for (uint32_t i = 0; i < n.linkCount; ++i)
		{
			const size_t at = static_cast<size_t>(n.linkStart) + i;
			if (at >= fileLinks.size())
			{
				break;
			}
			if (layer == 1 && at < allowed.size() && !allowed[at])
			{
				continue;
			}
			addLink(fileLinks[at]);
		}

		const auto& custom = raw.customLinks[area];
		auto it = custom.find(static_cast<uint16_t>(id));
		if (it != custom.end())
		{
			for (const NodeFileLink& ln : it->second)
			{
				addLink(ln);
			}
		}

		graph->linkInfo[f].offset = offset;
		graph->linkInfo[f].count = static_cast<uint32_t>(graph->links.size()) - offset;
	}

	graph->wcc.assign(total, PATHS_NO_FLAT);
	uint32_t wccCount = 0;
	std::vector<uint32_t> queue;
	queue.reserve(total);
	for (uint32_t i = 0; i < total; ++i)
	{
		if (graph->wcc[i] != PATHS_NO_FLAT)
		{
			continue;
		}
		queue.clear();
		queue.push_back(i);
		graph->wcc[i] = wccCount;
		size_t head = 0;
		while (head < queue.size())
		{
			const uint32_t cur = queue[head++];
			for (uint32_t nb : undirected[cur])
			{
				if (graph->wcc[nb] == PATHS_NO_FLAT)
				{
					graph->wcc[nb] = wccCount;
					queue.push_back(nb);
				}
			}
		}
		wccCount++;
	}

	graph->scc.assign(total, PATHS_NO_FLAT);
	std::vector<uint32_t> dfn(total, PATHS_NO_FLAT);
	std::vector<uint32_t> low(total, PATHS_NO_FLAT);
	std::vector<bool> onStack(total, false);
	std::vector<uint32_t> stack;
	stack.reserve(total);
	struct Frame
	{
		uint32_t u;
		uint32_t edge;
	};
	std::vector<Frame> calls;
	calls.reserve(total);
	uint32_t timer = 0;
	uint32_t sccCount = 0;

	for (uint32_t i = 0; i < total; ++i)
	{
		if (dfn[i] != PATHS_NO_FLAT)
		{
			continue;
		}
		calls.push_back({ i, 0 });
		dfn[i] = low[i] = timer++;
		stack.push_back(i);
		onStack[i] = true;

		while (!calls.empty())
		{
			Frame& frame = calls.back();
			const uint32_t u = frame.u;
			const GraphLinkInfo& info = graph->linkInfo[u];
			bool pushed = false;

			while (frame.edge < info.count)
			{
				const uint32_t v = graph->links[info.offset + frame.edge].target;
				frame.edge++;
				if (dfn[v] == PATHS_NO_FLAT)
				{
					dfn[v] = low[v] = timer++;
					stack.push_back(v);
					onStack[v] = true;
					calls.push_back({ v, 0 });
					pushed = true;
					break;
				}
				else if (onStack[v])
				{
					low[u] = std::min(low[u], dfn[v]);
				}
			}
			if (pushed)
			{
				continue;
			}

			calls.pop_back();
			if (!calls.empty())
			{
				const uint32_t parent = calls.back().u;
				low[parent] = std::min(low[parent], low[u]);
			}
			if (low[u] == dfn[u])
			{
				while (true)
				{
					const uint32_t v = stack.back();
					stack.pop_back();
					onStack[v] = false;
					graph->scc[v] = sccCount;
					if (u == v)
					{
						break;
					}
				}
				sccCount++;
			}
		}
	}

	graph->cells.assign(PATHS_GRID_DIM * PATHS_GRID_DIM, {});
	for (uint32_t f = 0; f < total; ++f)
	{
		graph->cells[gridIndex(graph->positions[f])].push_back(f);
	}

	return graph;
}

uint32_t LayerGraph::closest(const Vector3& at, float maxDist, bool skipBlocked) const
{
	const int cx = gridCell(at.x);
	const int cy = gridCell(at.y);
	const int rings = static_cast<int>(std::ceil(maxDist / PATHS_GRID_CELL)) + 1;

	uint32_t best = PATHS_NO_FLAT;
	float bestSq = maxDist * maxDist;

	for (int r = 0; r <= rings; ++r)
	{
		for (int dy = -r; dy <= r; ++dy)
		{
			for (int dx = -r; dx <= r; ++dx)
			{
				if (std::abs(dx) != r && std::abs(dy) != r)
				{
					continue;
				}
				const int x = cx + dx;
				const int y = cy + dy;
				if (x < 0 || y < 0 || x >= PATHS_GRID_DIM || y >= PATHS_GRID_DIM)
				{
					continue;
				}
				for (uint32_t f : cells[y * PATHS_GRID_DIM + x])
				{
					if (skipBlocked && isBlocked(f))
					{
						continue;
					}
					const Vector3 d = positions[f] - at;
					const float sq = d.x * d.x + d.y * d.y + d.z * d.z;
					if (sq < bestSq)
					{
						bestSq = sq;
						best = f;
					}
				}
			}
		}
		if (best != PATHS_NO_FLAT && std::sqrt(bestSq) <= static_cast<float>(r) * PATHS_GRID_CELL)
		{
			break;
		}
	}
	return best;
}

uint32_t LayerGraph::random(const Vector3& around, float minDist, float maxDist, std::mt19937& rng, const std::vector<NoSpawnArea>& noSpawn) const
{
	const int cx = gridCell(around.x);
	const int cy = gridCell(around.y);
	const int rings = static_cast<int>(std::ceil(maxDist / PATHS_GRID_CELL)) + 1;
	const float minSq = minDist * minDist;
	const float maxSq = maxDist * maxDist;

	std::vector<uint32_t> candidates;
	for (int dy = -rings; dy <= rings; ++dy)
	{
		for (int dx = -rings; dx <= rings; ++dx)
		{
			const int x = cx + dx;
			const int y = cy + dy;
			if (x < 0 || y < 0 || x >= PATHS_GRID_DIM || y >= PATHS_GRID_DIM)
			{
				continue;
			}
			for (uint32_t f : cells[y * PATHS_GRID_DIM + x])
			{
				if (isBlocked(f) || !spawnAllowedAt(positions[f], noSpawn))
				{
					continue;
				}
				const Vector3 d = positions[f] - around;
				const float sq = d.x * d.x + d.y * d.y;
				if (sq >= minSq && sq <= maxSq)
				{
					candidates.push_back(f);
				}
			}
		}
	}
	if (candidates.empty())
	{
		return PATHS_NO_FLAT;
	}
	std::uniform_int_distribution<size_t> pick(0, candidates.size() - 1);
	return candidates[pick(rng)];
}
