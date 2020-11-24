# regjump

Take a registry path and make RegEdit open to that path.

Examples.

```powershell
┌─[E:\sandbox]
└λ Invoke-RegJuml hklm

┌─[E:\sandbox]
└λ regjump hklm

┌─[E:\sandbox]
└λ Get-Item HKLM:\SYSTEM\CurrentControl\ | regjump
```
