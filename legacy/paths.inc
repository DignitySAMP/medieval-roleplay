#if defined _paths_included
	#endinput
#endif
#define _paths_included

#define PATHS_LAYER_PED (0)
#define PATHS_LAYER_CAR (1)

#define PATHS_OK (0)
#define PATHS_NO_START_NODE (1)
#define PATHS_NO_TARGET_NODE (2)
#define PATHS_UNREACHABLE (3)
#define PATHS_LEVEL_MISMATCH (4)
#define PATHS_LAST_MILE_BLOCKED (5)
#define PATHS_QUEUE_FULL (6)
#define PATHS_CANCELLED (7)
#define PATHS_BAD_ARGS (8)
#define PATHS_NPC_GONE (9)
#define PATHS_MOVE_REJECTED (10)

native Paths_Find(layer, Float:fromX, Float:fromY, Float:fromZ, Float:toX, Float:toY, Float:toZ);
native bool:Paths_Cancel(requestid);
native Paths_MoveNpc(npcid, layer, Float:x, Float:y, Float:z, NPC_MOVE_TYPE:moveType = NPC_MOVE_TYPE_AUTO, Float:speed = NPC_MOVE_SPEED_AUTO, Float:stopRange = 1.0);
native bool:Paths_StopNpc(npcid);
native bool:Paths_IsNpcMoving(npcid);
native Paths_GetNpcRequest(npcid);

native bool:Paths_ClosestNode(layer, Float:x, Float:y, Float:z, &area, &node, Float:maxDist = 60.0);
native bool:Paths_NodePos(layer, area, node, &Float:x, &Float:y, &Float:z);
native bool:Paths_RandomNode(layer, Float:x, Float:y, Float:z, Float:minDist, Float:maxDist, &area, &node);
native Float:Paths_NodeDistance(layer, area1, node1, area2, node2);
native Paths_NodeLinkCount(layer, area, node);
native bool:Paths_NodeLink(layer, area, node, index, &toArea, &toNode);
native Paths_NodeSpeedClass(area, node);
native Paths_NodeCount(layer);

native Paths_AddNode(layer, area, Float:x, Float:y, Float:z);
native bool:Paths_AddLink(layer, area, node, toArea, toNode);
native bool:Paths_LoadCustom(const file[]);
native bool:Paths_SetBlocked(layer, area, node, bool:blocked);
native bool:Paths_IsBlocked(layer, area, node);

native Paths_AddNoSpawnArea(Float:minX, Float:minY, Float:maxX, Float:maxY);
native bool:Paths_RemoveNoSpawnArea(id);
native bool:Paths_IsSpawnAllowed(Float:x, Float:y, Float:z);
native Paths_NoSpawnAreaCount();

native bool:Paths_SetWorkers(count);
native bool:Paths_SetQueueLimit(count);
native bool:Paths_SetLevelTolerance(Float:tolerance);
native bool:Paths_SetPointRange(layer, Float:range);
native Paths_Pending();

forward OnPathsFound(requestid, pathid, bool:success, reason);
forward OnPathsNpcArrive(npcid, requestid);
forward OnPathsNpcFail(npcid, requestid, reason);
