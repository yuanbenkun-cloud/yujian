# 顺序连点器

Windows 桌面连点工具，按点位列表顺序循环点击。

## 使用

1. 点击“屏幕布点”，依次在屏幕上左键添加点位；右键、Enter 或 Esc 完成。
2. 设置每秒总点击次数，范围为 1–100。
3. 按 F6 开始，再按 F6 停止。运行时按 Esc 也会立即强制停止连击。

也可以把鼠标移到目标位置后按 F8，直接向列表末尾添加点位。点位和速率会自动保存到当前 Windows 用户的 AppData 配置目录。

## 构建

项目使用单文件 WinForms 源码，可用 Windows 自带的 .NET Framework C# 编译器构建：

```powershell
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:winexe /optimize+ /platform:anycpu /out:'顺序连点器.exe' /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll .\Program.cs
```
