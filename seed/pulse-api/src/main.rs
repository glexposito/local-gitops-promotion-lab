use axum::{Router, http::StatusCode, routing::get};

const HELLO_WORLD: &str = "Hello, World!";
const DEFAULT_PORT: u16 = 8080;

#[tokio::main]
async fn main() {
    let port = std::env::var("PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(DEFAULT_PORT);

    let app = Router::new()
        .route("/", get(root))
        .route("/hello", get(hello))
        .route("/live", get(live))
        .route("/ready", get(ready))
        .route("/hostname", get(hostname));

    let listener = tokio::net::TcpListener::bind(("0.0.0.0", port))
        .await
        .unwrap();

    println!("Pulse API running on http://0.0.0.0:{port}");

    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    HELLO_WORLD
}

async fn hello() -> &'static str {
    HELLO_WORLD
}

async fn live() -> StatusCode {
    StatusCode::OK
}

async fn ready() -> StatusCode {
    StatusCode::OK
}

async fn hostname() -> String {
    hostname::get()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string()
}
