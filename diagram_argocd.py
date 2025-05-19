from diagrams import Diagram, Cluster
from diagrams.k8s.group import NS
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import CM, Secret
from diagrams.k8s.compute import Deploy, Pod, RS, Job
from diagrams.k8s.ecosystem import Kustomize

with Diagram("ArgoCD Kustomization & Repo-Server", show=False, graph_attr={"rankdir": "LR"}):
    ns = NS("Namespace: argocd")

    # Kustomization resource
    kustomize = Kustomize("Kustomization\ninstall.yaml\n+ patches")

    # ConfigMap for ArgoCD settings
    argocd_cm = CM("argocd-cm\n(kustomize.buildOptions)")

    # Secret holding SOPS GPG key
    sops_gpg = Secret("sops-gpg")

    # ArgoCD Repo Server Deployment
    with Cluster("argocd-repo-server Deployment"):
        deploy = Deploy("argocd-repo-server")
        rs     = RS("argocd-repo-server-rs")
        pod    = Pod("argocd-repo-server-pod")

        # Represent initContainers as Jobs
        init_ksops    = Job("init: install-ksops")
        init_import   = Job("init: import-gpg-key")

        # Volumes
        tools_vol     = Secret("emptyDir: custom-tools")
        gnupg_vol     = Secret("emptyDir: gnupg-home")

        deploy >> init_ksops
        deploy >> init_import
        deploy >> rs >> pod
        pod >> tools_vol
        pod >> gnupg_vol
        pod >> sops_gpg

    ns >> kustomize
    ns >> argocd_cm
    ns >> sops_gpg
    ns >> deploy
