AWS_PROFILE ?= ca2
CLUSTER_CONFIG := eks/cluster.yaml

cluster-up:
	AWS_PROFILE=$(AWS_PROFILE) eksctl create cluster -f $(CLUSTER_CONFIG)

cluster-setup:
	AWS_PROFILE=$(AWS_PROFILE) ./scripts/setup-cluster.sh

cluster-down:
	AWS_PROFILE=$(AWS_PROFILE) eksctl delete cluster -f $(CLUSTER_CONFIG) --wait

cluster-status:
	AWS_PROFILE=$(AWS_PROFILE) eksctl get cluster --region us-east-2
	kubectl get nodes -o wide

deploy:
	kubectl apply -f base/namespace.yaml
	./scripts/create-secrets.sh
	kubectl apply -f mongodb/storageclass.yaml
	kubectl apply -f mongodb/service.yaml
	kubectl apply -f mongodb/statefulset.yaml
	kubectl apply -f kafka/service.yaml
	kubectl apply -f kafka/statefulset.yaml
	kubectl apply -f processor/configmap.yaml
	kubectl apply -f processor/service.yaml
	kubectl apply -f processor/deployment.yaml
	kubectl apply -f producer/configmap.yaml
	kubectl apply -f producer/deployment.yaml
	kubectl apply -f network/network-policy.yaml
	kubectl apply -f rbac/processor-rbac.yaml
	kubectl apply -f scaling/producer-hpa.yaml

status:
	kubectl get all -n ca2
	kubectl get pvc -n ca2
	kubectl get networkpolicy -n ca2
	kubectl get hpa -n ca2

destroy:
	kubectl delete namespace ca2 --ignore-not-found
