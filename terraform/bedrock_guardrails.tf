# Insurance-Specific Guardrail
resource "aws_bedrock_guardrail" "denied_insurance_claims_policy" {
  name                      = "Denied-Insurance-Claims-Policy"
  description               = "This guardrail blocks any input to the model / output from the model related to specific denied insurance claims or coverage areas that are not part of the company's offerings."
  blocked_input_messaging   = "Sorry, I cannot answer this kind of question since it contains a denied topic related to insurance claims or coverage. [Blocked input] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."
  blocked_outputs_messaging = "Sorry, I cannot provide the answer for this question since it contains a denied topic related to insurance claims or coverage. [Blocked output] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."

  topic_policy_config {
    topics_config {
      name = "Denied-Claims"
      examples = [
        "Can I claim for a pre-existing condition?",
        "What is the claim process for car accidents not covered under my policy?"
      ]
      type       = "DENY"
      definition = "Denied claims refer to insurance claims related to conditions or incidents that are explicitly excluded from coverage by the policy terms or that fall outside the company's defined scope of coverage."
    }
    topics_config {
      name = "Exclusionary-Coverage"
      examples = [
        "Does your policy cover flood damage?",
        "Is earthquake coverage included in my home insurance?"
      ]
      type       = "DENY"
      definition = "Exclusionary coverage refers to coverage exclusions for specific events or perils under the policy. This guardrail blocks discussions on excluded coverage not offered by the company."
    }
    topics_config {
      name = "Non-Policy-Related-Advice"
      examples = [
        "How should I invest my money for retirement?",
        "What are some good stock picks for my portfolio?"
      ]
      type       = "DENY"
      definition = "Non-policy-related advice refers to financial or investment advice that is outside the scope of the insurance services provided by the company."
    }
  }
}

resource "aws_bedrock_guardrail_version" "denied_insurance_claims_policy_v1" {
  description   = "Denied-Insurance-Claims-Policy Version 1"
  guardrail_arn = aws_bedrock_guardrail.denied_insurance_claims_policy.guardrail_arn
}


# Content Filtering Guardrail
resource "aws_bedrock_guardrail" "content_filtering" {
  name                      = "Content-Filtering"
  description               = "This guardrail blocks any input to the model / output from the model if it contains harmful content."
  blocked_input_messaging   = "Sorry, I cannot answer this kind of question since it contains harmful content. [Blocked input] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."
  blocked_outputs_messaging = "Sorry, I cannot provide the answer for this question since the answer contains harmful content. [Blocked output] For our company's PII policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."

  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }
}

resource "aws_bedrock_guardrail_version" "content_filtering_v1" {
  description   = "Content-Filtering Version 1"
  guardrail_arn = aws_bedrock_guardrail.content_filtering.guardrail_arn
}


# Block PII Guardrail
resource "aws_bedrock_guardrail" "block_pii" {
  name                      = "Block-PII"
  description               = "This guardrail blocks any input to the model / output from the model if it contains any PII."
  blocked_input_messaging   = "Sorry, I cannot answer this kind of question since it contains PII. [Blocked input] For our company's PII policy, please refer here <Link-to-PII-Policy>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."
  blocked_outputs_messaging = "Sorry, I cannot provide the answer for this question since it contains PII. [Blocked output] For our company's PII policy, please refer here <Link-to-PII-Policy>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "ADDRESS"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "AGE"
      action = "BLOCK"
    }
    # Additional PII types...
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
  }
}

resource "aws_bedrock_guardrail_version" "block_pii_v1" {
  description   = "Block-PII Version 1"
  guardrail_arn = aws_bedrock_guardrail.block_pii.guardrail_arn
}


# Competitors Guardrail
resource "aws_bedrock_guardrail" "denied_topics" {
  name                      = "Denied-Topics"
  description               = "This guardrail blocks any input to the model / output from the model if it contains mention of a specifically denied topic."
  blocked_input_messaging   = "Sorry, I cannot answer this kind of question since it contains mention of a specifically denied topic. [Blocked input] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."
  blocked_outputs_messaging = "Sorry, I cannot provide the answer for this question since it contains mention of a specifically denied topic. [Blocked output] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."

  topic_policy_config {
    topics_config {
      name       = "insurance_competitors"
      examples   = ["Who are some of your competitors in insurance?", "Why is your policy better than XYZ Insurance?"]
      type       = "DENY"
      definition = "Insurance competitors refer to other companies or organizations that offer similar insurance products to the same target customers."
    }
  }
}

resource "aws_bedrock_guardrail_version" "denied_topics_v1" {
  description   = "Denied-Topics Version 1"
  guardrail_arn = aws_bedrock_guardrail.denied_topics.guardrail_arn
}


# Word Filters Guardrail
resource "aws_bedrock_guardrail" "word_filters" {
  name                      = "Word-Filters"
  description               = "This guardrail blocks any input or output that contains sensitive words or phrases."
  blocked_input_messaging   = "Sorry, I cannot answer this kind of question since it contains sensitive words or phrases. [Blocked input] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."
  blocked_outputs_messaging = "Sorry, I cannot provide the answer for this question since it contains sensitive words or phrases. [Blocked output] For our company's acceptable use policy, please refer here <Link-to-AUP>. If you feel this is an error, please reach out to IT Security here <Link-to-IT-Security> for further investigation."

  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }
}

resource "aws_bedrock_guardrail_version" "word_filters_v1" {
  description   = "Word-Filters Version 1"
  guardrail_arn = aws_bedrock_guardrail.word_filters.guardrail_arn
}


locals {
  guardrails = [
    aws_bedrock_guardrail.denied_insurance_claims_policy,
    aws_bedrock_guardrail.content_filtering,
    aws_bedrock_guardrail.block_pii,
    aws_bedrock_guardrail.denied_topics,
    aws_bedrock_guardrail.word_filters
  ]
  guardrail_ids = {
    for obj in local.guardrails : "${obj.name}" => obj.guardrail_id
  }
}

output "guardrail_ids" {
  value = local.guardrail_ids
}


