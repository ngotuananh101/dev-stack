#define MyAppName "Dev Stack"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Ponta Dev"
#define MyAppURL "https://github.com/ngotuananh101/dev-stack"
#define MyAppExeName "dev_stack.exe"
#define MyAppIconName "icon.ico"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Click Tools | Generate GUID in the Inno Setup IDE to generate a new one.
AppId={{D8C8B1C2-8E3A-4F7F-B6A2-9E8E9A7B4F7F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Ponta\{#MyAppName}
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=DevStack_Setup
SetupIconFile="..\assets\images\{#MyAppIconName}"
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  BaseDir: String;
  UserDataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    BaseDir := 'C:\Ponta';
    UserDataDir := ExpandConstant('{%APPDATA}\com.ponta\dev_stack');

    if DirExists(BaseDir) then
    begin
      if MsgBox('Do you want to delete all app data?' + #13#10 +
                '(' + BaseDir + ')' + #13#10#13#10 +
                'This includes installed apps, databases, logs, certificates, and vhosts.',
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        DelTree(BaseDir, True, True, True);
        Log('Deleted base directory: ' + BaseDir);
      end;
    end;

    if DirExists(UserDataDir) then
    begin
      if MsgBox('Do you want to delete user settings?' + #13#10 +
                '(' + UserDataDir + ')' + #13#10#13#10 +
                'This includes application preferences and saved state.',
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        DelTree(UserDataDir, True, True, True);
        Log('Deleted user data directory: ' + UserDataDir);
      end;
    end;
  end;
end;
