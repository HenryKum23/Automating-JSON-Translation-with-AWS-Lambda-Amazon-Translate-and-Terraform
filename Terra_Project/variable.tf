variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "name_prefix" {
  type    = string
  default = "ws-translate"
}

variable "input_bucket_name" {
  type    = string
  default = "ws-translate-input-bucket" # change to unique bucket name
}

variable "output_bucket_name" {
  type    = string
  default = "ws-translate-output-bucket" # change to unique bucket name
}

variable "default_target_languages" {
  type    = list(string)
  default = ["es"]
}

variable "s3_event_filter_prefix" {
  type    = string
  default = ""  # e.g. "uploads/"
}

variable "s3_event_filter_suffix" {
  type    = string
  default = ".json"
}
