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
var
  DeleteDataPage: TInputOptionWizardPage;

procedure InitializeWizard;
begin
  DeleteDataPage := CreateInputOptionPage(wpSelectDir,
    'Data Cleanup', 'Choose what to remove on uninstall.',
    'Select the data you want removed when uninstalling {#MyAppName}.',
    False, False);
  DeleteDataPage.Add('Delete all app data (C:\Ponta) — apps, databases, logs, certs, vhosts');
  DeleteDataPage.Add('Delete user settings (%APPDATA%\dev_stack)');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  BaseDir: String;
  UserDataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    BaseDir := 'C:\Ponta';
    UserDataDir := ExpandConstant('{%APPDATA}\dev_stack');

    if DeleteDataPage.Values[0] then
    begin
      if DirExists(BaseDir) then
      begin
        DelTree(BaseDir, True, True, True);
        Log('Deleted base directory: ' + BaseDir);
      end;
    end;

    if DeleteDataPage.Values[1] then
    begin
      if DirExists(UserDataDir) then
      begin
        DelTree(UserDataDir, True, True, True);
        Log('Deleted user data directory: ' + UserDataDir);
      end;
    end;
  end;
end;
