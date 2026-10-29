#include <pp-hooks>

hook OnGameModeInit()
{
	Help_Register(HELP_SECTION_ROLEPLAY,"Why do the church bells ring?","~w~The bells ring the hours of the day: ~y~Prime~w~ at six, when the village rises and the doors open; ~y~Terce~w~ at nine; ~y~Sext~w~ at eleven, dinner; ~y~Nones~w~ at one; ~y~Vespers~w~ at six, supper; ~y~Compline~w~ at eight, when the doors are barred.~n~~n~In winter the day is shorter: Prime at eight, Sext at noon, Vespers at four. The hour shows beside the date at the top of your screen.");
	Command_Describe("hours","Staff: show the church hour and fire the current keyframe again.");
}

hook OnServerFinishLoading()
{
	Routine_Refresh();
}
