# 更新日志



```
//2025040104

精简了代码但没有解决较大GIF的保存速度


```

## 🎉 **FuckGif**

**保存抖音表情包到相册的插件**



### 🌟 **功能使用**
**长按保存**到相册
**格式转换**自动转换为 GIF
**系统兼容**Trollfools注入和越狱设备（ios13+）


### 🛠 **技术概览**

**格式检测**

自动识别 HEIF/HEIC 文件头（`00000000 66747970 68656966`）
动态 GIF 验证（检查`GIF87a`/`GIF89a`标记）

**存储优化**

使用`PHAssetChangeRequest`
内存管理策略（弱引用 + 缓存清理）


### 📲 **编译指南**

```
\# 安装Theos

https://theos.dev/

\# 执行命令

make package
```

### 💻 **开发者信息**

@曲奇的坏品味🍻

GitHub: [https://github.com/c00kiec00k](https://github.com/c00kiec00k)

Telegram: [https://t.me/c00kiec00k](https://t.me/c00kiec00k)




