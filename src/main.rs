// src/main.rs

use lambda_runtime::{service_fn, LambdaEvent, Error};
use serde_json::Value;

async fn function_handler(event: LambdaEvent<Value>) -> Result<Value, Error> {
    // Deconstruct the incoming event into (payload, context)
    let (payload, _ctx) = event.into_parts();
    // Echo the JSON payload back
    Ok(payload)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    // Wrap your handler in a Service and run
    let handler = service_fn(function_handler);
    lambda_runtime::run(handler).await?;
    Ok(())
}