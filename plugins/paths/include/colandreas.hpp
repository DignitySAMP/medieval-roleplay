#pragma once

#include <sdk.hpp>

static const UID ColAndreasComponent_UID = UID(0x5C3A9E17B04D2F61);

struct IColAndreasComponent : public IComponent
{
	PROVIDE_UID(ColAndreasComponent_UID)

	virtual bool loaded() = 0;
	virtual bool mapReady() = 0;

	virtual int rayCast(const Vector3& from, const Vector3& to, Vector3& hit) = 0;
	virtual int rayCastNormal(const Vector3& from, const Vector3& to, Vector3& hit, Vector3& normal) = 0;
	virtual int rayCastMulti(const Vector3& from, const Vector3& to, Span<Vector3> hits, Span<int> models) = 0;
	virtual bool findZ(float x, float y, float& z) = 0;

	virtual bool contactTest(int model, const Vector3& pos, const Vector3& rot) = 0;
	virtual bool modelBounds(int model, Vector3& min, Vector3& max) = 0;

	virtual int createObject(int model, const Vector3& pos, const Vector3& rot) = 0;
	virtual bool setObjectPos(int index, const Vector3& pos) = 0;
	virtual bool setObjectRot(int index, const Vector3& rot) = 0;
	virtual bool destroyObject(int index) = 0;

	virtual bool removeBuilding(int model, const Vector3& at, float radius) = 0;
	virtual bool restoreBuilding(int model, const Vector3& at, float radius) = 0;
};
