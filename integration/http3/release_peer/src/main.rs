//! Independent HTTP/3 release client using public h3, Quinn and rustls APIs.
use bytes::{Buf, Bytes};
use http::{HeaderMap, HeaderValue, Request};
use quinn::crypto::rustls::{HandshakeData, QuicClientConfig};
use serde_json::{json, Value};
use std::{error::Error, fs::File, io::BufReader, sync::Arc, time::Duration};
use tokio::time::timeout;

type Result<T> = std::result::Result<T, Box<dyn Error + Send + Sync>>;

#[derive(Clone, Copy)]
enum RequestKind {
    Get,
    Trailers,
    ConsumerGet,
    ConsumerUpload,
}

fn fields(headers: &HeaderMap) -> Result<Vec<Vec<String>>> {
    headers
        .iter()
        .map(|(name, value)| {
            Ok(vec![
                name.as_str().to_owned(),
                String::from_utf8(value.as_bytes().to_vec())?,
            ])
        })
        .collect()
}

async fn request(
    sender: &mut h3::client::SendRequest<h3_quinn::OpenStreams, Bytes>,
    port: u16,
    path: &str,
    kind: RequestKind,
    connection_id: usize,
) -> Result<Value> {
    let consumer = matches!(kind, RequestKind::ConsumerGet | RequestKind::ConsumerUpload);
    let trailers = matches!(kind, RequestKind::Trailers);
    let upload =
        matches!(kind, RequestKind::ConsumerUpload).then(|| b"clean-h3-consumer-".repeat(4096));
    timeout(Duration::from_secs(if consumer { 8 } else { 5 }), async {
        let authority = if consumer {
            "localhost".to_owned()
        } else {
            format!("localhost:{port}")
        };
        let mut request = Request::builder()
            .method(if trailers || upload.is_some() {
                "POST"
            } else {
                "GET"
            })
            .uri(format!("https://{authority}{path}"))
            .body(())?;
        if let Some(payload) = &upload {
            request.headers_mut().insert(
                "content-length",
                HeaderValue::from_str(&payload.len().to_string())?,
            );
        }
        if trailers {
            request
                .headers_mut()
                .insert("content-length", HeaderValue::from_static("0"));
            request
                .headers_mut()
                .insert("trailer", HeaderValue::from_static("x-check"));
        }
        let mut stream = sender.send_request(request).await?;
        let stream_id = stream.id().into_inner();
        if let Some(payload) = &upload {
            for chunk in payload.chunks(4096) {
                stream.send_data(Bytes::copy_from_slice(chunk)).await?;
            }
        }
        if trailers {
            let mut fields = HeaderMap::new();
            fields.append("x-check", HeaderValue::from_static("one"));
            fields.append("x-check", HeaderValue::from_static("two"));
            stream.send_trailers(fields).await?;
        }
        // send_trailers writes HEADERS; finish supplies the actual stream FIN.
        stream.finish().await?;
        let response = stream.recv_response().await?;
        let mut initial = vec![vec![
            ":status".to_owned(),
            response.status().as_u16().to_string(),
        ]];
        initial.extend(fields(response.headers())?);
        let mut headers = vec![initial];
        let mut body = Vec::new();
        while let Some(mut chunk) = stream.recv_data().await? {
            if body.len() + chunk.remaining() > 262_144 {
                return Err("packaged H3 smoke response exceeded allowance".into());
            }
            let remaining = chunk.remaining();
            body.extend_from_slice(&chunk.copy_to_bytes(remaining));
        }
        // h3 waits for stream EOF when receiving trailers and rejects later frames.
        if let Some(trailers) = stream.recv_trailers().await? {
            headers.push(fields(&trailers)?);
        }
        Ok(json!({
            "path": path, "connection_id": connection_id, "stream_id": stream_id,
            "headers": headers, "body": body, "ended": true
        }))
    })
    .await?
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    let mut args = std::env::args().skip(1);
    let port: u16 = args.next().ok_or("missing listener port")?.parse()?;
    let ca = args.next().ok_or("missing CA certificate")?;
    let option = args.next();
    let consumer = option.as_deref() == Some("--consumer");
    let path = match option {
        None => None,
        Some(option) if option == "--consumer" && args.next().is_none() => None,
        Some(option) if option == "--path" => {
            let path = args.next().ok_or("missing GET path")?;
            if !path.starts_with('/') || args.next().is_some() {
                return Err("expected one absolute GET path".into());
            }
            Some(path)
        }
        _ => return Err("expected listener port, CA certificate and --path or --consumer".into()),
    };
    let mut roots = rustls::RootCertStore::empty();
    for certificate in rustls_pemfile::certs(&mut BufReader::new(File::open(ca)?)) {
        roots.add(certificate?)?;
    }
    if roots.is_empty() {
        return Err("CA file contained no certificates".into());
    }
    let mut tls = rustls::ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();
    tls.alpn_protocols = vec![b"h3".to_vec()];
    let mut endpoint = quinn::Endpoint::client("127.0.0.1:0".parse()?)?;
    endpoint.set_default_client_config(quinn::ClientConfig::new(Arc::new(
        QuicClientConfig::try_from(tls)?,
    )));
    let connection = endpoint
        .connect(format!("127.0.0.1:{port}").parse()?, "localhost")?
        .await?;
    let handshake = connection
        .handshake_data()
        .ok_or("missing TLS handshake data")?
        .downcast::<HandshakeData>()
        .map_err(|_| "unexpected TLS handshake provider")?;
    let alpn = handshake.protocol.ok_or("missing negotiated ALPN")?;
    if alpn != b"h3" {
        return Err("negotiated ALPN was not h3".into());
    }
    let connection_id = connection.stable_id();
    let (mut driver, mut sender) =
        h3::client::new(h3_quinn::Connection::new(connection.clone())).await?;
    let driving = tokio::spawn(async move { driver.wait_idle().await });
    let mut responses = Vec::new();
    if consumer {
        responses.push(
            request(
                &mut sender,
                port,
                "/",
                RequestKind::ConsumerGet,
                connection_id,
            )
            .await?,
        );
        responses.push(
            request(
                &mut sender,
                port,
                "/echo",
                RequestKind::ConsumerUpload,
                connection_id,
            )
            .await?,
        );
    } else if let Some(path) = path {
        responses.push(request(&mut sender, port, &path, RequestKind::Get, connection_id).await?);
    } else {
        responses.push(request(&mut sender, port, "/", RequestKind::Get, connection_id).await?);
        responses.push(
            request(
                &mut sender,
                port,
                "/echo-zero-declared",
                RequestKind::Trailers,
                connection_id,
            )
            .await?,
        );
    }
    drop(sender);
    connection.close(0x100u32.into(), b"release smoke complete");
    timeout(Duration::from_secs(2), endpoint.wait_idle()).await?;
    let _ = timeout(Duration::from_secs(2), driving).await?;
    println!(
        "{}",
        json!({"implementation": "h3-quinn", "alpn": String::from_utf8(alpn)?,
               "connection_id": connection_id, "responses": responses})
    );
    Ok(())
}
