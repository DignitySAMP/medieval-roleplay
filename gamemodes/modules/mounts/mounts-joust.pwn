static s_MountDismountCheck[32];

stock Mount_SetDismountCheck(const callback[])
{
    strcopy(s_MountDismountCheck,callback);
}

stock bool:Mount_CanDismount(playerid)
{
    return s_MountDismountCheck[0] == EOS || bool:pawn_call_public(s_MountDismountCheck,"d",playerid);
}

#define MODEL_TOURNEY_LANCE (-8218)
#define MODEL_TOURNEY_LANCE_STUB (-8219)
#define MOUNT_LANE_GAIN (0.08)
#define MOUNT_LANE_PUSH_MAX (0.06)

enum E_LANCE_POSE
{
    E_LANCE_NONE,
    E_LANCE_UPRIGHT,
    E_LANCE_LOWERING,
    E_LANCE_LOWERED,
    E_LANCE_SAGGING,
    E_LANCE_BROKEN
}

enum E_MOUNT_LANE
{
    bool:E_MOUNT_LANE_ACTIVE,
    Float:E_MOUNT_LANE_X,
    Float:E_MOUNT_LANE_Y,
    Float:E_MOUNT_LANE_END_X,
    Float:E_MOUNT_LANE_END_Y
}

static s_MountLanes[MAX_PLAYERS][E_MOUNT_LANE];
static E_LANCE_POSE:s_MountLancePoses[MAX_PLAYERS];
static bool:s_MountLanceHelms[MAX_PLAYERS];

forward bool:Mount_IsRiding(playerid);

stock bool:Mount_GetLaneOffset(Float:startX,Float:startY,Float:endX,Float:endY,Float:positionX,Float:positionY,&Float:along,&Float:across)
{
    new Float:deltaX = endX - startX, Float:deltaY = endY - startY, Float:length = VectorSize(deltaX,deltaY,0.0);
    if (length < 0.1)
    {
        along = 0.0;
        across = 0.0;
        return false;
    }
    along = ((positionX - startX) * deltaX + (positionY - startY) * deltaY) / length;
    across = (-(positionX - startX) * deltaY + (positionY - startY) * deltaX) / length;
    return true;
}

stock Float:Mount_GetLanePush(Float:across)
{
    new Float:push = -across * MOUNT_LANE_GAIN;
    if (push > MOUNT_LANE_PUSH_MAX)
    {
        return MOUNT_LANE_PUSH_MAX;
    }
    if (push < -MOUNT_LANE_PUSH_MAX)
    {
        return -MOUNT_LANE_PUSH_MAX;
    }
    return push;
}

stock bool:Mount_HasLane(playerid)
{
    return Util_IsValidPlayer(playerid) && s_MountLanes[playerid][E_MOUNT_LANE_ACTIVE];
}

stock bool:Mount_SetLane(playerid,Float:startX,Float:startY,Float:endX,Float:endY)
{
    if (!Mount_IsRiding(playerid) || VectorSize(endX - startX,endY - startY,0.0) < 0.1)
    {
        return false;
    }
    s_MountLanes[playerid][E_MOUNT_LANE_ACTIVE] = true;
    s_MountLanes[playerid][E_MOUNT_LANE_X] = startX;
    s_MountLanes[playerid][E_MOUNT_LANE_Y] = startY;
    s_MountLanes[playerid][E_MOUNT_LANE_END_X] = endX;
    s_MountLanes[playerid][E_MOUNT_LANE_END_Y] = endY;
    return true;
}

stock Mount_ClearLane(playerid)
{
    if (Util_IsValidPlayer(playerid))
    {
        s_MountLanes[playerid][E_MOUNT_LANE_ACTIVE] = false;
    }
}

stock Mount_HoldLane(playerid,Float:speed,&Float:angle,&Float:velocityX,&Float:velocityY)
{
    if (!Mount_HasLane(playerid))
    {
        return;
    }
    new Float:positionX, Float:positionY, Float:positionZ, Float:along, Float:across;
    GetPlayerPos(playerid,positionX,positionY,positionZ);
    new Float:deltaX = s_MountLanes[playerid][E_MOUNT_LANE_END_X] - s_MountLanes[playerid][E_MOUNT_LANE_X];
    new Float:deltaY = s_MountLanes[playerid][E_MOUNT_LANE_END_Y] - s_MountLanes[playerid][E_MOUNT_LANE_Y];
    new Float:length = VectorSize(deltaX,deltaY,0.0);
    Mount_GetLaneOffset(s_MountLanes[playerid][E_MOUNT_LANE_X],s_MountLanes[playerid][E_MOUNT_LANE_Y],s_MountLanes[playerid][E_MOUNT_LANE_END_X],s_MountLanes[playerid][E_MOUNT_LANE_END_Y],positionX,positionY,along,across);
    new Float:push = Mount_GetLanePush(across);
    angle = Util_GetAngleToPoint(s_MountLanes[playerid][E_MOUNT_LANE_X],s_MountLanes[playerid][E_MOUNT_LANE_Y],s_MountLanes[playerid][E_MOUNT_LANE_END_X],s_MountLanes[playerid][E_MOUNT_LANE_END_Y]);
    velocityX = speed * deltaX / length - push * deltaY / length;
    velocityY = speed * deltaY / length + push * deltaX / length;
}

stock E_LANCE_POSE:Mount_GetLance(playerid)
{
    return Util_IsValidPlayer(playerid) ? s_MountLancePoses[playerid] : E_LANCE_NONE;
}

stock Mount_GetLancePose(E_LANCE_POSE:pose,bool:isHelm,&Float:rotationX,&Float:rotationY,&Float:rotationZ)
{
    rotationX = 87.0;
    rotationY = -4.2;
    rotationZ = -174.1;
    if (pose == E_LANCE_LOWERING)
    {
        rotationY = -45.0;
        rotationZ = -151.6;
    }
    else if (pose == E_LANCE_LOWERED || pose == E_LANCE_BROKEN || pose == E_LANCE_SAGGING)
    {
        rotationY = pose == E_LANCE_SAGGING ? -105.0 : (isHelm ? -82.0 : -94.2);
        rotationZ = -129.1;
    }
}

stock Mount_GetLanceFit(E_LANCE_POSE:pose,bool:isHelm,Float:offset[3],Float:rotation[3],Float:scale[3])
{
    new model = pose == E_LANCE_BROKEN ? MODEL_TOURNEY_LANCE_STUB : MODEL_TOURNEY_LANCE;
    new Float:baseX, Float:baseY, Float:baseZ;
    Mount_GetLancePose(pose == E_LANCE_BROKEN ? E_LANCE_BROKEN : E_LANCE_UPRIGHT,false,baseX,baseY,baseZ);
    Mount_GetLancePose(pose,isHelm,rotation[0],rotation[1],rotation[2]);
    new Float:poseX = rotation[0], Float:poseY = rotation[1], Float:poseZ = rotation[2];
    offset[0] = 0.096;
    offset[1] = 0.038;
    offset[2] = 0.0;
    scale[0] = scale[1] = scale[2] = 1.0;

    if (Attach_GetFit(model,ATTACH_BONE_RIGHT_HAND,offset,rotation,scale))
    {
        rotation[0] += poseX - baseX;
        rotation[1] += poseY - baseY;
        rotation[2] += poseZ - baseZ;
    }
}

stock bool:Mount_SetLance(playerid,E_LANCE_POSE:pose)
{
    if (!Util_IsValidPlayer(playerid) || pose < E_LANCE_NONE || pose > E_LANCE_BROKEN || (pose != E_LANCE_NONE && !Mount_IsRiding(playerid)))
    {
        return false;
    }
    if (pose == E_LANCE_NONE)
    {
        if (s_MountLancePoses[playerid] != E_LANCE_NONE)
        {
            RemovePlayerAttachedObject(playerid,ATTACH_SLOT_HAND);
        }
        Attach_SetSlotFitEnabled(playerid,ATTACH_SLOT_HAND,true);
        s_MountLancePoses[playerid] = pose;
        s_MountLanceHelms[playerid] = false;
        return true;
    }
    new Float:offset[3], Float:rotation[3], Float:scale[3];
    Mount_GetLanceFit(pose,s_MountLanceHelms[playerid],offset,rotation,scale);
    Attach_SetSlotFitEnabled(playerid,ATTACH_SLOT_HAND,false);
    if (!SetPlayerAttachedObject(playerid,ATTACH_SLOT_HAND,pose == E_LANCE_BROKEN ? MODEL_TOURNEY_LANCE_STUB : MODEL_TOURNEY_LANCE,ATTACH_BONE_RIGHT_HAND,offset[0],offset[1],offset[2],rotation[0],rotation[1],rotation[2],scale[0],scale[1],scale[2]))
    {
        Attach_SetSlotFitEnabled(playerid,ATTACH_SLOT_HAND,true);
        return false;
    }
    s_MountLancePoses[playerid] = pose;
    return true;
}

stock Mount_SetLanceAim(playerid,bool:isHelm)
{
    if (Util_IsValidPlayer(playerid))
    {
        s_MountLanceHelms[playerid] = isHelm;
        Mount_SetLance(playerid,s_MountLancePoses[playerid]);
    }
}

#include <pp-hooks>

hook OnPlayerConnect(playerid)
{
    s_MountLanes[playerid][E_MOUNT_LANE_ACTIVE] = false;
    s_MountLancePoses[playerid] = E_LANCE_NONE;
    s_MountLanceHelms[playerid] = false;
}

hook OnPlayerDisconnect(playerid,reason)
{
    #pragma unused reason
    Mount_ClearLane(playerid);
    Mount_SetLance(playerid,E_LANCE_NONE);
}

hook Attach_OnFitChanged(model,bone)
{
    if (bone == ATTACH_BONE_RIGHT_HAND && (model == MODEL_TOURNEY_LANCE || model == MODEL_TOURNEY_LANCE_STUB))
    {
        foreach (new playerid : Player)
        {
            new E_LANCE_POSE:pose = Mount_GetLance(playerid);
            if (pose != E_LANCE_NONE)
            {
                Mount_SetLance(playerid,pose);
            }
        }
    }
}
