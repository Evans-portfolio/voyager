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

resource "kubernetes_manifest" "app_of_apps_test" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps-test"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitlab_repo_url
        targetRevision = "main"
        path           = "argocd/test/applications"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.gitlab_repo,
  ]
}
