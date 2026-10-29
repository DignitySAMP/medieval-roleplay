#pragma dynamic 2100000

#include "bootstrap/entry.pwn"

main()
{}

public OnGameModeInit()
{
    print("[mrp] booting");

    DisableInteriorEnterExits();
    EnableStuntBonusForAll(false);
    ManualVehicleEngineAndLights();

    Boot_Run();
    return 1;
}

forward OnServerFinishLoading();
public OnServerFinishLoading()
{
    Log_Info("boot", "Medieval Roleplay %s ready - %d slots", MRP_VERSION, MAX_PLAYERS);
    return 1;
}

forward UselessFunction();
public UselessFunction()
{
    return true;
}
