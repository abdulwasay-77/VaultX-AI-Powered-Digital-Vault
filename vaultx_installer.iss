; VaultX installer script for Inno Setup
; Compile with: Inno Setup Compiler -> File > Open this file -> Build > Compile (or press F9)

#define MyAppName "VaultX"
#define MyAppVersion "1.0"
#define MyAppPublisher "Abdul Wasay"
#define MyAppExeName "VaultX.bat"

[Setup]
AppId={{9F3E1B7A-2C6D-4F1B-9A3E-VAULTX000001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Installer needs admin rights to write to Program Files
PrivilegesRequired=admin
OutputDir=installer_output
OutputBaseFilename=VaultX-Setup
SetupIconFile=vaultx_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
LicenseFile=LICENSE.md

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; --- Backend: everything PyInstaller produced, goes into a "backend" subfolder ---
Source: "vaultx_backend\dist\vaultx_backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- Frontend: everything from the Flutter release build ---
Source: "vaultx_frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- Launcher that starts both together ---
Source: "VaultX.bat"; DestDir: "{app}"; Flags: ignoreversion

; --- Icon used for shortcuts ---
Source: "vaultx_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\vaultx_icon.ico"; WorkingDir: "{app}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\vaultx_icon.ico"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName} now"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up backend's created data/uploads/backups folders on uninstall (optional —
; remove this section if you'd rather keep user data after uninstall)
Type: filesandordirs; Name: "{app}\backend\data"
Type: filesandordirs; Name: "{app}\backend\uploads"
Type: filesandordirs; Name: "{app}\backend\backups"
