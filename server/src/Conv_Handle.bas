Attribute VB_Name = "Conv_Handle"
' :::::::::::::::::::::::::::::
' :: Request edit Conv packet ::
' :::::::::::::::::::::::::::::
Public Sub HandleRequestEditConv(ByVal index As Long, ByRef Data() As Byte, ByVal StartAddr As Long, ByVal ExtraVar As Long)
    Dim Buffer As clsBuffer

    ' Prevent hacking
    If GetPlayerAccess(index) < ADMIN_DEVELOPER Then
        Exit Sub
    End If

    Set Buffer = New clsBuffer
    Buffer.WriteLong SConvEditor
    SendDataTo index, Buffer.ToArray()
    Buffer.Flush: Set Buffer = Nothing
End Sub

Public Sub HandleRequestConvs(ByVal index As Long, ByRef Data() As Byte, ByVal StartAddr As Long, ByVal ExtraVar As Long)
    SendConvs index
End Sub

' :::::::::::::::::::::::
' :: Save Conv packet ::
' :::::::::::::::::::::::
Public Sub HandleSaveConv(ByVal index As Long, ByRef Data() As Byte, ByVal StartAddr As Long, ByVal ExtraVar As Long)
    Dim convNum As Long
    Dim Buffer As clsBuffer
    Dim i As Long
    Dim x As Long

    ' Prevent hacking
    If GetPlayerAccess(index) < ADMIN_DEVELOPER Then
        Exit Sub
    End If

    Set Buffer = New clsBuffer
    Buffer.WriteBytes Data()
    convNum = Buffer.ReadLong

    ' Prevent hacking
    If convNum < 0 Or convNum > MAX_CONVS Then
        Exit Sub
    End If

    With Conv(convNum)
        .Name = Buffer.ReadString
        .chatCount = Buffer.ReadLong
        ReDim .Conv(1 To .chatCount)
        For i = 1 To .chatCount
            .Conv(i).Conv = Buffer.ReadString
            For x = 1 To 4
                .Conv(i).rText(x) = Buffer.ReadString
                .Conv(i).rTarget(x) = Buffer.ReadLong
            Next
            .Conv(i).Event = Buffer.ReadLong
            .Conv(i).Data1 = Buffer.ReadLong
            .Conv(i).Data2 = Buffer.ReadLong
            .Conv(i).Data3 = Buffer.ReadLong
        Next
    End With
    
    ' Save it
    Call SendUpdateConvToAll(convNum)
    Call SaveConv(convNum)
    Call AddLog(GetPlayerName(index) & " saved Conv #" & convNum & ".", ADMIN_LOG)
End Sub