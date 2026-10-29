#define CRIER_KIND_FAITH "faith"

stock Crier_Announce(const kind[],const title[],const body[])
{
	mysql_tquery_s(g_Mysql,str_format("INSERT INTO realm_news (kind, title, body) VALUES ('%e', '%e', '%e')",kind,title,body));
	Log_Info("crier","%s: %s",title,body);
	pawn_call_public("Crier_OnNews","sss",kind,title,body);
}

forward Crier_OnNews(const kind[],const title[],const body[]);

public Crier_OnNews(const kind[],const title[],const body[])
{
	return 1;
}
