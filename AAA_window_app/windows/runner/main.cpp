#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <string>
#include <fstream>

#include "flutter_window.h"
#include "utils.h"

#pragma comment(lib, "shlwapi.lib")

bool IsShortcutCreated() {
    wchar_t appDataPath[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, appDataPath))) {
        std::wstring configDir = std::wstring(appDataPath) + L"\\ASPN AI AGENT";
        CreateDirectoryW(configDir.c_str(), NULL);
        
        std::wstring configPath = configDir + L"\\config.ini";
        
        // Check if file exists and has shortcut_created=true
        std::ifstream configFile(configPath);
        if (configFile.is_open()) {
            std::string line;
            while (getline(configFile, line)) {
                if (line == "shortcut_created=true") {
                    configFile.close();
                    return true;
                }
            }
            configFile.close();
        }
        return false;
    }
    return false;
}

void MarkShortcutAsCreated() {
    wchar_t appDataPath[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, appDataPath))) {
        std::wstring configDir = std::wstring(appDataPath) + L"\\ASPN AI AGENT";
        CreateDirectoryW(configDir.c_str(), NULL);
        
        std::wstring configPath = configDir + L"\\config.ini";
        
        // Write shortcut created status to config file
        std::ofstream configFile(configPath);
        if (configFile.is_open()) {
            configFile << "shortcut_created=true" << std::endl;
            configFile.close();
        }
    }
}

void CreateDesktopShortcut() {
    // Check if shortcut has been created before
    if (IsShortcutCreated()) {
        return;
    }

    wchar_t desktopPath[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(NULL, CSIDL_DESKTOPDIRECTORY, NULL, 0, desktopPath))) {
        wchar_t exePath[MAX_PATH];
        GetModuleFileNameW(NULL, exePath, MAX_PATH);

        std::wstring shortcutPath = std::wstring(desktopPath) + L"\\ASPN AI AGENT.lnk";
        
        IShellLinkW* pShellLink = nullptr;
        IPersistFile* pPersistFile = nullptr;

        if (SUCCEEDED(CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&pShellLink))) {
            pShellLink->SetPath(exePath);
            pShellLink->SetDescription(L"ASPN AI AGENT Application");
            pShellLink->SetWorkingDirectory(PathFindFileNameW(exePath));

            if (SUCCEEDED(pShellLink->QueryInterface(IID_IPersistFile, (LPVOID*)&pPersistFile))) {
                pPersistFile->Save(shortcutPath.c_str(), TRUE);
                pPersistFile->Release();
                
                // Mark shortcut as created
                MarkShortcutAsCreated();
            }
            pShellLink->Release();
        }
    }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Create desktop shortcut
  CreateDesktopShortcut();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ASPN AI AGENT", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
