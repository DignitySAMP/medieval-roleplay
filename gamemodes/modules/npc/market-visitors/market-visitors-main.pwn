#include <pp-hooks>

hook Market_OnChanged(open)
{
    #pragma unused open
    MarketVisitors_Place();
}

hook OnGameModeExit()
{
    MarketVisitors_Clear();
}

Timer_Declare(MarketVisitors_Tick)
{
    if (Market_IsOpen())
    {
        MarketVisitors_Place();
    }
    return 1;
}

hook OnGameModeInit()
{
    SetTimer("MarketVisitors_Tick",MARKET_VISITORS_TICK_MS,true);
}
