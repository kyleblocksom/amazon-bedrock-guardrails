# Amazon Bedrock Guardrails with Amazon CloudWatch

## Introduction

This project demonstrates how to implement, monitor, and refine AI safety measures at scale using Amazon Bedrock Guardrails and Amazon CloudWatch. It focuses on a practical example of an insurance assistant application, showcasing the end-to-end process of planning, deploying, testing, monitoring, and optimizing guardrails to ensure the safety and compliance of the AI interactions.

## Key Features

1. **Deployment with Terraform**: The solution uses Infrastructure as Code (IaC) with Terraform to automate the creation and deployment of Amazon Bedrock Guardrails and related monitoring infrastructure across different environments.
2. **Guardrail Types**: The project implements the following types of guardrails:
   - Insurance-specific: Restricts responses on sensitive insurance-related topics.
   - Content Filtering: Filters harmful or inappropriate content, including sexual, violent, hateful, and profane material.
   - PII Handling: Anonymizes or blocks personally identifiable information (PII).
   - Competitors: Prevents references to competitor companies or comparative product analysis.
   - Word Filters: Excludes specific sensitive or inappropriate words and phrases.
3. **Comprehensive Testing**: The solution includes a testing framework that uses the Amazon Bedrock Converse API to systematically evaluate the deployed guardrails across various scenarios.
4. **Monitoring and Visualization**: Amazon CloudWatch is used to track the performance of the guardrails, including both native Amazon Bedrock metrics and custom metrics tailored to the specific use case.
5. **Alerting and Optimization**: The project implements an automated alerting system using CloudWatch Alarms and AWS Lambda functions, enabling teams to respond to potential issues and optimize the guardrail configurations over time.

## Architecture Overview

The solution workflow consists of the following steps:

1. User sends a request to the insurance assistant application.
2. The application forwards the request to Amazon Bedrock, invoking the Converse API with specified guardrails.
3. Amazon Bedrock processes the request through the selected foundation model, applying the configured guardrails.
4. The model's response is evaluated against the guardrails before being returned to the application.
5. Amazon Bedrock logs information about the request, response, and any guardrail interventions to Amazon CloudWatch Logs.
6. Amazon CloudWatch Metrics are generated from the logs using predefined metric filters.
7. Amazon CloudWatch Alarms monitor these metrics and generate alerts when thresholds are exceeded.
8. When an alarm is raised, it sends a notification to an Amazon Simple Notifications Service (SNS) topic.
9. The SNS topic triggers an AWS Lambda function for alert processing.
10. The AWS Lambda function analyzes logs, leverages Amazon Bedrock for summarization, then sends detailed alerts through SNS.
11. Operations teams receive notifications and can access the Amazon CloudWatch Dashboard for a visual overview of all metrics and alarms.
12. Based on the monitoring data and alerts, teams can optimize guardrail configurations and re-deploy using Terraform.

## Getting Started

To get started with this solution, follow these steps:

1. Clone the repository: `git clone [repo-url]`
2. Navigate to the Terraform directory: `cd [repo-name]/terraform`
3. Review and customize the `variables.tf` file to match your requirements.
4. Initialize Terraform and apply the configuration:
   ```
   terraform init
   terraform plan
   terraform apply
   ```
5. Verify the deployed resources in the AWS Console.
6. Explore the [notebook code and testing framework](./notebook).
7. Monitor the solution's performance using the Amazon CloudWatch Dashboard.
8. Optimize the guardrail configurations based on the monitoring data and alerts.

## Conclusion

This project provides a comprehensive approach to implementing and managing AI safety measures using Amazon Bedrock Guardrails and Amazon CloudWatch. By leveraging Terraform for deployment, a robust testing framework, and a powerful monitoring and alerting system, organizations can maintain high standards of AI safety while adapting to evolving requirements and emerging risks in the field of generative AI.