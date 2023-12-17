# RabbitMQ consumer and sender

# TL;DR;
1. `make cluster`
2. `make build`
3. `make load`
4. `make consumer`
5. `make producer`
6. http://localhost:15672 (user/PASSWORD)
7. :eyes:

A simple docker container that will receive messages from a RabbitMQ queue and scale via KEDA.  The receiver will receive a single message at a time (per instance), and sleep for 1 second to simulate performing work.  When adding a massive amount of queue messages, KEDA will drive the container to scale out according to the event source (RabbitMQ).

# Running This Sandbox
## 1. Install [Minikube](https://minikube.sigs.k8s.io/docs/start/)
## 2. Install [KEDA](https://keda.sh/docs/2.12/deploy/#helm)
## 3. Install Rabbit MQ
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install rabbitmq --set auth.username=user --set auth.password=PASSWORD bitnami/rabbitmq --wait
```

Note the output from the above command, you will need it for following steps.

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
## 4. ⚠️ Wait for RabbitMQ to Deploy ⚠️
```sh
kubectl get po

NAME         READY   STATUS    RESTARTS   AGE
rabbitmq-0   1/1     Running   0          3m3s
```
## 5. Build and Load the Docker Image
```sh
make TAG=vx.y.z build load
```
## 6. Deploy a consumer
```sh
kubectl apply -f deploy/deploy-consumer.yaml
```
## 7. Validate the consumer has deployed
```sh
kubectl get deploy
```
You should see `rabbitmq-consumer` deployment with 0 pods as there currently aren't any queue messages and for that reason it is scaled to zero.
```sh
NAME                DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rabbitmq-consumer   0         0         0            0           3s
```
[This consumer](./receive/receive.go) is set to consume one message per instance, sleep for 1 second, and then acknowledge completion of the message.  This is used to simulate work.  The [`ScaledObject` included in the above deployment](deploy/deploy-consumer.yaml) is set to scale to a minimum of 0 replicas on no events, and up to a maximum of 30 replicas on heavy events (optimizing for a queue length of 5 message per replica).  After 30 seconds of no events the replicas will be scaled down (cooldown period).  These settings can be changed on the `ScaledObject` as needed.

## 8. Deploy the publisher job

```sh
kubectl apply -f deploy/deploy-publisher-job.yaml
```

- [The sender](./send/send.go) will publish an arbitrary number of messages to the queue. Note the expected command line arguments
- [The Publishing Job](./deploy/deploy-publisher-job.yaml) job will publish 900 messages to the "hello" queue the deployment is listening to. As the queue builds up, KEDA will help the horizontal pod autoscaler add more and more pods until the queue is drained after about 2 minutes and up to 30 concurrent pods.  You can modify the exact number of published messages in the `deploy-publisher-job.yaml` file.

## Validate the deployment scales

```sh
kubectl get deploy -w
```

You can watch the pods spin up and start to process queue messages.  As the message length continues to increase, more pods will be pro-actively added.  

You can see the number of messages vs the target per pod as well:

```sh
kubectl get hpa
```

After the queue is empty and the specified cooldown period (a property of the `ScaledObject`, default of 300 seconds) the last replica will scale back down to zero.

## Cleanup resources

```sh
kubectl delete job rabbitmq-publish
kubectl delete ScaledObject rabbitmq-consumer
kubectl delete deploy rabbitmq-consumer
helm delete rabbitmq
```
