#define SERVER_EVENTS_POLL_MS (5000)
#define SERVER_EVENTS_BATCH (64)
#define SERVER_EVENTS_TYPE_MAX (32)
#define SERVER_EVENTS_PAYLOAD_MAX (512)

new bool:g_ServerEventsPolling = false;

static s_ServerEventIds[SERVER_EVENTS_BATCH];
static s_ServerEventAccounts[SERVER_EVENTS_BATCH];
static s_ServerEventTypes[SERVER_EVENTS_BATCH][SERVER_EVENTS_TYPE_MAX];
static s_ServerEventPayloads[SERVER_EVENTS_BATCH][SERVER_EVENTS_PAYLOAD_MAX];

forward ServerEvent_OnReceived(eventid, const type[], const payload[], accountid);

public ServerEvent_OnReceived(eventid, const type[], const payload[], accountid)
{
	return 1;
}

forward ServerEvents_PollTick();

public ServerEvents_PollTick()
{
	yield 1;

	if (!IsDatabaseReady() || g_ServerEventsPolling)
	{
		return;
	}

	g_ServerEventsPolling = true;

	await mysql_aquery_s(g_Mysql, str_format("SELECT id, account_id, type, payload FROM server_events WHERE delivered_at IS NULL ORDER BY id LIMIT %d", SERVER_EVENTS_BATCH));

	if (mysql_errno(g_Mysql) != 0)
	{
		g_ServerEventsPolling = false;
		return;
	}

	new rows = cache_num_rows(), count = 0;
	for (new r = 0; r < rows && count < SERVER_EVENTS_BATCH; r++)
	{
		cache_get_value_name_int(r, "id", s_ServerEventIds[count]);
		cache_get_value_name_int(r, "account_id", s_ServerEventAccounts[count]);
		cache_get_value_name(r, "type", s_ServerEventTypes[count], SERVER_EVENTS_TYPE_MAX);
		cache_get_value_name(r, "payload", s_ServerEventPayloads[count], SERVER_EVENTS_PAYLOAD_MAX);
		count++;
	}

	for (new k = 0; k < count; k++)
	{
		await mysql_aquery_s(g_Mysql, str_format("UPDATE server_events SET delivered_at = NOW() WHERE id = %d", s_ServerEventIds[k]));
		pawn_call_public("ServerEvent_OnReceived", "dssd", s_ServerEventIds[k], s_ServerEventTypes[k], s_ServerEventPayloads[k], s_ServerEventAccounts[k]);
	}

	g_ServerEventsPolling = false;
}

#include <pp-hooks>

hook OnGameModeInit()
{
	mysql_tquery(
		g_Mysql,
		"CREATE TABLE IF NOT EXISTS server_events (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, account_id INT UNSIGNED NULL, type VARCHAR(32) NOT NULL, payload JSON NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, delivered_at DATETIME NULL, PRIMARY KEY (id), KEY idx_undelivered (delivered_at, account_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
	);
	SetTimer("ServerEvents_PollTick", SERVER_EVENTS_POLL_MS, true);
}
