#include <pp-hooks>

hook OnGameModeInit()
{
    new answer[HELP_ANSWER_LEN];
    format(answer,sizeof(answer),"~w~Use ~y~/me <action>~w~ for what your character does, such as /me brushes mud off his boots. Use ~y~/do <description>~w~ for something others can see. Both reach people within %d metres. Give other players time to answer before describing an outcome that involves them.",floatround(CHAT_RANGE_ACTION));
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I describe actions and scenes?",answer,true);
    format(answer,sizeof(answer),"~w~Type normally to speak to people nearby. Use ~y~/s <text>~w~ to shout within %d metres. Use ~y~/w <id or name> <text>~w~ to whisper to one player within %d metres. Others nearby see that you mutter, but don't read your whisper. Player ids appear beside their names.",floatround(CHAT_RANGE_SHOUT),floatround(CHAT_RANGE_WHISPER));
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I shout or whisper?",answer,false);
    format(answer,sizeof(answer),"~w~Use ~y~/b <text>~w~ for out-of-character chat within %d metres. Use ~y~/pm <id or name> <message>~w~ for a private out-of-character message to an online player. Use ~y~/re <message>~w~ to answer the last person who sent you a private message.",floatround(CHAT_RANGE_SAY));
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I talk out of character?",answer,false);
    format(answer,sizeof(answer),"~w~Use ~y~/doing <description>~w~ to put a short description under your nametag. It lasts %d minutes. Type ~y~/doing~w~ on its own to clear it early.",NAMETAG_DOING_MS / 60000);
    Help_Register(HELP_SECTION_ROLEPLAY,"How do I show what my character is doing?",answer,false);
	Help_Register(HELP_SECTION_ROLEPLAY,"How do people learn my name?","~w~Nobody knows your name until you tell them. Stand near someone and press ~y~H~w~ to introduce yourself. Until you do, they'll just see a stranger.~n~~n~Folk from other lands may speak a language you don't know. If they do, you'll see their words scrambled. Everyone understands ~y~Common~w~.");
	Help_Register(HELP_SECTION_ROLEPLAY,"How should I roleplay here?","~w~This is a fictional kingdom in the 1200s. Everyone here plays a person of that time.~n~~n~~y~Speak and act in period.~w~ Leave modern words, ideas and jokes out of character. ~y~Only know what your character knows.~w~ What you learn outside the game stays outside. ~y~Give others room to answer.~w~ Never force an outcome on another player. ~y~Your choices matter.~w~ Faith, standing, house and your name all count.~n~~n~Out-of-character talk goes in ~y~/b~w~. Keep it short. Use ~y~/me~w~ and ~y~/do~w~ to describe what you do and what others see.");
	Command_Describe("me","Act something out (20 m).","","Talking");
	Command_Describe("melow","Act something out quietly (5 m).","","Talking");
	Command_Describe("ame","An action over your head only, not in the chat.","","Talking");
	Command_Describe("my","A possessive action: Name's hands shake.","","Talking");
	Command_Describe("amy","Like /my, over your head only.","","Talking");
	Command_Describe("do","Describe something around you (20 m).","","Talking");
	Command_Describe("doing","A line under your name for 5 minutes. On its own, it clears it.","","Talking");
	Command_Describe("to","Speak to people by id, like /to 3,7 Good day.","","Talking");
	Command_Describe("lowto","Speak quietly to people by id (5 m).","","Talking");
	Command_Describe("lowerto","Speak very quietly to people by id (5 m).","","Talking");
	Command_Describe("s","Shout so people 40 m away hear you.","","Talking");
	Command_Describe("shout","Shout so people 40 m away hear you.","","Talking");
	Command_Describe("shoutto","Shout at people by id.","","Talking");
	Command_Describe("w","Whisper to one person within 3 m.","","Talking");
	Command_Describe("whisper","Whisper to one person within 3 m.","","Talking");
	Command_Describe("addwhisper","Add or remove someone in your whisper group.","","Talking");
	Command_Describe("gw","Whisper to everyone in your whisper group within 3 m.","","Talking");
	Command_Describe("groupwhisper","Whisper to everyone in your whisper group within 3 m.","","Talking");
	Command_Describe("b","Out of character, nearby (20 m).","","Out of character");
	Command_Describe("blow","Out of character, quietly (5 m).","","Out of character");
	Command_Describe("blower","Out of character, very quietly (5 m).","","Out of character");
	Command_Describe("pm","A private out-of-character message.","","Out of character");
	Command_Describe("re","Answer the last private message you got.","","Out of character");
	Command_Describe("dod","A private /do to one person, wherever they are.","","Talking");
	AnimPreload_Register("GANGS");
	Log_Info("chat","say %.0fm, shout %.0fm, whisper %.0fm",CHAT_RANGE_SAY,CHAT_RANGE_SHOUT,CHAT_RANGE_WHISPER);
}
