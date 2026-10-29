#define CGEN_MEMORY (50000)

#define MIXED_SPELLINGS
#include <open.mp>

#define SERVER_PLAYER_SLOTS (100)
#define SERVER_NPC_SLOTS (50)

#undef MAX_PLAYERS
#define MAX_PLAYERS (SERVER_PLAYER_SLOTS + SERVER_NPC_SLOTS)

#define STREAMER_ENABLE_TAGS
#include <streamer>
#include <mapfix>

#include <crashdetect>

#define CUSTOM_TAG_TYPES DynamicObject,DynamicPickup,DynamicCP,DynamicRaceCP,DynamicMapIcon,DynamicText3D,DynamicArea,DynamicActor,Node
#define PP_SYNTAX
#define PP_MULTILINE_AWAIT
#define PP_ADDITIONAL_TAGS CUSTOM_TAG_TYPES
#define MYSQL_ASYNC_DEFAULT_PARALLEL true
#include <PawnPlus>

pawn_on_init[gm]
{
    pp_native_hook_recursive(false);
}

#include <a_mysql>
#include <pp-mysql>
#include <pp-hooks>
DEFINE_HOOK_REPLACEMENT__(Player, Pl)
DEFINE_HOOK_REPLACEMENT__(Vehicle, Veh)

#include <foreach>

#define STRLIB_RETURN_SIZE (256)
#include <strlib>

#include <sscanf2>

#include <Pawn.RakNet>

#include <tdialogs>

forward OnPlayerCommandReceived(cmdid, playerid, cmdtext[]);

forward OnPlayerCommandPerformed(cmdid,playerid,cmdtext[],success);

#define CMD_DEFAULT_FLAG (4)
#define MAX_PUBLIC_FUNCTIONS (8192)
#include <smartcmd>

#include <samp_bcrypt>
#include <json>
#include <colour-manipulation>
#include <pawn-easing-functions>
#include <humanize>
#include <filemanager>
#define MAP_FILE_DIRECTORY "./scriptfiles/Maps/"
#include <samp-map-parser>
#include <colandreas>
#include <paths>
#include <pedestrians>
