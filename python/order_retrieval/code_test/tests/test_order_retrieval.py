import pytest
from unittest.mock import patch, MagicMock
import json
from order_retrieval import app, lambda_handler

class TestOrderRetrieval:
    """Test suite for Order Retrieval Lambda function"""

    def test_successful_order_retrieval(self, setup_environment, capsys):
        """Test successful order retrieval with valid API key"""
        print("\nTesting successful order retrieval:")
        
        test_order = {
            'orderId': '123',
            'items': [{'id': '1', 'quantity': 2}]
        }
        print(f"Test order: {json.dumps(test_order, indent=2)}")

        with patch('order_retrieval.sqs') as mock_sqs:
            mock_sqs.receive_message.return_value = {
                'Messages': [{
                    'Body': json.dumps(test_order),
                    'ReceiptHandle': 'receipt123'
                }]
            }
            print("✓ Mocked SQS")

            event = {
                'rawPath': '/process',
                'headers': {'x-api-key': setup_environment['api_key']}
            }
            print("✓ Event created")

            response = lambda_handler(event, None)
            print(f"Response: {json.dumps(response, indent=2)}")
            
            assert response['statusCode'] == 200
            response_body = json.loads(response['body'])
            assert 'order' in response_body
            assert response_body['order'] == test_order
            print("✓ Assertions passed")

    def test_empty_queue(self, setup_environment, capsys):
        """Test empty queue handling"""
        print("\nTesting empty queue handling:")
        
        with patch('order_retrieval.sqs') as mock_sqs:
            mock_sqs.receive_message.return_value = {}
            print("✓ Mocked empty SQS queue")

            event = {
                'rawPath': '/process',
                'headers': {'x-api-key': setup_environment['api_key']}
            }
            print("✓ Event created")

            response = lambda_handler(event, None)
            print(f"Response: {json.dumps(response, indent=2)}")
            
            assert response['statusCode'] == 200
            assert json.loads(response['body'])['message'] == 'No orders to process'
            print("✓ Assertions passed")

    def test_invalid_api_key(self, setup_environment, capsys):
        """Test invalid API key rejection"""
        print("\nTesting invalid API key:")
        
        event = {
            'rawPath': '/process',
            'headers': {'x-api-key': 'invalid_key'}
        }
        print("✓ Created event with invalid API key")

        response = lambda_handler(event, None)
        print(f"Response: {json.dumps(response, indent=2)}")
        
        assert response['statusCode'] == 401
        assert 'error' in json.loads(response['body'])
        print("✓ Assertions passed")
