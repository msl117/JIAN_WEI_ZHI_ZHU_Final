# 基于安路 FPGA 的实时工件边缘检测系统

本工程面向安路 PH1P35 FPGA 和 SC520CS MIPI 摄像头，实现脱机实时视频采集、传统图像处理、工件检测和 HDMI 显示。当前工程记录的 Tang Dynasty 版本为 6.2.178840，目标器件为 `PH1P35MDG324`，速度等级为 `-3`。

## 已实现功能

- SC520CS 摄像头初始化、固定曝光下的手动/自动模拟增益调节和 MIPI 双 lane 接收。
- RAW10 解包、去马赛克、SW1 可切换 AWB、原图、Sobel 边缘和灰度处理。
- 固定 ROI 二值化，ROI 外输出黑色。
- ROI 黑像素统计、工件存在判断和随统计边界更新的外接矩形框。
- C7 按键面积基准和形状模板学习。
- 支持旋转容忍的 32 x 32 轮廓匹配，显示 SHAPE、SCORE、ANGLE。
- QUALITY 百分比、PASS/FAIL/WAIT 状态、PASS/FAIL 计数和稳定 NG 蜂鸣器报警。
- HDMI 720p 视频、Logo、模式/增益/检测结果 OSD。

QUALITY 是基于 ROI 面积和轮廓匹配的确定性规则评分，不是 FPGA 内运行的 AI 模型。当前 RTL 的等级显示为 `WAIT`、`PASS`、`FAIL`，不要将其描述为已经实现了 PREMIUM/GOOD 等级或训练模型。

## 目录

```text
td_project/       TD 工程和时序约束
user_source/      RTL、板级约束及本地构建所需厂商依赖
verification/     单元仿真源码、脚本和测试输入
docs/             项目、源码、资源审查和板级验证文档
```

## Vendor Dependencies

The public source repository excludes encrypted Anlogic MIPI/HDMI/DDR HDL and generated vendor IP to respect their distribution terms. Obtain or regenerate the required PH1P35 IP with a licensed Anlogic Tang Dynasty installation before building. The project entry and local RTL remain included; synthesis is not expected to complete until those vendor dependencies are restored.

详细说明见：

- `docs/项目功能与代码说明.md`
- `docs/源码模块说明.md`
- `docs/资源与赛题指标审查.md`
- `docs/板级验证清单.md`
- `docs/开源说明.md`

## 打开和构建

1. 使用 TD 打开 `td_project/workpiece_inspection.al`。工程实际输出为 HDMI。
2. 确认工程设备为 `PH1P35MDG324`，并保留 `user_source/constraints_source/pin.adc`。
3. 综合、布局布线和 bitgen 由 TD 完成；MIPI、DDR 和 HDMI 厂商 IP 不应手动替换。
4. `td_project/camera_to_dsi_display_Runs/` 是旧工程名下的历史构建记录；其中 2026-10-20 的 bit 早于舵机 RTL 与约束改动，不包含舵机功能。新工程名需要重新综合、布局布线和生成 bit，不要将历史 bit 当作新工程结果。

SW1 拨上启用 AWB、拨下旁路；改变 AWB 后应按 C7 重新标定。AUTO 在 DEBUG ROI 且工件在场时冻结增益，其他显示模式按边缘背景测光调节。当前源码须重新综合、布线及生成 bit；现存报告仍有负 Setup WNS，不能代表这轮改动。
