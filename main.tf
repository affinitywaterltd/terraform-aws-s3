data "aws_caller_identity" "current" {}


locals {
    default_logging_config = {
        target_bucket = var.default_logging_bucket
        target_prefix = "accesslogs/AWSLogs/${data.aws_caller_identity.current.account_id}/s3/${var.bucket}/"
    }
}


resource "aws_s3_bucket" "this" {
  count = var.create_bucket ? 1 : 0

  bucket              = var.bucket
  bucket_prefix       = var.bucket_prefix
  acl                 = var.grant == [] ? var.acl : null
  tags                = var.tags
  force_destroy       = var.force_destroy
  acceleration_status = length(keys(var.website)) == 0 ? var.acceleration_status : null
  #region              = var.region deprecated in v3.0.0 of the AWS provider
  request_payer       = var.request_payer


  #
  # Static Hosted Website
  #
  dynamic "website" {
    for_each = length(keys(var.website)) == 0 ? [] : [var.website]

    content {
      index_document           = lookup(website.value, "index_document", null)
      error_document           = lookup(website.value, "error_document", null)
      redirect_all_requests_to = lookup(website.value, "redirect_all_requests_to", null)
      routing_rules            = lookup(website.value, "routing_rules", null)
    }
  }

  #
  # Cross-Origin Resource Sharing
  #
  dynamic "cors_rule" {
    for_each = length(keys(var.cors_rule)) == 0 ? [] : [var.cors_rule]

    content {
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }

  #
  # ACL Grant Permissions
  #
  dynamic "grant" {
    for_each = var.grant

    content {
      id          = lookup(grant.value, "id", null)
      type        = lookup(grant.value, "type", null)
      permissions = lookup(grant.value, "permissions", null)
      uri         = lookup(grant.value, "uri", null)
    }
  }

  #
  # Versioning
  #
  versioning {
      enabled    = var.versioning_enabled
      mfa_delete = var.versioning_mfa_delete
  }

  #
  # Default Logging
  #
  dynamic "logging" {
    for_each = var.default_logging_enabled == true ? [local.default_logging_config] : []

    content {
      target_bucket = local.default_logging_config.target_bucket
      target_prefix = lookup(local.default_logging_config, "target_prefix", null)
    }
  }

  #
  # Custom Logging
  #
  dynamic "logging" {
    for_each = (var.default_logging_enabled == false && length(keys(var.custom_logging_config)) != 0) ? [var.custom_logging_config] : []

    content {
      target_bucket = var.custom_logging_config.target_bucket
      target_prefix = lookup(var.custom_logging_config, "target_prefix", null)
    }
  }

  #
  # Default Lifecycle Rules
  #
  dynamic "lifecycle_rule" {
    for_each = var.default_lifecycle_rule_enabled == true ? [1] : []

    content {
      id                                     = "default_lifecycle_rule"
      abort_incomplete_multipart_upload_days = 30
      enabled                                = var.default_lifecycle_rule_enabled

      transition {
        days          = 30
        storage_class = "ONEZONE_IA"
      }
      /*transition {
        days          = 180
        storage_class = "GLACIER"
      }*/

      # Max 1 block - noncurrent_version_expiration
      noncurrent_version_expiration {
        days = 180
      }

      # Several blocks - noncurrent_version_transition
      noncurrent_version_transition {
        days          = 30
        storage_class = "ONEZONE_IA"
      }
    }
  }


  #
  # Custom Lifecycle Rules
  #
  dynamic "lifecycle_rule" {
    for_each = var.default_lifecycle_rule_enabled == false ? var.lifecycle_rule : []

    content {
      id                                     = lookup(lifecycle_rule.value, "id", null)
      prefix                                 = lookup(lifecycle_rule.value, "prefix", null)
      tags                                   = lookup(lifecycle_rule.value, "tags", null)
      abort_incomplete_multipart_upload_days = lookup(lifecycle_rule.value, "abort_incomplete_multipart_upload_days", null)
      enabled                                = lifecycle_rule.value.enabled

      # Max 1 block - expiration
      dynamic "expiration" {
        for_each = length(keys(lookup(lifecycle_rule.value, "expiration", {}))) == 0 ? [] : [lookup(lifecycle_rule.value, "expiration", {})]

        content {
          date                         = lookup(expiration.value, "date", null)
          days                         = lookup(expiration.value, "days", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }

      # Several blocks - transition
      dynamic "transition" {
        for_each = lookup(lifecycle_rule.value, "transition", [])

        content {
          date          = lookup(transition.value, "date", null)
          days          = lookup(transition.value, "days", null)
          storage_class = transition.value.storage_class
        }
      }

      # Max 1 block - noncurrent_version_expiration
      dynamic "noncurrent_version_expiration" {
        for_each = length(keys(lookup(lifecycle_rule.value, "noncurrent_version_expiration", {}))) == 0 ? [] : [lookup(lifecycle_rule.value, "noncurrent_version_expiration", {})]

        content {
          days = lookup(noncurrent_version_expiration.value, "days", null)
        }
      }

      # Several blocks - noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = lookup(lifecycle_rule.value, "noncurrent_version_transition", [])

        content {
          days          = lookup(noncurrent_version_transition.value, "days", null)
          storage_class = noncurrent_version_transition.value.storage_class
        }
      }
    }
  }

  #
  # Cross-Region Replciation and Same-Region Replication (CRR and SRR)
  #
 # Max 1 block - replication_configuration
  dynamic "replication_configuration" {
    for_each = length(keys(var.replication_configuration)) == 0 ? [] : [var.replication_configuration]

    content {
      role = replication_configuration.value.role

      dynamic "rules" {
        for_each = replication_configuration.value.rules

        content {
          id       = lookup(rules.value, "id", null)
          priority = lookup(rules.value, "priority", null)
          prefix   = lookup(rules.value, "prefix", null)
          status   = lookup(rules.value, "status", null)

          dynamic "destination" {
            for_each = length(keys(lookup(rules.value, "destination", {}))) == 0 ? [] : [lookup(rules.value, "destination", {})]

            content {
              bucket             = lookup(destination.value, "bucket", null)
              storage_class      = lookup(destination.value, "storage_class", null)
              replica_kms_key_id = lookup(destination.value, "replica_kms_key_id", null)
              account_id         = lookup(destination.value, "account_id", null)

              dynamic "access_control_translation" {
                for_each = length(keys(lookup(destination.value, "access_control_translation", {}))) == 0 ? [] : [lookup(destination.value, "access_control_translation", {})]

                content {
                  owner = access_control_translation.value.owner
                }
              }
            }
          }

          dynamic "source_selection_criteria" {
            for_each = length(keys(lookup(rules.value, "source_selection_criteria", {}))) == 0 ? [] : [lookup(rules.value, "source_selection_criteria", {})]

            content {

              dynamic "sse_kms_encrypted_objects" {
                for_each = length(keys(lookup(source_selection_criteria.value, "sse_kms_encrypted_objects", {}))) == 0 ? [] : [lookup(source_selection_criteria.value, "sse_kms_encrypted_objects", {})]

                content {

                  enabled = sse_kms_encrypted_objects.value.enabled
                }
              }
            }
          }

          dynamic "filter" {
            for_each = length(keys(lookup(rules.value, "filter", {}))) == 0 ? [] : [lookup(rules.value, "filter", {})]

            content {
              prefix = lookup(filter.value, "prefix", null)
              tags   = lookup(filter.value, "tags", null)
            }
          }

        }
      }
    }
  }

  #
  # Server Side Encryption
  #
  # Max 1 block - server_side_encryption_configuration
  server_side_encryption_configuration {
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm     = var.server_side_encryption_type
            kms_master_key_id = (var.server_side_encryption_type == "AES256") ? null : var.server_side_encryption_kms_key_id
        }
    }
  }

}

resource "aws_s3_bucket_policy" "this" {
  count = var.create_bucket && (var.attach_elb_log_delivery_policy || var.attach_policy) ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = var.attach_elb_log_delivery_policy ? data.aws_iam_policy_document.elb_log_delivery[0].json : var.policy
}

# AWS Load Balancer access log delivery policy
data "aws_elb_service_account" "this" {
  count = var.create_bucket && var.attach_elb_log_delivery_policy ? 1 : 0
}

data "aws_iam_policy_document" "elb_log_delivery" {
  count = var.create_bucket && var.attach_elb_log_delivery_policy ? 1 : 0

  statement {
    sid = ""

    principals {
      type        = "AWS"
      identifiers = data.aws_elb_service_account.this.*.arn
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.this[0].id}/*",
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create_bucket ? 1 : 0

  // Chain resources (s3_bucket -> s3_bucket_policy -> s3_bucket_public_access_block)
  // to prevent "A conflicting conditional operation is currently in progress against this resource."
  bucket = (var.attach_elb_log_delivery_policy || var.attach_policy) ? aws_s3_bucket_policy.this[0].id : aws_s3_bucket.this[0].id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets

  depends_on = [aws_s3_bucket_policy.this]

}