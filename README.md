Automating JSON Translation with AWS Lambda, Amazon Translate, and Terraform
---

```markdown
# 🌍 AWS JSON Translation Pipeline (Terraform + Lambda + Amazon Translate)

## 📌 Project Overview
This project builds a **serverless pipeline** that automatically translates JSON files uploaded to an S3 bucket into multiple languages using **Amazon Translate**, with the entire infrastructure managed via **Terraform**.

**Workflow:**
1. Upload a JSON file to the **input S3 bucket**
2. An **S3 event** triggers a **Lambda function**
3. Lambda reads the file, translates the text fields, and saves the results in the **output S3 bucket**
4. Translations are generated as new JSON files per language

---

## 🏗️ Architecture
```

┌─────────────┐       ┌──────────┐       ┌────────────┐
│  Input S3   │──────▶│  Lambda  │──────▶│  Output S3 │
│  Bucket     │       │ (Python) │       │  Bucket    │
└─────────────┘       └──────────┘       └────────────┘
│
▼
Amazon Translate

````

---

## ⚙️ Tech Stack
- **Terraform** – Infrastructure as Code  
- **AWS Lambda** – Python (boto3)  
- **Amazon S3** – Storage  
- **Amazon Translate** – Translation service  
- **Amazon Comprehend** – Language detection (`source_language=auto`)  
- **CloudWatch Logs** – Monitoring  

---

## 📂 JSON Input Format
```json
{
  "source_language": "auto",
  "target_languages": ["es", "fr"],
  "entries": [
    {"id": "1", "text": "Hello, world!"}
  ]
}
````

---

## 🚀 Setup Instructions

### 1️⃣ Clone the repo

```bash
git clone https://github.com/<your-username>/translation-pipeline.git
cd translation-pipeline
```

### 2️⃣ Deploy infrastructure with Terraform

```bash
terraform init
terraform apply -auto-approve
```

This creates:

* Input & Output S3 buckets
* IAM role + policies
* Lambda function
* S3 → Lambda trigger

### 3️⃣ Upload a test file

```bash
aws s3 cp test_inputs/greeting.json s3://<your-input-bucket>/greeting.json
```

### 4️⃣ Monitor execution

```bash
aws logs tail /aws/lambda/<your-lambda-name> --since 5m --follow
```

### 5️⃣ Check translated outputs

```bash
aws s3 ls s3://<your-output-bucket>/
aws s3 cp s3://<your-output-bucket>/greeting.es.translated.json .
```

---

## 🛠️ IAM Permissions

Lambda requires access to:

* **S3**

  * `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`
* **Translate**

  * `translate:TranslateText`
* **Comprehend**

  * `comprehend:DetectDominantLanguage` (if using `"source_language": "auto"`)
* **CloudWatch Logs**

  * `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

---

## 🧩 Common Issues

* **Empty output bucket** → Check CloudWatch logs for IAM errors
* **Auto language detection failing** → Ensure `comprehend:DetectDominantLanguage` is included in IAM policy
* **Lambda not triggering** → Verify S3 bucket notification (`aws s3api get-bucket-notification-configuration`)

---

## 🔮 Future Improvements

* Add Dead Letter Queue (SQS/SNS) for failed jobs
* Encrypt buckets with KMS
* Lifecycle policies for storage optimization
* API Gateway endpoint for uploads
* UI dashboard for monitoring translations

---

## 📈 Outcome

A **scalable, serverless translation pipeline** that translates text from JSON payloads into multiple languages, entirely provisioned with Terraform.

---

```
