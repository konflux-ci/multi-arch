# Importing AMIs to AWS

An IAM role is needed to enable importing AMIs via the `aws ec2 import-snapshot` 
command. This is, used, among other things, by the cootch-image-builder's AMI
upload functionality. Here is how to create it:

1. Create the role using the CLI with the trust policy file in this directory:
    ```
    aws iam create-role --role-name vmimport \
        --assume-role-policy-document file://aws/vmimport-trust-policy.json
    ```

2. Attach the security policy to the role:
    ```
    aws iam put-role-policy --role-name vmimport --policy-name vmimport-policy \
        --policy-document file://aws/vmimport-role-policy.json
    ```
    This policy assume we export to the `kata-image-bucket` S3 bucket, if using
    another bucket, change the policy accordingly.
