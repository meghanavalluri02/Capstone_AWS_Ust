**🛒 E-Commerce Microservice Capstone Project**
This project is a cloud-based e-commerce application built using microservices and deployed on Amazon EKS. It includes multi-region infrastructure setup using Terraform and CloudFormation, CI/CD automation using AWS CodePipeline, DNS failover using Route53, and monitoring with CloudWatch.

**📌 Project Goals**
- 🚀 Deploy a containerized e-commerce application (Product, Order, Frontend services) on AWS EKS  
- 🔁 Automate infrastructure setup using Terraform (Region B) and CloudFormation (Region A)  
- 📦 Implement CI/CD using AWS CodePipeline and CodeBuild  
- 🌍 Setup multi-region failover using Route 53  
- 📊 Monitor infrastructure using CloudWatch  


**⚙️ Components**
| Component            | Tool / Service                      | Description                                       |
|----------------------|--------------------------------------|---------------------------------------------------|
| Application Layer    | EKS + Docker                         | Microservices: Product, Order, Frontend           |
| CI/CD                | AWS CodePipeline, CodeBuild          | Automates Docker image builds and EKS deployments |
| Infra (Region A)     | AWS CloudFormation                   | Sets up VPC, EKS, Subnets, Security groups        |
| Infra (Region B)     | Terraform                            | Replicates Infra setup in another region          |
| DNS Failover         | Route 53                             | Configures health checks and regional failover    |
| Monitoring           | CloudWatch, SNS                      | Collects metrics/logs and sends alert notifications |


**🔧 Tools Used**
- **Amazon EKS** – for container orchestration  
- **AWS ECR** – to store container images  
- **Docker** – for containerizing microservices  
- **Kubernetes** – to manage deployments  
- **AWS CodePipeline/CodeBuild** – for CI/CD automation  
- **CloudFormation** – to deploy infra in Region A  
- **Terraform** – to deploy infra in Region B  
- **Route 53** – for DNS-based failover  
- **CloudWatch** – for monitoring and alerting  

**Architecture:**
![image](https://github.com/user-attachments/assets/58599a59-cc7b-4153-973f-64cc84d4e150)


**🚀 EKS Deployment Steps**
**1. Create EKS Cluster Using `eksctl`**
eksctl create cluster \
  --name ecommerce-cluster \
  --region <region> \
  --nodes 2

**2. Push Docker Images to ECR**
docker build -t product-service ./product-service
docker tag product-service:latest <your-account>.dkr.ecr.<region>.amazonaws.com/product-service:latest
docker push <your-account>.dkr.ecr.<region>.amazonaws.com/product-service:latest

**3. Apply Kubernetes Manifests**
kubectl apply -f k8s/mysql-deployment.yaml
kubectl apply -f k8s/product-deploy.yaml
kubectl apply -f k8s/order-deploy.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/services.yaml
kubectl apply -f k8s/ingress.yaml

**4. Access the Application**
Open LoadBalancer/Ingress URL to access the frontend
Test product add/view and order placement

**🔁 CI/CD Pipeline Setup**
Connect GitHub Repo to AWS CodePipeline
  Create new pipeline in CodePipeline
    a. Set source provider to GitHub
    b. Use buildspec.yaml for CodeBuild configuration

**🌍 Multi-Region Infrastructure Deployment**
📍 Region A – Using CloudFormation

GitHub Repo: Capstone - CloudFormation

aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name ecommerce-a \
  --region us-east-1

Region B – Using Terraform

GitHub Repo: Capstone - Terraform

terraform init

terraform apply

**🌐 Route 53 Failover Setup**
Create Health Check

For Region A LoadBalancer URL

Create Hosted Zone

Create A Records with Failover Policy

Primary: Region A

Secondary: Region B

Test failover by simulating failure in Region A

**📊 CloudWatch Monitoring Setup**
Logs: Set up logGroup and send application logs from EKS

Metrics: Enable CPU, memory, network metrics

Alarms: Use thresholds and create alarms

Notifications: Attach SNS topics to alarms for email alerts

**🧪 Application Features**
🛒 Add Product

🔍 View Products

📦 Place Order

📋 View Orders

💾 Persistent data using MySQL backend

🌐 DNS failover and multi-region availability
