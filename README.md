# multi-arch
Putting together a multi-arch configuration for Konflux

## Setting up AWS credentials for Crossplane

1. Create a "crossplane" user in IAM
2. Assign the `AmazonEC2FullAccess` role to it
3. Generate an access key
4. Store the access key in the `_aws_crossplane_creds.txt` with the following format:

    ```
    [default]
    aws_access_key_id = ID_HERE
    aws_secret_access_key = KEY_HERE
    ```
    That file is mentioned in `.gitignoer` so you wouldn't accidentally commit it
5. Create a secret in the cluster 
   
    ```
    kubectl create secret \
        generic aws-secret \
        --from-file=creds=./_aws_crossplane_creds.txt
    ```

## Other needed AWS settings

1. Create an SSH key pair called "crossplane"
2. Create a default VPC
3. Create a security group called "ssh" to allow inbound SSH traffic

## Creating a VPC in IBM cloud

In the left-hand menu, go into "Infrastructure" and there to "Network"->"VPCs"
and click on "Create".

Create a "crossplane" VPC within a "crossplane" resource group.

Can also set the default security group to allow SSH at this point.

(Just for the test) In the list of of "Subnets" in the bottom of the page,
select each subnet, click on the "edit" icon and enable the public gateway in
in the bottom of the right-hand menu to enable internet access.

## Setting up IBM cloud credentials

To go into IAM in IBM cloud console, go into the "Manage" menu in the top right,
and from there, into "Access (IAM)".

Select "Service IDs" in the left-hand menu and click on "Create service ID" and
create a "crossplane" service ID.

Te setup permissions:

1. In the "Assign Access" screen select "Access policy".
2. Select "VPC Infrastructure Services" under "Service".
3. Under "Resources" select "Specific resources", "Resource group" and
   "crossplane".
4. In "Resource group access" select "Viewer", "Operator" and "Editor".
5. In "Roles and actions" under "Platform access" select "Viewer", "Operator"
   and "Editor".
6. Leave the "Conditions" section empty.

To crate the "API key":

1. Under "API keys", click "Create".
2. Copy the key to the clipboard, or download.
3. Run the following command to save to a secret in the cluster:

    ```
    kubectl create secret \
      generic provider-ibm-cloud-secret \
      --from-literal=credentials=KEY_HERE
    ```
