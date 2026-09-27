Option Explicit
Dim shell, files, folder, command
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
folder = files.GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & folder & "\Monitor.ps1"""
If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "/tray" Then command = command & " -Tray"
End If
shell.Run command, 0, False
