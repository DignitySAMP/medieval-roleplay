#include <pp-hooks>

hook OnGameModeInit()
{
    Command_Describe("fps","Dev: toggle your FPS, ping and packet loss meter.");
    Command_Describe("fpscheck","Dev: tour the slow spots at a fixed hour (default noon, clear sky), turn round in 8 directions and log the median FPS over 12 seconds each; again to stop.");
}
