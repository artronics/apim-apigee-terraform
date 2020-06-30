data "archive_file" "bundle" {
  type = "zip"
  source_dir = "${path.root}/proxies/${var.proxy_type}"
  output_path = "${path.root}/build/${var.service_name}.zip"
}

resource "apigee_api_proxy" "proxy" {
  // add namespace
  name = "${var.service_name}-${var.apigee_environment}"
  bundle = data.archive_file.bundle.output_path
  bundle_sha = data.archive_file.bundle.output_sha
}

resource "apigee_api_proxy_deployment" "proxy_deployment" {
  proxy_name = apigee_api_proxy.proxy.name
  env = var.apigee_environment
  revision = "latest"

  # This tells the deploy to give existing connections a 60 grace period before abandoning them,
  # and otherwise deploys seamlessly.
  override = true
  delay = 60

  # Explicit dependency
  depends_on = [apigee_api_proxy.proxy]
}

resource "apigee_product" "product" {
  count = 0
  name = "${var.service_name}-${var.apigee_environment}"
  display_name = "${var.api_product_display_name} (${var.env_names[var.apigee_environment]} environment)"
  description = var.api_product_description
  approval_type = length(regexall("prod|ref", var.apigee_environment)) > 0 ? "manual" : "auto"
  proxies = var.apigee_environment == "int" ? [apigee_api_proxy.proxy.name, "identity-service-${var.apigee_environment}", "identity-service-${var.apigee_environment}-no-smartcard" ] : [apigee_api_proxy.proxy.name, "identity-service-${var.apigee_environment}"]

  quota = 300
  quota_interval = 1
  quota_time_unit = "minute"

  attributes = {
    access = "public",
    ratelimit = "5ps"
  }

  environments = [var.apigee_environment]
}
