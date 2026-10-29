#define STAFF_ROLE_LOREMASTER (0)
#define STAFF_ROLE_FACTION (1)
#define STAFF_ROLE_COUNT (2)
#define STAFF_TICKET_LEN (144)
#define STAFF_TICKETS_SHOWN (10)
#define STAFF_LOG_SHOWN (14)
#define STAFF_WARNINGS_SHOWN (10)
#define STAFF_JAIL_WORLD (9990)
#define STAFF_JAIL_TICK_MS (5000)
#define STAFF_REVIEW_HOURS (168)
#define STAFF_PANEL_WIDTH (320.0)
#define STAFF_CHAT_COLOUR (0xE0B07AFF)
#define STAFF_NOTE_COLOUR (0xD8CCB2FF)
#define STAFF_KICK_DELAY_MS (300)
#define STAFF_SHUTDOWN_MAX (30)

new const g_StaffRoleNames[STAFF_ROLE_COUNT][16] = {"loremaster", "faction team"};
new const g_StaffLevelNames[ADMIN_LEVEL_MANAGER + 1][12] = {"player", "assistant", "moderator", "admin", "management"};

enum _:E_STAFF_TICKET_STATES
{
	STAFF_TICKET_OPEN,
	STAFF_TICKET_CLAIMED,
	STAFF_TICKET_CLOSED,
}

new const g_StaffTicketStates[3][8] = {"open", "claimed", "closed"};
