auth_to_k8s() {
    print_info "Generating kubeconfig to authenticate with EKS cluster..."
    # To be able to interact with the Kubernetes cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the Azure CLI can generate for us and kubectl can use.
    # Ensure we've got a path setup for the kubeconfig file:
    export KUBECONFIG=$(pwd)/kubeconfig
    print_info "Kubeconfig path: $KUBECONFIG"
    rm -f $KUBECONFIG
    # Retrieve the credentials for the cluster using the Azure CLI:
    az aks get-credentials --resource-group "$NAME" --name "$NAME"
    # Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
    print_info "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
    kubectl cluster-info
    kubectl get ns
}