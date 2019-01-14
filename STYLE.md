# Telia Company Terraform Style Guide

## Introduction

This guide gives developers a guidance in the coding conventions used by Telia Company  for Terraform's HashiCorp Configuration Language (HCL). Terraform allows infrastructure to be described as code, which in turns makes changes and implementations of readable in a structured way. As such, we should adhere to a style guide to ensure readable and high quality code. As Terraform utilises [HCL](https://github.com/hashicorp/hcl), you may wish to take a detailed look at its [syntax guide](https://github.com/hashicorp/hcl/blob/master/README.md#syntax) for further guidance.

Inspired by [The Ruby Style Guide](https://github.com/bbatsov/ruby-style-guide) and [The Puppet Style Guide](https://docs.puppetlabs.com/guides/style_guide.html).

## Syntax

- Strings are in double-quotes.
- Booleans are in double-quotes.

### Spacing

Use 2 spaces when defining resources except when defining inline policies or other inline resources.

```hcl
resource "aws_iam_role" "iam_role" {
  name = "${var.resource_name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
```

There should be one blank lines between resource definitions.

```hcl
// bad
variable "vpc_id" {}

variable "vpc_id" {
  description = "The VPC this security group will go in"
  type        = "string"
}

// goo
variable "vpc_id" {
  description = "The VPC this security group will go in"
  type        = "string"
}


variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = "list"
  default     = []
}
```

### Resource Block Alignment

Parameter definitions in a resource block should be aligned. The `terraform fmt` command can do this for you.

```hcl
// bad
resource "aws_security_group" "main" {
    name = "${var.name}"
    description = "Security Group ${var.name}"
    vpc_id = "${var.vpc_id}"
    tags {
        Name = "${var.name}"
    }
}

// good
resource "aws_security_group" "main" {
  name        = "${var.name}"
  description = "Security Group ${var.name}"
  vpc_id      = "${var.vpc_id}"
  tags {
    Name = "${var.name}"
  }
}
```

### Variables

Variables should be provided in a `variables.tf` file at the root of your module.

A description and type should be provided for each declared variable. When it makes sense, please provide a reasonable default value.

## Outputs

Outputs should be provided in an `outputs.tf` file at the root of your module.

Attributes exported by your modules should follow the same descriptive format as variable names.

## Comments

Only comment what is necessary.

Single line comments: `#` .

Multi-line comments: `/*` followed by `*/`.

When commenting use two "//" and a space in front of the comment.

```hcl
# CREATE ELK IAM ROLE 
...
```

## Naming Conventions

### File Names and Structure

We strongly recommend that terraform modules and resources are grouped in a feature-based structure, this means that you should always strive to start with main.tf and split your resources into features, where each file groups a set of resources.

If your module is less complex, please attempt to flatten the directory structure

```shell
$ tree minimal-module/
.
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
```

For a complex module, resource creation may be split into multiple files but all nested module usage should be in the main file. variables.tf and outputs.tf should contain the declarations for variables and outputs, respectively.

Nested modules should exist under the modules/ subdirectory, global resources such as policy declarations should be declared in a standalone file (e.g. policies.tf).

```shell
$ tree module/
.
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── policies.tf
├── ...
├── modules/
│   ├── nestedA/
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── nestedB/
│   ├── .../
├── examples/
│   ├── default/
│   │   ├── main.tf
        .../
│   ├── advanced/
│   ├── .../
```

For more information see the official styleguide for Terraform.

### Parameter, Meta-parameter and Variable Naming

 Only use an underscore (`_`) when naming Terraform resources like TYPE/NAME parameters and variables.

 ```hcl
resource "aws_security_group" "security_group" {
...
 ```

Variable names should be descriptive. Avoid abbreviations when reasonable.  Verbosity is a good thing.

```hcl
// bad
variable "pub_sub_id" {}

// good
variable "public_subnet_id" {
  // definition
}
```

Boolean variables should follow the underlying definition in order to make the exposure transparent, if exposing an underlying modules variables try to stay as close to original modules declaration as possible.  

```hcl
// bad
variable "public" {}

variable "task_container_assign_public_ip" {
  description = "Assigned public IP to the container."
  default     = "false"
```

Terraform resources usually have an ID or some other attribute associated with them.  Variables for modules should refer to these attributes and match the actual name as much as possible.

```hcl
// bad
variable "vpc_cidr" {}
// -- or --
variable "cidr_block" {}
// -- or --
variable "address_range" {}


// good
variable "vpc_cidr_block" {
  // the vpc module exports an attribute named "cidr_block"
  description = "The CIDR block associated with the VPC"
  type = "string"
}
```

If the variable has a particular unit of measure, feel free to add that in for additional clarity.

```hcl
// bad
variable "root_disk_size" {}

// good
variable "root_disk_size_in_gb" {
  // definition
}
```

Variable names for lists should somehow indicate that they are a group of things.  You know... plural.

```hcl
// bad
variable "public_subnet_id" {}

// good
variable "public_subnet_ids" {
  // definition
}
```

Use variable names/descriptions from the official resource as much as possible. If the documentation provides a description of the resource, such as for the example for target groups, reuse the description.

| Argument         | Required | Description                                            |
| ---------------- | -------- | ------------------------------------------------------ |
| target_group_arn | Yes      | The ARN of the Target Group to which to route traffic. |

```hcl
// bad
output "target_group" {
  description = "The target Group."
  value       = "${module.grafana.target_group}"
}

// good
output "target_group_arn" {
  description = "The ARN of the Target Group."
  value       = "${module.grafana.target_group_arn}"
}

```

Not prefix all variable with the type of the resource, as it's apparent from the resource type.

```hcl
// bad
resource "aws_s3_bucket" "s3_bucket_imagest" {
  bucket = "${var.environment_name}-images-${var.aws_region}"
  acl    = "private"
}

// good
resource "aws_s3_bucket" "image_bucket" {
  bucket = "${var.environment_name}-images-${var.aws_region}"
  acl    = "private"
}
```

### Resource Naming

__Only use a hyphen (`-`) when naming the component being created.__


 ```hcl
resource "aws_security_group" "security_group" {
  name = "${var.resource_name}-security-group"
...
 ```

__A resource's NAME should be the same as the TYPE minus the provider.__

```hcl
resource "aws_autoscaling_group" "autoscaling_group" {
...
```

If there are multiple resources of the same TYPE defined, add a minimalistic identifier to differentiate between the two resources. A blank line should sperate resource definitions contained in the same file.

```hcl
// Create Data S3 Bucket
resource "aws_s3_bucket" "data_s3_bucket" {
  bucket = "${var.environment_name}-data-${var.aws_region}"
  acl    = "private"
  versioning {
    enabled = "true"
  }
}

// Create Images S3 Bucket
resource "aws_s3_bucket" "images_s3_bucket" {
  bucket = "${var.environment_name}-images-${var.aws_region}"
  acl    = "private"
}
```