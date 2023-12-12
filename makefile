TAG = 1.0.0
IMAGE_NAME = sample-go-rmq

.PHONY: build
build:
	docker build -t $(IMAGE_NAME):$(TAG) .


.PHONY: load
load:
	minikube image load $(IMAGE_NAME):$(TAG)

.PHONY: consumer
consumer:
	kubectl apply -f k8s-manifests/deploy-consumer.yaml

.PHONY: producer
producer:
	kubectl apply -f k8s-manifests/deploy-publisher-job.yaml

.PHONY: cluster
cluster:
	minikube delete
	minikube start

	helm repo add kedacore https://kedacore.github.io/charts
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update

	helm install keda kedacore/keda --namespace keda --create-namespace
	helm install --name rabbitmq --set auth.username=user --set auth.password=PASSWORD bitnami/rabbitmq --wait
