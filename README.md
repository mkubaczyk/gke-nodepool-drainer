# GKE Node pool drainer

This script cordons defined node pools, scales up defined resources (so there's no problem with Pod disruption budget etc.)
and then drains the nodes, so the resources schedule themselves on the node pools not covered by the script's run. 
Then drained node pools (since they are empty) can be destroyed.

## How to run

```
./drain.sh <parameters>
```

where parameters are:

```
--dry-run
Prints command that will be run instead of really running it

--nodepools=nodepool1,nodepool2
String with comma separated nodepools names to be drained, where by nodepool name we mean
cloud.google.com/gke-nodepool node's annotation value 


--scale-file=<path-to-file>
String with absolute path to file, that contains the resources to be scaled up before draining in content's format of one per line:
kind,namespace,name
example:
deployment,haproxy-ingress,haproxy-ingress-default-backend
deployment,haproxy-ingress,haproxy-ingress-controller
deployment,haproxy-ingress,haproxy-ingress-internal-default-backend
deployment,haproxy-ingress,haproxy-ingress-internal-controller
statefulset,prometheus,prometheus-prometheus-prometheus-oper-prometheus
statefulset,prometheus,alertmanager-prometheus-prometheus-oper-alertmanager

```

Example run:

```
./drain.sh --scale-file=/Users/username/conf/scalable --nodepools=stable,preempt --dry-run
```
