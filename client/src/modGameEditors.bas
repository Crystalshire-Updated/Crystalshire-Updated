Attribute VB_Name = "modGameEditors"
Option Explicit

' Temp event storage
Public tmpEvent As EventRec
Public tmpItem As ItemRec
Public tmpSpell As SpellRec
Public tmpNPC As NpcRec

Public curPageNum As Long
Public curCommand As Long
Public GraphicSelX As Long
Public GraphicSelY As Long

' ////////////////
' // Map Editor //
' ////////////////
Public Sub MapEditorInit()
    Dim I As Long
    ' set the width
    frmEditor_Map.Width = 9585
    ' we're in the map editor
    InMapEditor = True
    ' show the form
    frmEditor_Map.visible = True
    ' set the scrolly bars
    frmEditor_Map.scrlTileSet.Max = Count_Tileset
    frmEditor_Map.fraTileSet.caption = "Tileset: " & 1
    frmEditor_Map.scrlTileSet.value = 1
    ' set the scrollbars
    frmEditor_Map.scrlPictureY.Max = (frmEditor_Map.picBackSelect.Height \ PIC_Y) - (frmEditor_Map.picBack.Height \ PIC_Y)
    frmEditor_Map.scrlPictureX.Max = (frmEditor_Map.picBackSelect.Width \ PIC_X) - (frmEditor_Map.picBack.Width \ PIC_X)
    shpSelectedWidth = 32
    shpSelectedHeight = 32
    MapEditorTileScroll
    ' set shops for the shop attribute
    frmEditor_Map.cmbShop.AddItem "None"

    For I = 1 To MAX_SHOPS
        frmEditor_Map.cmbShop.AddItem I & ": " & Shop(I).name
    Next

    ' we're not in a shop
    frmEditor_Map.cmbShop.ListIndex = 0
End Sub

Public Sub MapEditorProperties()
    Dim X As Long, I As Long, tmpNum As Long

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_MapProperties.lstMusic.Clear
    frmEditor_MapProperties.lstMusic.AddItem "None."
    tmpNum = UBound(musicCache)

    For I = 1 To tmpNum
        frmEditor_MapProperties.lstMusic.AddItem musicCache(I)
    Next

    ' finished populating
    With frmEditor_MapProperties
        .scrlBoss.Max = MAX_MAP_NPCS
        .txtName.text = Trim$(map.MapData.name)

        ' find the music we have set
        If .lstMusic.ListCount >= 0 Then
            .lstMusic.ListIndex = 0
            tmpNum = .lstMusic.ListCount

            For I = 0 To tmpNum - 1

                If .lstMusic.list(I) = Trim$(map.MapData.Music) Then
                    .lstMusic.ListIndex = I
                End If

            Next

        End If

        ' rest of it
        .txtUp.text = CStr(map.MapData.Up)
        .txtDown.text = CStr(map.MapData.Down)
        .txtLeft.text = CStr(map.MapData.Left)
        .txtRight.text = CStr(map.MapData.Right)
        .cmbMoral.ListIndex = map.MapData.Moral
        .txtBootMap.text = CStr(map.MapData.BootMap)
        .txtBootX.text = CStr(map.MapData.BootX)
        .txtBootY.text = CStr(map.MapData.BootY)
        .CmbWeather.ListIndex = map.MapData.Weather
        .scrlWeatherIntensity.value = map.MapData.WeatherIntensity
        
        .ScrlFog.value = map.MapData.Fog
        .ScrlFogSpeed.value = map.MapData.FogSpeed
        .scrlFogOpacity.value = map.MapData.FogOpacity
        
        .scrlRed.value = map.MapData.Red
        .scrlGreen.value = map.MapData.Green
        .scrlBlue.value = map.MapData.Blue
        .scrlAlpha.value = map.MapData.Alpha
        .scrlBoss = map.MapData.BossNpc
        ' show the map npcs
        .lstNpcs.Clear

        For X = 1 To MAX_MAP_NPCS

            If map.MapData.Npc(X) > 0 Then
                .lstNpcs.AddItem X & ": " & Trim$(Npc(map.MapData.Npc(X)).name)
            Else
                .lstNpcs.AddItem X & ": No NPC"
            End If

        Next

        .lstNpcs.ListIndex = 0
        ' show the npc selection combo
        .cmbNpc.Clear
        .cmbNpc.AddItem "No NPC"

        For X = 1 To MAX_NPCS
            .cmbNpc.AddItem X & ": " & Trim$(Npc(X).name)
        Next

        ' set the combo box properly
        Dim tmpString() As String
        Dim NpcNum As Long
        tmpString = Split(.lstNpcs.list(.lstNpcs.ListIndex))
        NpcNum = CLng(Left$(tmpString(0), Len(tmpString(0)) - 1))
        .cmbNpc.ListIndex = map.MapData.Npc(NpcNum)
        ' show the current map
        .lblMap.caption = "Current map: " & GetPlayerMap(MyIndex)
        .txtMaxX.text = map.MapData.MaxX
        .txtMaxY.text = map.MapData.MaxY
    End With

End Sub

Public Sub MapEditorSetTile(ByVal X As Long, ByVal Y As Long, ByVal CurLayer As Long, Optional ByVal multitile As Boolean = False, Optional ByVal theAutotile As Byte = 0)
    Dim X2 As Long, Y2 As Long

    If theAutotile > 0 Then
        With map.TileData.Tile(X, Y)
            ' set layer
            .Layer(CurLayer).X = EditorTileX
            .Layer(CurLayer).Y = EditorTileY
            .Layer(CurLayer).tileSet = frmEditor_Map.scrlTileSet.value
            .Autotile(CurLayer) = theAutotile
            cacheRenderState X, Y, CurLayer
        End With
        ' do a re-init so we can see our changes
        initAutotiles
        Exit Sub
    End If

    If Not multitile Then ' single
        With map.TileData.Tile(X, Y)
            ' set layer
            .Layer(CurLayer).X = EditorTileX
            .Layer(CurLayer).Y = EditorTileY
            .Layer(CurLayer).tileSet = frmEditor_Map.scrlTileSet.value
            .Autotile(CurLayer) = 0
            cacheRenderState X, Y, CurLayer
        End With
    Else ' multitile
        Y2 = 0 ' starting tile for y axis
        For Y = CurY To CurY + EditorTileHeight - 1
            X2 = 0 ' re-set x count every y loop
            For X = CurX To CurX + EditorTileWidth - 1
                If X >= 0 And X <= map.MapData.MaxX Then
                    If Y >= 0 And Y <= map.MapData.MaxY Then
                        With map.TileData.Tile(X, Y)
                            .Layer(CurLayer).X = EditorTileX + X2
                            .Layer(CurLayer).Y = EditorTileY + Y2
                            .Layer(CurLayer).tileSet = frmEditor_Map.scrlTileSet.value
                            .Autotile(CurLayer) = 0
                            cacheRenderState X, Y, CurLayer
                        End With
                    End If
                End If
                X2 = X2 + 1
            Next
            Y2 = Y2 + 1
        Next
    End If

End Sub

Public Sub MapEditorMouseDown(ByVal Button As Integer, ByVal X As Long, ByVal Y As Long, Optional ByVal movedMouse As Boolean = True)
    Dim I As Long
    Dim CurLayer As Long

    ' find which layer we're on
    For I = 1 To MapLayer.Layer_Count - 1

        If frmEditor_Map.optLayer(I).value Then
            CurLayer = I
            Exit For
        End If

    Next

    If Not isInBounds Then Exit Sub
    If Button = vbLeftButton Then
        If frmEditor_Map.optLayers.value Then

            ' no autotiling
            If EditorTileWidth = 1 And EditorTileHeight = 1 Then 'single tile
                MapEditorSetTile CurX, CurY, CurLayer, , frmEditor_Map.scrlAutotile.value
            Else ' multi tile!

                If frmEditor_Map.scrlAutotile.value = 0 Then
                    MapEditorSetTile CurX, CurY, CurLayer, True
                Else
                    MapEditorSetTile CurX, CurY, CurLayer, , frmEditor_Map.scrlAutotile.value
                End If
            End If

        ElseIf frmEditor_Map.optAttribs.value Then

            With map.TileData.Tile(CurX, CurY)

                ' blocked tile
                If frmEditor_Map.optBlocked.value Then .Type = TILE_TYPE_BLOCKED

                ' warp tile
                If frmEditor_Map.optWarp.value Then
                    .Type = TILE_TYPE_WARP
                    .Data1 = EditorWarpMap
                    .Data2 = EditorWarpX
                    .Data3 = EditorWarpY
                    .Data4 = EditorWarpFall
                    .Data5 = 0
                End If

                ' item spawn
                If frmEditor_Map.optItem.value Then
                    .Type = TILE_TYPE_ITEM
                    .Data1 = ItemEditorNum
                    .Data2 = ItemEditorValue
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' npc avoid
                If frmEditor_Map.optNpcAvoid.value Then
                    .Type = TILE_TYPE_NPCAVOID
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' key
                If frmEditor_Map.optKey.value Then
                    .Type = TILE_TYPE_KEY
                    .Data1 = KeyEditorNum
                    .Data2 = KeyEditorTake
                    .Data3 = KeyEditorTime
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' key open
                If frmEditor_Map.optKeyOpen.value Then
                    .Type = TILE_TYPE_KEYOPEN
                    .Data1 = KeyOpenEditorX
                    .Data2 = KeyOpenEditorY
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' resource
                If frmEditor_Map.optResource.value Then
                    .Type = TILE_TYPE_RESOURCE
                    .Data1 = ResourceEditorNum
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' door
                If frmEditor_Map.optDoor.value Then
                    .Type = TILE_TYPE_DOOR
                    .Data1 = EditorWarpMap
                    .Data2 = EditorWarpX
                    .Data3 = EditorWarpY
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' npc spawn
                If frmEditor_Map.optNpcSpawn.value Then
                    .Type = TILE_TYPE_NPCSPAWN
                    .Data1 = SpawnNpcNum
                    .Data2 = SpawnNpcDir
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' shop
                If frmEditor_Map.optShop.value Then
                    .Type = TILE_TYPE_SHOP
                    .Data1 = EditorShop
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' bank
                If frmEditor_Map.optBank.value Then
                    .Type = TILE_TYPE_BANK
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' heal
                If frmEditor_Map.optHeal.value Then
                    .Type = TILE_TYPE_HEAL
                    .Data1 = MapEditorHealType
                    .Data2 = MapEditorHealAmount
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' trap
                If frmEditor_Map.optTrap.value Then
                    .Type = TILE_TYPE_TRAP
                    .Data1 = MapEditorHealAmount
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' slide
                If frmEditor_Map.optSlide.value Then
                    .Type = TILE_TYPE_SLIDE
                    .Data1 = MapEditorSlideDir
                    .Data2 = 0
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If

                ' chat
                If frmEditor_Map.optChat.value Then
                    .Type = TILE_TYPE_CHAT
                    .Data1 = MapEditorChatNpc
                    .Data2 = MapEditorChatDir
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If
                
                ' appear
                If frmEditor_Map.optAppear.value Then
                    .Type = TILE_TYPE_APPEAR
                    .Data1 = EditorAppearRange
                    .Data2 = EditorAppearBottom
                    .Data3 = 0
                    .Data4 = 0
                    .Data5 = 0
                End If
            End With

        ElseIf frmEditor_Map.optBlock.value Then

            If movedMouse Then Exit Sub
            ' find what tile it is
            X = X - ((X \ 32) * 32)
            Y = Y - ((Y \ 32) * 32)

            ' see if it hits an arrow
            For I = 1 To 4
                If X >= DirArrowX(I) And X <= DirArrowX(I) + 8 Then
                    If Y >= DirArrowY(I) And Y <= DirArrowY(I) + 8 Then
                        ' flip the value.
                        setDirBlock map.TileData.Tile(CurX, CurY).DirBlock, CByte(I), Not isDirBlocked(map.TileData.Tile(CurX, CurY).DirBlock, CByte(I))
                        Exit Sub
                    End If
                End If
            Next
        End If
    End If

    If Button = vbRightButton Then
        If frmEditor_Map.optLayers.value Then

            With map.TileData.Tile(CurX, CurY)
                ' clear layer
                .Layer(CurLayer).X = 0
                .Layer(CurLayer).Y = 0
                .Layer(CurLayer).tileSet = 0

                If .Autotile(CurLayer) > 0 Then
                    .Autotile(CurLayer) = 0
                    ' do a re-init so we can see our changes
                    initAutotiles
                End If

                cacheRenderState X, Y, CurLayer
            End With

        ElseIf frmEditor_Map.optAttribs.value Then

            With map.TileData.Tile(CurX, CurY)
                ' clear attribute
                .Type = 0
                .Data1 = 0
                .Data2 = 0
                .Data3 = 0
                .Data4 = 0
                .Data5 = 0
            End With

        End If
    End If

    CacheResources
End Sub

Public Sub MapEditorChooseTile(Button As Integer, X As Single, Y As Single)

    If Button = vbLeftButton Then
        EditorTileWidth = 1
        EditorTileHeight = 1
        EditorTileX = X \ PIC_X
        EditorTileY = Y \ PIC_Y
        shpSelectedTop = EditorTileY * PIC_Y
        shpSelectedLeft = EditorTileX * PIC_X
        shpSelectedWidth = PIC_X
        shpSelectedHeight = PIC_Y
    End If

End Sub

Public Sub MapEditorDrag(Button As Integer, X As Single, Y As Single)

    If Button = vbLeftButton Then
        ' convert the pixel number to tile number
        X = (X \ PIC_X) + 1
        Y = (Y \ PIC_Y) + 1

        ' check it's not out of bounds
        If X < 0 Then X = 0
        If X > frmEditor_Map.picBackSelect.Width / PIC_X Then X = frmEditor_Map.picBackSelect.Width / PIC_X
        If Y < 0 Then Y = 0
        If Y > frmEditor_Map.picBackSelect.Height / PIC_Y Then Y = frmEditor_Map.picBackSelect.Height / PIC_Y

        ' find out what to set the width + height of map editor to
        If X > EditorTileX Then ' drag right
            EditorTileWidth = X - EditorTileX
        Else ' drag left
            ' TO DO
        End If

        If Y > EditorTileY Then ' drag down
            EditorTileHeight = Y - EditorTileY
        Else ' drag up
            ' TO DO
        End If

        shpSelectedWidth = EditorTileWidth * PIC_X
        shpSelectedHeight = EditorTileHeight * PIC_Y
    End If

End Sub

Public Sub NudgeMap(ByVal theDir As Byte)
Dim X As Long, Y As Long, I As Long
    
    ' if left or right
    If theDir = DIR_UP Or theDir = DIR_LEFT Then
        For Y = 0 To map.MapData.MaxY
            For X = 0 To map.MapData.MaxX
                Select Case theDir
                    Case DIR_UP
                        ' move up all one
                        If Y > 0 Then CopyTile map.TileData.Tile(X, Y), map.TileData.Tile(X, Y - 1)
                    Case DIR_LEFT
                        ' move left all one
                        If X > 0 Then CopyTile map.TileData.Tile(X, Y), map.TileData.Tile(X - 1, Y)
                End Select
            Next
        Next
    Else
        For Y = map.MapData.MaxY To 0 Step -1
            For X = map.MapData.MaxX To 0 Step -1
                Select Case theDir
                    Case DIR_DOWN
                        ' move down all one
                        If Y < map.MapData.MaxY Then CopyTile map.TileData.Tile(X, Y), map.TileData.Tile(X, Y + 1)
                    Case DIR_RIGHT
                        ' move right all one
                        If X < map.MapData.MaxX Then CopyTile map.TileData.Tile(X, Y), map.TileData.Tile(X + 1, Y)
                End Select
            Next
        Next
    End If
    
    ' do events
    If map.TileData.EventCount > 0 Then
        For I = 1 To map.TileData.EventCount
            Select Case theDir
                Case DIR_UP
                    map.TileData.Events(I).Y = map.TileData.Events(I).Y - 1
                Case DIR_LEFT
                    map.TileData.Events(I).X = map.TileData.Events(I).X - 1
                Case DIR_RIGHT
                    map.TileData.Events(I).X = map.TileData.Events(I).X + 1
                Case DIR_DOWN
                    map.TileData.Events(I).Y = map.TileData.Events(I).Y + 1
            End Select
        Next
    End If
    
    initAutotiles
End Sub

Public Sub CopyTile(ByRef origTile As TileRec, ByRef newTile As TileRec)
Dim tilesize As Long
    tilesize = LenB(origTile)
    CopyMemory ByVal VarPtr(newTile), ByVal VarPtr(origTile), tilesize
    ZeroMemory ByVal VarPtr(origTile), tilesize
End Sub

Public Sub MapEditorTileScroll()

    ' horizontal scrolling
    If frmEditor_Map.picBackSelect.Width < frmEditor_Map.picBack.Width Then
        frmEditor_Map.scrlPictureX.enabled = False
    Else
        frmEditor_Map.scrlPictureX.enabled = True
        frmEditor_Map.picBackSelect.Left = (frmEditor_Map.scrlPictureX.value * PIC_X) * -1
    End If

    ' vertical scrolling
    If frmEditor_Map.picBackSelect.Height < frmEditor_Map.picBack.Height Then
        frmEditor_Map.scrlPictureY.enabled = False
    Else
        frmEditor_Map.scrlPictureY.enabled = True
        frmEditor_Map.picBackSelect.Top = (frmEditor_Map.scrlPictureY.value * PIC_Y) * -1
    End If

End Sub

Public Sub MapEditorSend()
    Call SendMap
    InMapEditor = False
    'Unload frmEditor_Map
    frmEditor_Map.Hide
End Sub

Public Sub MapEditorCancel()
    InMapEditor = False
    LoadMap GetPlayerMap(MyIndex)
    initAutotiles
    'Unload frmEditor_Map
    frmEditor_Map.Hide
End Sub

Public Sub MapEditorClearLayer()
    Dim I As Long
    Dim X As Long
    Dim Y As Long
    Dim CurLayer As Long

    ' find which layer we're on
    For I = 1 To MapLayer.Layer_Count - 1

        If frmEditor_Map.optLayer(I).value Then
            CurLayer = I
            Exit For
        End If

    Next

    If CurLayer = 0 Then Exit Sub

    ' ask to clear layer
    If MsgBox("Are you sure you wish to clear this layer?", vbYesNo, GAME_NAME) = vbYes Then

        For X = 0 To map.MapData.MaxX
            For Y = 0 To map.MapData.MaxY
                map.TileData.Tile(X, Y).Layer(CurLayer).X = 0
                map.TileData.Tile(X, Y).Layer(CurLayer).Y = 0
                map.TileData.Tile(X, Y).Layer(CurLayer).tileSet = 0
                cacheRenderState X, Y, CurLayer
            Next
        Next

        ' re-cache autos
        initAutotiles
    End If

End Sub

Public Sub MapEditorFillLayer()
    Dim I As Long
    Dim X As Long
    Dim Y As Long
    Dim CurLayer As Long

    ' find which layer we're on
    For I = 1 To MapLayer.Layer_Count - 1

        If frmEditor_Map.optLayer(I).value Then
            CurLayer = I
            Exit For
        End If

    Next

    ' Ground layer
    If MsgBox("Are you sure you wish to fill this layer?", vbYesNo, GAME_NAME) = vbYes Then

        For X = 0 To map.MapData.MaxX
            For Y = 0 To map.MapData.MaxY
                map.TileData.Tile(X, Y).Layer(CurLayer).X = EditorTileX
                map.TileData.Tile(X, Y).Layer(CurLayer).Y = EditorTileY
                map.TileData.Tile(X, Y).Layer(CurLayer).tileSet = frmEditor_Map.scrlTileSet.value
                map.TileData.Tile(X, Y).Autotile(CurLayer) = frmEditor_Map.scrlAutotile.value
                cacheRenderState X, Y, CurLayer
            Next
        Next

        ' now cache the positions
        initAutotiles
    End If

End Sub

Public Sub MapEditorClearAttribs()
    Dim X As Long
    Dim Y As Long

    If MsgBox("Are you sure you wish to clear the attributes on this map?", vbYesNo, GAME_NAME) = vbYes Then

        For X = 0 To map.MapData.MaxX
            For Y = 0 To map.MapData.MaxY
                map.TileData.Tile(X, Y).Type = 0
            Next
        Next

    End If

End Sub

Public Sub MapEditorLeaveMap()

    If InMapEditor Then
        If MsgBox("Save changes to current map?", vbYesNo) = vbYes Then
            Call MapEditorSend
        Else
            Call MapEditorCancel
        End If
    End If

End Sub

' /////////////////
' // Item Editor //
' /////////////////
Public Sub ItemEditorInit()
    Dim I As Long, SoundSet As Boolean, tmpNum As Long

    If frmEditor_Item.visible = False Then Exit Sub
    EditorIndex = frmEditor_Item.lstIndex.ListIndex + 1

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_Item.cmbSound.Clear
    frmEditor_Item.cmbSound.AddItem "None."
    tmpNum = UBound(soundCache)

    For I = 1 To tmpNum
        frmEditor_Item.cmbSound.AddItem soundCache(I)
    Next

    ' finished populating
    With Item(EditorIndex)
        frmEditor_Item.txtName.text = Trim$(.name)

        If .Pic > frmEditor_Item.scrlPic.Max Then .Pic = 0
        frmEditor_Item.scrlPic.value = .Pic
        frmEditor_Item.cmbType.ListIndex = .Type
        frmEditor_Item.scrlAnim.value = .Animation
        frmEditor_Item.txtDesc.text = Trim$(.Desc)

        ' find the sound we have set
        If frmEditor_Item.cmbSound.ListCount >= 0 Then
            tmpNum = frmEditor_Item.cmbSound.ListCount

            For I = 0 To tmpNum

                If frmEditor_Item.cmbSound.list(I) = Trim$(.sound) Then
                    frmEditor_Item.cmbSound.ListIndex = I
                    SoundSet = True
                End If

            Next

            If Not SoundSet Or frmEditor_Item.cmbSound.ListIndex = -1 Then frmEditor_Item.cmbSound.ListIndex = 0
        End If

        ' Type specific settings
        If (frmEditor_Item.cmbType.ListIndex >= ITEM_TYPE_WEAPON) And (frmEditor_Item.cmbType.ListIndex <= ITEM_TYPE_SHIELD) Then
            frmEditor_Item.fraEquipment.visible = True
            frmEditor_Item.scrlDamage.value = .Data2
            frmEditor_Item.cmbTool.ListIndex = .Data3

            If .speed < 100 Then .speed = 100
            frmEditor_Item.scrlSpeed.value = .speed

            ' loop for stats
            For I = 1 To Stats.Stat_Count - 1
                frmEditor_Item.scrlStatBonus(I).value = .Add_Stat(I)
            Next

            If Not .Paperdoll > Count_Paperdoll Then frmEditor_Item.scrlPaperdoll = .Paperdoll
            frmEditor_Item.scrlProf.value = .proficiency
        Else
            frmEditor_Item.fraEquipment.visible = False
        End If

        If frmEditor_Item.cmbType.ListIndex = ITEM_TYPE_CONSUME Then
            frmEditor_Item.fraVitals.visible = True
            frmEditor_Item.scrlAddHp.value = .AddHP
            frmEditor_Item.scrlAddMP.value = .AddMP
            frmEditor_Item.scrlAddExp.value = .AddEXP
            frmEditor_Item.scrlCastSpell.value = .CastSpell
            frmEditor_Item.chkInstant.value = .instaCast
        Else
            frmEditor_Item.fraVitals.visible = False
        End If

        If (frmEditor_Item.cmbType.ListIndex = ITEM_TYPE_SPELL) Then
            frmEditor_Item.fraSpell.visible = True
            frmEditor_Item.scrlSpell.value = .Data1
        Else
            frmEditor_Item.fraSpell.visible = False
        End If

        If frmEditor_Item.cmbType.ListIndex = ITEM_TYPE_FOOD Then
            If .HPorSP = 2 Then
                frmEditor_Item.optSP.value = True
            Else
                frmEditor_Item.optHP.value = True
            End If

            frmEditor_Item.scrlFoodHeal = .FoodPerTick
            frmEditor_Item.scrlFoodTick = .FoodTickCount
            frmEditor_Item.scrlFoodInterval = .FoodInterval
            frmEditor_Item.fraFood.visible = True
        Else
            frmEditor_Item.fraFood.visible = False
        End If

        ' Basic requirements
        frmEditor_Item.scrlAccessReq.value = .AccessReq
        frmEditor_Item.scrlLevelReq.value = .LevelReq

        ' loop for stats
        For I = 1 To Stats.Stat_Count - 1
            frmEditor_Item.scrlStatReq(I).value = .Stat_Req(I)
        Next

        ' Build cmbClassReq
        frmEditor_Item.cmbClassReq.Clear
        frmEditor_Item.cmbClassReq.AddItem "None"

        For I = 1 To Max_Classes
            frmEditor_Item.cmbClassReq.AddItem Class(I).name
        Next

        frmEditor_Item.cmbClassReq.ListIndex = .ClassReq
        ' Info
        frmEditor_Item.scrlPrice.value = .Price
        frmEditor_Item.cmbBind.ListIndex = .BindType
        frmEditor_Item.scrlRarity.value = .Rarity
        EditorIndex = frmEditor_Item.lstIndex.ListIndex + 1
    End With

    Item_Changed(EditorIndex) = True
End Sub

Public Sub ItemEditorOk()
    Dim I As Long

    For I = 1 To MAX_ITEMS

        If Item_Changed(I) Then
            Call SendSaveItem(I)
        End If

    Next

    Unload frmEditor_Item
    Editor = 0
    ClearChanged_Item
End Sub

Sub ItemEditorCopy()
    CopyMemory ByVal VarPtr(tmpItem), ByVal VarPtr(Item(EditorIndex)), LenB(Item(EditorIndex))
End Sub

Sub ItemEditorPaste()
    CopyMemory ByVal VarPtr(Item(EditorIndex)), ByVal VarPtr(tmpItem), LenB(tmpItem)
    ItemEditorInit
    frmEditor_Item.txtName_Validate False
End Sub

Public Sub ItemEditorCancel()
    Editor = 0
    Unload frmEditor_Item
    ClearChanged_Item
    ClearItems
    SendRequestItems
End Sub

Public Sub ClearChanged_Item()
    ZeroMemory Item_Changed(1), MAX_ITEMS * 2 ' 2 = boolean length
End Sub

' /////////////////
' // Animation Editor //
' /////////////////
Public Sub AnimationEditorInit()
    Dim I As Long
    Dim SoundSet As Boolean, tmpNum As Long

    If frmEditor_Animation.visible = False Then Exit Sub
    EditorIndex = frmEditor_Animation.lstIndex.ListIndex + 1

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_Animation.cmbSound.Clear
    frmEditor_Animation.cmbSound.AddItem "None."
    tmpNum = UBound(soundCache)

    For I = 1 To tmpNum
        frmEditor_Animation.cmbSound.AddItem soundCache(I)
    Next

    ' finished populating
    With Animation(EditorIndex)
        frmEditor_Animation.txtName.text = Trim$(.name)

        ' find the sound we have set
        If frmEditor_Animation.cmbSound.ListCount >= 0 Then
            tmpNum = frmEditor_Animation.cmbSound.ListCount

            For I = 0 To tmpNum

                If frmEditor_Animation.cmbSound.list(I) = Trim$(.sound) Then
                    frmEditor_Animation.cmbSound.ListIndex = I
                    SoundSet = True
                End If

            Next

            If Not SoundSet Or frmEditor_Animation.cmbSound.ListIndex = -1 Then frmEditor_Animation.cmbSound.ListIndex = 0
        End If

        For I = 0 To 1
            frmEditor_Animation.scrlSprite(I).value = .sprite(I)
            frmEditor_Animation.scrlFrameCount(I).value = .Frames(I)
            frmEditor_Animation.scrlLoopCount(I).value = .LoopCount(I)

            If .looptime(I) > 0 Then
                frmEditor_Animation.scrlLoopTime(I).value = .looptime(I)
            Else
                frmEditor_Animation.scrlLoopTime(I).value = 45
            End If

        Next

        EditorIndex = frmEditor_Animation.lstIndex.ListIndex + 1
    End With

    Animation_Changed(EditorIndex) = True
End Sub

Public Sub AnimationEditorOk()
    Dim I As Long

    For I = 1 To MAX_ANIMATIONS

        If Animation_Changed(I) Then
            Call SendSaveAnimation(I)
        End If

    Next

    Unload frmEditor_Animation
    Editor = 0
    ClearChanged_Animation
End Sub

Public Sub AnimationEditorCancel()
    Editor = 0
    Unload frmEditor_Animation
    ClearChanged_Animation
    ClearAnimations
    SendRequestAnimations
End Sub

Public Sub ClearChanged_Animation()
    ZeroMemory Animation_Changed(1), MAX_ANIMATIONS * 2 ' 2 = boolean length
End Sub

' ////////////////
' // Npc Editor //
' ////////////////
Public Sub NpcEditorInit()
    Dim I As Long
    Dim SoundSet As Boolean

    If frmEditor_NPC.visible = False Then Exit Sub
    EditorIndex = frmEditor_NPC.lstIndex.ListIndex + 1

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_NPC.cmbSound.Clear
    frmEditor_NPC.cmbSound.AddItem "None."

    For I = 1 To UBound(soundCache)
        frmEditor_NPC.cmbSound.AddItem soundCache(I)
    Next

    ' finished populating
    With frmEditor_NPC
        .scrlDrop.Max = MAX_NPC_DROPS
        .scrlSpell.Max = MAX_NPC_SPELLS
        .txtName.text = Trim$(Npc(EditorIndex).name)
        .txtAttackSay.text = Trim$(Npc(EditorIndex).AttackSay)

        If Npc(EditorIndex).sprite < 0 Or Npc(EditorIndex).sprite > .scrlSprite.Max Then Npc(EditorIndex).sprite = 0
        .scrlSprite.value = Npc(EditorIndex).sprite
        .txtSpawnSecs.text = CStr(Npc(EditorIndex).SpawnSecs)
        .cmbBehaviour.ListIndex = Npc(EditorIndex).Behaviour
        .scrlRange.value = Npc(EditorIndex).Range
        .txtHP.text = Npc(EditorIndex).HP
        .txtEXP.text = Npc(EditorIndex).EXP
        .txtLevel.text = Npc(EditorIndex).Level
        .txtDamage.text = Npc(EditorIndex).Damage
        .scrlConv.value = Npc(EditorIndex).Conv
        .scrlAnimation.value = Npc(EditorIndex).Animation

        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then

            For I = 0 To .cmbSound.ListCount

                If .cmbSound.list(I) = Trim$(Npc(EditorIndex).sound) Then
                    .cmbSound.ListIndex = I
                    SoundSet = True
                End If

            Next

            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If

        For I = 1 To Stats.Stat_Count - 1
            .scrlStat(I).value = Npc(EditorIndex).Stat(I)
        Next

        ' show 1 data
        .scrlDrop.value = 1
        .scrlSpell.value = 1
    End With

    NPC_Changed(EditorIndex) = True
End Sub

Public Sub NpcEditorOk()
    Dim I As Long

    For I = 1 To MAX_NPCS

        If NPC_Changed(I) Then
            Call SendSaveNpc(I)
        End If

    Next

    Unload frmEditor_NPC
    Editor = 0
    ClearChanged_NPC
End Sub

Sub NpcEditorCopy()
    CopyMemory ByVal VarPtr(tmpNPC), ByVal VarPtr(Npc(EditorIndex)), LenB(Npc(EditorIndex))
End Sub

Sub NpcEditorPaste()
    CopyMemory ByVal VarPtr(Npc(EditorIndex)), ByVal VarPtr(tmpNPC), LenB(tmpNPC)
    NpcEditorInit
    frmEditor_NPC.txtName_Validate False
End Sub

Public Sub NpcEditorCancel()
    Editor = 0
    Unload frmEditor_NPC
    ClearChanged_NPC
    ClearNpcs
    SendRequestNPCS
End Sub

Public Sub ClearChanged_NPC()
    ZeroMemory NPC_Changed(1), MAX_NPCS * 2 ' 2 = boolean length
End Sub

' /////////////////
' // Conv Editor //
' /////////////////
Public Sub ConvEditorInit()
    Dim I As Long, n As Long

    If frmEditor_Conv.visible = False Then Exit Sub
    EditorIndex = frmEditor_Conv.lstIndex.ListIndex + 1

    With frmEditor_Conv
        .txtName.text = Trim$(Conv(EditorIndex).name)

        If Conv(EditorIndex).chatCount = 0 Then
            Conv(EditorIndex).chatCount = 1
            ReDim Conv(EditorIndex).Conv(1 To Conv(EditorIndex).chatCount)
        End If

        For n = 1 To 4
            .cmbReply(n).Clear
            .cmbReply(n).AddItem "None"

            For I = 1 To Conv(EditorIndex).chatCount
                .cmbReply(n).AddItem I
            Next
        Next

        .scrlChatCount = Conv(EditorIndex).chatCount
        .scrlConv.Max = Conv(EditorIndex).chatCount
        .scrlConv.value = 1
        .txtConv = Conv(EditorIndex).Conv(.scrlConv.value).Conv

        For I = 1 To 4
            .txtReply(I).text = Conv(EditorIndex).Conv(.scrlConv.value).rText(I)
            .cmbReply(I).ListIndex = Conv(EditorIndex).Conv(.scrlConv.value).rTarget(I)
        Next

        .cmbEvent.ListIndex = Conv(EditorIndex).Conv(.scrlConv.value).Event
        .scrlData1.value = Conv(EditorIndex).Conv(.scrlConv.value).Data1
        .scrlData2.value = Conv(EditorIndex).Conv(.scrlConv.value).Data2
        .scrlData3.value = Conv(EditorIndex).Conv(.scrlConv.value).Data3
    End With

    Conv_Changed(EditorIndex) = True
End Sub

Public Sub ConvEditorOk()
    Dim I As Long

    For I = 1 To MAX_CONVS

        If Conv_Changed(I) Then
            Call SendSaveConv(I)
        End If

    Next

    Unload frmEditor_Conv
    Editor = 0
    ClearChanged_Conv
End Sub

Public Sub ConvEditorCancel()
    Editor = 0
    Unload frmEditor_Conv
    ClearChanged_Conv
    ClearConvs
    SendRequestConvs
End Sub

Public Sub ClearChanged_Conv()
    ZeroMemory Conv_Changed(1), MAX_CONVS * 2 ' 2 = boolean length
End Sub

' ////////////////
' // Resource Editor //
' ////////////////
Public Sub ResourceEditorInit()
    Dim I As Long
    Dim SoundSet As Boolean

    If frmEditor_Resource.visible = False Then Exit Sub
    EditorIndex = frmEditor_Resource.lstIndex.ListIndex + 1

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_Resource.cmbSound.Clear
    frmEditor_Resource.cmbSound.AddItem "None."

    For I = 1 To UBound(soundCache)
        frmEditor_Resource.cmbSound.AddItem soundCache(I)
    Next

    ' finished populating
    With frmEditor_Resource
        .scrlExhaustedPic.Max = Count_Resource
        .scrlNormalPic.Max = Count_Resource
        .scrlAnimation.Max = MAX_ANIMATIONS
        .txtName.text = Trim$(Resource(EditorIndex).name)
        .txtMessage.text = Trim$(Resource(EditorIndex).SuccessMessage)
        .txtMessage2.text = Trim$(Resource(EditorIndex).EmptyMessage)
        .cmbType.ListIndex = Resource(EditorIndex).ResourceType
        .scrlNormalPic.value = Resource(EditorIndex).ResourceImage
        .scrlExhaustedPic.value = Resource(EditorIndex).ExhaustedImage
        .scrlReward.value = Resource(EditorIndex).ItemReward
        .scrlTool.value = Resource(EditorIndex).ToolRequired
        .scrlHealth.value = Resource(EditorIndex).health
        .scrlRespawn.value = Resource(EditorIndex).RespawnTime
        .scrlAnimation.value = Resource(EditorIndex).Animation

        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then

            For I = 0 To .cmbSound.ListCount

                If .cmbSound.list(I) = Trim$(Resource(EditorIndex).sound) Then
                    .cmbSound.ListIndex = I
                    SoundSet = True
                End If

            Next

            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If

    End With

    Resource_Changed(EditorIndex) = True
End Sub

Public Sub ResourceEditorOk()
    Dim I As Long

    For I = 1 To MAX_RESOURCES

        If Resource_Changed(I) Then
            Call SendSaveResource(I)
        End If

    Next

    Unload frmEditor_Resource
    Editor = 0
    ClearChanged_Resource
End Sub

Public Sub ResourceEditorCancel()
    Editor = 0
    Unload frmEditor_Resource
    ClearChanged_Resource
    ClearResources
    SendRequestResources
End Sub

Public Sub ClearChanged_Resource()
    ZeroMemory Resource_Changed(1), MAX_RESOURCES * 2 ' 2 = boolean length
End Sub

' /////////////////
' // Shop Editor //
' /////////////////
Public Sub ShopEditorInit()
    Dim I As Long

    If frmEditor_Shop.visible = False Then Exit Sub
    EditorIndex = frmEditor_Shop.lstIndex.ListIndex + 1
    frmEditor_Shop.txtName.text = Trim$(Shop(EditorIndex).name)

    If Shop(EditorIndex).BuyRate > 0 Then
        frmEditor_Shop.scrlBuy.value = Shop(EditorIndex).BuyRate
    Else
        frmEditor_Shop.scrlBuy.value = 100
    End If

    frmEditor_Shop.cmbItem.Clear
    frmEditor_Shop.cmbItem.AddItem "None"
    frmEditor_Shop.cmbCostItem.Clear
    frmEditor_Shop.cmbCostItem.AddItem "None"

    For I = 1 To MAX_ITEMS
        frmEditor_Shop.cmbItem.AddItem I & ": " & Trim$(Item(I).name)
        frmEditor_Shop.cmbCostItem.AddItem I & ": " & Trim$(Item(I).name)
    Next

    frmEditor_Shop.cmbItem.ListIndex = 0
    frmEditor_Shop.cmbCostItem.ListIndex = 0
    UpdateShopTrade
    Shop_Changed(EditorIndex) = True
End Sub

Public Sub UpdateShopTrade(Optional ByVal tmpPos As Long = 0)
    Dim I As Long
    frmEditor_Shop.lstTradeItem.Clear

    For I = 1 To MAX_TRADES

        With Shop(EditorIndex).TradeItem(I)

            ' if none, show as none
            If .Item = 0 And .CostItem = 0 Then
                frmEditor_Shop.lstTradeItem.AddItem "Empty Trade Slot"
            Else
                frmEditor_Shop.lstTradeItem.AddItem I & ": " & .ItemValue & "x " & Trim$(Item(.Item).name) & " for " & .CostValue & "x " & Trim$(Item(.CostItem).name)
            End If

        End With

    Next

    frmEditor_Shop.lstTradeItem.ListIndex = tmpPos
End Sub

Public Sub ShopEditorOk()
    Dim I As Long

    For I = 1 To MAX_SHOPS

        If Shop_Changed(I) Then
            Call SendSaveShop(I)
        End If

    Next

    Unload frmEditor_Shop
    Editor = 0
    ClearChanged_Shop
End Sub

Public Sub ShopEditorCancel()
    Editor = 0
    Unload frmEditor_Shop
    ClearChanged_Shop
    ClearShops
    SendRequestShops
End Sub

Public Sub ClearChanged_Shop()
    ZeroMemory Shop_Changed(1), MAX_SHOPS * 2 ' 2 = boolean length
End Sub

' //////////////////
' // Spell Editor //
' //////////////////
Sub SpellEditorCopy()
    CopyMemory ByVal VarPtr(tmpSpell), ByVal VarPtr(Spell(EditorIndex)), LenB(Spell(EditorIndex))
End Sub

Sub SpellEditorPaste()
    CopyMemory ByVal VarPtr(Spell(EditorIndex)), ByVal VarPtr(tmpSpell), LenB(tmpSpell)
    SpellEditorInit
    frmEditor_Spell.txtName_Validate False
End Sub

Public Sub SpellEditorInit()
    Dim I As Long
    Dim SoundSet As Boolean

    If frmEditor_Spell.visible = False Then Exit Sub
    EditorIndex = frmEditor_Spell.lstIndex.ListIndex + 1

    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If

    ' add the array to the combo
    frmEditor_Spell.cmbSound.Clear
    frmEditor_Spell.cmbSound.AddItem "None."

    For I = 1 To UBound(soundCache)
        frmEditor_Spell.cmbSound.AddItem soundCache(I)
    Next

    ' finished populating
    With frmEditor_Spell
        ' set max values
        .scrlAnimCast.Max = MAX_ANIMATIONS
        .scrlAnim.Max = MAX_ANIMATIONS
        .scrlAOE.Max = MAX_BYTE
        .scrlRange.Max = MAX_BYTE
        .scrlMap.Max = MAX_MAPS
        .scrlNext.Max = MAX_SPELLS
        ' build class combo
        .cmbClass.Clear
        .cmbClass.AddItem "None"

        For I = 1 To Max_Classes
            .cmbClass.AddItem Trim$(Class(I).name)
        Next

        .cmbClass.ListIndex = 0
        ' set values
        .txtName.text = Trim$(Spell(EditorIndex).name)
        .txtDesc.text = Trim$(Spell(EditorIndex).Desc)
        .cmbType.ListIndex = Spell(EditorIndex).Type
        .scrlMP.value = Spell(EditorIndex).MPCost
        .scrlLevel.value = Spell(EditorIndex).LevelReq
        .scrlAccess.value = Spell(EditorIndex).AccessReq
        .cmbClass.ListIndex = Spell(EditorIndex).ClassReq
        .scrlCast.value = Spell(EditorIndex).CastTime
        .scrlCool.value = Spell(EditorIndex).CDTime
        .scrlIcon.value = Spell(EditorIndex).icon
        .scrlMap.value = Spell(EditorIndex).map
        .scrlX.value = Spell(EditorIndex).X
        .scrlY.value = Spell(EditorIndex).Y
        .scrlDir.value = Spell(EditorIndex).Dir
        .scrlVital.value = Spell(EditorIndex).Vital
        .scrlDuration.value = Spell(EditorIndex).Duration
        .scrlInterval.value = Spell(EditorIndex).Interval
        .scrlRange.value = Spell(EditorIndex).Range

        If Spell(EditorIndex).IsAoE Then
            .chkAOE.value = 1
        Else
            .chkAOE.value = 0
        End If

        .scrlAOE.value = Spell(EditorIndex).AoE
        .scrlAnimCast.value = Spell(EditorIndex).CastAnim
        .scrlAnim.value = Spell(EditorIndex).SpellAnim
        .scrlStun.value = Spell(EditorIndex).StunDuration
        .scrlNext.value = Spell(EditorIndex).NextRank
        .scrlIndex.value = Spell(EditorIndex).UniqueIndex
        .scrlUses.value = Spell(EditorIndex).NextUses

        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then

            For I = 0 To .cmbSound.ListCount

                If .cmbSound.list(I) = Trim$(Spell(EditorIndex).sound) Then
                    .cmbSound.ListIndex = I
                    SoundSet = True
                End If

            Next

            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If

    End With

    Spell_Changed(EditorIndex) = True
End Sub

Public Sub SpellEditorOk()
    Dim I As Long

    For I = 1 To MAX_SPELLS

        If Spell_Changed(I) Then
            Call SendSaveSpell(I)
        End If

    Next

    Unload frmEditor_Spell
    Editor = 0
    ClearChanged_Spell
End Sub

Public Sub SpellEditorCancel()
    Editor = 0
    Unload frmEditor_Spell
    ClearChanged_Spell
    ClearSpells
    SendRequestSpells
End Sub

Public Sub ClearChanged_Spell()
    ZeroMemory Spell_Changed(1), MAX_SPELLS * 2 ' 2 = boolean length
End Sub

Public Sub ClearAttributeDialogue()
    frmEditor_Map.fraNpcSpawn.visible = False
    frmEditor_Map.fraResource.visible = False
    frmEditor_Map.fraMapItem.visible = False
    frmEditor_Map.fraMapKey.visible = False
    frmEditor_Map.fraKeyOpen.visible = False
    frmEditor_Map.fraMapWarp.visible = False
    frmEditor_Map.fraShop.visible = False
End Sub
