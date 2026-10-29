#pragma once

#include <Server/Components/NPCs/npcs.hpp>
#include <Server/Components/Objects/objects.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <vector>

#define RIDERS_MAX 32
#define RIDERS_GAITS 4
#define RIDERS_ROUTE_MAX 2048

static INPCComponent* g_npcs = nullptr;

enum RiderGait
{
	RiderGait_Idle = 0,
	RiderGait_Walk = 1,
	RiderGait_Gallop = 2,
	RiderGait_Sprint = 3
};

struct RiderGaitRig
{
	int firstModel = 0;
	int step = -1;
	int frames = 1;
	int frameMs = 75;
	Vector3 offset {};
	Vector3 rotation {};
};

struct Rider
{
	bool used = false;
	INPC* npc = nullptr;
	int playerid = -1;
	int slot = 1;
	int bone = 1;
	int animIndex = 0;
	float rideHeight = 1.25f;
	RiderGaitRig rigs[RIDERS_GAITS];
	int gait = RiderGait_Idle;
	int moveGait = RiderGait_Sprint;
	int frame = 0;
	long long nextFrameMs = 0;
	int shownModel = 0;
	std::vector<Vector3> route;
	size_t routeAt = 0;
	bool moving = false;
	float speed = 6.0f;
	Vector3 pos {};
	float angle = 0.0f;
	long long lastMoveMs = 0;
};

static Rider g_Riders[RIDERS_MAX];

static long long Riders_NowMs()
{
	return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

static Rider* Riders_Find(int playerid)
{
	for (Rider& rider : g_Riders)
	{
		if (rider.used && rider.playerid == playerid)
		{
			return &rider;
		}
	}
	return nullptr;
}

static float Riders_Ground(float x, float y, float z)
{
	float hx, hy, hz;
	if (Bridge_RayCast(x, y, z + 3.0f, x, y, z - 12.0f, &hx, &hy, &hz) != 0)
	{
		return hz;
	}
	return z - 1.0f;
}

static void Riders_Attach(Rider& rider)
{
	if (!rider.npc)
	{
		return;
	}
	const RiderGaitRig& rig = rider.rigs[rider.gait];
	const int model = rig.firstModel + rig.step * rider.frame;
	if (model == rider.shownModel || rig.firstModel == 0)
	{
		return;
	}
	IPlayer* player = rider.npc->getPlayer();
	IPlayerObjectData* data = player ? queryExtension<IPlayerObjectData>(*player) : nullptr;
	if (!data)
	{
		return;
	}
	ObjectAttachmentSlotData slot {};
	slot.model = model;
	slot.bone = rider.bone;
	slot.offset = rig.offset;
	slot.rotation = rig.rotation;
	slot.scale = Vector3(1.0f, 1.0f, 1.0f);
	slot.colour1 = Colour::None();
	slot.colour2 = Colour::None();
	data->setAttachedObject(rider.slot, slot);
	rider.shownModel = model;
}

static void Riders_Sit(Rider& rider)
{
	if (rider.npc && rider.animIndex > 0)
	{
		rider.npc->setAnimation(rider.animIndex, 4.0f, true, true, true, true, 0);
	}
}

static void Riders_Fire(const char* name, int playerid)
{
	for (AMX* amx : g_AMX)
	{
		int idx;
		if (!amx_FindPublic(amx, name, &idx))
		{
			amx_Push(amx, playerid);
			cell ret;
			amx_Exec(amx, &ret, idx);
		}
	}
}

static void Riders_Face(Rider& rider, const Vector3& towards)
{
	const float dx = towards.x - rider.pos.x, dy = towards.y - rider.pos.y;
	if (dx * dx + dy * dy < 0.0001f)
	{
		return;
	}
	rider.angle = std::atan2(dy, dx) * 57.2957795f - 90.0f;
	if (rider.npc)
	{
		rider.npc->setRotation(GTAQuat(0.0f, 0.0f, rider.angle), false);
	}
}

static void Riders_Stop(Rider& rider)
{
	rider.moving = false;
	rider.route.clear();
	rider.routeAt = 0;
	rider.gait = RiderGait_Idle;
	rider.frame = 0;
	if (rider.npc)
	{
		rider.npc->setVelocity(Vector3(0.0f, 0.0f, 0.0f), false);
	}
	Riders_Attach(rider);
}

static void Riders_Advance(Rider& rider, long long now)
{
	const float dt = std::min(0.25f, static_cast<float>(now - rider.lastMoveMs) / 1000.0f);
	rider.lastMoveMs = now;
	float budget = rider.speed * dt;
	while (budget > 0.0f && rider.routeAt < rider.route.size())
	{
		const Vector3& to = rider.route[rider.routeAt];
		const float dx = to.x - rider.pos.x, dy = to.y - rider.pos.y;
		const float left = std::sqrt(dx * dx + dy * dy);
		if (left <= budget || left < 0.05f)
		{
			rider.pos.x = to.x;
			rider.pos.y = to.y;
			budget -= left;
			rider.routeAt++;
			continue;
		}
		rider.pos.x += dx / left * budget;
		rider.pos.y += dy / left * budget;
		Riders_Face(rider, to);
		budget = 0.0f;
	}
	rider.pos.z = Riders_Ground(rider.pos.x, rider.pos.y, rider.pos.z + 1.0f) + rider.rideHeight;
	if (rider.npc)
	{
		const float a = (rider.angle + 90.0f) / 57.2957795f;
		const float perTick = rider.speed / 50.0f;
		rider.npc->setPosition(rider.pos, false);
		rider.npc->setVelocity(Vector3(std::cos(a) * perTick, std::sin(a) * perTick, 0.0f), false);
	}
	if (rider.routeAt >= rider.route.size())
	{
		Riders_Stop(rider);
		Riders_Fire("OnRiderArrive", rider.playerid);
	}
}

static void Riders_Tick()
{
	if (!g_npcs)
	{
		return;
	}
	const long long now = Riders_NowMs();
	for (Rider& rider : g_Riders)
	{
		if (!rider.used || !rider.npc)
		{
			continue;
		}
		if (rider.moving)
		{
			Riders_Advance(rider, now);
		}
		if (!rider.used)
		{
			continue;
		}
		const int want = rider.moving ? rider.moveGait : RiderGait_Idle;
		if (want != rider.gait)
		{
			rider.gait = want;
			rider.frame = 0;
			rider.nextFrameMs = 0;
		}
		if (now >= rider.nextFrameMs)
		{
			const RiderGaitRig& rig = rider.rigs[rider.gait];
			rider.frame = rig.frames > 0 ? (rider.frame + 1) % rig.frames : 0;
			rider.nextFrameMs = now + std::max(rig.frameMs, 20);
			Riders_Attach(rider);
		}
	}
}

static void Riders_Free(Rider& rider)
{
	if (rider.npc && g_npcs)
	{
		g_npcs->destroy(*rider.npc);
	}
	rider = Rider();
}

static void Riders_OnNpcDestroyed(INPC& npc)
{
	for (Rider& rider : g_Riders)
	{
		if (rider.used && rider.npc == &npc)
		{
			rider = Rider();
		}
	}
}

static void Riders_FreeAll()
{
	for (Rider& rider : g_Riders)
	{
		if (rider.used)
		{
			Riders_Free(rider);
		}
	}
}

static cell AMX_NATIVE_CALL n_Rider_Create(AMX* amx, const cell* params)
{
	if (!g_npcs || params[0] < 11 * static_cast<int>(sizeof(cell)))
	{
		return 0xFFFF;
	}
	Rider* free = nullptr;
	for (Rider& rider : g_Riders)
	{
		if (!rider.used)
		{
			free = &rider;
			break;
		}
	}
	if (!free)
	{
		return 0xFFFF;
	}
	char name[MAX_PLAYER_NAME + 1] = "rider";
	cell* address = nullptr;
	if (amx_GetAddr(amx, params[1], &address) == AMX_ERR_NONE && address)
	{
		amx_GetString(name, address, 0, sizeof(name));
	}
	INPC* npc = g_npcs->create(StringView(name));
	if (!npc)
	{
		return 0xFFFF;
	}
	*free = Rider();
	free->used = true;
	free->npc = npc;
	free->playerid = npc->getID();
	free->slot = static_cast<int>(params[8]);
	free->bone = static_cast<int>(params[9]);
	free->animIndex = static_cast<int>(params[10]);
	free->rideHeight = amx_ctof(params[11]);
	free->pos = Vector3(amx_ctof(params[3]), amx_ctof(params[4]), amx_ctof(params[5]));
	free->angle = amx_ctof(params[6]);
	free->lastMoveMs = Riders_NowMs();
	npc->spawn();
	npc->setSkin(static_cast<int>(params[2]));
	npc->setVirtualWorld(static_cast<int>(params[7]));
	npc->setPosition(free->pos, true);
	npc->setRotation(GTAQuat(0.0f, 0.0f, free->angle), true);
	Riders_Sit(*free);
	return free->playerid;
}

static cell AMX_NATIVE_CALL n_Rider_SetGait(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	const int gait = static_cast<int>(params[2]);
	if (!rider || gait < 0 || gait >= RIDERS_GAITS)
	{
		return 0;
	}
	RiderGaitRig& rig = rider->rigs[gait];
	rig.firstModel = static_cast<int>(params[3]);
	rig.step = static_cast<int>(params[4]);
	rig.frames = std::max(1, static_cast<int>(params[5]));
	rig.frameMs = std::max(20, static_cast<int>(params[6]));
	rig.offset = Vector3(amx_ctof(params[7]), amx_ctof(params[8]), amx_ctof(params[9]));
	rig.rotation = Vector3(amx_ctof(params[10]), amx_ctof(params[11]), amx_ctof(params[12]));
	if (gait == rider->gait)
	{
		rider->shownModel = 0;
		Riders_Attach(*rider);
	}
	return 1;
}

static void Riders_Begin(Rider& rider, int gait, float speed)
{
	rider.routeAt = 0;
	rider.moving = !rider.route.empty();
	rider.moveGait = std::max(1, std::min(gait, RIDERS_GAITS - 1));
	rider.speed = std::max(0.5f, speed);
	rider.lastMoveMs = Riders_NowMs();
	if (rider.npc)
	{
		rider.pos = rider.npc->getPosition();
	}
	Riders_Sit(rider);
}

static cell AMX_NATIVE_CALL n_Rider_MoveTo(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	if (!rider || !rider->npc)
	{
		return 0;
	}
	const Vector3 to(amx_ctof(params[2]), amx_ctof(params[3]), amx_ctof(params[4]));
	rider->route.clear();
	if (g_paths)
	{
		std::vector<Vector3> points(RIDERS_ROUTE_MAX);
		const int count = g_paths->route(PathsLayer::Ped, rider->npc->getPosition(), to, Span<Vector3>(points.data(), points.size()));
		for (int i = 0; i < count; i++)
		{
			rider->route.push_back(points[i]);
		}
	}
	rider->route.push_back(to);
	Riders_Begin(*rider, static_cast<int>(params[5]), amx_ctof(params[6]));
	return static_cast<cell>(rider->route.size());
}

static cell AMX_NATIVE_CALL n_Rider_SetRoute(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	cell* points = nullptr;
	if (!rider || amx_GetAddr(amx, params[2], &points) != AMX_ERR_NONE || !points)
	{
		return 0;
	}
	const int count = std::min(static_cast<int>(params[3]), RIDERS_ROUTE_MAX);
	rider->route.clear();
	for (int i = 0; i < count; i++)
	{
		rider->route.emplace_back(amx_ctof(points[i * 3]), amx_ctof(points[i * 3 + 1]), amx_ctof(points[i * 3 + 2]));
	}
	Riders_Begin(*rider, static_cast<int>(params[4]), amx_ctof(params[5]));
	return count;
}

static cell AMX_NATIVE_CALL n_Rider_Stop(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	if (!rider)
	{
		return 0;
	}
	Riders_Stop(*rider);
	return 1;
}

static cell AMX_NATIVE_CALL n_Rider_SetSpeed(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	if (!rider)
	{
		return 0;
	}
	rider->moveGait = std::max(1, std::min(static_cast<int>(params[2]), RIDERS_GAITS - 1));
	rider->speed = std::max(0.5f, amx_ctof(params[3]));
	return 1;
}

static cell AMX_NATIVE_CALL n_Rider_IsMoving(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	return rider && rider->moving ? 1 : 0;
}

static cell AMX_NATIVE_CALL n_Rider_IsValid(AMX* amx, const cell* params)
{
	return Riders_Find(static_cast<int>(params[1])) ? 1 : 0;
}

static cell AMX_NATIVE_CALL n_Rider_GetRoutePoint(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	return rider && rider->moving ? static_cast<cell>(rider->routeAt) : -1;
}

static cell AMX_NATIVE_CALL n_Rider_GetPos(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	cell *x, *y, *z, *a;
	if (!rider || amx_GetAddr(amx, params[2], &x) != AMX_ERR_NONE || amx_GetAddr(amx, params[3], &y) != AMX_ERR_NONE || amx_GetAddr(amx, params[4], &z) != AMX_ERR_NONE || amx_GetAddr(amx, params[5], &a) != AMX_ERR_NONE)
	{
		return 0;
	}
	*x = amx_ftoc(rider->pos.x);
	*y = amx_ftoc(rider->pos.y);
	*z = amx_ftoc(rider->pos.z);
	*a = amx_ftoc(rider->angle);
	return 1;
}

static cell AMX_NATIVE_CALL n_Rider_Destroy(AMX* amx, const cell* params)
{
	Rider* rider = Riders_Find(static_cast<int>(params[1]));
	if (!rider)
	{
		return 0;
	}
	Riders_Free(*rider);
	return 1;
}

static cell AMX_NATIVE_CALL n_Rider_Count(AMX* amx, const cell* params)
{
	int count = 0;
	for (const Rider& rider : g_Riders)
	{
		if (rider.used)
		{
			count++;
		}
	}
	return count;
}

struct RidersNpcHandler final : public NPCEventHandler
{
	void onNPCDestroy(INPC& npc) override
	{
		Riders_OnNpcDestroyed(npc);
	}
};

static RidersNpcHandler g_RidersNpcHandler;

static AMX_NATIVE_INFO RiderNatives[] = {
	{ "Rider_Create", n_Rider_Create },
	{ "Rider_SetGait", n_Rider_SetGait },
	{ "Rider_MoveTo", n_Rider_MoveTo },
	{ "Rider_SetRoute", n_Rider_SetRoute },
	{ "Rider_Stop", n_Rider_Stop },
	{ "Rider_SetSpeed", n_Rider_SetSpeed },
	{ "Rider_IsMoving", n_Rider_IsMoving },
	{ "Rider_IsValid", n_Rider_IsValid },
	{ "Rider_GetRoutePoint", n_Rider_GetRoutePoint },
	{ "Rider_GetPos", n_Rider_GetPos },
	{ "Rider_Destroy", n_Rider_Destroy },
	{ "Rider_Count", n_Rider_Count },
	{ 0, 0 }
};
