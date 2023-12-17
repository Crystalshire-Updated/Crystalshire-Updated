Attribute VB_Name = "Client_InterfaceEvents"
Option Explicit
Public Declare Sub GetCursorPos Lib "user32" (lpPoint As POINTAPI)
Public Declare Function ScreenToClient Lib "user32" (ByVal hwnd As Long, lpPoint As POINTAPI) As Long
Public Declare Function entCallBack Lib "user32.dll" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As Long, ByVal Window As Long, ByRef Control As Long, ByVal forced As Long, ByVal lParam As Long) As Long
Public Const VK_LBUTTON = &H1
Public Const VK_RBUTTON = &H2
Public lastMouseX As Long, lastMouseY As Long
Public currMouseX As Long, currMouseY As Long
Public clickedX As Long, clickedY As Long
Public mouseClick(1 To 2) As Long
Public lastMouseClick(1 To 2) As Long

Public GlobalCaptcha As Long


Public Function MouseX(Optional ByVal hwnd As Long) As Long
    Dim lpPoint As POINTAPI
    GetCursorPos lpPoint

    If hwnd Then ScreenToClient hwnd, lpPoint
    MouseX = lpPoint.x
End Function

Public Function MouseY(Optional ByVal hwnd As Long) As Long
    Dim lpPoint As POINTAPI
    GetCursorPos lpPoint

    If hwnd Then ScreenToClient hwnd, lpPoint
    MouseY = lpPoint.y
End Function

Public Sub HandleMouseInput()
    Dim entState As EntityStates, i As Long, x As Long
    
    ' exit out if we're playing video
    If videoPlaying Then Exit Sub
    
    ' set values
    lastMouseX = currMouseX
    lastMouseY = currMouseY
    currMouseX = MouseX(frmMain.hwnd)
    currMouseY = MouseY(frmMain.hwnd)
    GlobalX = currMouseX
    GlobalY = currMouseY
    lastMouseClick(VK_LBUTTON) = mouseClick(VK_LBUTTON)
    lastMouseClick(VK_RBUTTON) = mouseClick(VK_RBUTTON)
    mouseClick(VK_LBUTTON) = GetAsyncKeyState(VK_LBUTTON)
    mouseClick(VK_RBUTTON) = GetAsyncKeyState(VK_RBUTTON)
    
    ' Hover
    entState = EntityStates.Hover

    ' MouseDown
    If (mouseClick(VK_LBUTTON) And lastMouseClick(VK_LBUTTON) = 0) Or (mouseClick(VK_RBUTTON) And lastMouseClick(VK_RBUTTON) = 0) Then
        clickedX = currMouseX
        clickedY = currMouseY
        entState = EntityStates.MouseDown
        ' MouseUp
    ElseIf (mouseClick(VK_LBUTTON) = 0 And lastMouseClick(VK_LBUTTON)) Or (mouseClick(VK_RBUTTON) = 0 And lastMouseClick(VK_RBUTTON)) Then
        entState = EntityStates.MouseUp
        ' MouseMove
    ElseIf (currMouseX <> lastMouseX) Or (currMouseY <> lastMouseY) Then
        entState = EntityStates.MouseMove
    End If

    ' Handle everything else
    If Not HandleGuiMouse(entState) Then
        ' reset /all/ control mouse events
        For i = 1 To WindowCount
            For x = 1 To Windows(i).ControlCount
                Windows(i).Controls(x).state = Normal
            Next
        Next
        If InGame Then
            If entState = EntityStates.MouseDown Then
                ' Handle events
                If currMouseX >= 0 And currMouseX <= frmMain.ScaleWidth Then
                    If currMouseY >= 0 And currMouseY <= frmMain.ScaleHeight Then
                    
                        If InMapEditor Then
                            If (mouseClick(VK_LBUTTON) And lastMouseClick(VK_LBUTTON) = 0) Then
                                Call MapEditorMouseDown(vbLeftButton, GlobalX, GlobalY, False)
                            ElseIf (mouseClick(VK_RBUTTON) And lastMouseClick(VK_RBUTTON) = 0) Then
                                Call MapEditorMouseDown(vbRightButton, GlobalX, GlobalY, False)
                            End If
                        Else
                            ' left click
                            If (mouseClick(VK_LBUTTON) And lastMouseClick(VK_LBUTTON) = 0) Then
                                ' targetting
                                FindTarget
                                ' right click
                            ElseIf (mouseClick(VK_RBUTTON) And lastMouseClick(VK_RBUTTON) = 0) Then
                                If ShiftDown Then
                                    ' admin warp if we're pressing shift and right clicking
                                    If GetPlayerAccess(MyIndex) >= 2 Then AdminWarp CurX, CurY
                                    Exit Sub
                                End If
                                ' right-click menu
                                For i = 1 To Player_HighIndex
                                    If IsPlaying(i) Then
                                        If GetPlayerMap(i) = GetPlayerMap(MyIndex) Then
                                            If GetPlayerX(i) = CurX And GetPlayerY(i) = CurY Then
                                                ShowPlayerMenu i, currMouseX, currMouseY
                                            End If
                                        End If
                                    End If
                                Next
                            End If
                        End If
                    End If
                End If
            ElseIf entState = EntityStates.MouseMove Then
                GlobalX_Map = GlobalX + (TileView.left * PIC_X) + Camera.left
                GlobalY_Map = GlobalY + (TileView.top * PIC_Y) + Camera.top
                ' Handle the events
                CurX = TileView.left + ((currMouseX + Camera.left) \ PIC_X)
                CurY = TileView.top + ((currMouseY + Camera.top) \ PIC_Y)

                If InMapEditor Then
                    If (mouseClick(VK_LBUTTON)) Then
                        Call MapEditorMouseDown(vbLeftButton, CurX, CurY, False)
                    ElseIf (mouseClick(VK_RBUTTON)) Then
                        Call MapEditorMouseDown(vbRightButton, CurX, CurY, False)
                    End If
                End If
            End If
        End If
    End If
End Sub

Public Function HandleGuiMouse(entState As EntityStates) As Boolean
    Dim i As Long, curWindow As Long, curControl As Long, callback As Long, x As Long
    
    ' if hiding gui
    If hideGUI = True Or InMapEditor Then Exit Function

    ' Find the container
    For i = 1 To WindowCount
        With Windows(i).Window
            If .enabled And .visible Then
                If .state <> EntityStates.MouseDown Then .state = EntityStates.Normal
                If currMouseX >= .left And currMouseX <= .width + .left Then
                    If currMouseY >= .top And currMouseY <= .height + .top Then
                        ' set the combomenu
                        If .design(0) = DesignTypes.designComboBackground Then
                            ' set the hover menu
                            If entState = MouseMove Or entState = Hover Then
                                ComboMenu_MouseMove i
                            ElseIf entState = MouseDown Then
                                ComboMenu_MouseDown i
                            End If
                        End If
                        ' everything else
                        If curWindow = 0 Then curWindow = i
                        If .zOrder > Windows(curWindow).Window.zOrder Then curWindow = i
                    End If
                End If
                If entState = EntityStates.MouseMove Then
                    If .canDrag Then
                        If .state = EntityStates.MouseDown Then
                            .left = Clamp(.left + ((currMouseX - .left) - .movedX), 0, ScreenWidth - .width)
                            .top = Clamp(.top + ((currMouseY - .top) - .movedY), 0, ScreenHeight - .height)
                        End If
                    End If
                End If
            End If
        End With
    Next

    ' Handle any controls first
    If curWindow Then
        ' reset /all other/ control mouse events
        For i = 1 To WindowCount
            If i <> curWindow Then
                For x = 1 To Windows(i).ControlCount
                    Windows(i).Controls(x).state = Normal
                Next
            End If
        Next
        For i = 1 To Windows(curWindow).ControlCount
            With Windows(curWindow).Controls(i)
                If .enabled And .visible Then
                    If .state <> EntityStates.MouseDown Then .state = EntityStates.Normal
                    If currMouseX >= .left + Windows(curWindow).Window.left And currMouseX <= .left + .width + Windows(curWindow).Window.left Then
                        If currMouseY >= .top + Windows(curWindow).Window.top And currMouseY <= .top + .height + Windows(curWindow).Window.top Then
                            If curControl = 0 Then curControl = i
                            If .zOrder > Windows(curWindow).Controls(curControl).zOrder Then curControl = i
                        End If
                    End If
                    If entState = EntityStates.MouseMove Then
                        If .canDrag Then
                            If .state = EntityStates.MouseDown Then
                                .left = Clamp(.left + ((currMouseX - .left) - .movedX), 0, Windows(curWindow).Window.width - .width)
                                .top = Clamp(.top + ((currMouseY - .top) - .movedY), 0, Windows(curWindow).Window.height - .height)
                            End If
                        End If
                    End If
                End If
            End With
        Next
        ' Handle control
        If curControl Then
            HandleGuiMouse = True
            With Windows(curWindow).Controls(curControl)
                If .state <> EntityStates.MouseDown Then
                    If entState <> EntityStates.MouseMove Then
                        .state = entState
                    Else
                        .state = EntityStates.Hover
                    End If
                End If
                If entState = EntityStates.MouseDown Then
                    If .canDrag Then
                        .movedX = clickedX - .left
                        .movedY = clickedY - .top
                    End If
                    ' toggle boxes
                    Select Case .type
                        Case EntityTypes.entityCheckbox
                            ' grouped boxes
                            If .group > 0 Then
                                If .value = 0 Then
                                    For i = 1 To Windows(curWindow).ControlCount
                                        If Windows(curWindow).Controls(i).type = EntityTypes.entityCheckbox Then
                                            If Windows(curWindow).Controls(i).group = .group Then
                                                Windows(curWindow).Controls(i).value = 0
                                            End If
                                        End If
                                    Next
                                    .value = 1
                                End If
                            Else
                                If .value = 0 Then
                                    .value = 1
                                Else
                                    .value = 0
                                End If
                            End If
                        Case EntityTypes.entityCombo
                            ShowComboMenu curWindow, curControl
                    End Select
                    ' set active input
                    SetActiveControl curWindow, curControl
                End If
                callback = .entCallBack(entState)
            End With
        Else
            ' Handle container
            With Windows(curWindow).Window
                HandleGuiMouse = True
                If .state <> EntityStates.MouseDown Then
                    If entState <> EntityStates.MouseMove Then
                        .state = entState
                    Else
                        .state = EntityStates.Hover
                    End If
                End If
                If entState = EntityStates.MouseDown Then
                    If .canDrag Then
                        .movedX = clickedX - .left
                        .movedY = clickedY - .top
                    End If
                End If
                callback = .entCallBack(entState)
            End With
        End If
        ' bring to front
        If entState = EntityStates.MouseDown Then
            UpdateZOrder curWindow
            activeWindow = curWindow
        End If
        ' call back
        If callback <> 0 Then entCallBack callback, curWindow, curControl, 0, 0
    End If

    ' Reset
    If entState = EntityStates.MouseUp Then ResetMouseDown
End Function

Public Sub ResetGUI()
    Dim i As Long, x As Long

    For i = 1 To WindowCount

        If Windows(i).Window.state <> MouseDown Then Windows(i).Window.state = Normal

        For x = 1 To Windows(i).ControlCount

            If Windows(i).Controls(x).state <> MouseDown Then Windows(i).Controls(x).state = Normal
        Next
    Next

End Sub

Public Sub ResetMouseDown()
    Dim callback As Long
    Dim i As Long, x As Long

    For i = 1 To WindowCount

        With Windows(i)
            .Window.state = EntityStates.Normal
            callback = .Window.entCallBack(EntityStates.Normal)

            If callback <> 0 Then entCallBack callback, i, 0, 0, 0

            For x = 1 To .ControlCount
                .Controls(x).state = EntityStates.Normal
                callback = .Controls(x).entCallBack(EntityStates.Normal)

                If callback <> 0 Then entCallBack callback, i, x, 0, 0
            Next

        End With

    Next

End Sub
' ################## ##
' ## REGISTER WINDOW ##
' #####################
Public Sub btnRegister_Click()
    HideWindows
    RenCaptcha
    ClearRegisterTexts
    ShowWindow GetWindowIndex("winRegister")
End Sub
Public Sub ClearRegisterTexts()
    Dim i As Long
    With Windows(GetWindowIndex("winRegister"))
        .Controls(GetControlIndex("winRegister", "txtAccount")).text = vbNullString
        .Controls(GetControlIndex("winRegister", "txtPass")).text = vbNullString
        .Controls(GetControlIndex("winRegister", "txtPass2")).text = vbNullString
        .Controls(GetControlIndex("winRegister", "txtCode")).text = vbNullString
        .Controls(GetControlIndex("winRegister", "txtCaptcha")).text = vbNullString
    For i = 0 To 6
        .Controls(GetControlIndex("winRegister", "picCaptcha")).image(i) = TextureCaptcha(GlobalCaptcha)
    Next
    End With
End Sub
Public Sub RenCaptcha()
    Dim N As Long
    N = Int(Rnd * (CountCaptcha - 1)) + 1
    GlobalCaptcha = N
End Sub
Public Sub btnSendRegister_Click()
    Dim User As String, Pass As String, pass2 As String, Code As String, Captcha As String

    With Windows(GetWindowIndex("winRegister"))
        User = .Controls(GetControlIndex("winRegister", "txtAccount")).text
        Pass = .Controls(GetControlIndex("winRegister", "txtPass")).text
        pass2 = .Controls(GetControlIndex("winRegister", "txtPass2")).text
        Code = .Controls(GetControlIndex("winRegister", "txtCode")).text
        Captcha = .Controls(GetControlIndex("winRegister", "txtCaptcha")).text
    End With

    If Trim$(Pass) <> Trim$(pass2) Then
       Call Dialogue("Register", "Falha ao criar conta.", "A confirmação não confere com a senha!", TypeDELCHAR, StyleOKAY, 1)
        Exit Sub
    End If
    
    If User = vbNullString Or Pass = vbNullString Or pass2 = vbNullString Or Code = vbNullString Then
        Call Dialogue("Register", "Falha ao criar conta.", "Nenhum campo pode ficar em branco!", TypeDELCHAR, StyleOKAY, 1)
        Exit Sub
    End If
    
    If Trim$(Captcha) <> Trim$(GetCaptcha) Then
        RenCaptcha
        ClearRegisterTexts
        Call Dialogue("Register", "Falha ao criar conta.", "Captcha Incorreto!", TypeDELCHAR, StyleOKAY, 1)
        Exit Sub
    End If
    
    SendRegister User, Pass, Code
End Sub
Public Sub btnReturnMain_Click()
    HideWindows
    ShowWindow GetWindowIndex("winLogin")
End Sub
Function GetCaptcha() As String
Select Case GlobalCaptcha
    
    Case 1
        GetCaptcha = "123"
    Case 2
        GetCaptcha = "123"
    Case 3
         GetCaptcha = "123"
    Case 4
         GetCaptcha = "123"
    Case 5
         GetCaptcha = "123"
    Case 6
         GetCaptcha = "123"
End Select
End Function

' ##################
' ## Login Window ##
' ##################

Public Sub btnLogin_Click()
    Dim User As String, Pass As String
    
    With Windows(GetWindowIndex("winLogin"))
        User = .Controls(GetControlIndex("winLogin", "txtUser")).text
        Pass = .Controls(GetControlIndex("winLogin", "txtPass")).text
    End With
    
    Login User, Pass
End Sub

Public Sub chkSaveUser_Click()

    With Windows(GetWindowIndex("winLogin")).Controls(GetControlIndex("winLogin", "chkSaveUser"))
        If .value = 0 Then ' set as false
            Options.SaveUser = 0
            Options.Username = vbNullString
            SaveOptions
        Else
            Options.SaveUser = 1
            SaveOptions
        End If
    End With
End Sub

' #######################
' ## Characters Window ##
' #######################

Public Sub Chars_DrawFace()
Dim Xo As Long, Yo As Long, imageFace As Long, imageChar As Long, x As Long, i As Long
    
    Xo = Windows(GetWindowIndex("winCharacters")).Window.left
    Yo = Windows(GetWindowIndex("winCharacters")).Window.top
    
    x = Xo + 24
    For i = 1 To MAX_CHARS
        If LenB(Trim$(CharName(i))) > 0 Then
            If CharSprite(i) > 0 Then
                If Not CharSprite(i) > CountChar And Not CharSprite(i) > CountFace Then
                    imageFace = TextureFace(CharSprite(i))
                    imageChar = TextureChar(CharSprite(i))
                    RenderTexture imageFace, x, Yo + 56, 0, 0, 94, 94, 94, 94
                    RenderTexture imageChar, x - 1, Yo + 117, 32, 0, 32, 32, 32, 32
                End If
            End If
        End If
        x = x + 110
    Next
End Sub

Public Sub btnAcceptChar_1()
    SendUseChar 1
End Sub

Public Sub btnAcceptChar_2()
    SendUseChar 2
End Sub

Public Sub btnAcceptChar_3()
    SendUseChar 3
End Sub

Public Sub btnDelChar_1()
    Dialogue "Delete Character", "Deleting this character is permanent.", "Are you sure you want to delete this character?", TypeDELCHAR, StyleYESNO, 1
End Sub

Public Sub btnDelChar_2()
    Dialogue "Delete Character", "Deleting this character is permanent.", "Are you sure you want to delete this character?", TypeDELCHAR, StyleYESNO, 2
End Sub

Public Sub btnDelChar_3()
    Dialogue "Delete Character", "Deleting this character is permanent.", "Are you sure you want to delete this character?", TypeDELCHAR, StyleYESNO, 3
End Sub

Public Sub btnCreateChar_1()
    CharNum = 1
    ShowClasses
End Sub

Public Sub btnCreateChar_2()
    CharNum = 2
    ShowClasses
End Sub

Public Sub btnCreateChar_3()
    CharNum = 3
    ShowClasses
End Sub

Public Sub btnCharacters_Close()
    DestroyTCP
    HideWindows
    ShowWindow GetWindowIndex("winLogin")
End Sub

' #####################
' ## Dialogue Window ##
' #####################

Public Sub btnDialogue_Close()
    If diaStyle = StyleOKAY Then
        dialogueHandler 1
    ElseIf diaStyle = StyleYESNO Then
        dialogueHandler 3
    End If
End Sub

Public Sub Dialogue_Okay()
    dialogueHandler 1
End Sub

Public Sub Dialogue_Yes()
    dialogueHandler 2
End Sub

Public Sub Dialogue_No()
    dialogueHandler 3
End Sub

' ####################
' ## Classes Window ##
' ####################

Public Sub Classes_DrawFace()
Dim imageFace As Long, Xo As Long, Yo As Long

    Xo = Windows(GetWindowIndex("winClasses")).Window.left
    Yo = Windows(GetWindowIndex("winClasses")).Window.top
    
    Max_Classes = 3
    
    If newCharClass = 0 Then newCharClass = 1

    Select Case newCharClass
        Case 1 ' Warrior
            imageFace = TextureGUI(52)
        Case 2 ' Wizard
            imageFace = TextureGUI(53)
        Case 3 ' Whisperer
            imageFace = TextureGUI(54)
    End Select
    
    ' render face
    RenderTexture imageFace, Xo + 14, Yo - 41, 0, 0, 256, 256, 256, 256
End Sub

Public Sub Classes_DrawText()
Dim image As Long, text As String, Xo As Long, Yo As Long, textArray() As String, i As Long, count As Long, y As Long, x As Long

    Xo = Windows(GetWindowIndex("winClasses")).Window.left
    Yo = Windows(GetWindowIndex("winClasses")).Window.top

    Select Case newCharClass
        Case 1 ' Warrior
            text = "The way of a warrior has never been an easy one. Skilled use of a sword is not something learnt overnight. Being able to take a decent amount of hits is important for these characters and as such they weigh a lot of importance on endurance and strength."
        Case 2 ' Wizard
            text = "Wizards are often mistrusted characters who have mastered the practise of using their own spirit to create elemental entities. Generally seen as playful and almost childish because of the huge amounts of pleasure they take from setting things on fire."
        Case 3 ' Whisperer
            text = "The art of healing is one which comes with tremendous amounts of pressure and guilt. Constantly being put under high-pressure situations where their abilities could mean the difference between life and death leads many Whisperers to insanity."
    End Select
    
    ' wrap text
    WordWrap_Array text, 200, textArray()
    ' render text
    count = UBound(textArray)
    y = Yo + 60
    For i = 1 To count
        x = Xo + 132 + (200 \ 2) - (TextWidth(font(Fonts.rockwell_15), textArray(i)) \ 2)
        RenderText font(Fonts.rockwell_15), textArray(i), x, y, White
        y = y + 14
    Next
End Sub

Public Sub btnClasses_Left()
Dim text As String
    newCharClass = newCharClass - 1
    If newCharClass <= 0 Then
        newCharClass = Max_Classes
    End If
    Windows(GetWindowIndex("winClasses")).Controls(GetControlIndex("winClasses", "lblClassName")).text = Trim$(Class(newCharClass).name)
End Sub

Public Sub btnClasses_Right()
Dim text As String
    newCharClass = newCharClass + 1
    If newCharClass > Max_Classes Then
        newCharClass = 1
    End If
    Windows(GetWindowIndex("winClasses")).Controls(GetControlIndex("winClasses", "lblClassName")).text = Trim$(Class(newCharClass).name)
End Sub

Public Sub btnClasses_Accept()
    HideWindow GetWindowIndex("winClasses")
    ShowWindow GetWindowIndex("winNewChar")
End Sub

Public Sub btnClasses_Close()
    HideWindows
    ShowWindow GetWindowIndex("winCharacters")
End Sub

' ###################
' ## New Character ##
' ###################

Public Sub NewChar_OnDraw()
Dim imageFace As Long, imageChar As Long, Xo As Long, Yo As Long
    
    Xo = Windows(GetWindowIndex("winNewChar")).Window.left
    Yo = Windows(GetWindowIndex("winNewChar")).Window.top
    
    If newCharGender = SEX_MALE Then
        imageFace = TextureFace(Class(newCharClass).MaleSprite(newCharSprite))
        imageChar = TextureChar(Class(newCharClass).MaleSprite(newCharSprite))
    Else
        imageFace = TextureFace(Class(newCharClass).FemaleSprite(newCharSprite))
        imageChar = TextureChar(Class(newCharClass).FemaleSprite(newCharSprite))
    End If
    
    ' render face
    RenderTexture imageFace, Xo + 166, Yo + 56, 0, 0, 94, 94, 94, 94
    ' render char
    RenderTexture imageChar, Xo + 166, Yo + 116, 32, 0, 32, 32, 32, 32
End Sub

Public Sub btnNewChar_Left()
Dim spriteCount As Long

    If newCharGender = SEX_MALE Then
        spriteCount = UBound(Class(newCharClass).MaleSprite)
    Else
        spriteCount = UBound(Class(newCharClass).FemaleSprite)
    End If

    If newCharSprite <= 0 Then
        newCharSprite = spriteCount
    Else
        newCharSprite = newCharSprite - 1
    End If
End Sub

Public Sub btnNewChar_Right()
Dim spriteCount As Long

    If newCharGender = SEX_MALE Then
        spriteCount = UBound(Class(newCharClass).MaleSprite)
    Else
        spriteCount = UBound(Class(newCharClass).FemaleSprite)
    End If

    If newCharSprite >= spriteCount Then
        newCharSprite = 0
    Else
        newCharSprite = newCharSprite + 1
    End If
End Sub

Public Sub chkNewChar_Male()
    newCharSprite = 1
    newCharGender = SEX_MALE
End Sub

Public Sub chkNewChar_Female()
    newCharSprite = 1
    newCharGender = SEX_FEMALE
End Sub

Public Sub btnNewChar_Cancel()
    Windows(GetWindowIndex("winNewChar")).Controls(GetControlIndex("winNewChar", "txtName")).text = vbNullString
    Windows(GetWindowIndex("winNewChar")).Controls(GetControlIndex("winNewChar", "chkMale")).value = 1
    Windows(GetWindowIndex("winNewChar")).Controls(GetControlIndex("winNewChar", "chkFemale")).value = 0
    newCharSprite = 1
    newCharGender = SEX_MALE
    HideWindows
    ShowWindow GetWindowIndex("winClasses")
End Sub

Public Sub btnNewChar_Accept()
Dim name As String
    name = Windows(GetWindowIndex("winNewChar")).Controls(GetControlIndex("winNewChar", "txtName")).text
    HideWindows
    AddChar name, newCharGender, newCharClass, newCharSprite
End Sub

' ##############
' ## Esc Menu ##
' ##############

Public Sub btnEscMenu_Return()
    HideWindow GetWindowIndex("winBlank")
    HideWindow GetWindowIndex("winEscMenu")
End Sub

Public Sub btnEscMenu_Options()
    HideWindow GetWindowIndex("winEscMenu")
    ShowWindow GetWindowIndex("winOptions"), True, True
End Sub

Public Sub btnEscMenu_MainMenu()
    HideWindows
    ShowWindow GetWindowIndex("winLogin")
    Stop_Music
    ' play the menu music
    If Len(Trim$(MenuMusic)) > 0 Then Play_Music Trim$(MenuMusic)
    logoutGame
End Sub

Public Sub btnEscMenu_Exit()
    HideWindow GetWindowIndex("winBlank")
    HideWindow GetWindowIndex("winEscMenu")
    DestroyGame
End Sub

' ##########
' ## Bars ##
' ##########

Public Sub Bars_OnDraw()
    Dim Xo As Long, Yo As Long, width As Long
    
    Xo = Windows(GetWindowIndex("winBars")).Window.left
    Yo = Windows(GetWindowIndex("winBars")).Window.top
    
    ' Bars
    RenderTexture TextureGUI(29), Xo + 15, Yo + 15, 0, 0, BarWidth_GuiHP, 13, BarWidth_GuiHP, 13
    RenderTexture TextureGUI(30), Xo + 15, Yo + 32, 0, 0, BarWidth_GuiSP, 13, BarWidth_GuiSP, 13
    RenderTexture TextureGUI(31), Xo + 15, Yo + 49, 0, 0, BarWidth_GuiEXP, 13, BarWidth_GuiEXP, 13
End Sub

' ##########
' ## Menu ##
' ##########

Public Sub btnMenu_Char()
Dim curWindow As Long
    curWindow = GetWindowIndex("winCharacter")
    If Windows(curWindow).Window.visible Then
        HideWindow curWindow
    Else
        ShowWindow curWindow, , False
    End If
End Sub

Public Sub btnMenu_Inv()
Dim curWindow As Long
    curWindow = GetWindowIndex("winInventory")
    If Windows(curWindow).Window.visible Then
        HideWindow curWindow
    Else
        ShowWindow curWindow, , False
    End If
End Sub

Public Sub btnMenu_Skills()
Dim curWindow As Long
    curWindow = GetWindowIndex("winSkills")
    If Windows(curWindow).Window.visible Then
        HideWindow curWindow
    Else
        ShowWindow curWindow, , False
    End If
End Sub

Public Sub btnMenu_Map()
    'Windows(GetWindowIndex("winCharacter")).Window.visible = Not Windows(GetWindowIndex("winCharacter")).Window.visible
End Sub

Public Sub btnMenu_Guild()
    'Windows(GetWindowIndex("winCharacter")).Window.visible = Not Windows(GetWindowIndex("winCharacter")).Window.visible
End Sub

Public Sub btnMenu_Quest()
    Dim i As Long, IsActiveBtn As Boolean
    
    For i = 1 To MAX_PLAYER_MISSIONS
        If Player(MyIndex).Mission(i).id > 0 Then
            IsActiveBtn = True
        End If
    Next
    
    If Not Windows(GetWindowIndex("winPlayerQuests")).Window.visible Then
        If IsActiveBtn Then
            Button_MissionActive = 1
            Call Window_QuestButtonUpdate
        End If
    End If
    
    Windows(GetWindowIndex("winPlayerQuests")).Window.visible = Not Windows(GetWindowIndex("winPlayerQuests")).Window.visible
End Sub

' #########################################################################################################################
' ## QUEST ################################################################################################################
' #########################################################################################################################

Public Sub btnQuest1()
    Button_MissionActive = 1
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest2()
    Button_MissionActive = 2
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest3()
    Button_MissionActive = 3
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest4()
    Button_MissionActive = 4
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest5()
    Button_MissionActive = 5
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest6()
    Button_MissionActive = 6
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest7()
    Button_MissionActive = 7
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest8()
    Button_MissionActive = 8
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest9()
    Button_MissionActive = 9
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest10()
    Button_MissionActive = 10
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest11()
    Button_MissionActive = 11
    Call Window_QuestLabelUpdate
End Sub

Public Sub btnQuest12()
    Button_MissionActive = 12
    Call Window_QuestLabelUpdate
End Sub

' ###############
' ##    Bank   ##
' ###############

Public Sub btnMenu_Bank()
    If Windows(GetWindowIndex("winBank")).Window.visible Then
        CloseBank
    End If

    Windows(GetWindowIndex("winBank")).Window.visible = Not Windows(GetWindowIndex("winBank")).Window.visible
End Sub

Public Sub Bank_MouseMove()
    Dim ItemNum As Long, x As Long, y As Long, i As Long

    ' exit out early if dragging
    If DragBox.type <> partNone Then Exit Sub

    ItemNum = IsBankItem(Windows(GetWindowIndex("winBank")).Window.left, Windows(GetWindowIndex("winBank")).Window.top)

    If ItemNum > 0 Then

        ' make sure we're not dragging the item
        If DragBox.type = partItem And DragBox.value = ItemNum Then Exit Sub
        ' calc position
        x = Windows(GetWindowIndex("winBank")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winBank")).Window.top - 4

        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winBank")).Window.left + Windows(GetWindowIndex("winBank")).Window.width
        End If

        ' go go go
        ShowItemDesc x, y, Bank.Item(ItemNum).num, False
    End If
End Sub

Public Sub Bank_MouseDown()
    Dim BankSlot As Long, winIndex As Long, i As Long

    ' is there an item?
    BankSlot = IsBankItem(Windows(GetWindowIndex("winBank")).Window.left, Windows(GetWindowIndex("winBank")).Window.top)

    If BankSlot > 0 Then
        ' exit out if we're offering that item

        ' drag it
        With DragBox
            .type = partItem
            .value = Bank.Item(BankSlot).num
            .origin = originBank
            .Slot = BankSlot
        End With

        winIndex = GetWindowIndex("winDragBox")
        With Windows(winIndex).Window
            .state = MouseDown
            .left = lastMouseX - 16
            .top = lastMouseY - 16
            .movedX = clickedX - .left
            .movedY = clickedY - .top
        End With

        ShowWindow winIndex, , False
        ' stop dragging inventory
        Windows(GetWindowIndex("winBank")).Window.state = Normal
    End If

    ' show desc. if needed
    Bank_MouseMove
End Sub

' ###############
' ## Inventory ##
' ###############

Public Sub Inventory_MouseDown()
Dim invNum As Long, winIndex As Long, i As Long
    
    ' is there an item?
    invNum = IsItem(Windows(GetWindowIndex("winInventory")).Window.left, Windows(GetWindowIndex("winInventory")).Window.top)
    
    If invNum Then
        ' exit out if we're offering that item
        If InTrade > 0 Then
            For i = 1 To MAX_INV
                If TradeYourOffer(i).num = invNum Then
                    ' is currency?
                    If Item(GetPlayerInvItemNum(MyIndex, TradeYourOffer(i).num)).type = ITEM_TYPE_CURRENCY Then
                        ' only exit out if we're offering all of it
                        If TradeYourOffer(i).value = GetPlayerInvItemValue(MyIndex, TradeYourOffer(i).num) Then
                            Exit Sub
                        End If
                    Else
                        Exit Sub
                    End If
                End If
            Next
            ' currency handler
            If Item(GetPlayerInvItemNum(MyIndex, invNum)).type = ITEM_TYPE_CURRENCY Then
                Dialogue "Select Amount", "Please choose how many to offer", "", TypeTRADEAMOUNT, StyleINPUT, invNum
                Exit Sub
            End If
            ' trade the normal item
            Call TradeItem(invNum, 0)
            Exit Sub
        End If
        
        ' drag it
        With DragBox
            .type = partItem
            .value = GetPlayerInvItemNum(MyIndex, invNum)
            .origin = originInventory
            .Slot = invNum
        End With
        
        winIndex = GetWindowIndex("winDragBox")
        With Windows(winIndex).Window
            .state = MouseDown
            .left = lastMouseX - 16
            .top = lastMouseY - 16
            .movedX = clickedX - .left
            .movedY = clickedY - .top
        End With
        ShowWindow winIndex, , False
        ' stop dragging inventory
        Windows(GetWindowIndex("winInventory")).Window.state = Normal
    End If

    ' show desc. if needed
    Inventory_MouseMove
End Sub

Public Sub Inventory_doubleClick()
Dim ItemNum As Long, i As Long

    If InTrade > 0 Then Exit Sub

    ItemNum = IsItem(Windows(GetWindowIndex("winInventory")).Window.left, Windows(GetWindowIndex("winInventory")).Window.top)
    
    If ItemNum Then
        SendUseItem ItemNum
    End If
    
    ' show desc. if needed
    Inventory_MouseMove
End Sub

Public Sub Inventory_MouseMove()
Dim ItemNum As Long, x As Long, y As Long, i As Long

    ' exit out early if dragging
    If DragBox.type <> partNone Then Exit Sub

    ItemNum = IsItem(Windows(GetWindowIndex("winInventory")).Window.left, Windows(GetWindowIndex("winInventory")).Window.top)
    
    If ItemNum Then
        ' exit out if we're offering that item
        If InTrade > 0 Then
            For i = 1 To MAX_INV
                If TradeYourOffer(i).num = ItemNum Then
                    ' is currency?
                    If Item(GetPlayerInvItemNum(MyIndex, TradeYourOffer(i).num)).type = ITEM_TYPE_CURRENCY Then
                        ' only exit out if we're offering all of it
                        If TradeYourOffer(i).value = GetPlayerInvItemValue(MyIndex, TradeYourOffer(i).num) Then
                            Exit Sub
                        End If
                    Else
                        Exit Sub
                    End If
                End If
            Next
        End If
        ' make sure we're not dragging the item
        If DragBox.type = partItem And DragBox.value = ItemNum Then Exit Sub
        ' calc position
        x = Windows(GetWindowIndex("winInventory")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winInventory")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winInventory")).Window.left + Windows(GetWindowIndex("winInventory")).Window.width
        End If
        ' go go go
        ShowInvDesc x, y, ItemNum
    End If
End Sub

' ###############
' ## Character ##
' ###############

Public Sub Character_MouseDown()
Dim ItemNum As Long
    
    ItemNum = IsEqItem(Windows(GetWindowIndex("winCharacter")).Window.left, Windows(GetWindowIndex("winCharacter")).Window.top)
    
    If ItemNum Then
        SendUnequip ItemNum
    End If
    
    ' show desc. if needed
    Character_MouseMove
End Sub

Public Sub Character_MouseMove()
Dim ItemNum As Long, x As Long, y As Long

    ' exit out early if dragging
    If DragBox.type <> partNone Then Exit Sub

    ItemNum = IsEqItem(Windows(GetWindowIndex("winCharacter")).Window.left, Windows(GetWindowIndex("winCharacter")).Window.top)
    
    If ItemNum Then
        ' calc position
        x = Windows(GetWindowIndex("winCharacter")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winCharacter")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winCharacter")).Window.left + Windows(GetWindowIndex("winCharacter")).Window.width
        End If
        ' go go go
        ShowEqDesc x, y, ItemNum
    End If
End Sub

Public Sub Character_SpendPoint1()
    SendTrainStat 1
End Sub

Public Sub Character_SpendPoint2()
    SendTrainStat 2
End Sub

Public Sub Character_SpendPoint3()
    SendTrainStat 3
End Sub

Public Sub Character_SpendPoint4()
    SendTrainStat 4
End Sub

Public Sub Character_SpendPoint5()
    SendTrainStat 5
End Sub

' #################
' ## Description ##
' #################

Public Sub Description_OnDraw()
    Dim Xo As Long, Yo As Long
    Dim texNum As Long, x As Long, y As Long
    Dim i As Long, count As Long
    Dim width As Long, height As Long

    ' exit out if we don't have a num
    If descItem = 0 Or descType = 0 Then Exit Sub

    Xo = Windows(GetWindowIndex("winDescription")).Window.left
    Yo = Windows(GetWindowIndex("winDescription")).Window.top
    Windows(GetWindowIndex("winDescription")).Window.width = 193
    Windows(GetWindowIndex("winDescription")).Controls(GetControlIndex("winDescription", "lblDescription")).width = 85
    
    Select Case descType
        Case 1 ' Inventory Item
            texNum = TextureItem(Item(descItem).Pic)
        Case 2 ' Spell Icon
            
            texNum = TextureSpellIcon(Spell(descItem).icon)
            ' render bar
            With Windows(GetWindowIndex("winDescription")).Controls(GetControlIndex("winDescription", "picBar"))
                If .visible Then RenderTexture TextureGUI(45), Xo + .left, Yo + .top, 0, 12, .value, 12, .value, 12
            End With
        Case 3
            Select Case inOfferType(descItem)
                Case Offers.Offer_Type_Mission
                    ' Define novos tamanhos
                    Windows(GetWindowIndex("winDescription")).Window.width = 298
                    Windows(GetWindowIndex("winDescription")).Controls(GetControlIndex("winDescription", "lblDescription")).width = 192
                    
                    Select Case Mission(inOffer(descItem)).type
                        Case MissionType.Mission_TypeCollect
                            texNum = TextureItem(Item(Mission(inOffer(descItem)).CollectItem).Pic)
                        Case MissionType.Mission_TypeKill
                            texNum = TextureChar(Npc(Mission(inOffer(descItem)).KillNPC).sprite)
                        Case MissionType.Mission_TypeTalk
                            texNum = TextureChar(Npc(Mission(inOffer(descItem)).TalkNPC).sprite)
                    End Select
                    
                    width = 42
                    height = 42
                    
                    x = Xo + 96
                    For i = 1 To 5
                        If Mission(inOffer(descItem)).RewardItem(i).ItemNum > 0 Then
                            RenderTexture TextureItem(Item(Mission(inOffer(descItem)).RewardItem(i).ItemNum).Pic), x + 4, Yo + 97, 0, 0, 32, 32, 32, 32
                        End If
                        RenderTexture TextureGUI(35), x, Yo + 92, 0, 0, width, height, width, height
                        x = x + 38
                    Next
                Case Offers.Offer_Type_Trade
                
                Case Offers.Offer_Type_Party
            End Select
    End Select
    
    ' render sprite
    RenderTexture texNum, Xo + 20, Yo + 34, 0, 0, 64, 64, 32, 32
    
    ' render text array
    y = 18
    count = UBound(descText)
    For i = 1 To count
        RenderText font(Fonts.verdana_12), descText(i).text, Xo + 141 - (TextWidth(font(Fonts.verdana_12), descText(i).text) \ 2), Yo + y, descText(i).Colour
        y = y + 12
    Next
    
    ' close
    HideWindow GetWindowIndex("winDescription")
End Sub

' ##############
' ## Drag Box ##
' ##############

Public Sub DragBox_OnDraw()
Dim Xo As Long, Yo As Long, texNum As Long, winIndex As Long

    winIndex = GetWindowIndex("winDragBox")
    Xo = Windows(winIndex).Window.left
    Yo = Windows(winIndex).Window.top
    
    ' get texture num
    With DragBox
        Select Case .type
            Case partItem
                If .value Then
                    texNum = TextureItem(Item(.value).Pic)
                End If
            Case partISpell
                If .value Then
                    texNum = TextureSpellIcon(Spell(.value).icon)
                End If
        End Select
    End With
    
    ' draw texture
    RenderTexture texNum, Xo, Yo, 0, 0, 32, 32, 32, 32
End Sub

Public Sub DragBox_Check()
Dim winIndex As Long, i As Long, curWindow As Long, curControl As Long, tmpRec As RECT
    
    winIndex = GetWindowIndex("winDragBox")
    
    ' can't drag nuthin'
    If DragBox.type = partNone Then Exit Sub
    
    ' check for other windows
    For i = 1 To WindowCount
        With Windows(i).Window
            If .visible Then
                ' can't drag to self
                If .name <> "winDragBox" Then
                    If currMouseX >= .left And currMouseX <= .left + .width Then
                        If currMouseY >= .top And currMouseY <= .top + .height Then
                            If curWindow = 0 Then curWindow = i
                            If .zOrder > Windows(curWindow).Window.zOrder Then curWindow = i
                        End If
                    End If
                End If
            End If
        End With
    Next
    
    ' we have a window - check if we can drop
    If curWindow Then
        Select Case Windows(curWindow).Window.name
            Case "winBank"
                If DragBox.origin = originBank Then
                    ' it's from the inventory!
                    If DragBox.type = partItem Then
                        ' find the slot to switch with
                        For i = 1 To MAX_BANK
                            With tmpRec
                                .top = Windows(curWindow).Window.top + BankTop + ((BankOffsetY + 32) * ((i - 1) \ BankColumns))
                                .bottom = .top + 32
                                .left = Windows(curWindow).Window.left + BankLeft + ((BankOffsetX + 32) * (((i - 1) Mod BankColumns)))
                                .Right = .left + 32
                            End With
    
                            If currMouseX >= tmpRec.left And currMouseX <= tmpRec.Right Then
                                If currMouseY >= tmpRec.top And currMouseY <= tmpRec.bottom Then
                                    ' switch the slots
                                    If DragBox.Slot <> i Then
                                        ChangeBankSlots DragBox.Slot, i
                                        Exit For
                                    End If
                                End If
                            End If
                        Next
                    End If
                End If
                
                ' se o item saiu do inventario
                If DragBox.origin = originInventory Then
                    If DragBox.type = partItem Then
    
                        If Item(GetPlayerInvItemNum(MyIndex, DragBox.Slot)).type <> ITEM_TYPE_CURRENCY Then
                            DepositItem DragBox.Slot, 1
                        Else
                            Dialogue "Depositar Item", "Insira a quantidade para depósito.", "", TypeDEPOSITITEM, StyleINPUT, DragBox.Slot
                        End If
    
                    End If
                End If
                
            Case "winInventory"
                If DragBox.origin = originInventory Then
                    ' it's from the inventory!
                    If DragBox.type = partItem Then
                        ' find the slot to switch with
                        For i = 1 To MAX_INV
                            With tmpRec
                                .top = Windows(curWindow).Window.top + InvTop + ((InvOffsetY + 32) * ((i - 1) \ InvColumns))
                                .bottom = .top + 32
                                .left = Windows(curWindow).Window.left + InvLeft + ((InvOffsetX + 32) * (((i - 1) Mod InvColumns)))
                                .Right = .left + 32
                            End With
                            
                            If currMouseX >= tmpRec.left And currMouseX <= tmpRec.Right Then
                                If currMouseY >= tmpRec.top And currMouseY <= tmpRec.bottom Then
                                    ' switch the slots
                                    If DragBox.Slot <> i Then SendChangeInvSlots DragBox.Slot, i
                                    Exit For
                                End If
                            End If
                        Next
                    End If
                End If
                
                ' se o item saiu do bank
                If DragBox.origin = originBank Then
                    If DragBox.type = partItem Then
    
                        If Item(Bank.Item(DragBox.Slot).num).type <> ITEM_TYPE_CURRENCY Then
                            WithdrawItem DragBox.Slot, 0
                        Else
                            Dialogue "Retirar Item", "Insira a quantidade que deseja retirar", "", TypeWITHDRAWITEM, StyleINPUT, DragBox.Slot
                        End If
    
                    End If
                End If
            Case "winSkills"
                If DragBox.origin = originSpells Then
                    ' it's from the spells!
                    If DragBox.type = partISpell Then
                        ' find the slot to switch with
                        For i = 1 To MAX_PLAYER_SPELLS
                            With tmpRec
                                .top = Windows(curWindow).Window.top + SkillTop + ((SkillOffsetY + 32) * ((i - 1) \ SkillColumns))
                                .bottom = .top + 32
                                .left = Windows(curWindow).Window.left + SkillLeft + ((SkillOffsetX + 32) * (((i - 1) Mod SkillColumns)))
                                .Right = .left + 32
                            End With
                            
                            If currMouseX >= tmpRec.left And currMouseX <= tmpRec.Right Then
                                If currMouseY >= tmpRec.top And currMouseY <= tmpRec.bottom Then
                                    ' switch the slots
                                    If DragBox.Slot <> i Then SendChangeSpellSlots DragBox.Slot, i
                                    Exit For
                                End If
                            End If
                        Next
                    End If
                End If
            Case "winHotbar"
                If DragBox.origin <> originNone Then
                    If DragBox.type <> partNone Then
                        ' find the slot
                        For i = 1 To MAX_HOTBAR
                            With tmpRec
                                .top = Windows(curWindow).Window.top + HotbarTop
                                .bottom = .top + 32
                                .left = Windows(curWindow).Window.left + HotbarLeft + ((i - 1) * HotbarOffsetX)
                                .Right = .left + 32
                            End With
                            
                            If currMouseX >= tmpRec.left And currMouseX <= tmpRec.Right Then
                                If currMouseY >= tmpRec.top And currMouseY <= tmpRec.bottom Then
                                    ' set the hotbar slot
                                    If DragBox.origin <> originHotbar Then
                                        If DragBox.type = partItem Then
                                            SendHotbarChange 1, DragBox.Slot, i
                                        ElseIf DragBox.type = partISpell Then
                                            SendHotbarChange 2, DragBox.Slot, i
                                        End If
                                    Else
                                        ' SWITCH the hotbar slots
                                        If DragBox.Slot <> i Then SwitchHotbar DragBox.Slot, i
                                    End If
                                    ' exit early
                                    Exit For
                                End If
                            End If
                        Next
                    End If
                End If
        End Select
    Else
        ' no windows found - dropping on bare map
        Select Case DragBox.origin
            Case PartTypeOrigins.originInventory
                If Item(GetPlayerInvItemNum(MyIndex, DragBox.Slot)).type <> ITEM_TYPE_CURRENCY Then
                    SendDropItem DragBox.Slot, GetPlayerInvItemNum(MyIndex, DragBox.Slot)
                Else
                    Dialogue "Drop Item", "Please choose how many to drop", "", TypeDROPITEM, StyleINPUT, GetPlayerInvItemNum(MyIndex, DragBox.Slot)
                End If
            Case PartTypeOrigins.originSpells
                ' dialogue
            Case PartTypeOrigins.originHotbar
                SendHotbarChange 0, 0, DragBox.Slot
        End Select
    End If
    
    ' close window
    HideWindow winIndex
    With DragBox
        .type = partNone
        .Slot = 0
        .origin = originNone
        .value = 0
    End With
End Sub

' ############
' ## Skills ##
' ############

Public Sub Skills_MouseDown()
Dim slotNum As Long, winIndex As Long
    
    ' is there an item?
    slotNum = IsSkill(Windows(GetWindowIndex("winSkills")).Window.left, Windows(GetWindowIndex("winSkills")).Window.top)
    
    If slotNum Then
        With DragBox
            .type = partISpell
            .value = PlayerSpells(slotNum).Spell
            .origin = originSpells
            .Slot = slotNum
        End With
        
        winIndex = GetWindowIndex("winDragBox")
        With Windows(winIndex).Window
            .state = MouseDown
            .left = lastMouseX - 16
            .top = lastMouseY - 16
            .movedX = clickedX - .left
            .movedY = clickedY - .top
        End With
        ShowWindow winIndex, , False
        ' stop dragging inventory
        Windows(GetWindowIndex("winSkills")).Window.state = Normal
    End If

    ' show desc. if needed
    Skills_MouseMove
End Sub

Public Sub Skills_doubleClick()
Dim slotNum As Long

    slotNum = IsSkill(Windows(GetWindowIndex("winSkills")).Window.left, Windows(GetWindowIndex("winSkills")).Window.top)
    
    If slotNum Then
        CastSpell slotNum
    End If
    
    ' show desc. if needed
    Skills_MouseMove
End Sub

Public Sub Skills_MouseMove()
Dim slotNum As Long, x As Long, y As Long

    ' exit out early if dragging
    If DragBox.type <> partNone Then Exit Sub

    slotNum = IsSkill(Windows(GetWindowIndex("winSkills")).Window.left, Windows(GetWindowIndex("winSkills")).Window.top)
    
    If slotNum Then
        ' make sure we're not dragging the item
        If DragBox.type = partItem And DragBox.value = slotNum Then Exit Sub
        ' calc position
        x = Windows(GetWindowIndex("winSkills")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winSkills")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winSkills")).Window.left + Windows(GetWindowIndex("winSkills")).Window.width
        End If
        ' go go go
        ShowPlayerSpellDesc x, y, slotNum
    End If
End Sub

' ############
' ## Hotbar ##
' ############

Public Sub Hotbar_MouseDown()
Dim slotNum As Long, winIndex As Long
    
    ' is there an item?
    slotNum = IsHotbar(Windows(GetWindowIndex("winHotbar")).Window.left, Windows(GetWindowIndex("winHotbar")).Window.top)
    
    If slotNum Then
        With DragBox
            If Hotbar(slotNum).sType = 1 Then ' inventory
                .type = partItem
            ElseIf Hotbar(slotNum).sType = 2 Then ' spell
                .type = partISpell
            End If
            .value = Hotbar(slotNum).Slot
            .origin = originHotbar
            .Slot = slotNum
        End With
        
        winIndex = GetWindowIndex("winDragBox")
        With Windows(winIndex).Window
            .state = MouseDown
            .left = lastMouseX - 16
            .top = lastMouseY - 16
            .movedX = clickedX - .left
            .movedY = clickedY - .top
        End With
        ShowWindow winIndex, , False
        ' stop dragging inventory
        Windows(GetWindowIndex("winHotbar")).Window.state = Normal
    End If

    ' show desc. if needed
    Hotbar_MouseMove
End Sub

Public Sub Hotbar_doubleClick()
Dim slotNum As Long

    slotNum = IsHotbar(Windows(GetWindowIndex("winHotbar")).Window.left, Windows(GetWindowIndex("winHotbar")).Window.top)
    
    If slotNum Then
        SendHotbarUse slotNum
    End If
    
    ' show desc. if needed
    Hotbar_MouseMove
End Sub

Public Sub Hotbar_MouseMove()
Dim slotNum As Long, x As Long, y As Long

    ' exit out early if dragging
    If DragBox.type <> partNone Then Exit Sub

    slotNum = IsHotbar(Windows(GetWindowIndex("winHotbar")).Window.left, Windows(GetWindowIndex("winHotbar")).Window.top)
    
    If slotNum Then
        ' make sure we're not dragging the item
        If DragBox.origin = originHotbar And DragBox.Slot = slotNum Then Exit Sub
        ' calc position
        x = Windows(GetWindowIndex("winHotbar")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winHotbar")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winHotbar")).Window.left + Windows(GetWindowIndex("winHotbar")).Window.width
        End If
        ' go go go
        Select Case Hotbar(slotNum).sType
            Case 1 ' inventory
                ShowItemDesc x, y, Hotbar(slotNum).Slot, False
            Case 2 ' spells
                ShowSpellDesc x, y, Hotbar(slotNum).Slot, 0
        End Select
    End If
End Sub

' Chat
Public Sub btnSay_Click()
    HandleKeyPresses vbKeyReturn
End Sub

Public Sub OnDraw_Chat()
Dim winIndex As Long, Xo As Long, Yo As Long

    winIndex = GetWindowIndex("winChat")
    Xo = Windows(winIndex).Window.left
    Yo = Windows(winIndex).Window.top + 16
    
    ' draw the box
    RenderDesign DesignTypes.designWindowDescription, Xo, Yo, 352, 152
'    ' draw the input box
'    RenderTexture TextureGUI(46), Xo + 7, Yo + 123, 0, 0, 171, 22, 171, 22
'    RenderTexture TextureGUI(46), Xo + 174, Yo + 123, 0, 22, 171, 22, 171, 22
    ' call the chat render
    RenderChat
End Sub

Public Sub OnDraw_ChatSmall()
Dim winIndex As Long, Xo As Long, Yo As Long

    winIndex = GetWindowIndex("winChatSmall")
    
    If actChatWidth < 160 Then actChatWidth = 160
    If actChatHeight < 10 Then actChatHeight = 10
    
    Xo = Windows(winIndex).Window.left + 10
    Yo = ScreenHeight - 16 - actChatHeight - 8
    
    ' draw the background
    RenderDesign DesignTypes.designWindowShadow, Xo, Yo, actChatWidth, actChatHeight
    ' call the chat render
    RenderChat
End Sub

Public Sub chkChat_Game()
    Options.channelState(ChatChannel.chGame) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkGame")).value
    UpdateChat
End Sub

Public Sub chkChat_Map()
    Options.channelState(ChatChannel.chMap) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkMap")).value
    UpdateChat
End Sub

Public Sub chkChat_Global()
    Options.channelState(ChatChannel.chGlobal) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkGlobal")).value
    UpdateChat
End Sub

Public Sub chkChat_Party()
    Options.channelState(ChatChannel.chParty) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkParty")).value
    UpdateChat
End Sub

Public Sub chkChat_Guild()
    Options.channelState(ChatChannel.chGuild) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkGuild")).value
    UpdateChat
End Sub

Public Sub chkChat_Private()
    Options.channelState(ChatChannel.chPrivate) = Windows(GetWindowIndex("winChat")).Controls(GetControlIndex("winChat", "chkPrivate")).value
    UpdateChat
End Sub

Public Sub btnChat_Up()
    ChatButtonUp = True
End Sub

Public Sub btnChat_Down()
    ChatButtonDown = True
End Sub

Public Sub btnChat_Up_MouseUp()
    ChatButtonUp = False
End Sub

Public Sub btnChat_Down_MouseUp()
    ChatButtonDown = False
End Sub

' Options
Public Sub btnOptions_Close()
    HideWindow GetWindowIndex("winOptions")
    ShowWindow GetWindowIndex("winEscMenu")
End Sub

Sub btnOptions_Confirm()
Dim i As Long, value As Long, width As Long, height As Long, message As Boolean, musicFile As String

    ' music
    value = Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "chkMusic")).value
    If Options.Music <> value Then
        Options.Music = value
        ' let them know
        If value = 0 Then
            AddText "Music turned off.", BrightGreen
            Stop_Music
        Else
            AddText "Music tured on.", BrightGreen
            ' play music
            If InGame Then musicFile = Trim$(Map.MapData.Music) Else musicFile = Trim$(MenuMusic)
            If Not musicFile = "None." Then
                Play_Music musicFile
            Else
                Stop_Music
            End If
        End If
    End If
    
    ' sound
    value = Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "chkSound")).value
    If Options.sound <> value Then
        Options.sound = value
        ' let them know
        If value = 0 Then
            AddText "Sound turned off.", BrightGreen
        Else
            AddText "Sound tured on.", BrightGreen
        End If
    End If
    
    ' autotiles
    value = Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "chkAutotiles")).value
    If value = 1 Then value = 0 Else value = 1
    If Options.NoAuto <> value Then
        Options.NoAuto = value
        ' let them know
        If value = 0 Then
            If InGame Then
                AddText "Autotiles turned on.", BrightGreen
                initAutotiles
            End If
        Else
            If InGame Then
                AddText "Autotiles turned off.", BrightGreen
                initAutotiles
            End If
        End If
    End If
    
    ' fullscreen
    value = Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "chkFullscreen")).value
    If Options.Fullscreen <> value Then
        Options.Fullscreen = value
        message = True
    End If
    
    ' resolution
    With Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "cmbRes"))
        If .value > 0 And .value <= RES_COUNT Then
            If Options.Resolution <> .value Then
                Options.Resolution = .value
                If Not isFullscreen Then
                    SetResolution
                Else
                    message = True
                End If
            End If
        End If
    End With
    
    ' render
    With Windows(GetWindowIndex("winOptions")).Controls(GetControlIndex("winOptions", "cmbRender"))
        If .value > 0 And .value <= 3 Then
            If Options.Render <> .value - 1 Then
                Options.Render = .value - 1
                message = True
            End If
        End If
    End With
    
    ' save options
    SaveOptions
    ' let them know
    If InGame Then
        If message Then AddText "Some changes will take effect next time you load the game.", BrightGreen
    End If
    ' close
    btnOptions_Close
End Sub

' OfferWindow

Public Sub Offer_MouseMove()
    Dim OfferNum As Long, x As Long, y As Long, i As Long

    OfferNum = IsOffer(Windows(GetWindowIndex("winOffer")).Window.left, Windows(GetWindowIndex("winOffer")).Window.top)

    If OfferNum > 0 Then

        ' make sure we're not dragging the item
        'If DragBox.Type = PartItem And DragBox.value = OfferNum Then Exit Sub
        ' calc position
        x = Windows(GetWindowIndex("winOffer")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winOffer")).Window.top

        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winOffer")).Window.left + Windows(GetWindowIndex("winOffer")).Window.width - 20
        End If

        ' go go go
        ShowOfferDesc x, y, OfferNum
    End If
End Sub

Public Sub AcceptOffer1()
    ' ACCEPT OFFER
    Select Case inOfferType(1)
        Case Offers.Offer_Type_Mission
            Call SendAcceptMissionRequest(1)
            
        Case Offers.Offer_Type_Trade
            Call SendAcceptTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendAcceptParty
    End Select
    Call UpdateOffers(1)
End Sub

Public Sub RecuseOffer1()
    Select Case inOfferType(1)
        Case Offers.Offer_Type_Mission
            Call SendDeclineMissionRequest

        Case Offers.Offer_Type_Trade
            Call SendDeclineTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendDeclineParty
    End Select
    Call UpdateOffers(1)
End Sub

Public Sub AcceptOffer2()
    ' ACCEPT OFFER
    Select Case inOfferType(2)
        Case Offers.Offer_Type_Mission
            Call SendAcceptMissionRequest(2)
            
        Case Offers.Offer_Type_Trade
            Call SendAcceptTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendAcceptParty
    End Select
    Call UpdateOffers(2)
End Sub

Public Sub RecuseOffer2()
    Select Case inOfferType(2)
        Case Offers.Offer_Type_Mission
            Call SendDeclineMissionRequest
            
        Case Offers.Offer_Type_Trade
            Call SendDeclineTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendDeclineParty
    End Select
    Call UpdateOffers(2)
End Sub

Public Sub AcceptOffer3()
    ' ACCEPT OFFER
    Select Case inOfferType(3)
        Case Offers.Offer_Type_Mission
            Call SendAcceptMissionRequest(3)
            
        Case Offers.Offer_Type_Trade
            Call SendAcceptTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendAcceptParty
    End Select
    Call UpdateOffers(3)
End Sub

Public Sub RecuseOffer3()
    Select Case inOfferType(3)
        Case Offers.Offer_Type_Mission
            Call SendDeclineMissionRequest
            
        Case Offers.Offer_Type_Trade
            Call SendDeclineTradeRequest
            
        Case Offers.Offer_Type_Party
            Call SendDeclineParty
    End Select
    Call UpdateOffers(3)
End Sub

' Npc Chat
Public Sub btnNpcChat_Close()
    HideWindow GetWindowIndex("winNpcChat")
End Sub

Public Sub btnOpt1()
    SendChatOption 1
End Sub
Public Sub btnOpt2()
    SendChatOption 2
End Sub
Public Sub btnOpt3()
    SendChatOption 3
End Sub
Public Sub btnOpt4()
    SendChatOption 4
End Sub

' Shop
Public Sub btnShop_Close()
    CloseShop
End Sub

Public Sub chkShopBuying()
    With Windows(GetWindowIndex("winShop"))
        If .Controls(GetControlIndex("winShop", "chkBuying")).value = 1 Then
            .Controls(GetControlIndex("winShop", "chkSelling")).value = 0
        Else
            .Controls(GetControlIndex("winShop", "chkSelling")).value = 0
            .Controls(GetControlIndex("winShop", "chkBuying")).value = 1
            Exit Sub
        End If
    End With
    ' show buy button, hide sell
    With Windows(GetWindowIndex("winShop"))
        .Controls(GetControlIndex("winShop", "btnSell")).visible = False
        .Controls(GetControlIndex("winShop", "btnBuy")).visible = True
    End With
    ' update the shop
    shopIsSelling = False
    shopSelectedSlot = 1
    UpdateShop
End Sub

Public Sub chkShopSelling()
    With Windows(GetWindowIndex("winShop"))
        If .Controls(GetControlIndex("winShop", "chkSelling")).value = 1 Then
            .Controls(GetControlIndex("winShop", "chkBuying")).value = 0
        Else
            .Controls(GetControlIndex("winShop", "chkBuying")).value = 0
            .Controls(GetControlIndex("winShop", "chkSelling")).value = 1
            Exit Sub
        End If
    End With
    ' show sell button, hide buy
    With Windows(GetWindowIndex("winShop"))
        .Controls(GetControlIndex("winShop", "btnBuy")).visible = False
        .Controls(GetControlIndex("winShop", "btnSell")).visible = True
    End With
    ' update the shop
    shopIsSelling = True
    shopSelectedSlot = 1
    UpdateShop
End Sub

Public Sub btnShopBuy()
    BuyItem shopSelectedSlot
End Sub

Public Sub btnShopSell()
    SellItem shopSelectedSlot
End Sub

Public Sub Shop_MouseDown()
Dim shopNum As Long
    
    ' is there an item?
    shopNum = IsShopSlot(Windows(GetWindowIndex("winShop")).Window.left, Windows(GetWindowIndex("winShop")).Window.top)
    
    If shopNum Then
        ' set the active slot
        shopSelectedSlot = shopNum
        UpdateShop
    End If
    
    Shop_MouseMove
End Sub

Public Sub Shop_MouseMove()
Dim shopSlot As Long, ItemNum As Long, x As Long, y As Long

    If InShop = 0 Then Exit Sub

    shopSlot = IsShopSlot(Windows(GetWindowIndex("winShop")).Window.left, Windows(GetWindowIndex("winShop")).Window.top)
    
    If shopSlot Then
        ' calc position
        x = Windows(GetWindowIndex("winShop")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winShop")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winShop")).Window.left + Windows(GetWindowIndex("winShop")).Window.width
        End If
        ' selling/buying
        If Not shopIsSelling Then
            ' get the itemnum
            ItemNum = Shop(InShop).TradeItem(shopSlot).Item
            If ItemNum = 0 Then Exit Sub
            ShowShopDesc x, y, ItemNum
        Else
            ' get the itemnum
            ItemNum = GetPlayerInvItemNum(MyIndex, shopSlot)
            If ItemNum = 0 Then Exit Sub
            ShowShopDesc x, y, ItemNum
        End If
    End If
End Sub

' Right Click Menu
Sub RightClick_Close()
    ' close all menus
    HideWindow GetWindowIndex("winRightClickBG")
    HideWindow GetWindowIndex("winPlayerMenu")
End Sub

' Player Menu
Sub PlayerMenu_Party()
    RightClick_Close
    If PlayerMenuIndex = 0 Then Exit Sub
    SendPartyRequest PlayerMenuIndex
End Sub

Sub PlayerMenu_Trade()
    RightClick_Close
    If PlayerMenuIndex = 0 Then Exit Sub
    SendTradeRequest PlayerMenuIndex
End Sub

Sub PlayerMenu_Guild()
    RightClick_Close
    If PlayerMenuIndex = 0 Then Exit Sub
    AddText "System not yet in place.", BrightRed
End Sub

Sub PlayerMenu_PM()
    RightClick_Close
    If PlayerMenuIndex = 0 Then Exit Sub
    AddText "System not yet in place.", BrightRed
End Sub

' Trade
Sub btnTrade_Close()
    HideWindow GetWindowIndex("winTrade")
    DeclineTrade
End Sub

Sub btnTrade_Accept()
    AcceptTrade
End Sub

Sub TradeMouseDown_Your()
Dim Xo As Long, Yo As Long, ItemNum As Long
    Xo = Windows(GetWindowIndex("winTrade")).Window.left + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picYour")).left
    Yo = Windows(GetWindowIndex("winTrade")).Window.top + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picYour")).top
    ItemNum = IsTrade(Xo, Yo)
    
    ' make sure it exists
    If ItemNum > 0 Then
        If TradeYourOffer(ItemNum).num = 0 Then Exit Sub
        If GetPlayerInvItemNum(MyIndex, TradeYourOffer(ItemNum).num) = 0 Then Exit Sub
        
        ' unoffer the item
        UntradeItem ItemNum
    End If
End Sub

Sub TradeMouseMove_Your()
Dim Xo As Long, Yo As Long, ItemNum As Long, x As Long, y As Long
    Xo = Windows(GetWindowIndex("winTrade")).Window.left + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picYour")).left
    Yo = Windows(GetWindowIndex("winTrade")).Window.top + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picYour")).top
    ItemNum = IsTrade(Xo, Yo)
    
    ' make sure it exists
    If ItemNum > 0 Then
        If TradeYourOffer(ItemNum).num = 0 Then Exit Sub
        If GetPlayerInvItemNum(MyIndex, TradeYourOffer(ItemNum).num) = 0 Then Exit Sub
        
        ' calc position
        x = Windows(GetWindowIndex("winTrade")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winTrade")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winTrade")).Window.left + Windows(GetWindowIndex("winTrade")).Window.width
        End If
        ' go go go
        ShowItemDesc x, y, GetPlayerInvItemNum(MyIndex, TradeYourOffer(ItemNum).num), False
    End If
End Sub

Sub TradeMouseMove_Their()
Dim Xo As Long, Yo As Long, ItemNum As Long, x As Long, y As Long
    Xo = Windows(GetWindowIndex("winTrade")).Window.left + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picTheir")).left
    Yo = Windows(GetWindowIndex("winTrade")).Window.top + Windows(GetWindowIndex("winTrade")).Controls(GetControlIndex("winTrade", "picTheir")).top
    ItemNum = IsTrade(Xo, Yo)
    
    ' make sure it exists
    If ItemNum > 0 Then
        If TradeTheirOffer(ItemNum).num = 0 Then Exit Sub
        
        ' calc position
        x = Windows(GetWindowIndex("winTrade")).Window.left - Windows(GetWindowIndex("winDescription")).Window.width
        y = Windows(GetWindowIndex("winTrade")).Window.top - 4
        ' offscreen?
        If x < 0 Then
            ' switch to right
            x = Windows(GetWindowIndex("winTrade")).Window.left + Windows(GetWindowIndex("winTrade")).Window.width
        End If
        ' go go go
        ShowItemDesc x, y, TradeTheirOffer(ItemNum).num, False
    End If
End Sub

' combobox
Sub CloseComboMenu()
    HideWindow GetWindowIndex("winComboMenuBG")
    HideWindow GetWindowIndex("winComboMenu")
End Sub
