#pragma once

#include <sdk.hpp>
#include <array>
#include <atomic>
#include <cstdint>
#include <memory>
#include <random>
#include <string>
#include <unordered_map>
#include <vector>

constexpr int PATHS_AREAS = 64;
constexpr uint32_t PATHS_NO_FLAT = 0xFFFFFFFFu;
constexpr float PATHS_NODE_SCALE = 0.125f;
constexpr float PATHS_NODE_Z_OFFSET = 1.2f;

constexpr float PATHS_INTERIOR_Z = 900.0f;

constexpr float PATHS_GRID_CELL = 64.0f;
constexpr float PATHS_GRID_ORIGIN = -3200.0f;
constexpr int PATHS_GRID_DIM = 100;

#pragma pack(push, 1)
struct NodeFileHeader
{
	uint32_t nodes;
	uint32_t vehicleNodes;
	uint32_t pedNodes;
	uint32_t naviNodes;
	uint32_t links;
};

struct NodeFileNode
{
	uint32_t memAddress;
	uint32_t zero;
	int16_t x;
	int16_t y;
	int16_t z;
	uint16_t distance;
	uint16_t linkId;
	uint16_t areaId;
	uint16_t nodeId;
	uint8_t width;
	uint8_t floodFill;
	uint32_t flags;
};

struct NodeFileLink
{
	uint16_t areaId;
	uint16_t nodeId;
};

struct NodeFileNavi
{
	int16_t x;
	int16_t y;
	uint16_t areaId;
	uint16_t nodeId;
	int8_t dirX;
	int8_t dirY;
	uint32_t flags;
};
#pragma pack(pop)

struct RawNode
{
	Vector3 position;
	uint8_t layer;
	bool water;
	bool interior;
	bool switchedOff;
	bool custom;
	uint8_t speedClass;
	uint32_t linkStart;
	uint32_t linkCount;
};

struct RawAreas
{
	std::array<std::vector<RawNode>, PATHS_AREAS> nodes;
	std::array<std::vector<NodeFileLink>, PATHS_AREAS> links;
	std::array<std::vector<uint8_t>, PATHS_AREAS> linkAllowed;
	uint32_t oneWayDropped = 0;
	std::array<std::unordered_map<uint16_t, std::vector<NodeFileLink>>, PATHS_AREAS> customLinks;
	std::array<size_t, PATHS_AREAS> fileNodeCount {};
	std::array<size_t, PATHS_AREAS> fileLinkCount {};
	int areasLoaded = 0;
};

struct NoSpawnArea
{
	int id;
	float minX;
	float minY;
	float maxX;
	float maxY;

	bool contains(const Vector3& p) const
	{
		return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
	}
};

inline bool spawnAllowedAt(const Vector3& p, const std::vector<NoSpawnArea>& areas)
{
	if (p.z > PATHS_INTERIOR_Z)
	{
		return false;
	}
	for (const NoSpawnArea& area : areas)
	{
		if (area.contains(p))
		{
			return false;
		}
	}
	return true;
}

struct GraphLinkInfo
{
	uint32_t offset;
	uint32_t count;
};

struct GraphLink
{
	uint32_t target;
	float cost;
};

struct LayerGraph
{
	std::vector<Vector3> positions;
	std::vector<GraphLinkInfo> linkInfo;
	std::vector<GraphLink> links;
	std::vector<uint16_t> flatArea;
	std::vector<uint16_t> flatNode;
	std::array<std::vector<uint32_t>, PATHS_AREAS> areaToFlat;
	std::vector<uint32_t> wcc;
	std::vector<uint32_t> scc;
	std::unique_ptr<std::atomic<uint8_t>[]> blocked;
	std::vector<std::vector<uint32_t>> cells;

	uint32_t flat(int area, int node) const
	{
		if (area < 0 || area >= PATHS_AREAS || node < 0)
		{
			return PATHS_NO_FLAT;
		}
		const auto& map = areaToFlat[area];
		if (static_cast<size_t>(node) >= map.size())
		{
			return PATHS_NO_FLAT;
		}
		return map[node];
	}

	bool isBlocked(uint32_t f) const
	{
		return blocked[f].load(std::memory_order_relaxed) != 0;
	}

	uint32_t closest(const Vector3& at, float maxDist, bool skipBlocked) const;
	uint32_t random(const Vector3& around, float minDist, float maxDist, std::mt19937& rng, const std::vector<NoSpawnArea>& noSpawn) const;
};

inline uint64_t blockKey(uint8_t layer, int area, int node)
{
	return (static_cast<uint64_t>(layer) << 32) | (static_cast<uint64_t>(area & 0xFFFF) << 16) | static_cast<uint64_t>(node & 0xFFFF);
}

bool loadNodeFiles(RawAreas& raw, std::string& log);
std::shared_ptr<LayerGraph> buildLayer(uint8_t layer, const RawAreas& raw, const std::unordered_map<uint64_t, bool>& manualBlocks);
