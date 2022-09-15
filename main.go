package main

import (
	"context"
	"crypto/cipher"
	"crypto/md5"
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"

	"github.com/armon/go-socks5"
	"golang.org/x/net/websocket"
)

var (
	_url = flag.String("u", "", "iis ashx url")
	u    *url.URL
	addr = flag.String("l", "127.0.0.1:1080", "socks5 server listen port")
)

type xor struct {
	key   []byte
	index int
}

func newXor(key []byte) cipher.Stream {
	return &xor{key: key}
}

func (x *xor) XORKeyStream(dst, src []byte) {
	if len(dst) < len(src) {
		panic("crypto/cipher: output smaller than input")
	}
	for i, c := range src {
		if x.index == len(x.key) {
			x.index = 0
		}
		dst[i] = c ^ x.key[x.index]
		x.index += 1
	}
}

type encryptWsConn struct {
	net.Conn
	reader io.Reader
	writer io.Writer
}

func newEncryptWsConn(ws net.Conn, addr string) (*encryptWsConn, error) {
	key := md5.Sum([]byte(addr))
	return &encryptWsConn{
		Conn: ws,
		writer: cipher.StreamWriter{
			S: newXor(key[:]),
			W: ws,
		},
		reader: cipher.StreamReader{
			S: newXor(key[:]),
			R: ws,
		},
	}, nil
}

func (e *encryptWsConn) Read(b []byte) (n int, err error) {
	return e.reader.Read(b)
}

func (e *encryptWsConn) Write(b []byte) (n int, err error) {
	return e.writer.Write(b)
}
func proxyDial(ctx context.Context, network, addr string) (net.Conn, error) {
	if !strings.HasPrefix(network, "tcp") {
		return nil, net.UnknownNetworkError(network)
	}
	location := *u
	if location.Scheme == "https" {
		location.Scheme = "wss"
	} else {
		location.Scheme = "ws"
	}

	ws, err := websocket.DialConfig(&websocket.Config{
		Version:  websocket.ProtocolVersionHybi13,
		Location: &location,
		Origin:   u,
		Header: http.Header{
			//FIXME: 把要连接的地址放在头里可能会被针对
			"X-Forwarded-Host": []string{addr},
		},
	})
	if err != nil {
		return nil, err
	}
	ws.PayloadType = websocket.BinaryFrame
	return newEncryptWsConn(ws, addr)
}

func main() {
	var err error
	flag.Parse()
	u, err = url.ParseRequestURI(*_url)
	if err != nil {
		log.Fatalln(err)
	}
	conf := &socks5.Config{}
	conf.Dial = proxyDial
	server, err := socks5.New(conf)
	if err != nil {
		log.Fatalln(err)
	}
	log.Println("socks5 listen", *addr)
	if err := server.ListenAndServe("tcp", *addr); err != nil {
		log.Fatalln(err)
	}
}
