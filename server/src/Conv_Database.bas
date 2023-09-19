Attribute VB_Name = "Conv_Database"
' ***********
' ** Convs **
' ***********
Public Sub SaveConv(ByVal convNum As Long)
    Dim filename As String
    Dim i As Long, x As Long, f As Long

    filename = App.Path & "\data\convs\conv" & convNum & ".dat"
    f = FreeFile

    Open filename For Binary As #f
    With Conv(convNum)
        Put #f, , .Name
        Put #f, , .chatCount
        For i = 1 To .chatCount
            Put #f, , CLng(Len(.Conv(i).Conv))
            Put #f, , .Conv(i).Conv
            For x = 1 To 4
                Put #f, , CLng(Len(.Conv(i).rText(x)))
                Put #f, , .Conv(i).rText(x)
                Put #f, , .Conv(i).rTarget(x)
            Next
            Put #f, , .Conv(i).Event
            Put #f, , .Conv(i).Data1
            Put #f, , .Conv(i).Data2
            Put #f, , .Conv(i).Data3
        Next
    End With
    Close #f
End Sub

Public Sub SaveConvs()
    Dim i As Long

    For i = 1 To MAX_CONVS
        Call SaveConv(i)
    Next
End Sub

Public Sub CheckConvs()
    Dim i As Long

    For i = 1 To MAX_CONVS
        If Not FileExist(App.Path & "\data\convs\conv" & i & ".dat") Then
            Call SaveConv(i)
        End If
    Next
End Sub

Public Sub LoadConvs()
    Dim filename As String
    Dim i As Long, n As Long, x As Long, f As Long
    Dim sLen As Long

    Call CheckConvs

    For i = 1 To MAX_CONVS
        filename = App.Path & "\data\convs\conv" & i & ".dat"
        f = FreeFile
        Open filename For Binary As #f
        With Conv(i)
            Get #f, , .Name
            Get #f, , .chatCount
            If .chatCount > 0 Then ReDim .Conv(1 To .chatCount)
            For n = 1 To .chatCount
                Get #f, , sLen
                .Conv(n).Conv = Space$(sLen)
                Get #f, , .Conv(n).Conv
                For x = 1 To 4
                    Get #f, , sLen
                    .Conv(n).rText(x) = Space$(sLen)
                    Get #f, , .Conv(n).rText(x)
                    Get #f, , .Conv(n).rTarget(x)
                Next
                Get #f, , .Conv(n).Event
                Get #f, , .Conv(n).Data1
                Get #f, , .Conv(n).Data2
                Get #f, , .Conv(n).Data3
            Next
        End With
        Close #f
    Next
End Sub

Public Sub ClearConv(ByVal index As Long)
    Call ZeroMemory(ByVal VarPtr(Conv(index)), LenB(Conv(index)))
    Conv(index).Name = vbNullString
    ReDim Conv(index).Conv(1)
End Sub

Public Sub ClearConvs()
    Dim i As Long

    For i = 1 To MAX_CONVS
        Call ClearConv(i)
    Next

End Sub