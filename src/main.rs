use lambda_runtime::{service_fn, LambdaEvent, Error};
use serde_json::Value;

async fn function_handler(event: LambdaEvent<Value>) -> Result<Value, Error> {
    let (payload, _ctx) = event.into_parts();
    Ok(payload)
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    let handler = service_fn(function_handler);
    lambda_runtime::run(handler).await?;
    Ok(())
}