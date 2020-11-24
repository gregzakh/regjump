using namespace Microsoft.Win32
using namespace System.Security.Principal

(Get-ChildItem "$PSScriptRoot\lib" -Filter *.ps1).ForEach{. $_.FullName}

Set-Alias -Name regjump -Value Invoke-RegJump
function Invoke-RegJump {
  [CmdletBinding(DefaultParameterSetName='Key')]
  param(
    [Parameter(Mandatory,
               ParameterSetName='Raw',
               Position=0,
               ValueFromPipeline)]
    [ValidateScript({!!($script:rk = Get-Item "Registry::$_" -ErrorAction 0)})]
    [ValidateNotNullOrEmpty()]
    [String]$Raw,

    [Parameter(Mandatory,
               ParameterSetName='Key',
               Position=0,
               ValueFromPipeline,
               ValueFromPipelineByPropertyName)]
    [RegistryKey]$Key
  )

  begin {
    New-Delegate -Module kernel32 -Signature {
      uint GetCurrentThreadId
    }

    New-Delegate -Module user32 -Signature {
      bool AttachThreadInput([uint, uint, bool])
      bool BringWindowToTop([ptr])
      ptr  FindWindowW([buf, buf])
      ptr  FindWindowExW([ptr, ptr, buf, buf])
      ptr  GetForegroundWindow
      uint GetWindowThreadProcessId([ptr, buf])
      ptr  SendMessageW([ptr, uint, ptr, ptr])
      bool ShowWindow([ptr, uint])
    }

    if (![WindowsPrincipal]::new([WindowsIdentity]::GetCurrent()).IsInRole(
      [WindowsBuiltInRole]::Administrator # dirty trick for non admin users
    ) -and !(Test-Path env:__COMPAT_LAYER)) { $env:__COMPAT_LAYER = 'RunAsInvoker' }
  }
  process {
    $rk = $PSCmdlet.ParameterSetName -eq 'Key' ? $Key : $rk
    $ca = [Int32[]][Char[]]"\\$($rk.Name -replace '\\', '\\')"
    $rk.Dispose()
  }
  end {
    try {
      if (!$ca.Length) { # piped key is not existed, no way to jump
        throw [InvalidOperationException]::new('Non-existent registry key.')
      }

      if (!($re = Get-Process -Name regedit -ErrorAction 0)) {
        if (!($re = Start-Process -FilePath regedit -ErrorAction 0 -PassThru)) {
          throw [InvalidOperationException]::new('Cannot launch registry editor.')
        }
      }

      Start-Sleep -Milliseconds 300
      $main = $user32.FindWindowW.Invoke([buf].Uni('RegEdit_RegEdit'), $null)
      $tree = $user32.FindWindowExW.Invoke($main, [IntPtr]::Zero, [buf].Uni('SysTreeView32'), $null)
      for ($i = 0; $i -lt 30; $i++) { # fold all before jump
        [void]$user32.SendMessageW.Invoke($tree, 0x100, [IntPtr]0x25, [IntPtr]::Zero)
      }

      Start-Sleep -Milliseconds 200
      for ($i = 0; $i -lt $ca.Length; $i++) {
        if ($ca[$i] -eq 92) { # hitting Right key
          [void]$user32.SendMessageW.Invoke($tree, 0x100, [IntPtr]0x27, [IntPtr]::Zero)
        }
        else { # hitting character key
          [void]$user32.SendMessageW.Invoke($tree, 0x102, [IntPtr]$ca[$i], [IntPtr]::Zero)
        }
      }

      Start-Sleep -Milliseconds 100 # bringing to front of the window of the registry editor
      $win = $user32.GetWindowThreadProcessId.Invoke($user32.GetForegroundWindow.Invoke(), $null)
      $cur = $kernel32.GetCurrentThreadId.Invoke()
      [void]$user32.AttachThreadInput.Invoke($win, $cur, $true)
      [void]$user32.BringWindowToTop.Invoke($re.MainWindowHandle)
      [void]$user32.ShowWindow.Invoke($re.MainWindowHandle, 0x05)
      [void]$user32.AttachThreadInput.Invoke($win, $cur, $false)
    }
    catch { Write-Verbose $_ }
    finally {
      if ($env:__COMPAT_LAYER) { Remove-Item env:__COMPAT_LAYER }
      if ($re) { $re.Dispose() }
    }
  }
}

Export-ModuleMember -Alias regjump -Function Invoke-RegJump
