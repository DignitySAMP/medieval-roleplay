#include <pp-hooks>

hook OnGameModeInit()
{
	Market_Place();
    Help_Register(HELP_SECTION_WORK,"When does Talmberg market open?","~w~The market opens on Saturdays from 09:00 until 16:00 by the county calendar. Traders bring their goods and villagers gather in the square. Between market days the stalls stand empty. The seasonal fair also opens the market.",true);
}

hook OnServerFinishLoading()
{
    Market_Refresh();
}

hook Calendar_OnHour(hour)
{
    #pragma unused hour
    Market_Refresh();
}

hook Calendar_OnSet()
{
    Market_Refresh();
}
