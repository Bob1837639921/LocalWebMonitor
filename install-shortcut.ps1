$ErrorActionPreference = "Stop"

function Z([string]$value) {
  return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop ("{0}.lnk" -f (Z "5pys5Zyw572R6aG155uR5ZCs"))
$launcherPath = Join-Path $root "start-floating.vbs"
$iconPath = Join-Path $root "assets\local-web-monitor.ico"

if (-not (Test-Path $launcherPath)) {
  throw "Cannot find launcher: $launcherPath"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = '"' + $launcherPath + '"'
$shortcut.WorkingDirectory = $root
$shortcut.Description = "Local Web Monitor"

if (Test-Path $iconPath) {
  $shortcut.IconLocation = "$iconPath,0"
}

$shortcut.Save()

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ShellRefresh {
  [DllImport("shell32.dll")]
  public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@

[ShellRefresh]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host "Desktop shortcut created: $shortcutPath"
