import os
import json
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
translate = boto3.client('translate')

OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET")
DEFAULT_TARGET_LANGS = os.environ.get("DEFAULT_TARGET_LANGS", "es").split(",")

def translate_text(text, source_lang='auto', target_lang='es'):
    # Amazon Translate: translate_text
    try:
        resp = translate.translate_text(
            Text=text,
            SourceLanguageCode=source_lang,
            TargetLanguageCode=target_lang
        )
        return resp.get('TranslatedText')
    except ClientError as e:
        logger.error("Translate API error: %s", e)
        raise

def process_payload(payload):
    """
    Expecting payload like:
    {
      "source_language": "auto",                     # optional
      "target_languages": ["es","fr"],               # optional (overrides env default)
      "entries": [
         {"id": "1", "text": "Hello world"},
         {"id": "2", "text": "Another sentence"}
      ]
    }
    """
    source_lang = payload.get("source_language", "auto")
    target_languages = payload.get("target_languages", DEFAULT_TARGET_LANGS)
    entries = payload.get("entries", [])

    results = {}
    for tlang in target_languages:
        translated_entries = []
        for e in entries:
            text = e.get("text", "")
            if not text:
                translated_text = ""
            else:
                translated_text = translate_text(text, source_lang, tlang)
            new_entry = dict(e)  # copy original fields
            new_entry["translated_text"] = translated_text
            new_entry["target_language"] = tlang
            translated_entries.append(new_entry)
        results[tlang] = {
            "target_language": tlang,
            "source_language": source_lang,
            "entries": translated_entries
        }
    return results

def write_output(s3_bucket, key_prefix, lang, result):
    out_key = f"{key_prefix.rstrip('/')}.{lang}.translated.json"
    try:
        s3.put_object(
            Bucket=s3_bucket,
            Key=out_key,
            Body=json.dumps(result, ensure_ascii=False).encode('utf-8'),
            ContentType='application/json'
        )
        logger.info("Wrote translated file %s to bucket %s", out_key, s3_bucket)
        return out_key
    except ClientError as e:
        logger.error("Failed to write output to S3: %s", e)
        raise

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    # Handle S3 put event (single record)
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        logger.info("Processing s3://%s/%s", bucket, key)
        try:
            obj = s3.get_object(Bucket=bucket, Key=key)
            body = obj['Body'].read()
            payload = json.loads(body)
        except Exception as e:
            logger.exception("Failed to read or parse JSON from S3: %s", e)
            continue

        try:
            results = process_payload(payload)
            # base output key prefix = original filename without .json
            base_prefix = key.rsplit('.', 1)[0]
            for lang, res in results.items():
                write_output(OUTPUT_BUCKET, base_prefix, lang, res)
        except Exception as e:
            logger.exception("Translation processing failed: %s", e)
            # Optionally: write a failed marker to output bucket
            error_key = f"{base_prefix}.error.json"
            try:
                s3.put_object(Bucket=OUTPUT_BUCKET, Key=error_key, Body=json.dumps({"error": str(e)}).encode('utf-8'))
            except Exception:
                logger.exception("Failed to write error marker.")
    return {"status": "done"}
