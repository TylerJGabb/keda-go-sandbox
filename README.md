# RabbitMQ consumer and sender

A simple docker container that will receive messages from a RabbitMQ queue and scale via KEDA.  The receiver will receive a single message at a time (per instance), and sleep for 1 second to simulate performing work.  When adding a massive amount of queue messages, KEDA will drive the container to scale out according to the event source (RabbitMQ).

## Pre-requisites

* Kubernetes cluster
* [KEDA 2.0 installed](https://keda.sh/docs/deploy/) on the cluster

## Setup

### Creating a RabbitMQ queue

#### [Install Helm](https://helm.sh/docs/using_helm/)

#### Install RabbitMQ via Helm

Since the Helm stable repository was migrated to the [Bitnami Repository](https://github.com/helm/charts/tree/master/stable/rabbitmq), add the Bitnami repo and use it during the installation:

```cli
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install rabbitmq --set auth.username=user --set auth.password=PASSWORD bitnami/rabbitmq --wait
```

#### Wait for RabbitMQ to Deploy

⚠️ Be sure to wait until the deployment has completed before continuing. ⚠️

```cli
kubectl get po

NAME         READY   STATUS    RESTARTS   AGE
rabbitmq-0   1/1     Running   0          3m3s
```

To access for outside the cluster, perform the following steps:

To Access the RabbitMQ AMQP port:
```
    echo "URL : amqp://127.0.0.1:5672/"
    kubectl port-forward --namespace default svc/rabbitmq 5672:5672
```
To Access the RabbitMQ Management interface:
```
    echo "URL : http://127.0.0.1:15672/"
    kubectl port-forward --namespace default svc/rabbitmq 15672:15672
```
### Deploying a RabbitMQ consumer

#### Deploy a consumer

```cli
kubectl apply -f deploy/deploy-consumer.yaml
```

#### Validate the consumer has deployed

```cli
kubectl get deploy
```

You should see `rabbitmq-consumer` deployment with 0 pods as there currently aren't any queue messages and for that reason it is scaled to zero.

```cli
NAME                DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rabbitmq-consumer   0         0         0            0           3s
```

[This consumer](https://github.com/kedacore/sample-go-rabbitmq/blob/master/cmd/receive/receive.go) is set to consume one message per instance, sleep for 1 second, and then acknowledge completion of the message.  This is used to simulate work.  The [`ScaledObject` included in the above deployment](deploy/deploy-consumer.yaml) is set to scale to a minimum of 0 replicas on no events, and up to a maximum of 30 replicas on heavy events (optimizing for a queue length of 5 message per replica).  After 30 seconds of no events the replicas will be scaled down (cooldown period).  These settings can be changed on the `ScaledObject` as needed.

### Publishing messages to the queue

#### Deploy the publisher job

The following job will publish 300 messages to the "hello" queue the deployment is listening to. As the queue builds up, KEDA will help the horizontal pod autoscaler add more and more pods until the queue is drained after about 2 minutes and up to 30 concurrent pods.  You can modify the exact number of published messages in the `deploy-publisher-job.yaml` file.

```cli
kubectl apply -f deploy/deploy-publisher-job.yaml
```

#### Validate the deployment scales

```cli
kubectl get deploy -w
```

You can watch the pods spin up and start to process queue messages.  As the message length continues to increase, more pods will be pro-actively added.  

You can see the number of messages vs the target per pod as well:

```cli
kubectl get hpa
```

After the queue is empty and the specified cooldown period (a property of the `ScaledObject`, default of 300 seconds) the last replica will scale back down to zero.

## Cleanup resources

```cli
kubectl delete job rabbitmq-publish
kubectl delete ScaledObject rabbitmq-consumer
kubectl delete deploy rabbitmq-consumer
helm delete rabbitmq
```
