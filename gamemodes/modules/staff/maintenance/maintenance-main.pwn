#include <pp-hooks>

hook OnGameModeInit()
{
    fremove("maintenance.done");
    Command_Describe("maintenance","Management: /maintenance <minutes> [reason], or /maintenance cancel.");
    SetTimer("Maintenance_Tick",1000,true);
}
