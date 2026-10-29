#define EVENTS_JOUST_LANE (1.2)
#define EVENTS_JOUST_LOWER_MS (400)
#define EVENTS_JOUST_STEADY_MS (800)
#define EVENTS_JOUST_LANE_ERROR (0.5)
#define EVENTS_QUINTAIN_X (13.8)
#define EVENTS_QUINTAIN_Y (-4.58)
#define EVENTS_QUINTAIN_PIN (2.24)
#define EVENTS_QUINTAIN_SHIELD_X (13.86)
#define EVENTS_PRACTICE_LIMIT_MS (15000)

enum E_PRACTICE
{
    bool:E_PRACTICE_ACTIVE,
    bool:E_PRACTICE_LOWERED,
    bool:E_PRACTICE_HELM,
    bool:E_PRACTICE_JUDGED,
    E_PRACTICE_LOWER_TICK,
    E_PRACTICE_START_TICK,
    E_PRACTICE_LAST_TICK,
    E_PRACTICE_BOX,
    E_LANCE_POSE:E_PRACTICE_POSE,
    Float:E_PRACTICE_LAST_X,
    Float:E_PRACTICE_LAST_Y
}

static s_Practices[MAX_PLAYERS][E_PRACTICE];
static s_PracticeRider = INVALID_PLAYER_ID;
static STREAMER_TAG_OBJECT:s_QuintainPost = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
static STREAMER_TAG_OBJECT:s_QuintainArm = STREAMER_TAG_OBJECT:INVALID_STREAMER_ID;
static s_QuintainSpinUntil;
static bool:s_QuintainPlaced;

stock E_LANCE_POSE:Events_GetLanceState(bool:isLowered,elapsed)
{
    if (!isLowered || elapsed < 0)
    {
        return E_LANCE_UPRIGHT;
    }
    if (elapsed < EVENTS_JOUST_LOWER_MS)
    {
        return E_LANCE_LOWERING;
    }
    if (elapsed < EVENTS_JOUST_LOWER_MS + EVENTS_JOUST_STEADY_MS)
    {
        return E_LANCE_LOWERED;
    }
    return E_LANCE_SAGGING;
}

stock Events_JudgeQuintain(E_LANCE_POSE:pose,bool:isGalloping,bool:isWalking,Float:laneError,bool:isHelm)
{
    if (isWalking || floatabs(laneError) > EVENTS_JOUST_LANE_ERROR || (pose != E_LANCE_LOWERED && pose != E_LANCE_SAGGING))
    {
        return 0;
    }
    if (isHelm && (pose != E_LANCE_LOWERED || !isGalloping))
    {
        return 0;
    }
    return pose == E_LANCE_LOWERED && isGalloping ? 2 : 1;
}

stock bool:Events_GetQuintainCrossing(Float:beforeX,Float:beforeY,Float:afterX,Float:afterY,&Float:fraction,&Float:laneError)
{
    if (beforeX >= EVENTS_QUINTAIN_SHIELD_X || afterX < EVENTS_QUINTAIN_SHIELD_X)
    {
        return false;
    }
    fraction = (EVENTS_QUINTAIN_SHIELD_X - beforeX) / (afterX - beforeX);
    laneError = beforeY + (afterY - beforeY) * fraction + EVENTS_JOUST_LANE;
    return true;
}

stock Events_GetPracticeLane(&Float:startX,&Float:startY,&Float:endX,&Float:endY)
{
    Events_ListsToWorld(-18.0,-EVENTS_JOUST_LANE,startX,startY);
    Events_ListsToWorld(18.0,-EVENTS_JOUST_LANE,endX,endY);
}

stock Events_GetQuintainObject(bool:isArm)
{
    return isArm ? _:s_QuintainArm : _:s_QuintainPost;
}

stock Events_PlaceQuintain()
{
    if (s_QuintainPlaced || g_EventsLists[0] == 0.0)
    {
        return false;
    }
    new Float:positionX, Float:positionY;
    Events_ListsToWorld(EVENTS_QUINTAIN_X,EVENTS_QUINTAIN_Y,positionX,positionY);
    new Float:ground = Events_ListsGroundAt(positionX,positionY), Float:rotation = Util_NormalizeAngle(Events_ListsFrameAngle() + 90.0);
    s_QuintainPost = Nearby_CreateDynamicObject(MODEL_TOURNEY_QUINTAIN,positionX,positionY,ground,0.0,0.0,rotation,0,0,-1,EVENTS_LISTS_STREAM,EVENTS_LISTS_STREAM);
    s_QuintainArm = Nearby_CreateDynamicObject(MODEL_TOURNEY_QUINTAIN_ARM,positionX,positionY,ground + EVENTS_QUINTAIN_PIN,0.0,0.0,rotation,0,0,-1,EVENTS_LISTS_STREAM,EVENTS_LISTS_STREAM);
    s_QuintainPlaced = true;
    return true;
}

stock bool:Events_IsPractising(playerid)
{
    return Util_IsValidPlayer(playerid) && s_Practices[playerid][E_PRACTICE_ACTIVE];
}

stock Events_StopPractice(playerid)
{
    if (!Util_IsValidPlayer(playerid))
    {
        return;
    }
    if (s_Practices[playerid][E_PRACTICE_BOX] > 0)
    {
        Infobox_Hide(playerid,s_Practices[playerid][E_PRACTICE_BOX]);
    }
    s_Practices[playerid][E_PRACTICE_BOX] = 0;
    s_Practices[playerid][E_PRACTICE_ACTIVE] = false;
    if (s_PracticeRider == playerid)
    {
        s_PracticeRider = INVALID_PLAYER_ID;
        Mount_ClearLane(playerid);
        Mount_SetLance(playerid,E_LANCE_NONE);
    }
}

stock bool:Events_IsAtPracticeGate(playerid)
{
    if (!s_QuintainPlaced || IsPlayerNPC(playerid) || !Mount_IsRiding(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || Events_GetRunningEvent() != -1)
    {
        return false;
    }
    new Float:positionX, Float:positionY, Float:positionZ, Float:frameX, Float:frameY;
    GetPlayerPos(playerid,positionX,positionY,positionZ);
    Events_WorldToLists(positionX,positionY,frameX,frameY);
    return frameX >= -21.0 && frameX <= -15.5 && floatabs(frameY + EVENTS_JOUST_LANE) <= 2.0 && floatabs(positionZ - g_EventsLists[2]) < 6.0;
}

stock Events_ShowPracticeBox(playerid,E_LANCE_POSE:pose)
{
    new lanceName[16];
    switch (pose)
    {
        case E_LANCE_UPRIGHT:
        {
            strcopy(lanceName,"up");
        }
        case E_LANCE_LOWERING:
        {
            strcopy(lanceName,"lowering");
        }
        case E_LANCE_LOWERED:
        {
            strcopy(lanceName,"steady");
        }
        case E_LANCE_SAGGING:
        {
            strcopy(lanceName,"sagging");
        }
        case E_LANCE_BROKEN:
        {
            strcopy(lanceName,"broken");
        }
    }
    s_Practices[playerid][E_PRACTICE_BOX] = Infobox_Show(playerid,"Joust practice",sprintf("Lance: ~y~%s~w~   Aim: ~y~%s~w~~n~Hold forward and gallop.~n~~y~Y~w~ lowers the lance. ~y~H~w~ switches aim.~n~~y~F~w~ dismounts and ends practice.",lanceName,s_Practices[playerid][E_PRACTICE_HELM] ? ("helm") : ("shield")),4);
}

stock bool:Events_StartPractice(playerid)
{
    if (!Events_IsAtPracticeGate(playerid) || Gui_IsBusy(playerid))
    {
        return false;
    }
    if (s_PracticeRider != INVALID_PLAYER_ID || s_QuintainSpinUntil > GetTickCount())
    {
        Gui_Notify(playerid,"The quintain is still in use. Wait for the rider and arm to finish, then try again.");
        return false;
    }
    new Float:startX, Float:startY, Float:endX, Float:endY;
    Events_GetPracticeLane(startX,startY,endX,endY);
    if (IsPlayerAttachedObjectSlotUsed(playerid,ATTACH_SLOT_HAND) || !Mount_SetLane(playerid,startX,startY,endX,endY))
    {
        Gui_Notify(playerid,"Put away what you're holding before practising with the lance.");
        return false;
    }
    Mount_SetLanceAim(playerid,false);
    if (!Mount_SetLance(playerid,E_LANCE_UPRIGHT))
    {
        Mount_ClearLane(playerid);
        return false;
    }
    s_PracticeRider = playerid;
    s_Practices[playerid][E_PRACTICE_ACTIVE] = true;
    s_Practices[playerid][E_PRACTICE_LOWERED] = false;
    s_Practices[playerid][E_PRACTICE_HELM] = false;
    s_Practices[playerid][E_PRACTICE_JUDGED] = false;
    s_Practices[playerid][E_PRACTICE_START_TICK] = GetTickCount();
    s_Practices[playerid][E_PRACTICE_LAST_TICK] = GetTickCount();
    s_Practices[playerid][E_PRACTICE_POSE] = E_LANCE_UPRIGHT;
    new Float:positionX, Float:positionY, Float:positionZ;
    GetPlayerPos(playerid,positionX,positionY,positionZ);
    Events_WorldToLists(positionX,positionY,s_Practices[playerid][E_PRACTICE_LAST_X],s_Practices[playerid][E_PRACTICE_LAST_Y]);
    Events_ShowPracticeBox(playerid,E_LANCE_UPRIGHT);
    Gui_Notify(playerid,"Lower the lance just before the quintain. It takes 0.4 seconds to come down, then stays steady for 0.8 seconds.");
    return true;
}

static Events_UpdatePractice(playerid)
{
    if (!Events_IsPractising(playerid))
    {
        return;
    }
    new now = GetTickCount(), Float:positionX, Float:positionY, Float:positionZ, Float:frameX, Float:frameY;
    GetPlayerPos(playerid,positionX,positionY,positionZ);
    Events_WorldToLists(positionX,positionY,frameX,frameY);
    if (!Mount_IsRiding(playerid) || !Session_IsPlaying(playerid) || GetPlayerVirtualWorld(playerid) != 0 || GetPlayerInterior(playerid) != 0 || Events_GetRunningEvent() != -1 || frameX > 18.5 || frameX < -22.0 || floatabs(frameY + EVENTS_JOUST_LANE) > 3.0 || floatabs(positionZ - g_EventsLists[2]) >= 6.0 || now - s_Practices[playerid][E_PRACTICE_START_TICK] > EVENTS_PRACTICE_LIMIT_MS)
    {
        Events_StopPractice(playerid);
        Gui_Notify(playerid,"Practice ended. Return to the west gate for another run.");
        return;
    }
    new E_LANCE_POSE:pose = s_Practices[playerid][E_PRACTICE_JUDGED] ? E_LANCE_BROKEN : Events_GetLanceState(s_Practices[playerid][E_PRACTICE_LOWERED],now - s_Practices[playerid][E_PRACTICE_LOWER_TICK]);
    if (s_Practices[playerid][E_PRACTICE_JUDGED])
    {
        pose = Mount_GetLance(playerid);
    }
    if (pose != s_Practices[playerid][E_PRACTICE_POSE])
    {
        Mount_SetLance(playerid,pose);
        s_Practices[playerid][E_PRACTICE_POSE] = pose;
        if (!Gui_IsBusy(playerid))
        {
            Events_ShowPracticeBox(playerid,pose);
        }
    }
    new Float:fraction, Float:laneError;
    if (!s_Practices[playerid][E_PRACTICE_JUDGED] && Events_GetQuintainCrossing(s_Practices[playerid][E_PRACTICE_LAST_X],s_Practices[playerid][E_PRACTICE_LAST_Y],frameX,frameY,fraction,laneError))
    {
        new crossingTick = s_Practices[playerid][E_PRACTICE_LAST_TICK] + floatround(float(now - s_Practices[playerid][E_PRACTICE_LAST_TICK]) * fraction);
        pose = Events_GetLanceState(s_Practices[playerid][E_PRACTICE_LOWERED],crossingTick - s_Practices[playerid][E_PRACTICE_LOWER_TICK]);
        new KEY:keys, updown, leftright;
        GetPlayerKeys(playerid,keys,updown,leftright);
        new bool:isWalking = (keys & KEY_WALK) != KEY:0 || updown != KEY_UP;
        new quality = Events_JudgeQuintain(pose,Mount_IsGalloping(playerid),isWalking,laneError,s_Practices[playerid][E_PRACTICE_HELM]);
        s_Practices[playerid][E_PRACTICE_JUDGED] = true;
        s_QuintainSpinUntil = now + 2000;
        if (quality > 0)
        {
            Mount_SetLance(playerid,E_LANCE_BROKEN);
            Gui_Notify(playerid,quality == 2 ? ("A clean hit! The quintain spins and your lance breaks.") : ("A weak hit. The quintain turns, but the lance wasn't steady at a gallop."));
        }
        else if (isWalking)
        {
            Mount_Throw(playerid,"The sandbag knocks you from the saddle. Gallop with a steady lance on your next run.");
        }
        else
        {
            Gui_Notify(playerid,"You missed. Keep the lance steady and aim at the shield for an easier hit.");
        }
    }
    s_Practices[playerid][E_PRACTICE_LAST_X] = frameX;
    s_Practices[playerid][E_PRACTICE_LAST_Y] = frameY;
    s_Practices[playerid][E_PRACTICE_LAST_TICK] = now;
}

forward bool:Events_PracticeContext(playerid);
public bool:Events_PracticeContext(playerid)
{
    return Events_IsPractising(playerid);
}

forward bool:Events_PracticeGateContext(playerid);
public bool:Events_PracticeGateContext(playerid)
{
    return Events_IsAtPracticeGate(playerid) && !Infobox_IsPromptBlocked(playerid,s_Practices[playerid][E_PRACTICE_BOX]);
}

forward Events_PracticeTick();
public Events_PracticeTick()
{
    if (s_QuintainPlaced && s_QuintainSpinUntil != 0)
    {
        new now = GetTickCount(), Float:rotation = Util_NormalizeAngle(Events_ListsFrameAngle() + 90.0);
        if (s_QuintainSpinUntil > now)
        {
            rotation += float(2000 - (s_QuintainSpinUntil - now)) * 360.0 / 2000.0;
        }
        else
        {
            s_QuintainSpinUntil = 0;
        }
        SetDynamicObjectRot(s_QuintainArm,0.0,0.0,rotation);
    }
    foreach (new playerid : Player)
    {
        if (Events_IsPractising(playerid))
        {
            if (Gui_IsBusy(playerid) && s_Practices[playerid][E_PRACTICE_BOX] > 0)
            {
                Infobox_Hide(playerid,s_Practices[playerid][E_PRACTICE_BOX]);
                s_Practices[playerid][E_PRACTICE_BOX] = 0;
            }
            Events_UpdatePractice(playerid);
            if (Events_IsPractising(playerid) && !Gui_IsBusy(playerid) && (s_Practices[playerid][E_PRACTICE_BOX] <= 0 || !Infobox_IsShown(playerid,s_Practices[playerid][E_PRACTICE_BOX])))
            {
                Events_ShowPracticeBox(playerid,Mount_GetLance(playerid));
            }
        }
        else if (Events_IsAtPracticeGate(playerid) && !Gui_IsBusy(playerid))
        {
            if (s_Practices[playerid][E_PRACTICE_BOX] <= 0 || !Infobox_IsShown(playerid,s_Practices[playerid][E_PRACTICE_BOX]))
            {
                s_Practices[playerid][E_PRACTICE_BOX] = Infobox_ShowPrompt(playerid,s_Practices[playerid][E_PRACTICE_BOX],"The quintain","Press ~y~Y~w~ to practise the joust.~n~Your horse keeps to the lane. ~y~F~w~ leaves practice.",2,true);
            }
        }
        else if (s_Practices[playerid][E_PRACTICE_BOX] > 0)
        {
            Infobox_Hide(playerid,s_Practices[playerid][E_PRACTICE_BOX]);
            s_Practices[playerid][E_PRACTICE_BOX] = 0;
        }
    }
    return 1;
}

#include <pp-hooks>

hook OnPlayerKeyStateChange(playerid,KEY:newkeys,KEY:oldkeys)
{
    if (Gui_IsBusy(playerid) || !Session_IsPlaying(playerid))
    {
        return;
    }
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_SCENE))
    {
        if (Events_IsPractising(playerid))
        {
            if (!s_Practices[playerid][E_PRACTICE_LOWERED] && !s_Practices[playerid][E_PRACTICE_JUDGED])
            {
                s_Practices[playerid][E_PRACTICE_LOWERED] = true;
                s_Practices[playerid][E_PRACTICE_LOWER_TICK] = GetTickCount();
                Mount_SetLance(playerid,E_LANCE_LOWERING);
                s_Practices[playerid][E_PRACTICE_POSE] = E_LANCE_LOWERING;
                Events_ShowPracticeBox(playerid,E_LANCE_LOWERING);
            }
        }
        else if (Events_IsAtPracticeGate(playerid) && !Keys_IsBusy(playerid,KEY_YES,KEYS_PRIO_MENU) && !Infobox_IsPromptBlocked(playerid,s_Practices[playerid][E_PRACTICE_BOX]))
        {
            Events_StartPractice(playerid);
        }
    }
    if ((newkeys & KEY_CTRL_BACK) && !(oldkeys & KEY_CTRL_BACK) && Events_IsPractising(playerid) && !s_Practices[playerid][E_PRACTICE_JUDGED] && !Keys_IsBusy(playerid,KEY_CTRL_BACK,KEYS_PRIO_SCENE))
    {
        s_Practices[playerid][E_PRACTICE_HELM] = !s_Practices[playerid][E_PRACTICE_HELM];
        Mount_SetLanceAim(playerid,s_Practices[playerid][E_PRACTICE_HELM]);
        Events_ShowPracticeBox(playerid,Mount_GetLance(playerid));
    }
}

hook OnPlayerUpdate(playerid)
{
    Events_UpdatePractice(playerid);
}

hook Mount_OnDismounted(playerid,horseid)
{
    #pragma unused horseid
    Events_StopPractice(playerid);
}

hook OnPlayerConnect(playerid)
{
    for (new i = 0; i < sizeof(s_Practices[]); i++)
    {
        s_Practices[playerid][i] = 0;
    }
}

hook OnPlayerDisconnect(playerid,reason)
{
    #pragma unused reason
    if (s_PracticeRider == playerid)
    {
        s_PracticeRider = INVALID_PLAYER_ID;
    }
    s_Practices[playerid][E_PRACTICE_ACTIVE] = false;
    s_Practices[playerid][E_PRACTICE_BOX] = 0;
}
