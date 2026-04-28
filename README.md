# dev_stack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Packaging for Windows

To create a Windows installer (.exe) for this application, follow these steps:

### Prerequisites
1.  **Inno Setup 6**: Download and install from [jrsoftware.org](https://jrsoftware.org/isdl.php).

### Steps
1.  Open PowerShell as Administrator (or in your terminal).
2.  Run the packaging script:
    ```powershell
    .\scripts\package.ps1
    ```
3.  The installer will be generated in the `innosetup\Output` directory.

Alternatively, you can build manually:
1.  Run `flutter build windows --release`.
2.  Open `innosetup\installer.iss` in the Inno Setup Compiler and click **Compile**.

