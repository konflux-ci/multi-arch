# multi-arch
Putting together a multi-arch configuration for Konflux

Following are steps for setting up OpenShift Sandboxed Containers on a ROSA
cluster with multiple cloud providers.

## 1. Install the operator

As described [here][op-inst].

[op-inst]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#installing-operator-web-console_aws-web

## 2. Setup a security group for peer-POD VMs.

From the AWS EC2 console check the security group for one of the cluster worker
nodes. It should have a name like `1234567890abcdef-12345-node`.

Create a new security group called "kata-peer-pods`. Make sure you place it in
the same VPC as the rest of the cluster. Add inbound rules to the group to allow
traffic going into TCP ports 15150 and 9000 from the worker nodes security group
we found earlier. Leave the default outbound rule allowing all outbound traffic
in place.

## 3. Setup credentials for running peer-POD VMs

From the AWS IAM console create a new user called `kata-peer-pods`. Fer setting
permissions, select the "Attach policies directly" option and select the 
"AmazonEC2FullAccess" policy.

After creating the user:
1. Click on it in the IAM users page to go into its management screen
2. Select the "Security credentials" tab
3. Click on "Create access key"
4. Select the "Other" option and click on "Next"
5. Provide a description for your access key and click "Create access key".
6. Store the access key details that now appear on screen in a file called 
   `_aws_peer_pods_creds.txt` with the following structure.

    ```
    AWS_ACCESS_KEY_ID=<the access key ID>
    AWS_SECRET_ACCESS_KEY=<the secret access key>
    ```
    The `.gitignore` file is setup in this repo to prevent committing this file.

The credentials file we created can now be used with the following command to 
create the secret we need in the cluster.

```
oc create secret generic \
    -n openshift-sandboxed-containers-operator \
    peer-pods-secret \
    --from-env-file=_aws_peer_pods_creds.txt
```
## 4. Create a subnet

From the AWS VPS console create a new subnet called `kata-peer-pods` within the 
same VPC as the cluter.

Make sure the routing table for the subnet is configured with a default route 
that goes to the NAT gateway so that peer-POD VMs can access external services.

## 5. Setup the peer-PODs config map

Follow instructions [here][make-cm] to create the `peer-pods-cm` config map.

[make-cm]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#creating-peer-pods-config-map_aws-web

Leave the `PODVM_AMI_ID` field unspecified.

Fro the `AWS_SUBNET_ID` value, specify the ID of the subnet you created in 
section #4 above.

For the `AWS_SG_IDS` value, specify the ID of the security group you created in 
section #2 above.

## 6. Create the KataConfig resource

AS described [here][kcfg].

[kcfg]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#creating-kataconfig-cr-web_aws-web

## 7. Run a test workload in AWS

Make sure you are in the "default" project or some other non-system project:

```
oc project default
```

Run an interactive peer-POD with the following command:

```
oc run kata-test1 -it --rm --pod-running-timeout=15m '
    --image=registry.access.redhat.com/ubi9-micro \
    --restart=Never \
    --overrides='{"spec": {"runtimeClassName": "kata-remote"}}'
```
