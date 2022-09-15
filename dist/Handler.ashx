<%@ WebHandler Language="C#" Class="Handler" %>

using System;
using System.Net.WebSockets;
using System.Threading.Tasks;
using System.Threading;
using System.Web;
using System.Web.WebSockets;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;

public class Handler : IHttpHandler
{
    public bool IsReusable
    {

        get { return true; }
    }
    public void ProcessRequest(HttpContext context)
    {
        var request = context.Request;
        var response = context.Response;
        if (!context.IsWebSocketRequest && !context.IsWebSocketRequestUpgrading)
        {
            response.StatusCode = 403;
            return;
        }
        var addr = request.Headers.Get("X-Forwarded-Host");
        if (addr == null)
        {
            response.StatusCode = 403;
            return;
        }
        var parts = addr.Split(':');
        if (parts.Length != 2)
        {
            response.StatusCode = 403;
            return;
        }
        var host = parts[0];
        var port = parts[1];
        var client = new TcpClient();
        try
        {
            client.Connect(host, int.Parse(port));
        }
        catch (Exception e)
        {
            response.StatusCode = 500;
            response.Write(e.ToString());
            return;
        }
        var key = MD5.Create().ComputeHash(Encoding.ASCII.GetBytes(addr));
        var p = new Proxy(client.Client, key);
        context.AcceptWebSocketRequest(p.ProcessRequest);
    }

    private class Proxy
    {
        private Socket sock;
        private byte[] key;
        public Proxy(Socket sock, byte[] key)
        {
            this.sock = sock;
            this.key = key;
        }
        private async Task ReadTask(WebSocket ws)
        {
            var buffer = new byte[1024];
            var index = 0;

            while (true)
            {
                try
                {
                    var r = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None).ConfigureAwait(false);
                    for (int i = 0; i < r.Count; i++)
                    {
                        buffer[i] = (byte)(buffer[i] ^ key[index]);
                        index++;
                        if (index == key.Length)
                        {
                            index = 0;
                        }
                    }
                    await sock.SendAsync(new ArraySegment<byte>(buffer, 0, r.Count), SocketFlags.None).ConfigureAwait(false);
                }
                catch
                {
                    break;
                }
            }

        }

        private async Task WriteTask(WebSocket ws)
        {
            var buffer = new byte[1024];
            var index = 0;

            while (true)
            {
                try
                {
                    var count = await sock.ReceiveAsync(new ArraySegment<byte>(buffer), SocketFlags.None).ConfigureAwait(false);
                    for (int i = 0; i < count; i++)
                    {
                        buffer[i] = (byte)(buffer[i] ^ key[index]);
                        index++;
                        if (index == key.Length)
                        {
                            index = 0;
                        }
                    }
                    await ws.SendAsync(new ArraySegment<byte>(buffer, 0, count), WebSocketMessageType.Binary, true, CancellationToken.None).ConfigureAwait(false);
                }
                catch
                {
                    break;
                }
            }
        }
        public async Task ProcessRequest(AspNetWebSocketContext context)
        {
            var ws = context.WebSocket;
            await Task.WhenAll(this.WriteTask(ws), this.ReadTask(ws));
        }
    }
}