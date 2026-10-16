; Inno Setup script for the Windows installer.
;
; Built in CI on the Windows runner (Inno Setup is preinstalled there) with
; `ISCC /DMyAppVersion=<x.y.z> packaging\windows\relay.iss` after
; `flutter build windows --release`. The output is attached to the GitHub
; release as relay-<version>-windows-x64-setup.exe.
;
; Per-user install (no UAC) so the in-app updater can run the installer
; silently without an elevation prompt; workspace data lives in %APPDATA%
; and is untouched by installs and updates.

#define MyAppName "Röle"
#define MyAppExeName "relay.exe"
#define MyAppPublisher "Röle"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{9A9F82CB-84B4-4ADE-BFD6-E4464E917169}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Röle
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
SourceDir=..\..
OutputDir=build\windows\installer
OutputBaseFilename=relay-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall
