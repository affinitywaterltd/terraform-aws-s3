# AWS Simple Storage Service (S3) Terraform module

Terraform module which creates S3 resources on AWS.

This module focuses on S3, S3 Bucket Policy and IAM.

* [S3 Bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
* [S3 Bucket Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)


This Terraform module will provide the required resources for an S3 bucket and all the required resources.

## Terraform versions

Terraform ~> 0.12

## Usage

Example with minimum required and useful settings
```hcl
module "s3" {
  source = "github.com/affinitywaterltd/terraform-aws-s3"

  bucket = "example"
  default_logging_bucket = "accesslogs-bucket"

  tags = merge(
    local.common_tags,
    {
      "ApplicationType" = "Storage"
      "Name"            = "example"
      "Description"     = ""
      "CreationDate"    = "01/01/2020"
    },
  )
}
```

Example without the default lifecycle rules
```hcl
module "s3" {
  source = "github.com/affinitywaterltd/terraform-aws-s3"

  bucket = "example"
  default_logging_bucket = "accesslogs-bucket"

  default_lifecycle_rule_enabled = false
  
  tags = merge(
    local.common_tags,
    {
      "ApplicationType" = "Storage"
      "Name"            = "example"
      "Description"     = ""
      "CreationDate"    = "01/01/2020"
    },
  )
}
```

Example with custom default lifecycle rules
```hcl
module "s3" {
  source = "github.com/affinitywaterltd/terraform-aws-s3"

  bucket = "example"
  default_logging_bucket = "accesslogs-bucket"

  default_lifecycle_rule_enabled = false

  lifecycle_rule = [
    {
      enabled = true
      id      = "s3-lifecycle-policy-aw_example_custom_logging"

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA" # or "STANDARD_IA"
        }
      ]

      noncurrent_version_transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
        }
      ]

      noncurrent_version_expiration = {
        days = 60
      }

      expiration = {
        days = 60
      }
    }
  ]
  
  tags = merge(
    local.common_tags,
    {
      "ApplicationType" = "Storage"
      "Name"            = "example"
      "Description"     = ""
      "CreationDate"    = "01/01/2020"
    },
  )
}
```

Example with S3 hosted website
```hcl
module "s3" {
  source = "github.com/affinitywaterltd/terraform-aws-s3"

  bucket = "example-website"
  default_logging_bucket = "accesslogs-bucket"

  default_lifecycle_rule_enabled = false
  
  website = {
      index_document = "index.html" # or redirect_all_requests_to = "https://otherwebsite.co.uk"
  }

  attach_policy = true
  policy = data.aws_iam_policy_document.bucket_policy.json
  
  tags = merge(
    local.common_tags,
    {
      "ApplicationType" = "Storage"
      "Name"            = "example"
      "Description"     = ""
      "CreationDate"    = "01/01/2020"
    },
  )
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.example.id}"
      ]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::example-website/*",
    ]
  }
}
```

Example with a custom ACL
```hcl
module "s3" {
  source = "github.com/affinitywaterltd/terraform-aws-s3"

  bucket = "example"
  default_logging_bucket = "accesslogs-bucket"

  grant = [
    {
      id          = data.aws_canonical_user_id.current_user.id
      type        = "CanonicalUser"
      permissions = ["FULL_CONTROL"]
    },
    {
      id          = "1111111122222222333333334444444455555555666666667777777788888888"
      type        = "CanonicalUser"
      permissions = ["READ_ACP", "WRITE", "READ"]
    },
  ]
  
  tags = merge(
    local.common_tags,
    {
      "ApplicationType" = "Storage"
      "Name"            = "example"
      "Description"     = ""
      "CreationDate"    = "01/01/2020"
    },
  )
}
```
## Conditional creation

Sometimes you need to have a way to create S3 resources conditionally but Terraform does not allow to use `count` inside `module` block, so the solution is to specify argument `create_bucket`.

```hcl
# S3 bucket will not be created
module "s3" {
  source  = "github.com/affinitywaterltd/terraform-aws-s3"

  create_bucket = false
  # ... omitted
}
```

## Lifecycle Rule Defaults
| Type | Days | Storage Class |
|------|---------|----------|
| transition | 30 | `ONEZONE_IA`|
| noncurrent_version_transition | 30 | `ONEZONE_IA`|
| noncurrent_version_expiration | 180 | |
| abort_incomplete_multipart_upload_days | 30 | |

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.12 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create_bucket | Controls if S3 bucket should be created | `bool` | `true` | no |
| attach_elb_log_delivery_policy | Controls if S3 bucket should have ELB log delivery policy attached | `bool` | `true` | no |
| attach_policy | Controls if S3 bucket should have bucket policy attached (set to `true` to use value of `policy` as bucket policy) | `bool` | `false` | yes |
| policy | A valid bucket policy JSON document. Note that if the policy document is not specific enough (but still valid), Terraform may view the policy as constantly changing in a terraform plan. In this case, please make sure you use the verbose/specific version of the policy. For more information about building AWS IAM policy documents with Terraform, see the AWS IAM Policy Document Guide | `string` | `null` | no |
| bucket | The name of the bucket. If omitted, Terraform will assign a random, unique name. | `string` | `nonane` | no |
| bucket_prefix | Creates a unique bucket name beginning with the specified prefix. Conflicts with bucket | `string` | `null` | no |
| default_logging_bucket | Defines bucket name for default logging configuration | `string` | `null` | yes |
| acl | The canned ACL to apply. Defaults to 'private' | `string` | `private` | no |
| website | Map containing static web-site hosting or redirect configuration | `map(string)` | `{}` | no |
| cors_rule | Map containing a rule of Cross-Origin Resource Sharing | `any` | `{}` | no |
| versioning_enabled | Enables bucket versioning | `bool` | `true` | no |
| server_side_encryption_type | The server-side encryption algorithm to use. Valid values are AES256 and aws:kms | `string` | `AES256` | no |
| server_side_encryption_kms_key_id | The AWS KMS master key ID used for the SSE-KMS encryption. This can only be used when you set the value of sse_algorithm as aws:kms. The default aws/s3 AWS KMS master key is used if this element is absent while the sse_algorithm is aws:kms | `string` | `aws/s3` | no |
| versioning_mfa_delete | Enables requirement to provide MFA to delete items from S3 | `bool` | `false` | no |
| default_logging_enabled | Determines if a default logging config is applied | `bool` | `true` | no |
| custom_logging_config | Map containing access bucket logging configuration | `map(string)` | `{}` | no |
| lifecycle_rule | List of maps containing configuration of object lifecycle management | `any` | `[]` | no |
| block_public_acls | Whether Amazon S3 should block public ACLs for this bucket | `bool` | `true` | no |
| block_public_policy | Whether Amazon S3 should block public bucket policies for this bucket | `bool` | `true` | no |
| ignore_public_acls | Whether Amazon S3 should ignore public ACLs for this bucket | `bool` | `true` | no |
| restrict_public_buckets | Whether Amazon S3 should restrict public bucket policies for this bucket | `bool` | `true` | no |
| grant | Map containing all ACL rules. | `any` | `[]` | no |
| default_lifecycle_rule_enabled | Determines if a default lifecycle config is applied | `bool` | `true` | no |
| replication_configuration | Map containing cross-region replication configuration | `any` | `{}` | no |
| force_destroy | A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable | `bool` | `false` | no |
| acceleration_status | Sets the accelerate configuration of an existing bucket. Can be Enabled or Suspended | `string` | `Suspended` | no |
| request_payer | Specifies who should bear the cost of Amazon S3 data transfer. Can be either BucketOwner or Requester. By default, the owner of the S3 bucket would incur the costs of any data transfer. See Requester Pays Buckets developer guide for more information | `string` | `null` | no |
| tags | A mapping of tags to assign to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | The name of the bucket |
| arn | The ARN of the bucket. Will be of format arn:aws:s3:::bucketname |
| bucket_domain_name | The bucket domain name. Will be of format bucketname.s3.amazonaws.com |
| bucket_regional_domain_name | The bucket region-specific domain name. The bucket domain name including the region name, please refer here for format. Note: The AWS CloudFront allows specifying S3 region-specific endpoint when creating S3 origin, it will prevent redirect issues from CloudFront to S3 Origin URL |
| hosted_zone_id | The Route 53 Hosted Zone ID for this bucket's region |
| region | The AWS region this bucket resides in |
| website_endpoint | The website endpoint, if the bucket is configured with a website. If not, this will be an empty string |
| website_domain | The domain of the website endpoint, if the bucket is configured with a website. If not, this will be an empty string. This is used to create Route 53 alias records |