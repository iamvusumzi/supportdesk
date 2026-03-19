resource "aws_sqs_queue" "ticket_routing" {
  name                       = "supportdesk-ticket-routing"
  visibility_timeout_seconds = 60    # must be >= Lambda timeout
  message_retention_seconds  = 86400 # 1 day

  # Dead letter queue configuration — ensures no message is lost
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ticket_routing_dlq.arn
    maxReceiveCount     = 3   # retry 3 times before sending to DLQ
  })
}

# Dead letter queue
resource "aws_sqs_queue" "ticket_routing_dlq" {
  name                      = "supportdesk-ticket-routing-dlq"
  message_retention_seconds = 604800  # 7 days — time to investigate failures
}