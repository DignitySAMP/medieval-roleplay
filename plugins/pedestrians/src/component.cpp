#include <sdk.hpp>
#include <Server/Components/Actors/actors.hpp>
#include <Server/Components/Objects/objects.hpp>
#include <Server/Components/Vehicles/vehicles.hpp>
#include <Server/Components/Pawn/pawn.hpp>
#include <Server/Components/Pawn/Impl/pawn_natives.hpp>
#include <Server/Components/Pawn/Impl/pawn_impl.hpp>

#include <cmath>
#include <cstdarg>
#include <cstdio>

#include "bridge.hpp"
#include "colandreas.hpp"
#include "paths.hpp"
#include "pedestrians.hpp"

static ICore* g_core = nullptr;
static IPlayerPool* g_players = nullptr;
static IActorsComponent* g_actors = nullptr;
static IObjectsComponent* g_objects = nullptr;
static IVehiclesComponent* g_vehicles = nullptr;
static IPathsComponent* g_paths = nullptr;
static IColAndreasComponent* g_colandreas = nullptr;

static void componentLogprintf(const char* format, ...)
{
	if (!g_core)
	{
		return;
	}
	char buffer[1024];
	va_list args;
	va_start(args, format);
	std::vsnprintf(buffer, sizeof(buffer), format, args);
	va_end(args);
	g_core->printLn("%s", buffer);
}

logprintf_t logprintf = componentLogprintf;

#include "main.cpp"
#include "riders.hpp"

static IPlayer* playerOf(int playerid)
{
	return (g_players && playerid >= 0 && playerid < MAX_PLAYERS) ? g_players->get(playerid) : nullptr;
}

static IActor* actorOf(int actorid)
{
	return (g_actors && actorid >= 0 && actorid != 0xFFFF) ? g_actors->get(actorid) : nullptr;
}

bool sampgdk_IsPlayerConnected(int playerid)
{
	return playerOf(playerid) != nullptr;
}

bool sampgdk_IsPlayerNPC(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? player->isBot() : false;
}

int sampgdk_GetPlayerPoolSize()
{
	if (!g_players)
	{
		return -1;
	}
	int highest = -1;
	for (IPlayer* player : g_players->entries())
	{
		highest = std::max(highest, player->getID());
	}
	return highest;
}

bool sampgdk_GetPlayerPos(int playerid, float* x, float* y, float* z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 pos = player->getPosition();
	*x = pos.x;
	*y = pos.y;
	*z = pos.z;
	return true;
}

int sampgdk_GetPlayerVirtualWorld(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? player->getVirtualWorld() : 0;
}

int sampgdk_GetPlayerInterior(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? static_cast<int>(player->getInterior()) : 0;
}

int sampgdk_GetPlayerState(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? static_cast<int>(player->getState()) : 0;
}

bool sampgdk_GetPlayerFacingAngle(int playerid, float* angle)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*angle = 0.0f;
		return false;
	}
	*angle = player->getRotation().ToEuler().z;
	return true;
}

int sampgdk_GetPlayerAnimationIndex(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? player->getAnimationData().ID : 0;
}

int sampgdk_GetPlayerWeapon(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? static_cast<int>(player->getArmedWeapon()) : 0;
}

int sampgdk_GetPlayerAmmo(int playerid)
{
	IPlayer* player = playerOf(playerid);
	return player ? static_cast<int>(player->getArmedWeaponAmmo()) : 0;
}

bool sampgdk_GetPlayerKeys(int playerid, int* keys, int* updown, int* leftright)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*keys = *updown = *leftright = 0;
		return false;
	}
	const PlayerKeyData& data = player->getKeyData();
	*keys = static_cast<int>(data.keys);
	*updown = data.upDown;
	*leftright = data.leftRight;
	return true;
}

bool sampgdk_GetPlayerVelocity(int playerid, float* x, float* y, float* z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 v = player->getVelocity();
	*x = v.x;
	*y = v.y;
	*z = v.z;
	return true;
}

bool sampgdk_GetPlayerCameraPos(int playerid, float* x, float* y, float* z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 v = player->getAimData().camPos;
	*x = v.x;
	*y = v.y;
	*z = v.z;
	return true;
}

bool sampgdk_GetPlayerCameraFrontVector(int playerid, float* x, float* y, float* z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 v = player->getAimData().camFrontVector;
	*x = v.x;
	*y = v.y;
	*z = v.z;
	return true;
}

int sampgdk_GetPlayerTargetActor(int playerid)
{
	IPlayer* player = playerOf(playerid);
	IActor* actor = player ? player->getTargetActor() : nullptr;
	return actor ? actor->getID() : 0xFFFF;
}

int sampgdk_GetPlayerVehicleID(int playerid)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		return 0;
	}
	IPlayerVehicleData* data = queryExtension<IPlayerVehicleData>(player);
	IVehicle* vehicle = data ? data->getVehicle() : nullptr;
	return vehicle ? vehicle->getID() : 0;
}

bool sampgdk_IsPlayerInRangeOfPoint(int playerid, float range, float x, float y, float z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		return false;
	}
	const Vector3 pos = player->getPosition();
	const float dx = pos.x - x, dy = pos.y - y, dz = pos.z - z;
	return dx * dx + dy * dy + dz * dz <= range * range;
}

bool sampgdk_PlayerPlaySound(int playerid, int soundid, float x, float y, float z)
{
	IPlayer* player = playerOf(playerid);
	if (!player)
	{
		return false;
	}
	player->playSound(static_cast<uint32_t>(soundid), Vector3(x, y, z));
	return true;
}

bool sampgdk_GetVehiclePos(int vehicleid, float* x, float* y, float* z)
{
	IVehicle* vehicle = g_vehicles ? g_vehicles->get(vehicleid) : nullptr;
	if (!vehicle)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 pos = vehicle->getPosition();
	*x = pos.x;
	*y = pos.y;
	*z = pos.z;
	return true;
}

bool sampgdk_GetVehicleVelocity(int vehicleid, float* x, float* y, float* z)
{
	IVehicle* vehicle = g_vehicles ? g_vehicles->get(vehicleid) : nullptr;
	if (!vehicle)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 v = vehicle->getVelocity();
	*x = v.x;
	*y = v.y;
	*z = v.z;
	return true;
}

int sampgdk_CreateActor(int skin, float x, float y, float z, float angle)
{
	IActor* actor = g_actors ? g_actors->create(skin, Vector3(x, y, z), angle) : nullptr;
	return actor ? actor->getID() : 0xFFFF;
}

bool sampgdk_DestroyActor(int actorid)
{
	if (!actorOf(actorid))
	{
		return false;
	}
	g_actors->release(actorid);
	return true;
}

bool sampgdk_SetActorPos(int actorid, float x, float y, float z)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->setPosition(Vector3(x, y, z));
	return true;
}

bool sampgdk_GetActorPos(int actorid, float* x, float* y, float* z)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		*x = *y = *z = 0.0f;
		return false;
	}
	const Vector3 pos = actor->getPosition();
	*x = pos.x;
	*y = pos.y;
	*z = pos.z;
	return true;
}

bool sampgdk_SetActorFacingAngle(int actorid, float angle)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->setRotation(GTAQuat(0.0f, 0.0f, angle));
	return true;
}

bool sampgdk_ApplyActorAnimation(int actorid, const char* lib, const char* name, float delta, bool loop, bool lockx, bool locky, bool freeze, int time)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->applyAnimation(AnimationData(delta, loop, lockx, locky, freeze, static_cast<uint32_t>(time), lib, name));
	return true;
}

bool sampgdk_ClearActorAnimations(int actorid)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->clearAnimations();
	return true;
}

bool sampgdk_SetActorHealth(int actorid, float health)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->setHealth(health);
	return true;
}

bool sampgdk_SetActorInvulnerable(int actorid, bool invulnerable)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->setInvulnerable(invulnerable);
	return true;
}

bool sampgdk_SetActorVirtualWorld(int actorid, int world)
{
	IActor* actor = actorOf(actorid);
	if (!actor)
	{
		return false;
	}
	actor->setVirtualWorld(world);
	return true;
}

int sampgdk_GetActorVirtualWorld(int actorid)
{
	IActor* actor = actorOf(actorid);
	return actor ? actor->getVirtualWorld() : 0;
}

int sampgdk_CreateObject(int model, float x, float y, float z, float rx, float ry, float rz, float drawdistance)
{
	IObject* object = g_objects ? g_objects->create(model, Vector3(x, y, z), Vector3(rx, ry, rz), drawdistance) : nullptr;
	return object ? object->getID() : 0xFFFF;
}

bool sampgdk_DestroyObject(int objectid)
{
	if (!g_objects || objectid < 0 || objectid == 0xFFFF || !g_objects->get(objectid))
	{
		return false;
	}
	g_objects->release(objectid);
	return true;
}

bool Bridge_HasCollision()
{
	return g_colandreas && g_colandreas->loaded();
}

int Bridge_RayCast(float x1, float y1, float z1, float x2, float y2, float z2, float* hx, float* hy, float* hz)
{
	if (!g_colandreas)
	{
		return 0;
	}
	Vector3 hit(0.0f, 0.0f, 0.0f);
	const int model = g_colandreas->rayCast(Vector3(x1, y1, z1), Vector3(x2, y2, z2), hit);
	*hx = hit.x;
	*hy = hit.y;
	*hz = hit.z;
	return model;
}

int Bridge_RayCastNormal(float x1, float y1, float z1, float x2, float y2, float z2, float* hx, float* hy, float* hz, float* nx, float* ny, float* nz)
{
	if (!g_colandreas)
	{
		return 0;
	}
	Vector3 hit(0.0f, 0.0f, 0.0f);
	Vector3 normal(0.0f, 0.0f, 0.0f);
	const int model = g_colandreas->rayCastNormal(Vector3(x1, y1, z1), Vector3(x2, y2, z2), hit, normal);
	*hx = hit.x;
	*hy = hit.y;
	*hz = hit.z;
	*nx = normal.x;
	*ny = normal.y;
	*nz = normal.z;
	return model;
}

bool Bridge_LoadNodes(std::vector<PedNode>& nodes)
{
	const int total = g_paths ? g_paths->nodeCount(PathsLayer::Ped) : 0;
	if (total <= 0)
	{
		return false;
	}
	nodes.reserve(static_cast<size_t>(total));
	for (int area = 0; area < 64 && static_cast<int>(nodes.size()) < total; ++area)
	{
		for (int node = 0; node < 65536 && static_cast<int>(nodes.size()) < total; ++node)
		{
			Vector3 pos;
			if (!g_paths->nodePos(PathsLayer::Ped, area, node, pos))
			{
				continue;
			}
			PedNode entry;
			entry.id = (area << 16) | node;
			entry.area = area;
			entry.x = pos.x;
			entry.y = pos.y;
			entry.z = pos.z;
			const int links = g_paths->linkCount(PathsLayer::Ped, area, node);
			for (int index = 0; index < links; ++index)
			{
				int toArea = 0, toNode = 0;
				if (g_paths->link(PathsLayer::Ped, area, node, index, toArea, toNode))
				{
					entry.links.push_back(static_cast<uint32_t>((toArea << 16) | toNode));
				}
			}
			nodes.push_back(std::move(entry));
		}
	}
	return !nodes.empty();
}

static int NearestNodeId(float x, float y, float z)
{
	int best = -1;
	float bestSq = 1.0e12f;
	for (const auto& node : g_Nodes)
	{
		if (g_IgnoredNodes.count(static_cast<uint32_t>(node.id)) != 0)
		{
			continue;
		}
		const float dx = node.x - x, dy = node.y - y, dz = node.z - z;
		const float d = dx * dx + dy * dy + dz * dz * 0.25f;
		if (d < bestSq)
		{
			bestSq = d;
			best = node.id;
		}
	}
	return best;
}

class PedestriansComponent final : public IPedestriansComponent, public CoreEventHandler, public PlayerConnectEventHandler, public PlayerShotEventHandler, public ActorEventHandler, public PawnEventHandler
{
private:
	ICore* core_ = nullptr;
	IPawnComponent* pawn_ = nullptr;
	bool initialised_ = false;
	long long tickMaxUs_ = 0;
	long long tickSumUs_ = 0;
	long long tickCount_ = 0;
	TimePoint lastTickReport_ {};

	inline static PedestriansComponent* instance_ = nullptr;

	void initOnce()
	{
		if (initialised_)
		{
			return;
		}
		initialised_ = true;
		Ped_OnGameModeInit();
	}

	void shot(IPlayer& player, int hitType, int hitId, const PlayerBulletData& bullet)
	{
		Ped_OnPlayerWeaponShot(player.getID(), bullet.weapon, hitType, hitId, bullet.hitPos.x, bullet.hitPos.y, bullet.hitPos.z);
	}

public:
	PedestriansComponent()
	{
		instance_ = this;
	}

	~PedestriansComponent()
	{
		if (core_)
		{
			core_->getEventDispatcher().removeEventHandler(this);
			core_->getPlayers().getPlayerConnectDispatcher().removeEventHandler(this);
			core_->getPlayers().getPlayerShotDispatcher().removeEventHandler(this);
		}
		if (g_actors)
		{
			g_actors->getEventDispatcher().removeEventHandler(this);
		}
		if (g_npcs)
		{
			g_npcs->getEventDispatcher().removeEventHandler(&g_RidersNpcHandler);
		}
		if (pawn_)
		{
			pawn_->getEventDispatcher().removeEventHandler(this);
		}
		instance_ = nullptr;
	}

	static PedestriansComponent* getInstance()
	{
		if (!instance_)
		{
			instance_ = new PedestriansComponent();
		}
		return instance_;
	}

	StringView componentName() const override
	{
		return "pedestrians";
	}

	SemanticVersion componentVersion() const override
	{
		return SemanticVersion(2, 0, 0, 0);
	}

	void onLoad(ICore* c) override
	{
		core_ = c;
		g_core = c;
		g_players = &c->getPlayers();
		setAmxLookups(core_);
		Ped_Load();
		core_->getEventDispatcher().addEventHandler(this);
		g_players->getPlayerConnectDispatcher().addEventHandler(this);
		g_players->getPlayerShotDispatcher().addEventHandler(this);
	}

	void onInit(IComponentList* components) override
	{
		pawn_ = components->queryComponent<IPawnComponent>();
		g_actors = components->queryComponent<IActorsComponent>();
		g_objects = components->queryComponent<IObjectsComponent>();
		g_vehicles = components->queryComponent<IVehiclesComponent>();
		g_paths = components->queryComponent<IPathsComponent>();
		g_colandreas = components->queryComponent<IColAndreasComponent>();
		g_npcs = components->queryComponent<INPCComponent>();
		if (g_npcs)
		{
			g_npcs->getEventDispatcher().addEventHandler(&g_RidersNpcHandler);
		}
		if (pawn_)
		{
			setAmxFunctions(pawn_->getAmxFunctions());
			setAmxLookups(components);
			pawn_->getEventDispatcher().addEventHandler(this);
		}
		if (g_actors)
		{
			g_actors->getEventDispatcher().addEventHandler(this);
		}
		core_->printLn("[pedestrians] component loaded: actors %s, objects %s, paths %s, colandreas %s, npcs %s (riders)",
			g_actors ? "yes" : "MISSING", g_objects ? "yes" : "MISSING", g_paths ? "yes" : "MISSING", g_colandreas ? "yes" : "none", g_npcs ? "yes" : "MISSING");
	}

	void onReady() override
	{
		initOnce();
	}

	void onFree(IComponent* component) override
	{
		if (component == pawn_)
		{
			pawn_->getEventDispatcher().removeEventHandler(this);
			pawn_ = nullptr;
			setAmxFunctions();
			setAmxLookups();
		}
		if (component == g_actors)
		{
			g_actors->getEventDispatcher().removeEventHandler(this);
			g_actors = nullptr;
		}
		if (component == g_objects)
		{
			g_objects = nullptr;
		}
		if (component == g_vehicles)
		{
			g_vehicles = nullptr;
		}
		if (component == g_paths)
		{
			g_paths = nullptr;
		}
		if (component == g_colandreas)
		{
			g_colandreas = nullptr;
		}
		if (component == g_npcs)
		{
			g_npcs->getEventDispatcher().removeEventHandler(&g_RidersNpcHandler);
			g_npcs = nullptr;
			Riders_FreeAll();
		}
	}

	void free() override
	{
		delete this;
	}

	void reset() override
	{
		Riders_FreeAll();
		Ped_Unload();
		initialised_ = false;
	}

	void onTick(Microseconds, TimePoint now) override
	{
		initOnce();
		const auto started = std::chrono::steady_clock::now();
		Ped_ProcessTick();
		Riders_Tick();
		const auto took = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started).count();
		tickMaxUs_ = std::max(tickMaxUs_, static_cast<long long>(took));
		tickSumUs_ += took;
		tickCount_++;
		if (now - lastTickReport_ >= Seconds(5))
		{
			lastTickReport_ = now;
			int inUse = 0;
			for (int a = 0; a < g_MaxActorsInPool; a++)
			{
				if (g_Actors[a].inUse)
				{
					inUse++;
				}
			}
			core_->printLn("[pedestrians] tick cost over 5 s: %lld ticks, max %lld us, mean %lld us, actors in use %d, humans %d",
				tickCount_, tickMaxUs_, tickCount_ ? tickSumUs_ / tickCount_ : 0LL, inUse, static_cast<int>(g_HumanPlayers.size()));
			tickMaxUs_ = 0;
			tickSumUs_ = 0;
			tickCount_ = 0;
		}
	}

	void onPlayerConnect(IPlayer& player) override
	{
		Ped_OnPlayerConnect(player.getID());
	}

	void onPlayerDisconnect(IPlayer& player, PeerDisconnectReason reason) override
	{
		Ped_OnPlayerDisconnect(player.getID(), static_cast<int>(reason));
	}

	bool onPlayerShotMissed(IPlayer& player, const PlayerBulletData& bullet) override
	{
		shot(player, 0, 0, bullet);
		return true;
	}

	bool onPlayerShotPlayer(IPlayer& player, IPlayer& target, const PlayerBulletData& bullet) override
	{
		shot(player, 1, target.getID(), bullet);
		return true;
	}

	bool onPlayerShotVehicle(IPlayer& player, IVehicle& target, const PlayerBulletData& bullet) override
	{
		shot(player, 2, target.getID(), bullet);
		return true;
	}

	bool onPlayerShotObject(IPlayer& player, IObject& target, const PlayerBulletData& bullet) override
	{
		shot(player, 3, target.getID(), bullet);
		return true;
	}

	bool onPlayerShotPlayerObject(IPlayer& player, IPlayerObject& target, const PlayerBulletData& bullet) override
	{
		shot(player, 4, target.getID(), bullet);
		return true;
	}

	void onPlayerGiveDamageActor(IPlayer& player, IActor& actor, float amount, unsigned weapon, BodyPart part) override
	{
		Ped_OnPlayerGiveDamageActor(player.getID(), actor.getID(), amount, static_cast<int>(weapon), static_cast<int>(part));
	}

	void registerExtraNatives(AMX* amx);

	void onAmxLoad(IPawnScript& script) override
	{
		pawn_natives::AmxLoad(script.GetAMX());
		Ped_AmxLoad(script.GetAMX());
		registerExtraNatives(script.GetAMX());
	}

	void onAmxUnload(IPawnScript& script) override
	{
		Ped_AmxUnload(script.GetAMX());
	}

	int spawnAt(const Vector3& pos, float angle, int skin, int kind) override
	{
		initOnce();
		const int nid = NearestNodeId(pos.x, pos.y, pos.z);
		const int slot = FreeSlot();
		if (nid < 0 || slot < 0)
		{
			return -1;
		}
		if (!FillSlot(slot, skin, pos.x, pos.y, pos.z, GetWalkStyleForSkin(skin), -1, static_cast<uint32_t>(nid)))
		{
			return -1;
		}
		g_Actors[slot].kind = kind;
		if (kind != 0)
		{
			g_Actors[slot].aggroFlag = false;
		}
		g_Actors[slot].currentAngle = angle;
		g_Actors[slot].targetAngle = angle;
		SendActorAngle(slot, angle);
		for (AMX* amx : g_AMX)
		{
			int idx;
			if (!amx_FindPublic(amx, "OnPedestrianSpawn", &idx))
			{
				amx_Push(amx, static_cast<cell>(nid));
				amx_Push(amx, g_Actors[slot].actorid);
				cell ret;
				amx_Exec(amx, &ret, idx);
			}
		}
		return g_Actors[slot].actorid;
	}

	bool flee(int actorid, const Vector3& from, Milliseconds duration) override
	{
		const int a = FindActorSlot(actorid);
		if (a == -1 || g_Actors[a].isDead)
		{
			return false;
		}
		AggroClear(a);
		g_Actors[a].surrenderBy = -1;
		g_Actors[a].scareTick = 0;
		g_Actors[a].fleeX = from.x;
		g_Actors[a].fleeY = from.y;
		g_Actors[a].fleeZ = from.z;
		g_Actors[a].hasFleePoint = true;
		if (!NavStartFlee(a, from.x, from.y, from.z))
		{
			if (g_Actors[a].hasTarget)
			{
				SnapToGraph(a);
			}
			const int curIdx = FindNodeIndex(g_Actors[a].currentNodeId);
			const int far = PickFarthestLink(curIdx, from.x, from.y, from.z);
			if (far != -1)
			{
				g_Actors[a].targetNodeId = far;
			}
		}
		StartPanicRun(a);
		g_Actors[a].panicTick = GetTimeMs() + static_cast<uint64_t>(duration.count());
		g_Actors[a].lastUpdateTime = GetTimeMs();
		SetPedState(a, PED_STATE_PANIC);
		return true;
	}

	bool walkTo(int actorid, const Vector3& to, float speed) override
	{
		const int a = FindActorSlot(actorid);
		if (a == -1 || g_Actors[a].isDead)
		{
			return false;
		}
		AggroClear(a);
		g_Actors[a].surrenderBy = -1;
		g_Actors[a].scareTick = 0;
		g_Actors[a].tgtX = to.x;
		g_Actors[a].tgtY = to.y;
		g_Actors[a].tgtZ = to.z;
		g_Actors[a].speed = speed;
		g_Actors[a].hasTarget = true;
		g_Actors[a].hasFleePoint = false;
		g_Actors[a].panicTick = 0;
		g_Actors[a].lastUpdateTime = GetTimeMs();
		g_Actors[a].navN = 0;
		g_Actors[a].navNextPlan = 0;
		g_Actors[a].navGoal = false;
		SetPedState(a, PED_STATE_WALKING);
		return true;
	}

	bool isAlive(int actorid) override
	{
		const int a = FindActorSlot(actorid);
		return a != -1 && !g_Actors[a].isDead;
	}

	int count() override
	{
		int n = 0;
		for (int a = 0; a < g_MaxActorsInPool; a++)
		{
			if (g_Actors[a].inUse && !g_Actors[a].isDead)
			{
				n++;
			}
		}
		return n;
	}
};

static cell AMX_NATIVE_CALL n_SpawnPedestrianAt(AMX* amx, const cell* params)
{
	PedestriansComponent* component = PedestriansComponent::getInstance();
	const int kind = params[0] >= 6 * static_cast<int>(sizeof(cell)) ? static_cast<int>(params[6]) : 0;
	const int actorid = component->spawnAt(Vector3(amx_ctof(params[2]), amx_ctof(params[3]), amx_ctof(params[4])), amx_ctof(params[5]), static_cast<int>(params[1]), kind);
	return actorid < 0 ? 0xFFFF : actorid;
}

static AMX_NATIVE_INFO ExtraNatives[] = {
	{ "SpawnPedestrianAt", n_SpawnPedestrianAt },
	{ 0, 0 }
};

void PedestriansComponent::registerExtraNatives(AMX* amx)
{
	amx_Register(amx, ExtraNatives, -1);
	amx_Register(amx, RiderNatives, -1);
}

COMPONENT_ENTRY_POINT()
{
	return PedestriansComponent::getInstance();
}
