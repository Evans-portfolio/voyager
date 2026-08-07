# Terraform runs on voyager, which cannot reach aks-prod's private API server
# directly. Before plan/apply on this stack, open a tunnel through the jumpbox:
#   ssh -f -N -L <aks_tunnel_local_port>:<privateFqdn>:443 -i ~/.ssh/jumpbox_rsa azureuser@<jumpbox public IP>
# privateFqdn comes from: az aks show -g rg-prod -n aks-prod --query privateFqdn -o tsv
#
# This is a second, independent ArgoCD instance living inside aks-prod itself,
# not the same one that manages test. That was a deliberate pivot, not an
# oversight - see the README engineering notes for the full reasoning. In
# short: having test's ArgoCD manage prod cross-VNet requires its pods to
# reach prod's private API directly, which hit a real, well-diagnosed
# networking wall (NSG rules confirmed correct, DNS confirmed resolving,
# peering allow_forwarded_traffic fixed, but packets still silently dropped
# somewhere beyond the pod - confirmed via tcpdump showing SYNs leaving the
# pod with zero response). Running ArgoCD per-cluster avoids that entire
# class of problem: each cluster's ArgoCD only ever talks to its own local
# Kubernetes API (https://kubernetes.default.svc), no cross-VNet GitOps
# control-plane traffic needed at all.
locals {
  admin_kubeconfig    = yamldecode(file(var.admin_kubeconfig_path))
  aks_cluster         = local.admin_kubeconfig.clusters[0].cluster
  aks_user            = local.admin_kubeconfig.users[0].user
  aks_server_hostname = trimsuffix(trimprefix(local.aks_cluster.server, "https://"), ":443")
}

provider "kubernetes" {
  host                   = "https://127.0.0.1:${var.aks_tunnel_local_port}"
  tls_server_name        = local.aks_server_hostname
  cluster_ca_certificate = base64decode(local.aks_cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.aks_user["client-certificate-data"])
  client_key             = base64decode(local.aks_user["client-key-data"])
}

provider "helm" {
  kubernetes {
    host                   = "https://127.0.0.1:${var.aks_tunnel_local_port}"
    tls_server_name        = local.aks_server_hostname
    cluster_ca_certificate = base64decode(local.aks_cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.aks_user["client-certificate-data"])
    client_key             = base64decode(local.aks_user["client-key-data"])
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.2.1" # pinned to match the version actually deployed on test, not just the same unpinned "latest" test happened to resolve to
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # No tools/Spot nodeSelector here, unlike test's argocd.tf - prod's tools
  # pool is at 0 nodes (quota-conserved, same as test's monitoring pool).
  # This schedules onto the main pool instead, which is untainted and
  # already where prod's backend/frontend land by the base chart's own
  # default nodeSelector.

  # Dedicated low-privilege account for GitLab CI, scoped to sync/get on
  # backend-prod, frontend-prod, and app-of-apps-prod only - not admin.
  # app-of-apps-prod access is required, not optional: it is the manual-
  # sync-only root that renders backend-prod/frontend-prod's Application
  # CRs, including the baked-in image tag from values-backend.yaml. Since
  # it never auto-syncs (deliberate - prod stays gated behind approval,
  # unlike test'''s auto-synced root), syncing only the child apps without
  # it left their spec.source.helm.values permanently frozen at whatever
  # tag was baked in at the very first deploy - every subsequent sync
  # trivially "succeeded" against that same stale spec, never actually
  # deploying new code. Mirrors the intent of
  # test's existing gitlab-ci AppProject role (argocd/test/applications/
  # templates/argocd-project.yaml), just via a local account instead of a
  # project role, since this instance's "default" AppProject is separate
  # from test's. policy.default stays empty (deny by default) so gitlab-ci
  # gets exactly what's granted below and nothing else - confirmed admin
  # itself is exempt from RBAC policy in ArgoCD, so this can't lock out
  # cluster operators.
  #
  # "login" capability (in addition to apiKey): deploy-prod logs in fresh
  # each run instead of using a long-lived stored token. A long-lived
  # apiKey token (and, separately, test's long-lived project-role token)
  # was observed going invalid ("token signature is invalid") within
  # roughly 15-40 minutes of being issued, on both clusters, with no pod
  # restart and no change to the underlying signing key - root cause not
  # pinned down. Logging in immediately before use sidesteps it rather
  # than depending on a token surviving the gap between CI runs.
  # server.service: internal LB, same reasoning as test's argocd.tf -
  # argocd-server gets a private IP inside vnet-prod, reachable from the
  # jumpbox/VNet only, never a public one. Distinct from ingress-nginx's
  # external LB (public, serves the sample-app to the internet).
  values = [
    <<-EOT
    configs:
      cm:
        accounts.gitlab-ci: apiKey, login
      rbac:
        policy.default: ""
        policy.csv: |
          p, gitlab-ci, applications, get, default/backend-prod, allow
          p, gitlab-ci, applications, sync, default/backend-prod, allow
          p, gitlab-ci, applications, get, default/frontend-prod, allow
          p, gitlab-ci, applications, sync, default/frontend-prod, allow
          p, gitlab-ci, applications, get, default/app-of-apps-prod, allow
          p, gitlab-ci, applications, sync, default/app-of-apps-prod, allow
    server:
      service:
        type: LoadBalancer
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    EOT
  ]
}
