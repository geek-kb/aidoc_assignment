import pytest
import sys
import os

# Add code directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '../../code'))

@pytest.fixture(autouse=True)
def setup_environment(monkeypatch):
    """Configure environment before each test"""
    api_key = "b6f5a2d96a8e4f98b1c3d7a54e9f8b2c"
    queue_url = "https://sqs.eu-north-1.amazonaws.com/912466608750/order-processor"

    monkeypatch.setenv("API_KEY", api_key)
    monkeypatch.setenv("SQS_QUEUE_URL", queue_url)

    # Force reload environment variables in app
    import order_retrieval
    order_retrieval.API_KEY = api_key
    order_retrieval.SQS_QUEUE_URL = queue_url

    print("\nTest Environment Setup:")
    print(f"✓ API Key: {api_key}")
    print(f"✓ Queue URL: {queue_url}")

    return {"api_key": api_key, "queue_url": queue_url}
