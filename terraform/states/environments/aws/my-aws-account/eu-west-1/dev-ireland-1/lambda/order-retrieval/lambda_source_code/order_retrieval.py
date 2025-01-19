import boto3
import json
import os
import logging
from flask import Flask, request, jsonify
from werkzeug.middleware.proxy_fix import ProxyFix
from botocore.exceptions import ClientError, BotoCoreError

# Configure logging
default_log_args = {
    "level": logging.DEBUG if os.environ.get("DEBUG", False) else logging.INFO,
    "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    "datefmt": "%d-%b-%y %H:%M",
    "force": True,
}
logging.basicConfig(**default_log_args)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Adjust Flask to handle requests via a proxy (like AWS Lambda Function URL)
app.wsgi_app = ProxyFix(app.wsgi_app)

# AWS environment variables
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
API_KEY = os.getenv("API_KEY")


# AWS SQS client
sqs = boto3.client('sqs')
ssm = boto3.client('ssm')
parameter_name = os.getenv("SSM_API_KEY")

# def get_api_key():
#     response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
#     return response['Parameter']['Value']

@app.route('/process', methods=['POST'])
def process_order():
    """
    Process an order by retrieving it from the SQS queue.
    The endpoint is secured with an API key.
    """
    logger.info("Received request to /process endpoint")

    # Check for API key in headers
    api_key = request.headers.get('x-api-key')
    if api_key != API_KEY:
        logger.warning("Unauthorized access attempt detected")
        return jsonify({"error": "Unauthorized"}), 401

    try:
        # Receive a message from the SQS queue
        logger.info("Attempting to retrieve a message from SQS queue")
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,  # Retrieve one message at a time
            WaitTimeSeconds=10  # Long polling
        )

        messages = response.get('Messages', [])
        if not messages:
            logger.info("No orders found in the SQS queue")
            return jsonify({"message": "No orders in the queue"}), 200

        message = messages[0]
        receipt_handle = message['ReceiptHandle']
        order_details = json.loads(message['Body'])

        # Log the retrieved message details
        logger.info(f"Retrieved message from SQS: {order_details}")

        # Delete the message from the queue
        logger.info("Attempting to delete the message from SQS queue")
        sqs.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=receipt_handle
        )
        logger.info("Message successfully deleted from SQS queue")

        return jsonify({"order": order_details}), 200

    except ClientError as e:
        logger.error(f"AWS ClientError occurred: {e}")
        return jsonify({"error": "Failed to retrieve or process the order", "details": str(e)}), 500
    except BotoCoreError as e:
        logger.error(f"AWS BotoCoreError occurred: {e}")
        return jsonify({"error": "AWS SDK issue", "details": str(e)}), 500
    except json.JSONDecodeError as e:
        logger.error(f"Failed to decode message body as JSON: {e}")
        return jsonify({"error": "Invalid message format", "details": str(e)}), 400
    except Exception as e:
        logger.error(f"Unexpected error occurred: {e}")
        return jsonify({"error": "An unexpected error occurred", "details": str(e)}), 500

# Lambda entry point
def lambda_handler(event, context):
    """
    AWS Lambda entry point for the Flask application.
    """
    logger.info("Lambda function triggered with event")
    try:
        # Proxy the event to the Flask app
        from werkzeug.wrappers import Request, Response
        request = Request(event)
        response = app.full_dispatch_request()
        return Response(response)
    except Exception as e:
        logger.error(f"Unexpected error in lambda_handler: {e}")
        raise
