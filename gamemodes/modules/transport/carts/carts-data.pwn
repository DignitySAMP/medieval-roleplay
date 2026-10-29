#define CARTS_MAX (64)
#define CARTS_REACH (2.8)
#define CARTS_SHAFT_REACH (3.2)
#define CARTS_TICK_MS (50)
#define CARTS_HITCH (2.5)
#define CARTS_PULL (1.75)
#define CARTS_RUN_SPEED (0.12)
#define CARTS_LEASH (4.0)
#define CARTS_SWING (14.0)
#define CARTS_STILL (0.02)
#define CARTS_SAVE_MS (5000)
#define CARTS_STREAM (120.0)
#define CARTS_LOAD_SHOW (4)
#define CARTS_SEATS_MAX (7)
#define CARTS_POSE_RETRY_MS (150)
#define CARTS_POSE_RESYNC_MS (400)
#define CARTS_POSE_SETTLE_MS (300)
#define CARTS_STAND_NUDGE_MS (400)
#define CARTS_STAND_NUDGE (0.05)
#define CARTS_SEAT_LIFT_CHAIR (0.55)
#define CARTS_SEAT_LIFT_GROUND (0.96)
#define CARTS_SEAT_REACH (3.5)

enum E_CART_KIND
{
	CART_KIND_HANDCART,
	CART_KIND_CART,
	CART_KIND_WAGON,
	CART_KIND_COACH,
	CART_KIND_PUBLIC_COACH,
	CART_KIND_PRISONER,
	CART_KIND_COUNT,
}

enum E_CART_DEF
{
	E_CART_DEF_NAME[20],
	E_CART_DEF_BODY,
	E_CART_DEF_WHEEL,
	E_CART_DEF_WHEELS,
	Float:E_CART_DEF_WHEEL_POS[12],
	Float:E_CART_DEF_RADIUS,
	Float:E_CART_DEF_BED[3],
	E_CART_DEF_SLOTS,
	E_CART_DEF_ITEM,
	bool:E_CART_DEF_HITCHED,
}

new const g_CartDefs[CART_KIND_COUNT][E_CART_DEF] = {
	{"handcart", MODEL_CARTS_HANDCART, MODEL_CARTS_HANDCART_WHEEL, 2, {-0.43, 0.00, 0.30, 0.43, 0.00, 0.30, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}, 0.30, {0.00, 0.05, 0.440}, 8, ITEM_HANDCART, false},
	{"horse cart", MODEL_CARTS_CART, MODEL_CARTS_CART_WHEEL, 2, {-0.70, 0.00, 0.55, 0.70, 0.00, 0.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}, 0.55, {0.00, 0.03, 0.725}, 20, ITEM_HORSE_CART, true},
	{"covered wagon", MODEL_CARTS_WAGON, MODEL_CARTS_WAGON_WHEEL, 4, {-0.86, -0.95, 0.50, 0.86, -0.95, 0.50, -0.86, 0.95, 0.50, 0.86, 0.95, 0.50}, 0.50, {0.00, 0.07, 0.980}, 32, -1, true},
	{"coach", MODEL_CARTS_COACH, MODEL_CARTS_COACH_WHEEL, 4, {-0.86, -0.85, 0.56, 0.86, -0.85, 0.56, -0.86, 0.85, 0.56, 0.86, 0.85, 0.56}, 0.56, {0.0, 0.0, 0.0}, 4, -1, true},
	{"village coach", MODEL_CARTS_PUBLIC_COACH, MODEL_CARTS_COACH_WHEEL, 4, {-0.86, -0.85, 0.56, 0.86, -0.85, 0.56, -0.86, 0.85, 0.56, 0.86, 0.85, 0.56}, 0.56, {0.0, 0.0, 0.0}, 4, -1, true},
	{"prisoner cart", MODEL_CARTS_PRISONER_CART, MODEL_CARTS_CART_WHEEL, 2, {-0.70, 0.00, 0.55, 0.70, 0.00, 0.55, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}, 0.55, {0.00, 0.25, 0.725}, 4, -1, true}
};

new const g_CartSeatCount[CART_KIND_COUNT] = {0, 3, 4, 4, 6, 4};
new const bool:g_CartSeatPrisoner[CART_KIND_COUNT] = {false, false, false, false, false, true};
new const Float:g_CartSeats[CART_KIND_COUNT][CARTS_SEATS_MAX * 4] = {
	{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
	{0.00, -0.62, 1.120, 180.0, -0.30, 0.55, 0.725, 180.0, 0.30, 0.55, 0.725, 180.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
	{-0.25, -1.20, 1.405, 180.0, 0.25, -1.20, 1.405, 180.0, -0.35, 0.60, 0.955, 180.0, 0.35, 0.60, 0.955, 180.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
	{-0.30, 0.90, 0.820, 180.0, 0.30, 0.90, 0.820, 180.0, -0.30, -0.70, 0.820, 0.0, 0.30, -0.70, 0.820, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0},
	{-0.46, -0.50, 1.270, 270.0, -0.46, 0.20, 1.270, 270.0, -0.46, 0.90, 1.270, 270.0, 0.46, -0.50, 1.270, 90.0, 0.46, 0.20, 1.270, 90.0, 0.46, 0.90, 1.270, 90.0, 0.0, 0.0, 0.0, 0.0},
	{-0.32, -0.15, 0.725, 270.0, 0.32, -0.15, 0.725, 90.0, -0.32, 0.50, 0.725, 270.0, 0.32, 0.50, 0.725, 90.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
};

new const Float:g_CartPull[CART_KIND_COUNT] = {1.0, 0.85, 0.75, 0.8, 0.8, 0.85};
new const Float:g_CartBench[CART_KIND_COUNT][3] = {
	{0.0, 0.0, 0.0}, {0.00, -0.62, 1.120}, {-0.25, -1.20, 1.405}, {0.00, -1.50, 1.575}, {0.00, -1.50, 1.575}, {0.00, -0.78, 1.120}
};
