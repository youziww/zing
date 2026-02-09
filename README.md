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

# todolist
搜索记录只显示最近十条（已完成）
deck可以折叠打开（已完成）
add deck按钮和import按钮在现在的基础上各占一半（已完成）
清除完历史搜索记录之后，刷新，历史记录又出现了
增加单词读音，例句（可以标上片假名）音调(⓪) → 词性 → 读音 → 释义