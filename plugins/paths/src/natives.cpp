#include "paths-component.hpp"

#include <Server/Components/Pawn/Impl/pawn_natives.hpp>

#define PATHS_API(name, params) PAWN_NATIVE(paths_scripting, name, params)

static PathsComponent* paths()
{
	return PathsComponent::getInstance();
}

static uint8_t layerOf(int layer)
{
	return static_cast<uint8_t>(layer < 0 || layer >= PATHS_LAYERS ? PATHS_LAYERS : layer);
}

PATHS_API(Paths_Find, int(int layer, float fromX, float fromY, float fromZ, float toX, float toY, float toZ))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return -PathsReason_BadArgs;
	}
	return paths()->find(static_cast<PathsLayer>(layer), Vector3(fromX, fromY, fromZ), Vector3(toX, toY, toZ), nullptr);
}

PATHS_API(Paths_Cancel, bool(int requestid))
{
	return paths()->cancel(requestid);
}

PATHS_API(Paths_MoveNpc, int(int npcid, int layer, float x, float y, float z, int moveType, float speed, float stopRange))
{
	if (moveType < NPCMoveType_None || moveType > NPCMoveType_Auto || stopRange <= 0.0f)
	{
		return -PathsReason_BadArgs;
	}
	return paths()->moveNpc(npcid, layerOf(layer), Vector3(x, y, z), static_cast<NPCMoveType>(moveType), speed, stopRange);
}

PATHS_API(Paths_StopNpc, bool(int npcid))
{
	return paths()->stopNpc(npcid);
}

PATHS_API(Paths_IsNpcMoving, bool(int npcid))
{
	return paths()->isNpcMoving(npcid);
}

PATHS_API(Paths_GetNpcRequest, int(int npcid))
{
	return paths()->npcRequest(npcid);
}

PATHS_API(Paths_ClosestNode, bool(int layer, float x, float y, float z, int& area, int& node, float maxDist))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	return paths()->closestNode(static_cast<PathsLayer>(layer), Vector3(x, y, z), area, node, maxDist);
}

PATHS_API(Paths_NodePos, bool(int layer, int area, int node, float& x, float& y, float& z))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	Vector3 out;
	if (!paths()->nodePos(static_cast<PathsLayer>(layer), area, node, out))
	{
		return false;
	}
	x = out.x;
	y = out.y;
	z = out.z;
	return true;
}

PATHS_API(Paths_RandomNode, bool(int layer, float x, float y, float z, float minDist, float maxDist, int& area, int& node))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	return paths()->randomNode(static_cast<PathsLayer>(layer), Vector3(x, y, z), minDist, maxDist, area, node);
}

PATHS_API(Paths_NodeDistance, float(int layer, int area1, int node1, int area2, int node2))
{
	return paths()->nodeDistance(layerOf(layer), area1, node1, area2, node2);
}

PATHS_API(Paths_NodeLinkCount, int(int layer, int area, int node))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return 0;
	}
	return paths()->linkCount(static_cast<PathsLayer>(layer), area, node);
}

PATHS_API(Paths_NodeLink, bool(int layer, int area, int node, int index, int& toArea, int& toNode))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	return paths()->link(static_cast<PathsLayer>(layer), area, node, index, toArea, toNode);
}

PATHS_API(Paths_NodeSpeedClass, int(int area, int node))
{
	return paths()->speedClass(area, node);
}

PATHS_API(Paths_NodeCount, int(int layer))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return 0;
	}
	return paths()->nodeCount(static_cast<PathsLayer>(layer));
}

PATHS_API(Paths_AddNode, int(int layer, int area, float x, float y, float z))
{
	return paths()->addNode(layerOf(layer), area, Vector3(x, y, z));
}

PATHS_API(Paths_AddLink, bool(int layer, int area, int node, int toArea, int toNode))
{
	return paths()->addLink(layerOf(layer), area, node, toArea, toNode);
}

PATHS_API(Paths_LoadCustom, bool(const std::string& file))
{
	return paths()->loadCustom(file);
}

PATHS_API(Paths_SetBlocked, bool(int layer, int area, int node, bool blocked))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	return paths()->setBlocked(static_cast<PathsLayer>(layer), area, node, blocked);
}

PATHS_API(Paths_IsBlocked, bool(int layer, int area, int node))
{
	if (layerOf(layer) >= PATHS_LAYERS)
	{
		return false;
	}
	return paths()->isBlocked(static_cast<PathsLayer>(layer), area, node);
}

PATHS_API(Paths_SetWorkers, bool(int count))
{
	return paths()->setWorkers(count);
}

PATHS_API(Paths_SetQueueLimit, bool(int count))
{
	return paths()->setQueueLimit(count);
}

PATHS_API(Paths_SetLevelTolerance, bool(float tolerance))
{
	return paths()->setLevelTolerance(tolerance);
}

PATHS_API(Paths_SetPointRange, bool(int layer, float range))
{
	return paths()->setPointRange(layerOf(layer), range);
}

PATHS_API(Paths_Pending, int())
{
	return paths()->pending();
}

PATHS_API(Paths_AddNoSpawnArea, int(float minX, float minY, float maxX, float maxY))
{
	return paths()->addNoSpawnArea(minX, minY, maxX, maxY);
}

PATHS_API(Paths_RemoveNoSpawnArea, bool(int id))
{
	return paths()->removeNoSpawnArea(id);
}

PATHS_API(Paths_IsSpawnAllowed, bool(float x, float y, float z))
{
	return paths()->spawnAllowed(Vector3(x, y, z));
}

PATHS_API(Paths_NoSpawnAreaCount, int())
{
	return paths()->noSpawnAreaCount();
}
