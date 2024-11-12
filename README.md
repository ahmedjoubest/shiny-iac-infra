# Jonah IaC Shiny Deployment

## Deployment and Environment Setup

### I. Terraform Deployment Workflow

In this setup, images are pushed locally without a CI/CD pipeline, so deployment with Terraform requires three steps:

1. **Apply Targeted Resources:** Create the ECR repository to make it available for image storage:
   ```bash
   terraform apply -target=aws_ecr_repository.shiny_repository
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

- For security, the ALB has a dedicated security group open to the internet on port 443, while the ECS service security group restricts access to traffic solely from the ALB, ensuring controlled and secure access.

- An SSL certificate is provisioned in ACM with DNS validation to secure the ALB and enable HTTPS traffic to the specified domain, including support for the `www` subdomain.

- CloudWatch is configured for centralized log management, enabling efficient logging and monitoring of the Shiny app.









