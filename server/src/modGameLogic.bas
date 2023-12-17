Attribute VB_Name = "modGameLogic"
Option Explicit

Function FindOpenPlayerSlot() As Long
    Dim i As Long
    FindOpenPlayerSlot = 0

    For i = 1 To MAX_PLAYERS

        If Not IsConnected(i) Then
            FindOpenPlayerSlot = i
            Exit Function
        End If

    Next

End Function

Function FindOpenMapItemSlot(ByVal mapnum As Long) As Long
    Dim i As Long
    FindOpenMapItemSlot = 0

    ' Check for subscript out of range
    If mapnum <= 0 Or mapnum > MAX_MAPS Then
        Exit Function
    End If

    For i = 1 To MAX_MAP_ITEMS

        If MapItem(mapnum, i).Num = 0 Then
            FindOpenMapItemSlot = i
            Exit Function
        End If

    Next

End Function

Function TotalOnlinePlayers() As Long
    Dim i As Long
    TotalOnlinePlayers = 0

    For i = 1 To Player_HighIndex

        If IsPlaying(i) Then
            TotalOnlinePlayers = TotalOnlinePlayers + 1
        End If

    Next

End Function

Function FindPlayer(ByVal Name As String) As Long
    Dim i As Long

    For i = 1 To Player_HighIndex

        If IsPlaying(i) Then

            ' Make sure we dont try to check a name thats to small
            If Len(GetPlayerName(i)) >= Len(Trim$(Name)) Then
                If UCase$(Mid$(GetPlayerName(i), 1, Len(Trim$(Name)))) = UCase$(Trim$(Name)) Then
                    FindPlayer = i
                    Exit Function
                End If
            End If
        End If

    Next

    FindPlayer = 0
End Function

Sub SpawnItem(ByVal ItemNum As Long, ByVal ItemVal As Long, ByVal mapnum As Long, ByVal x As Long, ByVal y As Long, Optional ByVal playerName As String = vbNullString)
    Dim i As Long

    ' Check for subscript out of range
    If ItemNum < 1 Or ItemNum > MAX_ITEMS Or mapnum <= 0 Or mapnum > MAX_MAPS Then
        Exit Sub
    End If

    ' Find open map item slot
    i = FindOpenMapItemSlot(mapnum)
    Call SpawnItemSlot(i, ItemNum, ItemVal, mapnum, x, y, playerName)
End Sub

Sub SpawnItemSlot(ByVal MapItemSlot As Long, ByVal ItemNum As Long, ByVal ItemVal As Long, ByVal mapnum As Long, ByVal x As Long, ByVal y As Long, Optional ByVal playerName As String = vbNullString, Optional ByVal canDespawn As Boolean = True, Optional ByVal isSB As Boolean = False)
    Dim packet As String
    Dim i As Long
    Dim buffer As clsBuffer

    ' Check for subscript out of range
    If MapItemSlot <= 0 Or MapItemSlot > MAX_MAP_ITEMS Or ItemNum < 0 Or ItemNum > MAX_ITEMS Or mapnum <= 0 Or mapnum > MAX_MAPS Then
        Exit Sub
    End If

    i = MapItemSlot

    If i <> 0 Then
        If ItemNum >= 0 And ItemNum <= MAX_ITEMS Then
            MapItem(mapnum, i).playerName = playerName
            MapItem(mapnum, i).playerTimer = GetTickCount + ITEM_SPAWN_TIME
            MapItem(mapnum, i).canDespawn = canDespawn
            MapItem(mapnum, i).despawnTimer = GetTickCount + ITEM_DESPAWN_TIME
            MapItem(mapnum, i).Num = ItemNum
            MapItem(mapnum, i).Value = ItemVal
            MapItem(mapnum, i).x = x
            MapItem(mapnum, i).y = y
            MapItem(mapnum, i).Bound = isSB
            ' send to map
            SendSpawnItemToMap mapnum, i
        End If
    End If

End Sub

Sub SpawnAllMapsItems()
    Dim i As Long

    For i = 1 To MAX_MAPS
        Call SpawnMapItems(i)
    Next

End Sub

Sub SpawnMapItems(ByVal mapnum As Long)
    Dim x As Long
    Dim y As Long

    ' Check for subscript out of range
    If mapnum <= 0 Or mapnum > MAX_MAPS Then
        Exit Sub
    End If

    ' Spawn what we have
    For x = 0 To Map(mapnum).MapData.MaxX
        For y = 0 To Map(mapnum).MapData.MaxY

            ' Check if the tile type is an item or a saved tile incase someone drops something
            If (Map(mapnum).TileData.Tile(x, y).Type = TILE_TYPE_ITEM) Then

                ' Check to see if its a currency and if they set the value to 0 set it to 1 automatically
                If Item(Map(mapnum).TileData.Tile(x, y).Data1).Type = ITEM_TYPE_CURRENCY And Map(mapnum).TileData.Tile(x, y).Data2 <= 0 Then
                    Call SpawnItem(Map(mapnum).TileData.Tile(x, y).Data1, 1, mapnum, x, y)
                Else
                    Call SpawnItem(Map(mapnum).TileData.Tile(x, y).Data1, Map(mapnum).TileData.Tile(x, y).Data2, mapnum, x, y)
                End If
            End If

        Next
    Next

End Sub

Function Random(ByVal Low As Long, ByVal High As Long) As Long
    Random = ((High - Low + 1) * Rnd) + Low
End Function

Public Sub SpawnNpc(ByVal mapNpcNum As Long, ByVal mapnum As Long)
    Dim buffer As clsBuffer
    Dim npcNum As Long
    Dim i As Long
    Dim x As Long
    Dim y As Long
    Dim Spawned As Boolean

    ' Check for subscript out of range
    If mapNpcNum <= 0 Or mapNpcNum > MAX_MAP_NPCS Or mapnum <= 0 Or mapnum > MAX_MAPS Then Exit Sub
    npcNum = Map(mapnum).MapData.Npc(mapNpcNum)

    If npcNum > 0 Then
    
        With MapNpc(mapnum).Npc(mapNpcNum)
            .Num = npcNum
            .Target = 0
            .targetType = 0 ' clear
            .Vital(Vitals.HP) = GetNpcMaxVital(npcNum, Vitals.HP)
            .Vital(Vitals.MP) = GetNpcMaxVital(npcNum, Vitals.MP)
            .Dir = Int(Rnd * 4)
            .spellBuffer.Spell = 0
            .spellBuffer.Timer = 0
            .spellBuffer.Target = 0
            .spellBuffer.tType = 0
        
            'Check if theres a spawn tile for the specific npc
            For x = 0 To Map(mapnum).MapData.MaxX
                For y = 0 To Map(mapnum).MapData.MaxY
                    If Map(mapnum).TileData.Tile(x, y).Type = TILE_TYPE_NPCSPAWN Then
                        If Map(mapnum).TileData.Tile(x, y).Data1 = mapNpcNum Then
                            .x = x
                            .y = y
                            .Dir = Map(mapnum).TileData.Tile(x, y).Data2
                            Spawned = True
                            Exit For
                        End If
                    End If
                Next y
            Next x
            
            If Not Spawned Then
        
                ' Well try 100 times to randomly place the sprite
                For i = 1 To 100
                    x = Random(0, Map(mapnum).MapData.MaxX)
                    y = Random(0, Map(mapnum).MapData.MaxY)
        
                    If x > Map(mapnum).MapData.MaxX Then x = Map(mapnum).MapData.MaxX
                    If y > Map(mapnum).MapData.MaxY Then y = Map(mapnum).MapData.MaxY
        
                    ' Check if the tile is walkable
                    If NpcTileIsOpen(mapnum, x, y) Then
                        .x = x
                        .y = y
                        Spawned = True
                        Exit For
                    End If
        
                Next
                
            End If
    
            ' Didn't spawn, so now we'll just try to find a free tile
            If Not Spawned Then
    
                For x = 0 To Map(mapnum).MapData.MaxX
                    For y = 0 To Map(mapnum).MapData.MaxY
    
                        If NpcTileIsOpen(mapnum, x, y) Then
                            .x = x
                            .y = y
                            Spawned = True
                        End If
    
                    Next
                Next
    
            End If
    
            ' If we suceeded in spawning then send it to everyone
            If Spawned Then
                Set buffer = New clsBuffer
                buffer.WriteLong SSpawnNpc
                buffer.WriteLong mapNpcNum
                buffer.WriteLong .Num
                buffer.WriteLong .x
                buffer.WriteLong .y
                buffer.WriteLong .Dir
                
                SendDataToMap mapnum, buffer.ToArray()
                buffer.Flush: Set buffer = Nothing
            End If
            
            SendMapNpcVitals mapnum, mapNpcNum
        End With
    End If
End Sub

Public Function NpcTileIsOpen(ByVal mapnum As Long, ByVal x As Long, ByVal y As Long) As Boolean
    Dim LoopI As Long
    NpcTileIsOpen = True

    If PlayersOnMap(mapnum) Then

        For LoopI = 1 To Player_HighIndex

            If GetPlayerMap(LoopI) = mapnum Then
                If GetPlayerX(LoopI) = x Then
                    If GetPlayerY(LoopI) = y Then
                        NpcTileIsOpen = False
                        Exit Function
                    End If
                End If
            End If

        Next

    End If

    For LoopI = 1 To MAX_MAP_NPCS

        If MapNpc(mapnum).Npc(LoopI).Num > 0 Then
            If MapNpc(mapnum).Npc(LoopI).x = x Then
                If MapNpc(mapnum).Npc(LoopI).y = y Then
                    NpcTileIsOpen = False
                    Exit Function
                End If
            End If
        End If

    Next

    If Map(mapnum).TileData.Tile(x, y).Type <> TILE_TYPE_WALKABLE Then
        If Map(mapnum).TileData.Tile(x, y).Type <> TILE_TYPE_NPCSPAWN Then
            If Map(mapnum).TileData.Tile(x, y).Type <> TILE_TYPE_ITEM Then
                NpcTileIsOpen = False
            End If
        End If
    End If
End Function

Sub SpawnMapNpcs(ByVal mapnum As Long)
    Dim i As Long

    For i = 1 To MAX_MAP_NPCS
        Call SpawnNpc(i, mapnum)
    Next

End Sub

Sub SpawnAllMapNpcs()
    Dim i As Long

    For i = 1 To MAX_MAPS
        Call SpawnMapNpcs(i)
    Next

End Sub

Function CanNpcMove(ByVal mapnum As Long, ByVal mapNpcNum As Long, ByVal Dir As Byte) As Boolean
    Dim i As Long
    Dim n As Long
    Dim x As Long
    Dim y As Long

    ' Check for subscript out of range
    If mapnum <= 0 Or mapnum > MAX_MAPS Or mapNpcNum <= 0 Or mapNpcNum > MAX_MAP_NPCS Or Dir < DIR_UP Or Dir > DIR_DOWN_RIGHT Then
        Exit Function
    End If

    x = MapNpc(mapnum).Npc(mapNpcNum).x
    y = MapNpc(mapnum).Npc(mapNpcNum).y
    CanNpcMove = True

    Select Case Dir
        Case DIR_UP

            ' Check to make sure not outside of boundries
            If y > 0 Then
                n = Map(mapnum).TileData.Tile(x, y - 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_UP + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If

        Case DIR_DOWN

            ' Check to make sure not outside of boundries
            If y < Map(mapnum).MapData.MaxY Then
                n = Map(mapnum).TileData.Tile(x, y + 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_DOWN + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If

        Case DIR_LEFT

            ' Check to make sure not outside of boundries
            If x > 0 Then
                n = Map(mapnum).TileData.Tile(x - 1, y).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_LEFT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If

        Case DIR_RIGHT

            ' Check to make sure not outside of boundries
            If x < Map(mapnum).MapData.MaxX Then
                n = Map(mapnum).TileData.Tile(x + 1, y).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_RIGHT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If
'#######################################################################################################################
'#######################################################################################################################
        Case DIR_UP_LEFT
            ' Check to make sure not outside of boundries
            If y > 0 And x > 0 Then
                n = Map(mapnum).TileData.Tile(x - 1, y - 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_LEFT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If
'#######################################################################################################################
'#######################################################################################################################
        Case DIR_UP_RIGHT
            ' Check to make sure not outside of boundries
            If y > 0 And x < Map(mapnum).MapData.MaxX Then
                n = Map(mapnum).TileData.Tile(x + 1, y - 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_RIGHT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If
'#######################################################################################################################
'#######################################################################################################################
        Case DIR_DOWN_LEFT

            ' Check to make sure not outside of boundries
            If y < Map(mapnum).MapData.MaxY And x > 0 Then
                n = Map(mapnum).TileData.Tile(x - 1, y + 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_LEFT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If
'#######################################################################################################################
'#######################################################################################################################
        Case DIR_DOWN_RIGHT

            ' Check to make sure not outside of boundries
            If y < Map(mapnum).MapData.MaxY And x < Map(mapnum).MapData.MaxX Then
                n = Map(mapnum).TileData.Tile(x + 1, y + 1).Type

                ' Check to make sure that the tile is walkable
                If n <> TILE_TYPE_WALKABLE And n <> TILE_TYPE_ITEM And n <> TILE_TYPE_NPCSPAWN Then
                    CanNpcMove = False
                    Exit Function
                End If

                ' Check to make sure that there is not a player in the way
                For i = 1 To Player_HighIndex
                    If IsPlaying(i) Then
                        If (GetPlayerMap(i) = mapnum) And (GetPlayerX(i) = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (GetPlayerY(i) = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                            CanNpcMove = False
                            Exit Function
                        End If
                    End If
                Next

                ' Check to make sure that there is not another npc in the way
                For i = 1 To MAX_MAP_NPCS
                    If (i <> mapNpcNum) And (MapNpc(mapnum).Npc(i).Num > 0) And (MapNpc(mapnum).Npc(i).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1) And (MapNpc(mapnum).Npc(i).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1) Then
                        CanNpcMove = False
                        Exit Function
                    End If
                Next
                
                ' Directional blocking
                If isDirBlocked(Map(mapnum).TileData.Tile(MapNpc(mapnum).Npc(mapNpcNum).x, MapNpc(mapnum).Npc(mapNpcNum).y).DirBlock, DIR_RIGHT + 1) Then
                    CanNpcMove = False
                    Exit Function
                End If
            Else
                CanNpcMove = False
            End If

    End Select

End Function

Sub NpcMove(ByVal mapnum As Long, ByVal mapNpcNum As Long, ByVal Dir As Long, ByVal movement As Long)
    Dim packet As String
    Dim buffer As clsBuffer

    ' Check for subscript out of range
    If mapnum <= 0 Or mapnum > MAX_MAPS Or mapNpcNum <= 0 Or mapNpcNum > MAX_MAP_NPCS Or Dir < DIR_UP Or Dir > DIR_DOWN_RIGHT Or movement < 1 Or movement > 2 Then
        Exit Sub
    End If

    MapNpc(mapnum).Npc(mapNpcNum).Dir = Dir

    Select Case Dir
        Case DIR_UP
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1
        Case DIR_DOWN
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1
        Case DIR_LEFT
            MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1
        Case DIR_RIGHT
            MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1
        Case DIR_UP_LEFT
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1: MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1
        Case DIR_UP_RIGHT
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y - 1: MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1
        Case DIR_DOWN_LEFT
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1: MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x - 1
        Case DIR_DOWN_RIGHT
            MapNpc(mapnum).Npc(mapNpcNum).y = MapNpc(mapnum).Npc(mapNpcNum).y + 1: MapNpc(mapnum).Npc(mapNpcNum).x = MapNpc(mapnum).Npc(mapNpcNum).x + 1
    End Select

    Set buffer = New clsBuffer
    buffer.WriteLong SNpcMove
    buffer.WriteLong mapNpcNum
    buffer.WriteLong MapNpc(mapnum).Npc(mapNpcNum).x
    buffer.WriteLong MapNpc(mapnum).Npc(mapNpcNum).y
    buffer.WriteLong MapNpc(mapnum).Npc(mapNpcNum).Dir
    buffer.WriteLong movement
    
    SendDataToMap mapnum, buffer.ToArray()
    buffer.Flush: Set buffer = Nothing

End Sub

Sub NpcDir(ByVal mapnum As Long, ByVal mapNpcNum As Long, ByVal Dir As Long)
    Dim packet As String
    Dim buffer As clsBuffer

    ' Check for subscript out of range
    If mapnum <= 0 Or mapnum > MAX_MAPS Or mapNpcNum <= 0 Or mapNpcNum > MAX_MAP_NPCS Or Dir < DIR_UP Or Dir > DIR_DOWN_RIGHT Then
        Exit Sub
    End If

    MapNpc(mapnum).Npc(mapNpcNum).Dir = Dir
    Set buffer = New clsBuffer
    buffer.WriteLong SNpcDir
    buffer.WriteLong mapNpcNum
    buffer.WriteLong Dir
    
    SendDataToMap mapnum, buffer.ToArray()
    buffer.Flush: Set buffer = Nothing
End Sub

Function GetTotalMapPlayers(ByVal mapnum As Long) As Long
    Dim i As Long
    Dim n As Long
    n = 0

    For i = 1 To Player_HighIndex

        If IsPlaying(i) And GetPlayerMap(i) = mapnum Then
            n = n + 1
        End If

    Next

    GetTotalMapPlayers = n
End Function

Sub ClearTempTiles()
    Dim i As Long

    For i = 1 To MAX_MAPS
        ClearTempTile i
    Next

End Sub

Sub ClearTempTile(ByVal mapnum As Long)
    Dim y As Long
    Dim x As Long
    TempTile(mapnum).DoorTimer = 0
    ReDim TempTile(mapnum).DoorOpen(0 To Map(mapnum).MapData.MaxX, 0 To Map(mapnum).MapData.MaxY)

    For x = 0 To Map(mapnum).MapData.MaxX
        For y = 0 To Map(mapnum).MapData.MaxY
            TempTile(mapnum).DoorOpen(x, y) = NO
        Next
    Next

End Sub

Public Sub CacheResources(ByVal mapnum As Long)
    Dim x As Long, y As Long, Resource_Count As Long
    Resource_Count = 0

    For x = 0 To Map(mapnum).MapData.MaxX
        For y = 0 To Map(mapnum).MapData.MaxY

            If Map(mapnum).TileData.Tile(x, y).Type = TILE_TYPE_RESOURCE Then
                Resource_Count = Resource_Count + 1
                ReDim Preserve ResourceCache(mapnum).ResourceData(0 To Resource_Count)
                ResourceCache(mapnum).ResourceData(Resource_Count).x = x
                ResourceCache(mapnum).ResourceData(Resource_Count).y = y
                ResourceCache(mapnum).ResourceData(Resource_Count).cur_health = Resource(Map(mapnum).TileData.Tile(x, y).Data1).health
            End If

        Next
    Next

    ResourceCache(mapnum).Resource_Count = Resource_Count
End Sub

Sub PlayerSwitchBankSlots(ByVal Index As Long, ByVal oldSlot As Long, ByVal newSlot As Long)
Dim OldNum As Long
Dim OldValue As Long
Dim NewNum As Long
Dim NewValue As Long

    If oldSlot = 0 Or newSlot = 0 Then
        Exit Sub
    End If
    
    OldNum = GetPlayerBankItemNum(Index, oldSlot)
    OldValue = GetPlayerBankItemValue(Index, oldSlot)
    NewNum = GetPlayerBankItemNum(Index, newSlot)
    NewValue = GetPlayerBankItemValue(Index, newSlot)
    
    SetPlayerBankItemNum Index, newSlot, OldNum
    SetPlayerBankItemValue Index, newSlot, OldValue
    
    SetPlayerBankItemNum Index, oldSlot, NewNum
    SetPlayerBankItemValue Index, oldSlot, NewValue
        
    SendBank Index
End Sub

Sub PlayerSwitchInvSlots(ByVal Index As Long, ByVal oldSlot As Long, ByVal newSlot As Long)
Dim OldNum As Long, OldValue As Long, oldBound As Byte
Dim NewNum As Long, NewValue As Long, newBound As Byte

    If oldSlot = 0 Or newSlot = 0 Then
        Exit Sub
    End If

    OldNum = GetPlayerInvItemNum(Index, oldSlot)
    OldValue = GetPlayerInvItemValue(Index, oldSlot)
    oldBound = Player(Index).Inv(oldSlot).Bound
    NewNum = GetPlayerInvItemNum(Index, newSlot)
    NewValue = GetPlayerInvItemValue(Index, newSlot)
    newBound = Player(Index).Inv(newSlot).Bound
    
    SetPlayerInvItemNum Index, newSlot, OldNum
    SetPlayerInvItemValue Index, newSlot, OldValue
    Player(Index).Inv(newSlot).Bound = oldBound
    
    SetPlayerInvItemNum Index, oldSlot, NewNum
    SetPlayerInvItemValue Index, oldSlot, NewValue
    Player(Index).Inv(oldSlot).Bound = newBound
    
    SendInventory Index
End Sub

Sub PlayerSwitchSpellSlots(ByVal Index As Long, ByVal oldSlot As Long, ByVal newSlot As Long)
Dim OldNum As Long, NewNum As Long, OldUses As Long, NewUses As Long

    If oldSlot = 0 Or newSlot = 0 Then
        Exit Sub
    End If

    OldNum = Player(Index).Spell(oldSlot).Spell
    NewNum = Player(Index).Spell(newSlot).Spell
    OldUses = Player(Index).Spell(oldSlot).Uses
    NewUses = Player(Index).Spell(newSlot).Uses
    
    Player(Index).Spell(oldSlot).Spell = NewNum
    Player(Index).Spell(oldSlot).Uses = NewUses
    Player(Index).Spell(newSlot).Spell = OldNum
    Player(Index).Spell(newSlot).Uses = OldUses
    SendPlayerSpells Index
End Sub

Sub PlayerUnequipItem(ByVal Index As Long, ByVal EqSlot As Long)

    If EqSlot <= 0 Or EqSlot > Equipment.Equipment_Count - 1 Then Exit Sub ' exit out early if error'd
    If FindOpenInvSlot(Index, GetPlayerEquipment(Index, EqSlot)) > 0 Then
        GiveInvItem Index, GetPlayerEquipment(Index, EqSlot), 0, , True
        PlayerMsg Index, "You unequip " & CheckGrammar(Item(GetPlayerEquipment(Index, EqSlot)).Name), Yellow
        ' send the sound
        SendPlayerSound Index, GetPlayerX(Index), GetPlayerY(Index), SoundEntity.seItem, GetPlayerEquipment(Index, EqSlot)
        ' remove equipment
        SetPlayerEquipment Index, 0, EqSlot
        SendWornEquipment Index
        SendMapEquipment Index
        SendStats Index
        ' send vitals
        Call SendVital(Index, Vitals.HP)
        Call SendVital(Index, Vitals.MP)
        ' send vitals to party if in one
        If TempPlayer(Index).inParty > 0 Then SendPartyVitals TempPlayer(Index).inParty, Index
    Else
        PlayerMsg Index, "Your inventory is full.", BrightRed
    End If

End Sub

Public Function CheckGrammar(ByVal Word As String, Optional ByVal Caps As Byte = 0) As String
Dim FirstLetter As String * 1
   
    FirstLetter = LCase$(left$(Word, 1))
   
    If FirstLetter = "$" Then
      CheckGrammar = (Mid$(Word, 2, Len(Word) - 1))
      Exit Function
    End If
   
    If FirstLetter Like "*[aeiou]*" Then
        If Caps Then CheckGrammar = "An " & Word Else CheckGrammar = "an " & Word
    Else
        If Caps Then CheckGrammar = "A " & Word Else CheckGrammar = "a " & Word
    End If
End Function

Function isInRange(ByVal Range As Long, ByVal x1 As Long, ByVal y1 As Long, ByVal x2 As Long, ByVal y2 As Long) As Boolean
Dim nVal As Long
    isInRange = False
    nVal = Sqr((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
    If nVal <= Range Then isInRange = True
End Function

Public Function isDirBlocked(ByRef blockvar As Byte, ByRef Dir As Byte) As Boolean
    If Not blockvar And (2 ^ Dir) Then
        isDirBlocked = False
    Else
        isDirBlocked = True
    End If
End Function

Public Function RAND(ByVal Low As Long, ByVal High As Long) As Long
    Randomize
    RAND = Int((High - Low + 1) * Rnd) + Low
End Function

' #####################
' ## Party functions ##
' #####################
Public Sub Party_PlayerLeave(ByVal Index As Long)
Dim partynum As Long, i As Long

    partynum = TempPlayer(Index).inParty
    If partynum > 0 Then
        ' find out how many members we have
        Party_CountMembers partynum
        ' make sure there's more than 2 people
        If Party(partynum).MemberCount > 2 Then
            ' check if leader
            If Party(partynum).Leader = Index Then
                ' set next person down as leader
                For i = 1 To MAX_PARTY_MEMBERS
                    If Party(partynum).Member(i) > 0 And Party(partynum).Member(i) <> Index Then
                        Party(partynum).Leader = Party(partynum).Member(i)
                        PartyMsg partynum, GetPlayerName(i) & " is now the party leader.", BrightBlue
                        Exit For
                    End If
                Next
                ' leave party
                PartyMsg partynum, GetPlayerName(Index) & " has left the party.", BrightRed
                ' remove from array
                For i = 1 To MAX_PARTY_MEMBERS
                    If Party(partynum).Member(i) = Index Then
                        Party(partynum).Member(i) = 0
                        Exit For
                    End If
                Next
                ' recount party
                Party_CountMembers partynum
                ' set update to all
                SendPartyUpdate partynum
                ' send clear to player
                SendPartyUpdateTo Index
            Else
                ' not the leader, just leave
                PartyMsg partynum, GetPlayerName(Index) & " has left the party.", BrightRed
                ' remove from array
                For i = 1 To MAX_PARTY_MEMBERS
                    If Party(partynum).Member(i) = Index Then
                        Party(partynum).Member(i) = 0
                        Exit For
                    End If
                Next
                ' recount party
                Party_CountMembers partynum
                ' set update to all
                SendPartyUpdate partynum
                ' send clear to player
                SendPartyUpdateTo Index
            End If
        Else
            ' find out how many members we have
            Party_CountMembers partynum
            ' only 2 people, disband
            PartyMsg partynum, "Party disbanded.", BrightRed
            ' clear out everyone's party
            For i = 1 To MAX_PARTY_MEMBERS
                Index = Party(partynum).Member(i)
                ' player exist?
                If Index > 0 Then
                    ' remove them
                    TempPlayer(Index).inParty = 0
                    ' send clear to players
                    SendPartyUpdateTo Index
                End If
            Next
            ' clear out the party itself
            ClearParty partynum
        End If
    End If
End Sub

Public Sub Party_Invite(ByVal Index As Long, ByVal targetPlayer As Long)
Dim partynum As Long, i As Long

    ' check if the person is a valid target
    If Not IsConnected(targetPlayer) Or Not IsPlaying(targetPlayer) Then Exit Sub
    
    ' make sure they're not busy
    If TempPlayer(targetPlayer).partyInvite > 0 Then
        ' they've already got a request for trade/party
        PlayerMsg Index, "This player has an outstanding party invitation already.", BrightRed
        ' exit out early
        Exit Sub
    End If
    ' make syure they're not in a party
    If TempPlayer(targetPlayer).inParty > 0 Then
        ' they're already in a party
        PlayerMsg Index, "This player is already in a party.", BrightRed
        'exit out early
        Exit Sub
    End If
    
    ' check if we're in a party
    If TempPlayer(Index).inParty > 0 Then
        partynum = TempPlayer(Index).inParty
        ' make sure we're the leader
        If Party(partynum).Leader = Index Then
            ' got a blank slot?
            For i = 1 To MAX_PARTY_MEMBERS
                If Party(partynum).Member(i) = 0 Then
                    ' send the invitation
                    SendPartyInvite targetPlayer, Index
                    ' set the invite target
                    TempPlayer(targetPlayer).partyInvite = Index
                    ' let them know
                    PlayerMsg Index, "Invitation sent.", Green
                    Exit Sub
                End If
            Next
            ' no room
            PlayerMsg Index, "Party is full.", BrightRed
            Exit Sub
        Else
            ' not the leader
            PlayerMsg Index, "You are not the party leader.", BrightRed
            Exit Sub
        End If
    Else
        ' not in a party - doesn't matter!
        SendPartyInvite targetPlayer, Index
        ' set the invite target
        TempPlayer(targetPlayer).partyInvite = Index
        ' let them know
        PlayerMsg Index, "Invitation sent.", Green
        Exit Sub
    End If
End Sub

Public Sub Party_InviteAccept(ByVal Index As Long, ByVal targetPlayer As Long)
Dim partynum As Long, i As Long, x As Long

    If Index = 0 Then Exit Sub
    
    If Not IsConnected(Index) Or Not IsPlaying(Index) Then
        TempPlayer(targetPlayer).TradeRequest = 0
        TempPlayer(Index).TradeRequest = 0
        Exit Sub
    End If
    
    If Not IsConnected(targetPlayer) Or Not IsPlaying(targetPlayer) Then
        TempPlayer(targetPlayer).TradeRequest = 0
        TempPlayer(Index).TradeRequest = 0
        Exit Sub
    End If
    
    If TempPlayer(targetPlayer).inParty > 0 Then
        PlayerMsg Index, Trim$(GetPlayerName(targetPlayer)) & " is already in a party.", BrightRed
        PlayerMsg targetPlayer, "You're already in a party.", BrightRed
        Exit Sub
    End If

    ' check if already in a party
    If TempPlayer(Index).inParty > 0 Then
        ' get the partynumber
        partynum = TempPlayer(Index).inParty
        ' got a blank slot?
        For i = 1 To MAX_PARTY_MEMBERS
            If Party(partynum).Member(i) = 0 Then
                'add to the party
                Party(partynum).Member(i) = targetPlayer
                ' recount party
                Party_CountMembers partynum
                ' send everyone's data to everyone
                SendPlayerData_Party partynum
                ' send update to all - including new player
                SendPartyUpdate partynum
                ' Send party vitals to everyone again
                For x = 1 To MAX_PARTY_MEMBERS
                    If Party(partynum).Member(x) > 0 Then
                        SendPartyVitals partynum, Party(partynum).Member(x)
                    End If
                Next
                ' let everyone know they've joined
                PartyMsg partynum, GetPlayerName(targetPlayer) & " has joined the party.", Pink
                ' add them in
                TempPlayer(targetPlayer).inParty = partynum
                Exit Sub
            End If
        Next
        ' no empty slots - let them know
        PlayerMsg Index, "Party is full.", BrightRed
        PlayerMsg targetPlayer, "Party is full.", BrightRed
        Exit Sub
    Else
        ' not in a party. Create one with the new person.
        For i = 1 To MAX_PARTYS
            ' find blank party
            If Not Party(i).Leader > 0 Then
                partynum = i
                Exit For
            End If
        Next
        ' create the party
        Party(partynum).MemberCount = 2
        Party(partynum).Leader = Index
        Party(partynum).Member(1) = Index
        Party(partynum).Member(2) = targetPlayer
        SendPlayerData_Party partynum
        SendPartyUpdate partynum
        SendPartyVitals partynum, Index
        SendPartyVitals partynum, targetPlayer
        ' let them know it's created
        PartyMsg partynum, "Party created.", BrightGreen
        PartyMsg partynum, GetPlayerName(Index) & " has joined the party.", Pink
        PartyMsg partynum, GetPlayerName(targetPlayer) & " has joined the party.", Pink
        ' clear the invitation
        TempPlayer(targetPlayer).partyInvite = 0
        ' add them to the party
        TempPlayer(Index).inParty = partynum
        TempPlayer(targetPlayer).inParty = partynum
        Exit Sub
    End If
End Sub

Public Sub Party_InviteDecline(ByVal Index As Long, ByVal targetPlayer As Long)
    If Not IsConnected(Index) Or Not IsPlaying(Index) Then
        TempPlayer(targetPlayer).TradeRequest = 0
        TempPlayer(Index).TradeRequest = 0
        Exit Sub
    End If
    
    If Not IsConnected(targetPlayer) Or Not IsPlaying(targetPlayer) Then
        TempPlayer(targetPlayer).TradeRequest = 0
        TempPlayer(Index).TradeRequest = 0
        Exit Sub
    End If
    
    PlayerMsg Index, GetPlayerName(targetPlayer) & " has declined to join the party.", BrightRed
    PlayerMsg targetPlayer, "You declined to join the party.", BrightRed
    ' clear the invitation
    TempPlayer(targetPlayer).partyInvite = 0
End Sub

Public Sub Party_CountMembers(ByVal partynum As Long)
Dim i As Long, highIndex As Long, x As Long
    ' find the high index
    For i = MAX_PARTY_MEMBERS To 1 Step -1
        If Party(partynum).Member(i) > 0 Then
            highIndex = i
            Exit For
        End If
    Next
    ' count the members
    For i = 1 To MAX_PARTY_MEMBERS
        ' we've got a blank member
        If Party(partynum).Member(i) = 0 Then
            ' is it lower than the high index?
            If i < highIndex Then
                ' move everyone down a slot
                For x = i To MAX_PARTY_MEMBERS - 1
                    Party(partynum).Member(x) = Party(partynum).Member(x + 1)
                    Party(partynum).Member(x + 1) = 0
                Next
            Else
                ' not lower - highindex is count
                Party(partynum).MemberCount = highIndex
                Exit Sub
            End If
        End If
        ' check if we've reached the max
        If i = MAX_PARTY_MEMBERS Then
            If highIndex = i Then
                Party(partynum).MemberCount = MAX_PARTY_MEMBERS
                Exit Sub
            End If
        End If
    Next
    ' if we're here it means that we need to re-count again
    Party_CountMembers partynum
End Sub

Public Sub Party_ShareExp(ByVal partynum As Long, ByVal exp As Long, ByVal Index As Long, Optional ByVal enemyLevel As Long = 0)
Dim expShare As Long, leftOver As Long, i As Long, tmpIndex As Long

    If Party(partynum).MemberCount <= 0 Then Exit Sub

    ' check if it's worth sharing
    If Not exp >= Party(partynum).MemberCount Then
        ' no party - keep exp for self
        GivePlayerEXP Index, exp, enemyLevel
        Exit Sub
    End If
    
    ' find out the equal share
    expShare = exp \ Party(partynum).MemberCount
    leftOver = exp Mod Party(partynum).MemberCount
    
    ' loop through and give everyone exp
    For i = 1 To MAX_PARTY_MEMBERS
        tmpIndex = Party(partynum).Member(i)
        ' existing member?Kn
        If tmpIndex > 0 Then
            ' playing?
            If IsConnected(tmpIndex) And IsPlaying(tmpIndex) Then
                ' give them their share
                GivePlayerEXP tmpIndex, expShare, enemyLevel
            End If
        End If
    Next
    
    ' give the remainder to a random member
    tmpIndex = Party(partynum).Member(RAND(1, Party(partynum).MemberCount))
    ' give the exp
    If leftOver > 0 Then GivePlayerEXP tmpIndex, leftOver, enemyLevel
End Sub

Public Sub GivePlayerEXP(ByVal Index As Long, ByVal exp As Long, Optional ByVal enemyLevel As Long = 0)
Dim multiplier As Long, partynum As Long, expBonus As Long
    ' no exp
    If exp = 0 Then Exit Sub
    ' rte9
    If Index <= 0 Or Index > MAX_PLAYERS Then Exit Sub
    ' make sure we're not max level
    If Not GetPlayerLevel(Index) >= MAX_LEVELS Then
        ' check for exp deduction
        If enemyLevel > 0 Then
            ' exp deduction
            If enemyLevel <= GetPlayerLevel(Index) - 3 Then
                ' 3 levels lower, exit out
                Exit Sub
            ElseIf enemyLevel <= GetPlayerLevel(Index) - 2 Then
                ' half exp if enemy is 2 levels lower
                exp = exp / 2
            End If
        End If
        ' check if in party
        partynum = TempPlayer(Index).inParty
        If partynum > 0 Then
            If Party(partynum).MemberCount > 1 Then
                multiplier = Party(partynum).MemberCount - 1
                ' multiply the exp
                expBonus = (exp / 100) * (multiplier * 3) ' 3 = 3% per party member
                ' Modify the exp
                exp = exp + expBonus
            End If
        End If
        ' give the exp
        Call SetPlayerExp(Index, GetPlayerExp(Index) + exp)
        SendEXP Index
        SendActionMsg GetPlayerMap(Index), "+" & exp & " EXP", White, 1, (GetPlayerX(Index) * 32), (GetPlayerY(Index) * 32)
        ' check if we've leveled
        CheckPlayerLevelUp Index
    Else
        Call SetPlayerExp(Index, 0)
        SendEXP Index
    End If
End Sub

Public Sub Unique_Item(ByVal Index As Long, ByVal ItemNum As Long)
Dim ClassNum As Long, i As Long

    Select Case Item(ItemNum).Data1
        Case 1 ' Reset Stats
            ClassNum = GetPlayerClass(Index)
            If ClassNum <= 0 Or ClassNum > Max_Classes Then Exit Sub
            ' re-set the actual stats to class defaults
            For i = 1 To Stats.Stat_Count - 1
                SetPlayerStat Index, i, Class(ClassNum).Stat(i)
            Next
            ' give player their points back
            SetPlayerPOINTS Index, (GetPlayerLevel(Index) - 1) * 3
            ' take item
            TakeInvItem Index, ItemNum, 1
            ' let them know we've done it
            PlayerMsg Index, "Your stats have been reset.", BrightGreen
            ' send them their new stats
            SendPlayerData Index
        Case Else ' Exit out otherwise
            Exit Sub
    End Select
End Sub

Public Function hasProficiency(ByVal Index As Long, ByVal proficiency As Long) As Boolean
    Select Case proficiency
        Case 0 ' None
            hasProficiency = True
            Exit Function
        Case 1 ' Heavy
            If GetPlayerClass(Index) = 1 Then
                hasProficiency = True
                Exit Function
            End If
        Case 2 ' Light
            If GetPlayerClass(Index) = 2 Or GetPlayerClass(Index) = 3 Then
                hasProficiency = True
                Exit Function
            End If
    End Select
    hasProficiency = False
End Function

Public Sub CheckProjectile(ByVal i As Long)
    Dim Angle As Long, x As Long, y As Long, n As Long
    Dim Attacker As Long, spellNum As Long
    Dim BaseDamage As Long, Damage As Long
    
    If i < 0 Or i > MAX_PROJECTILE_MAP Then Exit Sub
    
    Attacker = MapProjectile(i).Owner
    spellNum = MapProjectile(i).spellNum
    BaseDamage = Spell(spellNum).Vital
    Damage = BaseDamage + Int(GetPlayerStat(Attacker, Intelligence) / 3)
        
    ' ****** Create Particle ******
    With MapProjectile(i)
        If .Graphic > 0 Then
            If .Speed < 5000 Then
        
                ' ****** Update Position ******
                Angle = DegreeToRadian * Engine_GetAngle(.x, .y, .tX, .tY)
                .x = .x + (Sin(Angle) * ElapsedTime * (.Speed / 1000))
                .y = .y - (Cos(Angle) * ElapsedTime * (.Speed / 1000))
                
                If Spell(spellNum).IsAoE Then
                    Select Case MapProjectile(i).direction
                        Case DIR_UP
                            .xTargetAoE = .x - (Int(Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_UP + 1).x / 2) * PIC_X)
                            .yTargetAoE = .y
                        Case DIR_DOWN
                            .xTargetAoE = .x - (Int(Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_DOWN + 1).x / 2) * PIC_X)
                            .yTargetAoE = .y
                        Case DIR_LEFT, DIR_UP_LEFT, DIR_DOWN_LEFT
                            .xTargetAoE = .x
                            .yTargetAoE = .y - (Int(Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_LEFT + 1).y / 2) * PIC_Y)
                        Case DIR_RIGHT, DIR_UP_RIGHT, DIR_DOWN_RIGHT
                            .xTargetAoE = .x
                            .yTargetAoE = .y - (Int(Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_RIGHT + 1).y / 2) * PIC_Y)
                    End Select
                End If
            End If
        End If
    End With
    
    ' ****** Erase Projectile ******    Seperate Loop For Erasing
    If MapProjectile(i).OwnerType = TARGET_TYPE_PLAYER Then
        ' VERIFICA TYLE_BLOCK e TYLE_RESOURCE
        For x = 0 To Map(GetPlayerMap(Attacker)).MapData.MaxX
            For y = 0 To Map(GetPlayerMap(Attacker)).MapData.MaxY
                If Map(GetPlayerMap(Attacker)).TileData.Tile(x, y).Type = TILE_TYPE_BLOCKED Or Map(GetPlayerMap(Attacker)).TileData.Tile(x, y).Type = TILE_TYPE_RESOURCE Then
                    If Abs(MapProjectile(i).x - (x * PIC_X)) < 20 Then
                        If Abs(MapProjectile(i).y - (y * PIC_Y)) < 20 Then
                            Call ClearProjectile(i)
                            Exit Sub
                        End If
                    End If
                End If
            Next y
        Next x
        
        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
            ' VERIFICA PLAYER NO CAMINHO
            For n = 1 To Player_HighIndex
                If IsPlaying(n) Then
                    If n <> Attacker Then
                        If Abs(MapProjectile(i).x - (GetPlayerX(n) * PIC_X)) < 20 Then
                            If Abs(MapProjectile(i).y - (GetPlayerY(n) * PIC_Y)) < 20 Then
                                If CanPlayerAttackPlayer(Attacker, n, True) Then
                                    If MapProjectile(i).Speed <> 6000 Then
                                        PlayerAttackPlayer Attacker, n, Damage, spellNum
                                        Call ClearProjectile(i)
                                        Exit Sub
                                    Else
                                        If tick > MapProjectile(i).Duration Then
                                            PlayerAttackPlayer Attacker, n, Damage, spellNum
                                            MapProjectile(i).Duration = tick + 1000
                                        End If
                                    End If
                                Else
                                    If MapProjectile(i).Speed <> 6000 Then
                                        Call ClearProjectile(i)
                                        Exit Sub
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            Next
            
            ' VERIFICA NPC NO CAMINHO
            For n = 1 To MAX_MAP_NPCS
                If MapNpc(GetPlayerMap(Attacker)).Npc(n).Num <> 0 Then
                    If Abs(MapProjectile(i).x - (MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X)) < 20 Then
                        If Abs(MapProjectile(i).y - (MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y)) < 20 Then
                            If CanPlayerAttackNpc(Attacker, n, True) Then
                                If MapProjectile(i).Speed <> 6000 Then
                                    PlayerAttackNpc Attacker, n, Damage, spellNum
                                    Call ClearProjectile(i)
                                    Exit Sub
                                Else
                                    If tick > MapProjectile(i).Duration Then
                                        PlayerAttackNpc Attacker, n, Damage, spellNum
                                        MapProjectile(i).Duration = tick + 1000
                                    End If
                                End If
                            Else
                                If MapProjectile(i).Speed <> 6000 Then
                                    Call ClearProjectile(i)
                                    Exit Sub
                                End If
                            End If
                        End If
                    End If
                End If
            Next
        Else ' SE � DANO EM AREA If Not Spell(MapProjectile(i).spellNum).IsAoE Then
            Select Case MapProjectile(i).direction
                Case DIR_UP
                    ' VERIFICA NPC NO CAMINHO
                    For n = 1 To MAX_MAP_NPCS
                        If MapNpc(GetPlayerMap(Attacker)).Npc(n).Num <> 0 Then
                            If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) < Abs(MapProjectile(i).xTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_UP + 1).x * PIC_X)) Then
                                If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) <= MapProjectile(i).yTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) > Abs(MapProjectile(i).yTargetAoE - ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_UP + 1).y - 1) * PIC_Y)) Then
                                    If CanPlayerAttackNpc(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                    
                    ' VERIFICAR SE H� PLAYER NO CAMINHO
                    For n = 1 To Player_HighIndex
                        If n <> Attacker Then
                            If Abs(GetPlayerX(n) * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(GetPlayerX(n) * PIC_X) < Abs(MapProjectile(i).xTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_UP + 1).x * PIC_X)) Then
                                If Abs(GetPlayerY(n) * PIC_Y) <= MapProjectile(i).yTargetAoE And Abs(GetPlayerY(n) * PIC_Y) > Abs(MapProjectile(i).yTargetAoE - ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_UP + 1).y - 1) * PIC_Y)) Then
                                    If CanPlayerAttackPlayer(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                Case DIR_DOWN
                    ' VERIFICA NPC NO CAMINHO
                    For n = 1 To MAX_MAP_NPCS
                        If MapNpc(GetPlayerMap(Attacker)).Npc(n).Num <> 0 Then
                            If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) < Abs(MapProjectile(i).xTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_DOWN + 1).x * PIC_X)) Then
                                If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_DOWN + 1).y - 1) * PIC_Y)) Then
                                    If CanPlayerAttackNpc(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                    
                    ' VERIFICAR SE H� PLAYER NO CAMINHO
                    For n = 1 To Player_HighIndex
                        If n <> Attacker Then
                            If Abs(GetPlayerX(n) * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(GetPlayerX(n) * PIC_X) < Abs(MapProjectile(i).xTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_DOWN + 1).x * PIC_X)) Then
                                If Abs(GetPlayerY(n) * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(GetPlayerY(n) * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_DOWN + 1).y - 1) * PIC_Y)) Then
                                    If CanPlayerAttackPlayer(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                Case DIR_LEFT, DIR_UP_LEFT, DIR_DOWN_LEFT
                    ' VERIFICA NPC NO CAMINHO
                    For n = 1 To MAX_MAP_NPCS
                        If MapNpc(GetPlayerMap(Attacker)).Npc(n).Num <> 0 Then
                            If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_LEFT + 1).y * PIC_Y)) Then
                                If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) <= MapProjectile(i).xTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) > Abs(MapProjectile(i).xTargetAoE - ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_LEFT + 1).x - 1) * PIC_X)) Then
                                    If CanPlayerAttackNpc(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                    
                    ' VERIFICAR SE H� PLAYER NO CAMINHO
                    For n = 1 To Player_HighIndex
                        If n <> Attacker Then
                            If Abs(GetPlayerY(n) * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(GetPlayerY(n) * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_LEFT + 1).y * PIC_Y)) Then
                                If Abs(GetPlayerX(n) * PIC_X) <= MapProjectile(i).xTargetAoE And Abs(GetPlayerX(n) * PIC_X) > Abs(MapProjectile(i).xTargetAoE - ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_LEFT + 1).x - 1) * PIC_X)) Then
                                    If CanPlayerAttackPlayer(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                Case DIR_RIGHT, DIR_UP_RIGHT, DIR_DOWN_RIGHT
                    ' VERIFICA NPC NO CAMINHO
                    For n = 1 To MAX_MAP_NPCS
                        If MapNpc(GetPlayerMap(Attacker)).Npc(n).Num <> 0 Then
                            If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).y * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_RIGHT + 1).y * PIC_Y)) Then
                                If Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(MapNpc(GetPlayerMap(Attacker)).Npc(n).x * PIC_X) < Abs(MapProjectile(i).xTargetAoE + ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_RIGHT + 1).x - 1) * PIC_X)) Then
                                    If CanPlayerAttackNpc(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackNpc Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                    
                    ' VERIFICAR SE H� PLAYER NO CAMINHO
                    For n = 1 To Player_HighIndex
                        If n <> Attacker Then
                            If Abs(GetPlayerY(n) * PIC_Y) >= MapProjectile(i).yTargetAoE And Abs(GetPlayerY(n) * PIC_Y) < Abs(MapProjectile(i).yTargetAoE + (Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_RIGHT + 1).y * PIC_Y)) Then
                                If Abs(GetPlayerX(n) * PIC_X) >= MapProjectile(i).xTargetAoE And Abs(GetPlayerX(n) * PIC_X) < Abs(MapProjectile(i).xTargetAoE + ((Spell(MapProjectile(i).spellNum).DirectionAoE(DIR_RIGHT + 1).x - 1) * PIC_X)) Then
                                    If CanPlayerAttackPlayer(Attacker, n, True) Then
                                        If Not Spell(MapProjectile(i).spellNum).IsAoE Then
                                            If tick >= MapProjectile(i).Duration Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = tick + 1000
                                            End If
                                        Else
                                            If MapProjectile(i).Duration > 0 Then
                                                PlayerAttackPlayer Attacker, n, Damage, spellNum
                                                MapProjectile(i).Duration = MapProjectile(i).Duration - 1
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
            End Select
        End If
        
        ' VERIFICA SE CHEGOU AO ALVO
        If Abs(MapProjectile(i).x - MapProjectile(i).tX) < 20 Then
            If Abs(MapProjectile(i).y - MapProjectile(i).tY) < 20 Then
                If MapProjectile(i).Speed <> 6000 Then
                        Call ClearProjectile(i)
                        Exit Sub
                End If
            End If
        End If
        
        ' VERIFICAR SE � UMA TRAP E O TEMPO DE SPAWN ACABOU
        If MapProjectile(i).Speed >= 5000 Then
            If tick >= MapProjectile(i).Duration Then
                Call ClearProjectile(i)
                Exit Sub
            End If
        End If
        
    End If
End Sub
