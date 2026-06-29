# ==========================================================
# Enterprise DevSecOps Platform
# Makefile
# ==========================================================

SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help doctor fmt init validate plan apply destroy \
        kubeconfig bootstrap verify health dashboard \
        pods nodes services ingress namespaces events \
        logs grafana argocd clean release status setup all

# ==========================================================
# VARIABLES
# ==========================================================

AWS_REGION := ap-south-1

CLUSTER_NAME := enterprise-devsecops-dev

TF_DIR := terraform-infra/environments/dev

BOOTSTRAP_SCRIPT := bootstrap/argocd/install.sh

GREEN=\033[0;32m
RED=\033[0;31m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m

# ==========================================================
# HELP
# ==========================================================

help:
	@echo ""
	@echo "$(GREEN)Enterprise DevSecOps Platform$(NC)"
	@echo ""
	@echo "Infrastructure"
	@echo "-----------------------------"
	@echo " make doctor"
	@echo " make init"
	@echo " make fmt"
	@echo " make validate"
	@echo " make plan"
	@echo " make apply"
	@echo " make destroy"
	@echo ""
	@echo "Cluster"
	@echo "-----------------------------"
	@echo " make kubeconfig"
	@echo " make bootstrap"
	@echo " make verify"
	@echo " make health"
	@echo " make dashboard"
	@echo " make logs"
	@echo ""
	@echo "Git"
	@echo "-----------------------------"
	@echo " make status"
	@echo " make release"
	@echo ""
	@echo "Automation"
	@echo "-----------------------------"
	@echo " make setup"
	@echo " make all"
	@echo ""

# ==========================================================
# DOCTOR
# ==========================================================

doctor:
	@bash scripts/doctor.sh

# ==========================================================
# TERRAFORM
# ==========================================================

fmt:
	@bash scripts/terraform.sh fmt

init:
	@bash scripts/terraform.sh init

validate:
	@bash scripts/terraform.sh validate

plan:
	@bash scripts/terraform.sh plan

apply:
	@bash scripts/terraform.sh apply
	@$(MAKE) kubeconfig

destroy:
	@bash scripts/terraform.sh destroy

# ==========================================================
# KUBECONFIG
# ==========================================================

kubeconfig:
	@echo ""
	@echo "$(BLUE)Updating kubeconfig...$(NC)"
	@aws eks update-kubeconfig \
		--region $(AWS_REGION) \
		--name $(CLUSTER_NAME)

# ==========================================================
# BOOTSTRAP
# ==========================================================

bootstrap:
	@chmod +x $(BOOTSTRAP_SCRIPT)
	@bash $(BOOTSTRAP_SCRIPT)

# ==========================================================
# CLUSTER
# ==========================================================

pods:
	@kubectl get pods -A

nodes:
	@kubectl get nodes -o wide

services:
	@kubectl get svc -A

ingress:
	@kubectl get ingress -A

namespaces:
	@kubectl get ns

events:
	@kubectl get events -A \
		--sort-by=.metadata.creationTimestamp

# ==========================================================
# LOGS
# ==========================================================

logs:
	@bash scripts/logs.sh all

logs-argocd:
	@bash scripts/logs.sh argocd

logs-rag:
	@bash scripts/logs.sh rag

logs-prometheus:
	@bash scripts/logs.sh prometheus

logs-grafana:
	@bash scripts/logs.sh grafana

logs-falco:
	@bash scripts/logs.sh falco

logs-kyverno:
	@bash scripts/logs.sh kyverno

logs-trivy:
	@bash scripts/logs.sh trivy

# ==========================================================
# DASHBOARD
# ==========================================================

dashboard:
	@bash scripts/dashboard.sh all

grafana:
	@bash scripts/dashboard.sh grafana

argocd:
	@bash scripts/dashboard.sh argocd

prometheus:
	@bash scripts/dashboard.sh prometheus

otel:
	@bash scripts/dashboard.sh otel

# ==========================================================
# VERIFY
# ==========================================================

verify:
	@bash scripts/verify.sh

# ==========================================================
# HEALTH
# ==========================================================

health:
	@bash scripts/health.sh

# ==========================================================
# CLEANUP
# ==========================================================

clean:
	@bash scripts/cleanup.sh

# ==========================================================
# STATUS
# ==========================================================

status:
	@git status

# ==========================================================
# RELEASE
# ==========================================================

release:
	@bash scripts/release.sh

# ==========================================================
# DESTROY
# ==========================================================

nuke:
	@bash scripts/destroy.sh

# ==========================================================
# SETUP
# ==========================================================

setup:
	@echo ""
	@echo "$(GREEN)===========================================$(NC)"
	@echo "$(GREEN) Enterprise DevSecOps Platform Setup$(NC)"
	@echo "$(GREEN)===========================================$(NC)"
	@echo ""

	@$(MAKE) doctor
	@$(MAKE) init
	@$(MAKE) validate
	@$(MAKE) plan

	@echo ""
	@echo "$(YELLOW)Infrastructure will now be created...$(NC)"
	@echo ""

	@$(MAKE) apply
	@$(MAKE) bootstrap
	@$(MAKE) verify
	@$(MAKE) health

	@echo ""
	@echo "$(GREEN)===========================================$(NC)"
	@echo "$(GREEN) Infrastructure Ready$(NC)"
	@echo "$(GREEN)===========================================$(NC)"
	@echo ""
	@echo "Run:"
	@echo "  make dashboard"
	@echo ""
	@echo "To release:"
	@echo "  make release"
	@echo ""

# ==========================================================
# COMPLETE DEPLOYMENT
# ==========================================================

all: setup

# ==========================================================
# VERSION
# ==========================================================

version:
	@echo "Enterprise DevSecOps Platform"
	@echo "Version : v1.0"

# ==========================================================
# INFO
# ==========================================================

info:
	@echo ""
	@echo "AWS Region  : $(AWS_REGION)"
	@echo "Cluster     : $(CLUSTER_NAME)"
	@echo "Terraform   : $(TF_DIR)"
	@echo ""

