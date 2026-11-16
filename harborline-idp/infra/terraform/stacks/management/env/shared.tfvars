location                   = "canadacentral"
cost_center                = "CC-1001"
management_subscription_id = "00000000-0000-0000-0000-000000000001"
monitored_subscription_ids = [
  "00000000-0000-0000-0000-000000000002",
  "00000000-0000-0000-0000-000000000010",
  "00000000-0000-0000-0000-000000000020",
  "00000000-0000-0000-0000-000000000030",
]
groups = {
  platform_admins = "00000000-0000-0000-0000-00000000a001"
  all_engineers   = "00000000-0000-0000-0000-00000000a002"
}
alert_emails = {
  platform = "platform-oncall@harborline.example"
}
