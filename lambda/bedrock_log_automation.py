import json
import boto3
import logging

# Initialize AWS clients
sns_client = boto3.client('sns')
bedrock_client = boto3.client('bedrock-runtime')
logs_client = boto3.client('logs')

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    # Parse the CloudWatch Alarm event
    alarm_data = json.loads(event['Records'][0]['Sns']['Message'])
    
    # Extract relevant details (you may need to customize this based on your alarm's event structure)
    invocation_details = alarm_data.get('detail', {})
    """

    # Extract relevant details from CloudWatch event
    log_group = event['detail']['logGroup']
    log_stream = event['detail']['logStream']
    
    # Fetch the log events from CloudWatch Logs
    log_events = logs_client.filter_log_events(
        logGroupName=log_group,
        logStreamNames=[log_stream],
        limit=5  # Customize as needed
    )

    # Prepare the log event payload for Bedrock model
    log_payload = "\n".join([event['message'] for event in log_events['events']])

    # Create the prompt for the Bedrock model invocation
    prompt = {
        'input': log_payload,
        'context': 'Analyze the invocation log to detect issues and provide a summary.'
    }

    # Call Bedrock model for analysis
    response = bedrock_client.invoke_model(
        modelId='your-model-id',  # Replace with your Bedrock model ID
        body=json.dumps(prompt),
        contentType='application/json'
    )

    # Parse the model response
    model_response = response['body'].read().decode('utf-8')

    # Send SNS notification with model response
    sns_client.publish(
        TopicArn='arn:aws:sns:region:account-id:notification-topic',  # Replace with your SNS topic ARN
        Message=model_response,
        Subject='Bedrock Invocation Intervened: Analysis'
    )

    logger.info(f'SNS Notification Sent with Model Response: {model_response}')

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda executed successfully')
    }
