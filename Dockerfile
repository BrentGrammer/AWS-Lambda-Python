# Create an environment that looks exactly like the AWS Lambda function will run with
FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt ${LAMBDA_TASK_ROOT}

# install dependencies into a libs folder
RUN mkdir libs
RUN pip install -r requirements.txt -t libs
RUN cd libs/
# add __init__.py to libs to make it an importable module
RUN touch __init__.py
RUN cd ../

COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]