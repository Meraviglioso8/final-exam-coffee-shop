from diagrams import Diagram, Cluster
from diagrams.k8s.group import NS
from diagrams.k8s.podconfig import CM, Secret
from diagrams.k8s.storage import PV, PVC
from diagrams.k8s.compute import Deploy, Pod, RS, Job
from diagrams.k8s.clusterconfig import HPA
from diagrams.k8s.network import SVC, Ep, Ing
from diagrams.k8s.ecosystem import Helm, Kustomize
from diagrams.k8s.others import CRD
from diagrams import Node

with Diagram("Coffee Shop Full Stack Deployment", show=False, graph_attr={"rankdir": "LR"}):

    # ArgoCD Namespace
    with Cluster("argocd"):
        kusto = Kustomize("Kustomization\ninstall.yaml + patches")
        argocd_cm = CM("argocd-cm")
        sops_gpg = Secret("sops-gpg")
        with Cluster("repo-server"):
            repo_dep = Deploy("argocd-repo-server")
            repo_rs = RS("repo-server-rs")
            repo_pod = Pod("repo-server-pod")
            init1 = Job("install-ksops")
            init2 = Job("import-gpg-key")
            repo_dep >> [init1, init2] >> repo_rs >> repo_pod
        kusto >> argocd_cm >> sops_gpg >> repo_dep

    # CoffeeShop Namespace
    with Cluster("coffeeshop"):
        cfg = CM("coffeeshop-config")
        cert_mgr = Node("cert-manager")
        cluster_issuer = CRD("letsencrypt-prod")
        cert = CRD("meraviglioso-id-vn-tls")
        pv = PV("rabbitmq-local-pv")
        pvc = PVC("rabbitmq-data-pvc")
        docker_sec = Secret("docker-secret")
        pg_sec = Secret("postgres-secret")
        rmq_sec = Secret("rabbitmq-secret")

        apps = {}
        for name in ["barista","counter","kitchen","product","proxy","rabbitmq","web"]:
            with Cluster(name):
                dep = Deploy(f"{name}-deploy")
                rs = RS(f"{name}-rs")
                pod = Pod(f"{name}-pod")
                hpa = HPA(f"{name}-hpa")
                dep >> rs >> pod
                dep >> hpa
                apps[name] = pod

        for name, pod in apps.items():
            svc = SVC(f"{name}-svc")
            ep = Ep(f"{name}-ep")
            svc >> ep >> pod

        ing1 = Ing("proxy-ingress")
        ing2 = Ing("web-ingress")
        ing1 >> apps["proxy"]
        ing2 >> apps["web"]

        cfg >> pv >> pvc
        cert_mgr >> cluster_issuer >> cert

    # ingress-nginx
    with Cluster("ingress-nginx"):
        chart_ing = Helm("ingress-nginx")
        ing_dep = Deploy("nginx-controller")
        ing_pod = Pod("nginx-controller-pod")
        sm = CRD("ServiceMonitor")
        chart_ing >> ing_dep >> ing_pod >> sm

    # metrics-server
    with Cluster("kube-system"):
        chart_ms = Helm("metrics-server")
        ms_dep = Deploy("metrics-server")
        ms_pod = Pod("metrics-server-pod")
        chart_ms >> ms_dep >> ms_pod

    # monitoring namespace
    with Cluster("monitoring"):
        chart_pps = Helm("kube-prometheus-stack")
        op = Deploy("prometheus-operator")
        prom = Pod("prometheus-server")
        am = Pod("alertmanager")
        gf = Pod("grafana")
        ks = Pod("kube-state-metrics")
        ne1 = Pod("node-exporter-1")
        ne2 = Pod("node-exporter-2")
        svc_gf = SVC("grafana-svc")
        pv_gf = PV("grafana-pv")

        chart_pps >> op
        op >> [prom, am, gf, ks, ne1, ne2]
        gf >> svc_gf >> pv_gf
