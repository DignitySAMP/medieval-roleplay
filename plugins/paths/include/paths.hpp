#pragma once

#include <sdk.hpp>

enum class PathsLayer : uint8_t
{
	Ped = 0,
	Car = 1
};

enum PathsReason
{
	PathsReason_Ok = 0,
	PathsReason_NoStartNode = 1,
	PathsReason_NoTargetNode = 2,
	PathsReason_Unreachable = 3,
	PathsReason_LevelMismatch = 4,
	PathsReason_LastMileBlocked = 5,
	PathsReason_QueueFull = 6,
	PathsReason_Cancelled = 7,
	PathsReason_BadArgs = 8,
	PathsReason_NpcGone = 9,
	PathsReason_MoveRejected = 10
};

struct PathsResultHandler
{
	virtual void onPathsResult(int requestId, bool success, int reason, Span<const Vector3> points) = 0;
};

static const UID PathsComponent_UID = UID(0x7A3C5E11D2B94F60);

struct IPathsComponent : public IComponent
{
	PROVIDE_UID(PathsComponent_UID)

	virtual int find(PathsLayer layer, const Vector3& from, const Vector3& to, PathsResultHandler* handler) = 0;
	virtual int route(PathsLayer layer, const Vector3& from, const Vector3& to, Span<Vector3> out) = 0;
	virtual bool cancel(int requestId) = 0;

	virtual bool closestNode(PathsLayer layer, const Vector3& at, int& area, int& node, float maxDist) = 0;
	virtual bool nodePos(PathsLayer layer, int area, int node, Vector3& out) = 0;
	virtual bool randomNode(PathsLayer layer, const Vector3& around, float minDist, float maxDist, int& area, int& node) = 0;
	virtual int linkCount(PathsLayer layer, int area, int node) = 0;
	virtual bool link(PathsLayer layer, int area, int node, int index, int& toArea, int& toNode) = 0;
	virtual int speedClass(int area, int node) = 0;
	virtual int nodeCount(PathsLayer layer) = 0;

	virtual bool isBlocked(PathsLayer layer, int area, int node) = 0;
	virtual bool setBlocked(PathsLayer layer, int area, int node, bool blocked) = 0;

	virtual bool spawnAllowed(const Vector3& at) = 0;
	virtual int addNoSpawnArea(float minX, float minY, float maxX, float maxY) = 0;
	virtual bool removeNoSpawnArea(int id) = 0;
	virtual int noSpawnAreaCount() = 0;
};
