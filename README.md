# zing

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


● 目前 app 有两种方式添加 deck：                                                                                                                                                                                                                                                   
                                                                                                             
  1. 导入 .apkg 文件（已实现）                                                                                                                                                                                                                                                     
  - 在手机上下载 .apkg 文件（从 AnkiWeb 或其他来源）                                                         
  - 点击 app 首页的 "Import" 按钮，选择文件导入    

  -https://github.com/5mdld/anki-jlpt-decks/releases                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                                                   
  2. 预置数据（当前方式）
  - N2 和新标日的数据是打包在 app 里的，启动时自动加载
  - 添加新的预置数据需要重新编译 app

  直接粘贴 GitHub 地址目前不支持，需要额外开发一个 URL 导入功能。

# Todolist

## 已完成
- ~~搜索记录只显示最近十条~~
- ~~deck可以折叠打开~~
- ~~add deck按钮和import按钮在现在的基础上各占一半~~

## 已知问题
- 清除完历史搜索记录之后，刷新，历史记录又出现了
- 增加单词读音，例句（可以标上片假名）音调(⓪) → 词性 → 读音 → 释义

## 功能路线图

### P0 — 用户留存关键
- [ ] iCloud 备份/恢复
- [ ] 撤销操作（Undo）— 学习时按错可撤回
- [ ] 深色模式
- [ ] 卡片编辑 — 在浏览器中编辑已有卡片内容

### P1 — 竞争力提升
- [ ] 学习提醒通知（本地推送）
- [ ] TTS 发音（利用 iOS 系统 TTS）
- [ ] 手势操作 — 左右滑动答题
- [ ] 卡片模板自定义
- [ ] 图片支持

### P2 — 差异化亮点
- [ ] Widget 小组件 — 主屏显示今日待复习数
- [ ] /打卡
- [ ] Shortcuts 捷径集成
- [ ] iPad 分栏布局

iwtach协同,可以在iwatch上记单词