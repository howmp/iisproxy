# iisproxy

通过websocket在IIS8(Windows Server 2012)以上实现socks5代理

## 场景

在无法反弹`socks5`,仅有webshell权限时,代理进入内网，类似于[reGeorg](https://github.com/sensepost/reGeorg).

但相对于`reGeorg`优势在于稳定,流量不会放大。

## 限制

1. 可上传`ashx`文件,见 [Handler.ashx](dist/Handler.ashx)
2. IIS >= 8, 因为从IIS8开始才支持WebSocket协议, 见<https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-8/iis-80-websocket-protocol-support>

## 命令行参数

```txt
Usage of iisproxy:
  -l string
        socks5 server listen port (default "127.0.0.1:1080")
  -u string
        iis ashx url
```
