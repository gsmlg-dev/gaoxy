// Independent RFC 9220 channel client using public quic-go and gobwas/ws APIs.
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gobwas/ws"
	"github.com/gobwas/ws/wsutil"
	"github.com/quic-go/quic-go"
	"github.com/quic-go/quic-go/http3"
)

// These finite-fixture bounds apply only to this independent test client.
const (
	maxFixtureMessageBytes = 64 << 10
	maxFixtureControlBytes = 8 << 10
	maxFixtureFrames       = 256
)

func readMessage(stream io.ReadWriter) (wsutil.Message, error) {
	var messageBytes, controlBytes int64
	frames := 0
	account := func(header ws.Header) error {
		frames++
		if frames > maxFixtureFrames {
			return errors.New("fixture WebSocket frame budget exceeded")
		}
		if header.OpCode.IsControl() {
			controlBytes += header.Length
			if controlBytes > maxFixtureControlBytes {
				return errors.New("fixture WebSocket control budget exceeded")
			}
		} else {
			messageBytes += header.Length
			if messageBytes > maxFixtureMessageBytes {
				return errors.New("fixture WebSocket message budget exceeded")
			}
		}
		return nil
	}
	control := func(header ws.Header, source io.Reader) error {
		if err := account(header); err != nil {
			return err
		}
		// Reader validates RFC 6455's 125-byte control limit before this allocation.
		payload := make([]byte, int(header.Length))
		if _, err := io.ReadFull(source, payload); err != nil {
			return err
		}
		switch header.OpCode {
		case ws.OpPing:
			return wsutil.WriteClientMessage(stream, ws.OpPong, payload)
		case ws.OpPong:
			return nil
		default:
			return errors.New("unexpected CLOSE during fragmented WebSocket message")
		}
	}
	reader := wsutil.Reader{
		Source: stream, State: ws.StateClientSide, CheckUTF8: true,
		MaxFrameSize: maxFixtureMessageBytes,
		OnContinuation: func(header ws.Header, _ io.Reader) error {
			return account(header)
		},
		OnIntermediate: control,
	}
	for {
		header, err := reader.NextFrame()
		if err != nil {
			return wsutil.Message{}, err
		}
		if header.OpCode == ws.OpPing || header.OpCode == ws.OpPong {
			if err := control(header, &reader); err != nil {
				return wsutil.Message{}, err
			}
			continue
		}
		if err := account(header); err != nil {
			return wsutil.Message{}, err
		}
		// Fixed storage bounds cumulative fragmented reads as well as allocations.
		var payload [maxFixtureMessageBytes + 1]byte
		n := 0
		for {
			read, err := reader.Read(payload[n:])
			n += read
			if n > maxFixtureMessageBytes {
				return wsutil.Message{}, errors.New("fixture WebSocket message budget exceeded")
			}
			if err == io.EOF {
				break
			}
			if err != nil {
				return wsutil.Message{}, err
			}
		}
		return wsutil.Message{OpCode: header.OpCode, Payload: payload[:n]}, nil
	}
}

func run() error {
	if len(os.Args) != 3 {
		return errors.New("expected listener port and CA certificate")
	}
	port, err := strconv.ParseUint(os.Args[1], 10, 16)
	if err != nil || port == 0 {
		return errors.New("invalid listener port")
	}
	pem, err := os.ReadFile(os.Args[2])
	if err != nil {
		return err
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(pem) {
		return errors.New("CA file contained no certificates")
	}
	var messages []json.RawMessage
	if err := json.NewDecoder(io.LimitReader(os.Stdin, 1<<20)).Decode(&messages); err != nil {
		return err
	}
	if len(messages) != 2 {
		return errors.New("expected the two channel messages")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := quic.DialAddr(ctx, fmt.Sprintf("127.0.0.1:%d", port), &tls.Config{
		RootCAs: roots, ServerName: "localhost", NextProtos: []string{"h3"}, MinVersion: tls.VersionTLS13,
	}, nil)
	if err != nil {
		return err
	}
	defer conn.CloseWithError(quic.ApplicationErrorCode(http3.ErrCodeNoError), "channel smoke complete")
	alpn := conn.ConnectionState().TLS.NegotiatedProtocol
	if alpn != "h3" {
		return fmt.Errorf("unexpected negotiated ALPN: %q", alpn)
	}
	transport := &http3.Transport{DisableCompression: true}
	defer transport.Close()
	client := transport.NewClientConn(conn)
	select {
	case <-client.ReceivedSettings():
	case <-ctx.Done():
		return ctx.Err()
	}
	enabled := client.Settings().EnableExtendedConnect
	if !enabled {
		return errors.New("server did not advertise ENABLE_CONNECT_PROTOCOL")
	}
	stream, err := client.OpenRequestStream(ctx)
	if err != nil {
		return err
	}
	end, _ := ctx.Deadline()
	if err := stream.SetDeadline(end); err != nil {
		return err
	}
	url := fmt.Sprintf("https://localhost:%d/socket/websocket?vsn=2.0.0&unified=h3", port)
	request, err := http.NewRequestWithContext(ctx, http.MethodConnect, url, nil)
	if err != nil {
		return err
	}
	// quic-go's documented extended CONNECT API uses Request.Proto.
	request.Proto = "websocket"
	request.Header.Set("Sec-WebSocket-Version", "13")
	request.Header.Set("Origin", fmt.Sprintf("https://localhost:%d", port))
	if err := stream.SendRequestHeader(request); err != nil {
		return err
	}
	response, err := stream.ReadResponse()
	if err != nil {
		return err
	}
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected CONNECT status: %d", response.StatusCode)
	}
	replies := make([][2]string, 0, len(messages))
	for _, message := range messages {
		if err := wsutil.WriteClientMessage(stream, ws.OpText, message); err != nil {
			return err
		}
		reply, err := readMessage(stream)
		if err != nil {
			return err
		}
		if reply.OpCode != ws.OpText {
			return fmt.Errorf("unexpected channel message type: %d", reply.OpCode)
		}
		replies = append(replies, [2]string{"text", string(reply.Payload)})
	}
	if err := wsutil.WriteClientMessage(stream, ws.OpClose, ws.NewCloseFrameBody(ws.StatusNormalClosure, "done")); err != nil {
		return err
	}
	closed, err := readMessage(stream)
	if err != nil {
		return err
	}
	if closed.OpCode != ws.OpClose {
		return fmt.Errorf("expected peer CLOSE, received opcode %d", closed.OpCode)
	}
	code, reason := ws.ParseCloseFrameData(closed.Payload)
	if err := ws.CheckCloseFrameData(code, reason); err != nil {
		return err
	}
	if code != ws.StatusNormalClosure {
		return fmt.Errorf("unexpected peer CLOSE code: %d", code)
	}
	// Preserve the original requirement for the peer's HTTP/3 stream FIN.
	remaining, err := io.ReadAll(io.LimitReader(stream, 1))
	if err != nil {
		return err
	}
	if len(remaining) != 0 {
		return errors.New("unexpected data after peer CLOSE")
	}
	if err := stream.Close(); err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{
		"alpn": alpn, "enable_extended_connect": enabled, "status": response.StatusCode,
		"stream": stream.StreamID(), "messages": replies, "close_code": code,
	})
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
