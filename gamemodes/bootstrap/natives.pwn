forward Dialog_OnResponse(playerid, dialogid, response, listitem, const inputtext[]);

public Dialog_OnResponse(playerid, dialogid, response, listitem, const inputtext[])
{
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    pawn_call_public("Dialog_OnResponse", "dddds", playerid, dialogid, response, listitem, inputtext);
    return 0;
}

public OnPlayerUpdate(playerid)
{
    return 1;
}

public OnGameModeExit()
{
    return 1;
}

public OnPlayerConnect(playerid)
{
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    return 1;
}

public OnPlayerSpawn(playerid)
{
    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    return 1;
}

public OnPlayerTakeDamage(playerid, issuerid, Float:amount, WEAPON:weaponid, bodypart)
{
    return 1;
}

public OnPlayerGiveDamage(playerid, damagedid, Float:amount, WEAPON:weaponid, bodypart)
{
    return 1;
}

public OnPlayerWeaponShot(playerid, WEAPON:weaponid, BULLET_HIT_TYPE:hittype, hitid, Float:fX, Float:fY, Float:fZ)
{
    return 1;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    return 1;
}

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid)
{
    return 1;
}

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, CLICK_SOURCE:source)
{
    return 1;
}

public OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate)
{
    return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
    return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
    return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    return 1;
}

public OnPlayerFinishedDownloading(playerid, virtualworld)
{
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    return 1;
}

public OnVehicleSpawn(vehicleid)
{
    return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
    return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
    return 1;
}

public OnNPCFinishNode(npcid, nodeid)
{
    return 1;
}

public OnNPCFinishMove(npcid)
{
    return 1;
}

public OnNPCPlaybackEnd(npcid, recordid)
{
    return 1;
}

public OnNPCDeath(npcid, killerid, WEAPON:reason)
{
    return 1;
}

public OnNPCDestroy(npcid)
{
    return 1;
}

public OnNPCTakeDamage(npcid, issuerid, Float:amount, WEAPON:weaponid, bodypart)
{
    return 1;
}

public OnDynamicObjectMoved(STREAMER_TAG_OBJECT:objectid)
{
    return 1;
}

public OnObjectMoved(objectid)
{
    return 1;
}

public OnPlayerShootDynamicObject(playerid, weaponid, STREAMER_TAG_OBJECT:objectid, Float:x, Float:y, Float:z)
{
    return 1;
}

public OnPlayerEditDynamicObject(playerid, STREAMER_TAG_OBJECT:objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
    return 1;
}

public OnPlayerEditAttachedObject(playerid, EDIT_RESPONSE:response, index, modelid, boneid, Float:fOffsetX, Float:fOffsetY, Float:fOffsetZ, Float:fRotX, Float:fRotY, Float:fRotZ, Float:fScaleX, Float:fScaleY, Float:fScaleZ)
{
    return 1;
}

public OnPlayerEnterDynamicRaceCP(playerid, STREAMER_TAG_RACE_CP:checkpointid)
{
    return 1;
}

public OnPlayerEnterDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
    return 1;
}

public OnPlayerLeaveDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    return 1;
}

public OnPlayerLeaveDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    return 1;
}

public OnDynamicActorStreamIn(STREAMER_TAG_ACTOR:actorid, forplayerid)
{
    return 1;
}

public OnPlayerPickUpDynamicPickup(playerid, STREAMER_TAG_PICKUP:pickupid)
{
    return 1;
}

public OnPlayerGiveDamageDynamicActor(playerid, STREAMER_TAG_ACTOR:actorid, Float:amount, weaponid, bodypart)
{
    return 1;
}

public OnPlayerGiveDamageActor(playerid, damaged_actorid, Float:amount, WEAPON:weaponid, bodypart)
{
    return 1;
}

public OnPedestrianGetDamage(pedestrianid, playerid, weaponid, Float:amount)
{
    return 1;
}

public OnPedestrianDeath(actorid, killerid, reason)
{
    return 1;
}

public OnRiderArrive(riderid)
{
    return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
    return 1;
}

public OnRuntimeError(code, &bool:suppress)
{
    #pragma unused suppress
    return 1;
}

public OnPlayerText(playerid, text[])
{
    return 0;
}

public Streamer_OnItemStreamIn(type,STREAMER_ALL_TAGS:id,forplayerid)
{
    return 1;
}
