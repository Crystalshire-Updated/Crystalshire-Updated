Attribute VB_Name = "modDatabase"
Option Explicit
' Text API
Private Declare Function WritePrivateProfileString Lib "kernel32" Alias "WritePrivateProfileStringA" (ByVal lpApplicationname As String, ByVal lpKeyname As Any, ByVal lpString As String, ByVal lpfilename As String) As Long
Private Declare Function GetPrivateProfileString Lib "kernel32" Alias "GetPrivateProfileStringA" (ByVal lpApplicationname As String, ByVal lpKeyname As Any, ByVal lpdefault As String, ByVal lpreturnedstring As String, ByVal nsize As Long, ByVal lpfilename As String) As Long

Private crcTable(0 To 255) As Long

Public Sub InitCRC32()
Dim I As Long, n As Long, CRC As Long

    For I = 0 To 255
        CRC = I
        For n = 0 To 7
            If CRC And 1 Then
                CRC = (((CRC And &HFFFFFFFE) \ 2) And &H7FFFFFFF) Xor &HEDB88320
            Else
                CRC = ((CRC And &HFFFFFFFE) \ 2) And &H7FFFFFFF
            End If
        Next
        crcTable(I) = CRC
    Next
End Sub

Public Function CRC32(ByRef data() As Byte) As Long
Dim lCurPos As Long
Dim lLen As Long

    lLen = AryCount(data) - 1
    CRC32 = &HFFFFFFFF
    
    For lCurPos = 0 To lLen
        CRC32 = (((CRC32 And &HFFFFFF00) \ &H100) And &HFFFFFF) Xor (crcTable((CRC32 And 255) Xor data(lCurPos)))
    Next
    
    CRC32 = CRC32 Xor &HFFFFFFFF
End Function

Public Sub ChkDir(ByVal tDir As String, ByVal tName As String)

    If LCase$(Dir$(tDir & tName, vbDirectory)) <> tName Then Call MkDir(tDir & tName)
End Sub

Public Function FileExist(ByVal filename As String) As Boolean

    If LenB(Dir$(filename)) > 0 Then
        FileExist = True
    End If

End Function

' gets a string from a text file
Public Function GetVar(File As String, header As String, Var As String) As String
    Dim sSpaces As String   ' Max string length
    Dim szReturn As String  ' Return default value if not found
    szReturn = vbNullString
    sSpaces = Space$(5000)
    Call GetPrivateProfileString$(header, Var, szReturn, sSpaces, Len(sSpaces), File)
    GetVar = RTrim$(sSpaces)
    GetVar = Left$(GetVar, Len(GetVar) - 1)
End Function

' writes a variable to a text file
Public Sub PutVar(File As String, header As String, Var As String, value As String)
    Call WritePrivateProfileString$(header, Var, value, File)
End Sub

Public Sub SaveOptions()
    Dim filename As String, I As Long
    
    filename = App.path & "\Data Files\config_v2.ini"
    
    Call PutVar(filename, "Options", "Username", Options.Username)
    Call PutVar(filename, "Options", "Music", Str$(Options.Music))
    Call PutVar(filename, "Options", "Sound", Str$(Options.sound))
    Call PutVar(filename, "Options", "NoAuto", Str$(Options.NoAuto))
    Call PutVar(filename, "Options", "Render", Str$(Options.Render))
    Call PutVar(filename, "Options", "SaveUser", Str$(Options.SaveUser))
    Call PutVar(filename, "Options", "Resolution", Str$(Options.Resolution))
    Call PutVar(filename, "Options", "Fullscreen", Str$(Options.Fullscreen))
    For I = 0 To ChatChannel.Channel_Count - 1
        Call PutVar(filename, "Options", "Channel" & I, Str$(Options.channelState(I)))
    Next
End Sub

Public Sub LoadOptions()
    Dim filename As String, I As Long
    
    On Error GoTo errorhandler
    
    filename = App.path & "\Data Files\config_v2.ini"

    If Not FileExist(filename) Then
        GoTo errorhandler
    Else
        Options.Username = GetVar(filename, "Options", "Username")
        Options.Music = GetVar(filename, "Options", "Music")
        Options.sound = Val(GetVar(filename, "Options", "Sound"))
        Options.NoAuto = Val(GetVar(filename, "Options", "NoAuto"))
        Options.Render = Val(GetVar(filename, "Options", "Render"))
        Options.SaveUser = Val(GetVar(filename, "Options", "SaveUser"))
        Options.Resolution = Val(GetVar(filename, "Options", "Resolution"))
        Options.Fullscreen = Val(GetVar(filename, "Options", "Fullscreen"))
        For I = 0 To ChatChannel.Channel_Count - 1
            Options.channelState(I) = Val(GetVar(filename, "Options", "Channel" & I))
        Next
    End If
    
    Exit Sub
errorhandler:
    Options.Music = 1
    Options.sound = 1
    Options.NoAuto = 0
    Options.Username = vbNullString
    Options.Fullscreen = 0
    Options.Render = 0
    Options.SaveUser = 0
    For I = 0 To ChatChannel.Channel_Count - 1
        Options.channelState(I) = 1
    Next
    SaveOptions
    Exit Sub
End Sub

Public Sub SaveMap(ByVal mapNum As Long)
    Dim filename As String, f As Long, X As Long, Y As Long, I As Long
    
    ' save map data
    filename = App.path & MAP_PATH & mapNum & "_.dat"
    
    ' if it exists then kill the ini
    If FileExist(filename) Then Kill filename
    
    ' General
    With map.MapData
        PutVar filename, "General", "Name", .name
        PutVar filename, "General", "Music", .Music
        PutVar filename, "General", "Moral", Val(.Moral)
        PutVar filename, "General", "Up", Val(.Up)
        PutVar filename, "General", "Down", Val(.Down)
        PutVar filename, "General", "Left", Val(.Left)
        PutVar filename, "General", "Right", Val(.Right)
        PutVar filename, "General", "BootMap", Val(.BootMap)
        PutVar filename, "General", "BootX", Val(.BootX)
        PutVar filename, "General", "BootY", Val(.BootY)
        PutVar filename, "General", "MaxX", Val(.MaxX)
        PutVar filename, "General", "MaxY", Val(.MaxY)
        
        PutVar filename, "General", "Weather", Val(.Weather)
        PutVar filename, "General", "WeatherIntensity", Val(.WeatherIntensity)
        
        PutVar filename, "General", "Fog", Val(.Fog)
        PutVar filename, "General", "FogSpeed", Val(.FogSpeed)
        PutVar filename, "General", "FogOpacity", Val(.FogOpacity)
        
        PutVar filename, "General", "Red", Val(.Red)
        PutVar filename, "General", "Green", Val(.Green)
        PutVar filename, "General", "Blue", Val(.Blue)
        PutVar filename, "General", "Alpha", Val(.Alpha)
        
        PutVar filename, "General", "BossNpc", Val(.BossNpc)
        For I = 1 To MAX_MAP_NPCS
            PutVar filename, "General", "Npc" & I, Val(.Npc(I))
        Next
    End With
    
    ' dump tile data
    filename = App.path & MAP_PATH & mapNum & ".dat"
    
    ' if it exists then kill the ini
    If FileExist(filename) Then Kill filename
    
    f = FreeFile
    With map
        Open filename For Binary As #f
            For X = 0 To .MapData.MaxX
                For Y = 0 To .MapData.MaxY
                    Put #f, , .TileData.Tile(X, Y).Type
                    Put #f, , .TileData.Tile(X, Y).Data1
                    Put #f, , .TileData.Tile(X, Y).Data2
                    Put #f, , .TileData.Tile(X, Y).Data3
                    Put #f, , .TileData.Tile(X, Y).Data4
                    Put #f, , .TileData.Tile(X, Y).Data5
                    Put #f, , .TileData.Tile(X, Y).Autotile
                    Put #f, , .TileData.Tile(X, Y).DirBlock
                    For I = 1 To MapLayer.Layer_Count - 1
                        Put #f, , .TileData.Tile(X, Y).Layer(I).tileSet
                        Put #f, , .TileData.Tile(X, Y).Layer(I).X
                        Put #f, , .TileData.Tile(X, Y).Layer(I).Y
                    Next
                Next
            Next
        Close #f
    End With
    
    Close #f
End Sub

Sub GetMapCRC32(mapNum As Long)
Dim data() As Byte, filename As String, f As Long
    ' map data
    filename = App.path & MAP_PATH & mapNum & "_.dat"
    If FileExist(filename) Then
        f = FreeFile
        Open filename For Binary As #f
            data = Space$(LOF(f))
            Get #f, , data
        Close #f
        MapCRC32(mapNum).MapDataCRC = CRC32(data)
    Else
        MapCRC32(mapNum).MapDataCRC = 0
    End If
    ' clear
    Erase data
    ' tile data
    filename = App.path & MAP_PATH & mapNum & ".dat"
    If FileExist(filename) Then
        f = FreeFile
        Open filename For Binary As #f
            data = Space$(LOF(f))
            Get #f, , data
        Close #f
        MapCRC32(mapNum).MapTileCRC = CRC32(data)
    Else
        MapCRC32(mapNum).MapTileCRC = 0
    End If
End Sub

Public Sub LoadMap(ByVal mapNum As Long)
    Dim filename As String, I As Long, f As Long, X As Long, Y As Long
    
    ' load map data
    filename = App.path & MAP_PATH & mapNum & "_.dat"
    
    ' General
    With map.MapData
        .name = GetVar(filename, "General", "Name")
        .Music = GetVar(filename, "General", "Music")
        .Moral = Val(GetVar(filename, "General", "Moral"))
        .Up = Val(GetVar(filename, "General", "Up"))
        .Down = Val(GetVar(filename, "General", "Down"))
        .Left = Val(GetVar(filename, "General", "Left"))
        .Right = Val(GetVar(filename, "General", "Right"))
        .BootMap = Val(GetVar(filename, "General", "BootMap"))
        .BootX = Val(GetVar(filename, "General", "BootX"))
        .BootY = Val(GetVar(filename, "General", "BootY"))
        .MaxX = Val(GetVar(filename, "General", "MaxX"))
        .MaxY = Val(GetVar(filename, "General", "MaxY"))
        
        .Weather = Val(GetVar(filename, "General", "Weather"))
        .WeatherIntensity = Val(GetVar(filename, "General", "WeatherIntensity"))
        
        .Fog = Val(GetVar(filename, "General", "Fog"))
        .FogSpeed = Val(GetVar(filename, "General", "FogSpeed"))
        .FogOpacity = Val(GetVar(filename, "General", "FogOpacity"))
        
        .Red = Val(GetVar(filename, "General", "Red"))
        .Green = Val(GetVar(filename, "General", "Green"))
        .Blue = Val(GetVar(filename, "General", "Blue"))
        .Alpha = Val(GetVar(filename, "General", "Alpha"))
        .BossNpc = Val(GetVar(filename, "General", "BossNpc"))
        For I = 1 To MAX_MAP_NPCS
            .Npc(I) = Val(GetVar(filename, "General", "Npc" & I))
        Next
    End With
    
    ' dump tile data
    filename = App.path & MAP_PATH & mapNum & ".dat"
    f = FreeFile
    
    ReDim map.TileData.Tile(0 To map.MapData.MaxX, 0 To map.MapData.MaxY) As TileRec
    
    With map
        Open filename For Binary As #f
            For X = 0 To .MapData.MaxX
                For Y = 0 To .MapData.MaxY
                    Get #f, , .TileData.Tile(X, Y).Type
                    Get #f, , .TileData.Tile(X, Y).Data1
                    Get #f, , .TileData.Tile(X, Y).Data2
                    Get #f, , .TileData.Tile(X, Y).Data3
                    Get #f, , .TileData.Tile(X, Y).Data4
                    Get #f, , .TileData.Tile(X, Y).Data5
                    Get #f, , .TileData.Tile(X, Y).Autotile
                    Get #f, , .TileData.Tile(X, Y).DirBlock
                    For I = 1 To MapLayer.Layer_Count - 1
                        Get #f, , .TileData.Tile(X, Y).Layer(I).tileSet
                        Get #f, , .TileData.Tile(X, Y).Layer(I).X
                        Get #f, , .TileData.Tile(X, Y).Layer(I).Y
                    Next
                Next
            Next
        Close #f
    End With
    
    ClearTempTile
End Sub

Sub ClearPlayer(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Player(index)), LenB(Player(index)))
    Player(index).name = vbNullString
End Sub

Sub ClearItem(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Item(index)), LenB(Item(index)))
    Item(index).name = vbNullString
    Item(index).Desc = vbNullString
    Item(index).sound = "None."
End Sub

Sub ClearItems()
    Dim I As Long

    For I = 1 To MAX_ITEMS
        Call ClearItem(I)
    Next

End Sub

Sub ClearAnimInstance(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(AnimInstance(index)), LenB(AnimInstance(index)))
End Sub

Sub ClearAnimation(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Animation(index)), LenB(Animation(index)))
    Animation(index).name = vbNullString
    Animation(index).sound = "None."
End Sub

Sub ClearAnimations()
    Dim I As Long

    For I = 1 To MAX_ANIMATIONS
        Call ClearAnimation(I)
    Next

End Sub

Sub ClearNPC(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Npc(index)), LenB(Npc(index)))
    Npc(index).name = vbNullString
    Npc(index).sound = "None."
End Sub

Sub ClearNpcs()
    Dim I As Long

    For I = 1 To MAX_NPCS
        Call ClearNPC(I)
    Next

End Sub

Sub ClearSpell(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Spell(index)), LenB(Spell(index)))
    Spell(index).name = vbNullString
    Spell(index).Desc = vbNullString
    Spell(index).sound = "None."
End Sub

Sub ClearSpells()
    Dim I As Long

    For I = 1 To MAX_SPELLS
        Call ClearSpell(I)
    Next

End Sub

Sub ClearShop(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Shop(index)), LenB(Shop(index)))
    Shop(index).name = vbNullString
End Sub

Sub ClearShops()
    Dim I As Long

    For I = 1 To MAX_SHOPS
        Call ClearShop(I)
    Next

End Sub

Sub ClearResource(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Resource(index)), LenB(Resource(index)))
    Resource(index).name = vbNullString
    Resource(index).SuccessMessage = vbNullString
    Resource(index).EmptyMessage = vbNullString
    Resource(index).sound = "None."
End Sub

Sub ClearResources()
    Dim I As Long

    For I = 1 To MAX_RESOURCES
        Call ClearResource(I)
    Next

End Sub

Sub ClearMapItem(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(MapItem(index)), LenB(MapItem(index)))
End Sub

Sub ClearMap()
    Call ZeroMemory(ByVal VarPtr(map), LenB(map))
    map.MapData.name = vbNullString
    map.MapData.MaxX = MAX_MAPX
    map.MapData.MaxY = MAX_MAPY
    ReDim map.TileData.Tile(0 To map.MapData.MaxX, 0 To map.MapData.MaxY)
    initAutotiles
End Sub

Sub ClearMapItems()
    Dim I As Long

    For I = 1 To MAX_MAP_ITEMS
        Call ClearMapItem(I)
    Next

End Sub

Sub ClearMapNpc(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(MapNpc(index)), LenB(MapNpc(index)))
End Sub

Sub ClearMapNpcs()
    Dim I As Long

    For I = 1 To MAX_MAP_NPCS
        Call ClearMapNpc(I)
    Next

End Sub

' **********************
' ** Player functions **
' **********************
Function GetPlayerName(ByVal index As Long) As String

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerName = Trim$(Player(index).name)
End Function

Sub SetPlayerName(ByVal index As Long, ByVal name As String)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).name = name
End Sub

Function GetPlayerClass(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerClass = Player(index).Class
End Function

Sub SetPlayerClass(ByVal index As Long, ByVal ClassNum As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Class = ClassNum
End Sub

Function GetPlayerSprite(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerSprite = Player(index).sprite
End Function

Sub SetPlayerSprite(ByVal index As Long, ByVal sprite As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).sprite = sprite
End Sub

Function GetPlayerLevel(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerLevel = Player(index).Level
End Function

Sub SetPlayerLevel(ByVal index As Long, ByVal Level As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Level = Level
End Sub

Function GetPlayerExp(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerExp = Player(index).EXP
End Function

Sub SetPlayerExp(ByVal index As Long, ByVal EXP As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).EXP = EXP
End Sub

Function GetPlayerAccess(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerAccess = Player(index).Access
End Function

Sub SetPlayerAccess(ByVal index As Long, ByVal Access As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Access = Access
End Sub

Function GetPlayerPK(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerPK = Player(index).PK
End Function

Sub SetPlayerPK(ByVal index As Long, ByVal PK As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).PK = PK
End Sub

Function GetPlayerVital(ByVal index As Long, ByVal Vital As Vitals) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerVital = Player(index).Vital(Vital)
End Function

Sub SetPlayerVital(ByVal index As Long, ByVal Vital As Vitals, ByVal value As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Vital(Vital) = value

    If GetPlayerVital(index, Vital) > GetPlayerMaxVital(index, Vital) Then
        Player(index).Vital(Vital) = GetPlayerMaxVital(index, Vital)
    End If

End Sub

Function GetPlayerMaxVital(ByVal index As Long, ByVal Vital As Vitals) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerMaxVital = Player(index).MaxVital(Vital)
End Function

Function GetPlayerStat(ByVal index As Long, Stat As Stats) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerStat = Player(index).Stat(Stat)
End Function

Sub SetPlayerStat(ByVal index As Long, Stat As Stats, ByVal value As Long)

    If index > MAX_PLAYERS Then Exit Sub
    If value <= 0 Then value = 1
    If value > MAX_BYTE Then value = MAX_BYTE
    Player(index).Stat(Stat) = value
End Sub

Function GetPlayerPOINTS(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerPOINTS = Player(index).POINTS
End Function

Sub SetPlayerPOINTS(ByVal index As Long, ByVal POINTS As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).POINTS = POINTS
End Sub

Function GetPlayerMap(ByVal index As Long) As Long

    If index > MAX_PLAYERS Or index <= 0 Then Exit Function
    GetPlayerMap = Player(index).map
End Function

Sub SetPlayerMap(ByVal index As Long, ByVal mapNum As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).map = mapNum
End Sub

Function GetPlayerX(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerX = Player(index).X
End Function

Sub SetPlayerX(ByVal index As Long, ByVal X As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).X = X
End Sub

Function GetPlayerY(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerY = Player(index).Y
End Function

Sub SetPlayerY(ByVal index As Long, ByVal Y As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Y = Y
End Sub

Function GetPlayerDir(ByVal index As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerDir = Player(index).Dir
End Function

Sub SetPlayerDir(ByVal index As Long, ByVal Dir As Long)

    If index > MAX_PLAYERS Then Exit Sub
    Player(index).Dir = Dir
End Sub

Function GetPlayerInvItemNum(ByVal index As Long, ByVal invSlot As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    If invSlot = 0 Then Exit Function
    GetPlayerInvItemNum = PlayerInv(invSlot).num
End Function

Sub SetPlayerInvItemNum(ByVal index As Long, ByVal invSlot As Long, ByVal itemNum As Long)

    If index > MAX_PLAYERS Then Exit Sub
    PlayerInv(invSlot).num = itemNum
End Sub

Function GetPlayerInvItemValue(ByVal index As Long, ByVal invSlot As Long) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerInvItemValue = PlayerInv(invSlot).value
End Function

Sub SetPlayerInvItemValue(ByVal index As Long, ByVal invSlot As Long, ByVal ItemValue As Long)

    If index > MAX_PLAYERS Then Exit Sub
    PlayerInv(invSlot).value = ItemValue
End Sub

Function GetPlayerEquipment(ByVal index As Long, ByVal EquipmentSlot As Equipment) As Long

    If index > MAX_PLAYERS Then Exit Function
    GetPlayerEquipment = Player(index).Equipment(EquipmentSlot)
End Function

Sub SetPlayerEquipment(ByVal index As Long, ByVal invNum As Long, ByVal EquipmentSlot As Equipment)

    If index < 1 Or index > MAX_PLAYERS Then Exit Sub
    Player(index).Equipment(EquipmentSlot) = invNum
End Sub

Sub ClearConv(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Conv(index)), LenB(Conv(index)))
    Conv(index).name = vbNullString
    ReDim Conv(index).Conv(1)
End Sub

Sub ClearConvs()
    Dim I As Long

    For I = 1 To MAX_CONVS
        Call ClearConv(I)
    Next

End Sub
