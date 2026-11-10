#!/bin/sh
# Run once by the argocd-bootstrap Compose service, after all four clusters
# are up: waits for Argo CD on management, registers internal/stg/prod as
# managed clusters, then applies the root Application. From then on Argo CD
# manages everything from git.
#
# Each cluster Secret is labelled role=workload and stage=<cluster>. The
# ApplicationSets (argocd/appsets/) select clusters by those labels instead
# of hard-coding server URLs, so deploying to a new cluster is a registration
# step here, not a git edit to every ApplicationSet.
#
# Talks to each cluster over the k8s-management network by hostname, using
# the kubeconfig each k3s server writes (shared via the *-kubeconfig
# volumes). --server overrides the 127.0.0.1 baked into that file; TLS still
# verifies because each server has --tls-san=k3s-<cluster>.
set -e

# The default path uses this repository on GitHub. The local-only Compose
# profile overrides these values to point at the Gitea service instead.
GITOPS_REPO_URL="${GITOPS_REPO_URL:-https://github.com/glexposito/local-gitops-promotion-lab.git}"
KARGO_GIT_REPO_URL="${KARGO_GIT_REPO_URL:-git@github.com:glexposito/local-gitops-promotion-lab.git}"

management() { kubectl --kubeconfig=/kubeconfigs/management/k3s.yaml --server=https://k3s-management:6443 "$@"; }

echo "Waiting for Argo CD..."
for workload in deployment/argocd-server deployment/argocd-repo-server \
  deployment/argocd-applicationset-controller statefulset/argocd-application-controller; do
  management -n argocd wait --for=create "$workload" --timeout=600s
  management -n argocd rollout status "$workload" --timeout=300s
done

echo "Registering internal, stg, and prod as managed clusters..."
for cluster in internal stg prod; do
  remote() { kubectl --kubeconfig=/kubeconfigs/$cluster/k3s.yaml --server=https://k3s-$cluster:6443 "$@"; }
  # The token comes from manifests/<cluster>/10-argocd-manager.yaml.
  remote -n kube-system wait --for=create secret/argocd-manager-token --timeout=120s
  remote -n kube-system wait --for=jsonpath='{.data.token}' secret/argocd-manager-token --timeout=120s
  token=$(remote -n kube-system get secret argocd-manager-token -o jsonpath='{.data.token}' | base64 -d)
  management apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${cluster}-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    role: workload
    stage: ${cluster}
type: Opaque
stringData:
  name: ${cluster}
  server: https://k3s-${cluster}:6443
  config: |
    {"bearerToken":"${token}","tlsClientConfig":{"insecure":true}}
EOF
done

# Kargo's git write credential: the shared promotion task
# (kargo/shared/promote-kustomize-app.yaml) pushes digest commits to this
# repo. Secrets don't go in git, so it comes from a gitignored file,
# cluster/secrets/kargo-git-key (docs/kargo.md). It goes in Kargo's shared
# resources namespace, which every Kargo Project falls back to for
# credentials - one key for every app, not one per app. Created here up
# front; the Kargo chart adopts the namespace when it installs.
echo "Adding Kargo's shared git credential..."
management apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: kargo-shared-resources
EOF
if [ -n "${KARGO_GIT_USERNAME:-}" ] && [ -n "${KARGO_GIT_PASSWORD:-}" ]; then
  management -n kargo-shared-resources create secret generic gitops-poc-git \
    --from-literal=repoURL="$KARGO_GIT_REPO_URL" \
    --from-literal=username="$KARGO_GIT_USERNAME" \
    --from-literal=password="$KARGO_GIT_PASSWORD" \
    --dry-run=client -o yaml \
    | management label --local -f - kargo.akuity.io/cred-type=git -o yaml \
    | management apply -f -
elif [ -s /secrets/kargo-git-key ]; then
  management -n kargo-shared-resources create secret generic gitops-poc-git \
    --from-literal=repoURL="$KARGO_GIT_REPO_URL" \
    --from-file=sshPrivateKey=/secrets/kargo-git-key \
    --dry-run=client -o yaml \
    | management label --local -f - kargo.akuity.io/cred-type=git -o yaml \
    | management apply -f -
else
  echo "No Kargo git credential - add cluster/secrets/kargo-git-key or configure KARGO_GIT_USERNAME and KARGO_GIT_PASSWORD."
fi

echo "Applying the root Application..."
sed "s|https://github.com/glexposito/local-gitops-promotion-lab.git|$GITOPS_REPO_URL|g" /argocd/root-app.yaml \
  | management apply -n argocd -f -
echo "Managed clusters: internal, stg, prod. Argo CD UI: https://localhost:9000 (admin/123)"
