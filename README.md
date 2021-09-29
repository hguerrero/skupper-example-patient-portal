# Patient Portal with PostgreSQL and Skupper

[![main](https://github.com/ssorj/skupper-example-patient-portal/actions/workflows/main.yaml/badge.svg)](https://github.com/ssorj/skupper-example-patient-portal/actions/workflows/main.yaml)

#### A simple database-backed web application that runs in the public cloud but keeps its data in a private database

This example is part of a [suite of examples][examples] showing the
different ways you can use [Skupper][website] to connect services
across cloud providers, data centers, and edge sites.

[website]: https://skupper.io/
[examples]: https://skupper.io/examples/index.html

#### Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Step 1: Configure separate console sessions](#step-1-configure-separate-console-sessions)
* [Step 2: Access your clusters](#step-2-access-your-clusters)
* [Step 3: Set up your namespaces](#step-3-set-up-your-namespaces)
* [Step 4: Install Skupper in your namespaces](#step-4-install-skupper-in-your-namespaces)
* [Step 5: Check the status of your namespaces](#step-5-check-the-status-of-your-namespaces)
* [Step 6: Link your namespaces](#step-6-link-your-namespaces)
* [Step 7: Deploy the database](#step-7-deploy-the-database)
* [Step 8: Expose the database](#step-8-expose-the-database)
* [Step 9: Deploy the payment processor](#step-9-deploy-the-payment-processor)
* [Step 10: Expose the payment processor](#step-10-expose-the-payment-processor)
* [Step 11: Deploy the frontend](#step-11-deploy-the-frontend)
* [Step 12: Test the application](#step-12-test-the-application)
* [Cleaning up](#cleaning-up)
* [Next steps](#next-steps)

## Overview

This example is a simple database-backed web application that shows
how you can use Skupper to access a database at a remote site
without exposing it to the public internet.

It contains three services:

  * A PostgreSQL database running on a bare-metal or virtual
    machine in a private data center.

  * A payment-processing service running on Kubernetes in a private
    data center.

  * A web frontend service running on Kubernetes in the public
    cloud.  It uses the PostgreSQL database and the
    payment-processing service.

This example uses two Kubernetes namespaces, "private" and "public",
to represent the private Kubernetes cluster and the public cloud.

## Prerequisites

* The `kubectl` command-line tool, version 1.15 or later
  ([installation guide][install-kubectl])

* The `skupper` command-line tool, the latest version ([installation
  guide][install-skupper])

* Access to at least one Kubernetes cluster, from any provider you
  choose

[install-kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[install-skupper]: https://skupper.io/install/index.html

## Step 1: Configure separate console sessions

Skupper is designed for use with multiple namespaces, typically on
different clusters.  The `skupper` command uses your
[kubeconfig][kubeconfig] and current context to select the namespace
where it operates.

[kubeconfig]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

Your kubeconfig is stored in a file in your home directory.  The
`skupper` and `kubectl` commands use the `KUBECONFIG` environment
variable to locate it.

A single kubeconfig supports only one active context per user.
Since you will be using multiple contexts at once in this
exercise, you need to create distinct kubeconfigs.

Start a console session for each of your namespaces.  Set the
`KUBECONFIG` environment variable to a different path in each
session.

Console for _public_:

~~~ shell
export KUBECONFIG=~/.kube/config-public
~~~

Console for _private_:

~~~ shell
export KUBECONFIG=~/.kube/config-private
~~~

## Step 2: Access your clusters

The methods for accessing your clusters vary by Kubernetes provider.
Find the instructions for your chosen providers and use them to
authenticate and configure access for each console session.  See the
following links for more information:

* [Minikube](https://skupper.io/start/minikube.html)
* [Amazon Elastic Kubernetes Service (EKS)](https://skupper.io/start/eks.html)
* [Azure Kubernetes Service (AKS)](https://skupper.io/start/aks.html)
* [Google Kubernetes Engine (GKE)](https://skupper.io/start/gke.html)
* [IBM Kubernetes Service](https://skupper.io/start/ibmks.html)
* [OpenShift](https://skupper.io/start/openshift.html)
* [More providers](https://kubernetes.io/partners/#kcsp)

## Step 3: Set up your namespaces

Use `kubectl create namespace` to create the namespaces you wish to
use (or use existing namespaces).  Use `kubectl config set-context` to
set the current namespace for each session.

Console for _public_:

~~~ shell
kubectl create namespace public
kubectl config set-context --current --namespace public
~~~

Console for _private_:

~~~ shell
kubectl create namespace private
kubectl config set-context --current --namespace private
~~~

## Step 4: Install Skupper in your namespaces

The `skupper init` command installs the Skupper router and service
controller in the current namespace.  Run the `skupper init` command
in each namespace.

[minikube-tunnel]: https://skupper.io/start/minikube.html#running-minikube-tunnel

**Note:** If you are using Minikube, [you need to start `minikube
tunnel`][minikube-tunnel] before you install Skupper.

Console for _public_:

~~~ shell
skupper init
~~~

Console for _private_:

~~~ shell
skupper init --ingress none
~~~

Here we are using `--ingress none` in one of the namespaces simply to
make local development with Minikube easier.  (It's tricky to run two
Minikube tunnels on one host.)  The `--ingress none` option is not
required if your two namespaces are on different hosts or on public
clusters.

## Step 5: Check the status of your namespaces

Use `skupper status` in each console to check that Skupper is
installed.

Console for _public_:

~~~ shell
skupper status
~~~

Console for _private_:

~~~ shell
skupper status
~~~

You should see output like this for each namespace:

~~~
Skupper is enabled for namespace "<namespace>" in interior mode. It is not connected to any other sites. It has no exposed services.
The site console url is: http://<address>:8080
The credentials for internal console-auth mode are held in secret: 'skupper-console-users'
~~~

As you move through the steps below, you can use `skupper status` at
any time to check your progress.

## Step 6: Link your namespaces

Creating a link requires use of two `skupper` commands in conjunction,
`skupper token create` and `skupper link create`.

The `skupper token create` command generates a secret token that
signifies permission to create a link.  The token also carries the
link details.  Then, in a remote namespace, The `skupper link create`
command uses the token to create a link to the namespace that
generated it.

**Note:** The link token is truly a *secret*.  Anyone who has the
token can link to your namespace.  Make sure that only those you trust
have access to it.

First, use `skupper token create` in one namespace to generate the
token.  Then, use `skupper link create` in the other to create a link.

Console for _public_:

~~~ shell
skupper token create --token-type cert ~/secret.yaml
~~~

Console for _private_:

~~~ shell
skupper link create ~/secret.yaml
skupper link status --wait 30
~~~

If your console sessions are on different machines, you may need to
use `scp` or a similar tool to transfer the token.

## Step 7: Deploy the database

Console for _public_:

~~~ shell
docker run --detach --rm -p 5432:5432 quay.io/ssorj/patient-portal-database
~~~

## Step 8: Expose the database

Console for _public_:

~~~ shell
skupper gateway expose database localhost 5432
~~~

## Step 9: Deploy the payment processor

Console for _private_:

~~~ shell
kubectl apply -f payment-processor
~~~

## Step 10: Expose the payment processor

Console for _private_:

~~~ shell
skupper expose deployment/payment-processor --protocol http --port 8080
~~~

## Step 11: Deploy the frontend

Use `kubectl create deployment` to deploy the frontend service
in `public`.

Console for _public_:

~~~ shell
kubectl apply -f frontend
~~~

## Step 12: Test the application

Console for _public_:

~~~ shell
sleep 86400
~~~

## Cleaning up

To remove Skupper and the other resources from this exercise, use the
following commands.

Console for _public_:

~~~ shell
skupper delete
skupper gateway delete
kubectl delete service/patient-portal-frontend
kubectl delete deployment/patient-portal-frontend
~~~

Console for _private_:

~~~ shell
skupper delete
kubectl delete deployment/patient-portal-payment-processor
~~~

## Next steps

Check out the other [examples][examples] on the Skupper website.
