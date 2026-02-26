import os
import boto3
from dotenv import load_dotenv

env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
load_dotenv(env_path)

def set_cors():
    endpoint = os.getenv("R2_ENDPOINT")
    if not endpoint:
        print("No R2_ENDPOINT found in .env")
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
        print(f"CORS successfully applied to bucket {bucket}")
    except Exception as e:
        print(f"Error configuring CORS for {bucket}: {e}")

if __name__ == "__main__":
    set_cors()
