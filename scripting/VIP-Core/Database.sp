
#define CHARSET "utf8mb4"
#define COLLATION "utf8mb4_unicode_ci"

void LoadDatabase()
{
	// Проверка на секцию в databases.cfg
	if(SQL_CheckConfig("vip_core"))
	{


	}
	else
	{
		// Теперь мы можем сразу вызвать готовность VIP, так как база не обязательна...
		CallForward_OnVIPLoaded();
	}
}