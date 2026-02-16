# PhotoCleaner · 照片清理

> 快速扫描并清理 iPhone 相册中的相似照片。

## 功能特性

- **智能识别** — 基于 Apple Vision 框架的特征向量算法，精准找出相似照片
- **实时预览** — 扫描过程中同步展示结果，无需等待扫描完成
- **智能标记** — 自动保留每组中的第一张，其余标记为待删除
- **全屏预览** — 支持双指缩放、左右翻页、上下滑动关闭
- **批量操作** — 全选 / 全不选，一键批量删除
- **iCloud 支持** — 自动从 iCloud 拉取照片进行比对

## 技术栈

| 层级 | 技术 |
|---|---|
| UI | SwiftUI |
| 相似度计算 | Vision · `VNGenerateImageFeaturePrintRequest` |
| 相册访问 | PhotoKit · `PHCachingImageManager` |
| 并发 | Swift Concurrency (async/await · Task) |
| 反馈 | Core Haptics |

## 项目结构

```
PhotoCleaner/
├── PhotoCleanerApp.swift     # App 入口
├── ContentView.swift         # 根视图，管理页面切换
├── PhotoManager.swift        # 核心逻辑（扫描、选择、删除）
└── Views/
    ├── EmptyStateView.swift  # 首页 / 扫描入口
    ├── ResultsView.swift     # 相似照片分组列表
    ├── PhotoDetailView.swift # 全屏照片浏览
    └── ZoomableImageView.swift
```

## 运行要求

- iOS 26+
- Xcode 26+
- 真机运行（模拟器不支持 Vision 特征提取）

## 开始使用

1. Clone 仓库
2. 用 Xcode 打开 `PhotoCleaner.xcodeproj`
3. 在 **Signing & Capabilities** 中选择你自己的 Development Team
4. 选择真机目标，运行即可

首次启动时应用会请求相册访问权限，授权后点击 **开始扫描** 即可使用。

## 工作原理

1. 从相册获取全部图片，按拍摄时间降序排列
2. 对每张图片使用 `VNGenerateImageFeaturePrintRequest` 提取 256×256 特征向量
3. 计算相邻图片间的特征距离（阈值 `10.0`），距离越小越相似
4. 将连续相似的图片归为一组，实时推送到 UI

## License

MIT
