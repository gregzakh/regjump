@{
  RootModule = 'regjump.psm1'
  ModuleVersion = '1.0.0.0'
  CompatiblePSEditions = 'Core'
  GUID = 'f2afdd93-1ed3-47c8-a66d-541ab2158684'
  Author = 'greg zakharov'
  Copyright = 'MIT'
  Description = 'Take a registry path and make RegEdit open to that path.'
  PowerShellVersion = '7.1'
  AliasesToExport = 'regjump'
  FunctionsToExport = 'Invoke-RegJump'
  FileList = @(
    'lib\accel.ps1',
    'lib\pcall.ps1',
    'regjump.psd1',
    'regjump.psm1'
  )
}
