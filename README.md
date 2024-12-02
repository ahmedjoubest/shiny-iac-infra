# Jonah IaC Shiny Deployment

## Deployment and Environment Setup

### I. Terraform Deployment Workflow

In this setup, images are pushed locally without a CI/CD pipeline, so deployment with Terraform requires three steps:

1. **Apply Targeted Resources:** Create the ECR repository to make it available for image storage (note: same goes for the `logout_server` repository). Run the following commands:
   ```bash
   terraform apply -target=aws_ecr_repository.shiny_repository
   terraform apply -target=aws_ecr_repository.logout_server
   ```

2. **Push the Image:** Manually push the Docker image to ECR (refer to Docker commands in the next sections).

3. **Apply All Resources:** Run a full Terraform apply to complete the deployment, now that the image exists in ECR for use in the ECS task definition:
   ```bash
   terraform apply
   ``` 

This sequence ensures the image is available in ECR before deployment. Otherwise, it would require a manual update to the ECS task definition to point to the correct image URI (via the AWS Console).

### II. Steps to Push Docker Image to AWS ECR Manually

1. **Build the Docker Image Locally**: After having installed Docker on your Machine, run the following command to build the Docker image from the `Dockerfile`
   ```sh
   docker build -t shiny-repository .
   ```

2. **Tag the Image with the ECR Repository URI**: Tag the image to prepare it for upload to ECR. Replace `<aws_account_id>` and `<region>` with your AWS account ID and region.
   ```sh
   docker tag shiny-repository:latest 302263049627.dkr.ecr.us-east-1.amazonaws.com/shiny-repository:latest
   ```

**Note**: the `latest` tag is used in the Terraform configuration to pull the image from ECR. If you use a different tag, update the `container_definitions` in `main.tf` accordingly.
Same goes for `shiny-repository`.

3. **Authenticate Docker with ECR**: Use the AWS CLI to authenticate Docker with ECR. Replace `<region>` and `<aws_account_id>` as needed
   ```sh
   aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
   ```

You can get your account ID by running the following command in the AWS CLI:
```sh
aws sts get-caller-identity
```

4. **Push the Image to ECR**: Push the tagged image to the ECR repository
   ```sh
   docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/shiny-repository:latest
   ```

### III. Moving to the Production Environment

When moving to a production environment, consider the following changes:

- **Variables - VPC and Subnet IDs**: The `variables.tf` file contains variables for the VPC ID, subnet IDs, and other configuration settings. Update these variables to match the production environment.

Retrieve VPC and subnet IDs using the AWS CLI:
```sh
aws ec2 describe-vpcs --region <region> --query "Vpcs[*].VpcId" --output table
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" --region <region> --query "Subnets[*].SubnetId" --output table
```
   Replace `<region>` with your AWS region (e.g., `us-east-1`). Update `variables.tf` with the retrieved values.

- **Open-Access Security**: In this testing setup, the security group allows access from any IP (0.0.0.0/0) on port 3838 for easy access. In production, restrict access to specific IP ranges, especially for internal resources different from the data portals.

- **Docker File**: Please note that docker file is very simple and that in production we would need to add more to it
rephrase the last line
Please note that the Dockerfile is very simple and may need to be updated for production use. For example: [package management with `renv`](https://rstudio.github.io/renv/articles/docker.html), adding environment variables, setting up a non-root user, and other security best practices.
- **CI/CD Pipeline**: While it may seem overkill, setting up a CI/CD pipeline to automate the build and deployment process is recommended.

## Infrastructure Components and Configuration

### AWS Resources and Security Details

- The architecture leverages an internet-facing ALB with SSL termination to securely route incoming HTTPS traffic to an ECS Fargate-based service that hosts the Shiny app as a containerized service within a designated ECS cluster.

- The ALB is configured with stickiness to ensure that all requests from a user during their session are routed to the same server. This is achieved using **ALB-generated cookies**.
Traffic is routed to the ECS service in the target group through a Cognito user pool authorizer, which validates the user's JWT token before allowing access to the Shiny app. Please refer to the Cognito section for more details.

- For security, the ALB has a dedicated security group open to the internet on port 443, while the ECS service security group restricts access to traffic solely from the ALB, ensuring controlled and secure access.

- An SSL certificate is provisioned in ACM with DNS validation to secure the ALB and enable HTTPS traffic to the specified domain, including support for the `www` subdomain.

- CloudWatch is configured for centralized log management, enabling efficient logging and monitoring of the Shiny app.

### Cognito User Pool

#### User Authentication and Attributes

An AWS Cognito User Pool is configured to manage user authentication and attributes, supporting public sign-ups, email-based login, and automatic email verification. Key components are:

1. **User Pool**: Manages attributes including required fields (`email`, `given_name`, `family_name`) and optional fields (`phone_number`, `custom:role`, `custom:type`).  

2. **User Pool Domain**: Provides a unique domain for hosting authentication flows.  

3. **User Pool Client**:   Supports OAuth 2.0 with secure authorization code grant.  Configurable `callback_urls` (post-login redirection) and `logout_urls` (post-logout redirection) to handle user session flows effectively.

#### Logout Architecture

The Shiny app uses a **custom logout server** using `plumber` in `logout-plumber/` to handle user logout requests. The server/task is deployed as a separate ECS service in the same cluster, with a dedicated security group.
A Specific ALB Rule is configured to route `/logout` requests to this security group, instead of the shiny app default security group.

In the Shiny app, when the logout button is clicked:

- A GET request is sent to the `/logout` endpoint, which triggers the `AWSELBAuthSessionCookie-0` and `AWSELBAuthSessionCookie-1` cookies expiration, using the `Set-Cookie` header.
- A redirect to the Cognito logout URL is initiated, which invalidates the user's token and logs them out.

## Autoscaling Overview

### Current Approach

The infrastructure dynamically scales based on active sessions metrics. A DynamoDB table, updated via the `update_active_sessions_per_task()` function during user connection and disconnection, tracks global active session counts and number of tasks running. This data feeds the custom `SessionsPerTask` metric in CloudWatch, monitored by 2 alarms, each triggering a scaling action (Based on the [Step Scaling policy](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html)):

- **Scale Out**: Adds tasks when session load exceeds the threshold.
- **Scale In**: Reduces tasks during low activity, maintaining the minimum task count.

Current parameters:

- Minimum and maximum tasks: 1 and 5 
- Scale thresholds: 3 users per task (scale in) and 15 users per task (scale out)

These parameters can be set as environment variables, **in which case it would require alignment between R** (the `update_active_sessions_per_task()` function) **and Terraform** configurations.

**Limitations of AWS Native Metrics**: Metrics like `ActiveConnectionCount` and `ActiveSessionCount` from the ELB were tested but found unreliable as they include connections to both the load balancer and targets. (Ref: [AWS Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)).

### Next Steps for Autoscaling

1. **Metric Monitoring**: Simulate or monitor metrics in production to determine the most relevant for scaling policies. I also implemented CloudWatch Alarms for CPU usage and memory (without autoscaling actions) for this.
2. **Regular Metric Updates required**: If we go with the number of active sessions, then **we should Implement an AWS Lambda function** to update `SessionsPerTask` in CloudWatch at 1-2 minutes intervals. This resolves issues where:
   - Missing data causes alarms to fail - Data could be missing on static traffic, since the DynamoDB table is only updated on user connection/disconnection.
   - Alarms could not trigger scaling actions without new data points - where `treat_missing_data  = "ignore"` is not enough.
3. **Refinement**: Adjust scaling policies based on observed performance.
4. **Sessions Sticking**: A careful consideration should be given to session sticking. This is important to ensure that users are not disconnected when the scaling action is triggered. This can be achieved by using the `stickiness` feature of the ALB.

### Simpler Alternative

A **target tracking scaling policy** based on CPU utilization (or memory) offers a simpler and effective approach for many use cases. Using CPU metrics for scaling reduces complexity while ensuring robust performance. (Ref: [AWS Target Tracking Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-target-tracking.html)).








