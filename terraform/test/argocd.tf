# Terraform runs on voyager, which cannot reach aks-test's private API server directly.
# Before plan/apply on this stack, open a tunnel through the jumpbox:
#   ssh -f -N -L <aks_tunnel_local_port>:<privateFqdn>:443 -i ~/.ssh/jumpbox_rsa azureuser@<jumpbox public IP>
# privateFqdn comes from: az aks show -g rg-test -n aks-test --query privateFqdn -o tsv

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
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        nodeSelector = {
          "kubernetes.azure.com/agentpool" = "tools"
        }
        tolerations = [
          {
            key      = "kubernetes.azure.com/scalesetpriority"
            operator = "Equal"
            value    = "spot"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
}
