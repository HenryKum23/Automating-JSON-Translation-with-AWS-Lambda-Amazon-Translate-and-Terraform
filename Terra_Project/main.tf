data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda.zip"
}

resource "aws_s3_bucket" "input" {
  bucket = var.input_bucket_name
  acl    = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "output" {
  bucket = var.output_bucket_name
  acl    = "private"
  force_destroy = true
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_translate_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "translate:TranslateText",
          "comprehend:DetectDominantLanguage",   # <-- add this
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.input.arn,
          "${aws_s3_bucket.input.arn}/*",
          aws_s3_bucket.output.arn,
          "${aws_s3_bucket.output.arn}/*"
        ]
      },
      {
        Sid = "TranslateAccess"
        Effect = "Allow"
        Action = [
          "translate:TranslateText"
        ]
        Resource = "*"
      },
      {
        Sid = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "translator" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
  function_name    = "${var.name_prefix}-translate-lambda"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output.bucket
      # Optional defaults:
      DEFAULT_TARGET_LANGS = join(",", var.default_target_languages)
      # e.g. "es,fr,de"
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translator.function_name
  principal     = "s3.amazonaws.com"
  # source_arn could be limited to the bucket:
  source_arn    = aws_s3_bucket.input.arn
}

resource "aws_s3_bucket_notification" "input_notify" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.translator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_event_filter_prefix != "" ? var.s3_event_filter_prefix : null
    filter_suffix       = var.s3_event_filter_suffix != "" ? var.s3_event_filter_suffix : null
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
