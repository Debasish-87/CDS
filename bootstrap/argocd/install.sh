#!/usr/bin/env bash
# ============================================================
# Enterprise DevSecOps Platform
# ArgoCD Bootstrap Installer
# ============================================================

set -Eeuo pipefail

ARGOCD_VERSION="stable"

ARGOCD_NAMESPACE="argocd"

REPO_URL="https://github.com/Debasish-87/CDS.git"

ROOT_APP_NAME="dev-root"

ARGO_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# ============================================================
# LOGGING
# ============================================================

title(){

echo
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}$1${NC}"
echo -e "${BLUE}=================================================${NC}"
echo

}

success(){

echo -e "${GREEN}✔ $1${NC}"

}

warning(){

echo -e "${YELLOW}⚠ $1${NC}"

}

error(){

echo -e "${RED}✖ $1${NC}"

}

die(){

error "$1"

exit 1

}

# ============================================================
# REQUIREMENTS
# ============================================================

require(){

command -v "$1" >/dev/null \
|| die "$1 not installed"

}

doctor(){

title "Checking Requirements"

require kubectl

require helm

require git

require curl

require base64

success "All requirements satisfied"

}

# ============================================================
# NAMESPACE
# ============================================================

create_namespace(){

title "Creating Namespace"

kubectl create namespace \
"${ARGOCD_NAMESPACE}" \
--dry-run=client \
-o yaml \
| kubectl apply -f -

success "Namespace Ready"

}

# ============================================================
# INSTALL
# ============================================================

install_argocd(){

title "Installing ArgoCD"

kubectl apply \
--server-side \
--force-conflicts \
-n "${ARGOCD_NAMESPACE}" \
-f "${ARGO_MANIFEST}"

success "Installation Started"

}

# ============================================================
# WAIT CRDS
# ============================================================

wait_crds(){

title "Waiting For CRDs"

until kubectl get crd applications.argoproj.io >/dev/null 2>&1
do

sleep 5

echo "Waiting..."

done

success "CRDs Ready"

}

# ============================================================
# WAIT DEPLOYMENTS
# ============================================================

wait_deployments(){

title "Waiting Deployments"

DEPLOYMENTS=(

argocd-application-controller

argocd-applicationset-controller

argocd-dex-server

argocd-notifications-controller

argocd-redis

argocd-repo-server

argocd-server

)

for deployment in "${DEPLOYMENTS[@]}"
do

echo "Waiting ${deployment}"

kubectl rollout status deployment/${deployment} \
-n "${ARGOCD_NAMESPACE}" \
--timeout=600s || true

done

success "Deployments Ready"

}

# ============================================================
# WAIT PODS
# ============================================================

wait_pods(){

title "Waiting Pods"

kubectl wait \
--for=condition=Ready \
pod \
--all \
-n "${ARGOCD_NAMESPACE}" \
--timeout=600s

success "Pods Ready"

}

# ============================================================
# PATCH ARGOCD SERVER
# ============================================================

patch_server() {

    title "Patching ArgoCD Server"

    if kubectl get deployment argocd-server \
        -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1
    then

        kubectl patch deployment argocd-server \
            -n "${ARGOCD_NAMESPACE}" \
            --type='json' \
            -p='[
                {
                    "op":"add",
                    "path":"/spec/template/spec/containers/0/args/-",
                    "value":"--insecure"
                }
            ]' || true

        kubectl rollout status deployment/argocd-server \
            -n "${ARGOCD_NAMESPACE}" \
            --timeout=300s

        success "Server Patched"

    fi

}

# ============================================================
# ROOT APPLICATION
# ============================================================

create_root_app() {

    title "Creating Root GitOps Application"

cat <<EOF | kubectl apply -f -

apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: ${ROOT_APP_NAME}
  namespace: ${ARGOCD_NAMESPACE}

spec:

  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: gitops-repo

  destination:
    server: https://kubernetes.default.svc
    namespace: ${ARGOCD_NAMESPACE}

  syncPolicy:

    automated:

      prune: true
      selfHeal: true

    syncOptions:

    - CreateNamespace=true

EOF

    success "Root Application Created"

}

# ============================================================
# WAIT ROOT APP
# ============================================================

wait_root_app() {

    title "Waiting Root Application"

    for i in {1..60}
    do

        if kubectl get application \
            "${ROOT_APP_NAME}" \
            -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1
        then

            success "Root Application Ready"

            return

        fi

        sleep 5

    done

    warning "Root App not Ready"

}

# ============================================================
# SHOW PASSWORD
# ============================================================

show_password() {

    title "Admin Password"

    PASSWORD=$(
        kubectl \
        -n argocd \
        get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" \
        | base64 -d
    )

    echo ""
    echo "Username : admin"
    echo "Password : ${PASSWORD}"
    echo ""

}

# ============================================================
# VERIFY
# ============================================================

verify() {

    title "Verification"

    kubectl get ns

    echo ""

    kubectl get pods -A

    echo ""

    kubectl get svc -A

    echo ""

    kubectl get applications -n argocd || true

}

# ============================================================
# DASHBOARD INFO
# ============================================================

dashboard() {

cat <<EOF

====================================================

ArgoCD

kubectl port-forward \
svc/argocd-server \
-n argocd \
8080:443

https://localhost:8080

====================================================

Grafana

kubectl port-forward \
svc/grafana \
-n monitoring \
3000:80

http://localhost:3000

====================================================

Prometheus

kubectl port-forward \
svc/prometheus-server \
-n monitoring \
9090:80

http://localhost:9090

====================================================

EOF

}

# ============================================================
# SUMMARY
# ============================================================

summary() {

cat <<EOF

====================================================

Bootstrap Completed Successfully

Next Commands

make verify

make health

make dashboard

make logs

make release

====================================================

EOF

}

# ============================================================
# MAIN
# ============================================================

main() {

    doctor

    create_namespace

    install_argocd

    wait_crds

    wait_deployments

    wait_pods

    patch_server

    create_root_app

    wait_root_app

    show_password

    verify

    dashboard

    summary

}

main "$@"
