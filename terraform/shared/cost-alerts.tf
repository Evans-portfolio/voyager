data "azurerm_subscription" "current" {}

resource "azurerm_monitor_action_group" "billing_alerts" {
  name                = "ag-billing-alerts"
  resource_group_name = azurerm_resource_group.shared.name
  short_name          = "billing"

  email_receiver {
    name                    = "owner"
    email_address           = var.billing_alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-monthly-subscription"
  subscription_id = data.azurerm_subscription.current.id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = "2026-08-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 25
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.billing_alerts.id]
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.billing_alerts.id]
  }

  notification {
    enabled        = true
    threshold      = 75
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.billing_alerts.id]
  }

  lifecycle {
    ignore_changes = [time_period[0].start_date]
  }
}

output "billing_action_group_id" {
  value = azurerm_monitor_action_group.billing_alerts.id
}
