apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: trading-system-${environment}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  # Source: Config repository
  source:
    repoURL: '${config_repo_url}'
    targetRevision: ${target_revision}
    path: overlays/${environment}/app-of-apps
  
  # Destination: Current cluster
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  
  # Sync policy: Automatic with self-healing
  syncPolicy:
    automated:
      prune: true        # Remove resources when removed from Git
      selfHeal: true     # Automatically sync if cluster state drifts
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
