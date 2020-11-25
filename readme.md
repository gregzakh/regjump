# regjump

Take a registry path and make RegEdit open to that path.

Examples.

```powershell
┌─[E:\sandbox]
└λ Invoke-RegJump hklm

┌─[E:\sandbox]
└λ regjump hklm

┌─[E:\sandbox]
└λ Get-Item HKLM:\SYSTEM\CurrentControlSet\ | regjump
```
