from diagrams import Diagram, Cluster
from diagrams.k8s.ecosystem import Helm
from diagrams.k8s.compute import Pod, Deploy
from diagrams.k8s.group import NS
from diagrams import Diagram, Cluster
from diagrams.k8s.ecosystem import Helm
from diagrams.k8s.compute import Pod, Deploy
from diagrams.k8s.network import SVC
from diagrams.k8s.storage import PV
from diagrams.k8s.group import NS
from diagrams import Diagram, Cluster
from diagrams.k8s.ecosystem import Helm
from diagrams.k8s.compute import Deploy, Pod
from diagrams.k8s.others import CRD

with Diagram("Ingress-NGINX Helm Deployment", show=False, graph_attr={"rankdir": "LR"}):
    # The Helm chart installation
    chart = Helm("ingress-nginx (Helm Chart)")

    with Cluster("Namespace: ingress-nginx"):
        # Ingress-NGINX controller deployment & pod
        deploy = Deploy("ingress-nginx-controller")
        pod    = Pod("ingress-nginx-controller-pod")

        # Prometheus ServiceMonitor CRD
        sm = CRD("ServiceMonitor\nenabled via values")

        # relationships
        deploy >> pod
        pod >> sm

    # helm installs the chart in the cluster
    chart >> deploy



with Diagram("Metrics-Server Helm Deployment", show=False, graph_attr={"rankdir": "LR"}):
    chart = Helm("metrics-server (Helm Chart)")

    with Cluster("Namespace: kube-system"):
        deploy = Deploy("metrics-server-deployment")
        pod    = Pod("metrics-server-pod")

        chart >> deploy >> pod


with Diagram("kube-prometheus-stack (Monitoring)", show=False, graph_attr={"rankdir": "LR"}):
    chart = Helm("kube-prometheus-stack\n(Helm Chart)")

    with Cluster("Namespace: monitoring"):
        operator = Deploy("prometheus-operator")

        prometheus     = Pod("prometheus-server")
        alertmanager   = Pod("alertmanager")
        grafana        = Pod("grafana")
        kube_state     = Pod("kube-state-metrics")
        node_exporter1 = Pod("node-exporter-1")
        node_exporter2 = Pod("node-exporter-2")

        svc_grafana = SVC("grafana-svc")
        pv_grafana  = PV("grafana-pv")

        # chart → operator → all pods
        chart >> operator
        operator >> [prometheus, alertmanager, grafana, kube_state, node_exporter1, node_exporter2]

        # persist Grafana data
        grafana >> svc_grafana >> pv_grafana

