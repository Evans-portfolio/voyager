resource "kubernetes_secret" "gitlab_repo" {
  metadata {
    name      = "repo-server-sorcery-101"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.gitlab_repo_url
    username = "oauth2"
    password = var.gitlab_repo_token
  }
}

# This ArgoCD instance lives inside aks-prod itself, so
# "https://kubernetes.default.svc" correctly refers to prod - no remote
# cluster registration needed, unlike the abandoned cross-VNet approach.
#
# Deliberately manual-sync only (no automated block), for both this root
# app-of-apps and its children (backend-prod.yaml, frontend-prod.yaml) -
# matching the project's original design decision that prod deploys only
# through the CI approval gate, never auto-syncs. Unlike test's root, which
# is intentionally automated.
resource "kubernetes_manifest" "app_of_apps_prod" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps-prod"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitlab_repo_url
        targetRevision = "main"
        path           = "argocd/prod/applications"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.gitlab_repo,
  ]
}
