using namespace System.Reflection
using namespace System.Linq.Expressions
using namespace System.Runtime.InteropServices

function New-Delegate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)]
    [ValidateNotNullOrEmpty()]
    [String]$Module,

    [Parameter(Mandatory, Position=1)]
    [ValidateScript({![String]::IsNullOrEmpty($_)})]
    [ScriptBlock]$Signature
  )

  begin {
    $kernel32 = @{}
    [Array]::Find(( # GetModuleHandle, GetProcAddress
      Add-Type -AssemblyName Microsoft.Win32.SystemEvents -PassThru
    ), [Predicate[Type]]{$args[0].Name -eq 'kernel32'}).GetMethods(
      [BindingFlags]'NonPublic, Static, Public'
    ).Where{$_.Name -cmatch '\AGet(P|M)'}.ForEach{$kernel32[$_.Name] = $_}

    if (($mod = $kernel32.GetModuleHandle.Invoke($null, @($Module))) -eq [IntPtr]::Zero) {
      throw [DllNotFoundException]::new("Cannot find $Module library.")
    }
  }
  process {}
  end {
    $funcs = @{}
    for ($i, $m, $fn, $p = 0, ([Expression].Assembly.GetType(
        'System.Linq.Expressions.Compiler.DelegateHelpers'
      ).GetMethod('MakeNewCustomDelegate', [BindingFlags]'NonPublic, Static')
      ), [Marshal].GetMethod('GetDelegateForFunctionPointer', ([IntPtr])),
      $Signature.Ast.FindAll({$args[0].CommandElements}, $true).ToArray();
      $i -lt $p.Length; $i++
    ) {
      $fnret, $fname = ($def = $p[$i].CommandElements).Value

      if (($fnsig = $kernel32.GetProcAddress.Invoke($null, @($mod, $fname))) -eq [IntPtr]::Zero) {
        throw [InvalidOperationException]::new("Cannot find $fname signature.")
      }

      $fnargs = $def.Pipeline.Extent.Text
      [Object[]]$fnargs = [String]::IsNullOrEmpty($fnargs) ? $fnret : (
        ($fnargs -replace '\[|\]' -split ',\s+?').ForEach{
          $_.StartsWith('_') ? (Get-Variable $_.Remove(0, 1) -ValueOnly) : $_
        } + $fnret
      )

      $funcs[$fname] = $fn.MakeGenericMethod(
        [Delegate]::CreateDelegate([Func[[Type[]], Type]], $m).Invoke($fnargs)
      ).Invoke([Marshal], $fnsig)
    }

    Set-Variable -Name $Module -Value $funcs -Scope Script -Force
  }
}
