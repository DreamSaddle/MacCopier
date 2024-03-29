<p align="center">
    <a href="https://github.com/DreamSaddle/MacCopier/releases">
    <img src="https://img.shields.io/github/v/release/DreamSaddle/MacCopier?style=badge&color=58C9B9" alt="RELEASE"/>
    </a>
    <a href="https://github.com/DreamSaddle/MacCopier/commits/main">
    <img src="https://img.shields.io/github/last-commit/DreamSaddle/MacCopier?style=badge&color=30A9DE" alt="LAST COMMIT"/>
    </a>
    <a href="https://github.com/DreamSaddle/MacCopier/issues">
    <img src="https://img.shields.io/github/issues/DreamSaddle/MacCopier?style=badge&color=E71D36" alt="ISSUES"/>
    </a>
    <a href="https://github.com/DreamSaddle/MacCopier/blob/master/LICENSE">
    <img src="https://img.shields.io/github/license/DreamSaddle/MacCopier?style=badge&color=EFDC05" alt="LICENSE"/>
    </a>
</p>

# MacCopier

MacCopier(Message Authentication Code Copier) 是一个提供在 Macos 中收到短信验证码后自动复制到剪贴板功能的软件。

> **Warning**
>
> 请务必从[这里下载](https://github.com/DreamSaddle/MacCopier/releases)，此应用目前没有提供其它下载链接，以防止造成您的数据泄露。

## 功能列表

- [x] 收到验证码短信后自动提取验证码到到剪贴板
- [x] 自动粘贴到当前光标处

## 隐私信息收集

此应用为开源项目。应用通过不断扫描 `~/Library/Messages/chat.db` 数据库文件获取最新的短信验证码，**期间不会上传系统中任何数据**。

## 安装

1. [点击下载](https://github.com/DreamSaddle/MacCopier/releases)
2. 解压后，将 MacCopier.app 拖动到 应用程序 目录即可

![image.png](./Screenshots/4.png)

## 使用

### 让您的 Mac 能接收短信息

参照[教程](https://support.apple.com/zh-cn/guide/messages/icht8a28bb9a/mac)将 iPhone 开启**短信转发**功能。

### 设置应用权限

安装好软件后，需要为其设置 **完全磁盘访问权限**。步骤如下：

1. 打开 系统偏好设置 > 安全性与隐私
![image.png](./Screenshots/1.png)

2. 左下角解锁设置后，找到 完全磁盘访问权限 选项，在右侧列表中找到 MacCopier 将其勾选上即可。
![image.png](./Screenshots/2.png)

3. 您也可以勾选 `登录时启动`，这将会在下次登录系统时自动运行此应用。

![image.png](./Screenshots/5.png)

4. 您也可以勾选 `自动粘贴`，这将会在提取出验证码后自动粘贴到系统当前光标处。`自动粘贴`功能需要您为 `MacCopier`开启`辅助功能`权限。

## 项目依赖

- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) 提供登录时启动功能
- [Sauce](https://github.com/Clipy/Sauce) 提供自动粘贴功能

## 其它

- 扫描短信数据库文件SQL来自 [py2fa](https://github.com/TeavenX/py2fa/blob/7cf6514e9d0344b0b2789e2a2eb73bdf5bb1df8b/message2fa.py#L42)。
