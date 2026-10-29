#define NOTICE_SEED_BOARDS (3)
#define LETTERS_SEED_POSTS (2)

enum E_NOTICE_BOARD_DEF
{
	E_NOTICE_BOARD_DEF_NAME[24],
	Float:E_NOTICE_BOARD_DEF_POS[4],
}

new const g_NoticeBoardDefs[3][E_NOTICE_BOARD_DEF] = {
	{"Talmberg market", {1011.698, -3401.790, 65.734, 290.0}},
	{"the church village", {1009.698, -3153.290, 33.895, 290.0}},
	{"the guardhouse", {716.626, -3184.003, 22.703, 2.0}}
};

enum E_LETTERS_POST_DEF
{
	E_LETTERS_POST_DEF_NAME[24],
	Float:E_LETTERS_POST_DEF_TABLE[4],
	Float:E_LETTERS_POST_DEF_COURIER[4],
}

new const g_LettersPostDefs[2][E_LETTERS_POST_DEF] = {
	{"Talmberg", {1001.091, -3407.252, 66.305, 122.4}, {1000.331, -3407.735, 66.457, 302.4}},
	{"the church village", {1005.547, -3161.979, 32.266, 184.5}, {1005.617, -3162.876, 32.254, 4.5}}
};
