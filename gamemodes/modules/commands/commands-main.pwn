#include <pp-hooks>

hook OnGameModeInit()
{
	Command_Describe("help","Answers to common questions, and every command you can use. /help and a word searches both.","","Help");
	Command_Describe("searchcmd","Search the help and the commands, like /searchcmd whisper.","","Help");
}
