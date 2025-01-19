# Order Verification System

## Download & Setup

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/ordering-project.git
cd ordering-project
```

2. Setup Python Environment
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
source venv/bin/activate  # For Mac

# Install dependencies
pip install -r requirements.txt
```

## Project Structure
```bash
ordering-project/
├── source_code_test/
│   ├── order_verification/
│   │   ├── __init__.py
│   │   └── order_verification.py
│   ├── tests/
│   │   ├── __init__.py
│   │   └── test_lambda.py
│   ├── requirements.txt
│   └── pyproject.toml
```

## Run Tests
```bash
cd source_code_test
python -m pytest tests/test_lambda.py -v --capture=no
```

## Test Output Example:
```bash
Testing order validation:
Input order data: {
  "orderId": "12345",
  "customerEmail": "test@example.com",
  "items": [{"productId": "123"}]
}
✓ DynamoDB table called with correct table name
✓ DynamoDB query executed
```

## Environment Variables
| Name                 | Description    |        Default        |
|:--------------------:|:--------------:|:---------------------:|
| DYNAMODB_TABLE_NAME  | DynamoDB table | test-table            |
| SQS_QUEUE_URL        | SQS queue URL  | https://sqs.test.url  |
