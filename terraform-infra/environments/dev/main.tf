module "vpc" {
  source = "../../modules/vpc"

  project_name = "enterprise-devsecops"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  database_subnets = [
    "10.0.21.0/24",
    "10.0.22.0/24"
  ]

  availability_zones = [
    "ap-south-1a",
    "ap-south-1b"
  ]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "enterprise-devsecops-dev"
  cluster_version = "1.32"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = ["m7i-flex.large"]

  desired_size = 1
  min_size     = 1
  max_size     = 2
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "rag-document-qa"
  ]
}

module "github_oidc" {
  source      = "../../modules/github-oidc"
  github_repo = "Debasish-87/CDS"
}

module "alb_irsa" {
  source = "../../modules/iam/alb-controller"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider = replace(
    module.eks.oidc_provider_url,
    "https://",
    ""
  )
}

module "external_secrets_irsa" {
  source = "../../modules/iam/external-secrets"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider = replace(
    module.eks.oidc_provider_url,
    "https://",
    ""
  )
}

# ─── Outputs ───────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = module.eks.oidc_provider_url
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "github_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = module.github_oidc.github_role_arn
}

output "alb_controller_role_arn" {
  description = "IAM Role ARN for ALB Controller IRSA"
  value       = module.alb_irsa.role_arn
}

output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets IRSA"
  value       = module.external_secrets_irsa.role_arn
}
