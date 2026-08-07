variable "billing_alert_email" {
  description = "Email address to receive subscription budget threshold alerts"
  type        = string
  default     = "kipkiruivans@gmail.com"
}

variable "monthly_budget_amount" {
  description = "Monthly subscription budget amount (USD) that the 25/50/75% thresholds are calculated against"
  type        = number
  default     = 100
}
