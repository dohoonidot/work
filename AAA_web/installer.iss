; ASPN AI Agent Installer Script for Inno Setup
;
; 사용법:
; 1. Flutter 빌드: flutter build windows --release
; 2. Inno Setup Compiler에서 이 파일 열기
; 3. Compile 버튼 클릭
; 4. Output\ASPN_AI_Agent_Setup_v1.3.1.exe 생성됨

[Setup]
AppName=ASPN AI Agent
AppVersion=1.3.1
AppPublisher=ASPN
AppPublisherURL=https://github.com/dohooniaspn/ASPN_AI_AGENT
DefaultDirName={autodesktop}\ASPN AI Agent
DefaultGroupName=ASPN AI Agent
OutputDir=Output
OutputBaseFilename=ASPN_AI_Agent_Setup_v1.3.1
Compression=lzma2
SolidCompression=yes
SetupIconFile=assets\icon\ASPN_AAA_logo.ico
UninstallDisplayIcon={app}\ASPN_AI_Agent.exe
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DisableWelcomePage=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕화면에 바로가기 만들기"; GroupDescription: "추가 아이콘:";
Name: "startupicon"; Description: "시작 프로그램에 등록"; GroupDescription: "시작 옵션:";

[Files]
; 빌드된 전체 폴더 복사
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ASPN AI Agent"; Filename: "{app}\ASPN_AI_Agent.exe"
Name: "{group}\ASPN AI Agent 제거"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ASPN AI Agent"; Filename: "{app}\ASPN_AI_Agent.exe"; Tasks: desktopicon

[Run]
; 설치 후 자동 실행 (SILENT 모드에서도 항상 실행)
Filename: "{app}\ASPN_AI_Agent.exe"; Description: "ASPN AI Agent 실행"; Flags: nowait

[Registry]
; 시작 프로그램 등록
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "ASPN AI Agent"; ValueData: """{app}\ASPN_AI_Agent.exe"""; Flags: uninsdeletevalue; Tasks: startupicon

[Code]
// 기존 실행 중인 앱 자동 종료
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
  AppRunning: Boolean;
begin
  Result := True;

  // taskkill로 실행 중인 앱 확인 및 종료
  Exec('taskkill', '/IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  // ResultCode 0 = 프로세스를 찾아서 종료함
  // ResultCode 128 = 프로세스를 찾지 못함 (실행 중이 아님)
  AppRunning := (ResultCode = 0);

  if AppRunning then
  begin
    // SILENT 모드인 경우 자동으로 종료
    if WizardSilent() then
    begin
      // 강제 종료
      Exec('taskkill', '/F /IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1500);
      Result := True;
    end
    else
    begin
      // 일반 설치 모드에서는 사용자에게 확인
      if MsgBox('ASPN AI Agent가 실행 중입니다. 종료하고 계속하시겠습니까?', mbConfirmation, MB_YESNO) = IDYES then
      begin
        Exec('taskkill', '/F /IM ASPN_AI_Agent.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Sleep(1500);
        Result := True;
      end
      else
      begin
        Result := False;
      end;
    end;
  end;
end;
