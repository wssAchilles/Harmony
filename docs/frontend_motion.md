# 前端动效模式

本项目的动效服务于管理效率和状态反馈，不追求炫技。优先使用 Flutter 原生 `AnimatedSwitcher`、`AnimatedContainer`、`AnimatedScale`、`FadeTransition`、`SlideTransition` 和 `Hero`。

## Dashboard 分段进入

加载完成后，固定 AppBar，统计卡先按 40-60ms 间隔错峰进入，月统计和排行榜随后出现。用于减少整页突然刷新感。

## 图书库存状态过渡

库存、逾期、角色等标签使用 `StatusChip`。状态变化时过渡背景色和文案，让用户能看见业务状态变化。

## 异步按钮反馈

提交、登录、注册等动作使用 `AsyncActionButton`。按钮尺寸保持稳定，内容在 idle/loading/success/error 间切换。

## 筛选列表结果过渡

班级、分类、搜索筛选触发结果变化时，保留筛选控件稳定，只让结果区短促淡入或错峰进入，避免整页重建感。
