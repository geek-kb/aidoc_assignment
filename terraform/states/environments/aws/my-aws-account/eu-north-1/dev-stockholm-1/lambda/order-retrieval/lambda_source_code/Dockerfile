FROM public.ecr.aws/lambda/python:3.11

WORKDIR /var/task

COPY requirements.txt .
RUN pip install -r requirements.txt --no-cache-dir

COPY order_retrieval.py requirements.txt ./

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/var/task
ENV DEBUG=true

CMD [ "order_retrieval.lambda_handler" ]
