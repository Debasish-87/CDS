#!/usr/bin/env bash
# ============================================================
# Enterprise DevSecOps Platform
# Bootstrap Script
# ============================================================

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${ROOT_DIR}/scripts/helpers.sh"

ARGO_SCRIPT="${ROOT_DIR}/bootstrap/argocd/install.sh"

AWS_REGION="ap-south-1"
CLUSTER_NAME="enterprise-devsecops-dev"

banner
title "Enterprise DevSecOps Bootstrap"

# ============================================================
# REQUIREMENTS
# ============================================================

doctor() {

    title "Checking Requirements"

    require kubectl
    require helm
    require terraform
    require aws
    require git

    aws_login

}

# ============================================================
# UPDATE KUBECONFIG
# ============================================================

update_kubeconfig() {

    title "Updating kubeconfig"

    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME"

    cluster_check

    success "Connected to cluster"

}

# ============================================================
# VERIFY CLUSTER
# ============================================================

verify_cluster() {

    title "Cluster"

    kubectl get nodes

    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)

    if [[ "$NODE_COUNT" -eq 0 ]]; then

        die "No worker nodes found."

    fi

    success "$NODE_COUNT Worker Node(s)"

}

# ============================================================
# INSTALL ARGOCD
# ============================================================

install_argocd() {

    title "Installing ArgoCD"

    require_file "$ARGO_SCRIPT"

    chmod +x "$ARGO_SCRIPT"

    bash "$ARGO_SCRIPT"

}

# ============================================================
# WAIT FOR NAMESPACE
# ============================================================

wait_namespace() {

    title "Waiting for argocd namespace"

    until kubectl get ns argocd >/dev/null 2>&1
    do
        sleep 5
    done

    success "Namespace Ready"

}

# ============================================================
# WAIT FOR ARGOCD
# ============================================================

wait_argocd() {

    title "Waiting for ArgoCD"

    kubectl rollout status \
        deployment/argocd-server \
        -n argocd \
        --timeout=600s

    kubectl wait \
        --for=condition=Ready \
        pod \
        --all \
        -n argocd \
        --timeout=600s

    success "ArgoCD Ready"

}

# ============================================================
# VERIFY ARGOCD
# ============================================================

verify_argocd() {

    title "Verifying Installation"

    kubectl get pods -n argocd

    kubectl get svc -n argocd

    kubectl get applications -n argocd || true

}
# ============================================================
# SHOW ADMIN PASSWORD
# ============================================================

show_password() {

    title "ArgoCD Admin Password"

    if kubectl get secret argocd-initial-admin-secret \
        -n argocd >/dev/null 2>&1
    then

        PASSWORD=$(kubectl \
            -n argocd \
            get secret argocd-initial-admin-secret \
            -o jsonpath="{.data.password}" | base64 -d)

        echo ""
        echo "Username : admin"
        echo "Password : ${PASSWORD}"
        echo ""

    else

        warning "Admin password not available yet."

    fi

}

# ============================================================
# GITOPS STATUS
# ============================================================

sync_status() {

    title "GitOps Status"

    kubectl get applications -n argocd || true

    echo ""

    kubectl get applicationsets -n argocd || true

}

# ============================================================
# VERIFY PLATFORM COMPONENTS
# ============================================================

verify_components() {

    title "Platform Components"

    COMPONENTS=(
        argocd
        kube-system
        monitoring
        external-secrets
        kyverno
        falco
        trivy-system
        observability
        karpenter
    )

    for ns in "${COMPONENTS[@]}"
    do

        if kubectl get ns "$ns" >/dev/null 2>&1
        then
            success "$ns"

            kubectl get pods -n "$ns" \
                --no-headers 2>/dev/null || true

        else

            warning "$ns not installed"

        fi

        echo ""

    done

}

# ============================================================
# VERIFY CLUSTER
# ============================================================

verify_platform() {

    title "Cluster Status"

    kubectl get nodes

    echo ""

    kubectl get pods -A

    echo ""

    kubectl get svc -A

    echo ""

    kubectl get ingress -A || true

}

# ============================================================
# PORT FORWARD INFO
# ============================================================

show_dashboard_info() {

    title "Dashboards"

    cat <<EOF

ArgoCD

kubectl port-forward svc/argocd-server \
-n argocd 8080:443

https://localhost:8080

---------------------------------------

Grafana

kubectl port-forward svc/grafana \
-n monitoring 3000:80

http://localhost:3000

---------------------------------------

Prometheus

kubectl port-forward svc/prometheus-server \
-n monitoring 9090:80

http://localhost:9090

EOF

}

# ============================================================
# NEXT STEPS
# ============================================================

print_next_steps() {

cat <<EOF

==================================================

Bootstrap Completed Successfully

Next Commands

make verify

make health

make dashboard

make logs

make release

==================================================

EOF

}

# ============================================================
# MAIN
# ============================================================

main() {

    start_timer

    doctor

    update_kubeconfig

    verify_cluster

    install_argocd

    wait_namespace

    wait_argocd

    verify_argocd

    show_password

    sync_status

    verify_components

    verify_platform

    show_dashboard_info

    end_timer

    print_next_steps

}

main "$@"