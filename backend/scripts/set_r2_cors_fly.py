import os
import boto3

def set_cors():
    endpoint = os.getenv("R2_ENDPOINT")
    if not endpoint:
        print("Error: No R2_ENDPOINT found in environment variables.")
        return
        
    endpoint = endpoint.rstrip("/")
    if not endpoint.startswith("http"):
        endpoint = f"https://{endpoint}"
        
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=os.getenv("R2_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("R2_SECRET_ACCESS_KEY"),
        region_name="auto"
    )
    bucket = os.getenv("R2_BUCKET") or os.getenv("R2_BUCKET_NAME") or "celestya-media"
    print(f"Applying CORS config to: {bucket} at {endpoint}")
    
    cors_configuration = {
        'CORSRules': [{
            'AllowedHeaders': ['*'],
            'AllowedMethods': ['GET', 'HEAD', 'PUT', 'POST', 'DELETE'],
            'AllowedOrigins': ['*'],
            'ExposeHeaders': ['ETag']
        }]
    }
    
    try:
        client.put_bucket_cors(Bucket=bucket, CORSConfiguration=cors_configuration)
        print(f"SUCCESS: CORS successfully applied to bucket {bucket}")
    except Exception as e:
        import traceback
        print(f"FAILED: Error configuring CORS for {bucket}: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    set_cors()
