# multi-arch
Putting together a multi-arch configuration for Konflux

Following are steps for setting up OpenShift Sandboxed Containers on a ROSA
cluster with multiple cloud providers.

## 1. Operator and AWS setup

### 1.1. Install the operator

As described [here][op-inst].

[op-inst]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#installing-operator-web-console_aws-web

### 1.2. Setup a security group for peer-POD VMs.

From the AWS EC2 console check the security group for one of the cluster worker
nodes. It should have a name like `1234567890abcdef-12345-node`.

Create a new security group called "kata-peer-pods`. Make sure you place it in
the same VPC as the rest of the cluster. Add inbound rules to the group to allow
traffic going into TCP ports 15150 and 9000 from the worker nodes security group
we found earlier. Leave the default outbound rule allowing all outbound traffic
in place.

### 1.3. Setup credentials for running peer-POD VMs

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
### 1.4. Create a subnet

From the AWS VPC console create a new subnet called `kata-peer-pods` within the 
same VPC as the cluter.

Make sure the routing table for the subnet is configured with a default route 
that goes to the NAT gateway so that peer-POD VMs can access external services.

### 1.5. Setup the peer-PODs config map

Follow instructions [here][make-cm] to create the `peer-pods-cm` config map.

[make-cm]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#creating-peer-pods-config-map_aws-web

Leave the `PODVM_AMI_ID` field unspecified.

Fro the `AWS_SUBNET_ID` value, specify the ID of the subnet you created in 
section #1.4 above.

For the `AWS_SG_IDS` value, specify the ID of the security group you created in 
section #1.2 above.

### 1.6. Create the KataConfig resource

AS described [here][kcfg].

[kcfg]: https://docs.redhat.com/en/documentation/openshift_sandboxed_containers/1.8/html/user_guide/deploying-aws#creating-kataconfig-cr-web_aws-web

### 1.7. Run a test workload in AWS

Make sure you are in the "default" project or some other non-system project:

```
oc project default
```

Run an interactive peer-POD with the following command:

```
oc run kata-test1 -it --rm --pod-running-timeout=15m \
    --image=registry.access.redhat.com/ubi9-micro \
    --restart=Never \
    --overrides='{"spec": {"runtimeClassName": "kata-remote"}}'
```

## 2. IBM cloud setup

This section assumes the OSC operator was already installed and configured to 
leverage AWS as described above. We will setup an additional Cloud API Adapter 
for using IBM cloud.

### 2.1. Create a VPC

From the IBM cloud main dashboard, expand the top-left menu and select
"Infrastructure". From there select "Network" on the left-hand menu and "VPCs".

Create a new "kata-peer-pods-poc" VPC with a new "kata-peer-pods-poc" resource 
group.

To help with debugging, etc. set the default security group to Allow SSH and Ping.

### 2.2. Setup credentials

From the top menu select Manage -> Access.

Generate an API key and store it in a file called `_ibm_peer_pods_creds.txt`
with the following structure:

```
IBMCLOUD_API_KEY=<key here>
```

Create a secret in the cluster from the file:

```
oc create secret generic \
    -n openshift-sandboxed-containers-operator \
    peer-pods-secret-ibm \
    --from-env-file=_ibm_peer_pods_creds.txt
```

### 2.3 Build and upload a RHEL peer-POD vm image

The following operations need to be carried out on a VM of the target
architecture.

1. Obtain RHEL activation keys by going to [console.redhat.com][con.]. Click on
   the drop-down menu near the Red Hat logo on the lop-left, select "System
   Configuration" and "Activation Keys". Make note of the organization ID
   number, then Click on "Create activation key". Fill-in all the form details
   as needed to create the key. Finally store the key in a file called 
   `_rhel_act_key_creds.txt` with contents like the following:
    ```
    ORG_ID=<the Organisation ID>
    ACTIVATION_KEY=<Activation key name>
    export ORG_ID ACTIVATION_KEY
    ```
    You can source this file from your shell to have the key defined in your
    local environment:
    ```
    source _rhel_act_key_creds.txt
    ```
    
2. Add the following repositories to your activation key:
    * Red Hat CodeReady Linux Builder for RHEL 9 IBM z Systems (Debug RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 IBM z Systems (RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 x86_64 (Debug RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 x86_64 (RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 ARM 64 (Debug RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 ARM 64 (RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 Power, little endian (Debug RPMs)
    * Red Hat CodeReady Linux Builder for RHEL 9 Power, little endian (RPMs)

3. Create a RHEL offline token in [this page][rhtok]. Store it in a file called
   `_rh_offline_token_creds.txt` with format like the following:
   ```
   REDHAT_OFFLINE_TOKEN=<token here>>
   export REDHAT_OFFLINE_TOKEN
   ```
   Source the file to ge the token in your current environment:
   ```
   source _rh_offline_token_creds.txt
   ```

4. Download the RHEL base image using the `rhel/fetch_base_image.sh` script in
   this repo. The script required the `REDHAT_OFFLINE_TOKEN` environment
   variable to be defined. The image will be places in a file called 
   `rhel-9.5-s390x-kvm.qcow2` in the local directory.

5. Clone the [cloud-api-adapter][caa] repo. Then `cd` into the
   `src/cloud-api-adapter` directory.

6. From the `cloud-api-adapter` Git repo, run the following command to build the
   RHEL image for s390x (You need to have the RHEL activation key defined in
   the environment for the shell where you run this):
   ```
   ARCH=s390x PODVM_DISTRO=rhel make podvm-builder 
   ARCH=s390x PODVM_DISTRO=rhel make podvm-binaries 
   ARCH=s390x PODVM_DISTRO=rhel IMAGE_URL=/path/to/rhel.qcow2 \
      IMAGE_CHECKSUM=$(sha256sum $IMAGE_URL | cut -d\  -f1) \
      podvm-image
   ```
   This command would require `make` and `docker` or `podman` to run. It would
   build a container image locally with the POD-VM image in it.

7. Upload the image using the `src/cloud-api-adapter/ibmcloud/image/import.sh`
   script from the CAA repo. The script requires that `IBMCLOUD_API_KEY` would 
   be defined in the environment, as well as having a cloud storage instance and
   a bucket.
   ```
   import.sh \
      quay.io/confidential-containers/podvm-generic-rhel-<arch>:<image SHA>> \
      eu-de \
      --instance kata-peer-pods-poc-cos \
      --pull missing \
      --os rhel-coreos-stable-<arch>
   ```

[con.]: https://console.redhat.com
[caa]: https://github.com/confidential-containers/cloud-api-adaptor
[rhtok]: https://access.redhat.com/management/api

### 2.4 Enable traffic between AWS and IBM Cloud

1. In IBM Cloud:
    1. Create a VPN gateway - make note of the subnet you connect it to and
       you'll need to ensure all VMs are created in that subnet.
    2. Create an IKE policy (From the "IKE policies" tab on the VPNs screen),
       set the following values:
       1. IKE version: 2
       2. Encryption: aes256
       3. Authentication: sha256
       4. Diffie-Hellman Group: 14
       5. Key lifetime: 28800
    3. Create an IPsec policy (From the "IPsec policies" tab on the VPNs
       screen), set the following values:
       1. Encryption: aes256
       2. Authentication: sha256
       3. Perfect Forward Security: Enabled
       4. Diffie-Hellman Group: 14
       5. Key lifetime: 3600
2. In AWS:
    1. From the VPC console, create a Virtual Private Gateway (VPG).
    2. Click on the VPG ID to go into its details screen, from there you can 
       select "Attach to VPC" in the actions menu and attache it to the VPC your
       cluster resides in.
    3. Create a Customer Gateway (CGW), For the IP address put in one of the public
       IPs of the VPN gateway in the IBM side.
    4. Create a Site-to-Site VPN connection. Select the VPG and the CGW you've 
       created, select "static" routing and put in the CIDR block for the subnet
       you connected to the gateway in the IBM side. For both of the tunnels, 
       expand the options section, select "Edit tunnel X options" under
       "Advanced options for tunnel X" and set to following values to match the
       IKE and IPsec policies from the ibm side:
        1. Phase 1 encryption algorithms: AES256
        2. Phase 2 encryption algorithms: AES256
        3. Phase 3 integrity algorithms: SHA-256
        4. Phase 1 DH group numbers: 14
        5. Phase 5 DH group numbers: 14
        6. IKE Version: 2
        7. DPD timeout action: Restart
        8. All other values can remain with their defaults
    5. Select the VPN connection and click on the "Download configuration"
       button. From there select "Generic" for vendor and "Platform" and click
       "Download". The file will contain the keys you will need to setup the 
       connection from the IBM side.
3. In IBM Cloud:
    1. Go into the page for the VPN gateway you've created and create a VPN 
       connection. In the creation form:
        1. For "Peer gateway address" set the outside IP address for Tunnel 1
          from the AWS side.
        2. For "Preshared key" paste the key for tunel 1, you should be able to
           find it in the file you've downloaded.
        3. Select "Restart" For Dead peer detection action.
        4. Select the IKE and IPsec policies you've created.
    2. Repeat the process in section 1 above to create a VPN connection for
       Tunnel 2.
    3. If all goes well you should be able to see both connections become active
       within the next few minutes. The tunnels should also be show as "Up" on
       the AWS side.
    4. Edit the routing table for the subnet you've attached to the VPN, add a 
       route with:
        1. Destination set to the CIDR block of the cluster host's private
           subnet
        2. "Next hop type" set to "VPN connection"
        3. VPN Gateway set to the gateway you've created
        4. VPN connection set to the connection corresponding to Tunnel 1.
    5. (Optional) add a lower priority route to the same destination going
       through Tunnel 2.
4. In AWS:
    1. Edit the routing table for the cluster host's private subnet, add a route
       with the destination set to the CIDR block of the subnet you're using on
       the IBM side and the target set to the VPG you've created.

### 2.4 Create a security group

From the infrastructure console, select "Network", "Security Groups" and create
a new security group.

Create inbound rules for TCP ports 9000 and 15150, with the source set to the
CIDR block for the VPC used by the cluster on AWS.

Create an outbound rule allowing all traffic.

### 2.5 Create an SSH key

From the infrastructure console, select "Compute", "SSH keys" and create a new
key. Make sure you add it to the right resource group. For the key pair itself
you can either generate a new pair or past the a public key you already have.
This key is set on the peer POD VMs for debugging purposes.

### 2.6 Add a specialized cluster node for running the IBM cloud CAA

Use the ROSA OCM to add a machine pool. Add a `cloud-provider` label to the
machine pool with the value set to `ibm`. Also add a `NoSchedule` taint with the
same key and value.

### 2.7 Create the CAA DeamonSet

We need the CAA image from OSC 1.9.0 to work with the POD-VM image that we've,
built. At the time of writing this, OSC 1.9.0 was not release yet, so we fetch
the CAA image from an internal build registry and push it to the cluster's 
internal registry:
```
IMG_NAME=openshift-sandboxed-containers-operator-cloud-api-adaptor
CLUS_REG="$(
   oc get -n openshift-image-registry route default-route -o jsonpath='{.spec.host}'
)

podman pull \
   registry-proxy.engineering.redhat.com/rh-osbs/"$IMG_NAME":1.9.0-4
podman tag \
   registry-proxy.engineering.redhat.com/rh-osbs/"$IMG_NAME":1.9.0-4 \
   "$CLUS_REG"/openshift-sandboxed-containers-operator/"$IMG_NAME":1.9.0-4
podman push \
   "$CLUS_REG"/openshift-sandboxed-containers-operator/"$IMG_NAME":1.9.0-4
```
For the 1.9.0 CAA image to run, some RBAC changes need to be applied:
```
oc apply -f ibm/caa-1.9-clusterrole.yaml
oc apply -f ibm/caa-1.9-clusterrolebinding.yaml
```

Edit the `ibm/daemonset.yaml` file, set values for `IBMCLOUD_VPC_ENDPOINT`, 
`IBMCLOUD_RESOURCE_GROUP_ID`, `IBMCLOUD_SSH_KEY_ID`, `IBMCLOUD_PODVM_IMAGE_ID`,
`IBMCLOUD_ZONE`, `IBMCLOUD_VPC_SUBNET_ID`, `IBMCLOUD_VPC_SG_ID` and 
`IBMCLOUD_VPC_ID` according to the cloud configuration you've created.

Apply to the cluster:
```
oc apply -f ibm/deamonset.yaml
```

### 2.8. Run a test workload in IBM

Make sure you are in the "default" project or some other non-system project:

```
oc project default
```

Run an interactive peer-POD with the following command:

```
oc run kata-test1 -it --rm --pod-running-timeout=15m \
    --image=registry.access.redhat.com/ubi9-micro \
    --restart=Never \
    --overrides="$(cat ibm-overrides.json)"
```
