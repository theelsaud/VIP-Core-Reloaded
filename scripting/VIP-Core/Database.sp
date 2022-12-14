
#define CHARSET "utf8mb4"
#define COLLATION "utf8mb4_unicode_ci"

#define TABLE_USERS "vip_users"
#define TABLE_GROUPS "vip_groups"
#define TABLE_FEATURES "vip_features"
#define TABLE_STORAGE "vip_storage"

// For SQLite
// https://stackoverflow.com/questions/2717590/sqlite-insert-on-duplicate-key-update-upsert

void LoadDatabase()
{
	// Проверка на секцию в databases.cfg
	if(SQL_CheckConfig("vip_core"))
	{
		Database.Connect(OnConnect, "vip_core");
	}
	else
	{
		// Теперь мы можем сразу вызвать готовность VIP, так как база не обязательна...
		CallForward_OnVIPLoaded();
	}
}

bool Check_DatabaseConnection(char[] sFunction, const char[] sError, bool bFailState = false)
{
	if(sError[0])
	{
		if(bFailState) SetFailState("%s: %s", sFunction , sError);

		LogMessage("%s: %s", sFunction , sError);
		return true;
	}

	return false;
}



void OnConnect(Database db, const char[] error, any data)
{
	if(error[0])
	{
		//LogError("DB Error: %s", error);
		SetFailState("DB Error: %s", error);
		return;
	}

	g_eServerData.DB = db;
	//DBDriver driver = SQL_ReadDriver(db);
	Handle driver = SQL_ReadDriver(db);

	char sDriverName[64];
	//driver.GetProduct(sDriverName, sizeof(sDriverName));

	//driver.GetIdentifier(sDriverName, sizeof(sDriverName));

	//SM 1.10 FIX
	SQL_GetDriverIdent(driver, sDriverName, sizeof(sDriverName));

	if(error[0])
	{
		LogError("Driver: %s Error: %s", sDriverName, error);
		//SetFailState();
		return;
	}

	if(!strcmp(sDriverName, "mysql"))
	{
		g_eServerData.DB_Type = DB_MySQL;
	}

	if(!strcmp(sDriverName, "sqlite"))
	{
		g_eServerData.DB_Type = DB_SQLite;
	}

	if(!strcmp(sDriverName, "pgsql"))
	{
		// TODO - PostgreSQL
		g_eServerData.DB_Type = DB_Postgre;
	}

	DB_CreateTables();
}

void DB_CreateTables()
{
	// TODO Transaction

	if(g_eServerData.CoreIsReady)
	{
		LoadPlayersData();
		return;
	}

	Transaction hTxn = new Transaction();
	
	hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `"... TABLE_USERS ..."` (\
					`account_id` INT NOT NULL, \
					`name` VARCHAR(64) NOT NULL default 'unknown' COLLATE '" ... COLLATION ... "', \
					`sid` INT UNSIGNED NOT NULL, \
					`lastvisit` INT UNSIGNED NOT NULL default 0, \
					CONSTRAINT pk_UserID PRIMARY KEY (`account_id`, `sid`) \
					) DEFAULT CHARSET=" ... CHARSET ... ";");

	hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `"... TABLE_GROUPS ..."` (\
					`account_id` INT NOT NULL, \
					`sid` INT UNSIGNED NOT NULL, \
					`group` VARCHAR(64) NOT NULL, \
					`added` INT UNSIGNED NOT NULL default 0, \
					`expires` INT UNSIGNED NOT NULL default 0, \
					CONSTRAINT pk_GroupID PRIMARY KEY (`account_id`, `sid`, `group`), \
					CONSTRAINT `vip_users_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `"...TABLE_USERS..."` (`account_id`) \
					) DEFAULT CHARSET=" ... CHARSET ... ";");

	hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `"... TABLE_STORAGE ..."` (\
					`account_id` INT NOT NULL, \
					`sid` INT UNSIGNED NOT NULL, \
					`key` VARCHAR(64) NOT NULL, \
					`value` VARCHAR(64) NOT NULL, \
					`updated` VARCHAR(64) NOT NULL default 0, \
					CONSTRAINT pk_StorageID PRIMARY KEY (`account_id`, `sid`, `key`), \
					CONSTRAINT `vip_users_ibfk_2` FOREIGN KEY (`account_id`) REFERENCES `"...TABLE_USERS..."` (`account_id`) \
					) DEFAULT CHARSET=" ... CHARSET ... ";");

	hTxn.AddQuery("CREATE TABLE IF NOT EXISTS `"... TABLE_FEATURES ..."` (\
					`account_id` INT NOT NULL, \
					`sid` INT UNSIGNED NOT NULL, \
					`key` VARCHAR(64) NOT NULL, \
					`value` VARCHAR(64) NOT NULL, \
					`priority` VARCHAR(64) NOT NULL default 0, \
					`updated` VARCHAR(64) NOT NULL default 0, \
					CONSTRAINT pk_FeatureID PRIMARY KEY (`account_id`, `sid`, `key`), \
					CONSTRAINT `vip_users_ibfk_3` FOREIGN KEY (`account_id`) REFERENCES `"...TABLE_USERS..."` (`account_id`) \
					) DEFAULT CHARSET=" ... CHARSET ... ";");

	g_eServerData.DB.Execute(hTxn, SQL_Callback_TableCreate, SQL_TxnCallback_Failure, -1);
}


public void SQL_Callback_TableCreate(Database hDatabase, any Data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	// Все таблицы созданы...
	if(iNumQueries >= 4)
	{
		CallForward_OnVIPLoaded();
		LoadPlayersData();
	}
}

public void SQL_TxnCallback_Failure(Database hDatabase, any Data, int iNumQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	if(Data == -1)
	{
		char sBuffer[256];
		FormatEx(sBuffer, sizeof(sBuffer), "SQL_TxnCallback_Failure [%i]", iFailIndex);
		Check_DatabaseConnection(sBuffer, szError, true);
	}
	else
	{
		g_ePlayerData[Data].Status = Status_Error;
	}
	

	// if(iNumQueries != 0)
	// {

	// }
}

void DB_UpdatePlayerData(int iClient)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `"...TABLE_USERS..."` (`account_id`,`name`,`sid`,`lastvisit`) VALUES (%i,'%N',%i,%i) ON DUPLICATE KEY UPDATE `lastvisit` = VALUES(`lastvisit`);", g_ePlayerData[iClient].AccountID, iClient, g_eServerData.ServerID, GetTime());
	DebugMsg(DBG_SQL, sQuery);

	g_eServerData.DB.Query(SQL_EmptyCallBack, sQuery);
}

void DB_AddCustomFeature(int iClient, char[] sKey, char[] sValue, int iTarget = 0)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `"...TABLE_FEATURES..."` (`account_id`,`sid`,`key`,`value`,`updated`) VALUES (%i, %i,'%s','%s',%i) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `updated` = VALUES(`updated`);", g_ePlayerData[iClient].AccountID, g_eServerData.ServerID, sKey, sValue, GetTime());
	DebugMsg(DBG_SQL, sQuery);

	g_eServerData.DB.Query(SQL_EmptyCallBack, sQuery, iTarget);
}

void DB_RemoveCustomFeature(int iClient, char[] sKey, int iTarget = 0)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `"...TABLE_FEATURES..."` WHERE `account_id` = %i AND `sid` = %i AND `key` = '%s';", g_ePlayerData[iClient].AccountID, g_eServerData.ServerID, sKey);
	DebugMsg(DBG_SQL, sQuery);

	g_eServerData.DB.Query(SQL_EmptyCallBack, sQuery, iTarget);
}

void DB_LoadPlayerData(int iClient)
{
	if(g_eServerData.DB_Type == DB_None) 
	{
		g_ePlayerData[iClient].Status = Status_Loaded;
		CallForward_OnClientLoaded(iClient);
		return;
	}

	g_ePlayerData[iClient].ClearData();

	g_ePlayerData[iClient].Status = Status_Loading;

	Transaction hTxn = new Transaction();

	char sQuery[1024], sServerID[128];
	GetServerIDSelector(sServerID, sizeof(sServerID));
	
	FormatEx(sQuery, sizeof(sQuery), "SELECT `group`, `expires` FROM `" ... TABLE_GROUPS ... "` WHERE `account_id` = %i AND (`expires` >= %i OR `expires` = 0) AND %s;", g_ePlayerData[iClient].AccountID, GetTime(), sServerID);
	DebugMsg(DBG_SQL, sQuery);
	hTxn.AddQuery(sQuery);

	FormatEx(sQuery, sizeof(sQuery), "SELECT `key`, `value` FROM `" ... TABLE_FEATURES ... "` WHERE `account_id` = %i AND %s;", g_ePlayerData[iClient].AccountID, sServerID);
	DebugMsg(DBG_SQL, sQuery);
	hTxn.AddQuery(sQuery);

	GetStorageIDSelector(sServerID, sizeof(sServerID));

	FormatEx(sQuery, sizeof(sQuery), "SELECT `key`, `value` FROM `" ... TABLE_STORAGE ... "` WHERE `account_id` = %i AND %s;", g_ePlayerData[iClient].AccountID, sServerID);
	DebugMsg(DBG_SQL, sQuery);
	hTxn.AddQuery(sQuery);

	g_eServerData.DB.Execute(hTxn, SQL_LoadPlayerData, SQL_TxnCallback_Failure, iClient);
}

void DB_AddPlayerGroup(int iClient, char[] sGroup, int iExpire, int iTarget = 0)
{
	// switch(g_eServerData.DB_Type)
	// {
	// 	case DB_Postgre:
	// 	{

	// 	}
	// }
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `" ... TABLE_GROUPS ... "` (`account_id`, `sid`, `group`, `added`, `expires`) VALUES (%i, %i, '%s', %i, %i) ON DUPLICATE KEY UPDATE `expires` = %i;", g_ePlayerData[iClient].AccountID, g_eServerData.ServerID, sGroup, GetTime(), iExpire, iExpire);
	DebugMsg(DBG_SQL, sQuery);
	
	g_eServerData.DB.Query(SQL_CallbackAddPlayerGroup, sQuery, iTarget);
}

void DB_SaveStorage(int iClient, char[] sKey, char[] sValue)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `" ... TABLE_STORAGE ... "` (`account_id`, `sid`, `key`, `value`, `updated`) VALUES (%i, %i, '%s', '%s', %i) ON DUPLICATE KEY UPDATE `value` = '%s', `updated` = %i;", g_ePlayerData[iClient].AccountID, g_eServerData.ServerID, sKey, sValue, GetTime(), sValue, GetTime());
	DebugMsg(DBG_SQL, sQuery);
	
	g_eServerData.DB.Query(SQL_CallbackAddPlayerGroup, sQuery);
}

void DB_RemovePlayerGroup(int iClient, char[] sGroup, int iTarget = 0)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `" ... TABLE_GROUPS ... "` WHERE `account_id` = %i AND `sid` = %i AND `group` = '%s';", g_ePlayerData[iClient].AccountID, g_eServerData.ServerID, sGroup);
	DebugMsg(DBG_SQL, sQuery);
	
	g_eServerData.DB.Query(SQL_CallbackAddPlayerGroup, sQuery, iTarget);
}

// void DB_AddUserTransaction(Transaction hTh, int iClient)
// {

// }

// void DB_GetVIPUsers(int iTarget)
// {
// 	char sQuery[1024];
// 	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM `"... TABLE_USERS ... "` WHERE (select count(*) from "...TABLE_FEATURES..." where account_id = "... TABLE_USERS ...".account_id) + (select count(*) from "... TABLE_GROUPS ..." where account_id = "... TABLE_USERS ...".account_id) > 0 ORDER BY name;");

// 	DebugMsg(DBG_SQL, sQuery);

// 	g_eServerData.DB.Query(SQL_LoadVIPPlayers, sQuery, iTarget);
// }

// void SQL_LoadVIPPlayers(Database hOwner, DBResultSet hResult, const char[] szError, any data)
// {
	
// }

void SQL_LoadPlayerData(Database hDatabase, any data, int iNumQueries, DBResultSet[] results, any[] QueryData)
{
	char sGroup[VIP_GROUPNAME_LENGTH], sBuffer[256];

	while(results[0].FetchRow())
	{
		results[0].FetchString(0, sGroup, sizeof(sGroup));
		int iTime = results[0].FetchInt(1);

		DebugMsg(DBG_INFO, "GROUPS: %s - %i", sGroup, iTime);
	
		g_ePlayerData[data].AddGroup(sGroup, iTime);
	}

	while(results[1].FetchRow())
	{
		results[1].FetchString(0, sGroup, sizeof(sGroup));
		results[1].FetchString(1, sBuffer, sizeof(sBuffer));

		DebugMsg(DBG_INFO, "CUSTOM FEATURE: %s - %s", sGroup, sBuffer);
	
		g_ePlayerData[data].AddCustomFeature(sGroup, sBuffer);
	}

	while(results[2].FetchRow())
	{
		results[2].FetchString(0, sGroup, sizeof(sGroup));
		results[2].FetchString(1, sBuffer, sizeof(sBuffer));

		DebugMsg(DBG_INFO, "STORAGE: %s - %s", sGroup, sBuffer);
	
		g_ePlayerData[data].SaveStorage(sGroup, sBuffer);
	}

	g_ePlayerData[data].RebuildFeatureList();
	g_ePlayerData[data].Status = Status_Loaded;

	CallForward_OnClientLoaded(data);
	// CallForward_OnVipLoaded(data);
}

void SQL_EmptyCallBack(Database hOwner, DBResultSet hResult, const char[] szError, any data)
{
	return;
}

void SQL_CallbackAddPlayerGroup(Database hOwner, DBResultSet hResult, const char[] szError, any data)
{
	if(szError[0])
	{
		DebugMsg(DBG_INFO, szError);
		PrintToChat(data, "[VIP] Ошибка добавления группы в БД");
		return;
	}

	if(data > 0)
	{
		PrintToChat(data, "[VIP] Группа %s успешно добавлена в БД...", g_ePlayerData[data].CurrentGroup);
	}

	return;
}

void GetServerIDSelector(char[] sBuffer, int iMaxLen)
{
	FormatEx(sBuffer, iMaxLen, "(`sid` = %i OR `sid` = 0)", g_eServerData.ServerID);
}

void GetStorageIDSelector(char[] sBuffer, int iMaxLen)
{
	FormatEx(sBuffer, iMaxLen, "(`sid` = %i OR `sid` = 0)", g_eServerData.StorageID);
}