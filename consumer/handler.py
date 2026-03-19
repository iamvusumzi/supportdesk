import json
import os
import logging
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_db_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        sslmode="require"
    )

def assign_team(priority: str) -> str:
    """
    Routing logic — the first version of what will eventually
    be AI-driven classification.
    """
    if priority in ("CRITICAL", "HIGH"):
        return "ESCALATIONS"
    return "GENERAL_SUPPORT"

def lambda_handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["body"])
        ticket_id = body["ticketId"]
        priority  = body["priority"]

        assigned_team = assign_team(priority)

        logger.info(f"Routing ticket {ticket_id} (priority={priority}) → {assigned_team}")

        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE tickets
                    SET assigned_team = %s,
                        updated_at    = now()
                    WHERE id = %s
                    """,
                    (assigned_team, ticket_id)
                )
            conn.commit()
            logger.info(f"Ticket {ticket_id} assigned to {assigned_team}")
        finally:
            conn.close()

    return {"statusCode": 200}