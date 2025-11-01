#define MyAppName "CloudToLocalLLM"
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef SourceDir
#define SourceDir "."
#endif
#ifndef BuildDir
#define BuildDir "build\windows\x64\runner\Release"
#endif
#define MyAppPublisher "CloudToLocalLLM"
#define MyAppURL "https://cloudtolocalllm.online"
#define MyAppExeName "cloudtolocalllm.exe"

[Setup]
AppId={{com.cloudtolocalllm.app}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog commandline
PrivilegesRequired=lowest
OutputBaseFilename=CloudToLocalLLM-Windows-{#MyAppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  
  // If we're not running as admin and not explicitly asked for current user, ask user what they want
  if not IsAdminLoggedOn and (Pos('/CURRENTUSER', UpperCase(GetCmdTail)) = 0) then
  begin
    case SuppressibleMsgBox(
      'This application can be installed for all users or just for the current user.' + Chr(13) + Chr(10) + 
      Chr(13) + Chr(10) +
      'Installing for all users requires administrator privileges.' + Chr(13) + Chr(10) +
      'Installing for the current user only does not require administrator privileges.' + Chr(13) + Chr(10) +
      Chr(13) + Chr(10) +
      'Would you like to install for all users (Yes) or just for yourself (No)?',
      mbConfirmation, MB_YESNOCANCEL, IDNO) of
      IDYES:
        begin
          // Try to elevate with UAC prompt
          if ShellExecute('', 'open', ExpandConstant('{srcexe}'), '/ALLUSERS', '',
             SW_SHOWNORMAL, ewNoWait, ErrorCode) then
          begin
            // Successfully launched elevated instance, terminate this instance
            Result := False;
            Exit;
          end
          else begin
            // Failed to elevate
            SuppressibleMsgBox('Failed to launch elevated installer. ' +
              'You may try running this installer as an administrator.', mbError, MB_OK, IDOK);
            Result := False;
            Exit;
          end;
        end;
      IDNO:
        begin
          // Install for current user only - will be initialized in InitializeWizard
        end;
      IDCANCEL:
        begin
          Result := False;
        end;
    end;
  end;
end;

procedure InitializeWizard;
begin
  // If installing for current user only, change the default directory
  if (Pos('/CURRENTUSER', UpperCase(GetCmdTail)) > 0) or not IsAdminLoggedOn then
  begin
    WizardForm.DirEdit.Text := ExpandConstant('{localappdata}\{#MyAppName}');
  end;
end; 
