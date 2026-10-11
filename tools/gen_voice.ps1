# P7f: 用 Windows 内置 TTS (System.Speech / Microsoft Huihui zh-CN) 生成角色必杀语音。
# 运行：powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_voice.ps1
# Pitch 需通过 SSML <prosody> 设置：凛=清亮(+2st)，苍=低沉(-10st,慢)，澪=活泼(+8st,快)
Add-Type -AssemblyName System.Speech

$outDir = Join-Path $PSScriptRoot "..\assets\audio\vo"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# file, pitch(st), rate(%), text
$lines = @(
    @("vo_lin_1",  "+2",  "+10", "闪电，撕裂黑暗！"),
    @("vo_lin_2",  "+2",  "+10", "高压放电，接招！"),
    @("vo_cang_1", "-10", "-15", "冰壁，封锁！"),
    @("vo_cang_2", "-10", "-15", "感受一下，绝对零度！"),
    @("vo_miao_1", "+8",  "+20", "柔波，治愈吧！"),
    @("vo_miao_2", "+8",  "+20", "水镜冲击！")
)

foreach ($l in $lines) {
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $path = Join-Path $outDir ($l[0] + ".wav")
    $synth.SetOutputToWaveFile($path)
    $ssml = "<speak version='1.0' xml:lang='zh-CN'><voice name='Microsoft Huihui Desktop'>" +
            "<prosody pitch='" + $l[1] + "st' rate='" + $l[2] + "%'>" + $l[3] + "</prosody></voice></speak>"
    $synth.SpeakSsml($ssml)
    $synth.Dispose()   # Dispose 时才关闭 wav 流
    Write-Host ("wrote " + $l[0] + ".wav")
}
Write-Host "voice gen done"
