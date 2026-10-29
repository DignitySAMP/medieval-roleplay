#pragma once

#include <sdk.hpp>

static const UID PedestriansComponent_UID = UID(0x4B7E2D93A1C65F08);

struct IPedestriansComponent : public IComponent
{
	PROVIDE_UID(PedestriansComponent_UID)

	virtual int spawnAt(const Vector3& pos, float angle, int skin, int kind) = 0;
	virtual bool flee(int actorid, const Vector3& from, Milliseconds duration) = 0;
	virtual bool walkTo(int actorid, const Vector3& to, float speed) = 0;
	virtual bool isAlive(int actorid) = 0;
	virtual int count() = 0;
};
