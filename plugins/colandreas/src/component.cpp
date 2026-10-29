#include <sdk.hpp>
#include <Server/Components/Pawn/pawn.hpp>
#include <Server/Components/Pawn/Impl/pawn_natives.hpp>
#include <Server/Components/Pawn/Impl/pawn_impl.hpp>

#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdio>

#include <btBulletDynamicsCommon.h>
#include "ColAndreas.h"
#include "ColAndreasDatabaseReader.h"
#include "DynamicWorld.h"
#include "Natives.h"
#include "colandreas.hpp"

bool colInit = false;
bool colDataLoaded = false;
cell nullAddress = 0;
ColAndreasWorld* collisionWorld = nullptr;

static ICore* g_core = nullptr;

static void componentLogprintf(char* format, ...)
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

static cell AMX_NATIVE_CALL CA_InterfaceSelfTest(AMX* amx, const cell* params);

template <cell AMX_NATIVE_CALL (*Native)(AMX*, cell*)>
static cell AMX_NATIVE_CALL nativeTrampoline(AMX* amx, const cell* params)
{
	return Native(amx, const_cast<cell*>(params));
}

static AMX_NATIVE_INFO PluginNatives[] =
{
	{ "CA_Init", nativeTrampoline<&ColAndreasNatives::CA_Init> },
	{ "CA_RayCastLine", nativeTrampoline<&ColAndreasNatives::CA_RayCastLine> },
	{ "CA_RayCastLineExtraID", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineExtraID> },
	{ "CA_RayCastLineID", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineID> },
	{ "CA_RayCastLineAngle", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineAngle> },
	{ "CA_RayCastMultiLine", nativeTrampoline<&ColAndreasNatives::CA_RayCastMultiLine> },
	{ "CA_RayCastReflectionVector", nativeTrampoline<&ColAndreasNatives::CA_RayCastReflectionVector> },
	{ "CA_RayCastLineNormal", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineNormal> },
	{ "CA_ContactTest", nativeTrampoline<&ColAndreasNatives::CA_ContactTest> },
	{ "CA_LoadFromDff", nativeTrampoline<&ColAndreasNatives::CA_LoadFromDff> },
	{ "CA_CreateObject", nativeTrampoline<&ColAndreasNatives::CA_CreateObject> },
	{ "CA_DestroyObject", nativeTrampoline<&ColAndreasNatives::CA_DestroyObject> },
	{ "CA_IsValidObject", nativeTrampoline<&ColAndreasNatives::CA_IsValidObject> },
	{ "CA_EulerToQuat", nativeTrampoline<&ColAndreasNatives::CA_EulerToQuat> },
	{ "CA_QuatToEuler", nativeTrampoline<&ColAndreasNatives::CA_QuatToEuler> },
	{ "CA_RemoveBuilding", nativeTrampoline<&ColAndreasNatives::CA_RemoveBuilding> },
	{ "CA_RestoreBuilding", nativeTrampoline<&ColAndreasNatives::CA_RestoreBuilding> },
	{ "CA_SetObjectPos", nativeTrampoline<&ColAndreasNatives::CA_SetObjectPos> },
	{ "CA_SetObjectRot", nativeTrampoline<&ColAndreasNatives::CA_SetObjectRot> },
	{ "CA_GetModelBoundingSphere", nativeTrampoline<&ColAndreasNatives::CA_GetModelBoundingSphere> },
	{ "CA_GetModelBoundingBox", nativeTrampoline<&ColAndreasNatives::CA_GetModelBoundingBox> },
	{ "CA_SetObjectExtraID", nativeTrampoline<&ColAndreasNatives::CA_SetObjectExtraID> },
	{ "CA_GetObjectExtraID", nativeTrampoline<&ColAndreasNatives::CA_GetObjectExtraID> },
	{ "CA_RayCastLineEx", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineEx> },
	{ "CA_RayCastLineAngleEx", nativeTrampoline<&ColAndreasNatives::CA_RayCastLineAngleEx> },
	{ "CA_InterfaceSelfTest", CA_InterfaceSelfTest },
	{ 0, 0 }
};

static constexpr int MULTICAST_MAX = 99;

class ColAndreasComponent final : public IColAndreasComponent, public PawnEventHandler
{
private:
	ICore* core_ = nullptr;
	IPawnComponent* pawn_ = nullptr;

	inline static ColAndreasComponent* instance_ = nullptr;

	static btVector3 bt(const Vector3& v)
	{
		return btVector3(v.x, v.y, v.z);
	}

	static btVector3 rayStart(const Vector3& v)
	{
		return btVector3(v.x + 0.00001f, v.y + 0.00001f, v.z + 0.00001f);
	}

	static bool validModelRange(int model)
	{
		return (model >= 0 && model < 20000) || (model <= -1000 && model > -30000);
	}

	static bool validIndex(int index)
	{
		return index >= 0 && index < MAX_MAP_OBJECTS;
	}

public:
	ColAndreasComponent()
	{
		instance_ = this;
	}

	~ColAndreasComponent()
	{
		if (pawn_)
		{
			pawn_->getEventDispatcher().removeEventHandler(this);
		}
		instance_ = nullptr;
	}

	static ColAndreasComponent* getInstance()
	{
		if (!instance_)
		{
			instance_ = new ColAndreasComponent();
		}
		return instance_;
	}

	StringView componentName() const override
	{
		return "colandreas";
	}

	SemanticVersion componentVersion() const override
	{
		return SemanticVersion(1, 5, 0, 1);
	}

	void onLoad(ICore* c) override
	{
		core_ = c;
		g_core = c;
		setAmxLookups(core_);
	}

	void onInit(IComponentList* components) override
	{
		pawn_ = components->queryComponent<IPawnComponent>();
		if (pawn_)
		{
			setAmxFunctions(pawn_->getAmxFunctions());
			setAmxLookups(components);
			pawn_->getEventDispatcher().addEventHandler(this);
		}

		const auto started = std::chrono::steady_clock::now();
		collisionWorld = new ColAndreasWorld();
		colDataLoaded = collisionWorld->loadCollisionData();
		const auto took = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - started).count();

		core_->printLn("[colandreas] loaded - component %s, collision data %s, %u models, %u placements, %lld ms",
			CA_VERSION, colDataLoaded ? "yes" : "MISSING (natives answer no hit)",
			static_cast<unsigned>(ModelCount), static_cast<unsigned>(IPLCount), static_cast<long long>(took));
	}

	void onReady() override
	{
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
	}

	void free() override
	{
		delete this;
	}

	void reset() override
	{
		if (collisionWorld && collisionWorld->objectManager)
		{
			for (int index = 0; index < MAX_MAP_OBJECTS; ++index)
			{
				collisionWorld->objectManager->removeObjectManager(static_cast<uint16_t>(index));
			}
		}
	}

	void onAmxLoad(IPawnScript& script) override
	{
		pawn_natives::AmxLoad(script.GetAMX());
		amx_Register(script.GetAMX(), PluginNatives, -1);
	}

	void onAmxUnload(IPawnScript& script) override
	{
	}

	bool loaded() override
	{
		return colDataLoaded;
	}

	bool mapReady() override
	{
		return colInit;
	}

	int rayCast(const Vector3& from, const Vector3& to, Vector3& hit) override
	{
		if (!collisionWorld)
		{
			return 0;
		}
		btVector3 result;
		int32_t model = 0;
		if (!collisionWorld->performRayTest(rayStart(from), bt(to), result, model))
		{
			return 0;
		}
		hit = Vector3(result.getX(), result.getY(), result.getZ());
		return model;
	}

	int rayCastNormal(const Vector3& from, const Vector3& to, Vector3& hit, Vector3& normal) override
	{
		if (!collisionWorld)
		{
			return 0;
		}
		btVector3 position;
		btVector3 surface;
		int32_t model = 0;
		if (!collisionWorld->performRayTestNormal(rayStart(from), bt(to), position, surface, model))
		{
			return 0;
		}
		hit = Vector3(position.getX(), position.getY(), position.getZ());
		normal = Vector3(surface.getX(), surface.getY(), surface.getZ());
		return model;
	}

	int rayCastMulti(const Vector3& from, const Vector3& to, Span<Vector3> hits, Span<int> models) override
	{
		if (!collisionWorld)
		{
			return 0;
		}
		const int size = static_cast<int>(std::min<size_t>(std::min(hits.size(), models.size()), MULTICAST_MAX));
		if (size <= 0)
		{
			return -1;
		}
		int ids[MULTICAST_MAX] = {};
		btAlignedObjectArray<btVector3> result;
		if (!collisionWorld->performRayTestAll(rayStart(from), bt(to), result, ids, size))
		{
			return 0;
		}
		if (result.size() > size)
		{
			return -1;
		}
		for (int i = 0; i < result.size(); ++i)
		{
			hits[i] = Vector3(result[i].getX(), result[i].getY(), result[i].getZ());
			models[i] = ids[i];
		}
		return result.size();
	}

	bool findZ(float x, float y, float& z) override
	{
		Vector3 hit;
		if (rayCast(Vector3(x, y, 700.0f), Vector3(x, y, -1000.0f), hit) == 0)
		{
			return false;
		}
		z = hit.z;
		return true;
	}

	bool contactTest(int model, const Vector3& pos, const Vector3& rot) override
	{
		if (!collisionWorld || !colDataLoaded || GetModelRef(model) == 65535)
		{
			return false;
		}
		btVector3 euler = bt(rot);
		btVector3 position = bt(pos);
		btQuaternion quat;
		collisionWorld->EulerToQuat(euler, quat);
		return collisionWorld->performContactTest(model, position, quat) != 0;
	}

	bool modelBounds(int model, Vector3& min, Vector3& max) override
	{
		if (!collisionWorld || !validModelRange(model))
		{
			return false;
		}
		btVector3 low;
		btVector3 high;
		if (!collisionWorld->objectManager->getBoundingBox(model, low, high))
		{
			return false;
		}
		min = Vector3(low.getX(), low.getY(), low.getZ());
		max = Vector3(high.getX(), high.getY(), high.getZ());
		return true;
	}

	int createObject(int model, const Vector3& pos, const Vector3& rot) override
	{
		if (!collisionWorld || !colDataLoaded || GetModelRef(model) == 65535)
		{
			return -1;
		}
		btVector3 euler = bt(rot);
		btQuaternion quat;
		collisionWorld->EulerToQuat(euler, quat);
		const uint16_t index = collisionWorld->createColAndreasMapObject(1, model, quat, bt(pos));
		return index == 65535 ? -1 : static_cast<int>(index);
	}

	bool setObjectPos(int index, const Vector3& pos) override
	{
		if (!collisionWorld || !validIndex(index))
		{
			return false;
		}
		btVector3 position = bt(pos);
		return collisionWorld->objectManager->setObjectPosition(static_cast<uint16_t>(index), position) != 0;
	}

	bool setObjectRot(int index, const Vector3& rot) override
	{
		if (!collisionWorld || !validIndex(index))
		{
			return false;
		}
		btVector3 euler = bt(rot);
		btQuaternion quat;
		collisionWorld->EulerToQuat(euler, quat);
		return collisionWorld->objectManager->setObjectRotation(static_cast<uint16_t>(index), quat) != 0;
	}

	bool destroyObject(int index) override
	{
		if (!collisionWorld || !validIndex(index))
		{
			return false;
		}
		return collisionWorld->objectManager->removeObjectManager(static_cast<uint16_t>(index)) != 0;
	}

	bool removeBuilding(int model, const Vector3& at, float radius) override
	{
		if (!collisionWorld || colInit)
		{
			return false;
		}
		removeBuildingData data;
		data.r_Model = static_cast<int16_t>(model);
		data.r_X = at.x;
		data.r_Y = at.y;
		data.r_Z = at.z;
		data.r_Radius = radius;
		collisionWorld->removedManager->addBuilding(data);
		return true;
	}

	bool restoreBuilding(int model, const Vector3& at, float radius) override
	{
		if (!collisionWorld || !colInit)
		{
			return false;
		}
		removeBuildingData data;
		data.r_Model = static_cast<int16_t>(model);
		data.r_X = at.x;
		data.r_Y = at.y;
		data.r_Z = at.z;
		data.r_Radius = radius;
		collisionWorld->removedManager->restoreBuilding(data);
		return true;
	}
};

static cell AMX_NATIVE_CALL CA_InterfaceSelfTest(AMX* amx, const cell* params)
{
	IColAndreasComponent* world = ColAndreasComponent::getInstance();
	const float x = amx_ctof(params[1]);
	const float y = amx_ctof(params[2]);
	int mask = 0;

	float z = 0.0f;
	if (world->findZ(x, y, z))
	{
		mask |= 1;
		cell* address = nullptr;
		amx_GetAddr(amx, params[3], &address);
		*address = amx_ftoc(z);
	}

	Vector3 hit;
	const int model = world->rayCast(Vector3(x, y, z + 10.0f), Vector3(x, y, z - 10.0f), hit);
	if (model != 0 && std::abs(hit.z - z) < 0.001f)
	{
		mask |= 2;
	}

	Vector3 normal;
	if (world->rayCastNormal(Vector3(x, y, z + 10.0f), Vector3(x, y, z - 10.0f), hit, normal) == model && std::abs(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z - 1.0f) < 0.01f)
	{
		mask |= 4;
	}

	Vector3 low;
	Vector3 high;
	if (model != 0 && world->modelBounds(model, low, high) && high.x > low.x)
	{
		mask |= 8;
	}

	const float sky = z + 300.0f;
	const int index = world->createObject(model, Vector3(x, y, sky), Vector3(0.0f, 0.0f, 0.0f));
	if (index >= 0 && world->rayCast(Vector3(x, y, sky + 50.0f), Vector3(x, y, sky - 50.0f), hit) == model)
	{
		mask |= 16;
	}

	Vector3 hits[4];
	int models[4] = {};
	if (index >= 0 && world->rayCastMulti(Vector3(x, y, sky + 50.0f), Vector3(x, y, z - 10.0f), Span<Vector3>(hits, 4), Span<int>(models, 4)) == 2)
	{
		mask |= 32;
	}

	if (index >= 0 && world->setObjectPos(index, Vector3(x, y, sky + 20.0f)) && world->rayCast(Vector3(x, y, sky + 50.0f), Vector3(x, y, sky - 50.0f), hit) == model && hit.z > sky + 10.0f)
	{
		mask |= 64;
	}

	if (index >= 0 && world->setObjectRot(index, Vector3(0.0f, 0.0f, 90.0f)) && world->destroyObject(index) && world->rayCast(Vector3(x, y, sky + 50.0f), Vector3(x, y, sky - 50.0f), hit) == 0)
	{
		mask |= 128;
	}

	if (!world->contactTest(model, Vector3(x, y, sky + 400.0f), Vector3(0.0f, 0.0f, 0.0f)))
	{
		mask |= 256;
	}

	return mask;
}

COMPONENT_ENTRY_POINT()
{
	return ColAndreasComponent::getInstance();
}
