helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --create-namespace \
  -f values.yaml

kubectl -n argocd patch configmap argocd-cm --type merge --patch '{
  "data": {
    "configManagementPlugins": "- name: sops\n  generate:\n    command: [\"kubectl\", \"kustomize\", \"--enable-alpha-plugins\", \".\"]\n"
  }
}'

gpg --export-secret-keys --armor <your-key-id> > private.key

```
data:
  configManagementPlugins: |
    - name: sops
      generate:
        command: ["kubectl", "kustomize", "--enable-alpha-plugins", "."]

```
kubectl -n argocd create secret generic gpg-private-key --from-file=private.key

gpg --list-keys


