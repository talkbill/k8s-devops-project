#!/bin/bash
# Complete cleanup script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}This will destroy ALL resources including the EKS cluster.${NC}"
read -p "Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
  echo -e "${YELLOW}Cancelled.${NC}"
  exit 0
fi

echo -e "${YELLOW}Removing ArgoCD Application...${NC}"
# Delete the Application first (before namespace)
kubectl patch application k8s-devops-project -n argocd \
  --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]' \
  --ignore-not-found=true 2>/dev/null || true
kubectl delete application k8s-devops-project -n argocd \
  --ignore-not-found=true 2>/dev/null || true

echo -e "${YELLOW}Uninstalling ArgoCD Helm release...${NC}"
helm uninstall argocd -n argocd --ignore-not-found 2>/dev/null || true

echo -e "${YELLOW}Deleting ArgoCD CRDs...${NC}"
kubectl delete crd applications.argoproj.io appprojects.argoproj.io \
  --ignore-not-found=true 2>/dev/null || true

echo -e "${YELLOW}Deleting namespaces...${NC}"
# Delete devops-app first (no finalizers typically)
kubectl delete namespace devops-app --ignore-not-found=true 2>/dev/null || true

# Then monitoring
kubectl delete namespace monitoring --ignore-not-found=true 2>/dev/null || true

# Finally argocd (after removing finalizers)
kubectl patch namespace argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
kubectl delete namespace argocd --ignore-not-found=true 2>/dev/null || true

echo -e "${YELLOW}Waiting for namespace cleanup...${NC}"
sleep 10

# Let Terraform destroy everything else
echo -e "${YELLOW}Running terraform destroy...${NC}"
cd "$(dirname "$0")/../terraform"
terraform destroy -auto-approve

echo -e "${GREEN}Teardown complete.${NC}"