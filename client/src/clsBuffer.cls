VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsBuffer"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
Private buffer() As Byte
Private buffersize As Long
Private WriteHead As Long
Private ReadHead As Long

Private Sub Class_Initialize()
    Flush
End Sub

Public Sub PreAllocate(ByVal nLength As Long)
    WriteHead = 0
    ReadHead = 0
    buffersize = nLength - 1
    ReDim buffer(0 To buffersize)
End Sub

Public Sub Allocate(ByVal nLength As Long)

    If buffersize = 0 And nLength > 1 Then nLength = nLength - 1
    buffersize = buffersize + nLength
    ReDim Preserve buffer(0 To buffersize)
End Sub

Public Sub Flush()
    WriteHead = 0
    ReadHead = 0
    buffersize = 0
    ReDim buffer(0)
End Sub

Public Sub Trim()
    Dim c As Long

    ' If the readhead is past the buffersize, this means everything has been read in the array, flush it
    If ReadHead >= count Then
        Flush
    End If

End Sub

Public Sub WriteByte(ByVal nByte As Byte)

    If WriteHead > buffersize Then Allocate 1
    buffer(WriteHead) = nByte
    WriteHead = WriteHead + 1
End Sub

Public Sub WriteBytes(ByRef nByte() As Byte)
    Dim nLength As Long
    nLength = (UBound(nByte) - LBound(nByte)) + 1

    If WriteHead + nLength - 1 > buffersize Then Allocate nLength
    CopyMemory buffer(WriteHead), nByte(0), nLength
    WriteHead = WriteHead + nLength
End Sub

Public Sub WriteInteger(ByVal nInteger As Integer)

    If WriteHead + 1 > buffersize Then Allocate 2
    CopyMemory buffer(WriteHead), nInteger, 2
    WriteHead = WriteHead + 2
End Sub

Public Sub WriteLong(ByVal nLong As Long)

    If WriteHead + 3 > buffersize Then Allocate 4
    CopyMemory buffer(WriteHead), nLong, 4
    WriteHead = WriteHead + 4
End Sub

Public Sub WriteString(ByRef nString As String)
    Dim sBytes() As Byte
    Dim sLength As Long
    sLength = Len(nString)
    sBytes = StrConv(nString, vbFromUnicode)
    WriteLong sLength

    If sLength <= 0 Then Exit Sub
    If WriteHead + sLength - 1 > buffersize Then Allocate sLength
    CopyMemory buffer(WriteHead), sBytes(0), sLength
    WriteHead = WriteHead + sLength
End Sub

Public Function ReadByte(Optional MoveReadHead As Boolean = True) As Byte

    If ReadHead > buffersize Then Exit Function
    ReadByte = buffer(ReadHead)

    If MoveReadHead Then ReadHead = ReadHead + 1
End Function

Public Function ReadBytes(ByVal nLength As Long, Optional MoveReadHead As Boolean = True) As Byte()
    Dim Data() As Byte

    If nLength = 0 Then Exit Function
    If ReadHead + nLength - 1 > buffersize Then Exit Function
    ReDim Data(nLength - 1)
    CopyMemory Data(0), buffer(ReadHead), nLength

    If MoveReadHead Then ReadHead = ReadHead + nLength
    ReadBytes = Data
End Function

Public Function ReadInteger(Optional MoveReadHead As Boolean = True) As Integer

    If ReadHead + 1 > buffersize Then Exit Function
    CopyMemory ReadInteger, buffer(ReadHead), 2

    If MoveReadHead Then ReadHead = ReadHead + 2
End Function

Public Function ReadLong(Optional MoveReadHead As Boolean = True) As Long

    If ReadHead + 3 > buffersize Then Exit Function
    CopyMemory ReadLong, buffer(ReadHead), 4

    If MoveReadHead Then ReadHead = ReadHead + 4
End Function

Public Function ReadString(Optional MoveReadHead As Boolean = True) As String
    Dim sLength As Long
    Dim sBytes() As Byte
    sLength = ReadLong(False)

    If sLength <= 0 Then
        If MoveReadHead Then ReadHead = ReadHead + 4
        Exit Function
    End If

    ReDim sBytes(sLength - 1)
    CopyMemory sBytes(0), buffer(ReadHead + 4), sLength
    ReadString = StrConv(sBytes, vbUnicode)

    If MoveReadHead Then ReadHead = ReadHead + sLength + 4
End Function

Public Function count() As Long
    count = (UBound(buffer) - LBound(buffer)) + 1
End Function

Public Function length() As Long
    length = count - ReadHead
End Function

Public Function ToArray() As Byte()
    ToArray = buffer()
End Function

Public Function ToString() As String
    ToString = StrConv(buffer, vbUnicode)
End Function

Public Function CompressBuffer() As Long
    'zlib
    Dim result As Long
    Dim Size As Long
    Dim tempSize As Long
    Dim tempBuffer() As Byte
    Dim compressed() As Byte
    CompressBuffer = -1
    tempSize = count

    If tempSize > 0 Then
        Size = tempSize
        Size = Size + (Size * 0.01) + 12
        ReDim tempBuffer(0 To Size - 1) As Byte
        result = Compress(tempBuffer(0), Size, buffer(0), tempSize)

        If result = 0 Then
            ReDim compressed(0 To Size - 1)
            CopyMemory compressed(0), tempBuffer(0), Size
            Flush
            WriteLong tempSize      ' original size
            WriteLong Size          ' compressed size
            WriteBytes compressed() ' compressed data
            CompressBuffer = 0
        End If
    End If

End Function

Public Function DecompressBuffer() As Long
    'zlib
    Dim result As Long
    Dim OrigSize As Long
    Dim tempBuffer() As Byte
    Dim compressed() As Byte
    DecompressBuffer = -1

    If count > 0 Then
        OrigSize = ReadLong + 1
        ReDim tempBuffer(0 To OrigSize - 1) As Byte
        compressed = ReadBytes(ReadLong)
        result = uncompress(tempBuffer(0), OrigSize, compressed(0), UBound(compressed) + 1)

        If result = 0 Then
            ReDim compressed(0 To OrigSize - 1)
            CopyMemory compressed(0), tempBuffer(0), OrigSize
            Flush
            WriteBytes compressed()
            DecompressBuffer = 0
        End If
    End If

End Function
