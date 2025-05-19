from diagrams import Diagram, Cluster, Node
from diagrams.k8s.podconfig import CM, Secret
from diagrams.k8s.storage import PV, PVC
from diagrams.k8s.compute import Deploy, Pod, RS
from diagrams.k8s.clusterconfig import HPA
from diagrams.k8s.network import SVC, Ep, Ing

with Diagram(
    "Coffee Shop Kubernetes Resources",
    show=False,
    graph_attr={ "rankdir": "LR" }
):
    with Cluster("Namespace: coffeeshop"):

        # ConfigMap
        cfg = CM("coffeeshop-config")

        # Certificates / cert-manager
        cert_mgr       = Node("coffee-shop-cert-manager")
        cluster_issuer = Node("letsencrypt-prod (ClusterIssuer)")
        cert           = Node("meraviglioso-id-vn-tls (Certificate)")

        # Storage
        pv  = PV("rabbitmq-local-pv")
        pvc = PVC("rabbitmq-data-pvc")

        # Secrets
        docker_secret   = Secret("docker-secret")
        postgres_secret = Secret("postgres-secret")
        rabbitmq_secret = Secret("rabbitmq-secret")

        # Deployments → ReplicaSets → Pods + HPAs
        apps = {}
        for name in ["barista","counter","kitchen","product","proxy","rabbitmq","web"]:
            with Cluster(name.capitalize()):
                deploy = Deploy(f"{name}-deploy")
                rs     = RS(f"{name}-rs")
                pod    = Pod(f"{name}-pod")
                hpa    = HPA(f"{name}-hpa")

                deploy >> rs >> pod
                hpa << deploy

                apps[name] = pod

        # Services → Endpoints
        for name, pod in apps.items():
            svc = SVC(f"{name}-svc")
            ep  = Ep(f"{name}-ep")
            svc >> ep >> pod

        # Ingresses
        ing1 = Ing("proxy-ingress")
        ing2 = Ing("web-ingress")
        ing1 >> apps["proxy"]
        ing2 >> apps["web"]

    # Glue relations
    cfg >> pv >> pvc
    cert_mgr >> cluster_issuer >> cert




