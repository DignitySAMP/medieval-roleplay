#if defined _pedestrians_included
	#endinput
#endif
#define _pedestrians_included

#define PED_STATE_WALKING 1
#define PED_STATE_PANIC 2
#define PED_STATE_FALLEN 3
#define PED_STATE_STOPPED 4
#define PED_STATE_DEAD 5

#define DEFAULT_PED_MAX_POOL            500
#define DEFAULT_PED_MAX_PER_PLAYER      20
#define DEFAULT_PED_SPAWN_DENSITY       1.0
#define DEFAULT_PED_STREAM_DISTANCE     220.0
#define DEFAULT_PED_PANIC_RADIUS        80.0
#define DEFAULT_PED_GUNFIRE_PANIC_MS    4000
#define DEFAULT_PED_CORPSE_MS           30000

#if !defined PED_USE_COLANDREAS
	#if defined SKIP_COLANDREAS
		#define PED_USE_COLANDREAS false
	#else
		#define PED_USE_COLANDREAS true
	#endif
#endif

#if !defined PED_MAX_POOL
	#define PED_MAX_POOL DEFAULT_PED_MAX_POOL
#endif

#if !defined PED_MAX_PER_PLAYER
	#define PED_MAX_PER_PLAYER DEFAULT_PED_MAX_PER_PLAYER
#endif

#if !defined PED_SPAWN_DENSITY
	#define PED_SPAWN_DENSITY DEFAULT_PED_SPAWN_DENSITY
#endif

#if !defined PED_STREAM_DISTANCE
	#define PED_STREAM_DISTANCE DEFAULT_PED_STREAM_DISTANCE
#endif

#if !defined PED_PANIC_RADIUS
	#define PED_PANIC_RADIUS DEFAULT_PED_PANIC_RADIUS
#endif

#if !defined PED_GUNFIRE_PANIC_MS
	#define PED_GUNFIRE_PANIC_MS DEFAULT_PED_GUNFIRE_PANIC_MS
#endif

#if !defined PED_CORPSE_MS
	#define PED_CORPSE_MS DEFAULT_PED_CORPSE_MS
#endif

native Path_SetUseColAndreas(bool:use);
native TogglePedInInterior(bool:toggle);
native Path_SetTime(hour, minute);

native Path_SetMaxActorsInPool(count);
native Path_GetMaxActorsInPool();

native Path_SetMaxActorsPerPlayer(count);
native Path_GetMaxActorsPerPlayer();

native Path_SetSpawnDensity(Float:density);
native Float:Path_GetSpawnDensity();

native Path_SetStreamingDistance(Float:distance);
native Float:Path_GetStreamingDistance();

native Path_AddMaleSkin(skinid, walkstyle);
native Path_AddFemaleSkin(skinid, walkstyle);
native IgnorePedestrianNode(nodeid);
native Path_AddNoSpawnArea(Float:minX, Float:minY, Float:maxX, Float:maxY);

native PrintIgnoredNodesCount();
native SetPedestrianHealth(actorid, Float:health);
native Float:GetPedestrianHealth(actorid);
native SetPedestrianSpeed(actorid, Float:speed);
native SetPedestrianFloats(actorid, bool:floats, Float:surfaceZ);
native MakePedestrianPanic(actorid, duration_ms);
native IsPedestrianPanicking(actorid);
native SetPedestrianSkin(actorid, skinid);
native SetPedestrianWalkStyle(actorid, style);
native GetPedestrianNode(actorid);
native GetClosestPedestrianID(playerid);
native GetPedestrianSex(actorid);
native StopPedestrian(actorid);
native ResumePedestrian(actorid);
native ApplyPedestrianAnim(actorid, const animlib[], const animname[], Float:fDelta, loop, lockx, locky, freeze, time);
native IsPlayerInFrontOfPed(playerid, actorid);

native IsValidPedestrian(actorid);
native GetPedestriansInRange(Float:x, Float:y, Float:z, Float:range, out[], max = sizeof(out));
native GetPedestrianPos(actorid, &Float:x, &Float:y, &Float:z);
native SetPedestrianFacingAngle(actorid, Float:angle);
native Float:GetPedestrianFacingAngle(actorid);
native SetPedestrianTarget(actorid, Float:x, Float:y, Float:z, Float:speed);
native DespawnPedestrian(actorid);
native Path_ReloadNodes();
native PedestrianFleeFrom(actorid, Float:x, Float:y, Float:z, duration_ms);
native SetPedestrianKind(actorid, kind);
native SpawnPedestrianAt(skin, Float:x, Float:y, Float:z, Float:angle, kind = 0);
native GetPedestrianKind(actorid);
native Path_SetCorpseTime(ms);
native Path_SetPanicRadius(Float:radius);
native Path_SetPanicDuration(ms);
native Path_SetGasTime(ms);
native IsPointInTearGas(Float:x, Float:y, Float:z);
native Path_AddGangZone(gang, Float:minX, Float:minY, Float:maxX, Float:maxY);
native Path_SetGangSkins(gang, skinA, skinB, skinC);
native Path_SetPlayerGang(playerid, gang);
native Path_GetPlayerGang(playerid);
native Path_SetPackOdds(odds);
native Path_SetPackHostileRange(Float:range);
native Path_SetMaxPacksPerGang(count);
native GetPedestrianGang(actorid);
native Path_SetDebug(level);
native Path_SetSteering(bool:toggle);
native Path_DebugThrow(playerid, weaponid);
forward OnPedestrianPackHostile(leaderid, playerid);
native Path_SetPlayerHuman(playerid, bool:human);
native Path_SetNpcAsHuman(bool:toggle);

#define PED_BODY_AUTO (-1)
#define PED_BODY_PEOPLE (0)
#define PED_BODY_DEER (1)
#define PED_BODY_SHEEP (2)
native SetPedestrianBody(actorid, body);
native GetPedestrianBody(actorid);
native IsPedestrianOnNav(actorid);
native PedestrianPathProbe(body, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, &Float:length);
native Path_SetNav(bool:toggle);
native Path_SetNavCrowd(bool:toggle);
native Path_ReloadNav();
native Path_PrintNavStats();
native Path_GetNavLegs(&ok, &failed, &stalls, &targetFails = 0);
forward OnPedestrianPathFailed(actorid);

forward OnPedestrianGetDamage(pedestrianid, playerid, weaponid, Float:amount);
forward OnPedestrianSpawn(actorid, nodeid);
forward OnPedestrianReachTarget(actorid);
forward OnPedestrianPunchPlayer(actorid, playerid, punch);
forward OnPlayerThrowThrowable(playerid, weaponid, Float:x, Float:y, Float:z);
forward OnPlayerInTearGas(playerid, throwerid);
forward OnPedestrianHitByVeh(playerid, vehicleid, actorid);
forward OnPlayerAimPedestrian(playerid, pedestrianid);
forward OnPedestrianStateChange(actorid, oldstate, newstate);
forward OnPedestrianDeath(actorid, killerid, reason);

stock InitPedestrians()
{
#if PED_USE_COLANDREAS
	if(Path_SetUseColAndreas(true))
	{
		print("[Pedestrians] ColAndreas enabled for pedestrian height calculation.");
	}
	else
	{
		print("[Pedestrians] WARNING: PED_USE_COLANDREAS is set to true but ColAndreas plugin is missing.");
		print("[Pedestrians] Falling back to default coordinate calculation method.");
	}
#else
	Path_SetUseColAndreas(false);
	print("[Pedestrians] ColAndreas disabled via configuration.");
#endif

	TogglePedInInterior(false);
	Path_SetMaxActorsInPool(PED_MAX_POOL);
	Path_SetMaxActorsPerPlayer(PED_MAX_PER_PLAYER);
	Path_SetSpawnDensity(PED_SPAWN_DENSITY);
	Path_SetStreamingDistance(PED_STREAM_DISTANCE);
	Path_SetPanicRadius(PED_PANIC_RADIUS);
	Path_SetPanicDuration(PED_GUNFIRE_PANIC_MS);
	Path_SetCorpseTime(PED_CORPSE_MS);
	PrintIgnoredNodesCount();
}

native Rider_Create(const name[], skin, Float:x, Float:y, Float:z, Float:angle, world, slot, bone, animIndex, Float:rideHeight);
native Rider_SetGait(riderid, gait, firstModel, step, frames, frameMs, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz);
native Rider_MoveTo(riderid, Float:x, Float:y, Float:z, gait, Float:speed);
native Rider_SetRoute(riderid, const Float:points[], count, gait, Float:speed);
native Rider_Stop(riderid);
native Rider_SetSpeed(riderid, gait, Float:speed);
native bool:Rider_IsMoving(riderid);
native bool:Rider_IsValid(riderid);
native Rider_GetRoutePoint(riderid);
native bool:Rider_GetPos(riderid, &Float:x, &Float:y, &Float:z, &Float:angle);
native Rider_Destroy(riderid);
native Rider_Count();
forward OnRiderArrive(riderid);
