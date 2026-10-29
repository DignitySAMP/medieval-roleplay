#pragma once

#include <sdk.hpp>
#include <Server/Components/Pawn/pawn.hpp>
#include <Server/Components/Pawn/Impl/pawn_natives.hpp>

#include <cstdint>
#include <vector>

#define MAX_PLAYERS 1000

typedef void (*logprintf_t)(const char* format, ...);
extern logprintf_t logprintf;

struct PedNode;

bool sampgdk_IsPlayerConnected(int playerid);
bool sampgdk_IsPlayerNPC(int playerid);
int sampgdk_GetPlayerPoolSize();
bool sampgdk_GetPlayerPos(int playerid, float* x, float* y, float* z);
int sampgdk_GetPlayerVirtualWorld(int playerid);
int sampgdk_GetPlayerInterior(int playerid);
int sampgdk_GetPlayerState(int playerid);
bool sampgdk_GetPlayerFacingAngle(int playerid, float* angle);
int sampgdk_GetPlayerAnimationIndex(int playerid);
int sampgdk_GetPlayerWeapon(int playerid);
int sampgdk_GetPlayerAmmo(int playerid);
bool sampgdk_GetPlayerKeys(int playerid, int* keys, int* updown, int* leftright);
bool sampgdk_GetPlayerVelocity(int playerid, float* x, float* y, float* z);
bool sampgdk_GetPlayerCameraPos(int playerid, float* x, float* y, float* z);
bool sampgdk_GetPlayerCameraFrontVector(int playerid, float* x, float* y, float* z);
int sampgdk_GetPlayerTargetActor(int playerid);
int sampgdk_GetPlayerVehicleID(int playerid);
bool sampgdk_IsPlayerInRangeOfPoint(int playerid, float range, float x, float y, float z);
bool sampgdk_PlayerPlaySound(int playerid, int soundid, float x, float y, float z);

bool sampgdk_GetVehiclePos(int vehicleid, float* x, float* y, float* z);
bool sampgdk_GetVehicleVelocity(int vehicleid, float* x, float* y, float* z);

int sampgdk_CreateActor(int skin, float x, float y, float z, float angle);
bool sampgdk_DestroyActor(int actorid);
bool sampgdk_SetActorPos(int actorid, float x, float y, float z);
bool sampgdk_GetActorPos(int actorid, float* x, float* y, float* z);
bool sampgdk_SetActorFacingAngle(int actorid, float angle);
bool sampgdk_ApplyActorAnimation(int actorid, const char* lib, const char* name, float delta, bool loop, bool lockx, bool locky, bool freeze, int time);
bool sampgdk_ClearActorAnimations(int actorid);
bool sampgdk_SetActorHealth(int actorid, float health);
bool sampgdk_SetActorInvulnerable(int actorid, bool invulnerable);
bool sampgdk_SetActorVirtualWorld(int actorid, int world);
int sampgdk_GetActorVirtualWorld(int actorid);

int sampgdk_CreateObject(int model, float x, float y, float z, float rx, float ry, float rz, float drawdistance);
bool sampgdk_DestroyObject(int objectid);

bool Bridge_HasCollision();
int Bridge_RayCast(float x1, float y1, float z1, float x2, float y2, float z2, float* hx, float* hy, float* hz);
int Bridge_RayCastNormal(float x1, float y1, float z1, float x2, float y2, float z2, float* hx, float* hy, float* hz, float* nx, float* ny, float* nz);

bool Bridge_LoadNodes(std::vector<PedNode>& nodes);
