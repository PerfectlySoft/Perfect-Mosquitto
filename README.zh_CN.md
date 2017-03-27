# Perfect-Mosquitto [English](README.md)

<p align="center">
    <a href="http://perfect.org/get-involved.html" target="_blank">
        <img src="http://perfect.org/assets/github/perfect_github_2_0_0.jpg" alt="Get Involed with Perfect!" width="854" />
    </a>
</p>

<p align="center">
    <a href="https://github.com/PerfectlySoft/Perfect" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_1_Star.jpg" alt="Star Perfect On Github" />
    </a>  
    <a href="https://gitter.im/PerfectlySoft/Perfect" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_2_Git.jpg" alt="Chat on Gitter" />
    </a>  
    <a href="https://twitter.com/perfectlysoft" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_3_twit.jpg" alt="Follow Perfect on Twitter" />
    </a>  
    <a href="http://perfect.ly" target="_blank">
        <img src="http://www.perfect.org/github/Perfect_GH_button_4_slack.jpg" alt="Join the Perfect Slack" />
    </a>
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat" alt="Swift 3.0">
    </a>
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" alt="Platforms OS X | Linux">
    </a>
    <a href="http://perfect.org/licensing.html" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License Apache">
    </a>
    <a href="http://twitter.com/PerfectlySoft" target="_blank">
        <img src="https://img.shields.io/badge/Twitter-@PerfectlySoft-blue.svg?style=flat" alt="PerfectlySoft Twitter">
    </a>
    <a href="https://gitter.im/PerfectlySoft/Perfect?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge" target="_blank">
        <img src="https://img.shields.io/badge/Gitter-Join%20Chat-brightgreen.svg" alt="Join the chat at https://gitter.im/PerfectlySoft/Perfect">
    </a>
    <a href="http://perfect.ly" target="_blank">
        <img src="http://perfect.ly/badge.svg" alt="Slack Status">
    </a>
</p>


该项目是基于 MQTT 客户端函数库 libmosquitto 上的 Swift 类封装。

该软件使用SPM进行编译和测试，本软件也是[Perfect](https://github.com/PerfectlySoft/Perfect)项目的一部分，可以作为服务器组件独立运行。

请确保您已经安装并激活了最新版本的 Swift 3.0 tool chain 工具链。

## OS X 编译说明

### Homebrew 组件安装

本项目依赖于 mosquitto C语言函数库。为了实现在苹果操作系统上编译，请使用以下`brew`命令：

```
$ brew install mosquitto
```

### PC 配置文件

本项目同时需要手工编辑配置文件`/usr/local/lib/pkgconfig/mosquitto.pc`，内容如下：

```
Name: mosquitto
Description: Mosquitto Client Library
Version: 1.4.11
Requires:
Libs: -L/usr/local/lib -lmosquitto
Cflags: -I/usr/local/include

```

并且请确定当前终端环境中包括变量 `$PKG_CONFIG_PATH`:

```
$ export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig"
```

## Linux 编译说明

本项目需要 Ubuntu 16.04 静态函数库 `libmosquitto-dev`:

```
$ apt-get libmosquitto-dev
```


## 快速上手

### 函数库开放与关闭

在使用任何Perfect Mosquitto函数之前，请务必调用 `Mosquitto.OpenLibrary()`打开函数库。同样，请在程序退出时关闭函数库，即调用`Mosquitto.CloseLibrary()`静态方法。

*注意* 函数库开放与关闭操作不是线程安全的，因此请在执行多线程任务之前进行操作。

### 初始化一个 Mosquitto 类实例

初始化 Mosquitto 类时，可以带参数也可以不带任何参数。最简单的方法如下：

``` swift
let m = Mosquitto()
```

意味着自动为该客户端对象分配一个随机序列号，而且在断开连接时所有消息和订阅都会被自动清除。

当然您也可以手工为客户端分配一个序列号，这种情况下在断点续传时会非常有用：

``` swift
let mosquitto = Mosquitto(id: "myInstanceId", cleanSession: false)
```

### 连接到消息掮客

消息掮客就是用于中转维护消息的服务器，这里的消息服务器指的是符合MQTT协议的服务器——负责从消息源接收消息，并且分发到所有订阅者去。

虽然连接方法`connect()`可以异步操作、维持长连接或绑定到特定网卡地址，一般来说，下面的方法是最简明扼要的：只需要提供服务器地址和端口（通常是1883）即可：

``` swift
try moosquitto.connect(host: "mybroker.com", port: 1883)
```

尽管当例程结束时 Swift 会以清理对象的方式断开服务器连接，但我们仍然推荐显式调用 `disconnect()`方法断开服务器连接。除此之外，同一个例程在断开连接后，还可以用 `reconnect()`方法重新连回到服务器。

### 线程模型

#### 服务线程的启动停止
Perfect Mosquitto 有两种线程调度方式。客户端可以调用`start()`方法启动一个后台线程用于处理消息发布和接收，这种情况下主线程不会被阻塞，并且可以随时调用`stop()`方法结束后台服务线程运行：

``` swift
// 启动后台线程用于处理消息，不会阻塞主线程，调用后立刻返回。
try mosquitto.start()

// 随后您可以在主线程内执行任意操作，比如消息发送；消息接收会以回调方式进行。

// 如果不需要继续处理消息，可以调用以下函数停止服务线程的运行
try mosquitto.stop()
```

#### 等待消息事件

不同于上述方法，您还可以在主线程内处理所有事件，只不过需要频繁调用`wait()`函数，实现消息轮询：

``` swift
// 等待一个很短的时间（最小的时间片段）
// 此时，mosquitto 会利用这个时间片段进行消息收发处理
try mosquitto.wait(0)
```

该方法唯一的参数就是等待的时间片毫秒数。0代表最小时间片（由系统决定），负数则被视为1秒钟（1000毫秒）。

⚠️ *注意* ⚠️ *两种线程模型后台 `start()`/`stop()` 和轮询 `wait()`不能混用！*


### 发送消息

一旦连接到服务器，可以随时发送消息：

``` swift
var msg = Mosquitto.Message()
msg.id = 100 // 消息编码，请自行定义
msg.topic = "publish/test" // 消息主题，格式由MQTT决定
msg.string = "发送测试 🇨🇳🇨🇦"

let mid = try mosquitto.publish(message: msg)
```

如上述例子，首先是创建一个空消息结构，然后可以指定消息编号、消息主题和消息内容；随后调用`publish()`方法把准备好的消息发出去；该函数将返回实际的消息编号。

*注意* 消息内容也可以是一个二进制数组：
``` swift
// 发送一个二进制 [Int8] 字节数组
msg.payload = [40, 41, 42, 43, 44, 45]
```

一旦发布，请调用 `start()`后台线程处理器或者 `wait()`轮询进行实际消息发布，参考前文的消息模型。

### 消息的订阅和接收

在Perfect Mosquitto函数库中接收 MQTT 消息的唯一方法是自定义事件回调：

``` swift

mosquitto.OnMessage = { msg in

	// 打印消息编号
	print(msg.id)

	// 打印消息主题
	print(msg.topic)

	// 打印消息内容
	print(msg.string)

	// 以二进制字节流的形式输出消息内容
	print(msg.payload)
}//end on Message

```

一旦设置好事件回调函数，可以调用 `subscribe()`完成特定主题消息的订阅：

``` swift
try mosquitto.subscribe(topic: "publish/test")
```

一旦订阅，请调用 `start()`后台线程处理器或者 `wait()`轮询进行实际的消息接收，参考前文的消息模型。

## 其他函数参考

除上述简要说明之外，Perfect Mosquitto 还提供了完整的函数库，请参考项目的函数手册。

### 事件回调

如果有需要，请为您的mosquitto对象自行设置以下回调函数（闭包）：

API|参数|说明
---|----------|-----------
`OnConnect { status in }` | `ConnectionStatus` | 连接到服务器时触发
`OnDisconnected { status in }` | `ConnectionStatus` | 连接断开时出发
`OnPublish { msg in }` | `Message` | 消息发送后触发
`OnMessage { msg in }` | `Message` | 消息到达后触发
`OnSubscribe { id, qos in }` | `(Int32, [Int32])` | 消息订阅后触发
`OnUnsubscribe { id in }` | `Int32` (message id) | 消息取消订阅时出发
`OnLog { level, content in }` | `(LogLevel, String)` | 如果有日志生成时出发

### TLS 配置

- 设置 TLS 证书： `func setTLS(caFile: String, caPath: String, certFile: String? = nil, keyFile: String? = nil, keyPass: String? = nil) throws`

- 设置 TLS 验证方法： `func setTLS(verify: SSLVerify = .PEER, version: String? = nil, ciphers: String? = nil) throws`

- 设置 TLS 预分配钥匙： `func setTLS(psk: String, identity: String, ciphers: String? = nil) throws`

### 其他函数

- 配置期望： `func setConfigWill(message: Message?) throws`

- 配置用户名密码： `func login(username: String? = nil, password: String? = nil) throws`

- 配置消息发送失败时重试等待时间 `func setMessageRetry(max: UInt32 = 20)`

- 设置插队消息QoS优先级： `func setInflightMessages(max: UInt32 = 20) throws`

- 设置客户端断开时重连等待时间： `func reconnectSetDelay(delay: UInt32 = 2, delayMax: UInt32 = 10, backOff: Bool = false) throws`

- 断线重连：`func reconnect(_ asynchronous: Bool = true) throws`

- 当前客户端例程内容重启 `func reset(id: String? = nil, cleanSession: Bool = true) throws`

- 设置 MQTT 版本： `func setClientOption(_ version: MQTTVersion = .V31, value: UnsafeMutableRawPointer) throws`

- 解释错误信息（英语）`static func Explain(_ fault: Exception) -> String`
 


### 问题报告、内容贡献和客户支持

我们目前正在过渡到使用JIRA来处理所有源代码资源合并申请、修复漏洞以及其它有关问题。因此，GitHub 的“issues”问题报告功能已经被禁用了。

如果您发现了问题，或者希望为改进本文提供意见和建议，[请在这里指出](http://jira.perfect.org:8080/servicedesk/customer/portal/1).

在您开始之前，请参阅[目前待解决的问题清单](http://jira.perfect.org:8080/projects/ISS/issues).

## 更多信息
关于本项目更多内容，请参考[perfect.org](http://perfect.org).
