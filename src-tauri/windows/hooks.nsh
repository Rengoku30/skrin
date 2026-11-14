; Skrin's additions to Tauri's NSIS installer (tauri.installer.conf.json).
;
; Uninstalling leaves nothing of Skrin's behind: Tauri's own uninstaller
; takes the program, its shortcuts and its Apps entry, and asks with a
; checkbox before deleting the library and settings. These hooks add what
; Tauri does not know about. None of them runs for an update (/UPDATE), when
; the old version is removed only to be replaced.

!macro NSIS_HOOK_PREUNINSTALL
  ${If} $UpdateMode <> 1
    ; Skrin must be closed first, so the clean-up is not undone by a
    ; Skrin that keeps running, or wasted on an uninstall that is cancelled.
    !insertmacro CheckIfAppIsRunning "${MAINBINARYNAME}.exe" "${PRODUCTNAME}"
    ; "Offer Skrin as a video player" (default_player.rs): the same Remove
    ; as in Settings, plus Windows' cached name for the program.
    ExecWait '"$INSTDIR\${MAINBINARYNAME}.exe" --uninstall-cleanup'
  ${EndIf}
!macroend

!macro NSIS_HOOK_POSTUNINSTALL
  ${If} $UpdateMode <> 1
    ; Where Skrin was installed. Tauri keeps it unless the library is
    ; deleted too, to suggest the same folder next time; a program that has
    ; been removed should not leave its address behind.
    DeleteRegKey HKCU "${MANUPRODUCTKEY}"
    DeleteRegKey /ifempty HKCU "${MANUKEY}"
    ; What Windows' shell wrote about Skrin by itself, keyed by its app id:
    ; the Start menu's tile and the jump list (seen in Windows Sandbox).
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Start\TileProperties\W~${BUNDLEID}"
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Search\JumplistData" "${BUNDLEID}"
    ; And Windows' cached name for this uninstaller, which runs from a copy
    ; in the temporary folder (Skrin's own is cleared by --uninstall-cleanup).
    DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$EXEPATH.FriendlyAppName"
    DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$EXEPATH.ApplicationCompany"
    ; The built-in browser's cache and its .cookies file. Skrin's library and
    ; settings are in %APPDATA% and are not touched here (Tauri's checkbox
    ; decides); nothing in this folder is the person's own.
    RMDir /r "$LOCALAPPDATA\${BUNDLEID}"
  ${EndIf}
!macroend

; Kinema became Skrin in 0.17.0: a new name is a new program to Windows, with
; its own folder (%LOCALAPPDATA%\Skrin), Apps entry and shortcuts. So when
; Kinema is installed, its uninstaller is run first as an update (/UPDATE: the
; program files and its Apps entry go; the library and settings in
; %APPDATA%\com.kinema.app stay, as the app id did not change, and so do the
; "Open with" entries, which the renamed program moves to itself at launch,
; default_player.rs). An update leaves the old shortcuts, so they are taken
; here, unpinned first, with the old folder's address and Windows' cached
; name for the old program. Runs before any file is copied.
!macro NSIS_HOOK_PREINSTALL
  ReadRegStr $R8 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Kinema" "UninstallString"
  ${If} $R8 != ""
    !insertmacro CheckIfAppIsRunning "kinema.exe" "Kinema"
    ReadRegStr $R9 HKCU "Software\Basswaves\Kinema" ""
    ${If} $R9 == ""
      StrCpy $R9 "$LOCALAPPDATA\Kinema"
    ${EndIf}
    ExecWait '$R8 /S /UPDATE _?=$R9'
    Delete "$R9\uninstall.exe"
    RMDir "$R9"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Kinema"
    DeleteRegKey HKCU "Software\Basswaves\Kinema"
    !insertmacro UnpinShortcut "$SMPROGRAMS\Kinema.lnk"
    Delete "$SMPROGRAMS\Kinema.lnk"
    !insertmacro UnpinShortcut "$DESKTOP\Kinema.lnk"
    Delete "$DESKTOP\Kinema.lnk"
    ; A pin the unpin above could not take (its shortcut already gone) would
    ; point at a program that is no more.
    Delete "$APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Kinema.lnk"
    DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$R9\kinema.exe.FriendlyAppName"
    DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$R9\kinema.exe.ApplicationCompany"
  ${EndIf}
!macroend

; A setup run by hand over an installed Skrin updates in place.
;
; Tauri's "already installed" page pre-selects "uninstall before installing"
; for an upgrade, and then runs the old uninstaller as a real uninstall: the
; taskbar pin and the shortcuts go (Tauri's UnpinShortcut) and so does the
; default-player registration (--uninstall-cleanup). Only /UPDATE makes it
; an update, and the page cannot be told to pass it. So when this setup is
; run over an installed Skrin (any version) and was not started as an update, it
; starts itself again as one ("/P /UPDATE /R", what Tauri's own updater
; passes: no pages, files replaced in place, Skrin started at the end) and
; quits (MUI calls it as .onGUIInit). Silent installs (winget) never reach it and are unchanged.
; Over Kinema (before 0.17.0) the setup runs with its pages, as a first
; install of the new name; NSIS_HOOK_PREINSTALL above takes Kinema away.
;
; This file is read before the template's variables and defines exist, so it
; uses registers, literal names and its own version from the file header.
!define MUI_CUSTOMFUNCTION_GUIINIT SkrinUpdateInPlace
Function SkrinUpdateInPlace
  ${GetOptions} $CMDLINE "/UPDATE" $0
  ${IfNot} ${Errors}
    Return
  ${EndIf}
  ${GetOptions} $CMDLINE "/P" $0
  ${IfNot} ${Errors}
    Return
  ${EndIf}
  ReadRegStr $2 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Skrin" "DisplayVersion"
  ${If} $2 == ""
    Return
  ${EndIf}
  ; Newer, the same or older: all go in place. Only an uninstall the person
  ; asks for removes the shortcuts and the default-player entries, never a
  ; second run of the setup.
  Exec '"$EXEPATH" /P /UPDATE /R'
  Quit
FunctionEnd
