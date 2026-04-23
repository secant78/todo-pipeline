"""
Lambda function invoked by AWS Secrets Manager to rotate the JWT secret key.
Secrets Manager calls this with four lifecycle steps: createSecret, setSecret,
testSecret, finishSecret.  For a simple random string we only need createSecret
and finishSecret.
"""
import boto3
import secrets
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sm = boto3.client("secretsmanager")


def handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    metadata = sm.describe_secret(SecretId=arn)
    versions = metadata.get("VersionIdsToStages", {})

    if token not in versions:
        raise ValueError(f"Version {token} not found in secret {arn}")

    if "AWSCURRENT" in versions.get(token, []):
        logger.info("Version %s is already current — nothing to do", token)
        return

    if step == "createSecret":
        # Generate a cryptographically secure 64-character hex key
        new_secret = secrets.token_hex(32)
        sm.put_secret_value(
            SecretId=arn,
            ClientRequestToken=token,
            SecretString=new_secret,
            VersionStages=["AWSPENDING"],
        )
        logger.info("Created new secret version %s", token)

    elif step == "setSecret":
        # Nothing to propagate — ECS tasks pick up the new value on next restart
        logger.info("setSecret: no-op for plain text secret")

    elif step == "testSecret":
        # Verify the new value is a non-empty string
        val = sm.get_secret_value(SecretId=arn, VersionStage="AWSPENDING")
        assert val["SecretString"], "New secret is empty"
        logger.info("testSecret: new value looks valid")

    elif step == "finishSecret":
        # Promote AWSPENDING to AWSCURRENT; Secrets Manager demotes the old
        # AWSCURRENT to AWSPREVIOUS automatically.
        sm.update_secret_version_stage(
            SecretId=arn,
            VersionStage="AWSCURRENT",
            MoveToVersionId=token,
            RemoveFromVersionId=next(
                v for v, stages in versions.items() if "AWSCURRENT" in stages
            ),
        )
        logger.info("finishSecret: version %s is now AWSCURRENT", token)
