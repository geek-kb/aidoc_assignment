FROM public.ecr.aws/lambda/python:3.9

# Copy the function code
COPY order_retrieval.py requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies (if any)
RUN pip install -r requirements.txt --no-cache-dir

# Set the handler
CMD ["order_retrieval.lambda_handler"]
