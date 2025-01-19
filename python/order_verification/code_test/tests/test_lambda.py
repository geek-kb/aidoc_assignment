import json
import os
import pytest
from unittest.mock import patch, MagicMock

# Set required environment variables for tests
os.environ["DYNAMODB_TABLE_NAME"] = "test-table"
os.environ["SQS_QUEUE_URL"] = "https://sqs.test.url"

from order_verification.order_verification import validate_order, send_to_sqs

@pytest.fixture
def mock_dynamodb():
    """
    Fixture to mock DynamoDB interactions.
    Creates a mock table that returns a successful query response.
    Allows verification of table creation and query calls.
    """
    with patch('order_verification.order_verification.dynamodb') as mock:
        # Create table mock with successful query response
        table_mock = MagicMock()
        table_mock.query.return_value = {"Count": 1}
        mock.Table.return_value = table_mock
        
        # Store mock for assertions in tests
        mock.table_mock = table_mock
        yield mock

@pytest.fixture
def mock_sqs():
    """
    Fixture to mock SQS interactions.
    Creates a mock SQS client that returns a successful message ID.
    Allows verification of message sending operations.
    """
    with patch('order_verification.order_verification.sqs') as mock:
        # Configure mock to return successful message sending response
        mock.send_message.return_value = {'MessageId': 'test-id'}
        yield mock

def test_validate_order(mock_dynamodb, capsys):
    """
    Test order validation logic.
    Verifies:
    1. Order with valid product data is accepted
    2. DynamoDB table is created with correct name
    3. Query is executed to check product existence
    """
    print("\nTesting order validation:")
    # Test data representing a valid order
    order_data = {
        "orderId": "12345",
        "customerEmail": "test@example.com",
        "items": [{"productId": "123", "productName": "Test Product"}]
    }
    print(f"Input order data: {json.dumps(order_data, indent=2)}")
    
    # Execute validation
    result = validate_order(order_data)
    print(f"Validation result: {result}")
    
    # Verify results
    assert result is True
    mock_dynamodb.Table.assert_called_once_with(os.environ["DYNAMODB_TABLE_NAME"])
    print("✓ DynamoDB table called with correct table name")
    mock_dynamodb.table_mock.query.assert_called()
    print("✓ DynamoDB query executed")

def test_send_to_sqs(mock_sqs, capsys):
    """
    Test SQS message sending functionality.
    Verifies:
    1. Message is sent to correct SQS queue URL
    2. Message body contains correct order data
    """
    print("\nTesting SQS message sending:")
    # Test order data for SQS
    order_data = {
        "orderId": "12345",
        "items": [{"productId": "123"}]
    }
    print(f"Input order data: {json.dumps(order_data, indent=2)}")
    
    # Send message to SQS
    send_to_sqs(order_data)
    
    # Verify correct SQS parameters
    mock_sqs.send_message.assert_called_once_with(
        QueueUrl=os.environ["SQS_QUEUE_URL"],
        MessageBody=json.dumps(order_data)
    )
    print("✓ SQS message sent with correct parameters")

if __name__ == "__main__":
    pytest.main(["-v", "--capture=no"])
