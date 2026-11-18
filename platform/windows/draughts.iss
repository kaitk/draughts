; The Windows installer, built by scripts/windows.py --release with Inno Setup 6's ISCC,
; which passes Version, Exe, and OutDir. Unsigned (docs/development.md, "Desktop releases").
; Per user by default, so no administrator is asked for; the dialog offers all users.
; Uninstalling leaves the settings and saved games, which the app keeps in %APPDATA%.

[Setup]
AppId={{6F1C2B7E-3D5A-4E8B-9A41-D7C2E5B8F903}
AppName=Draughts
AppVersion={#Version}
AppVerName=Draughts {#Version}
AppPublisher=Gideonic
AppPublisherURL=https://kaitk.github.io/draughts/
DefaultDirName={autopf}\Draughts
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=draughts.ico
UninstallDisplayIcon={app}\Draughts.exe
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
OutputDir={#OutDir}
OutputBaseFilename=Draughts-{#Version}-windows-x64-setup

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Exe}"; DestDir: "{app}"; DestName: "Draughts.exe"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Draughts"; Filename: "{app}\Draughts.exe"
Name: "{autodesktop}\Draughts"; Filename: "{app}\Draughts.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Draughts.exe"; Description: "{cm:LaunchProgram,Draughts}"; Flags: nowait postinstall skipifsilent
