
#define D_KEY_SIZE 32
#define D_VALUE_SIZE 256

// Structure...

enum ChatHookType
{
	ChatHook_None = 0,
	ChatHook_CustomFeature,
	ChatHook_GenerateNewGroup,
	ChatHook_SearchPlayer
}

enum DatabaseUsage
{
	DB_None = 0,
	DB_SQLite,
	DB_MySQL,
	DB_Postgre // TODO
}


enum struct Times
{
	char Phrase[64];
	int Time;
}
ArrayList g_hTimes;

enum struct ServerData
{
	int ServerID;

	EngineVersion Engine;

	DatabaseUsage DB_Type;
	Database DB;

	char GroupsConfigPath[PLATFORM_MAX_PATH];
	char LogsPath[PLATFORM_MAX_PATH];

	// VIP_IsLoaded
	bool CoreIsReady;

	void Init()
	{
		//BuildPath(Path_SM, this.GroupsConfigPath, sizeof(this.GroupsConfigPath), "%s/%s", CONFIG_MAIN_PATH, CONFIG_GROUPS_FILENAME);
		//BuildPath(Path_SM, this.LogsPath, sizeof(this.LogsPath), "logs/%s", LOGS_FILENAME);
	}
}
ServerData g_eServerData;

enum struct PlayerFeature
{
	char Key[D_KEY_SIZE];
	char Value[D_VALUE_SIZE];

	int CurrentPriority;
	bool bEnabled;
}

enum struct GroupInfo
{
	char Name[D_GROUPNAME_LENGTH];

	// List of Feature (PlayerFeature)
	ArrayList hFeatureList;

	// List of extend Groups...
	ArrayList hExtendList;

	void Init()
	{
		//if(this.hFeatureList) delete this.hFeatureList;
		//if(this.hExtendList) delete this.hExtendList;

		this.hFeatureList = new ArrayList(sizeof(PlayerFeature));
		this.hExtendList = new ArrayList(D_GROUPNAME_LENGTH);
	}

	void Clear()
	{
		this.Name[0] = EOS;
		this.hFeatureList.Clear();
		this.hExtendList.Clear();
	}

	void AddFeature(char[] sKey, char[] sValue, int iPriority = 0)
	{
		PlayerFeature hPFeature;
		strcopy(hPFeature.Key, sizeof(hPFeature.Key), sKey);
		strcopy(hPFeature.Value, sizeof(hPFeature.Value), sValue);

		this.hFeatureList.PushArray(hPFeature, sizeof(hPFeature));
	}

	void DelFeature(char[] sKey, char[] sValue)
	{
		
	}

	void AddExtend(char[] sKey)
	{
		this.hExtendList.PushString(sKey);
	}
}
ArrayList g_hGroups;

enum struct PlayerGroup
{
	char Name[D_GROUPNAME_LENGTH];
	int ExpireTime;
}

// API
enum struct Feature
{
	char Key[D_FEATURENAME_LENGTH];

	
	int ValType;
	// check VIP_FeatureType
	int Type;
	

	Function OnSelectCB;
	Function OnDisplayCB;
	Function OnDrawCB;

	Handle hPlugin;

	int ToggleState;

	bool bCookie;
}
ArrayList g_hFeatures;

enum StatusLoading
{
	Status_None,
	Status_Loading,
	Status_Loaded,
	Status_Error
}

/* Player Struct
*/
enum struct PlayerData
{
	int iClient;

	int UserID;
	int AccountID;

	// State
	StatusLoading Status;

	// State (Groups > 0)
	bool bVIP;

	// List of groups player... (check PlayerGroup)
	ArrayList hGroups;

	// ArrayList feature builded from groups (check PlayerFeature)
	ArrayList hFeatures;

	// Unique for player (check PlayerFeature)
	ArrayList hCustomFeatures;

	ChatHookType HookChat;
	// For ConfirmMenu...
	Function hCallBack;

	// AdminMenu
	int CurrentTarget;
	int CurrentGroup;
	int CurrentTime;
	char CurrentFeature[D_FEATURENAME_LENGTH];

	bool CheckGroup(char[] sGroup)
	{
		return this.GetGroupIDByName(sGroup) > -1;
	}

	void AddGroup(char sGroup[D_GROUPNAME_LENGTH], int iExpire = 0)
	{
		PlayerGroup hGroup;
		hGroup.Name = sGroup;
		hGroup.ExpireTime = iExpire;
		this.hGroups.PushArray(hGroup, sizeof(hGroup));

		this.bVIP = this.IsVIP();
		this.RebuildFeatureList();
	}

	void RemoveGroup(char[] sGroup)
	{
		int iIndex = GetGroupIDByName(sGroup);
		if(iIndex != -1) 
		{
			this.hGroups.Erase(iIndex);

			this.bVIP = this.IsVIP();
			this.RebuildFeatureList();
		}
	}

	int GetExpireTimeByGroupID(int iIndex)
	{
		PlayerGroup hGroup;
		this.hGroups.GetArray(iIndex, hGroup, sizeof(hGroup));

		return hGroup.ExpireTime;
	}

	int GetGroupIDByName(char[] sName)
	{
		int iLen = this.hGroups.Length;
		for(int i = 0; i < iLen; i++)
		{
			PlayerGroup hGroup;
			this.hGroups.GetArray(i, hGroup, sizeof(hGroup));

			if(!strcmp(hGroup.Name, sName)) return i;
		}

		return -1;
	}

	void EnableFeature(char[] sFeature)
	{
		int iIndex = this.GetFeatureIDByName(sFeature);

		if(iIndex != -1)
		{
			this.hFeatures.Set(iIndex, true, PlayerFeature::bEnabled);
		}
	}

	void DisableFeature(char[] sFeature)
	{
		int iIndex = this.GetFeatureIDByName(sFeature);

		if(iIndex != -1)
		{
			this.hFeatures.Set(iIndex, false, PlayerFeature::bEnabled);
		}
	}

	void AddFeature(char[] sKey, char[] sValue, int iPriority = 0)
	{
		PrintToServer("AddFeature - %s - %s | %i", sKey, sValue, iPriority);
		PlayerFeature hPFeature;
		strcopy(hPFeature.Key, sizeof(hPFeature.Key), sKey);
		strcopy(hPFeature.Value, sizeof(hPFeature.Value), sValue);
		hPFeature.CurrentPriority = iPriority;
		hPFeature.bEnabled = true;

		// Получаем индекс функции в массиве
		int iIndex = this.GetFeatureIDByName(sKey);

		// Если функции нету, создаём новую...
		if(iIndex == -1)
		{
			PrintToServer("PushArray - %s", sKey);
			this.hFeatures.PushArray(hPFeature, sizeof(hPFeature));
		}
		else 
		{
			// Если мы хотим удалить параметр из списка...
			if(!sValue[0])
			{
				PrintToServer("Erase - %s", sKey);
				this.hFeatures.Erase(iIndex);
				return;
			}

			PrintToServer("GetArray - %s", sKey);
			// Если есть, проверяем текущий приоритет...
			PlayerFeature hCurrentPFeature;
			this.hFeatures.GetArray(iIndex, hCurrentPFeature, sizeof(hCurrentPFeature));

			if(iPriority <= hCurrentPFeature.CurrentPriority)
			{
				PrintToServer("SetArray - %s", sKey);
				this.hFeatures.SetArray(iIndex, hPFeature, sizeof(hPFeature));
			}
		}
	}

	int GetFeatureIDByName(char[] sKey)
	{
		int iLen = this.hFeatures.Length;
		for(int i = 0; i < iLen; i++)
		{
			PlayerFeature hPFeature;
			this.hFeatures.GetArray(i, hPFeature, sizeof(hPFeature));
			if(!strcmp(hPFeature.Key, sKey)) return i;
		}

		return -1;
	}



	bool DelFeature(char[] sKey)
	{
		int iIndex = this.GetFeatureIDByName(sKey);

		if(iIndex != -1)
		{
			this.hFeatures.Erase(iIndex);
			return true;
		}

		return false;
	}

	bool AddCustomFeature(char[] sKey, char[] sValue)
	{
		int iIndex = this.GetCustomFeatureIDByKey(sKey);

		PlayerFeature hFeature;
		strcopy(hFeature.Key, sizeof(hFeature.Key), sKey);
		strcopy(hFeature.Value, sizeof(hFeature.Value), sValue);

		if(iIndex != -1)
		{
			this.hCustomFeatures.SetArray(iIndex, hFeature, sizeof(hFeature));
		}
		else
		{
			this.hCustomFeatures.PushArray(hFeature, sizeof(hFeature));
		}
		return true;
	}

	bool DelCustomFeature(char[] sKey)
	{
		int iIndex = this.GetCustomFeatureIDByKey(sKey);

		if(iIndex != -1)
		{
			this.hCustomFeatures.Erase(iIndex);
			return true;
		}

		return false;
	}

	int GetCustomFeatureIDByKey(char[] sKey)
	{
		int iLen = this.hCustomFeatures.Length;

		for(int i = 0; i < iLen; i++)
		{
			PlayerFeature hFeature;
			if(!strcmp(hFeature.Key, sKey)) return i;
		}

		return -1;
	}

	void RebuildFeatureList()
	{
		PrintToServer("Start - RebuildFeatureList - this.hFeatures.Clear()");
		this.hFeatures.Clear();

		int iLen = g_hGroups.Length;
		for(int i = iLen-1; i >= 0; i--)
		{
			GroupInfo hGroup;
			g_hGroups.GetArray(i, hGroup, sizeof(hGroup));

			if(this.CheckGroup(hGroup.Name))
			{
				PrintToServer("Group: %s", hGroup.Name);

				this.AddFeatureByGroupID(i);
			}
		}

		// Выставляем игроку кастомные функции...
		iLen = this.hCustomFeatures.Length;
		for(int i = 0; i < iLen; i++)
		{
			PlayerFeature hPFeature;
			this.hCustomFeatures.GetArray(i, hPFeature, sizeof(hPFeature));

			this.AddFeature(hPFeature.Key, hPFeature.Value, -1);
		}
	}

	void AddFeatureByGroupID(int iIndex, int iDeep = 0)
	{
		GroupInfo hGroup;
		g_hGroups.GetArray(iIndex, hGroup, sizeof(hGroup));

		char sName[D_GROUPNAME_LENGTH];
		int iLen = hGroup.hExtendList.Length;
		for(int i = 0; i < iLen; i++)
		{
			hGroup.hExtendList.GetString(i, sName, sizeof(sName));
		
			int iID = GetGroupIDByName(sName);
			if(iID != -1) 
			{
				char sBuffer[256];
				for(int j = 0; j < iDeep+1; j++)
				{
					sBuffer[j] = '>';
				}
				sBuffer[iDeep+1] = '\0';
				PrintToServer("Extend: %s %s", sBuffer, sName);
				iDeep++;
				this.AddFeatureByGroupID(iID, iDeep);
			}
		}

		iLen = hGroup.hFeatureList.Length;
		for(int i = 0; i < iLen; i++)
		{
			PlayerFeature hPFeature;
			hGroup.hFeatureList.GetArray(i, hPFeature, sizeof(hPFeature));

			this.AddFeature(hPFeature.Key, hPFeature.Value, iDeep == 0 ? 0 : iIndex);
		}
	}

	void Init(int iClient)
	{
		this.iClient = iClient;
		this.hGroups = new ArrayList(sizeof(PlayerGroup));
		this.hFeatures = new ArrayList(sizeof(PlayerFeature));
		this.hCustomFeatures = new ArrayList(sizeof(PlayerFeature));
	}

	void LoadData()
	{
		// TODO: Загрузка данных...
		this.AccountID = GetSteamAccountID(this.iClient);
		this.UserID = GetClientUserId(this.iClient);



		this.RebuildFeatureList();
	}

	void ClearData()
	{
		this.Status = Status_None;
		this.hGroups.Clear();
		this.hFeatures.Clear();
		this.hCustomFeatures.Clear();
		this.bVIP = false;
	}

	bool IsVIP()
	{
		return this.hGroups.Length > 0;
	}
}
PlayerData g_ePlayerData[MAXPLAYERS+1];

// Methods...

void LoadStructModule()
{
	g_hGroups = new ArrayList(sizeof(GroupInfo));
	g_hFeatures = new ArrayList(sizeof(Feature));
	g_hTimes = new ArrayList(sizeof(Times));

	InitPlayersData();
	g_eServerData.Init();
}

int GetGroupIDByName(char[] sKey)
{
	int iLen = g_hGroups.Length;
	for(int i = 0; i < iLen; i++)
	{
		GroupInfo hGroup;
		g_hGroups.GetArray(i, hGroup, sizeof(hGroup));
		if(!strcmp(hGroup.Name, sKey)) return i;
	}

	return -1;
}

bool IsFeatureExists(char[] sKey)
{
	int iLen = g_hFeatures.Length;
	for(int i = 0; i < iLen; i++)
	{
		Feature hFeature;
		g_hFeatures.GetArray(i, hFeature, sizeof(hFeature));

		if(!strcmp(hFeature.Key, sKey)) return true;
	}
	return false;
}

int GetFeatureIDByKey(char[] sKey)
{
	int iLen = g_hFeatures.Length;
	for(int i = 0; i < iLen; i++)
	{
		Feature hFeature;
		g_hFeatures.GetArray(i, hFeature, sizeof(hFeature));

		if(!strcmp(hFeature.Key, sKey)) return i;
	}
	return -1;
}

void InitPlayersData()
{
	for(int i = 0; i <= MaxClients; i++)
	{
		g_ePlayerData[i].Init(i);
	}
}

void LoadPlayersData()
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		g_ePlayerData[i].LoadData();
	}
}

void RebuildFeatureList()
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		g_ePlayerData[i].RebuildFeatureList();
	}
}