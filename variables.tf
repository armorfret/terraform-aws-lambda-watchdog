variable "lambda_version" {
  description = "Version of the Lambda to use"
  type        = string
  default     = "v0.0.7"
}

variable "logging_bucket" {
  description = "S3 bucket to use for bucket logging"
  type        = string
}

variable "config_bucket" {
  description = "S3 bucket to use for configuration"
  type        = string
}

variable "data_bucket" {
  description = "S3 bucket from which to read data"
  type        = string
}

variable "lambda_bucket" {
  description = "S3 bucket from which to read the Lambda ZIP"
  type        = string
}

variable "hostname" {
  description = "Hostname to use for the site"
  type        = string
}

variable "rate" {
  description = "Frequency at which to invoke Lambda"
  type        = string
  default     = "1 hour"
}
